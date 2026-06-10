import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

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
