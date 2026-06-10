public enum SubscriptionEvent: Sendable, Hashable {
    case subscribed(central: Central, characteristic: Characteristic)
    case unsubscribed(central: Central, characteristic: Characteristic)
}
