import SwiftUI
import PhotosUI
import CoreLocation
import UIKit

private final class ProfileLocationPermissionHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
}

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var locationPermission = ProfileLocationPermissionHelper()

    @AppStorage("korneo.profile.geo.enabled") private var geoEnabled = false

    @State private var showConnectionSettings = false
    @State private var isSaving = false
    @State private var isRefreshing = false
    @State private var saveErrorText: String?
    @State private var saveInfoText: String?

    @State private var nameDraft = ""
    @State private var emailDraft = ""
    @State private var phoneDraft = ""
    @State private var notificationsEnabled = true

    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarUploadData: Data?
    @State private var avatarPreviewImage: UIImage?

    var body: some View {
        NavigationStack {
            List {
                Section("Профиль") {
                    HStack(spacing: 12) {
                        avatarView
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                                Label("Выбрать аватар", systemImage: "photo")
                            }
                            .buttonStyle(.bordered)

                            if avatarUploadData != nil {
                                Text("Новый аватар готов к сохранению")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    TextField("Имя", text: $nameDraft)
                    TextField("Email", text: $emailDraft)
                        .disabled(true)
                        .foregroundStyle(.secondary)
                    TextField("Телефон", text: $phoneDraft)
                        .keyboardType(.phonePad)

                    Toggle("Уведомления", isOn: $notificationsEnabled)
                    Toggle("Геолокация", isOn: $geoEnabled)
                        .onChange(of: geoEnabled) { _, newValue in
                            if newValue {
                                locationPermission.requestWhenInUseAuthorization()
                            }
                        }
                }

                Section("Информация") {
                    profileRow("Роль", appState.currentUser?.role?.rawValue ?? "-")
                    profileRow("Создан", formatDate(appState.currentUser?.createdAt))
                    profileRow("Последняя активность", formatDate(appState.currentUser?.lastSeenAt))
                    profileRow("User ID", appState.currentUser?.id ?? "-")
                }

                Section("Backend") {
                    profileRow("URL", appState.connectionConfig.baseURL)
                    profileRow("Daichi token", appState.connectionConfig.daichiToken.isEmpty ? "-" : "Configured")
                    Button("Настройки подключения") {
                        showConnectionSettings = true
                    }
                }

                if let info = saveInfoText, !info.isEmpty {
                    Section {
                        Text(info)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = saveErrorText, !error.isEmpty {
                    Section("Ошибка") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSaving ? "Сохранение..." : "Сохранить профиль") {
                        Task { await saveProfile() }
                    }
                    .disabled(isSaving || !canSaveProfile)

                    Button(isRefreshing ? "Синхронизация..." : "Синхронизировать") {
                        Task { await refreshCurrentUser() }
                    }
                    .disabled(isRefreshing)

                    Button("Выйти", role: .destructive) {
                        appState.signOut()
                    }
                }
            }
            .navigationTitle("Профиль")
            .refreshable {
                await refreshCurrentUser()
            }
        }
        .sheet(isPresented: $showConnectionSettings) {
            ConnectionSettingsView()
                .environmentObject(appState)
        }
        .onAppear {
            syncDraftsFromCurrentUser()
        }
        .onChange(of: appState.currentUser?.id) { _, _ in
            syncDraftsFromCurrentUser()
        }
        .onChange(of: avatarPickerItem) { _, newValue in
            guard let newValue else { return }
            Task {
                await loadAvatar(from: newValue)
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let preview = avatarPreviewImage {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
            } else if let url = validURL(appState.currentUser?.avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.18))
            Text(initials)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private var initials: String {
        let raw = (nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (emailDraft) : nameDraft)
        let parts = raw
            .split(separator: " ")
            .map { String($0.prefix(1)).uppercased() }
        if parts.isEmpty, let first = raw.first {
            return String(first).uppercased()
        }
        return parts.prefix(2).joined()
    }

    private var canSaveProfile: Bool {
        let nameChanged = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (appState.currentUser?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneChanged = phoneDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (appState.currentUser?.phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let notificationsChanged = notificationsEnabled != (appState.currentUser?.notificationEnabled ?? true)
        let avatarChanged = avatarUploadData != nil
        return nameChanged || phoneChanged || notificationsChanged || avatarChanged
    }

    private func syncDraftsFromCurrentUser() {
        let user = appState.currentUser
        nameDraft = user?.name ?? ""
        emailDraft = user?.email ?? ""
        phoneDraft = user?.phone ?? ""
        notificationsEnabled = user?.notificationEnabled ?? true
        if avatarUploadData == nil {
            avatarPreviewImage = nil
        }
    }

    private func saveProfile() async {
        guard let user = appState.currentUser else { return }
        isSaving = true
        saveErrorText = nil
        saveInfoText = nil
        defer { isSaving = false }

        do {
            var avatarURLToSave: String?
            if let data = avatarUploadData {
                avatarURLToSave = try await appState.client.uploadUserAvatar(
                    userId: user.id,
                    contentType: "image/jpeg",
                    data: data
                )
            }

            _ = try await appState.client.updateUserProfile(
                userId: user.id,
                name: nameDraft,
                phone: phoneDraft,
                avatarURL: avatarURLToSave,
                notificationEnabled: notificationsEnabled
            )

            avatarUploadData = nil
            avatarPickerItem = nil
            avatarPreviewImage = nil
            await refreshCurrentUser()
            saveInfoText = "Профиль сохранен"
        } catch {
            saveErrorText = error.localizedDescription
        }
    }

    private func refreshCurrentUser() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await appState.bootstrapCurrentUser()
        saveInfoText = "Данные синхронизированы"
    }

    private func loadAvatar(from item: PhotosPickerItem) async {
        do {
            guard let rawData = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: rawData),
                  let jpeg = image.jpegData(compressionQuality: 0.86) else {
                return
            }
            avatarPreviewImage = UIImage(data: jpeg)
            avatarUploadData = jpeg
        } catch {
            saveErrorText = error.localizedDescription
        }
    }

    private func profileRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func validURL(_ raw: String?) -> URL? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return URL(string: clean)
    }

    private func formatDate(_ raw: String?) -> String {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return "-" }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let date = isoFractional.date(from: clean) ?? iso.date(from: clean)
        guard let date else { return clean }

        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy HH:mm"
        return out.string(from: date)
    }
}
