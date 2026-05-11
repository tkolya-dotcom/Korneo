import Foundation

struct PurchaseRequestItem: Codable, Identifiable {
    let id: String
    let purchaseRequestId: String?
    let requestId: String?
    let materialName: String?
    let materialId: String?
    let material: PurchaseRequestItemMaterial?
    let quantity: Double?
    let quantityRequested: Double?
    let quantityApproved: Double?
    let quantityIssued: Double?
    let unit: String?
    let price: Double?
    let totalPrice: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case purchaseRequestId = "purchase_request_id"
        case requestId = "request_id"
        case materialName = "material_name"
        case materialId = "material_id"
        case material
        case quantity
        case quantityRequested = "quantity_requested"
        case quantityApproved = "quantity_approved"
        case quantityIssued = "quantity_issued"
        case unit
        case price
        case totalPrice = "total_price"
    }

    var resolvedMaterialName: String {
        if let materialName, !materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return materialName
        }
        if let materialName = material?.name, !materialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return materialName
        }
        return materialId ?? "material"
    }

    var resolvedUnit: String? {
        if let unit, !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unit
        }
        return material?.unit
    }

    var resolvedQuantity: Double {
        quantity ?? quantityRequested ?? quantityApproved ?? quantityIssued ?? 0
    }
}

struct PurchaseRequestItemMaterial: Codable {
    let name: String?
    let unit: String?
}
