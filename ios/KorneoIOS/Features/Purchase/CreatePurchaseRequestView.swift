import SwiftUI

struct CreatePurchaseRequestView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PurchaseRequestsViewModel
    private let initialParentTypeRaw: String?
    private let initialParentId: String?
    private let initialReceiptAddress: String?

    @State private var parentType: ParentType = .none
    @State private var parentOptions: [ParentOption] = [ParentOption(type: .none, id: "", label: "Без привязки", address: "")]
    @State private var selectedParentId = ""

    @State private var urgency: UrgencyLevel = .normal
    @State private var comment = ""
    @State private var receiptAddress = ""

    @State private var materialQuery = ""
    @State private var selectedMaterial: Material?
    @State private var quantityText = ""
    @State private var materialSuggestions: [Material] = []
    @State private var materialLines: [PurchaseRequestDraftMaterialLine] = []

    @State private var projects: [Project] = []
    @State private var tasks: [TaskItem] = []
    @State private var installations: [Installation] = []
    @State private var avrRows: [GenericRecord] = []

    @State private var isLoadingContext = false
    @State private var isSaving = false
    @State private var localErrorText: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var suppressNextMaterialSearch = false
    @State private var didApplyInitialParent = false

    init(
        viewModel: PurchaseRequestsViewModel,
        initialParentTypeRaw: String? = nil,
        initialParentId: String? = nil,
        initialReceiptAddress: String? = nil
    ) {
        self.viewModel = viewModel
        self.initialParentTypeRaw = initialParentTypeRaw
        self.initialParentId = initialParentId
        self.initialReceiptAddress = initialReceiptAddress
    }

    var body: some View {
        NavigationStack {
            Form {
                if let localErrorText {
                    Section("Ошибка") {
                        Text(localErrorText)
                            .foregroundStyle(.red)
                    }
                }

                Section("Привязка") {
                    Picker("Тип", selection: $parentType) {
                        ForEach(ParentType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .onChange(of: parentType) { _ in
                        rebuildParentOptions()
                    }

                    Picker("Связано с", selection: $selectedParentId) {
                        ForEach(parentOptions) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                }

                Section("Детали") {
                    Picker("Срочность", selection: $urgency) {
                        ForEach(UrgencyLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    TextField("Адрес получения", text: $receiptAddress)
                    TextField("Комментарий", text: $comment, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Материалы") {
                    TextField("Поиск материала", text: $materialQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .onChange(of: materialQuery) { value in
                            scheduleMaterialSearch(query: value)
                        }

                    if !materialSuggestions.isEmpty {
                        ForEach(materialSuggestions) { material in
                            Button {
                                selectMaterial(material)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(material.resolvedName)
                                    Text(material.id + (material.resolvedUnit.isEmpty ? "" : " (\(material.resolvedUnit))"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let selectedMaterial {
                        Text("Выбрано: \(selectedMaterial.resolvedName) [\(selectedMaterial.id)]")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Количество", text: $quantityText)
                        .keyboardType(.decimalPad)

                    Button("Добавить материал") {
                        _ = appendCurrentMaterialLine(showError: true)
                    }

                    if materialLines.isEmpty {
                        Text("Материалы не добавлены")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(materialLines) { line in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.materialName)
                                Text("\(formatQuantity(line.quantity)) \(line.unit.isEmpty ? "" : line.unit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            materialLines.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .disabled(isSaving || isLoadingContext)
            .overlay {
                if isSaving || isLoadingContext {
                    ProgressView(isSaving ? "Сохранение..." : "Загрузка...")
                }
            }
            .navigationTitle("Новая заявка")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Сохранение..." : "Сохранить") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task {
            await loadContext()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func loadContext() async {
        isLoadingContext = true
        defer { isLoadingContext = false }
        localErrorText = nil

        do {
            async let projectsRequest = appState.client.fetchProjects()
            async let tasksRequest = appState.client.fetchTasks()
            async let installationsRequest = appState.client.fetchInstallations()
            async let avrRequest = appState.client.fetchTableRows(
                table: "tasks_avr",
                select: "id,title,name,type,address,address_text,adres",
                order: "created_at.desc.nullslast",
                limit: 400
            )

            projects = try await projectsRequest
            tasks = try await tasksRequest
            installations = try await installationsRequest
            avrRows = try await avrRequest
            rebuildParentOptions()
            applyInitialParentSelectionIfNeeded()
        } catch {
            localErrorText = error.localizedDescription
        }
    }

    private func rebuildParentOptions() {
        var next: [ParentOption] = [ParentOption(type: parentType, id: "", label: "Без привязки", address: "")]

        switch parentType {
        case .none:
            break
        case .project:
            for project in projects {
                let id = clean(project.id)
                if id.isEmpty { continue }
                let label = labelWithAddress(title: clean(project.name), address: clean(project.address), fallback: "Проект \(id)")
                next.append(ParentOption(type: .project, id: id, label: label, address: clean(project.address)))
            }
        case .task:
            for task in tasks {
                let id = clean(task.id)
                if id.isEmpty { continue }
                let label = labelWithAddress(title: clean(task.title), address: clean(task.description), fallback: "Задача \(id)")
                next.append(ParentOption(type: .task, id: id, label: label, address: ""))
            }
        case .installation:
            for installation in installations {
                let id = clean(installation.id)
                if id.isEmpty { continue }
                let label = labelWithAddress(title: clean(installation.title), address: clean(installation.address), fallback: "Монтаж \(id)")
                next.append(ParentOption(type: .installation, id: id, label: label, address: clean(installation.address)))
            }
        case .avr:
            for row in avrRows {
                let id = clean(row.fields["id"]?.textValue)
                if id.isEmpty { continue }
                let title = firstNonBlank([
                    row.fields["title"]?.textValue,
                    row.fields["name"]?.textValue,
                    row.fields["type"]?.textValue,
                    "AVR \(id)"
                ])
                let address = firstNonBlank([
                    row.fields["address"]?.textValue,
                    row.fields["address_text"]?.textValue,
                    row.fields["adres"]?.textValue,
                    ""
                ])
                next.append(ParentOption(type: .avr, id: id, label: labelWithAddress(title: title, address: address, fallback: "AVR \(id)"), address: address))
            }
        }

        parentOptions = next
        if !parentOptions.contains(where: { $0.id == selectedParentId }) {
            selectedParentId = parentOptions.first?.id ?? ""
        }
    }

    private func applyInitialParentSelectionIfNeeded() {
        guard !didApplyInitialParent else { return }
        didApplyInitialParent = true

        if let raw = initialParentTypeRaw, let type = ParentType(rawValue: raw) {
            parentType = type
            rebuildParentOptions()
            if let parentId = initialParentId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !parentId.isEmpty,
               parentOptions.contains(where: { $0.id == parentId }) {
                selectedParentId = parentId
            }
        }

        if receiptAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let initialReceiptAddress {
            let cleanAddress = initialReceiptAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanAddress.isEmpty {
                receiptAddress = cleanAddress
            }
        }
    }

    private func scheduleMaterialSearch(query: String) {
        if suppressNextMaterialSearch {
            suppressNextMaterialSearch = false
            return
        }
        searchTask?.cancel()
        selectedMaterial = nil

        let trimmed = clean(query)
        if trimmed.isEmpty {
            materialSuggestions = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            do {
                let rows = try await appState.client.searchMaterials(query: trimmed, limit: 20)
                if Task.isCancelled { return }
                materialSuggestions = rows
            } catch {
                if Task.isCancelled { return }
                materialSuggestions = []
            }
        }
    }

    private func selectMaterial(_ material: Material) {
        suppressNextMaterialSearch = true
        selectedMaterial = material
        materialSuggestions = []
        let unitPart = material.resolvedUnit.isEmpty ? "" : " (\(material.resolvedUnit))"
        materialQuery = "\(material.resolvedName)\(unitPart) [\(material.id)]"
    }

    private func appendCurrentMaterialLine(showError: Bool) -> Bool {
        let quantity = parseQuantity(quantityText)
        guard quantity > 0 else {
            if showError { localErrorText = "Количество должно быть больше нуля" }
            return false
        }

        let fallbackText = clean(materialQuery)
        let resolvedMaterialId: String
        let resolvedName: String
        let resolvedUnit: String

        if let selectedMaterial {
            resolvedMaterialId = selectedMaterial.id
            resolvedName = selectedMaterial.resolvedName
            resolvedUnit = selectedMaterial.resolvedUnit
        } else {
            let bracketId = extractBracketValue(from: fallbackText)
            resolvedMaterialId = bracketId ?? fallbackText
            resolvedName = stripBracketSuffix(from: fallbackText, bracketValue: bracketId)
            resolvedUnit = ""
        }

        if clean(resolvedMaterialId).isEmpty || clean(resolvedName).isEmpty {
            if showError { localErrorText = "Сначала выберите материал" }
            return false
        }

        localErrorText = nil
        materialLines.append(
            PurchaseRequestDraftMaterialLine(
                materialId: clean(resolvedMaterialId),
                materialName: clean(resolvedName),
                unit: clean(resolvedUnit),
                quantity: quantity
            )
        )

        selectedMaterial = nil
        materialSuggestions = []
        materialQuery = ""
        quantityText = ""
        return true
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        localErrorText = nil

        if materialLines.isEmpty {
            _ = appendCurrentMaterialLine(showError: false)
        }

        if materialLines.isEmpty {
            localErrorText = "Добавьте хотя бы один материал"
            return
        }

        let parent = selectedParentOption()
        var resolvedAddress = clean(receiptAddress)
        if resolvedAddress.isEmpty {
            resolvedAddress = clean(parent?.address)
        }

        let stockByMaterial = await loadWarehouseStockMap()
        let enoughStock = hasEnoughStock(materialLines: materialLines, stockByMaterial: stockByMaterial)

        let payload = PurchaseRequestUpsertPayload(
            status: enoughStock ? PurchaseRequestStatus.readyForReceipt.rawValue : PurchaseRequestStatus.pending.rawValue,
            installationId: parent?.type == .installation ? nilIfBlank(parent?.id) : nil,
            taskId: parent?.type == .task ? nilIfBlank(parent?.id) : nil,
            taskAvrId: parent?.type == .avr ? nilIfBlank(parent?.id) : nil,
            projectId: parent?.type == .project ? nilIfBlank(parent?.id) : nil,
            createdBy: appState.currentUser?.id,
            comment: buildComment(userComment: clean(comment), parent: parent, urgency: urgency, lines: materialLines),
            receiptAddress: resolvedAddress.isEmpty ? nil : resolvedAddress,
            title: buildTitle(from: materialLines)
        )

        let ok = await viewModel.create(payload: payload, materialLines: materialLines)
        if ok {
            dismiss()
        } else if localErrorText == nil {
            localErrorText = viewModel.errorText
        }
    }

    private func selectedParentOption() -> ParentOption? {
        parentOptions.first(where: { $0.id == selectedParentId })
    }

    private func loadWarehouseStockMap() async -> [String: Double] {
        do {
            let rows = try await appState.client.fetchWarehouseStock()
            var stock: [String: Double] = [:]
            for row in rows {
                let materialId = clean(row.fields["material_id"]?.textValue)
                if materialId.isEmpty { continue }
                if let available = firstNumber(from: [
                    row.fields["quantity_available"],
                    row.fields["total_quantity"],
                    row.fields["quantity"]
                ]) {
                    stock[materialId] = available
                }
            }
            return stock
        } catch {
            return [:]
        }
    }

    private func hasEnoughStock(materialLines: [PurchaseRequestDraftMaterialLine], stockByMaterial: [String: Double]) -> Bool {
        var required: [String: Double] = [:]
        for line in materialLines {
            required[line.materialId, default: 0] += line.quantity
        }
        for (materialId, quantity) in required {
            let available = stockByMaterial[materialId] ?? 0
            if available < quantity { return false }
        }
        return true
    }

    private func buildTitle(from lines: [PurchaseRequestDraftMaterialLine]) -> String {
        guard let first = lines.first else { return "Материалы" }
        let suffix = lines.count > 1 ? " +\(lines.count - 1)" : ""
        return "Материалы: \(first.materialName)\(suffix)"
    }

    private func buildComment(
        userComment: String,
        parent: ParentOption?,
        urgency: UrgencyLevel,
        lines: [PurchaseRequestDraftMaterialLine]
    ) -> String {
        var parts: [String] = []
        parts.append("Срочность: \(urgency.title)")
        if let parent, !clean(parent.id).isEmpty {
            parts.append("Связано с: \(parent.label)")
        }
        if !userComment.isEmpty {
            parts.append("Комментарий: \(userComment)")
        }
        parts.append("Материалы:")
        for line in lines {
            let qty = formatQuantity(line.quantity)
            let unit = line.unit.isEmpty ? "" : " \(line.unit)"
            parts.append("- \(line.materialName) - \(qty)\(unit) [\(line.materialId)]")
        }
        return parts.joined(separator: "\n")
    }

    private func parseQuantity(_ value: String) -> Double {
        let normalized = value.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized) ?? 0
    }

    private func firstNumber(from values: [JSONValue?]) -> Double? {
        for value in values {
            guard let value else { continue }
            switch value {
            case let .number(number): return number
            case .string:
                let parsed = Double(value.textValue.replacingOccurrences(of: ",", with: "."))
                if let parsed { return parsed }
            default:
                break
            }
        }
        return nil
    }

    private func extractBracketValue(from value: String) -> String? {
        guard let left = value.lastIndex(of: "["), let right = value.lastIndex(of: "]"), left < right else {
            return nil
        }
        let start = value.index(after: left)
        return String(value[start..<right]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripBracketSuffix(from value: String, bracketValue: String?) -> String {
        guard let bracketValue, !bracketValue.isEmpty else { return value }
        let suffix = "[\(bracketValue)]"
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(suffix) {
            let base = String(trimmed.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return base.isEmpty ? bracketValue : base
        }
        return value
    }

    private func labelWithAddress(title: String, address: String, fallback: String) -> String {
        let base = title.isEmpty ? fallback : title
        return address.isEmpty ? base : "\(base) | \(address)"
    }

    private func firstNonBlank(_ values: [String?]) -> String {
        for value in values {
            let text = clean(value)
            if !text.isEmpty { return text }
        }
        return ""
    }

    private func clean(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nilIfBlank(_ value: String?) -> String? {
        let text = clean(value)
        return text.isEmpty ? nil : text
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }
}

private enum ParentType: String, CaseIterable, Identifiable {
    case none
    case project
    case task
    case installation
    case avr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Без привязки"
        case .project: return "Проект"
        case .task: return "Задача"
        case .installation: return "Монтаж"
        case .avr: return "AVR"
        }
    }
}

private enum UrgencyLevel: String, CaseIterable, Identifiable {
    case normal
    case urgent
    case critical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: return "Обычная"
        case .urgent: return "Срочная"
        case .critical: return "Критичная"
        }
    }
}

private struct ParentOption: Identifiable, Hashable {
    let type: ParentType
    let id: String
    let label: String
    let address: String
}
