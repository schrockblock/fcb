import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation
import ObjectiveC.runtime
import Testing
@testable import FCBComposable

private enum BLETestStubLocal {
    static func peripheralManager() -> CBPeripheralManager {
        CBPeripheralManager(delegate: nil, queue: nil)
    }
    static func service() -> CBMutableService {
        CBMutableService(type: CBUUID(string: "180F"), primary: true)
    }
}

@MainActor
struct BluetoothPeripheralClientContractTests {
    @Test func testValueRespondIsCallable() async {
        let client = BluetoothPeripheralClient.testValue
        // respond is non-throwing in the witness; calling it on testValue with the @DependencyClient
        // macro will invoke the macro-generated unimplemented body and record an Issue (Swift Testing)
        // rather than throw. Use withKnownIssue to suppress the recorded issue.
        await withKnownIssue {
            await client.respond(UUID(), .success)
        }
    }
}

@MainActor
struct BluetoothPeripheralClientServicesTests {
    @Test func stateStreamYieldsStateUpdates() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.stateStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidUpdateState(.poweredOn)
        let next = await iter.next()
        #expect(next == .poweredOn)
    }

    @Test func addServiceResolvesWhenDelegateFires() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let mutable = MutableService(id: CBUUID(string: "180F"), isPrimary: true, characteristics: [])

        let task = Task { try await actor.add(service: mutable) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.addedServices.count == 1)

        let cbService = fake.addedServices[0]
        fake.simulateDidAddService(cbService, error: nil)
        let result = try await task.value
        #expect(result.id == CBUUID(string: "180F"))
    }

    @Test func removeServiceCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cbService = BLETestStubLocal.service()
        await actor.injectServiceForTest(id: CBUUID(string: "180F"), service: cbService)

        await actor.remove(serviceID: CBUUID(string: "180F"))
        #expect(fake.removedServices.count == 1)
    }

    @Test func removeAllCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.removeAll()
        #expect(fake.removeAllCount == 1)
    }
}

@MainActor
struct BluetoothPeripheralClientAdvertisingTests {
    @Test func startAdvertisingResolvesWhenDelegateFires() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ad = AdvertisementData(localName: "Me")

        let task = Task { try await actor.startAdvertising(data: ad) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.startAdvertisingCalls.count == 1)

        fake.simulateDidStartAdvertising(error: nil)
        try await task.value
    }

    @Test func stopAdvertisingCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.stopAdvertising()
        #expect(fake.stopAdvertisingCount == 1)
    }

    @Test func isAdvertisingReflectsManagerState() async {
        let fake = FakePeripheralManager()
        fake.isAdvertising = true
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let advertising = await actor.isAdvertising()
        #expect(advertising == true)
    }
}
