import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: TasksViewModel
    @State var task: TaskItem
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false

    var body: some View {
        List {
            Section("Main") {
                detailRow("Title", task.title ?? "-")
                detailRow("Status", task.status ?? "-")
                detailRow("Description", task.description ?? "-")
            }
            Section("Relations") {
                detailRow("Project ID", task.projectId ?? "-")
                detailRow("Assignee ID", task.assigneeId ?? "-")
                detailRow("Created By", task.createdBy ?? "-")
            }
            Section("Dates") {
                detailRow("Due date", task.dueDate ?? "-")
                detailRow("Created", task.createdAt ?? "-")
                detailRow("Updated", task.updatedAt ?? "-")
            }

            Section("Comments") {
                CommentsSectionView(
                    entityType: "task",
                    entityId: task.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
            }

            Section("Status Flow") {
                if allowedTransitions.isEmpty {
                    Text("No further transitions")
                        .foregroundStyle(.secondary)
                } else if !canChangeStatus {
                    Text("Status updates are not allowed for your role")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTransitions) { next in
                        Button(isUpdatingStatus ? "Updating..." : "Move to \(next.rawValue)") {
                            Task { await changeStatus(next) }
                        }
                        .disabled(isUpdatingStatus)
                    }
                }
            }
        }
        .navigationTitle(task.title ?? "Task")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Edit") { showEditSheet = true }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TaskFormView(viewModel: viewModel, mode: .edit(task))
                .environmentObject(appState)
        }
        .onChange(of: showEditSheet) { isShown in
            if !isShown {
                Task { await refreshLocal() }
            }
        }
        .task {
            await refreshLocal()
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
    }

    private var allowedTransitions: [TaskStatus] {
        TaskStatus.allowedTransitions(from: task.status)
    }

    private var canChangeStatus: Bool {
        canEdit
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
    }

    private func changeStatus(_ next: TaskStatus) async {
        guard canChangeStatus else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        let ok = await viewModel.updateStatus(task: task, to: next)
        if ok {
            await refreshLocal()
        }
    }

    private func refreshLocal() async {
        await viewModel.load()
        if let updated = viewModel.tasks.first(where: { $0.id == task.id }) {
            task = updated
        }
    }
}
