import Foundation

struct DaichiProduct: Identifiable, Hashable {
    let id: String
    let article: String
    let name: String
    let brand: String
    let series: String
    let type: String
    let direction: String
    let group: String
    let price: String
    let currency: String
    let stock: Int
    let inTransit: Int
    let warehouse: String
    let power: String
}

struct DaichiProductParam: Hashable, Identifiable {
    let name: String
    let value: String

    var id: String { "\(name)|\(value)" }
}

struct DaichiProductDetails: Hashable {
    let params: [DaichiProductParam]
    let documentURLs: [String]
}
