import ComposableArchitecture
import FCBComposable
import Foundation

extension DependencyValues {
    /// Sets both BLE clients to `previewValue`. Use in SwiftUI `#Preview` blocks:
    /// `withDependencies { $0.previewBluetooth() } operation: { … }`.
    public mutating func previewBluetooth() {
        bluetoothCentralClient = .previewValue
        bluetoothPeripheralClient = .previewValue
    }
}
