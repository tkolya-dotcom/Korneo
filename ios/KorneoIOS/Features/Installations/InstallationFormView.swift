import SwiftUI

struct InstallationFormView: View {
    enum Mode {
        case create
        case edit(Installation)

        var title: String {
            switch self {
            case .create: return "New Installation"
            case .edit: return "Edit Installation"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: InstallationsViewModel
    let mode: Mode

    @State private var title = ""
    @State private var details = ""
    @State private var address = ""
    @State private var projectId = ""
    @State private var assigneeId = ""
    @State private var scheduledAt = ""
    @State private var deadline = ""
    @State private var status: InstallationStatus = .new
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Main") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Address", text: $address)
                }

                Section("Relations") {
                    TextField("Project ID", text: $projectId)
                        .textInputAutocapitalization(.never)
                    TextField("Assignee ID", text: $assigneeId)
                        .textInputAutocapitalization(.never)
                }

                Section("Dates") {
                    TextField("Scheduled at (ISO)", text: $scheduledAt)
                    TextField("Deadline (ISO)", text: $deadline)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(InstallationStatus.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                if let error = viewModel.errorText {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            fillFromMode()
        }
    }

    private func fillFromMode() {
        guard case let .edit(item) = mode else { return }
        title = item.title ?? ""
        details = item.description ?? ""
        address = item.address ?? ""
        projectId = item.projectId ?? ""
        assigneeId = item.assigneeId ?? ""
        scheduledAt = item.scheduledAt ?? ""
        deadline = item.deadline ?? ""
        status = InstallationStatus(rawValue: item.status ?? "") ?? .new
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let payload = InstallationUpsertPayload(
            projectId: nilIfBlank(projectId),
            title: nilIfBlank(title),
            description: nilIfBlank(details),
            assigneeId: nilIfBlank(assigneeId),
            status: status.rawValue,
            scheduledAt: nilIfBlank(scheduledAt),
            deadline: nilIfBlank(deadline),
            address: nilIfBlank(address),
            createdBy: appState.currentUser?.id
        )

        let ok: Bool
        switch mode {
        case .create:
            ok = await viewModel.create(payload: payload)
        case let .edit(item):
            ok = await viewModel.update(id: item.id, payload: payload)
        }

        if ok {
            dismiss()
        }
    }

    private func nilIfBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
