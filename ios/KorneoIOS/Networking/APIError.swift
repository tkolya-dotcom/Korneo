import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case missingSupabaseKey
    case missingDaichiToken
    case requestFailed(status: Int, message: String)
    case decodingFailed
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .missingSupabaseKey:
            return "Supabase key is missing. Check SUPABASE_ANON_KEY."
        case .missingDaichiToken:
            return "Daichi token is missing. Configure DAICHI_TOKEN in Profile > Connection."
        case let .requestFailed(status, message):
            return "Request failed (\(status)): \(message)"
        case .decodingFailed:
            return "Failed to decode server response"
        case .missingSession:
            return "No active session"
        }
    }
}
