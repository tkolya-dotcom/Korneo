import Foundation

@MainActor
final class CatalogViewModel: ObservableObject {
    @Published private(set) var products: [DaichiProduct] = []
    @Published private(set) var isLoading = false
    @Published var errorText: String?

    @Published private(set) var detailsById: [String: DaichiProductDetails] = [:]
    @Published private(set) var detailsLoadingIds = Set<String>()
    @Published var detailsErrorText: String?

    private var client: SupabaseClient?

    func bind(client: SupabaseClient) {
        self.client = client
    }

    func load(searchTerm: String?) async {
        guard let client else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            products = try await client.fetchDaichiProducts(searchTerm: searchTerm)
        } catch {
            errorText = error.localizedDescription
            products = []
        }
    }

    func loadDetailsIfNeeded(xmlId: String) async {
        let cleanId = xmlId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, !cleanId.isEmpty else { return }
        if detailsById[cleanId] != nil || detailsLoadingIds.contains(cleanId) {
            return
        }
        detailsLoadingIds.insert(cleanId)
        defer { detailsLoadingIds.remove(cleanId) }

        do {
            detailsById[cleanId] = try await client.fetchDaichiProductDetails(xmlId: cleanId)
        } catch {
            detailsErrorText = error.localizedDescription
        }
    }

    func details(for xmlId: String) -> DaichiProductDetails? {
        detailsById[xmlId.trimmingCharacters(in: .whitespacesAndNewlines)]
    }
}
