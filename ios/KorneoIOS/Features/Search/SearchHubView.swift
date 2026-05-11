import SwiftUI

struct SearchHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection = 0

    var body: some View {
        NavigationStack {
            if hasMapAccess {
                VStack {
                    Picker("Mode", selection: $selection) {
                        Text("Карта").tag(0)
                        Text("Каталог").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selection == 0 {
                        MapScreenView()
                    } else {
                        CatalogView()
                    }
                }
                .navigationTitle("Карта / Каталог")
            } else {
                CatalogView()
                    .navigationTitle("Каталог")
            }
        }
    }

    private var hasMapAccess: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role.hasMapAccess
    }
}
