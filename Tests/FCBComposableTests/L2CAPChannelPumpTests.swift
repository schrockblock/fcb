import Foundation
import Darwin
import Testing
@testable import FCBComposable

/// Outcome of awaiting the next element of a consumed `AsyncStream`.
/// `.timedOut` is kept DISTINCT from `.finished` so a regression that leaves the
/// stream open (never finishing) fails the assertion cleanly instead of masking
/// as an end-of-stream — and instead of hanging the whole test run.
private enum StreamNext: Equatable {
    case value(Data)
    case finished
    case timedOut
}

/// Drives a single `AsyncStream<Data>` to completion on a background task,
/// buffering elements so the test can await each with a bounded timeout.
private final class TimedStreamConsumer: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [Data] = []
    private var finished = false

    init(_ stream: AsyncStream<Data>) {
        Task { [weak self] in
            for await chunk in stream {
                guard let self else { return }
                self.enqueue(chunk)
            }
            self?.markFinished()
        }
    }

    private func enqueue(_ chunk: Data) {
        lock.lock(); queue.append(chunk); lock.unlock()
    }

    private func markFinished() {
        lock.lock(); finished = true; lock.unlock()
    }

    /// Pops the next chunk if present, or reports stream-end. Non-async so the
    /// lock is never held across a suspension point.
    private func poll() -> (value: Data?, done: Bool) {
        lock.lock(); defer { lock.unlock() }
        if !queue.isEmpty { return (queue.removeFirst(), false) }
        if finished { return (nil, true) }
        return (nil, false)
    }

    /// Awaits the next element, distinguishing a genuine stream finish from a
    /// ~`seconds` timeout so regressions fail cleanly rather than hang.
    func next(seconds: Double = 2.0) async -> StreamNext {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while true {
            let (value, done) = poll()
            if let value { return .value(value) }
            if done { return .finished }
            if deadline.timeIntervalSinceNow <= 0 { return .timedOut }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

/// An `OutputStream` that accepts at most `perCall` bytes per `write` while
/// reporting `hasSpaceAvailable == true` until an in-memory sink fills. This
/// forces PARTIAL writes: `write(_:maxLength:)` returns fewer bytes than
/// requested even though the stream is still writable — the exact condition a
/// real `CBL2CAPChannel` produces but a CFStream-over-socketpair never does.
/// It exercises the pump's drain LOOP taking a second-and-later iteration inside
/// a single `send()`, which a break-after-one-write regression strands.
private final class PartialWritingOutputStream: OutputStream, @unchecked Sendable {
    private let perCall: Int
    private let capacity: Int
    private let lock = NSLock()
    private var sink = Data()

    init(perCall: Int, capacity: Int) {
        self.perCall = perCall
        self.capacity = capacity
        super.init(toMemory: ())
    }

    /// Snapshot of everything written so far, in order.
    var written: Data { lock.lock(); defer { lock.unlock() }; return sink }

    override func open() {}
    override func close() {}
    override var delegate: StreamDelegate? {
        get { nil }
        set {}
    }
    override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}
    override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {}

    override var hasSpaceAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        return sink.count < capacity
    }

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        guard sink.count < capacity else { return 0 }
        let n = min(len, perCall, capacity - sink.count)
        sink.append(UnsafeBufferPointer(start: buffer, count: n))
        return n
    }
}

/// A socketpair-backed stream pair for the pump plus a raw peer fd for the test.
/// Socket-backed CFStreams re-arm `hasSpaceAvailable` under dispatch-queue
/// scheduling exactly like a real `CBL2CAPChannel`, so the production code runs
/// on its genuine code path.
@MainActor
private struct PumpHarness {
    let pump: L2CAPChannelPump
    let peerFD: Int32          // test's raw socket fd (POSIX read/write)
    private let pumpReadStream: InputStream
    private let pumpWriteStream: OutputStream

