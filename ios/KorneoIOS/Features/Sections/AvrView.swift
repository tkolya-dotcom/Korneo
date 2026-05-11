import SwiftUI

struct AvrView: View {
    private struct StatusOption: Identifiable {
        let value: String
        let title: String
        var id: String { value }
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var purchaseRequestsViewModel = PurchaseRequestsViewModel()

    @State private var rows: [GenericRecord] = []
    @State private var users: [User] = []
    @State private var addressCandidates: [AvrAddressCandidate] = []
    @State private var searchText = ""
    @State private var statusFilter = "all"
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var detailRow: GenericRecord?
    @State private var commentsRow: GenericRecord?
    @State private var pendingArchiveRow: GenericRecord?
    @State private var pendingDeleteRow: GenericRecord?
    @State private var statusTargetRow: GenericRecord?

    @State private var isMutating = false
    @State private var showCreateSheet = false
    @State private var editRow: GenericRecord?
    @State private var materialRequestRow: GenericRecord?
    @State private var equipmentHistoryRow: GenericRecord?
    @State private var equipmentChangeRow: GenericRecord?
    @State private var equipmentPromptRow: GenericRecord?

    private let statusOptions: [StatusOption] = [
        .init(value: "new", title: "Новая"),
        .init(value: "planned", title: "Запланировано"),
        .init(value: "in_progress", title: "В работе"),
        .init(value: "waiting_materials", title: "Ожидание материалов"),
        .init(value: "done", title: "Завершено"),
        .init(value: "postponed", title: "Отложено")
    ]

