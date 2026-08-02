import Foundation

/// Pumps one L2CAP channel's stream pair. Ported from ReTiCA's review-hardened
/// ChannelIO. All state is confined to `queue`: CFStream events are scheduled
/// onto it and the public methods hop onto it (send/close use queue.sync — they
/// must never be called FROM the pump queue itself). The designed-for-test
/// initializer takes a raw stream pair so bound in-memory pipes can drive it.
final class L2CAPChannelPump: NSObject, StreamDelegate, @unchecked Sendable {
    private let input: InputStream
    private let output: OutputStream
    private let queue: DispatchQueue

    // State confined to `queue`.
    private var finished = false
    private var incomingContinuation: AsyncStream<Data>.Continuation?
    private var incomingTaken = false
    private var preBuffer: [Data] = []   // inbound chunks before a consumer attaches

    // State confined to the run-loop thread (rlThread).
    private var outBuffer = Data()
    private var rlFinished = false

    // Run-loop thread for all stream I/O and event delivery.
    // CFStream hasSpaceAvailable events are not reliably re-delivered after a
    // bound-pair buffer fills and is drained; keeping all stream access on a
    // persistent run-loop thread lets drain() poll hasSpaceAvailable accurately
    // by briefly pumping the run loop between retries.
    private let rlThread = PumpRunLoopThread()

    init(input: InputStream, output: OutputStream,
         queue: DispatchQueue = DispatchQueue(label: "fcb.l2cap.pump")) {
        self.input = input
        self.output = output
        self.queue = queue
    }

    func open() {
        rlThread.schedule {
            self.input.delegate = self
            self.output.delegate = self
            self.input.schedule(in: .current, forMode: .default)
            self.output.schedule(in: .current, forMode: .default)
            self.input.open()
            self.output.open()
        }
    }

    /// Single-consumer: the first call returns the live stream (pre-attach
    /// chunks replayed in order); later calls return a finished stream.
    func incomingStream() -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        queue.async {
            guard !self.incomingTaken else { continuation.finish(); return }
            self.incomingTaken = true
            for chunk in self.preBuffer { continuation.yield(chunk) }
            self.preBuffer = []
            if self.finished {
                continuation.finish()
            } else {
                self.incomingContinuation = continuation
            }
        }
        return stream
    }

    /// Throws only when the channel is already closed/dead.
    func send(_ data: Data) throws {
        try queue.sync {
            guard !finished else { throw BluetoothError.operationCancelled }
        }
        rlThread.schedule {
            guard !self.rlFinished else { return }
            self.outBuffer.append(data)
            self.drain()
        }
    }

    /// Idempotent silent teardown; the only observable signal is `incoming` finishing.
    func close() {
        queue.sync { finishOnQueue() }
        rlThread.schedule {
            guard !self.rlFinished else { return }
            self.rlFinished = true
            self.outBuffer.removeAll()
            self.tearDownStreams()
        }
    }

    // MARK: - StreamDelegate (events arrive on rlThread run loop)

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            readAvailable()
        case .hasSpaceAvailable:
            drain()
        case .errorOccurred, .endEncountered:
            // Tear down streams here on the RL thread, then notify queue.
            guard !rlFinished else { return }
            rlFinished = true
            outBuffer.removeAll()
            tearDownStreams()
            queue.async { self.finishOnQueue() }
        default:
            break
        }
    }

    // MARK: - Run-loop-thread internals

    private func readAvailable() {
        guard !rlFinished else { return }
        var scratch = [UInt8](repeating: 0, count: 4096)
        while input.hasBytesAvailable {
            let count = input.read(&scratch, maxLength: scratch.count)
            if count > 0 {
                let chunk = Data(scratch[0..<count])
                queue.async {
                    guard !self.finished else { return }
                    if let continuation = self.incomingContinuation {
                        continuation.yield(chunk)
                    } else {
                        self.preBuffer.append(chunk)
                    }
                }
            } else if count < 0 {
                guard !rlFinished else { return }
                rlFinished = true
                outBuffer.removeAll()
                tearDownStreams()
                queue.async { self.finishOnQueue() }
                return
            } else {
                break
            }
        }
    }

    private func drain() {
        guard !rlFinished else { return }
        while !outBuffer.isEmpty {
            if !output.hasSpaceAvailable {
                // No space right now. Briefly pump the run loop so pending
                // events (e.g. hasSpaceAvailable after far end drains) can
                // fire, then retry.
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.001))
                if rlFinished { return }
                continue
            }
            let written = outBuffer.withUnsafeBytes { raw in
                output.write(raw.bindMemory(to: UInt8.self).baseAddress!, maxLength: outBuffer.count)
            }
            if written <= 0 { break }
            outBuffer.removeFirst(written)
        }
    }

    private func tearDownStreams() {
        input.remove(from: .current, forMode: .default)
        output.remove(from: .current, forMode: .default)
        input.delegate = nil
        output.delegate = nil
        input.close()
        output.close()
    }

    // MARK: - Queue-confined internals

    private func finishOnQueue() {
        guard !finished else { return }
        finished = true
        incomingContinuation?.finish()
        incomingContinuation = nil
    }
}

// MARK: - Private persistent run-loop thread

private final class PumpRunLoopThread: @unchecked Sendable {
    private let thread: Thread
    private let rl: RunLoop

    init() {
        var capturedRL: RunLoop?
        let sem = DispatchSemaphore(value: 0)
        thread = Thread {
            let rl = RunLoop.current
            capturedRL = rl
            rl.add(Port(), forMode: .default)  // keep run loop alive
            sem.signal()
            rl.run()
        }
        thread.name = "fcb.l2cap.runloop"
        thread.start()
        sem.wait()
        rl = capturedRL!
    }

    deinit {
        thread.cancel()
    }

    func schedule(_ block: @escaping () -> Void) {
        rl.perform(block)
    }
}
