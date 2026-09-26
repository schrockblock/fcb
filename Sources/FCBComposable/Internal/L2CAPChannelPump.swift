import Foundation

/// A strong reference to a non-Sendable object (a `CBL2CAPChannel`) that is only
/// ever held, never used, so it can cross into the pump from the delegate callback.
struct RetainedObject: @unchecked Sendable {
    let object: AnyObject
    init(_ object: AnyObject) { self.object = object }
}

/// Pumps one L2CAP channel's stream pair. Ported from ReTiCA's review-hardened
/// ChannelIO. All state is confined to `queue`: CFStream events are scheduled
/// onto it and the public methods hop onto it (send/close use queue.sync — they
/// must never be called FROM the pump queue itself). The designed-for-test
/// initializer takes a raw stream pair so a socketpair-backed pipe can drive it.
final class L2CAPChannelPump: NSObject, StreamDelegate, @unchecked Sendable {
    private let input: InputStream
    private let output: OutputStream
    private let queue: DispatchQueue
    // CoreBluetooth closes an L2CAP channel when its CBL2CAPChannel is deallocated,
    // and the channel object is the only thing keeping the stream pair alive. The
    // pump owns it for exactly as long as it pumps the streams.
    private var retained: RetainedObject?

    // All mutable state is confined to `queue`.
    private var outBuffer = Data()
    private var finished = false
    private var incomingContinuation: AsyncStream<Data>.Continuation?
    private var incomingTaken = false
    private var preBuffer: [Data] = []   // inbound chunks before a consumer attaches

    /// `retaining`: the object that owns the stream pair (the `CBL2CAPChannel`),
    /// held until the channel finishes. Tests that drive a bare socket pair pass nothing.
    init(input: InputStream, output: OutputStream, retaining owner: RetainedObject? = nil,
         queue: DispatchQueue = DispatchQueue(label: "fcb.l2cap.pump")) {
        self.input = input
        self.output = output
        self.retained = owner
        self.queue = queue
    }

    func open() {
        queue.async {
            self.input.delegate = self
            self.output.delegate = self
            CFReadStreamSetDispatchQueue(self.input as CFReadStream, self.queue)
            CFWriteStreamSetDispatchQueue(self.output as CFWriteStream, self.queue)
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
            outBuffer.append(data)
            drain()
        }
    }

    /// Idempotent silent teardown; the only observable signal is `incoming` finishing.
    func close() {
        queue.sync { finishOnQueue() }
    }

    // MARK: - StreamDelegate (events arrive on `queue`)

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .hasBytesAvailable:
            readAvailable()
        case .hasSpaceAvailable:
            drain()
        case .errorOccurred, .endEncountered:
            finishOnQueue()
        default:
            break
        }
    }

    // MARK: - Queue-confined internals

    private func readAvailable() {
        guard !finished else { return }
        var scratch = [UInt8](repeating: 0, count: 4096)
        while input.hasBytesAvailable {
            let count = input.read(&scratch, maxLength: scratch.count)
            if count > 0 {
                let chunk = Data(scratch[0..<count])
                if let continuation = incomingContinuation {
                    continuation.yield(chunk)
                } else {
                    preBuffer.append(chunk)
                }
            } else if count < 0 {
                finishOnQueue()
                return
            } else {
                break
            }
        }
    }

    private func drain() {
        guard !finished else { return }
        while output.hasSpaceAvailable, !outBuffer.isEmpty {
            let written = outBuffer.withUnsafeBytes { raw in
                output.write(raw.bindMemory(to: UInt8.self).baseAddress!, maxLength: outBuffer.count)
            }
            if written <= 0 { break }
            outBuffer.removeFirst(written)
        }
    }

    private func finishOnQueue() {
        guard !finished else { return }
        finished = true
        outBuffer.removeAll()
        input.close()
        output.close()
        CFReadStreamSetDispatchQueue(input as CFReadStream, nil)
        CFWriteStreamSetDispatchQueue(output as CFWriteStream, nil)
        input.delegate = nil
        output.delegate = nil
        incomingContinuation?.finish()
        incomingContinuation = nil
        retained = nil
    }
}
