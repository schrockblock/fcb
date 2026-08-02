@preconcurrency import CoreBluetooth
import Darwin
import Foundation
import Testing
@testable import FCBComposable

// MARK: - Helpers

/// Drives an AsyncStream<Data> in a background Task, buffering elements so
/// tests can await each with a bounded timeout. Avoids hanging on mutations.
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

/// Creates a socketpair-backed stream pair suitable for injection into
/// simulateInboundL2CAPChannelForTest. Returns (pumpInput, pumpOutput, peerFD).
/// The pump side is wrapped in CFStreams (shouldCloseNativeSocket = true).
/// The peer fd is non-blocking for test-side polling.
private func makeSocketPairStreams() -> (input: InputStream, output: OutputStream, peerFD: Int32) {
    var fds: [Int32] = [0, 0]
    precondition(socketpair(AF_UNIX, SOCK_STREAM, 0, &fds) == 0, "socketpair failed")
    let pumpFD = fds[0]
    let peerFD = fds[1]

    let flags = fcntl(peerFD, F_GETFL, 0)
    _ = fcntl(peerFD, F_SETFL, flags | O_NONBLOCK)

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
    return (cfRead as InputStream, cfWrite as OutputStream, peerFD)
}

// MARK: - Test suite

@Suite @MainActor
struct BluetoothPeripheralL2CAPTests {
    private func makeActor() async -> (PeripheralRoleActor, FakePeripheralManager) {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        // wireDelegate runs in a Task from init; give it a beat.
        try? await Task.sleep(nanoseconds: 50_000_000)
        return (actor, fake)
    }

    @Test func publishResolvesPSMAndRecordsEncryption() async throws {
        let (actor, fake) = await makeActor()
        fake.nextPublishPSM = 0x0192
        let psm = try await actor.publishL2CAPChannel(withEncryption: true)
        #expect(psm == 0x0192)
        #expect(fake.publishL2CAPCalls == [true])
    }

    @Test func publishErrorThrowsMappedBluetoothError() async {
        let (actor, fake) = await makeActor()
        fake.nextPublishError = NSError(domain: "test", code: 7)
        await #expect(throws: BluetoothError.underlying(NSError(domain: "test", code: 7))) {
            _ = try await actor.publishL2CAPChannel(withEncryption: false)
        }
    }

    @Test func unpublishForwardsPSM() async {
        let (actor, fake) = await makeActor()
        await actor.unpublishL2CAPChannel(psm: 0x0081)
        #expect(fake.unpublishL2CAPCalls == [0x0081])
    }

    @Test func inboundChannelSurfacesWithWorkingIO() async throws {
        let (actor, _) = await makeActor()

        // Use socketpair-backed streams — bound streams don't reliably fire
        // events under the pump's dispatch-queue scheduling.
        let (pumpInput, pumpOutput, peerFD) = makeSocketPairStreams()
        defer { Darwin.close(peerFD) }

        let stream = actor.l2capConnectionsStream()
        try? await Task.sleep(nanoseconds: 50_000_000)  // let registration land

        let peer = UUID()
        await actor.simulateInboundL2CAPChannelForTest(
            peerID: peer, psm: 0x0081, input: pumpInput, output: pumpOutput)

        // Bounded await so mutations that suppress yield cause a clean failure
        // rather than an infinite hang.
        let connection: L2CAPConnection? = await withTaskGroup(of: L2CAPConnection?.self) { group in
            group.addTask {
                var iter = stream.makeAsyncIterator()
                return await iter.next()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return nil
            }
            let result = await group.next()!
            group.cancelAll()
            return result
        }
        #expect(connection?.peerID == peer)
        #expect(connection?.psm == 0x0081)
        guard let connection else { return }

        // Inbound data flows: write from peer fd into the pump's input.
        let consumer = TimedStreamConsumer(connection.incoming())
        try? await Task.sleep(nanoseconds: 50_000_000)
        let inbound = Data([0x42])
        _ = inbound.withUnsafeBytes { raw in
            Darwin.write(peerFD, raw.baseAddress, inbound.count)
        }
        let chunk = await consumer.nextData()
        #expect(chunk == Data([0x42]))

        // Outbound data flows: send through connection, read on peer fd.
        try await connection.send(Data([0x99]))
        var got = Data()
        for _ in 0..<400 {
            var scratch = [UInt8](repeating: 0, count: 1)
            let n = Darwin.read(peerFD, &scratch, 1)
            if n > 0 {
                got.append(scratch[0])
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(got == Data([0x99]))
        await connection.close()
    }

    @Test func clientSurfaceForwardsToActor() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let client = BluetoothPeripheralClient.makeClient(actor: actor)
        fake.nextPublishPSM = 0x0200
        let psm = try await client.publishL2CAPChannel(false)
        #expect(psm == 0x0200)
        await client.unpublishL2CAPChannel(psm)
        #expect(fake.unpublishL2CAPCalls == [0x0200])
    }
}
