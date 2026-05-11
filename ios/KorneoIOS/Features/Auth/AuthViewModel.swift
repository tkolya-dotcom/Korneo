import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorText: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func signIn() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorText = "Введите email и пароль"
            return
        }

        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            try await appState.signIn(email: email, password: password)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
