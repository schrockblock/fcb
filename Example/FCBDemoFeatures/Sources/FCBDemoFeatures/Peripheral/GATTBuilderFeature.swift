import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

public struct DraftService: Equatable, Identifiable {
    public var id: CBUUID
    public var isPrimary: Bool
    public var characteristics: IdentifiedArrayOf<DraftCharacteristic>

    public init(id: CBUUID, isPrimary: Bool, characteristics: IdentifiedArrayOf<DraftCharacteristic>) {
        self.id = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}

public struct DraftCharacteristic: Equatable, Identifiable {
    public var id: CBUUID
    public var properties: CBCharacteristicProperties
    public var permissions: CBAttributePermissions
    public var initialValueText: String

    public init(id: CBUUID, properties: CBCharacteristicProperties, permissions: CBAttributePermissions, initialValueText: String) {
        self.id = id
        self.properties = properties
        self.permissions = permissions
        self.initialValueText = initialValueText
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.properties.rawValue == rhs.properties.rawValue
            && lhs.permissions.rawValue == rhs.permissions.rawValue
            && lhs.initialValueText == rhs.initialValueText
    }
}

@Reducer
public struct GATTBuilderFeature {
    @ObservableState
    public struct State: Equatable {
        public var services: IdentifiedArrayOf<DraftService>
        public var publishedServiceIDs: Set<CBUUID>
        public var newServiceUUIDInput: String
        public var publishError: String?

        public init(
            services: IdentifiedArrayOf<DraftService> = [],
            publishedServiceIDs: Set<CBUUID> = [],
            newServiceUUIDInput: String = "",
            publishError: String? = nil
        ) {
            self.services = services
            self.publishedServiceIDs = publishedServiceIDs
            self.newServiceUUIDInput = newServiceUUIDInput
            self.publishError = publishError
        }
    }

    public enum Action {
        case newServiceUUIDChanged(String)
        case addServiceTapped
        case isPrimaryToggled(serviceID: CBUUID, Bool)
        case removeServiceTapped(serviceID: CBUUID)
        case addCharacteristicTapped(serviceID: CBUUID)
        case characteristicUUIDChanged(serviceID: CBUUID, characteristicID: CBUUID, String)
        case togglePropertyTapped(serviceID: CBUUID, characteristicID: CBUUID, CBCharacteristicProperties)
        case togglePermissionTapped(serviceID: CBUUID, characteristicID: CBUUID, CBAttributePermissions)
        case initialValueChanged(serviceID: CBUUID, characteristicID: CBUUID, String)
        case removeCharacteristicTapped(serviceID: CBUUID, characteristicID: CBUUID)
        case publishServiceTapped(serviceID: CBUUID)
        case servicePublished(CBUUID)
        case publishFailed(BluetoothError)
        case removeAllPublishedTapped
        case removeAllPublishedCompleted
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .newServiceUUIDChanged(let text):
                state.newServiceUUIDInput = text
                return .none

            case .addServiceTapped:
                guard let uuid = CBUUIDParsing.parse(state.newServiceUUIDInput) else {
                    state.publishError = "Invalid UUID"
                    return .none
                }
                state.services.append(DraftService(id: uuid, isPrimary: true, characteristics: []))
                state.newServiceUUIDInput = ""
                state.publishError = nil
                return .none

            case .isPrimaryToggled(let sid, let value):
                state.services[id: sid]?.isPrimary = value
                return .none

            case .removeServiceTapped(let sid):
                let wasPublished = state.publishedServiceIDs.contains(sid)
                state.services.remove(id: sid)
                state.publishedServiceIDs.remove(sid)
                if wasPublished {
                    let remove = client.remove
                    return .run { _ in await remove(sid) }
                }
                return .none

            case .addCharacteristicTapped(let sid):
                let new = DraftCharacteristic(
                    id: CBUUID(nsuuid: UUID()),
                    properties: [.read],
                    permissions: [.readable],
                    initialValueText: ""
                )
                state.services[id: sid]?.characteristics.append(new)
                return .none

            case .characteristicUUIDChanged(let sid, let cid, let text):
                if let newID = CBUUIDParsing.parse(text),
                   var char = state.services[id: sid]?.characteristics[id: cid] {
                    state.services[id: sid]?.characteristics.remove(id: cid)
                    char.id = newID
                    state.services[id: sid]?.characteristics.append(char)
                }
                return .none

            case .togglePropertyTapped(let sid, let cid, let prop):
                if var char = state.services[id: sid]?.characteristics[id: cid] {
                    if char.properties.contains(prop) {
                        char.properties.remove(prop)
                    } else {
                        char.properties.insert(prop)
                    }
                    state.services[id: sid]?.characteristics[id: cid] = char
                }
                return .none

            case .togglePermissionTapped(let sid, let cid, let perm):
                if var char = state.services[id: sid]?.characteristics[id: cid] {
                    if char.permissions.contains(perm) {
                        char.permissions.remove(perm)
                    } else {
                        char.permissions.insert(perm)
                    }
                    state.services[id: sid]?.characteristics[id: cid] = char
                }
                return .none

            case .initialValueChanged(let sid, let cid, let text):
                state.services[id: sid]?.characteristics[id: cid]?.initialValueText = text
                return .none

            case .removeCharacteristicTapped(let sid, let cid):
                state.services[id: sid]?.characteristics.remove(id: cid)
                return .none

            case .publishServiceTapped(let sid):
                guard let draft = state.services[id: sid] else { return .none }
                let mutable = MutableService(
                    id: draft.id,
                    isPrimary: draft.isPrimary,
                    characteristics: draft.characteristics.map { c in
                        MutableCharacteristic(
                            id: c.id,
                            properties: c.properties,
                            permissions: c.permissions,
                            value: HexCoding.decode(c.initialValueText) ?? Data()
                        )
                    }
                )
                state.publishError = nil
                let add = client.add
                return .run { send in
                    do {
                        _ = try await add(mutable)
                        await send(.servicePublished(sid))
                    } catch let error as BluetoothError {
                        await send(.publishFailed(error))
                    } catch {
                        await send(.publishFailed(BluetoothError(error)))
                    }
                }

            case .servicePublished(let sid):
                state.publishedServiceIDs.insert(sid)
                return .none

            case .publishFailed(let err):
                state.publishError = errorDescription(err)
                return .none

            case .removeAllPublishedTapped:
                let removeAll = client.removeAll
                return .run { send in
                    await removeAll()
                    await send(.removeAllPublishedCompleted)
                }

            case .removeAllPublishedCompleted:
                state.publishedServiceIDs = []
                return .none
            }
        }
    }

    private func errorDescription(_ err: BluetoothError) -> String {
        switch err {
        case .poweredOff: return "poweredOff"
        case .unsupported: return "unsupported"
        case .operationCancelled: return "operationCancelled"
        default: return "\(err)"
        }
    }
}
