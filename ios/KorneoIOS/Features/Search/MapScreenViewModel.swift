import Foundation
import CoreLocation

@MainActor
final class MapScreenViewModel: ObservableObject {
    struct MapPoint: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let title: String
        let subtitle: String
        let source: String
    }

    struct UserLocationPoint: Identifiable {
        let id: String
        let userId: String
        let name: String
        let coordinate: CLLocationCoordinate2D
        let timestampText: String
        let freshnessText: String
        let isCurrent: Bool
        let isRecent: Bool
    }

    @Published private(set) var isLoading = false
    @Published var errorText: String?
    @Published private(set) var userLocationPoints: [UserLocationPoint] = []
    @Published private(set) var navigationPoints: [MapPoint] = []
    @Published private(set) var addressHints: [String] = []
    @Published private(set) var usersMapStatusText: String = "Нет активных геопозиций."

    private var client: SupabaseClient?
    private var currentUser: User?

    private let currentLocationMaxAge: TimeInterval = 5 * 60
    private let recentLocationMaxAge: TimeInterval = 60 * 60

    func bind(client: SupabaseClient, currentUser: User?) {
        self.client = client
        self.currentUser = currentUser
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
            async let mileageRowsReq = client.fetchMileageRecords()
            async let jobsReq = client.fetchJobsForMap()
            async let installationsReq = client.fetchInstallationMapRows()
            async let sitesReq = client.fetchSitesRows()
            async let atssReq = client.fetchAtssRowsMerged()

            let users: [User]
            if hasManagerRights {
                users = (try? await client.fetchUsers()) ?? []
            } else {
                users = []
            }

            let mileageRows = try await mileageRowsReq
            let jobs = try await jobsReq
            let installations = try await installationsReq
            let sites = (try? await sitesReq) ?? []
            let atss = (try? await atssReq) ?? []

            navigationPoints = buildNavigationPoints(jobs: jobs, installations: installations)
            addressHints = buildAddressHints(jobs: jobs, installations: installations, sites: sites, atss: atss)
            userLocationPoints = buildUserLocationPoints(records: mileageRows, users: users)
            usersMapStatusText = buildUsersMapStatus(points: userLocationPoints)
        } catch {
            errorText = error.localizedDescription
        }
    }

    var hasManagerRights: Bool {
        currentUser?.role?.hasManagerRights == true
    }

    private func buildNavigationPoints(jobs: [GenericRecord], installations: [GenericRecord]) -> [MapPoint] {
        let jobPoints = jobs.compactMap { row -> MapPoint? in
            guard let coordinate = coordinate(from: row.fields) else { return nil }
            return MapPoint(
                id: "job_\(row.id)",
                coordinate: coordinate,
                title: nonEmptyField(from: row.fields, keys: ["title", "status", "name"], fallback: "Работа"),
                subtitle: nonEmptyField(from: row.fields, keys: ["address", "address_text", "created_at"], fallback: ""),
                source: "job"
            )
        }

        let installationPoints = installations.compactMap { row -> MapPoint? in
            guard let coordinate = coordinate(from: row.fields) else { return nil }
            return MapPoint(
                id: "installation_\(row.id)",
                coordinate: coordinate,
                title: nonEmptyField(from: row.fields, keys: ["title", "status", "name"], fallback: "Монтаж"),
                subtitle: nonEmptyField(from: row.fields, keys: ["address", "address_text", "created_at"], fallback: ""),
                source: "installation"
            )
        }

        return (jobPoints + installationPoints).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private func buildAddressHints(
        jobs: [GenericRecord],
        installations: [GenericRecord],
        sites: [GenericRecord],
        atss: [GenericRecord]
    ) -> [String] {
        var unique = Set<String>()
        unique.insert("Моё местоположение")

        for row in jobs { appendAddress(from: row.fields, to: &unique) }
        for row in installations { appendAddress(from: row.fields, to: &unique) }
        for row in sites { appendAddress(from: row.fields, to: &unique) }
        for row in atss { appendAddress(from: row.fields, to: &unique) }

        return unique
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != "null" }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func appendAddress(from fields: [String: JSONValue], to set: inout Set<String>) {
        let keys = [
            "address", "address_text", "location", "place", "adres",
            "id_ploshadki", "servisnyy_id", "adres_razmeshcheniya"
        ]
        for key in keys {
            let value = (fields[key]?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty && value.lowercased() != "null" {
                set.insert(value)
            }
        }
    }

    private func buildUserLocationPoints(records: [MileageRecord], users: [User]) -> [UserLocationPoint] {
        guard hasManagerRights else { return [] }

        let usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        var latestByUserId: [String: MileageRecord] = [:]

        for record in records {
            guard let userId = record.userId?.trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty else { continue }
            guard record.latitude != nil, record.longitude != nil else { continue }

            if let existing = latestByUserId[userId] {
                let existingDate = recordDate(existing) ?? .distantPast
                let newDate = recordDate(record) ?? .distantPast
                if newDate > existingDate {
                    latestByUserId[userId] = record
                }
            } else {
                latestByUserId[userId] = record
            }
        }

        let now = Date()
        let points = latestByUserId.compactMap { (userId, record) -> UserLocationPoint? in
            guard let latitude = record.latitude, let longitude = record.longitude else { return nil }
            let date = recordDate(record)
            let age = date.map { now.timeIntervalSince($0) } ?? -1

            return UserLocationPoint(
                id: "user_\(userId)",
                userId: userId,
                name: resolveUserName(userId: userId, usersById: usersById),
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                timestampText: formatDate(date),
                freshnessText: freshnessLabel(age),
                isCurrent: age >= 0 && age <= currentLocationMaxAge,
                isRecent: age >= 0 && age <= recentLocationMaxAge
            )
        }

        return points.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func buildUsersMapStatus(points: [UserLocationPoint]) -> String {
        guard !points.isEmpty else {
            return "Нет активных геопозиций. Проверьте разрешение геолокации у пользователей."
        }
        let current = points.filter { $0.isCurrent }.count
        let stale = points.count - current
        return "На карте: \(points.count) • актуально: \(current) • старое: \(stale)"
    }

    private func resolveUserName(userId: String, usersById: [String: User]) -> String {
        if let user = usersById[userId] {
            let name = (user.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
            let email = (user.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !email.isEmpty { return email }
        }
        return userId
    }

    private func recordDate(_ record: MileageRecord) -> Date? {
        parseISODate(record.date) ?? parseISODate(record.createdAt)
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

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "Время не указано" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }

    private func freshnessLabel(_ ageSeconds: TimeInterval) -> String {
        if ageSeconds < 0 {
            return "Время неизвестно"
        }
        if ageSeconds <= currentLocationMaxAge {
            return "Текущее местоположение"
        }
        let minutes = max(1, Int(ageSeconds / 60))
        if minutes < 60 {
            return "Старое местоположение: \(minutes) мин назад"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "Старое местоположение: \(hours) ч назад"
        }
        return "Старое местоположение: \(hours / 24) дн назад"
    }

    private func coordinate(from fields: [String: JSONValue]) -> CLLocationCoordinate2D? {
        let lat = doubleField(from: fields, keys: ["latitude", "lat", "start_lat", "from_lat", "to_lat"])
        let lon = doubleField(from: fields, keys: ["longitude", "lng", "lon", "start_lng", "from_lng", "to_lng"])
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func doubleField(from fields: [String: JSONValue], keys: [String]) -> Double? {
        for key in keys {
            guard let value = fields[key] else { continue }
            switch value {
            case let .number(number):
                return number
            case let .string(string):
                let clean = string
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")
                if let number = Double(clean) {
                    return number
                }
            default:
                continue
            }
        }
        return nil
    }

    private func nonEmptyField(from fields: [String: JSONValue], keys: [String], fallback: String) -> String {
        for key in keys {
            let value = (fields[key]?.textValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty && value.lowercased() != "null" {
                return value
            }
        }
        return fallback
    }
}
