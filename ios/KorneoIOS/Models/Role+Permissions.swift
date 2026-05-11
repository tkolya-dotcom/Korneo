import Foundation

extension Role {
    var hasManagerRights: Bool {
        self == .manager || self == .deputyHead || self == .admin
    }

    var hasEngineerRights: Bool {
        self == .engineer || hasManagerRights
    }

    var hasCoordinatorRights: Bool {
        self == .support || hasManagerRights
    }

    var hasMapAccess: Bool {
        self == .engineer || hasManagerRights
    }
}
