import Foundation
import CoreXLSX

enum AtssXlsxImportParser {
    private static let preferredSheetNames = [
        "1 квартал 2026",
        "1 квартал 2026 ",
        "1 kv 2026",
        "sheet1"
    ]

    static func parse(fileURL: URL) throws -> [[String: JSONValue]] {
        guard let file = XLSXFile(filepath: fileURL.path) else {
            throw APIError.requestFailed(status: 400, message: "Не удалось открыть Excel файл")
        }

        let sharedStrings = try? file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()
        guard let workbook = workbooks.first else {
            throw APIError.requestFailed(status: 400, message: "В файле нет workbook")
        }
        let sheets = try file.parseWorksheetPathsAndNames(workbook: workbook)
        guard !sheets.isEmpty else {
            throw APIError.requestFailed(status: 400, message: "В файле нет листов")
        }

        let chosenPath = chooseSheetPath(from: sheets)
        let worksheet = try file.parseWorksheet(at: chosenPath)
        let rows = worksheet.data?.rows ?? []
        let parsedRows = rows.map { row in
            parseRow(row, sharedStrings: sharedStrings)
        }
        return toRecords(parsedRows)
    }

    private static func chooseSheetPath(from sheets: [(String, WorksheetPath)]) -> WorksheetPath {
        let normalized = sheets.map { (name: normalizeSheetName($0.0), path: $0.1) }
        for wanted in preferredSheetNames {
            if let found = normalized.first(where: { $0.name == normalizeSheetName(wanted) }) {
                return found.path
            }
        }
        if let quarter = normalized.first(where: { $0.name.contains("2026") && $0.name.contains("квартал") }) {
            return quarter.path
        }
        return normalized[0].path
    }

    private static func chooseSheetPath(from sheets: [String: WorksheetPath]) -> WorksheetPath {
        chooseSheetPath(from: sheets.map { ($0.key, $0.value) })
    }

    private static func chooseSheetPath(from sheets: [WorksheetPath: String]) -> WorksheetPath {
        chooseSheetPath(from: sheets.map { ($0.value, $0.key) })
    }

    private static func chooseSheetPath(from sheets: [(String?, WorksheetPath)]) -> WorksheetPath {
        chooseSheetPath(from: sheets.map { (($0.0 ?? ""), $0.1) })
    }

    private static func parseRow(_ row: Row, sharedStrings: SharedStrings?) -> [String] {
        var values: [String] = []
        for cell in row.cells {
            let reference = normalizeCellReference(String(describing: cell.reference))
            let index = columnIndex(reference: reference)
            if index < 0 { continue }
            while values.count <= index {
                values.append("")
            }
            values[index] = cellValue(cell, sharedStrings: sharedStrings)
        }
        return values
    }

