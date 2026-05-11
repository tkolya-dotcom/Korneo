import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel
    @State private var showConnectionSettings = false

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Вход") {
                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("Пароль", text: $viewModel.password)

                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Войти")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }

                Section("Подключение") {
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(appState.connectionConfig.baseURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Button("Изменить настройки Supabase") {
                        showConnectionSettings = true
                    }
                }

                if let error = viewModel.errorText {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Korneo")
        }
        .onAppear {
            if viewModel.email.isEmpty {
                // Keep expected demo account hint only as placeholder.
                viewModel.email = ""
            }
        }
        .sheet(isPresented: $showConnectionSettings) {
            ConnectionSettingsView()
                .environmentObject(appState)
        }
    }
}
