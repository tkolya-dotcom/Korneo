import SwiftUI

struct WarehouseView: View {
    private struct RestockDraft {
        var materialId = ""
        var quantity = ""
        var note = ""
    }

    private struct IssueDraft {
        var materialId = ""
        var quantity = ""
        var recipient = ""
        var note = ""
    }

    private struct AddMaterialDraft {
        var name = ""
        var category = ""
        var unit = ""
        var minStock = ""
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = WarehouseViewModel()
    @State private var searchText = ""
    @State private var availabilityFilter: WarehouseViewModel.AvailabilityFilter = .all
    @State private var showRestockSheet = false
    @State private var showIssueSheet = false
    @State private var showAddMaterialSheet = false
    @State private var showHistorySheet = false
    @State private var pendingIssueDraft: WarehouseViewModel.IssueDraft?
    @State private var showShortageConfirm = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.materials.isEmpty && viewModel.stockRows.isEmpty {
                ProgressView("Загрузка склада...")
            } else if let error = viewModel.errorText, viewModel.materials.isEmpty && viewModel.stockRows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List {
                    if let info = viewModel.infoText, !info.isEmpty {
                        Section {
                            Text(info)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Поиск и фильтры") {
                        TextField("Поиск по названию или id", text: $searchText)
                        Picker("Наличие", selection: $availabilityFilter) {
                            ForEach(WarehouseViewModel.AvailabilityFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if canManageWarehouse {
                        Section("Действия") {
                            Button {
                                showRestockSheet = true
                            } label: {
                                Label("Пополнить", systemImage: "plus.circle")
                            }
                            .disabled(viewModel.isMutating)

                            Button {
                                showIssueSheet = true
                            } label: {
                                Label("Выдать", systemImage: "arrow.up.circle")
                            }
                            .disabled(viewModel.isMutating)

                            Button {
                                showAddMaterialSheet = true
                            } label: {
                                Label("Добавить материал", systemImage: "shippingbox")
                            }
                            .disabled(viewModel.isMutating)
                        }
                    }

                    Section("Склад (\(filteredMaterials.count))") {
                        ForEach(filteredMaterials, id: \.id) { material in
                            let qty = viewModel.availableQuantity(for: material.id)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(material.resolvedName)
                                    .font(.headline)
                                Text("\(material.id)\(material.resolvedUnit.isEmpty ? "" : " • \(material.resolvedUnit)")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Остаток: \(formatQuantity(qty))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Button {
                            showHistorySheet = true
                        } label: {
                            Label("История операций", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        }
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("Склад")
        .alert("Остаток уйдет в минус", isPresented: $showShortageConfirm, presenting: pendingIssueDraft) { draft in
            Button("Продолжить", role: .destructive) {
                Task { await performIssue(draft: draft) }
            }
            Button("Отмена", role: .cancel) {
                pendingIssueDraft = nil
            }
        } message: { draft in
            let available = viewModel.availableQuantity(for: draft.materialId)
            let after = available - draft.quantity
            Text("На складе сейчас \(formatQuantity(available)). После выдачи будет \(formatQuantity(after)).")
        }
        .sheet(isPresented: $showHistorySheet) {
            NavigationStack {
                List(viewModel.historyRows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(historyTitle(row))
                            .font(.headline)
                        Text(historySubtitle(row))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("История")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            showHistorySheet = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showRestockSheet) {
            NavigationStack {
                WarehouseRestockSheet(
                    materials: viewModel.materials,
                    isSaving: viewModel.isMutating
                ) { draft in
                    await performRestock(draft: draft)
                }
                .navigationTitle("Пополнение")
            }
        }
        .sheet(isPresented: $showIssueSheet) {
            NavigationStack {
                WarehouseIssueSheet(
                    materials: viewModel.materials,
                    stockByMaterialId: Dictionary(uniqueKeysWithValues: viewModel.materials.map { ($0.id, viewModel.availableQuantity(for: $0.id)) }),
                    isSaving: viewModel.isMutating
                ) { draft in
                    await requestIssue(draft: draft)
                }
                .navigationTitle("Выдача")
            }
        }
        .sheet(isPresented: $showAddMaterialSheet) {
            NavigationStack {
                WarehouseAddMaterialSheet(isSaving: viewModel.isMutating) { draft in
                    await performAddMaterial(draft: draft)
                }
                .navigationTitle("Новый материал")
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
    }

    private var canManageWarehouse: Bool {
        appState.currentUser?.role?.hasCoordinatorRights == true
    }

    private var filteredMaterials: [Material] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.materials.filter { material in
            let name = material.resolvedName.lowercased()
            let id = material.id.lowercased()
            let textMatch = query.isEmpty || name.contains(query) || id.contains(query)
            guard textMatch else { return false }
            let qty = viewModel.availableQuantity(for: material.id)
            switch availabilityFilter {
            case .all:
                return true
            case .available:
                return qty > 0
            case .empty:
                return qty <= 0
            }
        }
    }

    private func requestIssue(draft: WarehouseIssueSheet.Draft) async {
        let issueDraft = WarehouseViewModel.IssueDraft(
            materialId: draft.materialId,
            quantity: draft.quantityValue,
            recipient: draft.recipient,
            note: draft.note
        )
        let available = viewModel.availableQuantity(for: draft.materialId)
        if available - issueDraft.quantity < 0 {
            pendingIssueDraft = issueDraft
            showShortageConfirm = true
            return
        }
        await performIssue(draft: issueDraft)
    }

    private func performIssue(draft: WarehouseViewModel.IssueDraft) async {
        let ok = await viewModel.issue(draft: draft, createdBy: appState.currentUser?.id)
        if ok {
            showIssueSheet = false
            pendingIssueDraft = nil
        }
    }

    private func performRestock(draft: WarehouseRestockSheet.Draft) async {
        let ok = await viewModel.restock(
            materialId: draft.materialId,
            quantity: draft.quantityValue,
            note: draft.note,
            createdBy: appState.currentUser?.id
        )
        if ok {
            showRestockSheet = false
        }
    }

    private func performAddMaterial(draft: WarehouseAddMaterialSheet.Draft) async {
        let ok = await viewModel.addMaterial(
            name: draft.name,
            category: draft.category,
            unit: draft.unit,
            minStockText: draft.minStock
        )
        if ok {
            showAddMaterialSheet = false
        }
    }

    private func historyTitle(_ row: GenericRecord) -> String {
        let materialId = clean(row.fields["material_id"]?.textValue)
        let type = clean(row.fields["type"]?.textValue)
        let op = type.lowercased() == "in" ? "Пополнение" : (type.lowercased() == "out" ? "Выдача" : safe(type))
        return "\(op): \(viewModel.materialName(for: materialId))"
    }

    private func historySubtitle(_ row: GenericRecord) -> String {
        let qty = clean(row.fields["quantity"]?.textValue)
        let recipient = clean(row.fields["recipient"]?.textValue)
        let note = clean(row.fields["note"]?.textValue)
        let date = clean(row.fields["created_at"]?.textValue)
        var parts: [String] = []
        if !qty.isEmpty { parts.append("Кол-во: \(qty)") }
        if !recipient.isEmpty { parts.append("Получатель: \(recipient)") }
        if !note.isEmpty { parts.append("Комментарий: \(note)") }
        if !date.isEmpty { parts.append(date) }
        return parts.joined(separator: " | ")
    }

    private func clean(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.lowercased() == "null" { return "" }
        return raw
    }

    private func safe(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

private struct WarehouseRestockSheet: View {
    struct Draft {
        var materialId = ""
        var quantity = ""
        var note = ""

        var quantityValue: Double {
            Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
    }

    let materials: [Material]
    let isSaving: Bool
    let onSave: (Draft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = Draft()

    var body: some View {
        Form {
            Picker("Материал", selection: $draft.materialId) {
                Text("Выберите").tag("")
                ForEach(materials, id: \.id) { material in
                    Text(material.resolvedName).tag(material.id)
                }
            }
            TextField("Количество", text: $draft.quantity)
                .keyboardType(.decimalPad)
            TextField("Комментарий", text: $draft.note, axis: .vertical)
                .lineLimit(2...4)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Сохраняем..." : "Сохранить") {
                    Task { await onSave(draft) }
                }
                .disabled(isSaving || draft.materialId.isEmpty || draft.quantityValue <= 0)
            }
        }
    }
}

private struct WarehouseIssueSheet: View {
    struct Draft {
        var materialId = ""
        var quantity = ""
        var recipient = ""
        var note = ""

        var quantityValue: Double {
            Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
    }

    let materials: [Material]
    let stockByMaterialId: [String: Double]
    let isSaving: Bool
    let onSave: (Draft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = Draft()

    var body: some View {
        Form {
            Picker("Материал", selection: $draft.materialId) {
                Text("Выберите").tag("")
                ForEach(materials, id: \.id) { material in
                    Text(material.resolvedName).tag(material.id)
                }
            }
            if !draft.materialId.isEmpty {
                let available = stockByMaterialId[draft.materialId] ?? 0
                Text("На складе: \(formatQuantity(available))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Количество", text: $draft.quantity)
                .keyboardType(.decimalPad)
            TextField("Получатель", text: $draft.recipient)
            TextField("Комментарий", text: $draft.note, axis: .vertical)
                .lineLimit(2...4)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Сохраняем..." : "Сохранить") {
                    Task { await onSave(draft) }
                }
                .disabled(isSaving || draft.materialId.isEmpty || draft.quantityValue <= 0)
            }
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) { return String(Int(value)) }
        return String(format: "%.2f", value)
    }
}

private struct WarehouseAddMaterialSheet: View {
    struct Draft {
        var name = ""
        var category = ""
        var unit = ""
        var minStock = ""
    }

    let isSaving: Bool
    let onSave: (Draft) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = Draft()

    var body: some View {
        Form {
            TextField("Название", text: $draft.name)
            TextField("Категория", text: $draft.category)
            TextField("Ед. изм.", text: $draft.unit)
            TextField("Мин. остаток", text: $draft.minStock)
                .keyboardType(.decimalPad)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Сохраняем..." : "Сохранить") {
                    Task { await onSave(draft) }
                }
                .disabled(isSaving || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