    private static func cellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings, let text = try? cell.stringValue(sharedStrings), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let raw = cell.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.lowercased() == "null" ? "" : raw
    }

    private static func toRecords(_ rows: [[String]]) -> [[String: JSONValue]] {
        var groups: [String: AtssImportGroup] = [:]
        var groupOrder: [String] = []

        if rows.count <= 1 { return [] }
        for rowIndex in 1..<rows.count {
            let row = rows[rowIndex]
            let tip = cell(row, 0)
            let idPloshadki = integer(cell(row, 1))
            let serviceId = cell(row, 2)
            if idPloshadki == nil || serviceId.isEmpty { continue }

            let key = "\(serviceId)__\(idPloshadki ?? 0)"
            var group = groups[key]
            if group == nil {
                group = AtssImportGroup(
                    targetTable: isKasip(tip) ? "kasip_azm_q1_2026" : "atss_q1_2026",
                    tip: tip,
                    idPloshadki: idPloshadki ?? 0,
                    serviceId: serviceId,
                    address: cell(row, 3),
                    district: cell(row, 4),
                    planDate: planDate(cell(row, 9)),
                    sks: []
                )
                groupOrder.append(key)
            }

            let sk = AtssImportSk(
                id: integer(cell(row, 5)),
                name: cell(row, 6),
                status: cell(row, 7),
                type: integer(cell(row, 8))
            )
            if sk.id != nil || !sk.name.isEmpty || !sk.status.isEmpty || sk.type != nil {
                group?.sks.append(sk)
            }

            if let group {
                groups[key] = group
            }
        }

        var result: [[String: JSONValue]] = []
        for key in groupOrder {
            guard let group = groups[key] else { continue }
            var record: [String: JSONValue] = [:]
            put(&record, "__target_table", .string(group.targetTable))
            put(&record, "tip", .string(group.tip))
            put(&record, "id_ploshadki", .number(Double(group.idPloshadki)))
            put(&record, "servisnyy_id", .string(group.serviceId))
            if group.targetTable == "kasip_azm_q1_2026" {
                put(&record, "adres_raspolozheniya", .string(group.address))
            } else {
                put(&record, "adres_razmeshcheniya", .string(group.address))
            }
            put(&record, "rayon", .string(group.district))
            putPlan(&record, table: group.targetTable, yyyymmdd: group.planDate)

            for idx in 0..<min(group.sks.count, 6) {
                putSk(&record, table: group.targetTable, slot: idx + 1, sk: group.sks[idx])
            }
            result.append(record)
        }
        return result
    }

    private static func putPlan(_ record: inout [String: JSONValue], table: String, yyyymmdd: Int?) {
        guard let yyyymmdd else { return }
        if table == "kasip_azm_q1_2026" {
            let month = (yyyymmdd / 100) % 100
            if month == 2 {
                put(&record, "plan_fevral", .number(Double(yyyymmdd)))
            } else if month == 3 {
                put(&record, "plan_mart", .number(Double(yyyymmdd)))
            } else {
                put(&record, "plan_yanvar", .number(Double(yyyymmdd)))
            }
        } else {
            put(&record, "planovaya_data_1_kv_2026", .string(formatDateForTimestamp(yyyymmdd)))
        }
    }

    private static func putSk(_ record: inout [String: JSONValue], table: String, slot: Int, sk: AtssImportSk) {
        if table == "kasip_azm_q1_2026" {
            if slot == 6 {
                putInteger(&record, "id_sk6", sk.id)
                put(&record, "naimenovanie_sk6", .string(sk.name))
                put(&record, "status_oborudovaniya6", .string(sk.status))
                putInteger(&record, "tip_sk_po_dogovoru6", sk.type)
            } else {
                putInteger(&record, "id_konditsionera\(slot)", sk.id)
                put(&record, "naimenovanie_sk\(slot)", .string(sk.name))
                put(&record, "status_sk\(slot)", .string(sk.status))
                putInteger(&record, "tip_sk_po_dogovoru\(slot)", sk.type)
            }
            return
        }

        if slot == 1 {
            putInteger(&record, "id_sk", sk.id)
            put(&record, "status_oborudovaniya", .string(sk.status))
            putInteger(&record, "tip_sk_po_dogovoru", sk.type)
        } else {
            putInteger(&record, "id_sk\(slot)", sk.id)
            put(&record, "naimenovanie_sk\(slot)", .string(sk.name))
            put(&record, "status_oborudovaniya\(slot)", .string(sk.status))
            putInteger(&record, "tip_sk_po_dogovoru\(slot)", sk.type)
        }
        put(&record, "naimenovanie_sk\(slot)", .string(sk.name))
    }

    private static func columnIndex(reference: String) -> Int {
        let upper = reference.uppercased()
        var acc = 0
        var foundLetter = false
        for scalar in upper.unicodeScalars {
            if scalar.value >= 65 && scalar.value <= 90 {
                foundLetter = true
                acc = (acc * 26) + Int(scalar.value - 64)
            } else if foundLetter {
                break
            }
        }
        return foundLetter ? max(0, acc - 1) : 0
    }

    private static func normalizeCellReference(_ raw: String) -> String {
        if raw.isEmpty { return "" }
        if let matched = raw.range(of: "[A-Z]+[0-9]+", options: .regularExpression) {
            return String(raw[matched])
        }
        if let matched = raw.range(of: "[A-Z]+", options: .regularExpression) {
            return String(raw[matched])
        }
        return raw
    }

    private static func cell(_ row: [String], _ index: Int) -> String {
        guard index >= 0, index < row.count else { return "" }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.lowercased() == "null" ? "" : value
    }

    private static func integer(_ raw: String) -> Int? {
        let clean = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !clean.isEmpty else { return nil }
        if let value = Double(clean) {
            return Int(value.rounded())
        }
        let digits = clean.filter { ("0"..."9").contains($0) || $0 == "-" }
        guard !digits.isEmpty, digits != "-" else { return nil }
        return Int(digits)
    }

    private static func planDate(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let serial = Double(value.replacingOccurrences(of: ",", with: ".")), serial > 30_000, serial < 70_000 {
            // Excel serial date (origin 1899-12-30)
            let base = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 0), year: 1899, month: 12, day: 30).date
            if let base {
                let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: Int(serial.rounded()), to: base)
                if let date {
                    let parts = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0) ?? .current, from: date)
                    if let y = parts.year, let m = parts.month, let d = parts.day {
                        return y * 10_000 + m * 100 + d
                    }
                }
            }
        }

        let normalized = value.replacingOccurrences(of: "/", with: ".").replacingOccurrences(of: "-", with: ".")
        let parts = normalized.split(separator: ".")
        if parts.count >= 3 {
            var day = Int(parts[0]) ?? 0
            var month = Int(parts[1]) ?? 0
            var year = Int(parts[2]) ?? 0
            if year > 0, month > 0, day > 0 {
                if year < 100 { year += 2000 }
                return year * 10_000 + month * 100 + day
            }
        }

        let digits = value.filter { ("0"..."9").contains($0) }
        if digits.count == 8 {
            if digits.hasPrefix("20") {
                return Int(digits)
            }
            let day = Int(String(digits.prefix(2))) ?? 0
            let month = Int(String(digits.dropFirst(2).prefix(2))) ?? 0
            let year = Int(String(digits.suffix(4))) ?? 0
            if day > 0, month > 0, year > 0 {
                return year * 10_000 + month * 100 + day
            }
        }

        return nil
    }

    private static func isKasip(_ tip: String) -> Bool {
        let value = tip.lowercased()
        return value.contains("kasip") || value.contains("азм") || value.contains("azm") || value.contains("касип")
    }

    private static func formatDateForTimestamp(_ yyyymmdd: Int) -> String {
        let year = yyyymmdd / 10_000
        let month = (yyyymmdd / 100) % 100
        let day = yyyymmdd % 100
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func put(_ map: inout [String: JSONValue], _ key: String, _ value: JSONValue) {
        switch value {
        case .null:
            return
        case let .string(text):
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty || clean.lowercased() == "null" { return }
            map[key] = .string(clean)
        default:
            map[key] = value
        }
    }

    private static func putInteger(_ map: inout [String: JSONValue], _ key: String, _ value: Int?) {
        guard let value else { return }
        map[key] = .number(Double(value))
    }

    private static func normalizeSheetName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive], locale: .current)
    }
}

private struct AtssImportGroup {
    let targetTable: String
    let tip: String
    let idPloshadki: Int
    let serviceId: String
    let address: String
    let district: String
    let planDate: Int?
    var sks: [AtssImportSk]
}

private struct AtssImportSk {
    let id: Int?
    let name: String
    let status: String
    let type: Int?
}
