@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct CentralWriteWithoutResponseReadinessTests {
        @Test func canSendWriteWithoutResponseReflectsThePeripheral() async throws {
            let setup = await makeMockRadio()
            let client = BluetoothCentralClient.makeClient(actor: setup.actor)
            _ = try await client.connect(setup.id, ConnectOptions?.none)

            // A fresh CBM connection has an empty write-without-response queue.
            #expect(await client.canSendWriteWithoutResponse(setup.id) == true)
            #expect(await client.canSendWriteWithoutResponse(UUID()) == false)
        }

        @Test func readyToSendEventIsForwarded() async throws {
            let setup = await makeMockRadio()
            let client = BluetoothCentralClient.makeClient(actor: setup.actor)
            try await connectAndDiscover(setup)
            let events = client.events()

            let ready = Task {
                await outcome(within: 2) { () -> UUID? in
                    for await event in events {
                        if case .isReadyToSendWriteWithoutResponse(let peripheral) = event {
                            return peripheral.id
                        }
                    }
                    return nil
                }
            }
            // Let the event stream register with the actor.
            try? await Task.sleep(nanoseconds: 50_000_000)
            // CBM consumes a write-without-response buffer slot, then frees it
            // and calls peripheralIsReady(toSendWriteWithoutResponse:).
            try await client.writeValue(Data([0x01]), setup.id, cbmBatteryLevelUUID, CBCharacteristicWriteType.withoutResponse)

            let result = try #require(await ready.value, "no isReadyToSendWriteWithoutResponse event within 2 s")
            #expect(try result.get() == setup.id)
        }
    }
}
