import SwiftUI

struct CatalogView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CatalogViewModel()

    @State private var searchText = ""
    @State private var powerFilter = ""
    @State private var brandFilter = ""
    @State private var seriesFilter = ""
    @State private var typeFilter = ""
    @State private var directionFilter = ""
    @State private var minPriceFilter = ""
    @State private var maxPriceFilter = ""
    @State private var onlyInStock = false
    @State private var onlyInTransit = false

    var body: some View {
        List {
            Section("Поиск") {
                TextField("Артикул / название", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(viewModel.isLoading ? "Ищем..." : "Искать") {
                    Task { await viewModel.load(searchTerm: searchText) }
                }
                .disabled(viewModel.isLoading)
            }

            Section("Фильтры") {
                TextField("Мощность", text: $powerFilter)
                TextField("Бренд", text: $brandFilter)
                TextField("Серия", text: $seriesFilter)
                TextField("Тип", text: $typeFilter)
                TextField("Направление", text: $directionFilter)
                TextField("Цена от", text: $minPriceFilter)
                    .keyboardType(.decimalPad)
                TextField("Цена до", text: $maxPriceFilter)
                    .keyboardType(.decimalPad)
                Toggle("Только в наличии", isOn: $onlyInStock)
                Toggle("Только в пути", isOn: $onlyInTransit)
            }

            if let error = viewModel.errorText, !error.isEmpty {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Товары (\(filteredProducts.count))") {
                if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView("Загрузка каталога...")
                } else if filteredProducts.isEmpty {
                    Text("Товары не найдены")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredProducts) { product in
                        NavigationLink {
                            DaichiProductDetailView(product: product)
                                .environmentObject(viewModel)
                        } label: {
                            DaichiProductRow(product: product)
                        }
                    }
                }
            }
        }
        .navigationTitle("Каталог Daichi")
        .refreshable {
            await viewModel.load(searchTerm: searchText)
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load(searchTerm: searchText)
        }
    }

    private var filteredProducts: [DaichiProduct] {
        viewModel.products.filter { product in
            let power = normalizePower(product.power)
            let productBrand = safeLower(product.brand)
            let productSeries = safeLower(product.series)
            let productType = safeLower(product.type)
            let productDirection = safeLower(product.direction)
            let article = safeLower(product.article)
            let name = safeLower(product.name)
            let group = safeLower(product.group)
            let search = safeLower(searchText)

            let matchesSearch = search.isEmpty || article.contains(search) || name.contains(search) || group.contains(search) || productDirection.contains(search)
            let matchesPower = normalizePower(powerFilter).isEmpty || power.contains(normalizePower(powerFilter))
            let matchesBrand = safeLower(brandFilter).isEmpty || productBrand.contains(safeLower(brandFilter))
            let matchesSeries = safeLower(seriesFilter).isEmpty || productSeries.contains(safeLower(seriesFilter))
            let matchesType = safeLower(typeFilter).isEmpty || productType.contains(safeLower(typeFilter))
            let matchesDirection = safeLower(directionFilter).isEmpty || productDirection.contains(safeLower(directionFilter))
            let matchesStock = !onlyInStock || product.stock > 0
            let matchesTransit = !onlyInTransit || product.inTransit > 0

            let price = parseDouble(product.price)
            let minPrice = parseDouble(minPriceFilter)
            let maxPrice = parseDouble(maxPriceFilter)
            let matchesMinPrice: Bool
            if let minPrice {
                matchesMinPrice = (price ?? -Double.infinity) >= minPrice
            } else {
                matchesMinPrice = true
            }
            let matchesMaxPrice: Bool
            if let maxPrice {
                matchesMaxPrice = (price ?? Double.infinity) <= maxPrice
            } else {
                matchesMaxPrice = true
            }

            return matchesSearch && matchesPower && matchesBrand && matchesSeries && matchesType && matchesDirection && matchesStock && matchesTransit && matchesMinPrice && matchesMaxPrice
        }
    }

    private func safeLower(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizePower(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "квт", with: "")
            .replacingOccurrences(of: "kw", with: "")
            .replacingOccurrences(of: "w", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .filter { "0123456789.".contains($0) }
    }

    private func parseDouble(_ raw: String) -> Double? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-".contains($0) }
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}

private struct DaichiProductRow: View {
    let product: DaichiProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(safe(product.article)) - \(safe(product.name))")
                .font(.headline)
            Text("Бренд: \(safe(product.brand)) | Серия: \(safe(product.series))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Группа: \(safe(product.group)) | Тип: \(safe(product.type))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !product.power.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Мощность: \(product.power) кВт")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("В наличии: \(product.stock) | В пути: \(product.inTransit)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(safe(product.price)) \(safe(product.currency))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Склад: \(safe(product.warehouse)) • Направление: \(safe(product.direction))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func safe(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
    }
}

private struct DaichiProductDetailView: View {
    let product: DaichiProduct
    @EnvironmentObject private var viewModel: CatalogViewModel

    var body: some View {
        List {
            Section("Товар") {
                Text("\(safe(product.article)) - \(safe(product.name))")
                Text("Бренд: \(safe(product.brand)) | Серия: \(safe(product.series))")
                Text("Тип: \(safe(product.type)) | Группа: \(safe(product.group))")
                Text("Цена: \(safe(product.price)) \(safe(product.currency))")
                Text("В наличии: \(product.stock)\nВ пути: \(product.inTransit)\nСклад: \(safe(product.warehouse))")
            }

            Section("Характеристики") {
                if isLoadingDetails {
                    ProgressView("Загрузка...")
                } else if let details {
                    if details.params.isEmpty {
                        Text("Характеристики не найдены")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(details.params) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.value)
                            }
                        }
                    }
                } else {
                    Text("Нет данных")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Документация") {
                if let details, !details.documentURLs.isEmpty {
                    ForEach(details.documentURLs, id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            Link(urlString.components(separatedBy: "/").last ?? urlString, destination: url)
                        } else {
                            Text(urlString)
                        }
                    }
                } else {
                    Text("Документация не найдена")
                        .foregroundStyle(.secondary)
                }
            }

            if let detailsError = viewModel.detailsErrorText, !detailsError.isEmpty {
                Section {
                    Text(detailsError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Детали")
        .task {
            await viewModel.loadDetailsIfNeeded(xmlId: product.id)
        }
    }

    private var details: DaichiProductDetails? {
        viewModel.details(for: product.id)
    }

    private var isLoadingDetails: Bool {
        viewModel.detailsLoadingIds.contains(product.id)
    }

    private func safe(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "-" : clean
    }
}
