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
                    TextField("Supabase URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    SecureField("Anon / publishable key", text: $anonKey)
                        .textInputAutocapitalization(.never)
                }

                Section("Daichi") {
                    SecureField("Daichi token", text: $daichiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
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
