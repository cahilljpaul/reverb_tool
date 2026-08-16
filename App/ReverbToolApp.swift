import SwiftUI

@main
struct ReverbToolApp: App {
    @StateObject private var viewModel = MonitorViewModel()

    var body: some Scene {
        WindowGroup {
            MonitorView(viewModel: viewModel)
        }
    }
}
