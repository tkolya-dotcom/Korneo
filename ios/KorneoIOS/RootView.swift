import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
            case .auth:
                AuthView(appState: appState)
            case .home:
                HomeTabView()
            }
        }
        .task {
            await appState.bootstrapCurrentUser()
        }
    }
}
