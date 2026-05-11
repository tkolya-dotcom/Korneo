import Foundation

enum Role: String, Codable {
    case manager
    case worker
    case engineer
    case support
    case deputyHead = "deputy_head"
    case admin
}
