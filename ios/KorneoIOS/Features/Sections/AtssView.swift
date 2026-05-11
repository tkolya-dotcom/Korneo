import SwiftUI
import UniformTypeIdentifiers

struct AtssView: View {
    private enum SourceFilter: String, CaseIterable, Identifiable {
        case all
        case atss
        case kasip

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Все"
            case .atss: return "ATSS"
            case .kasip: return "KASIP-AZM"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @State private var rows: [GenericRecord] = []
    @State private var searchText = ""
    @State private var sourceFilter: SourceFilter = .all
    @State private var districtFilter = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var detailRow: GenericRecord?
    @State private var pendingDeleteRow: GenericRecord?
    @State private var editRow: GenericRecord?
    @State private var isDeleting = false
    @State private var isImporting = false
    @State private var showImportPicker = false
    @State private var importStatusText: String?

    var body: some View {
        Group {
            if isLoading && visibleRows.isEmpty {
                ProgressView("Загрузка АТСС...")
            } else if let errorText, visibleRows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else if visibleRows.isEmpty {
                ContentUnavailableView("Нет записей АТСС", systemImage: "doc.text.magnifyingglass")
            } else {
                List {
                    Section("Фильтры") {
                        Picker("Источник", selection: $sourceFilter) {
                            ForEach(SourceFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Район", selection: $districtFilter) {
                            Text("Все районы").tag("")
                            ForEach(districtOptions, id: \.self) { district in
                                Text(district).tag(district)
                            }
                        }
                    }

                    if let importStatusText, !importStatusText.isEmpty {
                        Section("Статус импорта") {
                            Text(importStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(visibleRows) { row in
                        Button {
                            detailRow = row
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(atssTitle(for: row))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(atssSubtitle(for: row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(6)
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
        .navigationTitle("АТСС")
        .searchable(text: $searchText, prompt: "Поиск по адресу, EMTS, СК, серийному и инвентарному")
        .toolbar {
            if canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImportPicker = true
                    } label: {
                        if isImporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    .disabled(isImporting)
                    .accessibilityLabel("Импорт плана АТСС")
                }
            }
        }
        .task {
            await load()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: atssImportContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task { await importAtssFile(url) }
            case let .failure(error):
                importStatusText = "Ошибка выбора файла: \(error.localizedDescription)"
            }
        }
        .sheet(item: $detailRow) { row in
            NavigationStack {
                ScrollView {
                    Text(atssDetail(for: row))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(atssTitle(for: row))
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
                AtssEditSheet(
                    sourceTable: sourceTable(for: row),
                    initialServiceId: first(row, keys: ["servisnyy_id", "service_id", "emts"]),
                    initialAddress: first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]),
                    initialDistrict: first(row, keys: ["rayon", "district"]),
                    initialPlanDate: formattedAtssDate(first(row, keys: ["planovaya_data_1_kv_2026", "plan_yanvar", "plan_fevral", "plan_mart"])),
                    initialComment: first(row, keys: ["kommentariy", "comment"])
                ) { draft in
                    await saveAtssEdit(row: row, draft: draft)
                }
                .navigationTitle("Редактирование АТСС")
            }
        }
        .confirmationDialog(
            "Удалить запись АТСС?",
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

    private var atssImportContentTypes: [UTType] {
        var types: [UTType] = []
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        if let xls = UTType(filenameExtension: "xls") { types.append(xls) }
        if types.isEmpty { types.append(.data) }
        return types
    }

    private var visibleRows: [GenericRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rows.filter { row in
            if sourceFilter != .all {
                let isKasip = isKasipRow(row)
                if sourceFilter == .kasip && !isKasip {
                    return false
                }
                if sourceFilter == .atss && isKasip {
                    return false
                }
            }

            if !districtFilter.isEmpty {
                let district = first(row, keys: ["rayon", "district"]).lowercased()
                if district != districtFilter.lowercased() {
                    return false
                }
            }

            if q.isEmpty {
                return true
            }
            return atssSearchBlob(for: row).lowercased().contains(q)
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
            rows = try await appState.client.fetchAtssRowsMerged()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importAtssFile(_ url: URL) async {
        guard canDelete else { return }
        isImporting = true
        defer { isImporting = false }

        let ext = url.pathExtension.lowercased()
        if ext == "xls" {
            importStatusText = "Формат .xls не поддерживается. Используйте .xlsx."
            return
        }

        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { url.stopAccessingSecurityScopedResource() }
        }

        do {
            importStatusText = "Читаю Excel файл..."
            let records = try AtssXlsxImportParser.parse(fileURL: url)
            importStatusText = "Найдено строк: \(records.count). Обновляю БД..."
            let stats = try await appState.client.uploadAtssPlanRecords(records)
            let added = stats["added", default: 0]
            let updated = stats["updated", default: 0]
            let unchanged = stats["unchanged", default: 0]
            let errors = stats["errors", default: 0]
            let summary = "Импорт завершен: добавлено \(added), обновлено \(updated), без изменений \(unchanged), ошибок \(errors)"
            importStatusText = summary
            await load()
        } catch {
            importStatusText = "Ошибка импорта: \(error.localizedDescription)"
        }
    }

    private func delete(row: GenericRecord) async {
        guard canDelete else { return }
        let source = sourceTable(for: row)
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        guard !source.isEmpty, !siteId.isEmpty else { return }
        do {
            if source == "kasip_azm_q1_2026" {
                try await appState.client.deleteKasipAzm(siteId: siteId)
            } else {
                try await appState.client.deleteAtss(siteId: siteId)
            }
            pendingDeleteRow = nil
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func saveAtssEdit(row: GenericRecord, draft: AtssEditDraft) async -> String? {
        guard canDelete else { return "Недостаточно прав" }
        let source = sourceTable(for: row)
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        guard !source.isEmpty, !siteId.isEmpty else { return "Некорректный идентификатор записи" }

        var patch: [String: JSONValue] = [:]
        putIfNotBlank(&patch, key: "servisnyy_id", value: draft.serviceId)
        putIfNotBlank(&patch, key: source == "kasip_azm_q1_2026" ? "adres_raspolozheniya" : "adres_razmeshcheniya", value: draft.address)
        putIfNotBlank(&patch, key: "rayon", value: draft.district)
        putIfNotBlank(&patch, key: "kommentariy", value: draft.comment)

        if let planInt = parsePlanDateToInt(draft.planDate) {
            if source == "kasip_azm_q1_2026" {
                let month = (planInt / 100) % 100
                if month == 1 {
                    patch["plan_yanvar"] = .number(Double(planInt))
                } else if month == 2 {
                    patch["plan_fevral"] = .number(Double(planInt))
                } else if month == 3 {
                    patch["plan_mart"] = .number(Double(planInt))
                } else {
                    patch["plan_yanvar"] = .number(Double(planInt))
                }
            } else {
                patch["planovaya_data_1_kv_2026"] = .number(Double(planInt))
            }
        }

        if patch.isEmpty { return nil }

        do {
            if source == "kasip_azm_q1_2026" {
                try await appState.client.updateKasipAzm(siteId: siteId, patch: patch)
            } else {
                try await appState.client.updateAtss(siteId: siteId, patch: patch)
            }
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func atssTitle(for row: GenericRecord) -> String {
        let source = sourceLabel(sourceTable(for: row))
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        let emts = first(row, keys: ["emts", "servisnyy_id", "service_id"])
        return emts.isEmpty ? "\(source) \(safe(siteId))" : "\(source) \(safe(siteId)) • \(emts)"
    }

    private func atssSubtitle(for row: GenericRecord) -> String {
        let address = first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"])
        let district = first(row, keys: ["rayon", "district"])
        let emts = first(row, keys: ["emts", "servisnyy_id", "service_id"])
        let plan = formattedAtssDate(first(row, keys: ["planovaya_data_1_kv_2026", "plan_yanvar", "plan_fevral", "plan_mart"]))
        let skNames = joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"])
        let statuses = joined(row, baseKey: "status_sk", fallbackKeys: ["status_oborudovaniya", "equipment_status"])
        let serials = joined(row, baseKey: "serial_number", fallbackKeys: ["equipment_serial_number"])
        let inventories = joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"])
        return """
        Адрес: \(safe(address))
        Район: \(safe(district))
        EMTS / Service ID: \(safe(emts))
        \(plan.isEmpty ? "" : "Плановая дата: \(plan)\n")\(skNames.isEmpty ? "" : "Наименования СК: \(skNames)\n")\(statuses.isEmpty ? "" : "Статусы СК: \(statuses)\n")\(serials.isEmpty ? "" : "Серийные номера: \(serials)\n")\(inventories.isEmpty ? "" : "Инвентарные номера: \(inventories)")
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func atssDetail(for row: GenericRecord) -> String {
        var lines: [String] = []
        appendLine(&lines, label: "Источник", value: sourceLabel(sourceTable(for: row)))
        appendLine(&lines, label: "ID площадки", value: first(row, keys: ["id_ploshadki", "site_id", "id"]))
        appendLine(&lines, label: "EMTS / Service ID", value: first(row, keys: ["emts", "servisnyy_id", "service_id"]))
        appendLine(&lines, label: "Адрес", value: first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]))
        appendLine(&lines, label: "Район", value: first(row, keys: ["rayon", "district"]))
        appendLine(&lines, label: "Плановая дата", value: formattedAtssDate(first(row, keys: ["planovaya_data_1_kv_2026", "plan_yanvar", "plan_fevral", "plan_mart"])))
        for i in 1...6 {
            let skName = first(row, keys: ["naimenovanie_sk\(i)", "equipment_name\(i)", "name\(i)"])
            let status = first(row, keys: ["status_sk\(i)", "status_oborudovaniya\(i)", "equipment_status\(i)"])
            let serial = first(row, keys: ["serial_number\(i)", "equipment_serial_number\(i)"])
            let inventory = first(row, keys: ["inventory_number\(i)", "id_sk\(i)", "id_konditsionera\(i)", "equipment_inventory_number\(i)"])
            if skName.isEmpty && status.isEmpty && serial.isEmpty && inventory.isEmpty {
                continue
            }
            lines.append("SK \(i): \(safe(skName))")
            appendLine(&lines, label: "Статус", value: status)
            appendLine(&lines, label: "S/N", value: serial)
            appendLine(&lines, label: "Инвентарный", value: inventory)
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func atssSearchBlob(for row: GenericRecord) -> String {
        [
            first(row, keys: ["id_ploshadki", "site_id", "id"]),
            first(row, keys: ["emts", "servisnyy_id", "service_id"]),
            first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]),
            first(row, keys: ["rayon", "district"]),
            joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"]),
            joined(row, baseKey: "status_sk", fallbackKeys: ["status_oborudovaniya", "equipment_status"]),
            joined(row, baseKey: "serial_number", fallbackKeys: ["equipment_serial_number"]),
            joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"])
        ].joined(separator: " ")
    }

    private func sourceTable(for row: GenericRecord) -> String {
        normalized(row.fields["__source_table"]?.textValue)
    }

    private func sourceLabel(_ table: String) -> String {
        if table == "kasip_azm_q1_2026" {
            return "KASIP-AZM"
        }
        return "ATSS"
    }

    private func isKasipRow(_ row: GenericRecord) -> Bool {
        sourceTable(for: row) == "kasip_azm_q1_2026"
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
        let single = first(row, keys: [baseKey] + fallbackKeys)
        if !single.isEmpty && !values.contains(single) {
            values.append(single)
        }
        for i in 1...6 {
            let v = normalized(row.fields["\(baseKey)\(i)"]?.textValue)
            if !v.isEmpty && !values.contains(v) {
                values.append(v)
            }
        }
        return values.joined(separator: "; ")
    }

    private func formattedAtssDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.count == 8, let _ = Int(trimmed) {
            let year = String(trimmed.prefix(4))
            let monthStart = trimmed.index(trimmed.startIndex, offsetBy: 4)
            let monthEnd = trimmed.index(monthStart, offsetBy: 2)
            let month = String(trimmed[monthStart..<monthEnd])
            let day = String(trimmed.suffix(2))
            return "\(day).\(month).\(year)"
        }

        if let date = ISO8601DateFormatter().date(from: trimmed) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: trimmed) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "ru_RU")
            out.dateFormat = "dd.MM.yyyy"
            return out.string(from: date)
        }
        return trimmed
    }

    private func parsePlanDateToInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.count == 8, let direct = Int(trimmed) {
            return direct
        }
        let parts = trimmed.split(separator: ".")
        if parts.count == 3 {
            let day = Int(parts[0]) ?? 0
            let month = Int(parts[1]) ?? 0
            let year = Int(parts[2]) ?? 0
            guard day > 0, month > 0, year > 0 else { return nil }
            return year * 10000 + month * 100 + day
        }
        return nil
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

private struct AtssEditDraft {
    var serviceId = ""
    var address = ""
    var district = ""
    var planDate = ""
    var comment = ""
}

private struct AtssEditSheet: View {
    let sourceTable: String
    let initialServiceId: String
    let initialAddress: String
    let initialDistrict: String
    let initialPlanDate: String
    let initialComment: String
    let onSave: (AtssEditDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = AtssEditDraft()
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
                TextField("Плановая дата (dd.MM.yyyy или yyyymmdd)", text: $draft.planDate)
                TextField("Комментарий", text: $draft.comment, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section("Источник") {
                Text(sourceTable == "kasip_azm_q1_2026" ? "KASIP AZM" : "ATSS")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Отмена") {
                    dismiss()
                }
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
            draft.planDate = initialPlanDate
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


