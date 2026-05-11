import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var projectsCount = 0
    @Published private(set) var tasksCount = 0
    @Published private(set) var installationsCount = 0
    @Published private(set) var purchaseRequestsCount = 0
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private var client: SupabaseClient?

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load(currentUser: User?) async {
        guard let client else {
            errorText = "Клиент Supabase не настроен"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            async let projects = client.fetchProjects()
            async let tasks = client.fetchTasks()
            async let installations = client.fetchInstallations()
            async let requests = client.fetchPurchaseRequests()

            let projectsItems = try await projects
            let taskItems = try await tasks
            let installationItems = try await installations
            let requestItems = try await requests

            projectsCount = projectsItems.count
            tasksCount = visibleTasksCount(taskItems, currentUser: currentUser)
            installationsCount = visibleInstallationsCount(installationItems, currentUser: currentUser)
            purchaseRequestsCount = requestItems.count
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func visibleTasksCount(_ tasks: [TaskItem], currentUser: User?) -> Int {
        guard let currentUser else { return 0 }
        if currentUser.role?.hasCoordinatorRights == true {
            return tasks.count
        }
        let myId = currentUser.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myId.isEmpty else { return 0 }
        return tasks.filter { ($0.assigneeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == myId }.count
    }

    private func visibleInstallationsCount(_ installations: [Installation], currentUser: User?) -> Int {
        guard let currentUser else { return 0 }
        if currentUser.role?.hasCoordinatorRights == true {
            return installations.count
        }
        let myId = currentUser.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myId.isEmpty else { return 0 }
        return installations.filter { ($0.assigneeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == myId }.count
    }
}

