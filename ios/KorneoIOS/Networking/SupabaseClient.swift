import Foundation

final class SupabaseClient {
    private let keychain = KeychainStore()
    private let configStore: SupabaseRuntimeConfigStore
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private let sessionKey = "korneo.supabase.session"

    private var sessionTokens: SessionTokens? {
        get {
            guard let data = keychain.load(forKey: sessionKey) else { return nil }
            return try? decoder.decode(SessionTokens.self, from: data)
        }
        set {
            if let newValue, let data = try? encoder.encode(newValue) {
                keychain.save(data: data, forKey: sessionKey)
            } else {
                keychain.delete(forKey: sessionKey)
            }
        }
    }

    var hasActiveSession: Bool {
        sessionTokens?.accessToken.isEmpty == false
    }

    init(configStore: SupabaseRuntimeConfigStore = SupabaseRuntimeConfigStore(), urlSession: URLSession = .shared) {
        self.configStore = configStore
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    var runtimeConfig: SupabaseRuntimeConfig {
        configStore.load()
    }

    func updateConnection(url: String, anonKey: String, daichiToken: String? = nil) {
        configStore.save(url: normalizeBaseURL(url), anonKey: anonKey, daichiToken: daichiToken)
        clearSession()
    }

    func updateDaichiToken(_ token: String) {
        configStore.saveDaichiToken(token)
    }

    func clearSession() {
        sessionTokens = nil
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        let config = runtimeConfig
        let anonKey = normalizeApiKey(config.anonKey)
        guard !anonKey.isEmpty else { throw APIError.missingSupabaseKey }

        let body: [String: String] = [
            "email": email,
            "password": password
        ]

        let auth: AuthResponse = try await request(
            baseURL: config.baseURL,
            path: "auth/v1/token?grant_type=password",
            method: "POST",
            body: body,
            requiresAuth: false
        )

        sessionTokens = SessionTokens(accessToken: auth.accessToken, refreshToken: auth.refreshToken)
        return auth
    }

    func fetchCurrentUserProfile() async throws -> User {
        guard let authUser = try await fetchAuthUser() else {
            throw APIError.missingSession
        }
        let users: [User] = try await request(
            path: "rest/v1/users",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "auth_user_id", value: "eq.\(authUser.id)"),
                URLQueryItem(name: "select", value: "*")
            ]
        )
        guard let user = users.first else {
            throw APIError.requestFailed(status: 404, message: "User profile not found")
        }
        return user
    }

    func loadOrCreateUserProfile(from auth: AuthResponse) async throws -> User {
        if let user = try? await fetchCurrentUserProfile() {
            return user
        }

        guard let authUser = auth.user else {
            throw APIError.requestFailed(status: 400, message: "Auth user missing in response")
        }

        let payload: [String: String] = [
            "auth_user_id": authUser.id,
            "email": authUser.email ?? "",
            "name": authUser.email ?? "iOS User",
            "role": Role.engineer.rawValue
        ]

        let createdUsers: [User] = try await request(
            path: "rest/v1/users",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )

        guard let created = createdUsers.first else {
            throw APIError.requestFailed(status: 500, message: "Could not create user profile")
        }
        return created
    }

    func fetchProjects() async throws -> [Project] {
        try await request(
            path: "rest/v1/projects",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,description,status,client_name,address,budget,start_date,end_date,created_by,short_id,is_archived,created_at,updated_at"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func createProject(_ payload: ProjectUpsertPayload) async throws -> Project {
        let created: [Project] = try await request(
            path: "rest/v1/projects",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let first = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty create response")
        }
        return first
    }

    func updateProject(id: String, payload: ProjectUpsertPayload) async throws {
        _ = try await request(
            path: "rest/v1/projects",
            method: "PATCH",
            body: payload,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        ) as EmptyResponse
    }

    func deleteProject(id: String) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        await deleteComments(entityType: "project", entityId: cleanId)
        _ = try await request(
            path: "rest/v1/projects",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func fetchTasks() async throws -> [TaskItem] {
        try await request(
            path: "rest/v1/tasks",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,project_id,title,description,assignee_id,status,priority,due_date,is_archived,short_id,created_by,created_at,updated_at"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func createTask(_ payload: TaskUpsertPayload) async throws -> TaskItem {
        let created: [TaskItem] = try await request(
            path: "rest/v1/tasks",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let first = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty create response")
        }
        return first
    }

    func updateTask(id: String, payload: TaskUpsertPayload) async throws {
        _ = try await request(
            path: "rest/v1/tasks",
            method: "PATCH",
            body: payload,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        ) as EmptyResponse
    }

    func deleteTask(id: String) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        await deleteComments(entityType: "task", entityId: cleanId)
        _ = try await request(
            path: "rest/v1/tasks",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func updateTaskStatus(id: String, status: TaskStatus) async throws {
        let patch = TaskStatusPatch(status: status.rawValue)
        _ = try await request(
            path: "rest/v1/tasks",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        ) as EmptyResponse
    }

    func fetchChats() async throws -> [Chat] {
        let chats: [Chat] = try await request(
            path: "rest/v1/chats",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,type,name,created_by,created_at,updated_at,is_deleted"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
        return chats.filter { !($0.isDeleted ?? false) }
    }

    func fetchMyChats(userId: String) async throws -> [Chat] {
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserId.isEmpty else { return [] }

        let memberships: [ChatMemberRow] = try await request(
            path: "rest/v1/chat_members",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(cleanUserId)"),
                URLQueryItem(name: "select", value: "chat_id,user_id,pinned")
            ]
        )

        var pinnedByChatId: [String: Bool] = [:]
        let chatIds = Array(Set(memberships.compactMap { row in
            let chatId = row.chatId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !chatId.isEmpty {
                pinnedByChatId[chatId] = row.pinned ?? false
            }
            return chatId.isEmpty ? nil : chatId
        }))
        guard !chatIds.isEmpty else { return [] }
        let inFilter = buildInFilter(from: chatIds)
        guard !inFilter.isEmpty else { return [] }

        let chats: [Chat] = try await request(
            path: "rest/v1/chats",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "id", value: inFilter),
                URLQueryItem(name: "select", value: "id,type,name,created_by,created_at,updated_at,is_deleted"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )

        let visible = chats.filter { !($0.isDeleted ?? false) }
        let withPinned = visible.map { chat in
            Chat(
                id: chat.id,
                type: chat.type,
                name: chat.name,
                createdBy: chat.createdBy,
                createdAt: chat.createdAt,
                updatedAt: chat.updatedAt,
                isDeleted: chat.isDeleted,
                pinned: pinnedByChatId[chat.id] ?? false
            )
        }
        return withPinned.sorted { lhs, rhs in
            let leftPinned = lhs.pinned ?? false
            let rightPinned = rhs.pinned ?? false
            if leftPinned != rightPinned {
                return leftPinned && !rightPinned
            }
            let lTime = lhs.updatedAt ?? lhs.createdAt ?? ""
            let rTime = rhs.updatedAt ?? rhs.createdAt ?? ""
            return lTime > rTime
        }
    }

    func fetchAllGroupChats() async throws -> [Chat] {
        let chats: [Chat] = try await request(
            path: "rest/v1/chats",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "type", value: "eq.group"),
                URLQueryItem(name: "select", value: "id,type,name,created_by,created_at,updated_at,is_deleted"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
        return chats.filter { !($0.isDeleted ?? false) }
    }

    func fetchMessages(chatId: String, limit: Int = 200) async throws -> [Message] {
        try await request(
            path: "rest/v1/messages",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(chatId)"),
                URLQueryItem(name: "select", value: "id,chat_id,user_id,content,created_at,type,job_id,is_read,is_deleted"),
                URLQueryItem(name: "order", value: "created_at.asc.nullsfirst"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
    }

    func fetchLatestMessage(chatId: String) async throws -> Message? {
        let rows: [Message] = try await request(
            path: "rest/v1/messages",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(chatId)"),
                URLQueryItem(name: "select", value: "id,chat_id,user_id,content,created_at,type,job_id,is_read,is_deleted"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return rows.first(where: { !($0.isDeleted ?? false) })
    }

    func markMessagesRead(chatId: String, currentUserId: String) async throws {
        guard !currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let patch: [String: Bool] = ["is_read": true]
        _ = try await request(
            path: "rest/v1/messages",
            method: "PATCH",
            body: patch,
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(chatId)"),
                URLQueryItem(name: "user_id", value: "neq.\(currentUserId)"),
                URLQueryItem(name: "is_read", value: "eq.false")
            ]
        ) as EmptyResponse
    }

    func fetchTypingStatuses(chatId: String) async throws -> [ChatTypingStatus] {
        try await request(
            path: "rest/v1/chat_typing",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(chatId)"),
                URLQueryItem(name: "select", value: "chat_id,user_id,is_typing,updated_at,user:users(id,name,email)")
            ]
        )
    }

    func setTypingStatus(chatId: String, userId: String, isTyping: Bool) async throws {
        let body: [String: JSONValue] = [
            "chat_id": .string(chatId),
            "user_id": .string(userId),
            "is_typing": .bool(isTyping)
        ]
        _ = try await request(
            path: "rest/v1/chat_typing",
            method: "POST",
            body: body,
            queryItems: [URLQueryItem(name: "on_conflict", value: "chat_id,user_id")],
            headers: ["Prefer": "resolution=merge-duplicates"]
        ) as EmptyResponse
    }

    func sendMessage(chatId: String, userId: String, text: String, type: String = "text") async throws -> Message {
        let payload: [String: JSONValue] = [
            "chat_id": .string(chatId),
            "user_id": .string(userId),
            "content": .string(text),
            "type": .string(type)
        ]
        let created: [Message] = try await request(
            path: "rest/v1/messages",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let message = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty send response")
        }
        return message
    }

    func sendMessageContent(
        chatId: String,
        userId: String,
        content: JSONValue,
        type: String = "text"
    ) async throws -> Message {
        let payload: [String: JSONValue] = [
            "chat_id": .string(chatId),
            "user_id": .string(userId),
            "content": content,
            "type": .string(type)
        ]
        let created: [Message] = try await request(
            path: "rest/v1/messages",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let message = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty send response")
        }
        return message
    }

    func updateMessageContent(messageId: String, content: JSONValue) async throws {
        let cleanId = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        let patch: [String: JSONValue] = ["content": content]
        _ = try await request(
            path: "rest/v1/messages",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func deleteMessage(messageId: String) async throws {
        let cleanId = messageId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        _ = try await request(
            path: "rest/v1/messages",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func uploadChatAttachment(path: String, contentType: String, data: Data) async throws -> String {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "Attachment path is empty")
        }
        guard !data.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "Attachment data is empty")
        }

        let encodedPath = cleanPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanPath
        var request = try buildRequest(
            baseURL: normalizeBaseURL(runtimeConfig.baseURL),
            path: "storage/v1/object/chat_attachments/\(encodedPath)",
            method: "POST",
            bodyData: nil,
            queryItems: [],
            headers: [
                "Content-Type": contentType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "application/octet-stream" : contentType,
                "x-upsert": "true"
            ],
            requiresAuth: true
        )
        request.httpBody = data
        _ = try await execute(request: request) as EmptyResponse
        return "\(normalizeBaseURL(runtimeConfig.baseURL))storage/v1/object/public/chat_attachments/\(encodedPath)"
    }

    func createChatWithMembers(
        name: String,
        type: String,
        createdBy: String,
        memberIds: [String]
    ) async throws -> Chat {
        let cleanCreatedBy = createdBy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCreatedBy.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "created_by is required")
        }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatPayload: [String: JSONValue] = [
            "name": .string(cleanName.isEmpty ? "Chat" : cleanName),
            "type": .string(type),
            "created_by": .string(cleanCreatedBy)
        ]

        let createdChats: [Chat] = try await request(
            path: "rest/v1/chats",
            method: "POST",
            body: chatPayload,
            headers: ["Prefer": "return=representation"]
        )
        guard let chat = createdChats.first else {
            throw APIError.requestFailed(status: 500, message: "Empty create chat response")
        }

        let uniqueMembers = Array(Set(memberIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } + [cleanCreatedBy]))
        if !uniqueMembers.isEmpty {
            let memberPayloads: [[String: JSONValue]] = uniqueMembers.map {
                [
                    "chat_id": .string(chat.id),
                    "user_id": .string($0)
                ]
            }
            _ = try await request(
                path: "rest/v1/chat_members",
                method: "POST",
                body: memberPayloads,
                queryItems: [URLQueryItem(name: "on_conflict", value: "chat_id,user_id")],
                headers: ["Prefer": "resolution=merge-duplicates,return=minimal"]
            ) as EmptyResponse
        }

        return chat
    }

    func fetchChatMemberUserIds(chatId: String) async throws -> [String] {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty else { return [] }
        let rows: [ChatMemberRow] = try await request(
            path: "rest/v1/chat_members",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(cleanChatId)"),
                URLQueryItem(name: "select", value: "user_id")
            ]
        )
        return Array(
            Set(
                rows.compactMap { row in
                    let userId = row.userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return userId.isEmpty ? nil : userId
                }
            )
        )
    }

    func fetchPrivateChatPeerNames(chatIds: [String], currentUserId: String) async throws -> [String: String] {
        let cleanCurrentUserId = currentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCurrentUserId.isEmpty else { return [:] }
        let inFilter = buildInFilter(from: chatIds)
        guard !inFilter.isEmpty else { return [:] }

        let rows: [ChatMemberUserRow] = try await request(
            path: "rest/v1/chat_members",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: inFilter),
                URLQueryItem(name: "select", value: "chat_id,user_id,user:users(id,name,email)")
            ]
        )

        var result: [String: String] = [:]
        for row in rows {
            let chatId = row.chatId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let userId = row.userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if chatId.isEmpty || userId.isEmpty || userId == cleanCurrentUserId { continue }
            if result[chatId] != nil { continue }

            let name = row.user?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let email = row.user?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let display = !name.isEmpty ? name : email
            if !display.isEmpty {
                result[chatId] = display
            }
        }
        return result
    }

    func addChatMembers(chatId: String, userIds: [String]) async throws {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty else { return }
        let cleanUserIds = Array(
            Set(
                userIds
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        guard !cleanUserIds.isEmpty else { return }

        let payloads: [[String: JSONValue]] = cleanUserIds.map {
            [
                "chat_id": .string(cleanChatId),
                "user_id": .string($0)
            ]
        }
        _ = try await request(
            path: "rest/v1/chat_members",
            method: "POST",
            body: payloads,
            queryItems: [URLQueryItem(name: "on_conflict", value: "chat_id,user_id")],
            headers: ["Prefer": "resolution=merge-duplicates,return=minimal"]
        ) as EmptyResponse
    }

    func setChatPinned(chatId: String, userId: String, pinned: Bool) async throws {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty, !cleanUserId.isEmpty else { return }
        let patch: [String: Bool] = ["pinned": pinned]
        _ = try await request(
            path: "rest/v1/chat_members",
            method: "PATCH",
            body: patch,
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(cleanChatId)"),
                URLQueryItem(name: "user_id", value: "eq.\(cleanUserId)")
            ]
        ) as EmptyResponse
    }

    func removeChatForCurrentUser(chatId: String, userId: String) async throws {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty, !cleanUserId.isEmpty else { return }
        _ = try await request(
            path: "rest/v1/chat_members",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(cleanChatId)"),
                URLQueryItem(name: "user_id", value: "eq.\(cleanUserId)")
            ]
        ) as EmptyResponse
    }

    func deleteChatPermanently(chatId: String) async throws {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty else { return }

        try await deleteChatJobs(chatId: cleanChatId)
        try await deleteChatMessageReceipts(chatId: cleanChatId)
        try await deleteChatMessages(chatId: cleanChatId)
        try await deleteChatTyping(chatId: cleanChatId)
        try await deleteChatMembers(chatId: cleanChatId)
        try await deleteChatRow(chatId: cleanChatId)
    }

    func fetchUsers() async throws -> [User] {
        try await request(
            path: "rest/v1/users",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func updateUserProfile(
        userId: String,
        name: String?,
        phone: String?,
        avatarURL: String? = nil,
        notificationEnabled: Bool?
    ) async throws -> User {
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserId.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "User id is empty")
        }

        var patch: [String: JSONValue] = [:]
        if let name {
            patch["name"] = .string(name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let phone {
            let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            patch["phone"] = cleanPhone.isEmpty ? .null : .string(cleanPhone)
        }
        if let avatarURL {
            let cleanAvatar = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines)
            patch["avatar_url"] = cleanAvatar.isEmpty ? .null : .string(cleanAvatar)
        }
        if let notificationEnabled {
            patch["notification_enabled"] = .bool(notificationEnabled)
        }

        let rows: [User] = try await request(
            path: "rest/v1/users",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanUserId)")],
            headers: ["Prefer": "return=representation"]
        )
        guard let first = rows.first else {
            throw APIError.requestFailed(status: 500, message: "Empty update profile response")
        }
        return first
    }

    func uploadUserAvatar(userId: String, contentType: String, data: Data) async throws -> String {
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUserId.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "User id is empty")
        }
        guard !data.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "Avatar data is empty")
        }

        let ext: String
        let lowType = contentType.lowercased()
        if lowType.contains("png") {
            ext = "png"
        } else if lowType.contains("webp") {
            ext = "webp"
        } else {
            ext = "jpg"
        }

        let objectPath = "user_\(cleanUserId)/\(UUID().uuidString.lowercased()).\(ext)"
        let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
        let buckets = ["avatars", "user_avatars", "profile_avatars", "chat_attachments"]

        var lastError: Error?
        for bucket in buckets {
            do {
                var request = try buildRequest(
                    baseURL: normalizeBaseURL(runtimeConfig.baseURL),
                    path: "storage/v1/object/\(bucket)/\(encodedPath)",
                    method: "POST",
                    bodyData: nil,
                    queryItems: [],
                    headers: [
                        "Content-Type": lowType.isEmpty ? "application/octet-stream" : contentType,
                        "x-upsert": "true"
                    ],
                    requiresAuth: true
                )
                request.httpBody = data
                _ = try await execute(request: request) as EmptyResponse
                return "\(normalizeBaseURL(runtimeConfig.baseURL))storage/v1/object/public/\(bucket)/\(encodedPath)"
            } catch {
                lastError = error
            }
        }

        throw lastError ?? APIError.requestFailed(status: 500, message: "Avatar upload failed")
    }

    func fetchComments(entityType: String, entityId: String) async throws -> [EntityComment] {
        let cleanType = entityType.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanId = entityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanType.isEmpty, !cleanId.isEmpty else { return [] }

        let selects = [
            "id,entity_type,entity_id,resource_type,resource_id,user_id,created_by,message,content,comment,body,text,created_at,is_deleted,user:users(id,name,email)",
            "id,entity_type,entity_id,resource_type,resource_id,user_id,created_by,message,content,comment,body,text,created_at,is_deleted"
        ]
        let order = "created_at.asc.nullsfirst"
        let variants = commentQueryVariants(entityType: cleanType, entityId: cleanId)
        var lastError: Error?

        for select in selects {
            for baseItems in variants {
                var queryItems = baseItems
                queryItems.append(URLQueryItem(name: "select", value: select))
                queryItems.append(URLQueryItem(name: "order", value: order))
                do {
                    let rows: [EntityComment] = try await request(
                        path: "rest/v1/comments",
                        method: "GET",
                        queryItems: queryItems
                    )
                    let active = rows.filter { !($0.isDeleted ?? false) }
                    if !active.isEmpty {
                        return active
                    }
                } catch {
                    lastError = error
                }
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }

    func addComment(entityType: String, entityId: String, content: String, userId: String?) async throws -> EntityComment {
        let cleanType = entityType.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanId = entityId.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanType.isEmpty, !cleanId.isEmpty, !text.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "Comment payload is invalid")
        }

        let payloads = commentCreatePayloads(
            entityType: cleanType,
            entityId: cleanId,
            content: text,
            userId: userId?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        var lastError: Error?
        for payload in payloads {
            do {
                let rows: [EntityComment] = try await request(
                    path: "rest/v1/comments",
                    method: "POST",
                    body: payload,
                    headers: ["Prefer": "return=representation"]
                )
                if let created = rows.first {
                    return created
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? APIError.requestFailed(status: 500, message: "Could not create comment")
    }

    func registerPushToken(userId: String, token: String) async throws {
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let body = [
            "user_id": userId,
            "fcm_token": token
        ]

        do {
            _ = try await request(
                path: "functions/v1/push-register",
                method: "POST",
                body: body
            ) as [String: JSONValue]
        } catch {
            let patch = UserPushTokenPatch(fcmToken: token, notificationEnabled: true)
            _ = try await request(
                path: "rest/v1/users",
                method: "PATCH",
                body: patch,
                queryItems: [URLQueryItem(name: "id", value: "eq.\(userId)")]
            ) as EmptyResponse
        }
    }

    func sendWorkAlertPush(
        targetUserId: String,
        title: String?,
        bodyText: String?,
        chatId: String?,
        senderId: String?
    ) async throws {
        let safeTarget = targetUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeTarget.isEmpty else { return }

        let safeTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBody = (bodyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dedupeSeed = "\(safeTarget)|\(safeTitle)|\(safeBody)|\(chatId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")"
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: JSONValue] = [
            "title": .string(safeTitle.isEmpty ? "Korneo" : safeTitle),
            "body": .string(safeBody.isEmpty ? "Work alert" : safeBody),
            "message": .string(safeBody.isEmpty ? "Work alert" : safeBody),
            "content": .string(safeBody.isEmpty ? "Work alert" : safeBody),
            "text": .string(safeBody.isEmpty ? "Work alert" : safeBody),
            "type": .string("work_overdue"),
            "target_user_id": .string(safeTarget),
            "targetUserId": .string(safeTarget),
            "user_id": .string(safeTarget),
            "recipient_id": .string(safeTarget),
            "dedupe_key": .string(String(dedupeSeed.prefix(180))),
            "dedupeKey": .string(String(dedupeSeed.prefix(180))),
            "ignore_notification_enabled": .bool(true),
            "ignoreNotificationEnabled": .bool(true)
        ]

        let safeChatId = chatId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !safeChatId.isEmpty {
            payload["chat_id"] = .string(safeChatId)
            payload["chatId"] = .string(safeChatId)
        }

        let safeSenderId = senderId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !safeSenderId.isEmpty {
            payload["sender_id"] = .string(safeSenderId)
            payload["exclude_user_id"] = .string("")
            payload["excludeUserId"] = .string("")
        }

        _ = try await request(
            path: "functions/v1/push-send",
            method: "POST",
            body: payload
        ) as EmptyResponse
    }

    func fetchPurchaseRequests() async throws -> [PurchaseRequest] {
        try await request(
            path: "rest/v1/purchase_requests",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,status,installation_id,task_id,task_avr_id,project_id,created_by,approved_by,total_amount,comment,receipt_address,received_at,created_at,updated_at,short_id,title"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func searchMaterials(query: String, limit: Int = 20) async throws -> [Material] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let safeTerm = sanitizeFilterTerm(trimmed)
        guard !safeTerm.isEmpty else { return [] }
        let boundedLimit = max(1, min(limit, 100))
        return try await request(
            path: "rest/v1/materials",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,unit,default_unit"),
                URLQueryItem(name: "or", value: "name.ilike.*\(safeTerm)*,id.ilike.*\(safeTerm)*"),
                URLQueryItem(name: "order", value: "name.asc.nullslast"),
                URLQueryItem(name: "limit", value: "\(boundedLimit)")
            ]
        )
    }

    func fetchDaichiProducts(searchTerm: String?) async throws -> [DaichiProduct] {
        let token = runtimeConfig.daichiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw APIError.missingDaichiToken }

        let storeId = try await resolveDaichiDefaultStoreId(token: token)
        var queryItems = [URLQueryItem(name: "store-id", value: storeId)]
        let cleanTerm = (searchTerm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTerm.isEmpty {
            queryItems.append(URLQueryItem(name: "filter[NAME]", value: cleanTerm))
        }

        let root = try await daichiGet(path: "products/get/", token: token, queryItems: queryItems)
        if let message = daichiBodyError(root), !message.isEmpty {
            throw APIError.requestFailed(status: 400, message: message)
        }
        return parseDaichiProducts(root: root)
    }

    func fetchDaichiProductDetails(xmlId: String) async throws -> DaichiProductDetails {
        let token = runtimeConfig.daichiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { throw APIError.missingDaichiToken }
        let cleanId = xmlId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else {
            return DaichiProductDetails(params: [], documentURLs: [])
        }

        let root = try await daichiGet(
            path: "productparams/get/",
            token: token,
            queryItems: [URLQueryItem(name: "filter[XML_ID]", value: cleanId)]
        )
        return parseDaichiProductDetails(root: root)
    }

    func fetchMaterials(limit: Int = 1000) async throws -> [Material] {
        let boundedLimit = max(1, min(limit, 5000))
        return try await request(
            path: "rest/v1/materials",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,unit,default_unit"),
                URLQueryItem(name: "order", value: "name.asc.nullslast"),
                URLQueryItem(name: "limit", value: "\(boundedLimit)")
            ]
        )
    }

    func createMaterial(
        name: String,
        category: String?,
        unit: String?,
        minStock: Double?
    ) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var payload: [String: JSONValue] = ["name": .string(cleanName)]
        if let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["category"] = .string(category.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["unit"] = .string(unit.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let minStock {
            payload["min_stock"] = .number(minStock)
        }
        _ = try await request(
            path: "rest/v1/materials",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=minimal"]
        ) as EmptyResponse
    }

    func createPurchaseRequest(_ payload: PurchaseRequestUpsertPayload) async throws -> PurchaseRequest {
        let created: [PurchaseRequest] = try await request(
            path: "rest/v1/purchase_requests",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let first = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty create response")
        }
        return first
    }

    func createPurchaseRequestItem(
        requestId: String,
        materialId: String,
        materialName: String,
        quantity: Double,
        unit: String?
    ) async throws {
        let cleanRequestId = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMaterialId = materialId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMaterialName = materialName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleanRequestId.isEmpty, !cleanMaterialId.isEmpty, quantity > 0 else { return }

        let payloadVariants = buildPurchaseRequestItemPayloadVariants(
            requestId: cleanRequestId,
            materialId: cleanMaterialId,
            materialName: cleanMaterialName.isEmpty ? cleanMaterialId : cleanMaterialName,
            quantity: quantity,
            unit: cleanUnit.isEmpty ? nil : cleanUnit
        )
        var lastError: Error?
        for payload in payloadVariants {
            do {
                _ = try await request(
                    path: "rest/v1/purchase_request_items",
                    method: "POST",
                    body: payload,
                    headers: ["Prefer": "return=minimal"]
                ) as EmptyResponse
                return
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw APIError.requestFailed(status: 500, message: "Could not create purchase request item")
    }

    func deletePurchaseRequest(id: String) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }

        await deletePurchaseRequestItems(requestId: cleanId)
        await deleteComments(entityType: "purchase_request", entityId: cleanId)

        _ = try await request(
            path: "rest/v1/purchase_requests",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func fetchPurchaseRequestItems(requestId: String) async throws -> [PurchaseRequestItem] {
        let cleanId = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return [] }

        let select = "id,purchase_request_id,request_id,material_name,material_id,material(name,unit),quantity,quantity_requested,quantity_approved,quantity_issued,unit,price,total_price"
        let variants: [[URLQueryItem]] = [
            [
                URLQueryItem(name: "purchase_request_id", value: "eq.\(cleanId)"),
                URLQueryItem(name: "select", value: select)
            ],
            [
                URLQueryItem(name: "request_id", value: "eq.\(cleanId)"),
                URLQueryItem(name: "select", value: select)
            ]
        ]

        var lastError: Error?
        for queryItems in variants {
            do {
                return try await request(
                    path: "rest/v1/purchase_request_items",
                    method: "GET",
                    queryItems: queryItems
                )
            } catch {
                lastError = error
            }
        }

        throw lastError ?? APIError.requestFailed(status: 500, message: "Could not fetch purchase request items")
    }

    func updatePurchaseRequestStatus(id: String, status: PurchaseRequestStatus, approvedBy: String?, receivedAt: String?) async throws {
        let patch = PurchaseRequestStatusPatch(
            status: status.rawValue,
            approvedBy: approvedBy,
            receivedAt: receivedAt
        )
        _ = try await request(
            path: "rest/v1/purchase_requests",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        ) as EmptyResponse
    }

    func updatePurchaseRequestFields(id: String, patch: [String: JSONValue]) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        let variants = buildPurchaseRequestPatchVariants(patch)
        var lastError: Error?
        for payload in variants {
            do {
                _ = try await request(
                    path: "rest/v1/purchase_requests",
                    method: "PATCH",
                    body: payload,
                    queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")],
                    headers: ["Prefer": "return=minimal"]
                ) as EmptyResponse
                return
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw APIError.requestFailed(status: 500, message: "Could not update purchase request")
    }

    func addWarehouseStock(
        materialId: String,
        quantity: Double,
        note: String?,
        createdBy: String?
    ) async throws {
        guard !materialId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard quantity != 0 else { return }
        var payload: [String: JSONValue] = [
            "material_id": .string(materialId),
            "quantity": .number(quantity),
            "type": .string("in")
        ]
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["note"] = .string(note)
        }
        if let createdBy, !createdBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["created_by"] = .string(createdBy)
        }
        _ = try await request(
            path: "rest/v1/warehouse",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=minimal"]
        ) as EmptyResponse
    }

    func issueWarehouseStock(
        materialId: String,
        quantity: Double,
        recipient: String?,
        note: String?,
        createdBy: String?
    ) async throws {
        guard !materialId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard quantity != 0 else { return }
        var payload: [String: JSONValue] = [
            "material_id": .string(materialId),
            "quantity": .number(quantity),
            "type": .string("out")
        ]
        if let recipient, !recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["recipient"] = .string(recipient)
        }
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["note"] = .string(note)
        }
        if let createdBy, !createdBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["created_by"] = .string(createdBy)
        }
        _ = try await request(
            path: "rest/v1/warehouse_issues",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=minimal"]
        ) as EmptyResponse
    }

    func fetchMileageRecords() async throws -> [MileageRecord] {
        try await request(
            path: "rest/v1/user_locations",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,user_id,date,recorded_at,start_odometer,end_odometer,distance,distance_km,route,purpose,latitude,longitude,accuracy,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast"),
                URLQueryItem(name: "limit", value: "500")
            ]
        )
    }

    func fetchJobsForMap() async throws -> [GenericRecord] {
        try await fetchTableRows(
            table: "jobs",
            select: "*",
            order: "created_at.desc.nullslast",
            limit: 1000
        )
    }

    func createMapWorkJob(
        chatId: String,
        userId: String,
        address: String,
        title: String,
        plannedDurationHours: Int
    ) async throws -> String {
        let cleanChatId = chatId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanChatId.isEmpty, !cleanUserId.isEmpty, !cleanAddress.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "Invalid job payload")
        }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeHours = max(1, min(plannedDurationHours, 24))
        let jobId = UUID().uuidString
        let payloads = buildMapJobPayloadVariants(
            jobId: jobId,
            chatId: cleanChatId,
            userId: cleanUserId,
            address: cleanAddress,
            title: cleanTitle.isEmpty ? "ППО" : cleanTitle,
            plannedDurationHours: safeHours
        )

        var lastError: Error?
        for payload in payloads {
            do {
                _ = try await request(
                    path: "rest/v1/jobs",
                    method: "POST",
                    body: payload,
                    headers: ["Prefer": "return=minimal"]
                ) as EmptyResponse
                return jobId
            } catch {
                lastError = error
            }
        }
        throw lastError ?? APIError.requestFailed(status: 500, message: "Could not create map job")
    }

    func fetchInstallationMapRows() async throws -> [GenericRecord] {
        try await fetchTableRows(
            table: "installations",
            select: "id,title,status,address,latitude,longitude,lat,lng,created_at",
            order: "created_at.desc.nullslast",
            limit: 500
        )
    }

    func fetchWarehouseStock() async throws -> [GenericRecord] {
        try await request(
            path: "rest/v1/warehouse",
            method: "GET",
            queryItems: [URLQueryItem(name: "select", value: "*")]
        )
    }

    func fetchWarehouseHistory() async throws -> [GenericRecord] {
        try await request(
            path: "rest/v1/warehouse_issues",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func fetchTableRows(
        table: String,
        select: String = "*",
        order: String? = nil,
        limit: Int? = nil
    ) async throws -> [GenericRecord] {
        var queryItems = [URLQueryItem(name: "select", value: select)]
        if let order, !order.isEmpty {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        return try await request(
            path: "rest/v1/\(table)",
            method: "GET",
            queryItems: queryItems
        )
    }

    func fetchSitesRows() async throws -> [GenericRecord] {
        try await fetchTableRows(
            table: "quarter_2026",
            select: "*",
            order: nil,
            limit: 500
        )
    }

    func fetchAtssRowsMerged() async throws -> [GenericRecord] {
        async let atss = fetchTableRows(table: "atss_q1_2026", select: "*", order: nil, limit: 500)
        async let kasip = fetchTableRows(table: "kasip_azm_q1_2026", select: "*", order: nil, limit: 500)
        let atssRows = try await atss
        let kasipRows = try await kasip

        func tagged(_ rows: [GenericRecord], source: String) -> [GenericRecord] {
            rows.map { row in
                var fields = row.fields
                fields["__source_table"] = .string(source)
                let siteId = (fields["id_ploshadki"]?.textValue ?? fields["site_id"]?.textValue ?? fields["id"]?.textValue ?? row.id)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let stableId = siteId.isEmpty ? row.id : siteId
                return GenericRecord(id: "\(source):\(stableId)", fields: fields)
            }
        }

        return tagged(atssRows, source: "atss_q1_2026") + tagged(kasipRows, source: "kasip_azm_q1_2026")
    }

    func fetchInstallations() async throws -> [Installation] {
        try await request(
            path: "rest/v1/installations",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "select", value: "id,project_id,title,description,assignee_id,status,scheduled_at,deadline,address,is_archived,short_id,actual_completion_date,id_ploshadki,servisnyy_id,rayon,created_by,created_at,updated_at"),
                URLQueryItem(name: "order", value: "created_at.desc.nullslast")
            ]
        )
    }

    func createInstallation(_ payload: InstallationUpsertPayload) async throws -> Installation {
        let created: [Installation] = try await request(
            path: "rest/v1/installations",
            method: "POST",
            body: payload,
            headers: ["Prefer": "return=representation"]
        )
        guard let first = created.first else {
            throw APIError.requestFailed(status: 500, message: "Empty create response")
        }
        return first
    }

    func updateInstallation(id: String, payload: InstallationUpsertPayload) async throws {
        _ = try await request(
            path: "rest/v1/installations",
            method: "PATCH",
            body: payload,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        ) as EmptyResponse
    }

    func deleteInstallation(id: String) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        await deleteComments(entityType: "installation", entityId: cleanId)
        _ = try await request(
            path: "rest/v1/installations",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func patchTableRow(table: String, id: String, patch: [String: JSONValue]) async throws {
        let cleanTable = table.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTable.isEmpty, !cleanId.isEmpty else { return }
        _ = try await request(
            path: "rest/v1/\(cleanTable)",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")]
        ) as EmptyResponse
    }

    func patchTableRows(
        table: String,
        filterField: String,
        equals value: String,
        patch: [String: JSONValue]
    ) async throws {
        let cleanTable = table.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanField = filterField.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTable.isEmpty, !cleanField.isEmpty, !cleanValue.isEmpty else { return }
        _ = try await request(
            path: "rest/v1/\(cleanTable)",
            method: "PATCH",
            body: patch,
            queryItems: [URLQueryItem(name: cleanField, value: "eq.\(cleanValue)")],
            headers: ["Prefer": "return=minimal"]
        ) as EmptyResponse
    }

    func deleteTableRows(
        table: String,
        filterField: String,
        equals value: String
    ) async throws {
        let cleanTable = table.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanField = filterField.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTable.isEmpty, !cleanField.isEmpty, !cleanValue.isEmpty else { return }
        _ = try await request(
            path: "rest/v1/\(cleanTable)",
            method: "DELETE",
            queryItems: [URLQueryItem(name: cleanField, value: "eq.\(cleanValue)")]
        ) as EmptyResponse
    }

    func deleteSite(siteId: String) async throws {
        try await deleteTableRows(table: "quarter_2026", filterField: "id_ploshadki", equals: siteId)
    }

    func deleteAtss(siteId: String) async throws {
        try await deleteTableRows(table: "atss_q1_2026", filterField: "id_ploshadki", equals: siteId)
    }

    func deleteKasipAzm(siteId: String) async throws {
        try await deleteTableRows(table: "kasip_azm_q1_2026", filterField: "id_ploshadki", equals: siteId)
    }

    func updateAtss(siteId: String, patch: [String: JSONValue]) async throws {
        try await patchTableRows(table: "atss_q1_2026", filterField: "id_ploshadki", equals: siteId, patch: patch)
    }

    func updateKasipAzm(siteId: String, patch: [String: JSONValue]) async throws {
        try await patchTableRows(table: "kasip_azm_q1_2026", filterField: "id_ploshadki", equals: siteId, patch: patch)
    }

    func uploadAtssPlanRecords(_ records: [[String: JSONValue]]) async throws -> [String: Int] {
        var stats: [String: Int] = [
            "total": records.count,
            "added": 0,
            "updated": 0,
            "unchanged": 0,
            "errors": 0
        ]
        if records.isEmpty { return stats }

        for source in records {
            let table = atssImportTable(source)
            let clean = cleanAtssImportRecord(source)
            let siteId = atssString(clean["id_ploshadki"])
            if table.isEmpty || siteId.isEmpty {
                stats["errors", default: 0] += 1
                continue
            }

            do {
                let existing: [GenericRecord] = try await request(
                    path: "rest/v1/\(table)",
                    method: "GET",
                    queryItems: [
                        URLQueryItem(name: "id_ploshadki", value: "eq.\(siteId)"),
                        URLQueryItem(name: "select", value: "*"),
                        URLQueryItem(name: "limit", value: "1")
                    ]
                )

                if let current = existing.first {
                    let patch = changedAtssFields(current: current.fields, incoming: clean)
                    if patch.isEmpty {
                        stats["unchanged", default: 0] += 1
                        continue
                    }
                    _ = try await request(
                        path: "rest/v1/\(table)",
                        method: "PATCH",
                        body: patch,
                        queryItems: [URLQueryItem(name: "id_ploshadki", value: "eq.\(siteId)")],
                        headers: ["Prefer": "return=minimal"]
                    ) as EmptyResponse
                    stats["updated", default: 0] += 1
                } else {
                    _ = try await request(
                        path: "rest/v1/\(table)",
                        method: "POST",
                        body: clean,
                        headers: ["Prefer": "return=minimal"]
                    ) as EmptyResponse
                    stats["added", default: 0] += 1
                }
            } catch {
                stats["errors", default: 0] += 1
            }
        }

        return stats
    }

    func updateSite(siteId: String, patch: [String: JSONValue]) async throws {
        try await patchTableRows(table: "quarter_2026", filterField: "id_ploshadki", equals: siteId, patch: patch)
    }

    func unarchiveTask(id: String) async throws {
        try await patchTableRow(table: "tasks", id: id, patch: ["is_archived": .bool(false)])
    }

    func unarchiveInstallation(id: String) async throws {
        try await patchTableRow(table: "installations", id: id, patch: ["is_archived": .bool(false)])
    }

    func unarchiveAvr(id: String) async throws {
        try await patchTableRow(table: "tasks_avr", id: id, patch: ["is_archived": .bool(false)])
    }

    func archiveAvr(id: String) async throws {
        try await patchTableRow(table: "tasks_avr", id: id, patch: ["is_archived": .bool(true)])
    }

    func updateAvrStatus(id: String, status: String) async throws {
        try await updateAvrTask(id: id, patch: ["status": .string(status)])
    }

    func deleteAvrTask(id: String) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        do { try await deleteTableRows(table: "equipment_changes", filterField: "task_id", equals: cleanId) } catch { }
        do { try await deleteTableRows(table: "materials_requests", filterField: "task_id", equals: cleanId) } catch { }
        try await deleteTableRows(table: "tasks_avr", filterField: "id", equals: cleanId)
    }

    func createAvrTask(payload: [String: JSONValue]) async throws -> GenericRecord {
        let variants = buildAvrPayloadVariants(payload, forCreate: true)
        var lastError: Error?
        for variant in variants {
            do {
                let created: [GenericRecord] = try await request(
                    path: "rest/v1/tasks_avr",
                    method: "POST",
                    body: variant,
                    headers: ["Prefer": "return=representation"]
                )
                if let first = created.first {
                    return first
                }
                return GenericRecord(id: UUID().uuidString, fields: variant)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw APIError.requestFailed(status: 500, message: "Could not create AVR")
    }

    func updateAvrTask(id: String, patch: [String: JSONValue]) async throws {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        let variants = buildAvrPayloadVariants(patch, forCreate: false)
        var lastError: Error?
        for variant in variants {
            do {
                _ = try await request(
                    path: "rest/v1/tasks_avr",
                    method: "PATCH",
                    body: variant,
                    queryItems: [URLQueryItem(name: "id", value: "eq.\(cleanId)")],
                    headers: ["Prefer": "return=minimal"]
                ) as EmptyResponse
                return
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw APIError.requestFailed(status: 500, message: "Could not update AVR")
    }

    func createEquipmentChange(payload: [String: JSONValue]) async throws -> GenericRecord {
        let variants = buildEquipmentChangePayloadVariants(payload)
        var lastError: Error?
        for variant in variants {
            do {
                let created: [GenericRecord] = try await request(
                    path: "rest/v1/equipment_changes",
                    method: "POST",
                    body: variant,
                    headers: ["Prefer": "return=representation"]
                )
                if let first = created.first {
                    return first
                }
                return GenericRecord(id: UUID().uuidString, fields: variant)
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        throw APIError.requestFailed(status: 500, message: "Could not create equipment change")
    }

    func fetchEquipmentChanges(taskId: String) async throws -> [GenericRecord] {
        let cleanId = taskId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return [] }
        return try await request(
            path: "rest/v1/equipment_changes",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "task_id", value: "eq.\(cleanId)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "changed_at.desc.nullslast")
            ]
        )
    }

    private func fetchAuthUser() async throws -> AuthUser? {
        guard hasActiveSession else { return nil }
        return try await request(path: "auth/v1/user", method: "GET")
    }

    private func refreshSessionIfPossible() async throws -> Bool {
        guard let refreshToken = sessionTokens?.refreshToken, !refreshToken.isEmpty else { return false }
        let config = runtimeConfig
        let anonKey = normalizeApiKey(config.anonKey)
        guard !anonKey.isEmpty else { throw APIError.missingSupabaseKey }

        struct RefreshPayload: Codable {
            let refreshToken: String
            enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
        }

        let refreshed: AuthResponse = try await request(
            baseURL: config.baseURL,
            path: "auth/v1/token?grant_type=refresh_token",
            method: "POST",
            body: RefreshPayload(refreshToken: refreshToken),
            requiresAuth: false
        )

        sessionTokens = SessionTokens(accessToken: refreshed.accessToken, refreshToken: refreshed.refreshToken ?? refreshToken)
        return true
    }

    private func request<T: Decodable, Body: Encodable>(
        baseURL: String? = nil,
        path: String,
        method: String,
        body: Body,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> T {
        let resolvedBaseURL = normalizeBaseURL(baseURL ?? runtimeConfig.baseURL)
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(
            baseURL: resolvedBaseURL,
            path: path,
            method: method,
            bodyData: bodyData,
            queryItems: queryItems,
            headers: headers,
            requiresAuth: requiresAuth
        )

        do {
            return try await execute(request: request)
        } catch APIError.requestFailed(let status, _) where status == 401 && requiresAuth {
            if try await refreshSessionIfPossible() {
                let retryRequest = try buildRequest(
                    baseURL: resolvedBaseURL,
                    path: path,
                    method: method,
                    bodyData: bodyData,
                    queryItems: queryItems,
                    headers: headers,
                    requiresAuth: requiresAuth
                )
                return try await execute(request: retryRequest)
            }
            throw APIError.missingSession
        }
    }

    private func request<T: Decodable>(
        baseURL: String? = nil,
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        requiresAuth: Bool = true
    ) async throws -> T {
        let resolvedBaseURL = normalizeBaseURL(baseURL ?? runtimeConfig.baseURL)
        let request = try buildRequest(
            baseURL: resolvedBaseURL,
            path: path,
            method: method,
            bodyData: nil,
            queryItems: queryItems,
            headers: headers,
            requiresAuth: requiresAuth
        )

        do {
            return try await execute(request: request)
        } catch APIError.requestFailed(let status, _) where status == 401 && requiresAuth {
            if try await refreshSessionIfPossible() {
                let retryRequest = try buildRequest(
                    baseURL: resolvedBaseURL,
                    path: path,
                    method: method,
                    bodyData: nil,
                    queryItems: queryItems,
                    headers: headers,
                    requiresAuth: requiresAuth
                )
                return try await execute(request: retryRequest)
            }
            throw APIError.missingSession
        }
    }

    private func buildRequest(
        baseURL: String,
        path: String,
        method: String,
        bodyData: Data?,
        queryItems: [URLQueryItem],
        headers: [String: String],
        requiresAuth: Bool
    ) throws -> URLRequest {
        let anonKey = normalizeApiKey(runtimeConfig.anonKey)
        guard !anonKey.isEmpty else { throw APIError.missingSupabaseKey }
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        if requiresAuth {
            guard let token = sessionTokens?.accessToken, !token.isEmpty else {
                throw APIError.missingSession
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyData {
            request.httpBody = bodyData
        }

        return request
    }

    private func normalizeBaseURL(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AppConfig.supabaseURL.hasSuffix("/") ? AppConfig.supabaseURL : "\(AppConfig.supabaseURL)/"
        }
        return trimmed.hasSuffix("/") ? trimmed : "\(trimmed)/"
    }

    private func normalizeApiKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func execute<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed(status: -1, message: "No HTTP response")
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.requestFailed(status: http.statusCode, message: message)
        }

        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func commentQueryVariants(entityType: String, entityId: String) -> [[URLQueryItem]] {
        [
            [
                URLQueryItem(name: "entity_type", value: "eq.\(entityType)"),
                URLQueryItem(name: "entity_id", value: "eq.\(entityId)"),
                URLQueryItem(name: "is_deleted", value: "eq.false")
            ],
            [
                URLQueryItem(name: "entity_type", value: "eq.\(entityType)"),
                URLQueryItem(name: "resource_id", value: "eq.\(entityId)"),
                URLQueryItem(name: "is_deleted", value: "eq.false")
            ],
            [
                URLQueryItem(name: "resource_type", value: "eq.\(entityType)"),
                URLQueryItem(name: "resource_id", value: "eq.\(entityId)"),
                URLQueryItem(name: "is_deleted", value: "eq.false")
            ],
            [
                URLQueryItem(name: "entity_type", value: "eq.\(entityType)"),
                URLQueryItem(name: "entity_id", value: "eq.\(entityId)")
            ],
            [
                URLQueryItem(name: "resource_type", value: "eq.\(entityType)"),
                URLQueryItem(name: "resource_id", value: "eq.\(entityId)")
            ]
        ]
    }

    private func commentCreatePayloads(entityType: String, entityId: String, content: String, userId: String?) -> [[String: JSONValue]] {
        let textFields = ["message", "content", "comment", "body", "text"]
        var payloads: [[String: JSONValue]] = []

        func appendBasePayload(
            typeKey: String,
            idKey: String,
            userKey: String?,
            includeIsDeleted: Bool
        ) {
            for textKey in textFields {
                var payload: [String: JSONValue] = [
                    typeKey: .string(entityType),
                    idKey: .string(entityId),
                    textKey: .string(content)
                ]
                if includeIsDeleted {
                    payload["is_deleted"] = .bool(false)
                }
                if let userId, !userId.isEmpty, let userKey {
                    payload[userKey] = .string(userId)
                }
                payloads.append(payload)
            }
        }

        appendBasePayload(typeKey: "entity_type", idKey: "entity_id", userKey: "user_id", includeIsDeleted: true)
        appendBasePayload(typeKey: "entity_type", idKey: "entity_id", userKey: "user_id", includeIsDeleted: false)
        appendBasePayload(typeKey: "entity_type", idKey: "resource_id", userKey: "user_id", includeIsDeleted: true)
        appendBasePayload(typeKey: "entity_type", idKey: "resource_id", userKey: "user_id", includeIsDeleted: false)
        appendBasePayload(typeKey: "resource_type", idKey: "resource_id", userKey: "user_id", includeIsDeleted: true)
        appendBasePayload(typeKey: "resource_type", idKey: "resource_id", userKey: "user_id", includeIsDeleted: false)

        if let userId, !userId.isEmpty {
            for textKey in textFields {
                var payload: [String: JSONValue] = [
                    "entity_type": .string(entityType),
                    "entity_id": .string(entityId),
                    textKey: .string(content),
                    "created_by": .string(userId)
                ]
                payloads.append(payload)
                payload["is_deleted"] = .bool(false)
                payloads.append(payload)
            }
        }

        return payloads
    }

    private func buildInFilter(from ids: [String]) -> String {
        let clean = ids
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.contains(",") && !$0.contains("(") && !$0.contains(")") }
        guard !clean.isEmpty else { return "" }
        return "in.(\(clean.joined(separator: ",")))"
    }

    private func sanitizeFilterTerm(_ value: String) -> String {
        value
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: "*", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildPurchaseRequestItemPayloadVariants(
        requestId: String,
        materialId: String,
        materialName: String,
        quantity: Double,
        unit: String?
    ) -> [[String: JSONValue]] {
        var variants: [[String: JSONValue]] = []

        func append(_ base: [String: JSONValue]) {
            var payload = base
            if let unit, !unit.isEmpty {
                payload["unit"] = .string(unit)
            }
            variants.append(payload)
        }

        append([
            "purchase_request_id": .string(requestId),
            "material_id": .string(materialId),
            "material_name": .string(materialName),
            "quantity": .number(quantity)
        ])
        append([
            "request_id": .string(requestId),
            "material_id": .string(materialId),
            "material_name": .string(materialName),
            "quantity": .number(quantity)
        ])
        append([
            "purchase_request_id": .string(requestId),
            "request_id": .string(requestId),
            "material_id": .string(materialId),
            "name": .string(materialName),
            "quantity_requested": .number(quantity)
        ])
        append([
            "purchase_request_id": .string(requestId),
            "request_id": .string(requestId),
            "material_id": .string(materialId),
            "name": .string(materialName),
            "material_name": .string(materialName),
            "quantity": .number(quantity),
            "quantity_requested": .number(quantity)
        ])

        return variants
    }

    private func buildMapJobPayloadVariants(
        jobId: String,
        chatId: String,
        userId: String,
        address: String,
        title: String,
        plannedDurationHours: Int
    ) -> [[String: JSONValue]] {
        var variants: [[String: JSONValue]] = []

        appendVariant(&variants, [
            "id": .string(jobId),
            "status": .string("pending"),
            "engineer_id": .string(userId),
            "chat_id": .string(chatId),
            "address": .string(address),
            "title": .string(title),
            "planned_duration_hours": .number(Double(plannedDurationHours)),
            "created_by": .string(userId)
        ])

        appendVariant(&variants, [
            "id": .string(jobId),
            "status": .string("pending"),
            "executor_id": .string(userId),
            "chat_id": .string(chatId),
            "address": .string(address),
            "title": .string(title),
            "planned_duration_hours": .number(Double(plannedDurationHours)),
            "created_by": .string(userId)
        ])

        appendVariant(&variants, [
            "id": .string(jobId),
            "status": .string("pending"),
            "assignee_id": .string(userId),
            "chat_id": .string(chatId),
            "address": .string(address),
            "title": .string(title),
            "planned_duration_hours": .number(Double(plannedDurationHours)),
            "created_by": .string(userId)
        ])

        appendVariant(&variants, [
            "id": .string(jobId),
            "status": .string("pending"),
            "chat_id": .string(chatId),
            "address": .string(address),
            "title": .string(title),
            "planned_duration_hours": .number(Double(plannedDurationHours)),
            "created_by": .string(userId)
        ])

        return variants
    }

    private func buildPurchaseRequestPatchVariants(_ original: [String: JSONValue]) -> [[String: JSONValue]] {
        var variants: [[String: JSONValue]] = []

        func appendIfNeeded(_ payload: [String: JSONValue]) {
            if !payload.isEmpty && !variants.contains(payload) {
                variants.append(payload)
            }
        }

        appendIfNeeded(original)

        var withoutAudit = original
        withoutAudit["status_changed_at"] = nil
        withoutAudit["status_changed_by"] = nil
        appendIfNeeded(withoutAudit)

        var compatible: [String: JSONValue] = [:]
        let compatibleKeys = ["status", "comment", "approved_by", "approved_at", "receipt_address", "received_at", "updated_at"]
        for key in compatibleKeys {
            if let value = original[key] {
                compatible[key] = value
            }
        }
        appendIfNeeded(compatible)

        var minimal: [String: JSONValue] = [:]
        let minimalKeys = ["status", "comment", "approved_by"]
        for key in minimalKeys {
            if let value = original[key] {
                minimal[key] = value
            }
        }
        appendIfNeeded(minimal)

        return variants
    }

    private func buildAvrPayloadVariants(_ original: [String: JSONValue], forCreate: Bool) -> [[String: JSONValue]] {
        var variants: [[String: JSONValue]] = []
        appendVariant(&variants, original)

        var withoutAudit = original
        withoutAudit["status_changed_at"] = nil
        withoutAudit["status_changed_by"] = nil
        appendVariant(&variants, withoutAudit)

        appendVariant(&variants, compatibleAvrPayload(from: original, forCreate: forCreate))

        if !forCreate {
            var statusOnly: [String: JSONValue] = [:]
            if let status = original["status"] { statusOnly["status"] = status }
            if let archived = original["is_archived"] { statusOnly["is_archived"] = archived }
            appendVariant(&variants, statusOnly)
        }
        return variants
    }

    private func compatibleAvrPayload(from source: [String: JSONValue], forCreate: Bool) -> [String: JSONValue] {
        var compatible: [String: JSONValue] = [:]
        copyIfPresent(source, &compatible, key: "project_id")
        copyIfPresent(source, &compatible, key: "status")
        copyIfPresent(source, &compatible, key: "created_by")
        copyIfPresent(source, &compatible, key: "is_archived")

        let title = firstNonBlank(from: source, keys: ["title", "name", "type"])
        if !title.isEmpty {
            compatible["title"] = .string(title)
        } else if forCreate {
            compatible["title"] = .string("AVR")
        }

        let description = firstNonBlank(from: source, keys: ["description", "comment"])
        if !description.isEmpty {
            compatible["description"] = .string(description)
        }

        let assignee = firstNonBlank(from: source, keys: ["assignee_id", "executor_id"])
        if !assignee.isEmpty {
            compatible["assignee_id"] = .string(assignee)
        }

        let address = firstNonBlank(from: source, keys: ["address", "address_text"])
        if !address.isEmpty {
            compatible["address"] = .string(address)
        }

        let dueDate = firstNonBlank(from: source, keys: ["due_date", "date_to", "planned_installation_date", "date_from"])
        if !dueDate.isEmpty {
            compatible["due_date"] = .string(dateOnly(dueDate))
        }
        return compatible
    }

    private func buildEquipmentChangePayloadVariants(_ original: [String: JSONValue]) -> [[String: JSONValue]] {
        var variants: [[String: JSONValue]] = []
        appendVariant(&variants, original)

        var compatible: [String: JSONValue] = [:]
        copyIfPresent(original, &compatible, key: "task_id")
        copyIfPresent(original, &compatible, key: "changed_by")
        copyIfPresent(original, &compatible, key: "change_type")
        copyIfPresent(original, &compatible, key: "field_name")
        copyIfPresent(original, &compatible, key: "comment")

        var oldValue: [String: JSONValue] = [:]
        if let before = original["before_status"] {
            oldValue["value"] = before
        }
        if let serial = original["serial_number"] {
            oldValue["serial_number"] = serial
        }
        if let equipmentType = original["equipment_type"] {
            oldValue["equipment_type"] = equipmentType
        }

        var newValue: [String: JSONValue] = [:]
        if let after = original["after_status"] {
            newValue["value"] = after
        }
        if let serial = original["serial_number"] {
            newValue["serial_number"] = serial
        }
        if let equipmentType = original["equipment_type"] {
            newValue["equipment_type"] = equipmentType
        }

        if !oldValue.isEmpty {
            compatible["old_value"] = .object(oldValue)
        }
        if !newValue.isEmpty {
            compatible["new_value"] = .object(newValue)
        }
        appendVariant(&variants, compatible)

        var minimal: [String: JSONValue] = [:]
        copyIfPresent(original, &minimal, key: "task_id")
        copyIfPresent(original, &minimal, key: "changed_by")
        copyIfPresent(original, &minimal, key: "change_type")
        copyIfPresent(original, &minimal, key: "field_name")
        copyIfPresent(original, &minimal, key: "comment")
        appendVariant(&variants, minimal)
        return variants
    }

    private func atssImportTable(_ source: [String: JSONValue]) -> String {
        let table = atssString(source["__target_table"]).lowercased()
        if table == "kasip_azm_q1_2026" { return table }
        return "atss_q1_2026"
    }

    private func cleanAtssImportRecord(_ source: [String: JSONValue]) -> [String: JSONValue] {
        var clean: [String: JSONValue] = [:]
        for (key, value) in source {
            if key.hasPrefix("__") { continue }
            if hasMeaningfulValue(value) {
                clean[key] = value
            }
        }
        return clean
    }

    private func changedAtssFields(current: [String: JSONValue], incoming: [String: JSONValue]) -> [String: JSONValue] {
        var patch: [String: JSONValue] = [:]
        for (key, next) in incoming {
            if key == "id_ploshadki" { continue }
            if !hasMeaningfulValue(next) { continue }
            let previous = current[key]
            if !sameAtssValue(previous: previous, next: next) {
                patch[key] = next
            }
        }
        return patch
    }

    private func sameAtssValue(previous: JSONValue?, next: JSONValue) -> Bool {
        let left = atssString(previous)
        let right = atssString(next)
        if left == right { return true }

        let leftNum = Double(left.replacingOccurrences(of: ",", with: "."))
        let rightNum = Double(right.replacingOccurrences(of: ",", with: "."))
        if let leftNum, let rightNum {
            return abs(leftNum - rightNum) < 0.0001
        }
        return false
    }

    private func atssString(_ value: JSONValue?) -> String {
        let text = (value?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased() == "null" { return "" }
        if let number = Double(text), number == floor(number) {
            return String(Int(number))
        }
        return text
    }

    private func daichiGet(path: String, token: String, queryItems: [URLQueryItem]) async throws -> JSONValue {
        guard var components = URLComponents(string: "https://api.daichi.ru/b2b/v1/\(path)") else {
            throw APIError.invalidURL
        }
        var mergedItems = [URLQueryItem(name: "access-token", value: token)]
        mergedItems.append(contentsOf: queryItems)
        components.queryItems = mergedItems
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.requestFailed(status: -1, message: "No HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Daichi request failed"
            throw APIError.requestFailed(status: http.statusCode, message: message)
        }

        do {
            return try decoder.decode(JSONValue.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func resolveDaichiDefaultStoreId(token: String) async throws -> String {
        let root = try await daichiGet(path: "stores/get/", token: token, queryItems: [])
        if let message = daichiBodyError(root), !message.isEmpty {
            throw APIError.requestFailed(status: 400, message: message)
        }
        guard let result = daichiObject(root)["Result"] else {
            throw APIError.requestFailed(status: 500, message: "Daichi stores payload is missing Result")
        }
        let id = daichiDefaultStoreId(from: result)
        if id.isEmpty {
            throw APIError.requestFailed(status: 500, message: "Daichi store id not found")
        }
        return id
    }

    private func daichiDefaultStoreId(from result: JSONValue) -> String {
        if let rows = daichiArray(result) {
            var fallback = ""
            for rowValue in rows {
                let row = daichiObject(rowValue)
                let idPrimary = daichiString(row["XML_ID"])
                let id = idPrimary.isEmpty ? daichiString(row["xml_id"]) : idPrimary
                if fallback.isEmpty { fallback = id }
                let isDefaultRaw = daichiString(row["IS_DEFAULT"])
                let isDefault = (isDefaultRaw.isEmpty ? daichiString(row["is_default"]) : isDefaultRaw).lowercased()
                if isDefault == "1" || isDefault == "true" {
                    return id
                }
            }
            return fallback
        }
        let row = daichiObject(result)
        let primary = daichiString(row["XML_ID"])
        return primary.isEmpty ? daichiString(row["xml_id"]) : primary
    }

    private func daichiBodyError(_ root: JSONValue) -> String? {
        let result = daichiObject(root)["Result"]
        guard let resultValue = result else { return nil }
        let resultObject = daichiObject(resultValue)
        let successRaw = daichiString(resultObject["success"])
        let success = (successRaw.isEmpty ? daichiString(resultObject["SUCCESS"]) : successRaw).lowercased()
        if success.isEmpty || (success != "false" && success != "0") {
            return nil
        }
        let errorObject = daichiObject(resultObject["error"])
        let messageRaw = daichiString(errorObject["message"])
        let message = messageRaw.isEmpty ? daichiString(errorObject["MESSAGE"]) : messageRaw
        return message.isEmpty ? "Daichi API returned an error" : message
    }

    private func parseDaichiProducts(root: JSONValue) -> [DaichiProduct] {
        var rawProducts: [[String: JSONValue]] = []
        collectDaichiProducts(from: root, output: &rawProducts, depth: 0)
        var seen = Set<String>()
        var parsed: [DaichiProduct] = []
        for row in rawProducts {
            guard let item = parseDaichiProduct(row) else { continue }
            let key = "\(item.id)|\(item.article)|\(item.name)"
            if seen.insert(key).inserted {
                parsed.append(item)
            }
        }
        return parsed
    }

    private func collectDaichiProducts(
        from value: JSONValue,
        output: inout [[String: JSONValue]],
        depth: Int
    ) {
        guard depth <= 8 else { return }
        if let array = daichiArray(value) {
            for row in array {
                collectDaichiProducts(from: row, output: &output, depth: depth + 1)
            }
            return
        }
        let object = daichiObject(value)
        guard !object.isEmpty else { return }
        if looksLikeDaichiProduct(object) {
            output.append(object)
            return
        }
        for (_, nested) in object {
            collectDaichiProducts(from: nested, output: &output, depth: depth + 1)
        }
    }

    private func looksLikeDaichiProduct(_ value: [String: JSONValue]) -> Bool {
        value["XML_ID"] != nil || value["xml_id"] != nil || value["PARAMS:"] != nil || value["PRICES:"] != nil || value["STORE:"] != nil
    }

    private func parseDaichiProduct(_ object: [String: JSONValue]) -> DaichiProduct? {
        let params = daichiObject(firstDaichiValue(in: object, keys: ["PARAMS:", "PARAMS"]))
        let prices = daichiObject(firstDaichiValue(in: object, keys: ["PRICES:", "PRICES"]))
        let store = daichiObject(firstDaichiValue(in: object, keys: ["STORE:", "STORE"]))

        let id = firstDaichiString(sources: [object, params], keys: ["XML_ID", "xml_id", "ID", "id"])
        let article = firstDaichiString(sources: [object, params], keys: ["NAME", "ARTICLE", "article", "code"])
        let brand = firstDaichiString(sources: [params, object], keys: ["BRAND", "brand", "ATTR_BRAND"])
        let series = firstDaichiString(sources: [params, object], keys: ["ATTR_L_SERIA", "SERIES", "series"])
        let type = firstDaichiString(sources: [params, object], keys: ["ATTR_L_GOODTYPE", "TYPE", "type"])
        let group = firstDaichiString(sources: [params, object], keys: ["ATTR_L_GOODGROUP", "GROUP", "group"])
        let direction = firstDaichiString(sources: [params, object], keys: ["ATTR_L_IN_UNIT_TYPE", "DIRECTION", "direction"])
        let power = firstDaichiString(sources: [params, object], keys: ["ATTR_CAPACITY_COOL", "ATTR_CAP_COOL_NOM", "POWER", "power"])
        let displayNameRaw = firstDaichiString(sources: [params, object], keys: ["ATTR_RUS_NAME_AX", "DISPLAY_NAME", "display_name", "TITLE", "title"])
        let displayName = displayNameRaw.isEmpty ? article : displayNameRaw

        let priceRaw = firstDaichiString(sources: [prices, object], keys: ["PRICE", "price", "BASE_PRICE"])
        let currencyRaw = firstDaichiString(sources: [prices, object], keys: ["CURRENCY", "currency"])
        let price = priceRaw.isEmpty ? "0" : priceRaw
        let currency = currencyRaw.isEmpty ? "RUR" : currencyRaw
        let stock = firstDaichiInt(sources: [store, object], keys: ["STORE_AMOUNT", "AMOUNT", "quantity", "quantity_available", "stock"])
        let inTransit = firstDaichiInt(sources: [store, object], keys: ["DELIVERY_AMOUNT", "IN_TRANSIT", "TRANSIT", "inTransit", "delivery"])
        let warehouse = firstDaichiString(sources: [store, object], keys: ["NAME", "WAREHOUSE", "warehouse", "store"])

        if id.isEmpty && article.isEmpty && displayName.isEmpty {
            return nil
        }

        return DaichiProduct(
            id: id,
            article: article,
            name: displayName,
            brand: brand,
            series: series,
            type: type.isEmpty ? displayName : type,
            direction: direction,
            group: group,
            price: price,
            currency: currency,
            stock: stock,
            inTransit: inTransit,
            warehouse: warehouse,
            power: power
        )
    }

    private func parseDaichiProductDetails(root: JSONValue) -> DaichiProductDetails {
        var params: [DaichiProductParam] = []
        var docs: [String] = []
        collectDaichiParamsAndDocs(from: root, params: &params, docs: &docs, depth: 0)
        let uniqueParams = Array(Set(params)).sorted {
            if $0.name == $1.name { return $0.value < $1.value }
            return $0.name < $1.name
        }
        let uniqueDocs = Array(Set(docs)).sorted()
        return DaichiProductDetails(params: uniqueParams, documentURLs: uniqueDocs)
    }

    private func collectDaichiParamsAndDocs(
        from value: JSONValue,
        params: inout [DaichiProductParam],
        docs: inout [String],
        depth: Int
    ) {
        guard depth <= 8 else { return }
        if let doc = daichiDocumentURL(from: value), !doc.isEmpty {
            docs.append(doc)
        }
        if let array = daichiArray(value) {
            for child in array {
                collectDaichiParamsAndDocs(from: child, params: &params, docs: &docs, depth: depth + 1)
            }
            return
        }
        let object = daichiObject(value)
        guard !object.isEmpty else { return }

        let name = daichiString(object["NAME"])
        let rawValue = daichiString(object["VALUE"])
        if !name.isEmpty, !rawValue.isEmpty {
            params.append(DaichiProductParam(name: name, value: rawValue))
        }

        for (key, nested) in object {
            if key.hasPrefix("ATTR_") {
                let nestedObj = daichiObject(nested)
                let attrName = daichiString(nestedObj["NAME"])
                let attrValue = daichiString(nestedObj["VALUE"])
                if !attrName.isEmpty, !attrValue.isEmpty {
                    params.append(DaichiProductParam(name: attrName, value: attrValue))
                }
            }
            collectDaichiParamsAndDocs(from: nested, params: &params, docs: &docs, depth: depth + 1)
        }
    }

    private func daichiDocumentURL(from value: JSONValue) -> String? {
        guard case let .string(rawText) = value else { return nil }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let low = text.lowercased()
        let isURL = low.hasPrefix("http://") || low.hasPrefix("https://")
        let looksLikeFile = [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".zip"].contains { low.contains($0) }
        guard isURL || looksLikeFile else { return nil }
        return isURL ? text : "https://\(text)"
    }

    private func daichiObject(_ value: JSONValue?) -> [String: JSONValue] {
        guard case let .object(obj)? = value else { return [:] }
        return obj
    }

    private func daichiArray(_ value: JSONValue?) -> [JSONValue]? {
        guard case let .array(arr)? = value else { return nil }
        return arr
    }

    private func daichiString(_ value: JSONValue?) -> String {
        let clean = (value?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.lowercased() == "null" { return "" }
        return clean
    }

    private func daichiInt(_ value: JSONValue?) -> Int {
        let clean = daichiString(value)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let number = Double(clean) else { return 0 }
        return Int(number.rounded())
    }

    private func firstDaichiValue(in object: [String: JSONValue], keys: [String]) -> JSONValue? {
        for key in keys {
            if let value = object[key] {
                return value
            }
        }
        return nil
    }

    private func firstDaichiString(sources: [[String: JSONValue]], keys: [String]) -> String {
        for source in sources {
            for key in keys {
                let value = daichiString(source[key])
                if !value.isEmpty { return value }
            }
        }
        return ""
    }

    private func firstDaichiInt(sources: [[String: JSONValue]], keys: [String]) -> Int {
        for source in sources {
            for key in keys {
                let value = daichiInt(source[key])
                if value != 0 { return value }
            }
        }
        return 0
    }

    private func appendVariant(_ variants: inout [[String: JSONValue]], _ candidate: [String: JSONValue]) {
        guard !candidate.isEmpty else { return }
        if !variants.contains(candidate) {
            variants.append(candidate)
        }
    }

    private func copyIfPresent(_ from: [String: JSONValue], _ to: inout [String: JSONValue], key: String) {
        guard let value = from[key], hasMeaningfulValue(value) else { return }
        to[key] = value
    }

    private func hasMeaningfulValue(_ value: JSONValue) -> Bool {
        switch value {
        case .null:
            return false
        case let .string(text):
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !clean.isEmpty && clean.lowercased() != "null"
        case let .array(items):
            return !items.isEmpty
        case let .object(map):
            return !map.isEmpty
        case .number, .bool:
            return true
        }
    }

    private func firstNonBlank(from source: [String: JSONValue], keys: [String]) -> String {
        for key in keys {
            guard let value = source[key] else { continue }
            let clean = value.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty, clean.lowercased() != "null" {
                return clean
            }
        }
        return ""
    }

    private func dateOnly(_ raw: String) -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count >= 10 {
            return String(clean.prefix(10))
        }
        return clean
    }

    private func deleteChatJobs(chatId: String) async throws {
        _ = try await request(
            path: "rest/v1/jobs",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "chat_id", value: "eq.\(chatId)")]
        ) as EmptyResponse
    }

    private func deleteChatMessageReceipts(chatId: String) async throws {
        let messageRows: [MessageIdRow] = try await request(
            path: "rest/v1/messages",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "chat_id", value: "eq.\(chatId)"),
                URLQueryItem(name: "select", value: "id")
            ]
        )

        let ids = messageRows.map(\.id).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if ids.isEmpty { return }

        var index = 0
        while index < ids.count {
            let chunk = Array(ids[index..<min(index + 50, ids.count)])
            let inFilter = buildInFilter(from: chunk)
            if !inFilter.isEmpty {
                _ = try await request(
                    path: "rest/v1/message_read_receipts",
                    method: "DELETE",
                    queryItems: [URLQueryItem(name: "message_id", value: inFilter)]
                ) as EmptyResponse
            }
            index += 50
        }
    }

    private func deleteChatMessages(chatId: String) async throws {
        _ = try await request(
            path: "rest/v1/messages",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "chat_id", value: "eq.\(chatId)")]
        ) as EmptyResponse
    }

    private func deleteChatTyping(chatId: String) async throws {
        _ = try await request(
            path: "rest/v1/chat_typing",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "chat_id", value: "eq.\(chatId)")]
        ) as EmptyResponse
    }

    private func deleteChatMembers(chatId: String) async throws {
        _ = try await request(
            path: "rest/v1/chat_members",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "chat_id", value: "eq.\(chatId)")]
        ) as EmptyResponse
    }

    private func deleteChatRow(chatId: String) async throws {
        _ = try await request(
            path: "rest/v1/chats",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(chatId)")]
        ) as EmptyResponse
    }

    private func deleteComments(entityType: String, entityId: String) async {
        let variants = [
            [URLQueryItem(name: "entity_type", value: "eq.\(entityType)"), URLQueryItem(name: "entity_id", value: "eq.\(entityId)")],
            [URLQueryItem(name: "entity_type", value: "eq.\(entityType)"), URLQueryItem(name: "resource_id", value: "eq.\(entityId)")],
            [URLQueryItem(name: "resource_type", value: "eq.\(entityType)"), URLQueryItem(name: "resource_id", value: "eq.\(entityId)")]
        ]
        for queryItems in variants {
            _ = try? await request(
                path: "rest/v1/comments",
                method: "DELETE",
                queryItems: queryItems
            ) as EmptyResponse
        }
    }

    private func deletePurchaseRequestItems(requestId: String) async {
        let variants = [
            [URLQueryItem(name: "purchase_request_id", value: "eq.\(requestId)")],
            [URLQueryItem(name: "request_id", value: "eq.\(requestId)")]
        ]
        for queryItems in variants {
            _ = try? await request(
                path: "rest/v1/purchase_request_items",
                method: "DELETE",
                queryItems: queryItems
            ) as EmptyResponse
        }
    }
}

