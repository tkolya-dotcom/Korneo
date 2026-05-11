import SwiftUI

struct ChatsView: View {
    private struct ChatRoute: Hashable {
        let chatId: String
        let chatName: String
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatsViewModel()
    @State private var path: [ChatRoute] = []
    @State private var showCreateSheet = false
    @State private var pendingRemoveChat: Chat?
    @State private var pendingDeleteChat: Chat?
    @State private var isActionInProgress = false
    @State private var selectedChatForAddMembers: Chat?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    ProgressView("Loading chats...")
                } else if let error = viewModel.errorText, viewModel.chats.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if viewModel.chats.isEmpty {
                    ContentUnavailableView("No chats", systemImage: "message")
                } else {
                    List(viewModel.chats) { chat in
                        NavigationLink(value: ChatRoute(chatId: chat.id, chatName: chat.name ?? "Chat")) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(chatDisplayName(chat))
                                        .font(.headline)
                                    if chat.pinned ?? false {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    Spacer(minLength: 8)
                                    if let unread = viewModel.chatUnreadCountById[chat.id], unread > 0 {
                                        Text("\(unread)")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.red))
                                    }
                                    if !isPrivateChat(chat),
                                       let raw = viewModel.chatTimestampById[chat.id],
                                       let time = shortTime(raw),
                                       !time.isEmpty {
                                        Text(time)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let preview = viewModel.chatPreviewById[chat.id], !preview.isEmpty {
                                    Text(preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                } else {
                                    Text(chat.type ?? "group")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if canPinOrRemoveFromMyList {
                                Button {
                                    Task { _ = await viewModel.togglePin(chat: chat, currentUser: appState.currentUser) }
                                } label: {
                                    Label((chat.pinned ?? false) ? "Unpin" : "Pin", systemImage: (chat.pinned ?? false) ? "pin.slash" : "pin")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDeletePermanently(chat: chat) {
                                Button(role: .destructive) {
                                    pendingDeleteChat = chat
                                } label: {
                                    Label("Delete DB", systemImage: "trash")
                                }
                            }
                            if canPinOrRemoveFromMyList {
                                Button(role: .destructive) {
                                    pendingRemoveChat = chat
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                        }
                        .contextMenu {
                            if canPinOrRemoveFromMyList {
                                Button((chat.pinned ?? false) ? "Unpin" : "Pin") {
                                    Task { _ = await viewModel.togglePin(chat: chat, currentUser: appState.currentUser) }
                                }
                            }
                            if canManageGroupMembers(chat: chat) {
                                Button("Add Members") {
                                    selectedChatForAddMembers = chat
                                }
                            }
                            if canDeletePermanently(chat: chat) {
                                Button("Delete Permanently", role: .destructive) {
                                    pendingDeleteChat = chat
                                }
                            } else if canPinOrRemoveFromMyList {
                                Button("Remove from My Chats", role: .destructive) {
                                    pendingRemoveChat = chat
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.load(currentUser: appState.currentUser)
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                if canToggleAllGroups {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(viewModel.showingAllGroups ? "My Chats" : "All Groups") {
                            Task {
                                viewModel.showingAllGroups.toggle()
                                await viewModel.load(currentUser: appState.currentUser)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: ChatRoute.self) { route in
                ChatDetailView(
                    chatId: route.chatId,
                    chatName: route.chatName,
                    userId: appState.currentUser?.id ?? ""
                )
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load(currentUser: appState.currentUser)
            openPendingDeepLinkIfNeeded()
        }
        .task(id: refreshLoopKey) {
            guard appState.currentUser != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                await viewModel.load(currentUser: appState.currentUser)
            }
        }
        .onChange(of: appState.pendingChatDeepLink?.chatId) { _ in
            openPendingDeepLinkIfNeeded()
        }
        .onChange(of: appState.currentUser?.id) { _ in
            Task { await viewModel.load(currentUser: appState.currentUser) }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChatSheetView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .sheet(item: $selectedChatForAddMembers) { chat in
            AddChatMembersSheetView(chat: chat, viewModel: viewModel)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Remove chat from your list?",
            isPresented: Binding(
                get: { pendingRemoveChat != nil },
                set: { if !$0 { pendingRemoveChat = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isActionInProgress ? "Removing..." : "Remove", role: .destructive) {
                guard let chat = pendingRemoveChat else { return }
                Task {
                    isActionInProgress = true
                    defer { isActionInProgress = false }
                    let ok = await viewModel.removeForCurrentUser(chat: chat, currentUser: appState.currentUser)
                    if ok {
                        pendingRemoveChat = nil
                    }
                }
            }
            .disabled(isActionInProgress)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes chat only for you.")
        }
        .confirmationDialog(
            "Delete chat permanently?",
            isPresented: Binding(
                get: { pendingDeleteChat != nil },
                set: { if !$0 { pendingDeleteChat = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isActionInProgress ? "Deleting..." : "Delete", role: .destructive) {
                guard let chat = pendingDeleteChat else { return }
                Task {
                    isActionInProgress = true
                    defer { isActionInProgress = false }
                    let ok = await viewModel.deletePermanently(chat: chat, currentUser: appState.currentUser)
                    if ok {
                        pendingDeleteChat = nil
                    }
                }
            }
            .disabled(isActionInProgress)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Chat, members and messages will be deleted from database.")
        }
    }

    private func openPendingDeepLinkIfNeeded() {
        guard let link = appState.pendingChatDeepLink else { return }
        let fallbackName = viewModel.chats.first(where: { $0.id == link.chatId })?.name ?? link.chatName ?? "Chat"
        let resolvedName = viewModel.privateChatNameById[link.chatId] ?? fallbackName
        path = [ChatRoute(chatId: link.chatId, chatName: resolvedName)]
        appState.consumePendingChatDeepLink()
    }

    private var canToggleAllGroups: Bool {
        appState.currentUser?.role?.hasManagerRights == true
    }

    private func canDeletePermanently(chat: Chat) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == chat.createdBy
    }

    private var canPinOrRemoveFromMyList: Bool {
        !viewModel.showingAllGroups
    }

    private func canManageGroupMembers(chat: Chat) -> Bool {
        guard canPinOrRemoveFromMyList else { return false }
        guard let currentUserId = appState.currentUser?.id else { return false }
        let isGroup = (chat.type ?? "").lowercased() == "group"
        return isGroup && chat.createdBy == currentUserId
    }

    private func chatDisplayName(_ chat: Chat) -> String {
        if let privateName = viewModel.privateChatNameById[chat.id], !privateName.isEmpty {
            return privateName
        }
        let base = chat.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return base.isEmpty ? "Chat" : base
    }

    private func isPrivateChat(_ chat: Chat) -> Bool {
        (chat.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "private"
    }

    private func shortTime(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: trimmed) ?? ISO8601DateFormatter().date(from: trimmed)
        guard let date else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM HH:mm"
        return out.string(from: date)
    }

    private var refreshLoopKey: String {
        let userId = appState.currentUser?.id ?? "none"
        let mode = viewModel.showingAllGroups ? "all" : "my"
        return "\(userId):\(mode)"
    }
}
