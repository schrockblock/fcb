import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

@MainActor
struct BluetoothCentralClientContractTests {
    @Test func testValueDisconnectThrowsUnimplemented() async {
        let client = BluetoothCentralClient.testValue
        await withKnownIssue("disconnect should report unimplemented") {
            _ = try await client.disconnect(UUID())
        }
    }
}