struct InstallationUpsertPayload: Codable {
    var projectId: String?
    var title: String?
    var description: String?
    var assigneeId: String?
    var status: String?
    var scheduledAt: String?
    var deadline: String?
    var address: String?
    var idPloshadki: String?
    var rayon: String?
    var createdBy: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case title
        case description
        case assigneeId = "assignee_id"
        case status
        case scheduledAt = "scheduled_at"
        case deadline
        case address
        case idPloshadki = "id_ploshadki"
        case rayon
        case createdBy = "created_by"
    }
}

struct ProjectUpsertPayload: Codable {
    let name: String?
    let description: String?
    let status: String?
    let clientName: String?
    let address: String?
    let budget: String?
    let startDate: String?
    let endDate: String?
    let createdBy: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case status
        case clientName = "client_name"
        case address
        case budget
        case startDate = "start_date"
        case endDate = "end_date"
        case createdBy = "created_by"
    }
}

struct TaskUpsertPayload: Codable {
    let projectId: String?
    let title: String?
    let description: String?
    let assigneeId: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let createdBy: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case title
        case description
        case assigneeId = "assignee_id"
        case status
        case priority
        case dueDate = "due_date"
        case createdBy = "created_by"
    }
}

struct UserPushTokenPatch: Codable {
    let fcmToken: String
    let notificationEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case notificationEnabled = "notification_enabled"
    }
}

struct TaskStatusPatch: Codable {
    let status: String
}

struct PurchaseRequestStatusPatch: Codable {
    let status: String
    let approvedBy: String?
    let receivedAt: String?

    enum CodingKeys: String, CodingKey {
        case status
        case approvedBy = "approved_by"
        case receivedAt = "received_at"
    }
}

struct EmptyResponse: Codable {}
