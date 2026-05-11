import SwiftUI

struct SearchHubView: View {
    private enum SearchMode: Int {
        case map = 0
        case catalog = 1
    }

    @EnvironmentObject private var appState: AppState
    @State private var selection: SearchMode = .map

    var body: some View {
        NavigationStack {
            if hasMapAccess {
                VStack {
                    Picker("Режим", selection: $selection) {
                        Text("Карта").tag(SearchMode.map)
                        Text("Каталог").tag(SearchMode.catalog)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selection == .map {
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
