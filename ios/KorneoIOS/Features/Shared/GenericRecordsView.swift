import SwiftUI

struct GenericRecordsView: View {
    let title: String
    let table: String
    let order: String?
    let limit: Int?

    @EnvironmentObject private var appState: AppState
    @State private var rows: [GenericRecord] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        Group {
            if isLoading && rows.isEmpty {
                ProgressView("Loading...")
            } else if let errorText, rows.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(errorText))
            } else {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(primaryText(for: row))
                            .font(.headline)
                        Text(secondaryText(for: row))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .refreshable {
                    await load()
                }
            }
        }
        .navigationTitle(title)
        .task {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            rows = try await appState.client.fetchTableRows(table: table, order: order, limit: limit)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func primaryText(for row: GenericRecord) -> String {
        let keys = ["title", "name", "id_ploshadki", "id", "short_id"]
        for key in keys {
            if let value = row.fields[key]?.textValue, !value.isEmpty {
                return value
            }
        }
        return row.id
    }

    private func secondaryText(for row: GenericRecord) -> String {
        let keys = ["status", "address", "description", "created_at", "updated_at"]
        let parts = keys.compactMap { key -> String? in
            guard let value = row.fields[key]?.textValue, !value.isEmpty else { return nil }
            return "\(key): \(value)"
        }
        return parts.joined(separator: " • ")
    }
}


