import SwiftUI

struct SitesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rows: [GenericRecord] = []
    @State private var searchText = ""
    @State private var districtFilter = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var detailRow: GenericRecord?
    @State private var pendingDeleteRow: GenericRecord?
    @State private var editRow: GenericRecord?
    @State private var isDeleting = false

    var body: some View {
        Group {
            if isLoading && visibleRows.isEmpty {
                ProgressView("Загрузка площадок...")
            } else if let errorText, visibleRows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else if visibleRows.isEmpty {
                ContentUnavailableView("Нет площадок", systemImage: "mappin.slash")
            } else {
                List {
                    Section("Фильтр") {
                        Picker("Район", selection: $districtFilter) {
                            Text("Все районы").tag("")
                            ForEach(districtOptions, id: \.self) { district in
                                Text(district).tag(district)
                            }
                        }
                    }

                    ForEach(visibleRows) { row in
                        Button {
                            detailRow = row
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(siteTitle(for: row))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(siteSubtitle(for: row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(4)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Детали", systemImage: "doc.text.magnifyingglass") {
                                detailRow = row
                            }
                            if canDelete {
                                Button("Редактировать", systemImage: "square.and.pencil") {
                                    editRow = row
                                }
                                Button("Удалить", systemImage: "trash", role: .destructive) {
                                    pendingDeleteRow = row
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDelete {
                                Button {
                                    editRow = row
                                } label: {
                                    Label("Редактировать", systemImage: "square.and.pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    pendingDeleteRow = row
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle("Площадки")
        .searchable(text: $searchText, prompt: "Поиск по адресу, EMTS, СК, серийному и инвентарному")
        .task {
            await load()
        }
        .sheet(item: $detailRow) { row in
            NavigationStack {
                ScrollView {
                    Text(siteDetail(for: row))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(siteTitle(for: row))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            detailRow = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $editRow) { row in
            NavigationStack {
                SiteEditSheet(
                    initialServiceId: first(row, keys: ["servisnyy_id", "service_id", "emts"]),
                    initialAddress: first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]),
                    initialDistrict: first(row, keys: ["rayon", "district"]),
                    initialSkCount: first(row, keys: ["kolichestvo_sk", "sk_count", "equipment_count"]),
                    initialComment: first(row, keys: ["comment", "kommentariy"])
                ) { draft in
                    await saveSiteEdit(row: row, draft: draft)
                }
                .navigationTitle("Редактирование площадки")
            }
        }
        .confirmationDialog(
            "Удалить площадку?",
            isPresented: Binding(
                get: { pendingDeleteRow != nil },
                set: { if !$0 { pendingDeleteRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Удаление..." : "Удалить", role: .destructive) {
                guard let row = pendingDeleteRow else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    await delete(row: row)
                }
            }
            .disabled(isDeleting)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private var canDelete: Bool {
        appState.currentUser?.role?.hasManagerRights == true
    }

    private var visibleRows: [GenericRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.filter { row in
            if !districtFilter.isEmpty {
                let district = first(row, keys: ["rayon", "district"]).lowercased()
                if district != districtFilter.lowercased() {
                    return false
                }
            }
            if q.isEmpty {
                return true
            }
            return siteSearchBlob(for: row).lowercased().contains(q)
        }
    }

    private var districtOptions: [String] {
        var values = Set<String>()
        for row in rows {
            let district = first(row, keys: ["rayon", "district"])
            if !district.isEmpty {
                values.insert(district)
            }
        }
        return values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            rows = try await appState.client.fetchSitesRows()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(row: GenericRecord) async {
        guard canDelete else { return }
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        guard !siteId.isEmpty else { return }
        do {
            try await appState.client.deleteSite(siteId: siteId)
            pendingDeleteRow = nil
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveSiteEdit(row: GenericRecord, draft: SiteEditDraft) async -> String? {
        guard canDelete else { return "Недостаточно прав" }
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        guard !siteId.isEmpty else { return "Некорректный идентификатор записи" }

        var patch: [String: JSONValue] = [:]
        putIfNotBlank(&patch, key: "servisnyy_id", value: draft.serviceId)
        putIfNotBlank(&patch, key: "adres_razmeshcheniya", value: draft.address)
        putIfNotBlank(&patch, key: "rayon", value: draft.district)
        putIfNotBlank(&patch, key: "comment", value: draft.comment)

        if let count = Int(draft.skCount.trimmingCharacters(in: .whitespacesAndNewlines)), count >= 0 {
            patch["kolichestvo_sk"] = .number(Double(count))
        }

        if patch.isEmpty { return nil }
        do {
            try await appState.client.updateSite(siteId: siteId, patch: patch)
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func siteTitle(for row: GenericRecord) -> String {
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        let emts = first(row, keys: ["emts", "servisnyy_id", "service_id"])
        return emts.isEmpty ? "Площадка \(safe(siteId))" : "Площадка \(safe(siteId)) • \(emts)"
    }

    private func siteSubtitle(for row: GenericRecord) -> String {
        let address = first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"])
        let district = first(row, keys: ["rayon", "district"])
        let emts = first(row, keys: ["emts", "servisnyy_id", "service_id"])
        let skCount = first(row, keys: ["kolichestvo_sk", "sk_count", "equipment_count"])
        let skNames = joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"])
        let serials = joined(row, baseKey: "serial_number", fallbackKeys: ["servisnyy_id", "service_id", "equipment_serial_number"])
        let inventories = joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"])
        return """
        Адрес: \(safe(address))
        Район: \(safe(district))
        EMTS / Service ID: \(safe(emts))
        Кол-во СК: \(safe(skCount))
        \(skNames.isEmpty ? "" : "Наименования СК: \(skNames)\n")\(serials.isEmpty ? "" : "Серийные номера: \(serials)\n")\(inventories.isEmpty ? "" : "Инвентарные номера: \(inventories)")
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func siteDetail(for row: GenericRecord) -> String {
        var lines: [String] = []
        appendLine(&lines, label: "ID площадки", value: first(row, keys: ["id_ploshadki", "site_id", "id"]))
        appendLine(&lines, label: "EMTS / Service ID", value: first(row, keys: ["emts", "servisnyy_id", "service_id"]))
        appendLine(&lines, label: "Адрес", value: first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]))
        appendLine(&lines, label: "Район", value: first(row, keys: ["rayon", "district"]))
        appendLine(&lines, label: "Кол-во СК", value: first(row, keys: ["kolichestvo_sk", "sk_count", "equipment_count"]))
        appendLine(&lines, label: "Наименования СК", value: joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"]))
        appendLine(&lines, label: "Серийные номера", value: joined(row, baseKey: "serial_number", fallbackKeys: ["servisnyy_id", "service_id", "equipment_serial_number"]))
        appendLine(&lines, label: "Инвентарные номера", value: joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"]))
        return lines.joined(separator: "\n\n")
    }

    private func siteSearchBlob(for row: GenericRecord) -> String {
        [
            first(row, keys: ["id_ploshadki", "site_id", "id"]),
            first(row, keys: ["emts", "servisnyy_id", "service_id"]),
            first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]),
            first(row, keys: ["rayon", "district"]),
            joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"]),
            joined(row, baseKey: "serial_number", fallbackKeys: ["servisnyy_id", "service_id", "equipment_serial_number"]),
            joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"])
        ].joined(separator: " ")
    }

    private func first(_ row: GenericRecord, keys: [String]) -> String {
        for key in keys {
            let value = normalized(row.fields[key]?.textValue)
            if !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private func joined(_ row: GenericRecord, baseKey: String, fallbackKeys: [String]) -> String {
        var values: [String] = []
        for i in 1...6 {
            let v = normalized(row.fields["\(baseKey)\(i)"]?.textValue)
            if !v.isEmpty && !values.contains(v) {
                values.append(v)
            }
        }
        if values.isEmpty {
            let single = first(row, keys: [baseKey] + fallbackKeys)
            if !single.isEmpty {
                values.append(single)
            }
        }
        return values.joined(separator: "; ")
    }

    private func putIfNotBlank(_ patch: inout [String: JSONValue], key: String, value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        patch[key] = .string(clean)
    }

    private func safe(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }

    private func normalized(_ value: String?) -> String {
        let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.lowercased() == "null" {
            return ""
        }
        if let number = Double(raw), number == floor(number) {
            return String(Int(number))
        }
        return raw
    }

    private func appendLine(_ lines: inout [String], label: String, value: String) {
        guard !value.isEmpty else { return }
        lines.append("\(label): \(value)")
    }
}

private struct SiteEditDraft {
    var serviceId = ""
    var address = ""
    var district = ""
    var skCount = ""
    var comment = ""
}

private struct SiteEditSheet: View {
    let initialServiceId: String
    let initialAddress: String
    let initialDistrict: String
    let initialSkCount: String
    let initialComment: String
    let onSave: (SiteEditDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = SiteEditDraft()
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        Form {
            if let errorText {
                Section("Ошибка") {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            Section("Основное") {
                TextField("Service ID", text: $draft.serviceId)
                TextField("Адрес", text: $draft.address)
                TextField("Район", text: $draft.district)
                TextField("Количество СК", text: $draft.skCount)
                    .keyboardType(.numberPad)
                TextField("Комментарий", text: $draft.comment, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
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
        .task {
            draft.serviceId = initialServiceId
            draft.address = initialAddress
            draft.district = initialDistrict
            draft.skCount = initialSkCount
            draft.comment = initialComment
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorText = nil
        if let error = await onSave(draft) {
            errorText = error
        } else {
            dismiss()
        }
    }
}


