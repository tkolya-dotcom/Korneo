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

    private let prefs = UserDefaults.standard
    private let formulaKey = "korneo.mileage.formula.rate"
    private let manualRecordsKey = "korneo.mileage.manual.records"
    private let distanceOverridesKey = "korneo.mileage.distance.overrides"
    private let routeOverridesKey = "korneo.mileage.route.overrides"

    private let hiddenMileageBuffer = 1.07
    private let fallbackPurpose = "Работа"

    func bind(client: SupabaseClient, currentUser: User?) {
        self.client = client
        self.currentUser = currentUser
        loadLocalStateIfNeeded()
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
            async let mileageReq = client.fetchMileageRecords()

            var users: [User] = []
            if isManager {
                users = (try? await client.fetchUsers()) ?? []
            }

            remoteRecords = try await mileageReq
            usersById = Dictionary(
                uniqueKeysWithValues: users.map { user in
                    let display = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let fallback = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return (user.id, display.isEmpty ? (fallback.isEmpty ? user.id : fallback) : display)
                }
            )

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
        var set: Set<String> = ["г.Санкт-Петербург, ул. Воронежская, д. 33"]
        for record in records {
            let route = cleanRoute(record.route)
            if route.isEmpty { continue }
            let parts = route.components(separatedBy: "->")
            for raw in parts {
                let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !item.isEmpty {
                    set.insert(item)
                }
            }
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
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        let clean = trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? fallback : clean
    }
}
