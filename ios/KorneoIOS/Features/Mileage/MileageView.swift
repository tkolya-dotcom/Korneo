import SwiftUI
import MapKit
import UIKit

struct MileageView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case map
        case stats
        case records

        var id: String { rawValue }
        var title: String {
            switch self {
            case .map: return "Карта"
            case .stats: return "Статистика"
            case .records: return "Записи"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MileageViewModel()

    @State private var selectedTab: Tab = .map
    @State private var filterMode: MileageViewModel.FilterMode = .day
    @State private var selectedDate = Date()
    @State private var selectedUserId: String?
    @State private var mapCameraPosition: MapCameraPosition = .automatic

    @State private var showFormulaEditor = false
    @State private var formulaDraft = ""
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var showFullscreenMap = false

    @State private var showManualAddSheet = false
    @State private var manualFrom = ""
    @State private var manualTo = ""
    @State private var manualDistance = ""
    @State private var manualUserId: String?

    @State private var editingRecord: MileageRecord?
    @State private var editDistance = ""
    @State private var editRoute = ""
    @State private var isBound = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.records.isEmpty {
                    ProgressView("Загрузка пробега...")
                } else if let error = viewModel.errorText, viewModel.records.isEmpty {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    VStack(spacing: 10) {
                        filterBar
                        tabPicker
                        tabContent
                    }
                    .padding(.horizontal)
                    .refreshable {
                        await reload()
                    }
                }
            }
            .navigationTitle("Пробег")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        manualUserId = selectedUserId
                        manualFrom = ""
                        manualTo = ""
                        manualDistance = ""
                        showManualAddSheet = true
                    } label: {
                        Label("Добавить", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Экспорт") {
                        exportCsv()
                    }
                    .disabled(filteredRecords.isEmpty)
                }
                if viewModel.isManager {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Формула") {
                            formulaDraft = String(format: "%.2f", viewModel.formulaRatePerKm)
                            showFormulaEditor = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showFormulaEditor) {
                formulaSheet
            }
            .sheet(isPresented: $showExportSheet) {
                if let exportURL {
                    ShareSheet(activityItems: [exportURL])
                } else {
                    Text("Нет файла")
                }
            }
            .sheet(isPresented: $showFullscreenMap) {
                fullscreenMapSheet
            }
            .sheet(isPresented: $showManualAddSheet) {
                manualAddSheet
            }
            .sheet(item: $editingRecord) { record in
                editRecordSheet(record: record)
            }
        }
        .task { await ensureBoundAndLoad() }
        .onAppear {
            Task { await ensureBoundAndLoad() }
        }
        .onChange(of: appState.selectedTab) { tab in
            guard tab == .mileage else { return }
            Task { await reload() }
        }
        .onChange(of: appState.currentUser?.id) { _ in
            Task { await ensureBoundAndLoad() }
        }
        .onChange(of: filterMode) { _, _ in moveCameraToFiltered() }
        .onChange(of: selectedDate) { _, _ in moveCameraToFiltered() }
        .onChange(of: selectedUserId) { _, _ in moveCameraToFiltered() }
    }

    private var filterBar: some View {
        VStack(spacing: 8) {
            Picker("Период", selection: $filterMode) {
                ForEach(MileageViewModel.FilterMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            DatePicker("Дата", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.compact)

            if viewModel.isManager {
                Picker("Пользователь", selection: $selectedUserId) {
                    ForEach(Array(viewModel.userOptions().enumerated()), id: \.offset) { item in
                        let option = item.element
                        Text(option.name).tag(option.id as String?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var tabPicker: some View {
        Picker("Вкладка", selection: $selectedTab) {
            ForEach(Tab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .map:
            mapContent
        case .stats:
            statsContent
        case .records:
            recordsContent
        }
    }

    private var mapContent: some View {
        VStack(spacing: 8) {
            let points = viewModel.mapPoints(from: filteredRecords)
            let routeCoordinates = filteredRecords
                .sorted { (viewModel.dateForRecord($0) ?? .distantPast) < (viewModel.dateForRecord($1) ?? .distantPast) }
                .compactMap { record -> CLLocationCoordinate2D? in
                    guard let lat = record.latitude, let lon = record.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }

            Map(position: $mapCameraPosition) {
                if routeCoordinates.count > 1 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(.cyan.opacity(0.7), lineWidth: 4)
                }
                ForEach(points) { point in
                    Annotation(point.title, coordinate: point.coordinate) {
                        VStack(spacing: 2) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                            Text(point.title)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .frame(minHeight: 340)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: filteredRecords.count) { _, _ in
                moveCameraToFiltered()
            }

            if points.isEmpty {
                Text("Нет точек для выбранного фильтра")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !points.isEmpty {
                Button {
                    showFullscreenMap = true
                } label: {
                    Label("Полный экран", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statsContent: some View {
        let stats = viewModel.stats(for: filteredRecords, todayRecords: todayRecords)
        return List {
            statRow("Период", periodTitle)
            statRow("Пробег (км)", String(format: "%.2f", stats.totalDistanceKm))
            statRow("Точек", "\(stats.totalPoints)")
            statRow("За сегодня (км)", String(format: "%.2f", stats.todayDistanceKm))
            statRow("Компенсация", String(format: "%.2f", stats.compensation))
            statRow("Ставка за 1 км", String(format: "%.2f", viewModel.formulaRatePerKm))
            statRow("Средняя точность (м)", stats.averageAccuracy.map { String(format: "%.1f", $0) } ?? "-")
        }
        .listStyle(.plain)
    }

    private var recordsContent: some View {
        List(filteredRecords) { record in
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.formatDate(record.date ?? record.createdAt))
                    .font(.headline)
                Text("Пробег: \(viewModel.formatDistance(record.distance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.isManager {
                    Text("Пользователь: \(viewModel.userName(for: record.userId))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let route = viewModel.cleanRoute(record.route)
                if !route.isEmpty {
                    Text(route)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                let purpose = viewModel.cleanPurpose(record.purpose)
                if !purpose.isEmpty {
                    Text(purpose)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.isManualRecord(record.id) {
                    Button(role: .destructive) {
                        viewModel.removeManualRecord(id: record.id)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
                Button {
                    editDistance = String(format: "%.2f", max(0, record.distance ?? 0))
                    editRoute = viewModel.cleanRoute(record.route)
                    editingRecord = record
                } label: {
                    Label("Править", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
        .listStyle(.plain)
    }

    private var formulaSheet: some View {
        NavigationStack {
            Form {
                TextField("Ставка за 1 км", text: $formulaDraft)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Формула")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { showFormulaEditor = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let raw = formulaDraft
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: ",", with: ".")
                        if let value = Double(raw), value > 0 {
                            viewModel.updateFormulaRate(value)
                            showFormulaEditor = false
                        }
                    }
                }
            }
        }
    }

    private var manualAddSheet: some View {
        NavigationStack {
            Form {
                if viewModel.isManager {
                    Picker("Пользователь", selection: $manualUserId) {
                        ForEach(Array(viewModel.userOptions().enumerated()), id: \.offset) { item in
                            let option = item.element
                            Text(option.name).tag(option.id as String?)
                        }
                    }
                }

                TextField("Откуда", text: $manualFrom)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()

                TextField("Куда", text: $manualTo)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()

                TextField("Километры", text: $manualDistance)
                    .keyboardType(.decimalPad)

                if !viewModel.knownAddresses().isEmpty {
                    Section("Подсказки адресов") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.knownAddresses(), id: \.self) { address in
                                    Button(address) {
                                        if manualFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            manualFrom = address
                                        } else {
                                            manualTo = address
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ручной маршрут")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { showManualAddSheet = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let distanceRaw = manualDistance
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: ",", with: ".")
                        guard let distance = Double(distanceRaw), distance > 0 else { return }
                        viewModel.addManualRecord(
                            userId: manualUserId,
                            from: manualFrom,
                            to: manualTo,
                            kilometers: distance,
                            date: selectedDate
                        )
                        showManualAddSheet = false
                    }
                }
            }
        }
    }

    private var fullscreenMapSheet: some View {
        NavigationStack {
            Map(position: $mapCameraPosition) {
                let points = viewModel.mapPoints(from: filteredRecords)
                let routeCoordinates = filteredRecords
                    .sorted { (viewModel.dateForRecord($0) ?? .distantPast) < (viewModel.dateForRecord($1) ?? .distantPast) }
                    .compactMap { record -> CLLocationCoordinate2D? in
                        guard let lat = record.latitude, let lon = record.longitude else { return nil }
                        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    }
                if routeCoordinates.count > 1 {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(.cyan.opacity(0.7), lineWidth: 4)
                }
                ForEach(points) { point in
                    Annotation(point.title, coordinate: point.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Маршрут")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { showFullscreenMap = false }
                }
            }
        }
    }

    private func editRecordSheet(record: MileageRecord) -> some View {
        NavigationStack {
            Form {
                Text(viewModel.formatDate(record.date ?? record.createdAt))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Километры", text: $editDistance)
                    .keyboardType(.decimalPad)

                TextField("Маршрут", text: $editRoute)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Правка маршрута")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { editingRecord = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        let normalized = editDistance
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: ",", with: ".")
                        let distance = Double(normalized)
                        viewModel.saveOverrides(
                            recordId: record.id,
                            distance: distance,
                            route: editRoute
                        )
                        editingRecord = nil
                    }
                }
            }
        }
    }

    private var filteredRecords: [MileageRecord] {
        viewModel.filteredRecords(
            mode: filterMode,
            selectedDate: selectedDate,
            selectedUserId: selectedUserId
        )
    }

    private var todayRecords: [MileageRecord] {
        viewModel.recordsForToday(selectedUserId: selectedUserId)
    }

    private var periodTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        switch filterMode {
        case .day:
            formatter.dateFormat = "dd.MM.yyyy"
        case .month:
            formatter.dateFormat = "MM.yyyy"
        case .year:
            formatter.dateFormat = "yyyy"
        }
        return formatter.string(from: selectedDate)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func reload() async {
        await viewModel.load()
        moveCameraToFiltered()
    }

    private func ensureBoundAndLoad() async {
        if !isBound {
            viewModel.bind(client: appState.client, currentUser: appState.currentUser)
            isBound = true
        } else {
            viewModel.bind(client: appState.client, currentUser: appState.currentUser)
        }
        await reload()
    }

    private func moveCameraToFiltered() {
        let points = viewModel.mapPoints(from: filteredRecords)
        let coordinates = points.map(\.coordinate)
        guard !coordinates.isEmpty else { return }
        mapCameraPosition = .rect(rect(for: coordinates))
    }

    private func rect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        guard let first = coordinates.first else { return .world }
        var rect = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))
        for coordinate in coordinates.dropFirst() {
            rect = rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        if rect.size.width < 500 || rect.size.height < 500 {
            rect = rect.insetBy(dx: -2000, dy: -2000)
        }
        return rect
    }

    private func exportCsv() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "mileage_report_\(formatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let header = "date,user,distance_km,route,purpose,accuracy\n"
        let rows = filteredRecords.map { record in
            let date = csvEscape(viewModel.formatDate(record.date ?? record.createdAt))
            let user = csvEscape(viewModel.userName(for: record.userId))
            let distance = String(format: "%.2f", max(0, record.distance ?? 0))
            let route = csvEscape(viewModel.cleanRoute(record.route))
            let purpose = csvEscape(viewModel.cleanPurpose(record.purpose))
            let accuracy = record.accuracy.map { String(format: "%.2f", $0) } ?? ""
            return "\(date),\(user),\(distance),\(route),\(purpose),\(accuracy)"
        }
        let content = header + rows.joined(separator: "\n")

        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            // Keep silent UI-wise here; data remains in-app.
        }
    }

    private func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
