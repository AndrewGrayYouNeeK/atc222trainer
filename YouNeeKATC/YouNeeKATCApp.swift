import SwiftUI

@main
struct YouNeeKATCApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .preferredColorScheme(.dark)
                .task { env.bootstrap() }
        }
    }
}
