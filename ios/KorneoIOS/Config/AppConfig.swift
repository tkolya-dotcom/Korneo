import Foundation

enum AppConfig {
    static var supabaseURL: String {
        let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        let value = (fromInfo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return "https://jmxjbdnqnzkzxgsfywha.supabase.co"
        }
        return value
    }

    static var supabaseAnonKey: String {
        let fromInfo = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        return (fromInfo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var daichiToken: String {
        let fromInfo = Bundle.main.object(forInfoDictionaryKey: "DAICHI_TOKEN") as? String
        return (fromInfo ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
