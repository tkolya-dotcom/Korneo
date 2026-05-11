import Foundation

struct SupabaseRuntimeConfig {
    var baseURL: String
    var anonKey: String
    var daichiToken: String
}

final class SupabaseRuntimeConfigStore {
    private let userDefaults: UserDefaults
    private let keychain: KeychainStore

    private let urlKey = "korneo.supabase.url"
    private let anonKeyKey = "korneo.supabase.anon_key"
    private let daichiTokenKey = "korneo.daichi.token"

    init(userDefaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.userDefaults = userDefaults
        self.keychain = keychain
    }

    func load() -> SupabaseRuntimeConfig {
        let storedURL = (userDefaults.string(forKey: urlKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let storedKey = keychain.loadText(forKey: anonKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let storedDaichiToken = keychain.loadText(forKey: daichiTokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return SupabaseRuntimeConfig(
            baseURL: storedURL.isEmpty ? AppConfig.supabaseURL : storedURL,
            anonKey: storedKey.isEmpty ? AppConfig.supabaseAnonKey : storedKey,
            daichiToken: storedDaichiToken.isEmpty ? AppConfig.daichiToken : storedDaichiToken
        )
    }

    func save(url: String, anonKey: String, daichiToken: String?) {
        userDefaults.set(url.trimmingCharacters(in: .whitespacesAndNewlines), forKey: urlKey)
        keychain.saveText(anonKey.trimmingCharacters(in: .whitespacesAndNewlines), forKey: anonKeyKey)
        if let daichiToken {
            keychain.saveText(daichiToken.trimmingCharacters(in: .whitespacesAndNewlines), forKey: daichiTokenKey)
        }
    }

    func saveDaichiToken(_ token: String) {
        keychain.saveText(token.trimmingCharacters(in: .whitespacesAndNewlines), forKey: daichiTokenKey)
    }
}
