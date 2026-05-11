import Foundation
import Combine

@MainActor
final class PurchaseRequestsViewModel: ObservableObject {
    @Published private(set) var items: [PurchaseRequest] = []
    @Published private(set) var materialPreviewByRequestId: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    private var client: SupabaseClient?

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load() async {
        guard let client else {
            errorText = "Client is not configured"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            items = try await client.fetchPurchaseRequests()
            await loadMaterialPreviews(for: items)
        } catch {
            errorText = error.localizedDescription
        }
    }

    func create(payload: PurchaseRequestUpsertPayload, materialLines: [PurchaseRequestDraftMaterialLine] = []) async -> Bool {
        guard let client else { return false }
        errorText = nil
        do {
            let created = try await client.createPurchaseRequest(payload)
            var itemInsertFailed = false
            for line in materialLines {
                do {
                    try await client.createPurchaseRequestItem(
                        requestId: created.id,
                        materialId: line.materialId,
                        materialName: line.materialName,
                        quantity: line.quantity,
                        unit: line.unit.isEmpty ? nil : line.unit
                    )
                } catch {
                    itemInsertFailed = true
                }
            }

            items.insert(created, at: 0)
            materialPreviewByRequestId[created.id] = materialLines.isEmpty ? "" : formatPreview(lines: materialLines)
            await notifyManagersAboutNewRequest(
                created: created,
                senderId: payload.createdBy,
                materialCount: materialLines.count
            )
            if itemInsertFailed {
                errorText = "Request created, but some material rows were not saved."
            }
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    func updateStatus(item: PurchaseRequest, to status: PurchaseRequestStatus, currentUserId: String?) async -> Bool {
        await updateFields(
            item: item,
            status: status,
            comment: item.comment ?? "",
            receiptAddress: item.receiptAddress ?? "",
            currentUserId: currentUserId
        )
    }

    func updateFields(
        item: PurchaseRequest,
        status: PurchaseRequestStatus,
        comment: String,
        receiptAddress: String,
        currentUserId: String?
    ) async -> Bool {
        guard let client else { return false }
        errorText = nil
        do {
            let previousStatus = item.status?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let wasReceived = item.status == PurchaseRequestStatus.received.rawValue
            var patch: [String: JSONValue] = [
                "status": .string(status.rawValue),
                "comment": .string(comment.trimmingCharacters(in: .whitespacesAndNewlines)),
                "receipt_address": .string(receiptAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            ]

            if status == .received && (item.receivedAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                patch["received_at"] = .string(ISO8601DateFormatter().string(from: Date()))
            }
            if status == .approved || status == .inOrder || status == .readyForReceipt {
                if let currentUserId, !currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    patch["approved_by"] = .string(currentUserId)
                }
            }

            try await client.updatePurchaseRequestFields(id: item.id, patch: patch)
            if status == .received && !wasReceived {
                try await applyReceivedMaterialsToWarehouse(for: item, currentUserId: currentUserId)
            }
            if previousStatus != status.rawValue {
                await notifyStatusChanged(item: item, newStatus: status, actorId: currentUserId)
            }
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
            try await client.deletePurchaseRequest(id: id)
            items.removeAll { $0.id == id }
            materialPreviewByRequestId[id] = nil
            return true
        } catch {
            errorText = error.localizedDescription
            return false
        }
    }

    private func applyReceivedMaterialsToWarehouse(for request: PurchaseRequest, currentUserId: String?) async throws {
        guard let client else { return }
        let items = try await client.fetchPurchaseRequestItems(requestId: request.id)
        if items.isEmpty { return }

        let requestLabel = request.shortId.map { "#\($0)" } ?? request.id
        let recipient = parentTargetLabel(for: request)

        for item in items {
            let materialId = (item.materialId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let quantity = item.resolvedQuantity
            if materialId.isEmpty || quantity <= 0 { continue }

            let materialName = item.resolvedMaterialName
            let incomingNote = "Incoming by purchase request \(requestLabel): \(materialName)"
            try await client.addWarehouseStock(
                materialId: materialId,
                quantity: quantity,
                note: incomingNote,
                createdBy: currentUserId
            )

            let outgoingNote = "Issue by purchase request \(requestLabel) to \(recipient)"
            try await client.issueWarehouseStock(
                materialId: materialId,
                quantity: quantity,
                recipient: recipient,
                note: outgoingNote,
                createdBy: currentUserId
            )
        }
    }

    private func parentTargetLabel(for request: PurchaseRequest) -> String {
        if let taskAvrId = request.taskAvrId, !taskAvrId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "avr request \(taskAvrId)"
        }
        if let installationId = request.installationId, !installationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "installation \(installationId)"
        }
        if let taskId = request.taskId, !taskId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "task \(taskId)"
        }
        if let projectId = request.projectId, !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "project \(projectId)"
        }
        return "parent request"
    }

    private func loadMaterialPreviews(for requests: [PurchaseRequest]) async {
        guard let client else { return }
        var previews: [String: String] = [:]
        for request in requests {
            do {
                let rows = try await client.fetchPurchaseRequestItems(requestId: request.id)
                previews[request.id] = formatPreview(items: rows)
            } catch {
                previews[request.id] = nil
            }
        }
        materialPreviewByRequestId = previews
    }

    private func formatPreview(items: [PurchaseRequestItem]) -> String {
        let nonEmpty = items.filter { row in
            row.resolvedQuantity > 0 || !row.resolvedMaterialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if nonEmpty.isEmpty { return "" }
        let head = nonEmpty.prefix(2).map { row in
            let quantity = formatQuantity(row.resolvedQuantity)
            let unit = row.resolvedUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return unit.isEmpty ? "\(row.resolvedMaterialName): \(quantity)" : "\(row.resolvedMaterialName): \(quantity) \(unit)"
        }
        let suffix = nonEmpty.count > 2 ? " +\(nonEmpty.count - 2) more" : ""
        return head.joined(separator: " | ") + suffix
    }

    private func formatPreview(lines: [PurchaseRequestDraftMaterialLine]) -> String {
        let nonEmpty = lines.filter { row in
            row.quantity > 0 && !row.materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if nonEmpty.isEmpty { return "" }
        let head = nonEmpty.prefix(2).map { row in
            let quantity = formatQuantity(row.quantity)
            let unit = row.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            return unit.isEmpty ? "\(row.materialName): \(quantity)" : "\(row.materialName): \(quantity) \(unit)"
        }
        let suffix = nonEmpty.count > 2 ? " +\(nonEmpty.count - 2) more" : ""
        return head.joined(separator: " | ") + suffix
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func notifyStatusChanged(item: PurchaseRequest, newStatus: PurchaseRequestStatus, actorId: String?) async {
        guard let client else { return }
        let cleanActorId = actorId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var targetIds: Set<String> = []
        if let creatorId = item.createdBy?.trimmingCharacters(in: .whitespacesAndNewlines),
           !creatorId.isEmpty,
           creatorId != cleanActorId {
            targetIds.insert(creatorId)
        }

        if let users = try? await client.fetchUsers() {
            for user in users {
                let userId = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
                if userId.isEmpty || userId == cleanActorId { continue }
                let role = user.role
                let manager = role?.hasManagerRights == true || role == .support
                if manager {
                    targetIds.insert(userId)
                }
            }
        }

        if targetIds.isEmpty { return }
        let title = "Purchase request: \(newStatus.displayLabel)"
        let body = requestPushBody(item: item)
        for targetId in targetIds {
            try? await client.sendWorkAlertPush(
                targetUserId: targetId,
                title: title,
                bodyText: body,
                chatId: nil,
                senderId: cleanActorId.isEmpty ? nil : cleanActorId
            )
        }
    }

    private func requestPushBody(item: PurchaseRequest) -> String {
        let shortLabel = item.shortId.map { "#\($0)" } ?? item.id
        let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if title.isEmpty {
            return shortLabel
        }
        return "\(shortLabel) - \(title)"
    }

    private func notifyManagersAboutNewRequest(
        created: PurchaseRequest,
        senderId: String?,
        materialCount: Int
    ) async {
        guard let client else { return }
        let cleanSenderId = senderId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let users = try? await client.fetchUsers() else { return }

        let title = "New purchase request"
        let statusText = created.status == PurchaseRequestStatus.readyForReceipt.rawValue
            ? "ready for receipt"
            : "pending approval"
        let count = materialCount > 0 ? materialCount : 1
        let body = "Status: \(statusText). Positions: \(count)"

        for user in users {
            let targetId = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if targetId.isEmpty || targetId == cleanSenderId { continue }
            let role = user.role
            let manager = role?.hasManagerRights == true || role == .support
            if !manager { continue }
            try? await client.sendWorkAlertPush(
                targetUserId: targetId,
                title: title,
                bodyText: body,
                chatId: nil,
                senderId: cleanSenderId.isEmpty ? nil : cleanSenderId
            )
        }
    }
}
