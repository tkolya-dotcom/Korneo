import SwiftUI

struct CreateChatSheetView: View {
    private enum ChatType: String, CaseIterable, Identifiable {
        case `private`
        case group

        var id: String { rawValue }

        var title: String {
            switch self {
            case .private: return "Личный"
            case .group: return "Групповой"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ChatsViewModel

    @State private var users: [User] = []
    @State private var isLoadingUsers = false
    @State private var isSaving = false
    @State private var chatType: ChatType = .private
    @State private var privateUserId: String = ""
    @State private var groupName: String = ""
    @State private var groupMemberIds: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                if isLoadingUsers {
                    ProgressView("Загрузка пользователей...")
                }

                Section("Тип") {
                    Picker("Тип чата", selection: $chatType) {
                        ForEach(ChatType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if chatType == .private {
                    Section("Пользователь") {
                        if users.isEmpty {
                            Text("Нет доступных пользователей")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Выберите пользователя", selection: $privateUserId) {
                                ForEach(users) { user in
                                    Text(displayName(user)).tag(user.id)
                                }
                            }
                        }
                    }
                } else {
                    Section("Группа") {
                        TextField("Название группы", text: $groupName)
                        if users.isEmpty {
                            Text("Нет доступных пользователей")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(users) { user in
                                Toggle(displayName(user), isOn: binding(for: user.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Новый чат")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Создание..." : "Создать") {
                        Task { await create() }
                    }
                    .disabled(isSaving || !canCreate)
                }
            }
        }
        .task {
            await loadUsers()
        }
    }

    private var canCreate: Bool {
        if chatType == .private {
            return !privateUserId.isEmpty
        }
        return groupMemberIds.count >= 2
    }

    private func create() async {
        guard let currentUser = appState.currentUser else { return }
        isSaving = true
        defer { isSaving = false }

        let ok: Bool
        if chatType == .private {
            guard let user = users.first(where: { $0.id == privateUserId }) else { return }
            ok = await viewModel.createChat(
                currentUser: currentUser,
                name: displayName(user),
                type: .private,
                memberIds: [user.id]
            )
        } else {
            ok = await viewModel.createChat(
                currentUser: currentUser,
                name: groupName,
                type: .group,
                memberIds: Array(groupMemberIds)
            )
        }

        if ok {
            dismiss()
        }
    }

    private func loadUsers() async {
        guard let currentUserId = appState.currentUser?.id else { return }
        isLoadingUsers = true
        defer { isLoadingUsers = false }
        do {
            let rows = try await appState.client.fetchUsers()
            users = rows
                .filter { $0.id != currentUserId }
                .sorted { displayName($0).localizedCaseInsensitiveCompare(displayName($1)) == .orderedAscending }
            if privateUserId.isEmpty {
                privateUserId = users.first?.id ?? ""
            }
        } catch {
            users = []
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
            get: { groupMemberIds.contains(userId) },
            set: { isSelected in
                if isSelected {
                    groupMemberIds.insert(userId)
                } else {
                    groupMemberIds.remove(userId)
                }
            }
        )
    }
}
