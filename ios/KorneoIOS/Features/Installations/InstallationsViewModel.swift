import Foundation
import Combine

@MainActor
final class InstallationsViewModel: ObservableObject {
    @Published private(set) var items: [Installation] = []
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private var client: SupabaseClient?

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
            items = try await client.fetchInstallations()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func create(payload: InstallationUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            let created = try await client.createInstallation(payload)
            items.insert(created, at: 0)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func update(id: String, payload: InstallationUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            try await client.updateInstallation(id: id, payload: payload)
            await load()
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func updateStatus(item: Installation, to newStatus: InstallationStatus) async -> Bool {
        let payload = InstallationUpsertPayload(
            projectId: item.projectId,
            title: item.title,
            description: item.description,
            assigneeId: item.assigneeId,
            status: newStatus.rawValue,
            scheduledAt: item.scheduledAt,
            deadline: item.deadline,
            address: item.address,
            createdBy: item.createdBy
        )
        return await update(id: item.id, payload: payload)
    }

    func delete(id: String) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteInstallation(id: id)
            items.removeAll { $0.id == id }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }
}

