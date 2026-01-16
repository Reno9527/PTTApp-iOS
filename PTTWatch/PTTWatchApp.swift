import SwiftUI

@main
struct PTTWatchApp: App {
    @StateObject private var viewModel = WatchPTTViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
