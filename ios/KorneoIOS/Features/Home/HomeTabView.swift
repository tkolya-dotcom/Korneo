import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tag(AppState.HomeTab.home)
                .tabItem {
                    Label("Главная", systemImage: "house")
                }

            TasksView()
                .tag(AppState.HomeTab.tasks)
                .tabItem {
                    Label("Задачи", systemImage: "checklist")
                }

            ChatsView()
                .tag(AppState.HomeTab.chats)
                .tabItem {
                    Label("Чаты", systemImage: "message")
                }

            SearchHubView()
                .tag(AppState.HomeTab.search)
                .tabItem {
                    Label("Карта", systemImage: "map")
                }

            MileageView()
                .tag(AppState.HomeTab.mileage)
                .tabItem {
                    Label("Пробег", systemImage: "speedometer")
                }

            ProfileView()
                .tag(AppState.HomeTab.profile)
                .tabItem {
                    Label("Профиль", systemImage: "person.crop.circle")
                }
        }
    }
}
