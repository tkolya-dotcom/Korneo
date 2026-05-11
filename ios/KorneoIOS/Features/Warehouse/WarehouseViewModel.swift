import Foundation
import Combine

@MainActor
final class WarehouseViewModel: ObservableObject {
    enum AvailabilityFilter: String, CaseIterable, Identifiable {
        case all
        case available
        case empty

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Все"
            case .available: return "В наличии"
            case .empty: return "Нет на складе"
            }
        }
    }

    struct IssueDraft {
        let materialId: String
        let quantity: Double
        let recipient: String
        let note: String
    }

    @Published private(set) var materials: [Material] = []
    @Published private(set) var stockByMaterialId: [String: Double] = [:]
    @Published private(set) var stockRows: [GenericRecord] = []
    @Published private(set) var historyRows: [GenericRecord] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isMutating = false
    @Published var errorText: String?
    @Published var infoText: String?

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
            async let materialsReq = client.fetchMaterials()
            async let stock = client.fetchWarehouseStock()
            async let history = client.fetchWarehouseHistory()
            materials = try await materialsReq
            stockRows = try await stock
            historyRows = try await history
            rebuildStockIndex()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func restock(
        materialId: String,
        quantity: Double,
        note: String,
        createdBy: String?
    ) async -> Bool {
        guard let client else { return false }
        let cleanMaterialId = materialId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMaterialId.isEmpty, quantity > 0 else {
            errorText = "Выберите материал и количество"
            return false
        }
        isMutating = true
        defer { isMutating = false }
        do {
            try await client.addWarehouseStock(
                materialId: cleanMaterialId,
                quantity: quantity,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                createdBy: createdBy
            )
            infoText = "Пополнение выполнено"
            await load()
            return true
        } catch {
            errorText = "Ошибка пополнения: \(error.localizedDescription)"
            return false
        }
    }

    func issue(
        draft: IssueDraft,
        createdBy: String?
    ) async -> Bool {
        guard let client else { return false }
        let materialId = draft.materialId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !materialId.isEmpty, draft.quantity > 0 else {
            errorText = "Выберите материал и количество"
            return false
        }

        let availableBefore = stockByMaterialId[materialId] ?? 0
        let shortage = max(0, draft.quantity - availableBefore)

        isMutating = true
        defer { isMutating = false }
        do {
            try await client.issueWarehouseStock(
                materialId: materialId,
                quantity: draft.quantity,
                recipient: draft.recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.recipient,
                note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.note,
                createdBy: createdBy
            )
            if shortage > 0 {
                try await createAutoPurchaseRequestForShortage(
                    materialId: materialId,
                    shortage: shortage,
                    recipient: draft.recipient,
                    note: draft.note,
                    createdBy: createdBy
                )
                infoText = "Выдача выполнена. Автодозаказ создан."
            } else {
                infoText = "Выдача выполнена"
            }
            await load()
            return true
        } catch {
            errorText = "Ошибка выдачи: \(error.localizedDescription)"
            return false
        }
    }

    func addMaterial(
        name: String,
        category: String,
        unit: String,
        minStockText: String
    ) async -> Bool {
        guard let client else { return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorText = "Введите название"
            return false
        }
        let minStock = parsePositiveDouble(minStockText)

        isMutating = true
        defer { isMutating = false }
        do {
            try await client.createMaterial(
                name: cleanName,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category,
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : unit,
                minStock: minStock
            )
            infoText = "Материал создан"
            await load()
            return true
        } catch {
            errorText = "Ошибка создания: \(error.localizedDescription)"
            return false
        }
    }

    func availableQuantity(for materialId: String) -> Double {
        stockByMaterialId[materialId] ?? 0
    }

    func materialName(for materialId: String) -> String {
        if let material = materials.first(where: { $0.id == materialId }) {
            return material.resolvedName
        }
        return materialId
    }

    private func rebuildStockIndex() {
        var map: [String: Double] = [:]
        for row in stockRows {
            let materialId = clean(row.fields["material_id"]?.textValue)
            if materialId.isEmpty { continue }

            let quantity = firstDouble(
                row.fields["quantity_available"]?.textValue,
                row.fields["total_quantity"]?.textValue,
                row.fields["quantity"]?.textValue
            )
            guard let quantity else { continue }
            map[materialId, default: 0] += quantity
        }
        stockByMaterialId = map
    }

    private func createAutoPurchaseRequestForShortage(
        materialId: String,
        shortage: Double,
        recipient: String,
        note: String,
        createdBy: String?
    ) async throws {
        guard let client, shortage > 0 else { return }

        let material = materials.first(where: { $0.id == materialId })
        let materialName = material?.resolvedName ?? materialId
        let recipientPart = recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : ". Получатель: \(recipient.trimmingCharacters(in: .whitespacesAndNewlines))"
        let notePart = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : ". Комментарий: \(note.trimmingCharacters(in: .whitespacesAndNewlines))"

        let payload = PurchaseRequestUpsertPayload(
            status: "approved",
            installationId: nil,
            taskId: nil,
            taskAvrId: nil,
            projectId: nil,
            createdBy: createdBy,
            comment: "Автоматическая заявка: склад ушел в минус на \(formatQuantity(shortage))\(recipientPart)\(notePart)",
            receiptAddress: nil,
            title: "Дозаказ: \(materialName)"
        )
        let created = try await client.createPurchaseRequest(payload)

        try await client.createPurchaseRequestItem(
            requestId: created.id,
            materialId: materialId,
            materialName: materialName,
            quantity: shortage,
            unit: material?.resolvedUnit.isEmpty == true ? nil : material?.resolvedUnit
        )
    }

    private func parsePositiveDouble(_ raw: String) -> Double? {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !clean.isEmpty, let value = Double(clean), value > 0 else { return nil }
        return value
    }

    private func firstDouble(_ values: String?...) -> Double? {
        for value in values {
            let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".") ?? ""
            if clean.isEmpty { continue }
            if let parsed = Double(clean) {
                return parsed
            }
        }
        return nil
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    private func clean(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.lowercased() == "null" ? "" : raw
    }
}

