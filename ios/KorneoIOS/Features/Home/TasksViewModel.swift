import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
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
            tasks = try await client.fetchTasks()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func create(payload: TaskUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            let created = try await client.createTask(payload)
            tasks.insert(created, at: 0)
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func update(id: String, payload: TaskUpsertPayload) async -> Bool {
        guard let client else { return false }
        do {
            try await client.updateTask(id: id, payload: payload)
            await load()
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func updateStatus(task: TaskItem, to status: TaskStatus) async -> Bool {
        guard let client else { return false }
        do {
            try await client.updateTaskStatus(id: task.id, status: status)
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
            try await client.deleteTask(id: id)
            tasks.removeAll { $0.id == id }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }
}

