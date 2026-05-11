import Foundation

struct Material: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let unit: String?
    let defaultUnit: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case unit
        case defaultUnit = "default_unit"
    }

    var resolvedName: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? id : trimmed
    }

    var resolvedUnit: String {
        let normalizedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedUnit.isEmpty { return normalizedUnit }
        return defaultUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
