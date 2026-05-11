import Foundation

struct PurchaseRequestDraftMaterialLine: Identifiable, Hashable {
    let id = UUID()
    let materialId: String
    let materialName: String
    let unit: String
    let quantity: Double
}
