import Foundation

struct MileageRecord: Codable, Identifiable {
    let id: String
    let userId: String?
    let date: String?
    let startOdometer: Double?
    let endOdometer: Double?
    let distance: Double?
    let route: String?
    let purpose: String?
    let latitude: Double?
    let longitude: Double?
    let accuracy: Double?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case recordedAt = "recorded_at"
        case startOdometer = "start_odometer"
        case endOdometer = "end_odometer"
        case distance
        case distanceKm = "distance_km"
        case route
        case purpose
        case latitude
        case longitude
        case accuracy
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? container.decodeIfPresent(String.self, forKey: .recordedAt)
        startOdometer = try container.decodeIfPresent(Double.self, forKey: .startOdometer)
        endOdometer = try container.decodeIfPresent(Double.self, forKey: .endOdometer)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? container.decodeIfPresent(Double.self, forKey: .distanceKm)
        route = try container.decodeIfPresent(String.self, forKey: .route)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        accuracy = try container.decodeIfPresent(Double.self, forKey: .accuracy)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }

    init(
        id: String,
        userId: String?,
        date: String?,
        startOdometer: Double?,
        endOdometer: Double?,
        distance: Double?,
        route: String?,
        purpose: String?,
        latitude: Double?,
        longitude: Double?,
        accuracy: Double?,
        createdAt: String?
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.startOdometer = startOdometer
        self.endOdometer = endOdometer
        self.distance = distance
        self.route = route
        self.purpose = purpose
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.createdAt = createdAt
    }
}
