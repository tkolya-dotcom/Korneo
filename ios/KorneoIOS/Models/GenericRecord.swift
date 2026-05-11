import Foundation

struct GenericRecord: Codable, Identifiable {
    let id: String
    let fields: [String: JSONValue]

    init(id: String, fields: [String: JSONValue]) {
        self.id = id
        self.fields = fields
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [String: JSONValue] = [:]
        for key in container.allKeys {
            values[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
        }
        let rawId = values["id"]?.textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = (rawId?.isEmpty == false) ? rawId! : UUID().uuidString
        self.fields = values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in fields {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}
