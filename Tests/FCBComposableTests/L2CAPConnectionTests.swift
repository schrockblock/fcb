import Foundation
import Darwin
import Testing
@testable import FCBComposable

/// Drives a single `AsyncStream<Data>` in a background Task, buffering
/// elements so the test can await each with a bounded timeout. Mirrors
/// the helper in L2CAPChannelPumpTests.
private final class TimedStreamConsumer: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [Data] = []
    private var done = false

    init(_ stream: AsyncStream<Data>) {
        Task { [weak self] in
            for await chunk in stream {
                guard let self else { return }
                self.enqueue(chunk)
            }
            self?.markDone()
        }
    }

    private func enqueue(_ chunk: Data) {
        lock.lock(); queue.append(chunk); lock.unlock()
    }

    private func markDone() {
        lock.lock(); done = true; lock.unlock()
    }

    private func poll() -> (value: Data?, finished: Bool) {
        lock.lock(); defer { lock.unlock() }
        if !queue.isEmpty { return (queue.removeFirst(), false) }
        if done { return (nil, true) }
        return (nil, false)
    }

    /// Awaits the next data chunk with a bounded timeout (~2 s).
    /// Returns nil on timeout or stream end.
    func nextData(seconds: Double = 2.0) async -> Data? {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while true {
            let (value, finished) = poll()
            if let value { return value }
            if finished { return nil }
            if deadline.timeIntervalSinceNow <= 0 { return nil }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

/// A socketpair-backed harness that creates a pump suitable for
/// `L2CAPConnection.make`. The pump side uses CFStream-wrapped socket fds;
/// the test side uses the raw peer fd (non-blocking) for POSIX read/write.
/// This mirrors L2CAPChannelPumpTests' PumpHarness so events fire reliably
/// under the pump's dispatch-queue scheduling.
@MainActor
private struct ConnectionHarness {
    let pump: L2CAPChannelPump
    let peerFD: Int32

    init() {
        var fds: [Int32] = [0, 0]
        precondition(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0, "socketpair failed")
        let pumpFD = fds[0]
        peerFD = fds[1]

        // Non-blocking peer fd so test-side polling read never hangs.
        let flags = fcntl(peerFD, F_GETFL, 0)
        _ = fcntl(peerFD, F_SETFL, flags | O_NONBLOCK)

        // Wrap the pump side in CFStreams; they will close the native socket.
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, pumpFD, &readStream, &writeStream)
        let cfRead = readStream!.takeRetainedValue()
        let cfWrite = writeStream!.takeRetainedValue()
        CFReadStreamSetProperty(cfRead,
            CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket),
            kCFBooleanTrue)
        CFWriteStreamSetProperty(cfWrite,
            CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket),
            kCFBooleanTrue)
        pump = L2CAPChannelPump(input: cfRead as InputStream, output: cfWrite as OutputStream)
    }

    /// Test writes bytes that land on the pump's input.
    func write(_ data: Data) {
        _ = data.withUnsafeBytes { raw in
            Darwin.write(peerFD, raw.baseAddress, data.count)
        }
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

    func closePeer() {
        Darwin.close(peerFD)
    }
}

@Suite @MainActor
struct L2CAPConnectionTests {
    @Test func factoryProducesWorkingConnection() async throws {
        let harness = ConnectionHarness()
        let peer = UUID()
        let connection = L2CAPConnection.make(pump: harness.pump, peerID: peer, psm: 0x0081)
        #expect(connection.peerID == peer)
        #expect(connection.psm == 0x0081)

        let consumer = TimedStreamConsumer(connection.incoming())
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Inbound: write [0x0A, 0x0B] to the pump's input side via the peer fd.
        let inbound = Data([0x0A, 0x0B])
        harness.write(inbound)
        var received = Data()
        while received.count < 2 {
            guard let chunk = await consumer.nextData() else { break }
            received.append(chunk)
        }
        #expect(received == inbound)

        // Outbound: send [0x0C] through the connection and read it on the peer fd.
        try await connection.send(Data([0x0C]))
        let got = await harness.read(count: 1)
        #expect(got == Data([0x0C]))

        await connection.close()
        harness.closePeer()
    }

    @Test func l2capNotSupportedErrorExistsAndIsEquatable() {
        #expect(BluetoothError.l2capNotSupported == BluetoothError.l2capNotSupported)
        #expect(BluetoothError.l2capNotSupported != BluetoothError.poweredOff)
    }
}