    init(buffer: Int = 4096) {
        var fds: [Int32] = [0, 0]
        let rc = socketpair(AF_UNIX, SOCK_STREAM, 0, &fds)
        precondition(rc == 0, "socketpair failed: \(errno)")
        let pumpFD = fds[0]
        peerFD = fds[1]

        // Size the socket buffers so `largePayloadDrainsThroughSmallBuffer`
        // genuinely back-pressures and forces repeated hasSpaceAvailable re-arms.
        var sndbuf = Int32(buffer)
        setsockopt(pumpFD, SOL_SOCKET, SO_SNDBUF, &sndbuf, socklen_t(MemoryLayout<Int32>.size))
        var rcvbuf = Int32(buffer)
        setsockopt(peerFD, SOL_SOCKET, SO_RCVBUF, &rcvbuf, socklen_t(MemoryLayout<Int32>.size))

        // Non-blocking peer fd so the polling read helper can loop.
        let flags = fcntl(peerFD, F_GETFL, 0)
        _ = fcntl(peerFD, F_SETFL, flags | O_NONBLOCK)

        // Wrap the pump side in CFStreams; close the native socket on stream close.
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, pumpFD, &readStream, &writeStream)
        let cfRead = readStream!.takeRetainedValue()
        let cfWrite = writeStream!.takeRetainedValue()
        // Close the native socket when the streams close.
        CFReadStreamSetProperty(cfRead, CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket), kCFBooleanTrue)
        CFWriteStreamSetProperty(cfWrite, CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket), kCFBooleanTrue)
        pumpReadStream = cfRead as InputStream
        pumpWriteStream = cfWrite as OutputStream
        pump = L2CAPChannelPump(input: pumpReadStream, output: pumpWriteStream)
        pump.open()
    }

    /// Test writes bytes that land on the pump's input.
    func write(_ data: Data) {
        _ = data.withUnsafeBytes { raw in
            Darwin.write(peerFD, raw.baseAddress, data.count)
        }
    }

    /// Signals EOF to the pump's input by closing the peer fd.
    func closePeer() {
        Darwin.close(peerFD)
    }

    /// Polls the peer fd until `count` bytes arrive or ~2 s elapse.
    func read(count: Int) async -> Data {
        var out = Data()
        var scratch = [UInt8](repeating: 0, count: 4096)
        for _ in 0..<400 {
            let want = min(scratch.count, count - out.count)
            let n = scratch.withUnsafeMutableBytes { raw in
                Darwin.read(peerFD, raw.baseAddress, want)
            }
            if n > 0 { out.append(contentsOf: scratch[0..<n]) }
            if out.count >= count { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return out
    }
}

@Suite @MainActor
struct L2CAPChannelPumpTests {
    @Test func inboundBytesArriveOnIncomingStream() async {
        let harness = PumpHarness()
        let consumer = TimedStreamConsumer(harness.pump.incomingStream())
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.write(Data([0x01, 0x02, 0x03]))
        var received = Data()
        while received.count < 3, case let .value(chunk) = await consumer.next() { received.append(chunk) }
        #expect(received == Data([0x01, 0x02, 0x03]))
        harness.pump.close()
    }

    @Test func bytesArrivingBeforeConsumerAttachesAreBuffered() async {
        let harness = PumpHarness()
        harness.write(Data([0xAA, 0xBB]))
        try? await Task.sleep(nanoseconds: 100_000_000) // let the pump read pre-attach
        let consumer = TimedStreamConsumer(harness.pump.incomingStream())
        var received = Data()
        while received.count < 2, case let .value(chunk) = await consumer.next() { received.append(chunk) }
        #expect(received == Data([0xAA, 0xBB]))
        harness.pump.close()
    }

    @Test func outboundSendReachesTheFarSide() async throws {
        let harness = PumpHarness()
        try? await Task.sleep(nanoseconds: 50_000_000)
        try harness.pump.send(Data([0x10, 0x20]))
        let got = await harness.read(count: 2)
        #expect(got == Data([0x10, 0x20]))
        harness.pump.close()
    }

    @Test func largePayloadDrainsThroughSmallBuffer() async throws {
        // A small socket send buffer means the payload cannot go out in one write:
        // the pump fills the buffer, back-pressures, and must resume draining on
        // each `hasSpaceAvailable` as the far side consumes. All 8 KB-buffered
        // bytes of a 100 KB payload must arrive intact and in order.
        let harness = PumpHarness(buffer: 8192)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let payload = Data((0..<100_000).map { UInt8($0 % 251) })
        try harness.pump.send(payload)
        let got = await harness.read(count: payload.count)
        #expect(got == payload)
        harness.pump.close()
    }

    @Test func farSideEOFFinishesIncoming() async {
        let harness = PumpHarness()
        let consumer = TimedStreamConsumer(harness.pump.incomingStream())
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.closePeer()  // EOF on the pump's input
        let next = await consumer.next()
        #expect(next == .finished)
    }

    @Test func sendAfterCloseThrows() async {
        let harness = PumpHarness()
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.pump.close()
        #expect(throws: BluetoothError.operationCancelled) {
            try harness.pump.send(Data([0x01]))
        }
    }

    @Test func closeFinishesIncomingAndIsIdempotent() async {
        let harness = PumpHarness()
        let consumer = TimedStreamConsumer(harness.pump.incomingStream())
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.pump.close()
        harness.pump.close()  // second close is a no-op, no crash
        let next = await consumer.next()
        #expect(next == .finished)
    }

    @Test func secondIncomingStreamIsAlreadyFinished() async {
        let harness = PumpHarness()
        _ = harness.pump.incomingStream()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let second = TimedStreamConsumer(harness.pump.incomingStream())
        let next = await second.next()
        #expect(next == .finished)
        harness.pump.close()
    }

    /// Covers the drain LOOP's multi-iteration path directly: the output stream
    /// accepts only 1 byte per `write` while staying writable, so a single
    /// `send()` must loop many times to flush the payload. A break-after-one-write
    /// regression strands all but the first byte. (Uses a custom OutputStream so
    /// it does not depend on socket write-chunking, which the other tests use.)
    @Test func drainLoopFlushesPartialWritesWithinOneSend() async throws {
        // Real CFStream input (never fed) so the pump's input side is valid.
        var fds: [Int32] = [0, 0]
        precondition(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0)
        var readStream: Unmanaged<CFReadStream>?
        var writeStreamUnused: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, fds[0], &readStream, &writeStreamUnused)
        let cfRead = readStream!.takeRetainedValue()
        writeStreamUnused?.release()
        CFReadStreamSetProperty(cfRead, CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket), kCFBooleanTrue)
        let input = cfRead as InputStream

        let payload = Data((0..<500).map { UInt8($0 % 251) })
        let partial = PartialWritingOutputStream(perCall: 1, capacity: payload.count)
        let pump = L2CAPChannelPump(input: input, output: partial)
        pump.open()
        try? await Task.sleep(nanoseconds: 50_000_000)

        try pump.send(payload)

        // Poll the sink with a bounded timeout, mirroring the other tests.
        var got = Data()
        for _ in 0..<400 {
            got = partial.written
            if got.count >= payload.count { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(got == payload)
        pump.close()
        Darwin.close(fds[1])
    }
}
