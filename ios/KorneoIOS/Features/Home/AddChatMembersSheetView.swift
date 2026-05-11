import SwiftUI

struct AddChatMembersSheetView: View {
    let chat: Chat
    @ObservedObject var viewModel: ChatsViewModel

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var users: [User] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var existingMemberIds: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    ProgressView("Загрузка пользователей...")
                }
                if availableUsers.isEmpty && !isLoading {
                    Text("Нет пользователей для добавления")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Доступные пользователи") {
                        ForEach(availableUsers) { user in
                            Toggle(displayName(user), isOn: binding(for: user.id))
                        }
                    }
                }
            }
            .navigationTitle("Добавить участников")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Добавление..." : "Добавить") {
                        Task { await addMembers() }
                    }
                    .disabled(isSaving || selectedUserIds.isEmpty)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private var availableUsers: [User] {
        let currentUserId = appState.currentUser?.id
        return users.filter { user in
            if let currentUserId, user.id == currentUserId { return false }
            return !existingMemberIds.contains(user.id)
        }
    }

    private func loadData() async {
        guard let currentUser = appState.currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let usersRequest = appState.client.fetchUsers()
            async let memberIdsRequest = appState.client.fetchChatMemberUserIds(chatId: chat.id)
            let (loadedUsers, memberIds) = try await (usersRequest, memberIdsRequest)
            users = loadedUsers.sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
            existingMemberIds = Set(memberIds)
            existingMemberIds.insert(currentUser.id)
        } catch {
            users = []
            existingMemberIds = []
        }
    }

    private func addMembers() async {
        isSaving = true
        defer { isSaving = false }
        let ok = await viewModel.addMembers(
            chatId: chat.id,
            userIds: Array(selectedUserIds),
            currentUser: appState.currentUser
        )
        if ok {
            dismiss()
        }
    }

    private func displayName(_ user: User) -> String {
        let name = user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return email.isEmpty ? "Пользователь" : email
    }

    private func binding(for userId: String) -> Binding<Bool> {
        Binding(
            get: { selectedUserIds.contains(userId) },
            set: { isSelected in
                if isSelected {
                    selectedUserIds.insert(userId)
                } else {
                    selectedUserIds.remove(userId)
                }
            }
        )
    }
}
