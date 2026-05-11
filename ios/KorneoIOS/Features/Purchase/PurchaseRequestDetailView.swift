import SwiftUI

struct PurchaseRequestDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: PurchaseRequestsViewModel
    @State var item: PurchaseRequest
    @State private var requestItems: [PurchaseRequestItem] = []

    @State private var isUpdatingStatus = false
    @State private var showEditSheet = false
    @State private var draftStatus: PurchaseRequestStatus = .draft
    @State private var draftComment = ""
    @State private var draftReceiptAddress = ""

    var body: some View {
        List {
            Section("Main") {
                detailRow("Status", statusLabel(for: item.status))
                detailRow("Title", displayTitle)
                detailRow("Comment", item.comment ?? "-")
            }
            Section("Relations") {
                detailRow("Project ID", item.projectId ?? "-")
                detailRow("Installation ID", item.installationId ?? "-")
                detailRow("Task ID", item.taskId ?? "-")
                detailRow("Task AVR ID", item.taskAvrId ?? "-")
            }
            Section("Delivery") {
                detailRow("Receipt address", item.receiptAddress ?? "-")
                detailRow("Received at", shortDate(item.receivedAt) ?? "-")
            }
            Section("Meta") {
                detailRow("Created by", item.createdBy ?? "-")
                detailRow("Approved by", item.approvedBy ?? "-")
                detailRow("Created", shortDate(item.createdAt) ?? "-")
                detailRow("Updated", shortDate(item.updatedAt) ?? "-")
            }

            Section("Materials") {
                if requestItems.isEmpty {
                    if fallbackMaterialsFromComment.isEmpty {
                        Text("No materials")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(fallbackMaterialsFromComment)
                            .font(.caption)
                    }
                } else {
                    ForEach(requestItems) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.resolvedMaterialName)
                            Text(materialSubtitle(for: row))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Comments") {
                CommentsSectionView(
                    entityType: "purchase_request",
                    entityId: item.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
            }

            Section("Status Flow") {
                if allowedTransitions.isEmpty {
                    Text("No further transitions")
                        .foregroundStyle(.secondary)
                } else if !canEdit {
                    Text("Status updates are not allowed for your role")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTransitions) { next in
                        Button(isUpdatingStatus ? "Updating..." : "Move to \(next.displayLabel)") {
                            Task { await changeStatus(next) }
                        }
                        .disabled(isUpdatingStatus)
                    }
                }
            }
        }
        .navigationTitle(displayTitle)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        openEditor()
                    }
                    .disabled(isUpdatingStatus)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("Status") {
                        Picker("Status", selection: $draftStatus) {
                            ForEach(PurchaseRequestStatus.allCases) { status in
                                Text(status.displayLabel).tag(status)
                            }
                        }
                    }
                    Section("Details") {
                        TextField("Comment", text: $draftComment, axis: .vertical)
                            .lineLimit(2...6)
                        TextField("Receipt address", text: $draftReceiptAddress)
                    }
                }
                .navigationTitle("Edit Request")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showEditSheet = false }
                            .disabled(isUpdatingStatus)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isUpdatingStatus ? "Saving..." : "Save") {
                            Task { await saveEditedFields() }
                        }
                        .disabled(isUpdatingStatus)
                    }
                }
            }
        }
        .task {
            await refreshLocal()
        }
    }

    private var displayTitle: String {
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let comment = item.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
            return String(comment.split(separator: "\n").first ?? "Request")
        }
        if let shortId = item.shortId {
            return "Request #\(shortId)"
        }
        return "Request"
    }

    private var fallbackMaterialsFromComment: String {
        guard let comment = item.comment, !comment.isEmpty else { return "" }
        let lines = comment
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                line.hasPrefix("-") || line.lowercased().hasPrefix("materials:")
            }
        return lines.joined(separator: "\n")
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

    private var allowedTransitions: [PurchaseRequestStatus] {
        PurchaseRequestStatus.allowedTransitions(from: item.status)
    }

    private var canEdit: Bool {
        guard let user = appState.currentUser else { return false }
        let manager = user.role?.hasManagerRights == true || user.role == .support
        let creator = user.id == item.createdBy
        return manager || creator
    }

    private func openEditor() {
        draftStatus = PurchaseRequestStatus(rawValue: item.status ?? "") ?? .draft
        draftComment = item.comment ?? ""
        draftReceiptAddress = item.receiptAddress ?? ""
        showEditSheet = true
    }

    private func changeStatus(_ next: PurchaseRequestStatus) async {
        guard canEdit else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        let ok = await viewModel.updateStatus(item: item, to: next, currentUserId: appState.currentUser?.id)
        if ok {
            await refreshLocal()
        }
    }

    private func saveEditedFields() async {
        guard canEdit else { return }
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }

        let ok = await viewModel.updateFields(
            item: item,
            status: draftStatus,
            comment: draftComment,
            receiptAddress: draftReceiptAddress,
            currentUserId: appState.currentUser?.id
        )
        if ok {
            showEditSheet = false
            await refreshLocal()
        }
    }

    private func refreshLocal() async {
        await viewModel.load()
        if let updated = viewModel.items.first(where: { $0.id == item.id }) {
            item = updated
        }
        do {
            requestItems = try await appState.client.fetchPurchaseRequestItems(requestId: item.id)
        } catch {
            requestItems = []
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func materialSubtitle(for row: PurchaseRequestItem) -> String {
        let quantityText = formatQuantity(row.resolvedQuantity)
        let unitText = row.resolvedUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return unitText.isEmpty ? quantityText : "\(quantityText) \(unitText)"
    }

    private func statusLabel(for raw: String?) -> String {
        guard let raw, let status = PurchaseRequestStatus(rawValue: raw) else {
            return raw ?? "-"
        }
        return status.displayLabel
    }

    private func shortDate(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy HH:mm"
        return out.string(from: date)
    }
}
