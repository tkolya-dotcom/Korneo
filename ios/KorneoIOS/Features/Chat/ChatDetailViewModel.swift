import Foundation
import Combine

@MainActor
final class ChatDetailViewModel: ObservableObject {
    private let maxAttachmentBytes = 250 * 1024 * 1024
    @Published private(set) var messages: [Message] = []
    @Published private(set) var typingUsersText: String = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingForwardTargets = false
    @Published private(set) var forwardTargets: [Chat] = []
    @Published var errorText: String?
    @Published var draftMessage = ""
    @Published var replyTarget: Message?

    private var client: SupabaseClient?
    private let chatId: String
    private let userId: String
    private var pollingTask: Task<Void, Never>?
    private var typingStopTask: Task<Void, Never>?
    private var isTyping = false

    init(chatId: String, userId: String) {
        self.chatId = chatId
        self.userId = userId
    }

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load() async {
        guard let client else {
            errorText = "Клиент Supabase не настроен"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let rows = try await client.fetchMessages(chatId: chatId)
            messages = visibleMessages(rows)
            try? await client.markMessagesRead(chatId: chatId, currentUserId: userId)
            await refreshTypingStatuses()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func send() async {
        let text = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let client else { return }
        guard !userId.isEmpty else {
            errorText = "ID текущего пользователя пуст"
            return
        }

        do {
            let message: Message
            if let replyTarget {
                let payload: [String: JSONValue] = [
                    "text": .string(text),
                    "reply_to_message_id": .string(replyTarget.id),
                    "reply_text": .string(trimForReplyPreview(replyTarget.contentText))
                ]
                message = try await client.sendMessageContent(
                    chatId: chatId,
                    userId: userId,
                    content: .object(payload),
                    type: "text"
                )
            } else {
                message = try await client.sendMessage(chatId: chatId, userId: userId, text: text)
            }

            messages.append(message)
            draftMessage = ""
            clearReply()
            await setTyping(false)
            try? await client.markMessagesRead(chatId: chatId, currentUserId: userId)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func setReplyTarget(_ message: Message) {
        replyTarget = message
    }

    func clearReply() {
        replyTarget = nil
    }

    func addReaction(message: Message, emoji: String) async {
        guard let client else { return }
        let cleanEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmoji.isEmpty else { return }

        var contentObject = message.contentObject ?? [:]
        if contentObject["text"] == nil {
            contentObject["text"] = .string(message.contentText)
        }

        var reactions: [String] = []
        if case let .array(items)? = contentObject["reactions"] {
            reactions = items.map(\.textValue).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if !reactions.contains(cleanEmoji) {
            reactions.append(cleanEmoji)
        }

        contentObject["reactions"] = .array(reactions.map { .string($0) })
        contentObject["reactions_text"] = .string(reactions.joined(separator: " "))

        do {
            try await client.updateMessageContent(messageId: message.id, content: .object(contentObject))
            await refreshSilently()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func deleteMessage(message: Message) async {
        guard let client else { return }
        do {
            try await client.deleteMessage(messageId: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func canDeleteMessage(_ message: Message, role: Role?) -> Bool {
        if message.userId == userId { return true }
        return role?.hasManagerRights == true || role == .support
    }

    func sendAttachment(fileName: String, mimeType: String, data: Data) async -> Bool {
        guard let client else { return false }
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "ID текущего пользователя пуст"
            return false
        }
        if data.count <= 0 {
            errorText = "Вложение пустое"
            return false
        }
        if data.count > maxAttachmentBytes {
            errorText = "Вложение больше 250 МБ"
            return false
        }

        let cleanName = sanitizedFileName(fileName)
        let cleanMime = mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "application/octet-stream" : mimeType
        let path = "\(chatId)/\(UUID().uuidString)_\(cleanName)"

        do {
            let url = try await client.uploadChatAttachment(path: path, contentType: cleanMime, data: data)
            let content: [String: JSONValue] = [
                "type": .string("attachment"),
                "text": .string("Файл: \(cleanName)"),
                "file_name": .string(cleanName),
                "mime_type": .string(cleanMime),
                "size_bytes": .number(Double(data.count)),
                "url": .string(url)
            ]
            let message = try await client.sendMessageContent(
                chatId: chatId,
                userId: userId,
                content: .object(content),
                type: "attachment"
            )
            messages.append(message)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func loadForwardTargets() async {
        guard let client else { return }
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoadingForwardTargets = true
        defer { isLoadingForwardTargets = false }

        do {
            let chats = try await client.fetchMyChats(userId: userId)
            forwardTargets = chats
                .filter { $0.id != chatId }
                .sorted {
                    let left = ($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let right = ($1.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                }
        } catch {
            forwardTargets = []
            errorText = error.localizedDescription
        }
    }

    func forwardMessage(_ message: Message, to targetChatId: String) async -> Bool {
        guard let client else { return false }
        let cleanTargetChatId = targetChatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTargetChatId.isEmpty else { return false }

        var contentObject = message.contentObject ?? [:]
        if contentObject["text"] == nil {
            contentObject["text"] = .string(message.contentText)
        }
        contentObject["forwarded_original_message_id"] = .string(message.id)
        contentObject["forwarded_from_user_id"] = .string(message.userId ?? "")
        contentObject["forwarded_from_name"] = .string(forwardSourceName(for: message))

        do {
            _ = try await client.sendMessageContent(
                chatId: cleanTargetChatId,
                userId: userId,
                content: .object(contentObject),
                type: message.type ?? "text"
            )
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func startLiveUpdates() {
        stopLiveUpdates()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshSilently()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func stopLiveUpdates() {
        pollingTask?.cancel()
        pollingTask = nil
        typingStopTask?.cancel()
        typingStopTask = nil
        Task { await setTyping(false) }
    }

    func draftDidChange() {
        let hasText = !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasText {
            Task { await setTyping(true) }
            typingStopTask?.cancel()
            typingStopTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard let self else { return }
                await self.setTyping(false)
            }
        } else {
            Task { await setTyping(false) }
        }
    }

    private func refreshSilently() async {
        guard let client else { return }
        do {
            let rows = try await client.fetchMessages(chatId: chatId)
            messages = visibleMessages(rows)
            try? await client.markMessagesRead(chatId: chatId, currentUserId: userId)
            await refreshTypingStatuses()
        } catch {
            // Keep silent during polling.
        }
    }

    private func refreshTypingStatuses() async {
        guard let client else { return }
        do {
            let rows = try await client.fetchTypingStatuses(chatId: chatId)
            let names = rows
                .filter { $0.isTyping && $0.userId != userId }
                .map { row in
                    let name = row.user?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !name.isEmpty { return name }
                    let email = row.user?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return email.isEmpty ? row.userId : email
                }
            typingUsersText = names.isEmpty ? "" : "\(names.joined(separator: ", ")) печатает..."
        } catch {
            typingUsersText = ""
        }
    }

    private func setTyping(_ value: Bool) async {
        guard let client else { return }
        guard !userId.isEmpty else { return }
        guard isTyping != value else { return }
        isTyping = value
        do {
            try await client.setTypingStatus(chatId: chatId, userId: userId, isTyping: value)
        } catch {
            // Ignore typing transport errors.
        }
    }

    private func trimForReplyPreview(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count <= 64 { return clean }
        return String(clean.prefix(64)) + "..."
    }

    private func visibleMessages(_ rows: [Message]) -> [Message] {
        return rows.filter { !($0.isDeleted ?? false) }
    }

    private func forwardSourceName(for message: Message) -> String {
        let cleanForwarded = message.forwardedFromName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanForwarded.isEmpty { return cleanForwarded }
        let cleanUserId = message.userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleanUserId.isEmpty ? "Неизвестно" : cleanUserId
    }

    private func sanitizedFileName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "file" }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let mapped = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(mapped)
        return result.isEmpty ? "file" : result
    }
}
