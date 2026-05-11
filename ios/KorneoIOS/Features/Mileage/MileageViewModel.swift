import Foundation
import Combine
import CoreLocation

@MainActor
final class MileageViewModel: ObservableObject {
    enum FilterMode: String, CaseIterable, Identifiable {
        case day
        case month
        case year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .day: return "День"
            case .month: return "Месяц"
            case .year: return "Год"
            }
        }
    }

    struct MileageStats {
        let totalDistanceKm: Double
        let compensation: Double
        let totalPoints: Int
        let todayDistanceKm: Double
        let averageAccuracy: Double?
    }

    struct MapPoint: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let title: String
        let subtitle: String
    }

    private struct ManualStoredRecord: Codable {
        let id: String
        let userId: String?
        let date: String
        let distance: Double
        let route: String
        let purpose: String?
    }

    private struct JobPoint {
        let id: String
        let userId: String
        let date: Date
        let address: String
        let latitude: Double?
        let longitude: Double?
        let isBasePoint: Bool
    }

    @Published private(set) var records: [MileageRecord] = []
    @Published private(set) var usersById: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published var errorText: String?
    @Published var formulaRatePerKm: Double = 17.0

    private var client: SupabaseClient?
    private var currentUser: User?

    private var remoteRecords: [MileageRecord] = []
    private var manualRecords: [MileageRecord] = []
    private var distanceOverrides: [String: Double] = [:]
    private var routeOverrides: [String: String] = [:]

    private var jobsSourceRows: [GenericRecord] = []
    private var addressSourceRows: [GenericRecord] = []

    private let prefs = UserDefaults.standard
    private let formulaKey = "korneo.mileage.formula.rate"
    private let manualRecordsKey = "korneo.mileage.manual.records"
    private let distanceOverridesKey = "korneo.mileage.distance.overrides"
    private let routeOverridesKey = "korneo.mileage.route.overrides"

    private let hiddenMileageBuffer = 1.07
    private let fallbackPurpose = "Работа"
    private let dailyBaseAddress = "г.Санкт-Петербург, ул. Воронежская, д. 33"

    func bind(client: SupabaseClient, currentUser: User?) {
        self.client = client
        self.currentUser = currentUser
        loadLocalStateIfNeeded()
    }

    func load() async {
        guard let client else {
            errorText = "Клиент не настроен"
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            async let mileageReq = client.fetchMileageRecords()
            async let jobsReq = client.fetchJobsForMap()
            async let sitesReq = client.fetchSitesRows()
            async let atssReq = client.fetchAtssRowsMerged()

            let users: [User]
            if isManager {
                users = (try? await client.fetchUsers()) ?? []
            } else {
                users = []
            }

            let mileageRows = (try? await mileageReq) ?? []
            jobsSourceRows = (try? await jobsReq) ?? []
            let sitesRows = (try? await sitesReq) ?? []
            let atssRows = (try? await atssReq) ?? []
            addressSourceRows = sitesRows + atssRows

            usersById = makeUsersMap(from: users)
            var rebuilt = rebuildFromJobs(jobs: jobsSourceRows, addressRows: addressSourceRows)
            if rebuilt.isEmpty {
                let fallbackRows = await loadMileageFallbackJobsFromChats(client: client)
                if !fallbackRows.isEmpty {
                    jobsSourceRows.append(contentsOf: fallbackRows)
                    rebuilt = rebuildFromJobs(jobs: jobsSourceRows, addressRows: addressSourceRows)
                }
            }
            remoteRecords = rebuilt.isEmpty ? mileageRows : rebuilt

            applyLocalOverlays()
        } catch {
            errorText = error.localizedDescription
        }
    }

    var isManager: Bool {
        currentUser?.role?.hasManagerRights == true
    }

    func updateFormulaRate(_ value: Double) {
        guard value > 0 else { return }
        formulaRatePerKm = value
        prefs.set(value, forKey: formulaKey)
    }

    func filteredRecords(
        mode: FilterMode,
        selectedDate: Date,
        selectedUserId: String?
    ) -> [MileageRecord] {
        let userScoped = scopedByUser(records, selectedUserId: selectedUserId)
        return userScoped.filter { record in
            guard let date = dateForRecord(record) else { return false }
            return matchesPeriod(date: date, mode: mode, selectedDate: selectedDate)
        }
    }

    func recordsForToday(selectedUserId: String?) -> [MileageRecord] {
        let userScoped = scopedByUser(records, selectedUserId: selectedUserId)
        let cal = Calendar.current
        let today = Date()
        return userScoped.filter { record in
            guard let date = dateForRecord(record) else { return false }
            return cal.isDate(date, inSameDayAs: today)
        }
    }

    func stats(for filtered: [MileageRecord], todayRecords: [MileageRecord]) -> MileageStats {
        let totalDistance = filtered.reduce(0.0) { $0 + max(0, $1.distance ?? 0) }
        let compensation = totalDistance * formulaRatePerKm
        let todayDistance = todayRecords.reduce(0.0) { $0 + max(0, $1.distance ?? 0) }
        let accuracies = filtered.compactMap(\.accuracy).filter { $0 > 0 }
        let avgAccuracy = accuracies.isEmpty ? nil : accuracies.reduce(0, +) / Double(accuracies.count)
        return MileageStats(
            totalDistanceKm: totalDistance,
            compensation: compensation,
            totalPoints: filtered.count,
            todayDistanceKm: todayDistance,
            averageAccuracy: avgAccuracy
        )
    }

    func mapPoints(from filtered: [MileageRecord]) -> [MapPoint] {
        filtered.compactMap { record in
            guard let lat = record.latitude, let lon = record.longitude else { return nil }
            let title = cleanPurpose(record.purpose).ifEmpty("Точка")
            let subtitle = "\(formatDate(record.date ?? record.createdAt)) - \(formatDistance(record.distance))"
            return MapPoint(
                id: record.id,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                title: title,
                subtitle: subtitle
            )
        }
    }

    func userOptions() -> [(id: String?, name: String)] {
        guard isManager else { return [] }
        var list: [(id: String?, name: String)] = [(nil, "Все пользователи")]
        let rows = usersById
            .map { (id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        list.append(contentsOf: rows.map { (id: Optional($0.id), name: $0.name) })
        return list
    }

    func userName(for userId: String?) -> String {
        let clean = (userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty || clean == "unassigned" {
            return "Не назначен"
        }
        if let fromMap = usersById[clean], !fromMap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromMap
        }
        if clean == currentUser?.id {
            let ownName = (currentUser?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownName.isEmpty { return ownName }
            let ownEmail = (currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownEmail.isEmpty { return ownEmail }
        }
        return clean
    }

    func knownAddresses(limit: Int = 80) -> [String] {
        var set: Set<String> = [dailyBaseAddress]

        for record in records {
            let route = cleanRoute(record.route)
            if route.isEmpty { continue }
            for part in route.components(separatedBy: "->") {
                let item = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty { set.insert(item) }
            }
        }

        for row in jobsSourceRows {
            let address = extractAddress(from: row.fields)
            if !address.isEmpty { set.insert(address) }
        }

        for row in addressSourceRows {
            let address = extractAddress(from: row.fields)
            if !address.isEmpty { set.insert(address) }
        }

        return Array(set)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { $0 }
    }

    func addManualRecord(userId: String?, from: String, to: String, kilometers: Double, date: Date = Date()) {
        let fromClean = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let toClean = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fromClean.isEmpty, !toClean.isEmpty, kilometers > 0 else { return }

        let selectedUserId: String
        if let clean = userId?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty {
            selectedUserId = clean
        } else {
            selectedUserId = currentUser?.id ?? "unassigned"
        }

        let author = userName(for: selectedUserId)
        let iso = ISO8601DateFormatter().string(from: date)
        let record = MileageRecord(
            id: "manual|\(UUID().uuidString.lowercased())",
            userId: selectedUserId,
            date: iso,
            startOdometer: nil,
            endOdometer: nil,
            distance: applyMileageAdjustment(kilometers),
            route: "\(fromClean) -> \(toClean)",
            purpose: "Пользователь: \(author)",
            latitude: nil,
            longitude: nil,
            accuracy: nil,
            createdAt: iso
        )
        manualRecords.append(record)
        persistLocalState()
        applyLocalOverlays()
    }

    func saveOverrides(recordId: String, distance: Double?, route: String?) {
        let cleanId = recordId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }

        if let distance, distance > 0 {
            distanceOverrides[cleanId] = distance
        } else {
            distanceOverrides.removeValue(forKey: cleanId)
        }

        let cleanRoute = route?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanRoute.isEmpty {
            routeOverrides[cleanId] = cleanRoute
        } else {
            routeOverrides.removeValue(forKey: cleanId)
        }

        persistLocalState()
        applyLocalOverlays()
    }

    func removeManualRecord(id: String) {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanId.hasPrefix("manual|") else { return }
        manualRecords.removeAll { $0.id == cleanId }
        distanceOverrides.removeValue(forKey: cleanId)
        routeOverrides.removeValue(forKey: cleanId)
        persistLocalState()
        applyLocalOverlays()
    }

    func isManualRecord(_ id: String) -> Bool {
        id.hasPrefix("manual|")
    }

    func dateForRecord(_ record: MileageRecord) -> Date? {
        parseISODate(record.date) ?? parseISODate(record.createdAt)
    }

    func formatDate(_ raw: String?) -> String {
        if let date = parseISODate(raw) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            return formatter.string(from: date)
        }
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Без даты" : clean
    }

    func formatDistance(_ value: Double?) -> String {
        let distance = max(0, value ?? 0)
        return String(format: "%.2f км", distance)
    }

    func cleanPurpose(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "" }
        if isGarbledText(value) { return fallbackPurpose }
        return value
    }

    func cleanRoute(_ raw: String?) -> String {
        let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || isGarbledText(value) {
            return ""
        }
        return value
    }

    private func scopedByUser(_ source: [MileageRecord], selectedUserId: String?) -> [MileageRecord] {
        if isManager {
            let cleanSelected = (selectedUserId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanSelected.isEmpty {
                return source
            }
            return source.filter { ($0.userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == cleanSelected }
        }
        let myId = (currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !myId.isEmpty else { return [] }
        return source.filter { ($0.userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == myId }
    }

    private func matchesPeriod(date: Date, mode: FilterMode, selectedDate: Date) -> Bool {
        let cal = Calendar.current
        switch mode {
        case .day:
            return cal.isDate(date, inSameDayAs: selectedDate)
        case .month:
            return cal.component(.year, from: date) == cal.component(.year, from: selectedDate)
                && cal.component(.month, from: date) == cal.component(.month, from: selectedDate)
        case .year:
            return cal.component(.year, from: date) == cal.component(.year, from: selectedDate)
        }
    }

    private func parseISODate(_ raw: String?) -> Date? {
        let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFractional.date(from: clean) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: clean) {
            return date
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = parser.date(from: clean) {
            return date
        }

        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: clean)
    }

    private func isGarbledText(_ value: String) -> Bool {
        value.contains("пїЅ")
            || value.contains("????")
            || value.contains("Гђ")
            || value.contains("Р В ")
            || value.count > 220
    }

    private func applyMileageAdjustment(_ km: Double) -> Double {
        max(0, km) * hiddenMileageBuffer
    }

    private func applyLocalOverlays() {
        let remote = remoteRecords.map { record in
            patchedRecord(for: record)
        }
        let manual = manualRecords.map { record in
            patchedRecord(for: record)
        }

        records = (remote + manual).sorted { lhs, rhs in
            (dateForRecord(lhs) ?? .distantPast) > (dateForRecord(rhs) ?? .distantPast)
        }
    }

    private func patchedRecord(for record: MileageRecord) -> MileageRecord {
        let cleanId = record.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let overriddenDistance = distanceOverrides[cleanId] ?? record.distance
        let overriddenRoute = routeOverrides[cleanId] ?? record.route

        return MileageRecord(
            id: record.id,
            userId: record.userId,
            date: record.date,
            startOdometer: record.startOdometer,
            endOdometer: record.endOdometer,
            distance: overriddenDistance,
            route: overriddenRoute,
            purpose: record.purpose,
            latitude: record.latitude,
            longitude: record.longitude,
            accuracy: record.accuracy,
            createdAt: record.createdAt
        )
    }

    private func loadLocalStateIfNeeded() {
        if let stored = prefs.object(forKey: formulaKey) as? Double, stored > 0 {
            formulaRatePerKm = stored
        }

        if let data = prefs.data(forKey: manualRecordsKey) {
            let decoded = (try? JSONDecoder().decode([ManualStoredRecord].self, from: data)) ?? []
            manualRecords = decoded.map { item in
                MileageRecord(
                    id: item.id,
                    userId: item.userId,
                    date: item.date,
                    startOdometer: nil,
                    endOdometer: nil,
                    distance: item.distance,
                    route: item.route,
                    purpose: item.purpose,
                    latitude: nil,
                    longitude: nil,
                    accuracy: nil,
                    createdAt: item.date
                )
            }
        }

        if let rawDistance = prefs.dictionary(forKey: distanceOverridesKey) {
            distanceOverrides = rawDistance.reduce(into: [:]) { partial, pair in
                if let numeric = pair.value as? NSNumber {
                    partial[pair.key] = numeric.doubleValue
                } else if let string = pair.value as? String, let parsed = Double(string) {
                    partial[pair.key] = parsed
                }
            }
        } else {
            distanceOverrides = [:]
        }

        if let rawRoute = prefs.dictionary(forKey: routeOverridesKey) {
            routeOverrides = rawRoute.reduce(into: [:]) { partial, pair in
                if let value = pair.value as? String {
                    partial[pair.key] = value
                }
            }
        } else {
            routeOverrides = [:]
        }

        applyLocalOverlays()
    }

    private func persistLocalState() {
        let stored = manualRecords.map { record in
            ManualStoredRecord(
                id: record.id,
                userId: record.userId,
                date: record.date ?? record.createdAt ?? ISO8601DateFormatter().string(from: Date()),
                distance: record.distance ?? 0,
                route: record.route ?? "",
                purpose: record.purpose
            )
        }
        if let encoded = try? JSONEncoder().encode(stored) {
            prefs.set(encoded, forKey: manualRecordsKey)
        }
        prefs.set(distanceOverrides, forKey: distanceOverridesKey)
        prefs.set(routeOverrides, forKey: routeOverridesKey)
    }

    private func makeUsersMap(from users: [User]) -> [String: String] {
        var map = Dictionary(
            uniqueKeysWithValues: users.map { user in
                let display = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return (user.id, display.isEmpty ? (fallback.isEmpty ? user.id : fallback) : display)
            }
        )

        if let currentUser {
            let name = (currentUser.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = (currentUser.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let display = name.isEmpty ? (fallback.isEmpty ? currentUser.id : fallback) : name
            map[currentUser.id] = display
        }

        return map
    }

    private func loadMileageFallbackJobsFromChats(client: SupabaseClient) async -> [GenericRecord] {
        let userId = (currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { return [] }

        guard let chats = try? await client.fetchMyChats(userId: userId), !chats.isEmpty else {
            return []
        }

        let groupChats = chats.filter { ($0.type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "group" }
        if groupChats.isEmpty { return [] }

        var rows: [GenericRecord] = []
        var dedupe = Set<String>()

        for chat in groupChats {
            guard let messages = try? await client.fetchMessages(chatId: chat.id, limit: 300), !messages.isEmpty else {
                continue
            }
            for message in messages {
                guard let row = mileageRowFromMessage(chatId: chat.id, message: message) else { continue }
                let key = mileageRowKey(row.fields)
                if dedupe.insert(key).inserted {
                    rows.append(row)
                }
            }
        }

        return rows
    }

    private func mileageRowFromMessage(chatId: String, message: Message) -> GenericRecord? {
        if message.isDeleted == true { return nil }
        let content = message.contentObject
        let isWorkCard = value(from: content, key: "type").lowercased() == "work_card"
        if isWorkCard && !isMileageCompletedStatus(value(from: content, key: "status")) {
            return nil
        }

        var address = value(from: content, key: "address")
        if address.isEmpty {
            address = extractAddressFromMileageText(message.contentText)
        }
        address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if address.isEmpty { return nil }

        let createdAt = firstNonEmpty([
            value(from: content, key: "created_at"),
            message.createdAt
        ]) ?? ""
        let startedAt = firstNonEmpty([
            value(from: content, key: "planned_at"),
            value(from: content, key: "started_at"),
            message.createdAt
        ]) ?? ""

        let id = message.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }

        var fields: [String: JSONValue] = [:]
        fields["id"] = .string(id)
        fields["address"] = .string(address)
        fields["created_at"] = .string(createdAt)
        fields["started_at"] = .string(startedAt)
        fields["finished_at"] = .string(value(from: content, key: "finished_at"))
        fields["user_id"] = .string((message.userId ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        fields["engineer_id"] = .string(firstNonEmpty([
            value(from: content, key: "assignee_id"),
            value(from: content, key: "executor_id"),
            value(from: content, key: "engineer_id")
        ]) ?? "")
        fields["created_by"] = .string(firstNonEmpty([
            value(from: content, key: "creator_id"),
            value(from: content, key: "created_by"),
            message.userId
        ]) ?? "")
        fields["status"] = .string(firstNonEmpty([value(from: content, key: "status"), "from_chat"]) ?? "from_chat")
        fields["title"] = .string(value(from: content, key: "title"))
        fields["work_type"] = .string(value(from: content, key: "title"))
        fields["hours"] = .string(firstNonEmpty([
            value(from: content, key: "hours"),
            value(from: content, key: "planned_duration_hours")
        ]) ?? "")
        fields["planned_deadline"] = .string(firstNonEmpty([
            value(from: content, key: "planned_deadline"),
            value(from: content, key: "planned_deadline_iso")
        ]) ?? "")
        fields["planned_at"] = .string(value(from: content, key: "planned_at"))
        fields["creator_name"] = .string(value(from: content, key: "creator_name"))
        fields["naimenovanie_sk"] = .string(value(from: content, key: "naimenovanie_sk"))
        fields["job_id"] = .string(value(from: content, key: "job_id"))
        fields["servisnyy_id"] = .string(value(from: content, key: "emts"))
        fields["sk_count"] = .string(value(from: content, key: "sk_count"))
        fields["chat_id"] = .string(chatId.trimmingCharacters(in: .whitespacesAndNewlines))

        return GenericRecord(id: id, fields: fields)
    }

    private func mileageRowKey(_ fields: [String: JSONValue]) -> String {
        let jobId = text(fields["job_id"])
        if !jobId.isEmpty { return "job|\(jobId)" }

        let id = text(fields["id"])
        if !id.isEmpty { return "id|\(id)" }

        let chatId = text(fields["chat_id"])
        let createdAt = text(fields["created_at"])
        let address = text(fields["address"])
        return "chat|\(chatId)|\(createdAt)|\(address)"
    }

    private func extractAddressFromMileageText(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        let marker = "Адрес:"
        guard let range = normalized.range(of: marker) else { return "" }
        var value = String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if let stop = value.range(of: " Часы:") {
            value = String(value[..<stop.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    private func value(from object: [String: JSONValue]?, key: String) -> String {
        guard let object else { return "" }
        return text(object[key])
    }

    private func text(_ value: JSONValue?) -> String {
        (value?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rebuildFromJobs(jobs: [GenericRecord], addressRows: [GenericRecord]) -> [MileageRecord] {
        if jobs.isEmpty { return [] }

        let addressCoords = buildAddressCoordinateCache(jobs: jobs, addressRows: addressRows)
        var grouped: [String: [JobPoint]] = [:]

        for row in jobs {
            let fields = row.fields
            if isDeletedRow(fields: fields) { continue }

            let status = firstNonEmpty([
                fields["status"]?.textValue,
                fields["job_status"]?.textValue
            ]) ?? ""
            if !status.isEmpty && !isMileageCompletedStatus(status) {
                continue
            }

            guard let date = parseJobDate(fields: fields) else { continue }
            let userId = firstNonEmpty([
                fields["executor_id"]?.textValue,
                fields["engineer_id"]?.textValue,
                fields["assignee_id"]?.textValue,
                fields["created_by"]?.textValue,
                fields["user_id"]?.textValue
            ]) ?? "unassigned"

            let address = extractAddress(from: fields).ifEmpty("Без адреса")
            let coord = coordinate(from: fields) ?? coordinateForAddress(address, cache: addressCoords)

            let point = JobPoint(
                id: row.id,
                userId: userId,
                date: date,
                address: address,
                latitude: coord?.latitude,
                longitude: coord?.longitude,
                isBasePoint: false
            )

            let dayKey = dayKeyFor(date)
            grouped["\(userId)|\(dayKey)", default: []].append(point)
        }

        var built: [MileageRecord] = []
        for (key, points) in grouped {
            guard !points.isEmpty else { continue }
            let userId = String(key.split(separator: "|").first ?? Substring("unassigned"))
            let sorted = points.sorted { $0.date < $1.date }
            let withEndpoints = withDailyBaseEndpoints(points: sorted, userId: userId)

            if withEndpoints.count < 2 { continue }
            for idx in 1..<withEndpoints.count {
                let prev = withEndpoints[idx - 1]
                let cur = withEndpoints[idx]
                let distanceKm = calculateDistanceKm(from: prev, to: cur, addressCoords: addressCoords)
                let adjusted = applyMileageAdjustment(distanceKm)
                let route = "\(prev.address) -> \(cur.address)"
                let segmentId = buildSegmentKey(userId: userId, date: cur.date, index: idx, from: prev.address, to: cur.address)

                let record = MileageRecord(
                    id: segmentId,
                    userId: userId,
                    date: isoString(cur.date),
                    startOdometer: nil,
                    endOdometer: nil,
                    distance: adjusted,
                    route: route,
                    purpose: "Пользователь: \(userName(for: userId))",
                    latitude: cur.latitude,
                    longitude: cur.longitude,
                    accuracy: nil,
                    createdAt: isoString(cur.date)
                )
                built.append(record)
            }
        }

        return built
    }

    private func withDailyBaseEndpoints(points: [JobPoint], userId: String) -> [JobPoint] {
        guard let first = points.first else { return [] }
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 0, minute: 1, second: 0, of: first.date) ?? first.date
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: first.date) ?? first.date

        let startPoint = JobPoint(
            id: "base_start|\(userId)|\(dayKeyFor(first.date))",
            userId: userId,
            date: start,
            address: dailyBaseAddress,
            latitude: nil,
            longitude: nil,
            isBasePoint: true
        )
        let endPoint = JobPoint(
            id: "base_end|\(userId)|\(dayKeyFor(first.date))",
            userId: userId,
            date: end,
            address: dailyBaseAddress,
            latitude: nil,
            longitude: nil,
            isBasePoint: true
        )

        return [startPoint] + points + [endPoint]
    }

    private func buildAddressCoordinateCache(jobs: [GenericRecord], addressRows: [GenericRecord]) -> [String: CLLocationCoordinate2D] {
        var cache: [String: CLLocationCoordinate2D] = [:]

        for row in jobs {
            let address = normalizedAddress(extractAddress(from: row.fields))
            guard !address.isEmpty else { continue }
            if let coordinate = coordinate(from: row.fields) {
                cache[address] = cache[address] ?? coordinate
            }
        }

        for row in addressRows {
            let address = normalizedAddress(extractAddress(from: row.fields))
            guard !address.isEmpty else { continue }
            if let coordinate = coordinate(from: row.fields) {
                cache[address] = cache[address] ?? coordinate
            }
        }

        return cache
    }

    private func extractAddress(from fields: [String: JSONValue]) -> String {
        firstNonEmpty([
            fields["address"]?.textValue,
            fields["address_text"]?.textValue,
            fields["adres"]?.textValue,
            fields["location"]?.textValue,
            fields["place"]?.textValue,
            fields["id_ploshadki"]?.textValue,
            fields["servisnyy_id"]?.textValue
        ]) ?? ""
    }

    private func parseJobDate(fields: [String: JSONValue]) -> Date? {
        parseISODate(firstNonEmpty([
            fields["started_at"]?.textValue,
            fields["completed_at"]?.textValue,
            fields["updated_at"]?.textValue,
            fields["created_at"]?.textValue,
            fields["date"]?.textValue
        ]))
    }

    private func isDeletedRow(fields: [String: JSONValue]) -> Bool {
        if let deleted = fields["is_deleted"] {
            switch deleted {
            case .bool(true):
                return true
            case .number(let number):
                if number != 0 { return true }
            case .string(let value):
                let clean = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if clean == "true" || clean == "1" { return true }
            default:
                break
            }
        }

        let deletedAt = (fields["deleted_at"]?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !deletedAt.isEmpty && deletedAt.lowercased() != "null"
    }

    private func isMileageCompletedStatus(_ status: String) -> Bool {
        let value = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value == "done" || value == "completed" || value == "finished"
    }

    private func coordinate(from fields: [String: JSONValue]) -> CLLocationCoordinate2D? {
        let lat = firstNumber(from: [
            fields["lat"], fields["latitude"], fields["shirina"], fields["gps_lat"], fields["geo_lat"]
        ])
        let lon = firstNumber(from: [
            fields["lng"], fields["lon"], fields["longitude"], fields["dolgota"], fields["gps_lng"], fields["gps_lon"], fields["geo_lng"], fields["geo_lon"]
        ])
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func coordinateForAddress(_ address: String, cache: [String: CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        let key = normalizedAddress(address)
        if key.isEmpty { return nil }
        return cache[key]
    }

    private func calculateDistanceKm(from prev: JobPoint, to cur: JobPoint, addressCoords: [String: CLLocationCoordinate2D]) -> Double {
        let fromCoordinate = coordinateFromPoint(prev, cache: addressCoords)
        let toCoordinate = coordinateFromPoint(cur, cache: addressCoords)

        guard let fromCoordinate, let toCoordinate else { return 0 }
        let a = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        let b = CLLocation(latitude: toCoordinate.latitude, longitude: toCoordinate.longitude)
        return max(0, a.distance(from: b) / 1000.0)
    }

    private func coordinateFromPoint(_ point: JobPoint, cache: [String: CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        if let lat = point.latitude, let lon = point.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return coordinateForAddress(point.address, cache: cache)
    }

    private func firstNumber(from values: [JSONValue?]) -> Double? {
        for value in values {
            guard let value else { continue }
            switch value {
            case .number(let number):
                return number
            case .string(let text):
                let normalized = text.replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = Double(normalized) {
                    return parsed
                }
            default:
                continue
            }
        }
        return nil
    }

    private func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            let clean = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return nil
    }

    private func normalizedAddress(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func dayKeyFor(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func buildSegmentKey(userId: String, date: Date, index: Int, from: String, to: String) -> String {
        let safeFrom = normalizedAddress(from)
            .replacingOccurrences(of: "|", with: "_")
            .prefix(32)
        let safeTo = normalizedAddress(to)
            .replacingOccurrences(of: "|", with: "_")
            .prefix(32)
        return "seg|\(userId)|\(dayKeyFor(date))|\(index)|\(safeFrom)|\(safeTo)"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? fallback : clean
    }
}
