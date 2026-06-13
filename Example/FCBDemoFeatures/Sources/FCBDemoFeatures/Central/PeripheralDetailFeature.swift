import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct PeripheralDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let peripheral: Peripheral
        public var id: UUID { peripheral.id }
        public var connectionState: ConnectionState
        public var services: IdentifiedArrayOf<ServiceRow>
        public var characteristics: [CBUUID: IdentifiedArrayOf<CharacteristicRow>]
        public var characteristicValues: [CBUUID: Data]
        public var notifyingCharacteristics: Set<CBUUID>
        public var connectError: String?
        public var operationError: String?
        public var pendingWriteText: [CBUUID: String]

        public init(
            peripheral: Peripheral,
            connectionState: ConnectionState = .disconnected,
            services: IdentifiedArrayOf<ServiceRow> = [],
            characteristics: [CBUUID: IdentifiedArrayOf<CharacteristicRow>] = [:],
            characteristicValues: [CBUUID: Data] = [:],
            notifyingCharacteristics: Set<CBUUID> = [],
            connectError: String? = nil,
            operationError: String? = nil,
            pendingWriteText: [CBUUID: String] = [:]
        ) {
            self.peripheral = peripheral
            self.connectionState = connectionState
            self.services = services
            self.characteristics = characteristics
            self.characteristicValues = characteristicValues
            self.notifyingCharacteristics = notifyingCharacteristics
            self.connectError = connectError
            self.operationError = operationError
            self.pendingWriteText = pendingWriteText
        }
    }

    public enum Action {
        case onAppear
        case connectTapped
        case disconnectTapped
        case connected(Peripheral)
        case connectFailed(BluetoothError)
        case disconnected
        case eventStreamEvent(CentralEvent)
        case discoverServicesTapped
        case servicesDiscovered([Service])
        case servicesDiscoveryFailed(BluetoothError)
        case discoverCharacteristicsTapped(serviceID: CBUUID)
        case characteristicsDiscovered(serviceID: CBUUID, [Characteristic])
        case readTapped(characteristicID: CBUUID)
        case valueRead(characteristicID: CBUUID, Data)
        case writeTextChanged(characteristicID: CBUUID, String)
        case writeTapped(characteristicID: CBUUID, withResponse: Bool)
        case writeCompleted(characteristicID: CBUUID)
        case toggleNotifyTapped(characteristicID: CBUUID)
        case notifyValueReceived(characteristicID: CBUUID, Data)
        case operationFailed(BluetoothError)
    }

    @Dependency(\.bluetoothCentralClient) var client

    enum CancelID: Hashable {
        case events(UUID)
        case notify(CBUUID)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let events = client.events
                return .run { send in
                    for await event in events() {
                        await send(.eventStreamEvent(event))
                    }
                }
                .cancellable(id: CancelID.events(state.peripheral.id), cancelInFlight: true)

            case .connectTapped:
                state.connectionState = .connecting
                state.connectError = nil
                let connect = client.connect
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let p = try await connect(pid, nil)
                        await send(.connected(p))
                    } catch let error as BluetoothError {
                        await send(.connectFailed(error))
                    } catch {
                        await send(.connectFailed(BluetoothError(error)))
                    }
                }

            case .disconnectTapped:
                let disconnect = client.disconnect
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        try await disconnect(pid)
                        await send(.disconnected)
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .connected(let p):
                state.connectionState = p.state
                return .none

            case .connectFailed(let err):
                state.connectionState = .disconnected
                state.connectError = "\(err)"
                return .none

            case .disconnected:
                state.connectionState = .disconnected
                state.services = []
                state.characteristics = [:]
                state.characteristicValues = [:]
                state.notifyingCharacteristics = []
                return .none

            case .eventStreamEvent(let event):
                if case .didDisconnect(let p, _) = event, p.id == state.peripheral.id {
                    state.connectionState = .disconnected
                    state.services = []
                    state.characteristics = [:]
                    state.characteristicValues = [:]
                    state.notifyingCharacteristics = []
                }
                return .none

            case .discoverServicesTapped:
                let discoverServices = client.discoverServices
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let services = try await discoverServices(pid, nil)
                        await send(.servicesDiscovered(services))
                    } catch let error as BluetoothError {
                        await send(.servicesDiscoveryFailed(error))
                    } catch {
                        await send(.servicesDiscoveryFailed(BluetoothError(error)))
                    }
                }

            case .servicesDiscovered(let services):
                state.services = IdentifiedArray(uniqueElements: services.map(ServiceRow.init))
                return .none

            case .servicesDiscoveryFailed(let err):
                state.operationError = "\(err)"
                return .none

            case .discoverCharacteristicsTapped(let serviceID):
                let discoverChars = client.discoverCharacteristics
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let chars = try await discoverChars(pid, serviceID, nil)
                        await send(.characteristicsDiscovered(serviceID: serviceID, chars))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .characteristicsDiscovered(let serviceID, let chars):
                state.characteristics[serviceID] = IdentifiedArray(uniqueElements: chars.map(CharacteristicRow.init))
                return .none

            case .readTapped(let cid):
                let readValue = client.readValue
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let data = try await readValue(pid, cid)
                        await send(.valueRead(characteristicID: cid, data))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .valueRead(let cid, let data):
                state.characteristicValues[cid] = data
                return .none

            case .writeTextChanged(let cid, let text):
                state.pendingWriteText[cid] = text
                return .none

            case .writeTapped(let cid, let withResponse):
                guard let data = HexCoding.decode(state.pendingWriteText[cid] ?? "") else {
                    state.operationError = "Invalid hex"
                    return .none
                }
                let writeValue = client.writeValue
                let pid = state.peripheral.id
                let type: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
                return .run { send in
                    do {
                        try await writeValue(data, pid, cid, type)
                        await send(.writeCompleted(characteristicID: cid))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .writeCompleted(let cid):
                state.pendingWriteText[cid] = ""
                return .none

            case .toggleNotifyTapped(let cid):
                let setNotify = client.setNotify
                let notifications = client.notifications
                let pid = state.peripheral.id
                let enabling = !state.notifyingCharacteristics.contains(cid)
                if enabling {
                    state.notifyingCharacteristics.insert(cid)
                } else {
                    state.notifyingCharacteristics.remove(cid)
                }
                return .run { send in
                    do {
                        try await setNotify(enabling, pid, cid)
                        if enabling {
                            for try await data in notifications(pid, cid) {
                                await send(.notifyValueReceived(characteristicID: cid, data))
                            }
                        }
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }
                .cancellable(id: CancelID.notify(cid), cancelInFlight: !enabling)

            case .notifyValueReceived(let cid, let data):
                state.characteristicValues[cid] = data
                return .none

            case .operationFailed(let err):
                state.operationError = "\(err)"
                return .none
            }
        }
    }
}

public struct ServiceRow: Equatable, Identifiable {
    public var id: CBUUID { service.id }
    public var service: Service
    public init(_ service: Service) { self.service = service }
}

public struct CharacteristicRow: Equatable, Identifiable {
    public var id: CBUUID { characteristic.id }
    public var characteristic: Characteristic
    public init(_ characteristic: Characteristic) { self.characteristic = characteristic }
}