    var body: some View {
        Group {
            if isLoading && visibleRows.isEmpty {
                ProgressView("Загрузка АВР...")
            } else if let errorText, visibleRows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else if visibleRows.isEmpty {
                ContentUnavailableView("Нет записей АВР", systemImage: "doc.text.magnifyingglass")
            } else {
                List {
                    Section {
                        Picker("Статус", selection: $statusFilter) {
                            Text("Все").tag("all")
                            ForEach(statusOptions) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    ForEach(visibleRows) { row in
                        Button {
                            detailRow = row
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(avrTitle(for: row))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(avrSubtitle(for: row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(5)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Детали", systemImage: "doc.text.magnifyingglass") {
                                detailRow = row
                            }
                            Button("Комментарии", systemImage: "text.bubble") {
                                commentsRow = row
                            }
                            if canEdit {
                                Button("Редактировать", systemImage: "square.and.pencil") {
                                    editRow = row
                                }
                                Button("Заявка на материалы", systemImage: "cart.badge.plus") {
                                    materialRequestRow = row
                                }
                                Button("Изменить статус", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                                    statusTargetRow = row
                                }
                                Button("Изменение оборудования", systemImage: "wrench.and.screwdriver") {
                                    equipmentChangeRow = row
                                }
                                Button("История оборудования", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") {
                                    equipmentHistoryRow = row
                                }
                                Button("В архив", systemImage: "archivebox") {
                                    pendingArchiveRow = row
                                }
                            }
                            if canDelete(row: row) {
                                Button("Удалить", systemImage: "trash", role: .destructive) {
                                    pendingDeleteRow = row
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                commentsRow = row
                            } label: {
                                Label("Комментарии", systemImage: "text.bubble")
                            }
                            .tint(.indigo)

                            if canEdit {
                                Button {
                                    materialRequestRow = row
                                } label: {
                                    Label("Материалы", systemImage: "cart.badge.plus")
                                }
                                .tint(.teal)

                                Button {
                                    pendingArchiveRow = row
                                } label: {
                                    Label("В архив", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle("AVR")
        .searchable(text: $searchText, prompt: "Поиск по названию, адресу, оборудованию")
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            purchaseRequestsViewModel.bind(client: appState.client)
            await loadReferenceData()
            await load()
        }
        .sheet(item: $detailRow) { row in
            NavigationStack {
                ScrollView {
                    Text(avrDetail(for: row))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(avrTitle(for: row))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            detailRow = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $commentsRow) { row in
            NavigationStack {
                CommentsSectionView(
                    entityType: "avr",
                    entityId: row.id,
                    currentUserId: appState.currentUser?.id,
                    client: appState.client
                )
                .padding()
                .navigationTitle("Комментарии")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            commentsRow = nil
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            NavigationStack {
                AvrEditorSheet(mode: .create, users: users, addressCandidates: addressCandidates) { form in
                    await createAvr(from: form)
                }
                .navigationTitle("Создать АВР")
            }
        }
        .sheet(item: $editRow) { row in
            NavigationStack {
                AvrEditorSheet(mode: .edit(prefillForm(from: row)), users: users, addressCandidates: addressCandidates) { form in
                    await updateAvr(id: row.id, from: form)
                }
                .navigationTitle("Редактировать АВР")
            }
        }
        .sheet(item: $materialRequestRow) { row in
            CreatePurchaseRequestView(
                viewModel: purchaseRequestsViewModel,
                initialParentTypeRaw: "avr",
                initialParentId: row.id,
                initialReceiptAddress: first(row, keys: ["address_text", "address"])
            )
            .environmentObject(appState)
        }
        .sheet(item: $equipmentHistoryRow) { row in
            NavigationStack {
                EquipmentHistorySheet(taskId: row.id, client: appState.client)
                    .navigationTitle("История оборудования")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Закрыть") {
                                equipmentHistoryRow = nil
                            }
                        }
                    }
            }
        }
        .sheet(item: $equipmentChangeRow) { row in
            NavigationStack {
                EquipmentChangeSheet(
                    initialEquipmentType: first(row, keys: ["equipment_type", "naimenovanie_sk"]),
                    initialSerial: first(row, keys: ["equipment_serial_number", "serial_number"]),
                    initialBefore: first(row, keys: ["equipment_status", "status"])
                ) { draft in
                    await createEquipmentChange(taskId: row.id, sourceRow: row, draft: draft)
                }
                .navigationTitle("Изменение оборудования")
            }
        }
        .confirmationDialog(
            "Переместить эту запись АВР в архив?",
            isPresented: Binding(
                get: { pendingArchiveRow != nil },
                set: { if !$0 { pendingArchiveRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isMutating ? "Архивация..." : "В архив") {
                guard let row = pendingArchiveRow else { return }
                Task {
                    isMutating = true
                    defer { isMutating = false }
                    await archive(row: row)
                }
            }
            .disabled(isMutating)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Запись будет перемещена в архив.")
        }
        .confirmationDialog(
            "Удалить эту запись АВР?",
            isPresented: Binding(
                get: { pendingDeleteRow != nil },
                set: { if !$0 { pendingDeleteRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isMutating ? "Удаление..." : "Удалить", role: .destructive) {
                guard let row = pendingDeleteRow else { return }
                Task {
                    isMutating = true
                    defer { isMutating = false }
                    await delete(row: row)
                }
            }
            .disabled(isMutating)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .confirmationDialog(
            "Изменить статус АВР",
            isPresented: Binding(
                get: { statusTargetRow != nil },
                set: { if !$0 { statusTargetRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(statusOptions) { option in
                Button(option.title) {
                    guard let row = statusTargetRow else { return }
                    Task {
                        isMutating = true
                        defer { isMutating = false }
                        await updateStatus(row: row, to: option.value)
                    }
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выберите новый статус.")
        }
        .confirmationDialog(
            "Статус «Завершено» установлен",
            isPresented: Binding(
                get: { equipmentPromptRow != nil },
                set: { if !$0 { equipmentPromptRow = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Да, изменить оборудование") {
                guard let row = equipmentPromptRow else { return }
                equipmentPromptRow = nil
                equipmentChangeRow = row
            }
            Button("Нет", role: .cancel) {
                equipmentPromptRow = nil
            }
        } message: {
            Text("Оборудование менялось по этой заявке?")
        }
    }

    private var canEdit: Bool {
        appState.currentUser?.role?.hasCoordinatorRights == true
    }

    private var visibleRows: [GenericRecord] {
        let user = appState.currentUser
        let base = rows.filter { row in
            !(asBool(row.fields["is_archived"]))
        }.filter { row in
            canSee(row: row, userId: user?.id, role: user?.role)
        }

        let byStatus = base.filter { row in
            if statusFilter == "all" { return true }
            return normalized(row.fields["status"]?.textValue).lowercased() == statusFilter
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byStatus }
        return byStatus.filter { avrSearchBlob(for: $0).lowercased().contains(q) }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            rows = try await appState.client.fetchTableRows(
                table: "tasks_avr",
                select: "*",
                order: "created_at.desc.nullslast",
                limit: 500
            )
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func loadReferenceData() async {
        do {
            async let usersReq = appState.client.fetchUsers()
            async let sitesReq = appState.client.fetchSitesRows()
            async let atssReq = appState.client.fetchAtssRowsMerged()
            async let installationsReq = appState.client.fetchInstallations()

            let fetchedUsers = try await usersReq
            let siteRows = try await sitesReq
            let atssRows = try await atssReq
            let installations = try await installationsReq

            users = fetchedUsers.sorted { userLabel($0).localizedCaseInsensitiveCompare(userLabel($1)) == .orderedAscending }

            var candidates: [AvrAddressCandidate] = []
            candidates.append(contentsOf: siteRows.compactMap { makeAddressCandidate(from: $0, source: "sites") })
            candidates.append(contentsOf: atssRows.compactMap { makeAddressCandidate(from: $0, source: sourceTable(from: $0)) })
            candidates.append(contentsOf: installations.compactMap { installation in
                let address = normalized(installation.address)
                if address.isEmpty { return nil }
                let siteId = normalized(installation.idPloshadki)
                let serviceId = normalized(installation.servisnyyId)
                let labelBase = normalized(installation.title).isEmpty ? "Монтаж \(installation.id)" : normalized(installation.title)
                let label = serviceId.isEmpty ? "\(labelBase) • \(address)" : "\(labelBase) • \(serviceId) • \(address)"
                return AvrAddressCandidate(
                    id: "installation:\(installation.id)",
                    source: "installations",
                    label: label,
                    address: address,
                    siteId: siteId,
                    addressId: normalized(installation.id),
                    serviceId: serviceId,
                    inventory: "",
                    equipmentNames: "",
                    equipmentCount: 0,
                    skOptions: []
                )
            })

            var seen = Set<String>()
            addressCandidates = candidates.filter { candidate in
                let key = "\(candidate.source)|\(candidate.siteId)|\(candidate.address)|\(candidate.serviceId)"
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
        } catch {
            users = []
            addressCandidates = []
        }
    }

    private func archive(row: GenericRecord) async {
        guard canEdit else { return }
        do {
            try await appState.client.archiveAvr(id: row.id)
            pendingArchiveRow = nil
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(row: GenericRecord) async {
        guard canDelete(row: row) else { return }
        do {
            try await appState.client.deleteAvrTask(id: row.id)
            pendingDeleteRow = nil
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func updateStatus(row: GenericRecord, to status: String) async {
        guard canEdit else { return }
        do {
            let beforeStatus = first(row, keys: ["status"])
            try await appState.client.updateAvrStatus(id: row.id, status: status)
            if let userId = appState.currentUser?.id, !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let changePayload: [String: JSONValue] = [
                    "task_id": .string(row.id),
                    "changed_by": .string(userId),
                    "change_type": .string("status"),
                    "field_name": .string("status"),
                    "before_status": .string(beforeStatus),
                    "after_status": .string(status),
                    "comment": .string("Статус изменён из экрана АВР")
                ]
                _ = try? await appState.client.createEquipmentChange(payload: changePayload)
            }
            await notifyAvrChanged(row: row, changeText: "Статус изменён: \(statusLabel(status))")
            if status.lowercased() == "done" {
                equipmentPromptRow = row
            }
            statusTargetRow = nil
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func createAvr(from form: AvrFormData) async -> String? {
        guard let userId = appState.currentUser?.id else {
            return "User is not loaded"
        }
        let cleanEngineerIds = Array(Set(form.engineerIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        let fallbackResponsibleId = cleanEngineerIds.first ?? ""
        let responsibleId = form.responsibleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackResponsibleId : form.responsibleId
        let selectedCandidate = addressCandidates.first(where: { $0.id == form.selectedAddressId })
        let equipment = resolveEquipmentInput(form: form, candidate: selectedCandidate)

        var payload: [String: JSONValue] = [
            "type": .string(form.type),
            "status": .string("new"),
            "created_by": .string(userId),
            "title": .string(form.title),
            "date_from": .string(form.dateFrom),
            "date_to": .string(form.dateTo),
            "due_date": .string(form.dateTo)
        ]
        putIfNotBlank(&payload, key: "project_id", value: form.projectId)
        putIfNotBlank(&payload, key: "executor_id", value: responsibleId)
        putIfNotBlank(&payload, key: "assignee_id", value: responsibleId)
        putIfNotBlank(&payload, key: "address_text", value: form.address)
        putIfNotBlank(&payload, key: "address", value: form.address)
        putIfNotBlank(&payload, key: "description", value: form.comment)
        putIfNotBlank(&payload, key: "comment", value: form.comment)
        putIfNotBlank(&payload, key: "planned_installation_date", value: form.plannedDate)
        putIfNotBlank(&payload, key: "equipment_type", value: equipment.type)
        putIfNotBlank(&payload, key: "naimenovanie_sk", value: equipment.type)
        putIfNotBlank(&payload, key: "equipment_serial_number", value: equipment.serial)
        putIfNotBlank(&payload, key: "serial_number", value: equipment.serial)
        putIfNotBlank(&payload, key: "equipment_inventory_number", value: equipment.inventory)
        putIfNotBlank(&payload, key: "inventory_number", value: equipment.inventory)
        putIfNotBlank(&payload, key: "equipment_status", value: equipment.status)
        putIfNotBlank(&payload, key: "status_sk", value: equipment.status)
        putIfNotBlank(&payload, key: "equipment_comment", value: equipment.comment)
        putIfNotBlank(&payload, key: "kommentariy", value: equipment.comment)
        if let count = parsePositiveInt(equipment.count), count > 0 {
            payload["total_equipment_count"] = .number(Double(count))
        }
        if !cleanEngineerIds.isEmpty {
            payload["engineer_ids"] = .array(cleanEngineerIds.map { .string($0) })
            payload["executor_ids"] = .array(cleanEngineerIds.map { .string($0) })
            payload["engineers_count"] = .number(Double(cleanEngineerIds.count))
            let names = cleanEngineerIds.map { userName(for: $0) }.joined(separator: ", ")
            if !names.isEmpty {
                payload["engineers"] = .string(names)
            }
        }
        if let candidate = selectedCandidate {
            putIfNotBlank(&payload, key: "site_id", value: candidate.siteId)
            putIfNotBlank(&payload, key: "address_id", value: candidate.addressId)
            if normalized(form.address).isEmpty {
                putIfNotBlank(&payload, key: "address_text", value: candidate.address)
                putIfNotBlank(&payload, key: "address", value: candidate.address)
            }
            if normalized(equipment.serial).isEmpty {
                putIfNotBlank(&payload, key: "equipment_serial_number", value: candidate.serviceId)
                putIfNotBlank(&payload, key: "serial_number", value: candidate.serviceId)
            }
            if normalized(equipment.inventory).isEmpty {
                putIfNotBlank(&payload, key: "equipment_inventory_number", value: candidate.inventory)
                putIfNotBlank(&payload, key: "inventory_number", value: candidate.inventory)
            }
            if normalized(equipment.type).isEmpty {
                putIfNotBlank(&payload, key: "equipment_type", value: candidate.equipmentNames)
                putIfNotBlank(&payload, key: "naimenovanie_sk", value: candidate.equipmentNames)
            }
            if parsePositiveInt(equipment.count) == nil, candidate.equipmentCount > 0 {
                payload["total_equipment_count"] = .number(Double(candidate.equipmentCount))
            }
        }

        do {
            let created = try await appState.client.createAvrTask(payload: payload)
            await notifyAvrCreated(responsibleId: responsibleId, row: created)
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func updateAvr(id: String, from form: AvrFormData) async -> String? {
        let sourceRow = rows.first(where: { $0.id == id })
        let cleanEngineerIds = Array(Set(form.engineerIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        let fallbackResponsibleId = cleanEngineerIds.first ?? ""
        let responsibleId = form.responsibleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackResponsibleId : form.responsibleId
        let selectedCandidate = addressCandidates.first(where: { $0.id == form.selectedAddressId })
        let equipment = resolveEquipmentInput(form: form, candidate: selectedCandidate)

        var patch: [String: JSONValue] = [
            "type": .string(form.type),
            "title": .string(form.title),
            "date_from": .string(form.dateFrom),
            "date_to": .string(form.dateTo),
            "due_date": .string(form.dateTo)
        ]
        putIfNotBlank(&patch, key: "project_id", value: form.projectId)
        putIfNotBlank(&patch, key: "executor_id", value: responsibleId)
        putIfNotBlank(&patch, key: "assignee_id", value: responsibleId)
        putIfNotBlank(&patch, key: "address_text", value: form.address)
        putIfNotBlank(&patch, key: "address", value: form.address)
        putIfNotBlank(&patch, key: "description", value: form.comment)
        putIfNotBlank(&patch, key: "comment", value: form.comment)
        putIfNotBlank(&patch, key: "planned_installation_date", value: form.plannedDate)
        putIfNotBlank(&patch, key: "equipment_type", value: equipment.type)
        putIfNotBlank(&patch, key: "naimenovanie_sk", value: equipment.type)
        putIfNotBlank(&patch, key: "equipment_serial_number", value: equipment.serial)
        putIfNotBlank(&patch, key: "serial_number", value: equipment.serial)
        putIfNotBlank(&patch, key: "equipment_inventory_number", value: equipment.inventory)
        putIfNotBlank(&patch, key: "inventory_number", value: equipment.inventory)
        putIfNotBlank(&patch, key: "equipment_status", value: equipment.status)
        putIfNotBlank(&patch, key: "status_sk", value: equipment.status)
        putIfNotBlank(&patch, key: "equipment_comment", value: equipment.comment)
        putIfNotBlank(&patch, key: "kommentariy", value: equipment.comment)
        if let count = parsePositiveInt(equipment.count), count > 0 {
            patch["total_equipment_count"] = .number(Double(count))
        }
        if !cleanEngineerIds.isEmpty {
            patch["engineer_ids"] = .array(cleanEngineerIds.map { .string($0) })
            patch["executor_ids"] = .array(cleanEngineerIds.map { .string($0) })
            patch["engineers_count"] = .number(Double(cleanEngineerIds.count))
            let names = cleanEngineerIds.map { userName(for: $0) }.joined(separator: ", ")
            if !names.isEmpty {
                patch["engineers"] = .string(names)
            }
        }
        if let candidate = selectedCandidate {
            putIfNotBlank(&patch, key: "site_id", value: candidate.siteId)
            putIfNotBlank(&patch, key: "address_id", value: candidate.addressId)
            if normalized(form.address).isEmpty {
                putIfNotBlank(&patch, key: "address_text", value: candidate.address)
                putIfNotBlank(&patch, key: "address", value: candidate.address)
            }
            if parsePositiveInt(equipment.count) == nil, candidate.equipmentCount > 0 {
                patch["total_equipment_count"] = .number(Double(candidate.equipmentCount))
            }
        }

        do {
            try await appState.client.updateAvrTask(id: id, patch: patch)
            if let sourceRow {
                await notifyAvrChanged(row: sourceRow, changeText: "АВР обновлена")
            }
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func resolveEquipmentInput(form: AvrFormData, candidate: AvrAddressCandidate?) -> (type: String, serial: String, inventory: String, status: String, comment: String, count: String) {
        let formType = normalized(form.equipmentType)
        let formSerial = normalized(form.serial)
        let formInventory = normalized(form.inventory)
        let formStatus = normalized(form.equipmentStatus)
        let formComment = normalized(form.equipmentComment)
        let formCount = normalized(form.equipmentCount)

        guard let candidate else {
            return (formType, formSerial, formInventory, formStatus, formComment, formCount)
        }

        let selected = candidate.skOptions.filter { option in
            form.selectedSkOptionKeys.contains(option.id) || form.selectedSkOptionKeys.contains(option.name)
        }
        if selected.isEmpty {
            return (formType, formSerial, formInventory, formStatus, formComment, formCount)
        }

        let names = selected.map(\.name).filter { !$0.isEmpty }
        let ids = selected.map(\.idValue).filter { !$0.isEmpty }
        let serials = selected.map(\.serial).filter { !$0.isEmpty }

        var statuses: [String] = []
        for value in selected.map(\.status) where !value.isEmpty && !statuses.contains(value) {
            statuses.append(value)
        }
        var comments: [String] = []
        for value in selected.map(\.comment) where !value.isEmpty && !comments.contains(value) {
            comments.append(value)
        }

        return (
            type: formType.isEmpty ? names.joined(separator: "; ") : formType,
            serial: formSerial.isEmpty ? serials.joined(separator: "; ") : formSerial,
            inventory: formInventory.isEmpty ? ids.joined(separator: "; ") : formInventory,
            status: formStatus.isEmpty ? statuses.joined(separator: "; ") : formStatus,
            comment: formComment.isEmpty ? comments.joined(separator: "; ") : formComment,
            count: formCount.isEmpty ? String(selected.count) : formCount
        )
    }

    private func notifyAvrCreated(responsibleId: String, row: GenericRecord?) async {
        let target = responsibleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        guard target != appState.currentUser?.id else { return }

        let title = "Новая АВР"
        let rowTitle = row.map { first($0, keys: ["title"]) } ?? ""
        let bodyTitle = rowTitle.isEmpty ? "Новая заявка" : rowTitle
        let body = "\(bodyTitle)\nВы назначены ответственным"
        try? await appState.client.sendWorkAlertPush(
            targetUserId: target,
            title: title,
            bodyText: body,
            chatId: nil,
            senderId: appState.currentUser?.id
        )
    }

    private func notifyAvrChanged(row: GenericRecord, changeText: String) async {
        let currentUserId = appState.currentUser?.id.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let assignedIds = Set(assignedEngineerIds(for: row))
        let title = "АВР изменена"
        let rowTitle = first(row, keys: ["title"])
        let bodyTitle = rowTitle.isEmpty ? "Заявка" : rowTitle
        let body = "\(bodyTitle)\n\(changeText.isEmpty ? "Есть изменения" : changeText)"

        for user in users {
            let userId = user.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if userId.isEmpty || userId == currentUserId { continue }
            if assignedIds.contains(userId) { continue }
            try? await appState.client.sendWorkAlertPush(
                targetUserId: userId,
                title: title,
                bodyText: body,
                chatId: nil,
                senderId: currentUserId
            )
        }
    }

    private func assignedEngineerIds(for row: GenericRecord) -> [String] {
        var result: [String] = []
        for value in parseIds(row.fields["engineer_ids"]) + parseIds(row.fields["executor_ids"]) {
            if !value.isEmpty && !result.contains(value) {
                result.append(value)
            }
        }
        let single = [first(row, keys: ["executor_id"]), first(row, keys: ["assignee_id"])]
        for value in single where !value.isEmpty && !result.contains(value) {
            result.append(value)
        }
        if result.count > 6 {
            return Array(result.prefix(6))
        }
        return result
    }

    private func createEquipmentChange(taskId: String, sourceRow: GenericRecord, draft: EquipmentChangeDraft) async -> String? {
        guard let userId = appState.currentUser?.id else {
            return "User is not loaded"
        }

        var payload: [String: JSONValue] = [
            "task_id": .string(taskId),
            "changed_by": .string(userId),
            "change_type": .string(draft.changeType),
            "field_name": .string(draft.fieldName),
            "before_status": .string(draft.beforeValue),
            "after_status": .string(draft.afterValue),
            "comment": .string(draft.comment)
        ]
        putIfNotBlank(&payload, key: "serial_number", value: draft.serial)
        putIfNotBlank(&payload, key: "equipment_type", value: draft.equipmentType)

        do {
            _ = try await appState.client.createEquipmentChange(payload: payload)
            var avrPatch: [String: JSONValue] = [:]
            putIfNotBlank(&avrPatch, key: "equipment_type", value: draft.equipmentType)
            putIfNotBlank(&avrPatch, key: "equipment_serial_number", value: draft.serial)
            putIfNotBlank(&avrPatch, key: "equipment_status", value: draft.afterValue)
            putIfNotBlank(&avrPatch, key: "equipment_comment", value: draft.comment)
            if !avrPatch.isEmpty {
                try? await appState.client.updateAvrTask(id: taskId, patch: avrPatch)
            }
            await notifyAvrChanged(row: sourceRow, changeText: "Оборудование изменено")
            await load()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func canDelete(row: GenericRecord) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true {
            return true
        }
        let createdBy = normalized(row.fields["created_by"]?.textValue)
        return !createdBy.isEmpty && createdBy == user.id
    }

    private func canSee(row: GenericRecord, userId: String?, role: Role?) -> Bool {
        guard let userId else { return false }
        if role?.hasCoordinatorRights == true {
            return true
        }
        let createdBy = normalized(row.fields["created_by"]?.textValue)
        let executorId = first(row, keys: ["executor_id", "assignee_id"])
        if createdBy == userId || executorId == userId {
            return true
        }
        let engineerIds = parseIds(row.fields["engineer_ids"]) + parseIds(row.fields["executor_ids"])
        return engineerIds.contains(userId)
    }

    private func sourceTable(from row: GenericRecord) -> String {
        normalized(row.fields["__source_table"]?.textValue)
    }

    private func makeAddressCandidate(from row: GenericRecord, source: String) -> AvrAddressCandidate? {
        let siteId = first(row, keys: ["id_ploshadki", "site_id", "id"])
        let address = first(row, keys: ["adres_razmeshcheniya", "adres_raspolozheniya", "address_text", "address", "adres"])
        let serviceId = first(row, keys: ["servisnyy_id", "service_id", "emts", "equipment_serial_number", "serial_number"])
        let inventory = first(row, keys: ["equipment_inventory_number", "inventory_number", "id_sk", "id_konditsionera"])
        let equipmentNames = joinedIndexed(row, baseKey: "naimenovanie_sk", fallbackKeys: ["equipment_type", "equipment_name", "name"])
        let options = skOptions(from: row)
        if siteId.isEmpty && address.isEmpty && serviceId.isEmpty { return nil }

        let sourceLabel: String = {
            if source == "kasip_azm_q1_2026" { return "KASIP" }
            if source == "atss_q1_2026" { return "ATSS" }
            if source == "sites" { return "SITE" }
            return source.uppercased()
        }()
        let idLabel = siteId.isEmpty ? "-" : siteId
        var label = "\(sourceLabel) \(idLabel)"
        if !serviceId.isEmpty { label += " • \(serviceId)" }
        if !address.isEmpty { label += " • \(address)" }

        return AvrAddressCandidate(
            id: "\(source):\(siteId.isEmpty ? "\(address)|\(serviceId)" : siteId)",
            source: source,
            label: label,
            address: address,
            siteId: siteId,
            addressId: first(row, keys: ["address_id", "id"]),
            serviceId: serviceId,
            inventory: inventory,
            equipmentNames: equipmentNames,
            equipmentCount: equipmentCount(from: row, options: options, equipmentNames: equipmentNames),
            skOptions: options
        )
    }

    private func joinedIndexed(_ row: GenericRecord, baseKey: String, fallbackKeys: [String]) -> String {
        var values: [String] = []
        let single = first(row, keys: [baseKey] + fallbackKeys)
        if !single.isEmpty { values.append(single) }
        for i in 1...6 {
            let value = normalized(row.fields["\(baseKey)\(i)"]?.textValue)
            if !value.isEmpty, !values.contains(value) {
                values.append(value)
            }
        }
        return values.joined(separator: "; ")
    }

    private func skOptions(from row: GenericRecord) -> [AvrSkOption] {
        var values: [AvrSkOption] = []
        for i in 1...6 {
            let name = normalized(row.fields["naimenovanie_sk\(i)"]?.textValue)
            if name.isEmpty { continue }
            let idValue = first(row, keys: ["inventory_number\(i)", "id_sk\(i)", "id_konditsionera\(i)"])
            let serial = first(row, keys: ["serial_number\(i)", "servisnyy_id\(i)", "service_id\(i)"])
            let status = first(row, keys: ["status_sk\(i)", "status_oborudovaniya\(i)"])
            let comment = first(row, keys: ["kommentariy\(i)", "kommentarij\(i)", "comment\(i)", "primechanie\(i)", "primechanie_sk\(i)", "tip_sk_po_dogovoru\(i)"])
            values.append(
                AvrSkOption(
                    slot: i,
                    idValue: idValue,
                    name: name,
                    serial: serial,
                    status: status,
                    comment: comment
                )
            )
        }

        if !values.isEmpty {
            return values
        }

        let baseName = first(row, keys: ["naimenovanie_sk", "equipment_type"])
        if baseName.isEmpty {
            return []
        }
        return [
            AvrSkOption(
                slot: 1,
                idValue: first(row, keys: ["inventory_number", "id_sk", "equipment_inventory_number"]),
                name: baseName,
                serial: first(row, keys: ["serial_number", "servisnyy_id", "service_id", "equipment_serial_number"]),
                status: first(row, keys: ["status_sk", "status_oborudovaniya", "equipment_status"]),
                comment: first(row, keys: ["kommentariy", "kommentarij", "comment", "primechanie", "equipment_comment", "tip_sk_po_dogovoru"])
            )
        ]
    }

    private func equipmentCount(from row: GenericRecord, options: [AvrSkOption], equipmentNames: String) -> Int {
        if !options.isEmpty {
            return options.count
        }
        if let explicit = parsePositiveInt(first(row, keys: ["total_equipment_count", "equipment_count", "sk_count"])), explicit > 0 {
            return explicit
        }
        let names = equipmentNames
            .split(separator: ";")
            .map { normalized(String($0)) }
            .filter { !$0.isEmpty }
        return names.count
    }

    private func parsePositiveInt(_ raw: String) -> Int? {
        let text = normalized(raw)
        guard !text.isEmpty else { return nil }
        if let value = Int(text), value > 0 { return value }
        if let value = Double(text), value > 0 {
            return Int(value.rounded())
        }
        return nil
    }

    private func userLabel(_ user: User) -> String {
        let name = normalized(user.name)
        if !name.isEmpty { return name }
        let email = normalized(user.email)
        if !email.isEmpty { return email }
        return user.id
    }

    private func userName(for userId: String) -> String {
        guard !userId.isEmpty else { return "" }
        if let user = users.first(where: { $0.id == userId }) {
            return userLabel(user)
        }
        return userId
    }

    private func prefillForm(from row: GenericRecord) -> AvrFormData {
        let equipmentType = first(row, keys: ["equipment_type", "naimenovanie_sk"])
        return AvrFormData(
            type: first(row, keys: ["type"]).isEmpty ? "AVR" : first(row, keys: ["type"]),
            title: first(row, keys: ["title"]),
            address: first(row, keys: ["address_text", "address"]),
            dateFrom: first(row, keys: ["date_from", "due_date"]).prefix(10).description,
            dateTo: first(row, keys: ["date_to", "due_date"]).prefix(10).description,
            plannedDate: first(row, keys: ["planned_installation_date"]).prefix(10).description,
            comment: first(row, keys: ["description", "comment"]),
            projectId: first(row, keys: ["project_id"]),
            responsibleId: first(row, keys: ["executor_id", "assignee_id"]),
            equipmentType: equipmentType,
            serial: first(row, keys: ["equipment_serial_number", "serial_number"]),
            inventory: first(row, keys: ["equipment_inventory_number", "inventory_number"]),
            equipmentStatus: first(row, keys: ["equipment_status", "status_sk", "status_oborudovaniya"]),
            equipmentComment: first(row, keys: ["equipment_comment", "kommentariy", "comment"]),
            equipmentCount: first(row, keys: ["total_equipment_count", "equipment_count", "sk_count"]),
            engineerIds: parseIds(row.fields["engineer_ids"]).isEmpty ? parseIds(row.fields["executor_ids"]) : parseIds(row.fields["engineer_ids"]),
            selectedSkOptionKeys: [],
            selectedAddressId: resolveAddressCandidateId(for: row)
        )
    }

    private func resolveAddressCandidateId(for row: GenericRecord) -> String {
        let siteId = first(row, keys: ["site_id", "id_ploshadki"])
        let address = first(row, keys: ["address_text", "address", "adres_razmeshcheniya", "adres_raspolozheniya"])
        let direct = addressCandidates.first { candidate in
            if !siteId.isEmpty, candidate.siteId == siteId { return true }
            if !address.isEmpty, candidate.address == address { return true }
            return false
        }
        return direct?.id ?? ""
    }

    private func avrTitle(for row: GenericRecord) -> String {
        let title = first(row, keys: ["title"])
        if !title.isEmpty { return title }
        let type = typeLabel(first(row, keys: ["type"]))
        let shortId = first(row, keys: ["short_id", "id"])
        return "\(type) \(safe(shortId))"
    }

    private func avrSubtitle(for row: GenericRecord) -> String {
        let type = typeLabel(first(row, keys: ["type"]))
        let status = statusLabel(first(row, keys: ["status"]))
        let address = first(row, keys: ["address_text", "address"])
        let equipment = compactEquipment(first(row, keys: ["equipment_type", "naimenovanie_sk"]))
        let from = displayDate(first(row, keys: ["date_from", "due_date", "created_at"]))
        let to = displayDate(first(row, keys: ["date_to", "due_date", "updated_at"]))
        return """
        Тип: \(type) | Статус: \(status)
        Период: \(safe(from)) - \(safe(to))
        Адрес: \(safe(address))
        \(equipment.isEmpty ? "" : "Оборудование: \(equipment)")
        """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func avrDetail(for row: GenericRecord) -> String {
        var lines: [String] = []
        appendLine(&lines, label: "ID", value: row.id)
        appendLine(&lines, label: "Название", value: first(row, keys: ["title"]))
        appendLine(&lines, label: "Тип", value: typeLabel(first(row, keys: ["type"])))
        appendLine(&lines, label: "Статус", value: statusLabel(first(row, keys: ["status"])))
        appendLine(&lines, label: "Проект", value: first(row, keys: ["project_id"]))
        appendLine(&lines, label: "Ответственный", value: first(row, keys: ["executor_id", "assignee_id"]))
        appendLine(&lines, label: "Инженеры", value: first(row, keys: ["engineers"]))
        appendLine(&lines, label: "Адрес", value: first(row, keys: ["address_text", "address"]))
        appendLine(&lines, label: "Дата начала", value: displayDate(first(row, keys: ["date_from", "due_date"])))
        appendLine(&lines, label: "Дата окончания", value: displayDate(first(row, keys: ["date_to", "due_date"])))
        appendLine(&lines, label: "Плановая установка", value: displayDate(first(row, keys: ["planned_installation_date"])))
        appendLine(&lines, label: "Оборудование", value: first(row, keys: ["equipment_type", "naimenovanie_sk"]))
        appendLine(&lines, label: "Серийный номер", value: first(row, keys: ["equipment_serial_number", "serial_number"]))
        appendLine(&lines, label: "Инвентарный номер", value: first(row, keys: ["equipment_inventory_number", "inventory_number"]))
        appendLine(&lines, label: "Состояние оборудования", value: first(row, keys: ["equipment_status", "status_sk", "status_oborudovaniya"]))
        appendLine(&lines, label: "Комментарий по оборудованию", value: first(row, keys: ["equipment_comment", "kommentariy", "comment"]))
        appendLine(&lines, label: "Количество оборудования", value: first(row, keys: ["total_equipment_count", "equipment_count", "sk_count"]))
        appendLine(&lines, label: "Описание", value: first(row, keys: ["description", "comment"]))
        appendLine(&lines, label: "Создано", value: displayDateTime(first(row, keys: ["created_at"])))
        appendLine(&lines, label: "Обновлено", value: displayDateTime(first(row, keys: ["updated_at"])))
        return lines.joined(separator: "\n\n")
    }

    private func avrSearchBlob(for row: GenericRecord) -> String {
        [
            first(row, keys: ["title", "type", "status"]),
            first(row, keys: ["address_text", "address"]),
            first(row, keys: ["equipment_type", "naimenovanie_sk"]),
            first(row, keys: ["equipment_serial_number", "serial_number"]),
            first(row, keys: ["equipment_inventory_number", "inventory_number"]),
            first(row, keys: ["project_id", "executor_id", "assignee_id"])
        ].joined(separator: " ")
    }

    private func typeLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "nrd":
            return "NRD"
        case "tech_task":
            return "Техзадание"
        default:
            return raw.isEmpty ? "AVR" : raw.uppercased()
        }
    }

    private func statusLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "new": return "Новая"
        case "planned": return "Запланировано"
        case "in_progress": return "В работе"
        case "waiting_materials": return "Ожидание материалов"
        case "done", "completed": return "Завершено"
        case "postponed": return "Отложено"
        case "cancelled": return "Отменено"
        default: return raw.isEmpty ? "-" : raw
        }
    }

    private func compactEquipment(_ raw: String) -> String {
        let cleaned = normalized(raw)
        if cleaned.count <= 80 {
            return cleaned
        }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: 77)
        return "\(cleaned[..<idx])..."
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

    private func parseIds(_ value: JSONValue?) -> [String] {
        guard let value else { return [] }
        switch value {
        case let .array(values):
            return values.map { normalized($0.textValue) }.filter { !$0.isEmpty }
        case let .string(text):
            return text
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .split(separator: ",")
                .map { normalized(String($0)) }
                .filter { !$0.isEmpty }
        default:
            return []
        }
    }

    private func putIfNotBlank(_ payload: inout [String: JSONValue], key: String, value: String) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        payload[key] = .string(clean)
    }

    private func asBool(_ value: JSONValue?) -> Bool {
        normalized(value?.textValue).lowercased() == "true"
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

    private func safe(_ value: String) -> String {
        value.isEmpty ? "-" : value
    }

    private func displayDate(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        if let iso = ISO8601DateFormatter().date(from: raw) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: iso)
        }
        if raw.count >= 10, raw.contains("-") {
            return String(raw.prefix(10).split(separator: "-").reversed().joined(separator: "."))
        }
        return raw
    }

    private func displayDateTime(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy HH:mm"
        return out.string(from: date)
    }

    private func appendLine(_ lines: inout [String], label: String, value: String) {
        guard !value.isEmpty else { return }
        lines.append("\(label): \(value)")
    }
}

private struct AvrFormData {
    var type: String = "AVR"
    var title = ""
    var address = ""
    var dateFrom = ""
    var dateTo = ""
    var plannedDate = ""
    var comment = ""
    var projectId = ""
    var responsibleId = ""
    var equipmentType = ""
    var serial = ""
    var inventory = ""
    var equipmentStatus = ""
    var equipmentComment = ""
    var equipmentCount = ""
    var engineerIds: [String] = []
    var selectedSkOptionKeys: [String] = []
    var selectedAddressId = ""
}

private struct AvrSkOption: Identifiable, Hashable {
    let slot: Int
    let idValue: String
    let name: String
    let serial: String
    let status: String
    let comment: String

    var id: String {
        "slot\(slot)|\(name)|\(idValue)"
    }

    var fullLabel: String {
        let slotLabel = "SK\(slot)"
        let idPart = idValue.isEmpty ? "-" : idValue
        let serialPart = serial.isEmpty ? "-" : serial
        return "\(slotLabel): \(name) | id: \(idPart) | serial: \(serialPart)"
    }
}

private struct AvrAddressCandidate: Identifiable {
    let id: String
    let source: String
    let label: String
    let address: String
    let siteId: String
    let addressId: String
    let serviceId: String
    let inventory: String
    let equipmentNames: String
    let equipmentCount: Int
    let skOptions: [AvrSkOption]
}

private struct EquipmentChangeDraft {
    var changeType = "diagnostics"
    var fieldName = "equipment_type"
    var equipmentType = ""
    var serial = ""
    var beforeValue = ""
    var afterValue = ""
    var comment = ""
}

private struct AvrEditorSheet: View {
    enum Mode {
        case create
        case edit(AvrFormData)
    }

    let mode: Mode
    let users: [User]
    let addressCandidates: [AvrAddressCandidate]
    let onSave: (AvrFormData) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var form = AvrFormData()
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var addressSearch = ""

    private let typeOptions = ["AVR", "NRD", "TECH_TASK"]

    var body: some View {
        Form {
            if let errorText {
                Section("Ошибка") {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            Section("Основное") {
                Picker("Тип", selection: $form.type) {
                    ForEach(typeOptions, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                TextField("Название", text: $form.title)
                TextField("Адрес", text: $form.address)
                TextField("Описание", text: $form.comment, axis: .vertical)
                    .lineLimit(2...5)
            }
            if !addressCandidates.isEmpty {
                Section("Каталог адресов") {
                    TextField("Поиск по каталогу адресов", text: $addressSearch)
                    if !selectedAddressLabel.isEmpty {
                        Text("Выбрано: \(selectedAddressLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filteredAddressCandidates.prefix(12)) { candidate in
                        Button {
                            applyCandidate(candidate)
                        } label: {
                            Text(candidate.label)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            Section("Даты (ГГГГ-ММ-ДД)") {
                TextField("Дата с", text: $form.dateFrom)
                TextField("Дата по", text: $form.dateTo)
                TextField("Плановая дата", text: $form.plannedDate)
            }
            Section("Связи") {
                TextField("ID проекта", text: $form.projectId)
                if users.isEmpty {
                    TextField("ID ответственного", text: $form.responsibleId)
                } else {
                    Picker("Ответственный", selection: $form.responsibleId) {
                        Text("Не назначен").tag("")
                        ForEach(users) { user in
                            Text(userLabel(user)).tag(user.id)
                        }
                    }
                }
            }
            if !users.isEmpty {
                Section("Инженеры (1-6)") {
                    ForEach(engineerUsers) { user in
                        Toggle(userLabel(user), isOn: engineerBinding(user.id))
                    }
                }
            }
            Section("Оборудование") {
                TextField("Тип оборудования", text: $form.equipmentType)
                TextField("Серийный номер", text: $form.serial)
                TextField("Инвентарный номер", text: $form.inventory)
                TextField("Состояние", text: $form.equipmentStatus)
                TextField("Комментарий", text: $form.equipmentComment, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Количество", text: $form.equipmentCount)
                    .keyboardType(.numberPad)
            }
            if !selectedCandidateSkOptions.isEmpty {
                Section("Слоты СК") {
                    ForEach(selectedCandidateSkOptions) { option in
                        Toggle(option.fullLabel, isOn: skBinding(option))
                            .font(.caption)
                    }
                }
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
                .disabled(isSaving || !isValid)
            }
        }
        .task {
            if case .edit(let data) = mode {
                form = data
            } else {
                let today = DateFormatter.yyyyMMdd.string(from: Date())
                if form.dateFrom.isEmpty { form.dateFrom = today }
                if form.dateTo.isEmpty { form.dateTo = today }
            }
            if form.selectedAddressId.isEmpty {
                addressSearch = form.address
            }
            hydrateSkSelectionFromForm()
        }
    }

    private var isValid: Bool {
        !form.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !form.dateFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !form.dateTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var engineerUsers: [User] {
        users.filter { user in
            guard let role = user.role else { return false }
            return role == .engineer || role.hasManagerRights || role == .support
        }
    }

    private var filteredAddressCandidates: [AvrAddressCandidate] {
        let query = clean(addressSearch).lowercased()
        if query.isEmpty { return addressCandidates }
        return addressCandidates.filter { candidate in
            candidate.label.lowercased().contains(query) ||
            candidate.address.lowercased().contains(query) ||
            candidate.serviceId.lowercased().contains(query) ||
            candidate.siteId.lowercased().contains(query) ||
            candidate.inventory.lowercased().contains(query)
        }
    }

    private var selectedAddressLabel: String {
        guard let candidate = addressCandidates.first(where: { $0.id == form.selectedAddressId }) else { return "" }
        return candidate.label
    }

    private var selectedCandidateSkOptions: [AvrSkOption] {
        guard let candidate = addressCandidates.first(where: { $0.id == form.selectedAddressId }) else { return [] }
        return candidate.skOptions
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorText = nil
        if let error = await onSave(form) {
            errorText = error
        } else {
            dismiss()
        }
    }

    private func applyCandidate(_ candidate: AvrAddressCandidate) {
        form.selectedAddressId = candidate.id
        addressSearch = candidate.label
        if clean(form.address).isEmpty {
            form.address = candidate.address
        }
        if clean(form.serial).isEmpty {
            form.serial = candidate.serviceId
        }
        if clean(form.inventory).isEmpty {
            form.inventory = candidate.inventory
        }
        if clean(form.equipmentType).isEmpty {
            form.equipmentType = candidate.equipmentNames
        }
        if clean(form.equipmentCount).isEmpty, candidate.equipmentCount > 0 {
            form.equipmentCount = String(candidate.equipmentCount)
        }
        if candidate.skOptions.count == 1 && form.selectedSkOptionKeys.isEmpty {
            form.selectedSkOptionKeys = [candidate.skOptions[0].id]
            applySelectedSkOptions(candidate.skOptions)
        } else {
            hydrateSkSelectionFromForm()
        }
    }

    private func engineerBinding(_ userId: String) -> Binding<Bool> {
        Binding(
            get: { form.engineerIds.contains(userId) },
            set: { selected in
                if selected {
                    if !form.engineerIds.contains(userId), form.engineerIds.count < 6 {
                        form.engineerIds.append(userId)
                    }
                } else {
                    form.engineerIds.removeAll { $0 == userId }
                }
            }
        )
    }

    private func skBinding(_ option: AvrSkOption) -> Binding<Bool> {
        Binding(
            get: { form.selectedSkOptionKeys.contains(option.id) },
            set: { selected in
                if selected {
                    if !form.selectedSkOptionKeys.contains(option.id) {
                        form.selectedSkOptionKeys.append(option.id)
                    }
                } else {
                    form.selectedSkOptionKeys.removeAll { $0 == option.id }
                }
                applySelectedSkOptions(selectedCandidateSkOptions.filter { form.selectedSkOptionKeys.contains($0.id) })
            }
        )
    }

    private func hydrateSkSelectionFromForm() {
        guard !selectedCandidateSkOptions.isEmpty else { return }
        if !form.selectedSkOptionKeys.isEmpty {
            return
        }

        let typedNames = clean(form.equipmentType)
            .split(separator: ";")
            .map { clean(String($0)).lowercased() }
            .filter { !$0.isEmpty }
        if typedNames.isEmpty {
            if selectedCandidateSkOptions.count == 1 {
                form.selectedSkOptionKeys = [selectedCandidateSkOptions[0].id]
                applySelectedSkOptions([selectedCandidateSkOptions[0]])
            }
            return
        }

        var keys: [String] = []
        for option in selectedCandidateSkOptions {
            if typedNames.contains(option.name.lowercased()) {
                keys.append(option.id)
            }
        }
        if !keys.isEmpty {
            form.selectedSkOptionKeys = keys
            applySelectedSkOptions(selectedCandidateSkOptions.filter { keys.contains($0.id) })
        }
    }

    private func applySelectedSkOptions(_ options: [AvrSkOption]) {
        guard !options.isEmpty else { return }
        let names = options.map(\.name).filter { !$0.isEmpty }
        let ids = options.map(\.idValue).filter { !$0.isEmpty }
        let serials = options.map(\.serial).filter { !$0.isEmpty }

        var statuses: [String] = []
        for value in options.map(\.status) where !value.isEmpty && !statuses.contains(value) {
            statuses.append(value)
        }
        var comments: [String] = []
        for value in options.map(\.comment) where !value.isEmpty && !comments.contains(value) {
            comments.append(value)
        }

        form.equipmentType = names.joined(separator: "; ")
        form.inventory = ids.joined(separator: "; ")
        form.serial = serials.joined(separator: "; ")
        form.equipmentStatus = statuses.joined(separator: "; ")
        form.equipmentComment = comments.joined(separator: "; ")
        form.equipmentCount = String(options.count)
    }

    private func userLabel(_ user: User) -> String {
        let name = clean(user.name)
        if !name.isEmpty { return name }
        let email = clean(user.email)
        if !email.isEmpty { return email }
        return user.id
    }

    private func clean(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct EquipmentChangeSheet: View {
    let initialEquipmentType: String
    let initialSerial: String
    let initialBefore: String
    let onSave: (EquipmentChangeDraft) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var draft = EquipmentChangeDraft()
    @State private var isSaving = false
    @State private var errorText: String?

    private let changeTypes: [(String, String)] = [
        ("diagnostics", "Диагностика"),
        ("repair", "Ремонт"),
        ("replacement", "Замена"),
        ("installation", "Установка"),
        ("dismantling", "Демонтаж"),
        ("comment", "Комментарий")
    ]

    var body: some View {
        Form {
            if let errorText {
                Section("Ошибка") {
                    Text(errorText).foregroundStyle(.red)
                }
            }
            Section("Изменение") {
                Picker("Тип", selection: $draft.changeType) {
                    ForEach(changeTypes, id: \.0) { item in
                        Text(item.1).tag(item.0)
                    }
                }
                TextField("Поле", text: $draft.fieldName)
            }
            Section("Оборудование") {
                TextField("Тип оборудования", text: $draft.equipmentType)
                TextField("Серийный номер", text: $draft.serial)
            }
            Section("Значения") {
                TextField("Было", text: $draft.beforeValue)
                TextField("Стало", text: $draft.afterValue)
                TextField("Комментарий", text: $draft.comment, axis: .vertical)
                    .lineLimit(2...5)
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
            draft.equipmentType = initialEquipmentType
            draft.serial = initialSerial
            draft.beforeValue = initialBefore
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

private struct EquipmentHistorySheet: View {
    let taskId: String
    let client: SupabaseClient

    @State private var rows: [GenericRecord] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView("Загрузка истории...")
            } else if let errorText, rows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else if rows.isEmpty {
                ContentUnavailableView("История пуста", systemImage: "clock")
            } else {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(historyTypeLabel(first(row, keys: ["change_type"])))
                            .font(.headline)
                        Text(displayDateTime(first(row, keys: ["changed_at", "created_at"])))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(historyLine(for: row))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            rows = try await client.fetchEquipmentChanges(taskId: taskId)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func historyLine(for row: GenericRecord) -> String {
        let field = first(row, keys: ["field_name"])
        let before = first(row, keys: ["before_status"])
        let after = first(row, keys: ["after_status"])
        let comment = first(row, keys: ["comment"])
        let oldVal = first(row, keys: ["old_value"])
        let newVal = first(row, keys: ["new_value"])

        var parts: [String] = []
        if !field.isEmpty { parts.append("Поле: \(field)") }
        if !before.isEmpty { parts.append("Было: \(before)") }
        if !after.isEmpty { parts.append("Стало: \(after)") }
        if !comment.isEmpty { parts.append("Комментарий: \(comment)") }
        if !oldVal.isEmpty && before.isEmpty { parts.append("Старое: \(oldVal)") }
        if !newVal.isEmpty && after.isEmpty { parts.append("Новое: \(newVal)") }
        return parts.joined(separator: " | ")
    }

    private func historyTypeLabel(_ raw: String) -> String {
        switch raw.lowercased() {
        case "status": return "Статус изменён"
        case "equipment", "equipment_change": return "Оборудование изменено"
        case "diagnostics": return "Диагностика"
        case "repair": return "Ремонт"
        case "replacement": return "Замена"
        case "installation": return "Установка"
        case "dismantling": return "Демонтаж"
        case "comment": return "Комментарий"
        case "created", "create": return "Создано"
        default: return raw.isEmpty ? "Изменение" : raw
        }
    }

    private func first(_ row: GenericRecord, keys: [String]) -> String {
        for key in keys {
            let text = row.fields[key]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty, text.lowercased() != "null" {
                return text
            }
        }
        return ""
    }

    private func displayDateTime(_ raw: String) -> String {
        guard !raw.isEmpty else { return "" }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy HH:mm"
        return out.string(from: date)
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}


