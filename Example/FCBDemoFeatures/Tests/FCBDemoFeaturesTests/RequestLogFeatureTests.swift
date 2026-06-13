import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct RequestLogFeatureTests {
    private static let central = Central(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                                          maximumUpdateValueLength: 128)
    private static let serviceID = CBUUID(string: "180F")
    private static let charID = CBUUID(string: "2A19")
    private static func sampleChar() -> Characteristic {
        Characteristic(id: charID, serviceID: serviceID, peripheralID: UUID(),
                       properties: [.read], value: nil, isNotifying: false)
    }
    private static let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    @Test func readRequestArrivalAppends() async {
        let req = ReadRequest(id: Self.requestID, central: Self.central, characteristic: Self.sampleChar(), offset: 0)
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.readRequestReceived(req)) {
            $0.readRequests = [req]
        }
    }

    @Test func respondReadRemovesFromList() async {
        let req = ReadRequest(id: Self.requestID, central: Self.central, characteristic: Self.sampleChar(), offset: 0)
        let store = TestStore(
            initialState: RequestLogFeature.State(readRequests: [req])
        ) {
            RequestLogFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.respond = { _, _ in }
        }
        store.exhaustivity = .off
        await store.send(.respondReadTapped(requestID: Self.requestID, code: .success))
        await store.receive(\.respondedRead) {
            $0.readRequests = []
        }
    }

    @Test func writeBatchAppendsAll() async {
        let req1 = WriteRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                                 central: Self.central, characteristic: Self.sampleChar(), offset: 0, value: Data([0x01]))
        let req2 = WriteRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                                 central: Self.central, characteristic: Self.sampleChar(), offset: 0, value: Data([0x02]))
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.writeRequestsReceived([req1, req2])) {
            $0.writeRequests = [LoggedWriteRequest(id: req1.id, request: req1),
                                LoggedWriteRequest(id: req2.id, request: req2)]
        }
    }

    @Test func defaultCodeChange() async {
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.defaultCodeChanged(.readNotPermitted)) {
            $0.defaultResultCode = .readNotPermitted
        }
    }

    @Test func clearLogResetsAllSections() async {
        let req = ReadRequest(id: Self.requestID, central: Self.central, characteristic: Self.sampleChar(), offset: 0)
        let store = TestStore(
            initialState: RequestLogFeature.State(readRequests: [req])
        ) {
            RequestLogFeature()
        }
        await store.send(.clearLogTapped) {
            $0.readRequests = []
            $0.writeRequests = []
            $0.subscriptions = []
        }
    }
}
