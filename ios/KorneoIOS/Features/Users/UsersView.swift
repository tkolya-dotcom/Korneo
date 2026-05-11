import SwiftUI

struct UsersView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UsersViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Loading users...")
            } else if let error = viewModel.errorText, viewModel.users.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List(filteredUsers) { user in
                    NavigationLink {
                        UserDetailView(user: user)
                    } label: {
                        UserRowView(user: user)
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search user")
        .navigationTitle("Users")
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
    }

    private var filteredUsers: [User] {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !search.isEmpty else { return viewModel.users }
        return viewModel.users.filter { user in
            let name = (user.name ?? "").lowercased()
            let email = (user.email ?? "").lowercased()
            let role = (user.role?.rawValue ?? "").lowercased()
            let phone = (user.phone ?? "").lowercased()
            return name.contains(search) || email.contains(search) || role.contains(search) || phone.contains(search)
        }
    }
}

private struct UserRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(avatarURL: user.avatarUrl, name: user.name ?? user.email ?? "")
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text(roleTitle(user.role))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func roleTitle(_ role: Role?) -> String {
        switch role {
        case .manager: return "Manager"
        case .worker: return "Worker"
        case .engineer: return "Engineer"
        case .support: return "Support"
        case .deputyHead: return "Deputy Head"
        case .admin: return "Admin"
        case nil: return "Unknown"
        }
    }

    private var displayName: String {
        let clean = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? (user.email ?? "User") : clean
    }
}

private struct UserDetailView: View {
    let user: User

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    UserAvatarView(avatarURL: user.avatarUrl, name: user.name ?? user.email ?? "", size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.headline)
                        Text(roleTitle(user.role))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Profile") {
                userRow("Email", user.email)
                userRow("Phone", user.phone)
                userRow("Role", roleTitle(user.role))
                userRow("Created", formatDateTime(user.createdAt))
                userRow("User ID", user.id)
            }
        }
        .navigationTitle("User")
    }

    private var displayName: String {
        let clean = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? (user.email ?? "-") : clean
    }

    private func userRow(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(safeValue(value))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func safeValue(_ value: String?) -> String {
        let clean = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
    }

    private func roleTitle(_ role: Role?) -> String {
        switch role {
        case .manager: return "Manager"
        case .worker: return "Worker"
        case .engineer: return "Engineer"
        case .support: return "Support"
        case .deputyHead: return "Deputy Head"
        case .admin: return "Admin"
        case nil: return "-"
        }
    }

    private func formatDateTime(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "-" }
        let normalized = value.replacingOccurrences(of: "Z", with: "+00:00")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            parser.dateFormat = format
            if let date = parser.date(from: normalized) {
                let output = DateFormatter()
                output.locale = Locale(identifier: "ru_RU")
                output.dateFormat = "dd.MM.yyyy HH:mm"
                return output.string(from: date)
            }
        }
        return value
    }
}

private struct UserAvatarView: View {
    let avatarURL: String?
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url = validURL(avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                }
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Text(initials(from: name))
                            .font(.system(size: size * 0.35, weight: .semibold))
                            .foregroundStyle(.primary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func validURL(_ raw: String?) -> URL? {
        let text = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return URL(string: text)
    }

    private func initials(from raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "?" }
        let parts = value.split(separator: " ").map(String.init)
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
