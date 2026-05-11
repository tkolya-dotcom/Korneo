import Foundation
import Combine

@MainActor
final class UsersViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private var client: SupabaseClient?

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load() async {
        guard let client else {
            errorText = "Клиент не настроен"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            users = try await client.fetchUsers()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
