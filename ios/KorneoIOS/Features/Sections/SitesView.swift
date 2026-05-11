import SwiftUI

struct SitesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var rows: [GenericRecord] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var detailRow: GenericRecord?
    @State private var pendingDeleteRow: GenericRecord?
    @State private var editRow: GenericRecord?
    @State private var isDeleting = false

    var body: some View {
        Group {
            if isLoading && visibleRows.isEmpty {
                ProgressView("Loading sites...")
            } else if let errorText, visibleRows.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else if visibleRows.isEmpty {
                ContentUnavailableView("No sites", systemImage: "mappin.slash")
            } else {
                List(visibleRows) { row in
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
                        Button("Details", systemImage: "doc.text.magnifyingglass") {
                            detailRow = row
                        }
                        if canDelete {
                            Button("Edit", systemImage: "square.and.pencil") {
                                editRow = row
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDeleteRow = row
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canDelete {
                            Button {
                                editRow = row
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                pendingDeleteRow = row
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle("Sites")
        .searchable(text: $searchText, prompt: "Search by address, EMTS, SK, serial, inventory")
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
                        Button("Close") {
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
                .navigationTitle("Edit Site")
            }
        }
        .confirmationDialog(
            "Delete this site?",
            isPresented: Binding(
                get: { pendingDeleteRow != nil },
                set: { if !$0 { pendingDeleteRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Deleting..." : "Delete", role: .destructive) {
                guard let row = pendingDeleteRow else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    await delete(row: row)
                }
            }
            .disabled(isDeleting)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var canDelete: Bool {
        appState.currentUser?.role?.hasManagerRights == true
    }

    private var visibleRows: [GenericRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { row in
            siteSearchBlob(for: row).lowercased().contains(q)
        }
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
        guard canDelete else { return "Permission denied" }
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        guard !siteId.isEmpty else { return "Invalid record id" }

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
        return emts.isEmpty ? "Site \(safe(siteId))" : "Site \(safe(siteId)) • \(emts)"
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
        Address: \(safe(address))
        District: \(safe(district))
        EMTS / Service ID: \(safe(emts))
        SK count: \(safe(skCount))
        \(skNames.isEmpty ? "" : "SK names: \(skNames)\n")\(serials.isEmpty ? "" : "S/N: \(serials)\n")\(inventories.isEmpty ? "" : "Inventory: \(inventories)")
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func siteDetail(for row: GenericRecord) -> String {
        var lines: [String] = []
        appendLine(&lines, label: "Site ID", value: first(row, keys: ["id_ploshadki", "site_id", "id"]))
        appendLine(&lines, label: "EMTS / Service ID", value: first(row, keys: ["emts", "servisnyy_id", "service_id"]))
        appendLine(&lines, label: "Address", value: first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address", "adres", "address_text"]))
        appendLine(&lines, label: "District", value: first(row, keys: ["rayon", "district"]))
        appendLine(&lines, label: "SK count", value: first(row, keys: ["kolichestvo_sk", "sk_count", "equipment_count"]))
        appendLine(&lines, label: "SK names", value: joined(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_name", "name"]))
        appendLine(&lines, label: "Serials", value: joined(row, baseKey: "serial_number", fallbackKeys: ["servisnyy_id", "service_id", "equipment_serial_number"]))
        appendLine(&lines, label: "Inventory", value: joined(row, baseKey: "inventory_number", fallbackKeys: ["id_sk", "id_konditsionera", "equipment_inventory_number"]))
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
                Section("Error") {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            Section("Main") {
                TextField("Service ID", text: $draft.serviceId)
                TextField("Address", text: $draft.address)
                TextField("District", text: $draft.district)
                TextField("SK count", text: $draft.skCount)
                    .keyboardType(.numberPad)
                TextField("Comment", text: $draft.comment, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
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


