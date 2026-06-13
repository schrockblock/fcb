import ComposableArchitecture
import FCBDemoFeatures
import SwiftUI

@main
struct FCBDemoEntry: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
