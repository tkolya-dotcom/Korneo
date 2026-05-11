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
            Section("Основное") {
                detailRow("Статус", statusLabel(for: item.status))
                detailRow("Заголовок", displayTitle)
                detailRow("Комментарий", item.comment ?? "-")
            }
            Section("Связи") {
                detailRow("Проект ID", item.projectId ?? "-")
                detailRow("Монтаж ID", item.installationId ?? "-")
                detailRow("Задача ID", item.taskId ?? "-")
                detailRow("АВР задача ID", item.taskAvrId ?? "-")
            }
            Section("Доставка") {
                detailRow("Адрес получения", item.receiptAddress ?? "-")
                detailRow("Получено", shortDate(item.receivedAt) ?? "-")
            }
            Section("Служебное") {
                detailRow("Создал", item.createdBy ?? "-")
                detailRow("Согласовал", item.approvedBy ?? "-")
                detailRow("Создано", shortDate(item.createdAt) ?? "-")
                detailRow("Обновлено", shortDate(item.updatedAt) ?? "-")
            }

            Section("Материалы") {
                if requestItems.isEmpty {
                    if fallbackMaterialsFromComment.isEmpty {
                        Text("Материалы не добавлены")
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

            Section("Комментарии") {
                CommentsSectionView(
                    entityType: "purchase_request",
                    entityId: item.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
            }

            Section("Статусы") {
                if allowedTransitions.isEmpty {
                    Text("Нет доступных переходов")
                        .foregroundStyle(.secondary)
                } else if !canEdit {
                    Text("Для вашей роли изменение статуса недоступно")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allowedTransitions) { next in
                        Button(isUpdatingStatus ? "Обновляем..." : "Перевести в «\(next.displayLabel)»") {
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
                    Button("Изменить") {
                        openEditor()
                    }
                    .disabled(isUpdatingStatus)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    Section("Статус") {
                        Picker("Статус", selection: $draftStatus) {
                            ForEach(PurchaseRequestStatus.allCases) { status in
                                Text(status.displayLabel).tag(status)
                            }
                        }
                    }
                    Section("Детали") {
                        TextField("Комментарий", text: $draftComment, axis: .vertical)
                            .lineLimit(2...6)
                        TextField("Адрес получения", text: $draftReceiptAddress)
                    }
                }
                .navigationTitle("Редактирование")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Отмена") { showEditSheet = false }
                            .disabled(isUpdatingStatus)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isUpdatingStatus ? "Сохраняем..." : "Сохранить") {
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
            return String(comment.split(separator: "\n").first ?? "Заявка")
        }
        if let shortId = item.shortId {
            return "Заявка #\(shortId)"
        }
        return "Заявка"
    }

    private var fallbackMaterialsFromComment: String {
        guard let comment = item.comment, !comment.isEmpty else { return "" }
        let lines = comment
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let lower = line.lowercased()
                return line.hasPrefix("-") || lower.hasPrefix("materials:") || lower.hasPrefix("материалы:")
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
        item.canEdit(using: appState.currentUser)
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
