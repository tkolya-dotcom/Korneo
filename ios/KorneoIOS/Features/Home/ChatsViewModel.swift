import Foundation
import Combine

@MainActor
final class ChatsViewModel: ObservableObject {
    enum ChatCreateType {
        case `private`
        case group
    }

    @Published private(set) var chats: [Chat] = []
    @Published private(set) var privateChatNameById: [String: String] = [:]
    @Published private(set) var chatPreviewById: [String: String] = [:]
    @Published private(set) var chatTimestampById: [String: String] = [:]
    @Published private(set) var chatUnreadCountById: [String: Int] = [:]
    @Published private(set) var isLoading = false
    @Published var errorText: String?
    @Published var showingAllGroups = false

    private var client: SupabaseClient?

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load(currentUser: User?) async {
        guard let client else {
            errorText = "Client is not configured"
            return
        }
        guard let currentUser else {
            chats = []
            errorText = "User is not authenticated"
            return
        }
        if currentUser.role?.hasManagerRights != true {
            showingAllGroups = false
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            if showingAllGroups && currentUser.role?.hasManagerRights == true {
                chats = try await client.fetchAllGroupChats()
            } else {
                chats = try await client.fetchMyChats(userId: currentUser.id)
            }
            privateChatNameById = try await resolvePrivateChatNames(chats: chats, currentUserId: currentUser.id)
            await loadChatPreviews(for: chats, currentUserId: currentUser.id)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func createChat(
        currentUser: User?,
        name: String,
        type: ChatCreateType,
        memberIds: [String]
    ) async -> Bool {
        guard let client else {
            errorText = "Client is not configured"
            return false
        }
        guard let currentUser else {
            errorText = "User is not authenticated"
            return false
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedMembers = memberIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        if type == .private {
            if selectedMembers.count != 1 {
                errorText = "Select one user for private chat"
                return false
            }
        } else {
            if selectedMembers.count < 2 {
                errorText = "Select at least two users for group chat"
                return false
            }
        }

        do {
            let chatType = type == .private ? "private" : "group"
            let chatName = type == .private
                ? (trimmedName.isEmpty ? "Private chat" : trimmedName)
                : (trimmedName.isEmpty ? "Group chat" : trimmedName)
            _ = try await client.createChatWithMembers(
                name: chatName,
                type: chatType,
                createdBy: currentUser.id,
                memberIds: selectedMembers
            )
            await load(currentUser: currentUser)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func togglePin(chat: Chat, currentUser: User?) async -> Bool {
        guard let client else {
            errorText = "Client is not configured"
            return false
        }
        guard let currentUser else {
            errorText = "User is not authenticated"
            return false
        }
        do {
            let nextPinned = !(chat.pinned ?? false)
            try await client.setChatPinned(chatId: chat.id, userId: currentUser.id, pinned: nextPinned)
            await load(currentUser: currentUser)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func removeForCurrentUser(chat: Chat, currentUser: User?) async -> Bool {
        guard let client else {
            errorText = "Client is not configured"
            return false
        }
        guard let currentUser else {
            errorText = "User is not authenticated"
            return false
        }
        do {
            try await client.removeChatForCurrentUser(chatId: chat.id, userId: currentUser.id)
            chats.removeAll { $0.id == chat.id }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func deletePermanently(chat: Chat, currentUser: User?) async -> Bool {
        guard let client else {
            errorText = "Client is not configured"
            return false
        }
        guard let currentUser else {
            errorText = "User is not authenticated"
            return false
        }
        do {
            try await client.deleteChatPermanently(chatId: chat.id)
            chats.removeAll { $0.id == chat.id }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func addMembers(chatId: String, userIds: [String], currentUser: User?) async -> Bool {
        guard let client else {
            errorText = "Client is not configured"
            return false
        }
        guard let currentUser else {
            errorText = "User is not authenticated"
            return false
        }
        do {
            try await client.addChatMembers(chatId: chatId, userIds: userIds)
            await load(currentUser: currentUser)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func loadChatPreviews(for chats: [Chat], currentUserId: String) async {
        guard let client else { return }
        var previewById: [String: String] = [:]
        var timestampById: [String: String] = [:]
        var unreadById: [String: Int] = [:]

        for chat in chats {
            let chatId = chat.id
            let isPrivate = (chat.type ?? "").lowercased() == "private"
            do {
                if let latest = try await client.fetchLatestMessage(chatId: chatId) {
                    let text = latest.contentText.trimmingCharacters(in: .whitespacesAndNewlines)
                    previewById[chatId] = isPrivate ? "" : (text.isEmpty ? "No messages" : text)
                    timestampById[chatId] = latest.createdAt ?? ""
                    let isOwn = latest.userId?.trimmingCharacters(in: .whitespacesAndNewlines) == currentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                    let unread = (!isOwn && (latest.isRead == false)) ? 1 : 0
                    unreadById[chatId] = unread
                } else {
                    previewById[chatId] = isPrivate ? "" : "No messages"
                    timestampById[chatId] = ""
                    unreadById[chatId] = 0
                }
            } catch {
                previewById[chatId] = ""
                timestampById[chatId] = ""
                unreadById[chatId] = 0
            }
        }

        chatPreviewById = previewById
        chatTimestampById = timestampById
        chatUnreadCountById = unreadById
    }

    private func resolvePrivateChatNames(chats: [Chat], currentUserId: String) async throws -> [String: String] {
        guard let client else { return [:] }
        let privateIds = chats
            .filter { ($0.type ?? "").lowercased() == "private" }
            .map(\.id)
        if privateIds.isEmpty { return [:] }
        return try await client.fetchPrivateChatPeerNames(chatIds: privateIds, currentUserId: currentUserId)
    }
}
