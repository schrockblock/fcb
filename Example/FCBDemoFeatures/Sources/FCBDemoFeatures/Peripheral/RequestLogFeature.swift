import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

public struct LoggedWriteRequest: Equatable, Identifiable {
    public var id: UUID
    public var request: WriteRequest

    public init(id: UUID, request: WriteRequest) {
        self.id = id
        self.request = request
    }
}

public struct LoggedSubscription: Equatable, Identifiable {
    public var id: UUID
    public var event: SubscriptionEvent
    public var receivedAt: Date

    public init(id: UUID = UUID(), event: SubscriptionEvent, receivedAt: Date = Date()) {
        self.id = id
        self.event = event
        self.receivedAt = receivedAt
    }
}

@Reducer
public struct RequestLogFeature {
    @ObservableState
    public struct State: Equatable {
        public var readRequests: IdentifiedArrayOf<ReadRequest>
        public var writeRequests: IdentifiedArrayOf<LoggedWriteRequest>
        public var subscriptions: [LoggedSubscription]
        public var defaultResultCode: CBATTError.Code

        public init(
            readRequests: IdentifiedArrayOf<ReadRequest> = [],
            writeRequests: IdentifiedArrayOf<LoggedWriteRequest> = [],
            subscriptions: [LoggedSubscription] = [],
            defaultResultCode: CBATTError.Code = .success
        ) {
            self.readRequests = readRequests
            self.writeRequests = writeRequests
            self.subscriptions = subscriptions
            self.defaultResultCode = defaultResultCode
        }
    }

    public enum Action {
        case onAppear
        case readRequestReceived(ReadRequest)
        case writeRequestsReceived([WriteRequest])
        case subscriptionEvent(SubscriptionEvent)
        case respondReadTapped(requestID: UUID, code: CBATTError.Code)
        case respondWriteTapped(requestID: UUID, code: CBATTError.Code)
        case respondedRead(requestID: UUID)
        case respondedWrite(requestID: UUID)
        case defaultCodeChanged(CBATTError.Code)
        case clearLogTapped
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    enum CancelID: Hashable { case reads, writes, subs }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let readRequests = client.readRequests
                let writeRequests = client.writeRequests
                let subscriptions = client.subscriptions
                return .merge(
                    .run { send in
                        for await req in readRequests() {
                            await send(.readRequestReceived(req))
                        }
                    }.cancellable(id: CancelID.reads, cancelInFlight: true),
                    .run { send in
                        for await batch in writeRequests() {
                            await send(.writeRequestsReceived(batch))
                        }
                    }.cancellable(id: CancelID.writes, cancelInFlight: true),
                    .run { send in
                        for await ev in subscriptions() {
                            await send(.subscriptionEvent(ev))
                        }
                    }.cancellable(id: CancelID.subs, cancelInFlight: true)
                )

            case .readRequestReceived(let req):
                state.readRequests[id: req.id] = req
                return .none

            case .writeRequestsReceived(let batch):
                for req in batch {
                    state.writeRequests[id: req.id] = LoggedWriteRequest(id: req.id, request: req)
                }
                return .none

            case .subscriptionEvent(let ev):
                state.subscriptions.insert(LoggedSubscription(event: ev), at: 0)
                if state.subscriptions.count > 10 {
                    state.subscriptions.removeLast(state.subscriptions.count - 10)
                }
                return .none

            case .respondReadTapped(let id, let code):
                let respond = client.respond
                return .run { send in
                    await respond(id, code)
                    await send(.respondedRead(requestID: id))
                }

            case .respondWriteTapped(let id, let code):
                let respond = client.respond
                return .run { send in
                    await respond(id, code)
                    await send(.respondedWrite(requestID: id))
                }

            case .respondedRead(let id):
                state.readRequests.remove(id: id)
                return .none

            case .respondedWrite(let id):
                state.writeRequests.remove(id: id)
                return .none

            case .defaultCodeChanged(let code):
                state.defaultResultCode = code
                return .none

            case .clearLogTapped:
                state.readRequests.removeAll()
                state.writeRequests.removeAll()
                state.subscriptions.removeAll()
                return .none
            }
        }
    }
}
