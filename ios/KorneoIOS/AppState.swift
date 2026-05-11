import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    enum Route {
        case auth
        case home
    }

    enum HomeTab: Hashable {
        case home
        case chats
        case search
        case mileage
        case profile
    }

    struct ChatDeepLink: Equatable {
        let chatId: String
        let chatName: String?
    }

    @Published private(set) var route: Route = .auth
    @Published private(set) var currentUser: User?
    @Published var selectedTab: HomeTab = .home
    @Published private(set) var pendingChatDeepLink: ChatDeepLink?

    let client: SupabaseClient
    private let pushManager: PushNotificationManager
    private var cancellables = Set<AnyCancellable>()

    init(client: SupabaseClient = SupabaseClient(), pushManager: PushNotificationManager? = nil) {
        self.client = client
        self.pushManager = pushManager ?? PushNotificationManager()

        NotificationCenter.default.publisher(for: .pushDeviceTokenDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self, let token = note.object as? String else { return }
                self.pushManager.saveDeviceToken(token)
                Task { await self.syncPushTokenIfPossible() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .pushOpenChatRequested)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                let chatIdFromUserInfo = note.userInfo?["chat_id"] as? String
                let chatNameRaw = note.userInfo?["chat_name"] as? String
                let chatName = chatNameRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
                let chatIdFromObject = note.object as? String
                guard let chatId = (chatIdFromUserInfo ?? chatIdFromObject)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !chatId.isEmpty else {
                    return
                }
                self.handlePushOpenChat(chatId: chatId, chatName: (chatName?.isEmpty == false ? chatName : nil))
            }
            .store(in: &cancellables)

        if client.hasActiveSession {
            route = .home
        }
    }

    func signIn(email: String, password: String) async throws {
        let auth = try await client.login(email: email, password: password)
        currentUser = try await client.loadOrCreateUserProfile(from: auth)
        route = .home
        await requestPushPermissionIfNeeded()
        await syncPushTokenIfPossible()
    }

    func bootstrapCurrentUser() async {
        guard route == .home else { return }
        do {
            currentUser = try await client.fetchCurrentUserProfile()
            await requestPushPermissionIfNeeded()
            await syncPushTokenIfPossible()
        } catch {
            client.clearSession()
            route = .auth
        }
    }

    func signOut() {
        client.clearSession()
        currentUser = nil
        route = .auth
        selectedTab = .home
        pendingChatDeepLink = nil
    }

    var connectionConfig: SupabaseRuntimeConfig {
        client.runtimeConfig
    }

    func updateConnection(url: String, anonKey: String, daichiToken: String) {
        func normalizeURL(_ raw: String) -> String {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            while value.hasSuffix("/") {
                value.removeLast()
            }
            return value
        }

        let current = client.runtimeConfig
        let cleanCurrentURL = normalizeURL(current.baseURL)
        let cleanCurrentKey = current.anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNewURL = normalizeURL(url)
        let cleanNewKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let supabaseChanged = cleanCurrentURL != cleanNewURL || cleanCurrentKey != cleanNewKey
        if supabaseChanged {
            client.updateConnection(url: url, anonKey: anonKey, daichiToken: daichiToken)
            currentUser = nil
            route = .auth
            return
        }

        client.updateDaichiToken(daichiToken)
    }

    func requestPushPermissionIfNeeded() async {
        await pushManager.requestAuthorizationAndRegister()
    }

    func syncPushTokenIfPossible() async {
        guard let userId = currentUser?.id else { return }
        guard let token = pushManager.cachedDeviceToken, !token.isEmpty else { return }
        do {
            try await client.registerPushToken(userId: userId, token: token)
        } catch {
            #if DEBUG
            print("Push token sync failed: \(error.localizedDescription)")
            #endif
        }
    }

    func consumePendingChatDeepLink() {
        pendingChatDeepLink = nil
    }

    private func handlePushOpenChat(chatId: String, chatName: String?) {
        pendingChatDeepLink = ChatDeepLink(chatId: chatId, chatName: chatName)
        selectedTab = .chats
    }
}
