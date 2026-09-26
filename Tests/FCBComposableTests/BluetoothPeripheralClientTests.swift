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

extension BLETestStubLocal {
    static func central() -> CBCentral {
        let obj = unsafeBitCast(class_createInstance(CBCentral.self, 0)!, to: CBCentral.self)
        _ = Unmanaged.passRetained(obj)
        // Inject _identifier (declared in CBPeer) so .identifier returns a stable UUID
        if let ivar = class_getInstanceVariable(CBCentral.self, "_identifier") {
            object_setIvar(obj, ivar, UUID() as NSUUID)
        }
        return obj
    }
    static func characteristic() -> CBCharacteristic {
        let obj = unsafeBitCast(class_createInstance(CBCharacteristic.self, 0)!, to: CBCharacteristic.self)
        _ = Unmanaged.passRetained(obj)
        // Inject _UUID (declared in CBAttribute) so .uuid returns a valid CBUUID
        if let ivar = class_getInstanceVariable(CBCharacteristic.self, "_UUID") {
            object_setIvar(obj, ivar, CBUUID(string: "2A19"))
        }
        return obj
    }
    static func attRequest() -> CBATTRequest {
        let obj = unsafeBitCast(class_createInstance(CBATTRequest.self, 0)!, to: CBATTRequest.self)
        _ = Unmanaged.passRetained(obj)
        // Inject _central and _characteristic so accessing those properties doesn't crash
        if let ivar = class_getInstanceVariable(CBATTRequest.self, "_central") {
            object_setIvar(obj, ivar, central())
        }
        if let ivar = class_getInstanceVariable(CBATTRequest.self, "_characteristic") {
            object_setIvar(obj, ivar, characteristic())
        }
        return obj
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

    @Test func stateStreamReplaysCurrentStateOnSubscribe() async {
        // Late subscribers must receive the manager's current state immediately,
        // not hang waiting for a transition that already happened.
        let fake = FakePeripheralManager()
        fake.state = .poweredOn
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.stateStream()
        var iter = stream.makeAsyncIterator()
        // No simulateDidUpdateState here on purpose.
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

@MainActor
struct BluetoothPeripheralClientRequestsTests {
    @Test func readRequestsStreamYieldsRequests() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.readRequestsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cbReq = BLETestStubLocal.attRequest()
        fake.simulateDidReceiveRead(cbReq)
        let next = await iter.next()
        #expect(next != nil)
    }

    @Test func writeRequestsStreamYieldsBatches() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.writeRequestsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidReceiveWrite([BLETestStubLocal.attRequest(), BLETestStubLocal.attRequest()])
        let next = await iter.next()
        #expect(next?.count == 2)
    }

    @Test func respondLookupCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cbReq = BLETestStubLocal.attRequest()
        let id = UUID()
        await actor.injectRequestForTest(id: id, request: cbReq)
        await actor.respond(requestID: id, result: .success)
        #expect(fake.respondCalls.count == 1)
    }

    @Test func subscriptionStreamYieldsSubscribeEvent() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.subscriptionsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidSubscribe(central: BLETestStubLocal.central(), characteristic: BLETestStubLocal.characteristic())
        let event = await iter.next()
        if case .subscribed = event {
            // pass
        } else {
            Issue.record("expected .subscribed, got \(String(describing: event))")
        }
    }

    @Test func updateValueReturnsManagerResult() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)   // let wireDelegate run
        let svc = MutableService(id: CBUUID(string: "180F"), isPrimary: true, characteristics: [
            MutableCharacteristic(id: CBUUID(string: "2A19"), properties: .notify, permissions: .readable, value: nil)
        ])
        async let added = actor.add(service: svc)
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidAddService(fake.addedServices[0])
        _ = try await added

        fake.nextUpdateValueResult = true
        #expect(try await actor.updateValue(data: Data([1]), characteristicID: CBUUID(string: "2A19"), centralIDs: nil) == true)
        fake.nextUpdateValueResult = false
        #expect(try await actor.updateValue(data: Data([2]), characteristicID: CBUUID(string: "2A19"), centralIDs: nil) == false)
        #expect(fake.updateValueCalls.count == 2)
    }
}
