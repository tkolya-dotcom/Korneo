import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let expiresAt: Int?
    let refreshToken: String?
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

struct SessionTokens: Codable {
    let accessToken: String
    let refreshToken: String?
}
