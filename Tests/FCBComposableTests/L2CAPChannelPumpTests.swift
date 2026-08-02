import Foundation
import Testing
@testable import FCBComposable

/// One bound in-memory pipe: bytes written to `output` appear on `input`.
private func makeBoundPair(buffer: Int = 4096) -> (input: InputStream, output: OutputStream) {
    var input: InputStream?
    var output: OutputStream?
    Stream.getBoundStreams(withBufferSize: buffer, inputStream: &input, outputStream: &output)
    return (input!, output!)
}

/// Test-side harness around a pump: pipe1 feeds the pump's input,
/// pipe2 carries the pump's output back to the test.
@MainActor
private struct PumpHarness {
    let pump: L2CAPChannelPump
    let feed: OutputStream    // test writes here → pump's input
    let sink: InputStream     // pump's output lands here

    init(buffer: Int = 4096) {
        let pipe1 = makeBoundPair(buffer: buffer)
        let pipe2 = makeBoundPair(buffer: buffer)
        pump = L2CAPChannelPump(input: pipe1.input, output: pipe2.output)
        feed = pipe1.output
        sink = pipe2.input
        feed.open()
        sink.open()
        pump.open()
    }

    func write(_ data: Data) {
        _ = data.withUnsafeBytes { raw in
            feed.write(raw.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
        }
    }

    /// Polls the sink until `count` bytes arrive or ~2 s elapse.
    func read(count: Int) async -> Data {
        var out = Data()
        for _ in 0..<200 {
            var scratch = [UInt8](repeating: 0, count: count)
            while sink.hasBytesAvailable, out.count < count {
                let n = sink.read(&scratch, maxLength: min(scratch.count, count - out.count))
                if n > 0 { out.append(contentsOf: scratch[0..<n]) } else { break }
            }
            if out.count >= count { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return out
    }
}

@Suite @MainActor
struct L2CAPChannelPumpTests {
    @Test func inboundBytesArriveOnIncomingStream() async {
        let harness = PumpHarness()
        var iterator = harness.pump.incomingStream().makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.write(Data([0x01, 0x02, 0x03]))
        var received = Data()
        while received.count < 3, let chunk = await iterator.next() { received.append(chunk) }
        #expect(received == Data([0x01, 0x02, 0x03]))
        harness.pump.close()
    }

    @Test func bytesArrivingBeforeConsumerAttachesAreBuffered() async {
        let harness = PumpHarness()
        harness.write(Data([0xAA, 0xBB]))
        try? await Task.sleep(nanoseconds: 100_000_000) // let the pump read pre-attach
        var iterator = harness.pump.incomingStream().makeAsyncIterator()
        var received = Data()
        while received.count < 2, let chunk = await iterator.next() { received.append(chunk) }
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
        // 64-byte bound buffer forces partial writes; the pump must keep
        // draining on hasSpaceAvailable while the test consumes the far side.
        let harness = PumpHarness(buffer: 64)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let payload = Data((0..<10_000).map { UInt8($0 % 251) })
        try harness.pump.send(payload)
        let got = await harness.read(count: payload.count)
        #expect(got == payload)
        harness.pump.close()
    }

    @Test func farSideEOFFinishesIncoming() async {
        let harness = PumpHarness()
        var iterator = harness.pump.incomingStream().makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.feed.close()  // EOF on the pump's input
        var sawEnd = false
        for _ in 0..<200 {
            if await iterator.next() == nil { sawEnd = true; break }
        }
        #expect(sawEnd)
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
        var iterator = harness.pump.incomingStream().makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        harness.pump.close()
        harness.pump.close()  // second close is a no-op, no crash
        let next = await iterator.next()
        #expect(next == nil)
    }

    @Test func secondIncomingStreamIsAlreadyFinished() async {
        let harness = PumpHarness()
        _ = harness.pump.incomingStream()
        try? await Task.sleep(nanoseconds: 50_000_000)
        var second = harness.pump.incomingStream().makeAsyncIterator()
        let next = await second.next()
        #expect(next == nil)
        harness.pump.close()
    }
}
