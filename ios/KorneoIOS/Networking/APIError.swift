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
            return "Некорректный URL"
        case .missingSupabaseKey:
            return "Отсутствует ключ Supabase. Проверьте SUPABASE_ANON_KEY."
        case .missingDaichiToken:
            return "Отсутствует токен Daichi. Укажите DAICHI_TOKEN в Профиль -> Подключение."
        case let .requestFailed(status, message):
            return "Ошибка запроса (\(status)): \(message)"
        case .decodingFailed:
            return "Не удалось разобрать ответ сервера"
        case .missingSession:
            return "Нет активной сессии"
        }
    }
}
