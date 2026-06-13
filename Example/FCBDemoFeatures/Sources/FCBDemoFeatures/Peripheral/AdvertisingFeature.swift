import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct AdvertisingFeature {
    @ObservableState
    public struct State: Equatable {
        public var isAdvertising: Bool
        public var localName: String
        public var includedServiceUUIDsText: String
        public var lastError: String?

        public init(
            isAdvertising: Bool = false,
            localName: String = "",
            includedServiceUUIDsText: String = "",
            lastError: String? = nil
        ) {
            self.isAdvertising = isAdvertising
            self.localName = localName
            self.includedServiceUUIDsText = includedServiceUUIDsText
            self.lastError = lastError
        }
    }

    public enum Action {
        case localNameChanged(String)
        case includedUUIDsChanged(String)
        case startAdvertisingTapped
        case stopAdvertisingTapped
        case advertisingStarted
        case advertisingFailed(BluetoothError)
        case stopAdvertisingCompleted
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .localNameChanged(let s):
                state.localName = s
                return .none

            case .includedUUIDsChanged(let s):
                state.includedServiceUUIDsText = s
                return .none

            case .startAdvertisingTapped:
                let ad = AdvertisementData(
                    localName: state.localName.isEmpty ? nil : state.localName,
                    serviceUUIDs: CBUUIDParsing.parseList(state.includedServiceUUIDsText)
                )
                state.lastError = nil
                let startAdvertising = client.startAdvertising
                return .run { send in
                    do {
                        try await startAdvertising(ad)
                        await send(.advertisingStarted)
                    } catch let error as BluetoothError {
                        await send(.advertisingFailed(error))
                    } catch {
                        await send(.advertisingFailed(BluetoothError(error)))
                    }
                }

            case .stopAdvertisingTapped:
                let stopAdvertising = client.stopAdvertising
                return .run { send in
                    await stopAdvertising()
                    await send(.stopAdvertisingCompleted)
                }

            case .advertisingStarted:
                state.isAdvertising = true
                return .none

            case .advertisingFailed(let err):
                state.lastError = description(of: err)
                return .none

            case .stopAdvertisingCompleted:
                state.isAdvertising = false
                return .none
            }
        }
    }

    private func description(of err: BluetoothError) -> String {
        switch err {
        case .poweredOff: return "poweredOff"
        case .unsupported: return "unsupported"
        case .operationCancelled: return "operationCancelled"
        default: return "\(err)"
        }
    }
}
