import ComposableArchitecture
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct AppFeatureTests {
    @Test func tabSwitch() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.tabChanged(.peripheral)) { $0.tab = .peripheral }
        await store.send(.tabChanged(.central)) { $0.tab = .central }
    }
}
