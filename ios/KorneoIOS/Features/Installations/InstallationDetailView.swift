import SwiftUI

struct InstallationDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    @State var item: Installation
    @State private var showEditSheet = false
    @State private var isUpdatingStatus = false

    var body: some View {
        List {
            Section("Main") {
                detailRow("Title", item.title ?? "-")
                detailRow("Status", item.status ?? "-")
                detailRow("Address", item.address ?? "-")
                detailRow("Description", item.description ?? "-")
            }

            Section("Relations") {
                detailRow("Project ID", item.projectId ?? "-")
                detailRow("Assignee ID", item.assigneeId ?? "-")
                detailRow("Created By", item.createdBy ?? "-")
            }

            Section("Schedule") {
                detailRow("Scheduled", item.scheduledAt ?? "-")
                detailRow("Deadline", item.deadline ?? "-")
                detailRow("Completed", item.actualCompletionDate ?? "-")
            }

            Section("Comments") {
                CommentsSectionView(
                    entityType: "installation",
                    entityId: item.id,
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
        .navigationTitle(item.title ?? "Installation")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            InstallationFormView(viewModel: viewModel, mode: .edit(item))
                .environmentObject(appState)
        }
        .onChange(of: showEditSheet) { isShown in
            if !isShown {
                Task { await refreshLocalItem() }
            }
        }
        .task {
            await refreshLocalItem()
        }
    }

    private var allowedTransitions: [InstallationStatus] {
        InstallationStatus.allowedTransitions(from: item.status)
    }

    private var canEdit: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role != .engineer
    }

    private var canChangeStatus: Bool {
        canEdit
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

    private func changeStatus(_ next: InstallationStatus) async {
        guard canChangeStatus else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        let ok = await viewModel.updateStatus(item: item, to: next)
        if ok {
            await refreshLocalItem()
        }
    }

    private func refreshLocalItem() async {
        await viewModel.load()
        if let updated = viewModel.items.first(where: { $0.id == item.id }) {
            item = updated
        }
    }
}
