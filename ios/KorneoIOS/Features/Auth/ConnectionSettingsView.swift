import SwiftUI

struct ConnectionSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var url = ""
    @State private var anonKey = ""
    @State private var daichiToken = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Supabase") {
                    TextField("URL Supabase", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Anon / publishable ключ", text: $anonKey)
                        .textInputAutocapitalization(.never)
                }

                Section("Daichi") {
                    SecureField("Токен Daichi", text: $daichiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Подключение")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        appState.updateConnection(url: url, anonKey: anonKey, daichiToken: daichiToken)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            let cfg = appState.connectionConfig
            if url.isEmpty { url = cfg.baseURL }
            if anonKey.isEmpty { anonKey = cfg.anonKey }
            if daichiToken.isEmpty { daichiToken = cfg.daichiToken }
        }
    }
}
