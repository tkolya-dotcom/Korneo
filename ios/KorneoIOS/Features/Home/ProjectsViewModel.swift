import Foundation
import Combine

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
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
            projects = try await client.fetchProjects()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func create(payload: ProjectUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            let created = try await client.createProject(payload)
            projects.insert(created, at: 0)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func update(id: String, payload: ProjectUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            try await client.updateProject(id: id, payload: payload)
            await load()
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func delete(id: String) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteProject(id: id)
            projects.removeAll { $0.id == id }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }
}

