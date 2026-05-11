import Foundation
import SwiftUI
import MapKit
import CoreLocation

struct MapScreenView: View {
    private struct CachedRoute: Codable {
        let from: String
        let to: String
        let startLat: Double
        let startLon: Double
        let endLat: Double
        let endLon: Double
        let distance: Double
        let duration: Double
        let coordinates: [[Double]]
        let savedAt: String
    }

    private enum Mode: String, CaseIterable, Identifiable {
        case users
        case navigation

        var id: String { rawValue }

        var title: String {
            switch self {
            case .users: return "Пользователи"
            case .navigation: return "Навигация"
            }
        }
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MapScreenViewModel()
    @StateObject private var locationProvider = LocationProvider()

    @State private var selectedMode: Mode = .navigation
    @State private var usersCameraPosition: MapCameraPosition = .automatic
    @State private var navigationCameraPosition: MapCameraPosition = .automatic

    @State private var routeFrom = ""
    @State private var routeTo = ""
    @State private var activeRoute: MKRoute?
    @State private var cachedRouteCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeStartCoordinate: CLLocationCoordinate2D?
    @State private var routeEndCoordinate: CLLocationCoordinate2D?
    @State private var routeInfoText = ""
    @State private var routeErrorText: String?
    @State private var showRouteError = false
    @State private var isCalculatingRoute = false

    @State private var showQuickWorkSheet = false
    @State private var availableGroupChats: [Chat] = []
    @State private var selectedGroupChatId = ""
    @State private var workType = "ППО"
    @State private var workHours = "8"
    @State private var workNote = ""
    @State private var isCreatingWork = false
    @State private var workInfoText: String?

    @State private var showArrivalPrompt = false
    @State private var arrivalPromptAddress = ""
    @State private var hasAskedArrivalForCurrentRoute = false

    @State private var showInAppNavigationSheet = false
    @State private var isBound = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.navigationPoints.isEmpty && viewModel.userLocationPoints.isEmpty {
                ProgressView("Загрузка карты...")
            } else if let error = viewModel.errorText,
                      viewModel.navigationPoints.isEmpty,
                      viewModel.userLocationPoints.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                VStack(spacing: 10) {
                    if hasManagerRights {
                        Picker("Режим", selection: $selectedMode) {
                            ForEach(Mode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    if selectedMode == .users && hasManagerRights {
                        usersMap
                    } else {
                        navigationMap
                    }
                }
            }
        }
        .alert("Ошибка", isPresented: $showRouteError) {
            Button("Ок", role: .cancel) { }
        } message: {
            Text(routeErrorText ?? "Не удалось построить маршрут")
        }
        .sheet(isPresented: $showQuickWorkSheet) {
            quickWorkSheet
        }
        .sheet(isPresented: $showInAppNavigationSheet) {
            inAppNavigationSheet
        }
        .alert("Вы приехали", isPresented: $showArrivalPrompt) {
            Button("Нет", role: .cancel) { }
            Button("Да") {
                Task { await prepareQuickWorkCreation() }
            }
        } message: {
            Text("Запланировать работы по адресу?\n\(arrivalPromptAddress)")
        }
        .task { await ensureBoundAndLoad() }
        .onAppear {
            Task { await ensureBoundAndLoad() }
        }
        .onChange(of: appState.selectedTab) { tab in
            guard tab == .search else { return }
            Task { await reload() }
        }
        .onChange(of: appState.currentUser?.id) { _ in
            Task { await ensureBoundAndLoad() }
        }
        .onReceive(locationProvider.$currentCoordinate) { coordinate in
            guard let coordinate else { return }
            handleArrivalCheck(current: coordinate)
        }
    }

    private var hasManagerRights: Bool {
        appState.currentUser?.role?.hasManagerRights == true
    }

    private var usersMap: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Map(position: $usersCameraPosition) {
                    ForEach(viewModel.userLocationPoints) { point in
                        Annotation(point.name, coordinate: point.coordinate) {
                            VStack(spacing: 3) {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundStyle(userMarkerColor(point))
                                Text(point.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .frame(minHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    legendItem(color: .green, text: "Текущее")
                    legendItem(color: .orange, text: "Недавнее")
                    legendItem(color: .red, text: "Старое")
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)
            }

            Text(viewModel.usersMapStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            List(viewModel.userLocationPoints) { point in
                VStack(alignment: .leading, spacing: 2) {
                    Text(point.name)
                        .font(.headline)
                    Text(point.timestampText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(point.freshnessText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
            .listStyle(.plain)
        }
        .padding(.horizontal)
        .refreshable { await reload() }
    }

    private var navigationMap: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                Map(position: $navigationCameraPosition) {
                    ForEach(viewModel.navigationPoints) { point in
                        Annotation(point.title, coordinate: point.coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(markerColor(for: point.source))
                        }
                    }

                    if let activeRoute {
                        MapPolyline(activeRoute.polyline)
                            .stroke(.cyan, lineWidth: 5)
                    } else if cachedRouteCoordinates.count > 1 {
                        MapPolyline(coordinates: cachedRouteCoordinates)
                            .stroke(.cyan, lineWidth: 5)
                    }

                    if let routeStartCoordinate {
                        Annotation("Старт", coordinate: routeStartCoordinate) {
                            Image(systemName: "flag.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    if let routeEndCoordinate {
                        Annotation("Финиш", coordinate: routeEndCoordinate) {
                            Image(systemName: "flag.checkered.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .frame(minHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    legendItem(color: .blue, text: "Работы")
                    legendItem(color: .green, text: "Монтажи")
                    legendItem(color: .cyan, text: "Маршрут")
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(10)
            }

            Group {
                TextField("Откуда", text: $routeFrom)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                suggestionList(for: routeFrom) { routeFrom = $0 }

                TextField("Куда", text: $routeTo)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                suggestionList(for: routeTo) { routeTo = $0 }
            }

            HStack(spacing: 10) {
                Button("Моё местоположение") {
                    routeFrom = "Моё местоположение"
                }
                .buttonStyle(.bordered)

                Button(isCalculatingRoute ? "Строим..." : "Построить маршрут") {
                    Task { await buildRoute() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCalculatingRoute || routeFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || routeTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack(spacing: 10) {
                Button("Открыть навигацию") {
                    openInAppleMaps()
                }
                .buttonStyle(.bordered)
                .disabled(routeStartCoordinate == nil || routeEndCoordinate == nil)

                Button("Навигация в приложении") {
                    showInAppNavigationSheet = true
                }
                .buttonStyle(.bordered)
                .disabled(routeStartCoordinate == nil || routeEndCoordinate == nil)

                Button("Добавить работы") {
                    Task { await prepareQuickWorkCreation() }
                }
                .buttonStyle(.bordered)
                .disabled(routeEndCoordinate == nil || routeTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Очистить маршрут", role: .destructive) {
                    activeRoute = nil
                    cachedRouteCoordinates = []
                    routeStartCoordinate = nil
                    routeEndCoordinate = nil
                    routeInfoText = ""
                    hasAskedArrivalForCurrentRoute = false
                }
                .buttonStyle(.bordered)
            }

            if !routeInfoText.isEmpty {
                Text(routeInfoText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let workInfoText, !workInfoText.isEmpty {
                Text(workInfoText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .refreshable { await reload() }
    }

    private func suggestionList(for query: String, onPick: @escaping (String) -> Void) -> some View {
        let suggestions = filteredHints(for: query)
        return Group {
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { onPick(suggestion) }
                                .buttonStyle(.bordered)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private func filteredHints(for rawQuery: String) -> [String] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return Array(viewModel.addressHints.prefix(8))
        }
        return viewModel.addressHints
            .filter { $0.lowercased().contains(query) }
            .prefix(8)
            .map { $0 }
    }

    private func reload() async {
        await viewModel.load()

        if hasManagerRights, !viewModel.userLocationPoints.isEmpty {
            usersCameraPosition = .rect(mapRect(for: viewModel.userLocationPoints.map(\.coordinate)))
        }

        if !viewModel.navigationPoints.isEmpty {
            navigationCameraPosition = .rect(mapRect(for: viewModel.navigationPoints.map(\.coordinate)))
        }
    }

    private func ensureBoundAndLoad() async {
        if !isBound {
            locationProvider.requestPermission()
            isBound = true
        }
        viewModel.bind(client: appState.client, currentUser: appState.currentUser)
        selectedMode = hasManagerRights ? .users : .navigation
        await reload()
    }

    private func buildRoute() async {
        let fromText = routeFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        let toText = routeTo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fromText.isEmpty, !toText.isEmpty else { return }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        guard let fromCoordinate = await resolveCoordinate(for: fromText) else {
            presentRouteError("Не удалось определить точку старта")
            return
        }

        guard let toCoordinate = await resolveCoordinate(for: toText) else {
            presentRouteError("Не удалось определить точку назначения")
            return
        }

        do {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromCoordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toCoordinate))
            request.transportType = .automobile

            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                presentRouteError("Маршрут не найден")
                return
            }

            activeRoute = route
            cachedRouteCoordinates = route.polyline.coordinates
            routeStartCoordinate = fromCoordinate
            routeEndCoordinate = toCoordinate
            routeInfoText = routeSummary(route)
            navigationCameraPosition = .rect(route.polyline.boundingMapRect)
            hasAskedArrivalForCurrentRoute = false

            saveRouteToCache(
                from: fromText,
                to: toText,
                start: fromCoordinate,
                end: toCoordinate,
                distance: route.distance,
                duration: route.expectedTravelTime,
                coordinates: route.polyline.coordinates
            )
        } catch {
            if loadRouteFromCache(from: fromText, to: toText) {
                return
            }
            presentRouteError("Ошибка построения маршрута: \(error.localizedDescription)")
        }
    }

    private func resolveCoordinate(for query: String) async -> CLLocationCoordinate2D? {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        if clean.caseInsensitiveCompare("Моё местоположение") == .orderedSame {
            return locationProvider.currentCoordinate
        }

        if let exact = viewModel.navigationPoints.first(where: {
            $0.subtitle.caseInsensitiveCompare(clean) == .orderedSame ||
            $0.title.caseInsensitiveCompare(clean) == .orderedSame
        }) {
            return exact.coordinate
        }

        if let approximate = viewModel.navigationPoints.first(where: {
            $0.subtitle.lowercased().contains(clean.lowercased()) ||
            $0.title.lowercased().contains(clean.lowercased())
        }) {
            return approximate.coordinate
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = clean
        if let current = locationProvider.currentCoordinate {
            request.region = MKCoordinateRegion(
                center: current,
                span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            return nil
        }
    }

    private func openInAppleMaps() {
        guard let start = routeStartCoordinate, let end = routeEndCoordinate else { return }
        let source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        source.name = "Старт"

        let destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        destination.name = "Финиш"

        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }

    private var inAppNavigationSheet: some View {
        NavigationStack {
            Map(position: $navigationCameraPosition) {
                if let activeRoute {
                    MapPolyline(activeRoute.polyline)
                        .stroke(.cyan, lineWidth: 6)
                } else if cachedRouteCoordinates.count > 1 {
                    MapPolyline(coordinates: cachedRouteCoordinates)
                        .stroke(.cyan, lineWidth: 6)
                }

                if let routeStartCoordinate {
                    Annotation("Старт", coordinate: routeStartCoordinate) {
                        Image(systemName: "flag.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let routeEndCoordinate {
                    Annotation("Финиш", coordinate: routeEndCoordinate) {
                        Image(systemName: "flag.checkered.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if let current = locationProvider.currentCoordinate {
                    Annotation("Вы", coordinate: current) {
                        Image(systemName: "location.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Навигация")
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routeInfoText.isEmpty ? "Маршрут активен" : routeInfoText)
                    if let destination = routeEndCoordinate, let current = locationProvider.currentCoordinate {
                        let left = CLLocation(latitude: current.latitude, longitude: current.longitude)
                            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
                        Text(String(format: "До точки: %.0f м", left))
                    }
                }
                .font(.caption)
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") {
                        showInAppNavigationSheet = false
                    }
                }
            }
        }
    }

    private var quickWorkSheet: some View {
        NavigationStack {
            Form {
                Picker("Групповой чат", selection: $selectedGroupChatId) {
                    ForEach(availableGroupChats, id: \.id) { chat in
                        Text(chatDisplayName(chat)).tag(chat.id)
                    }
                }

                Picker("Тип работ", selection: $workType) {
                    Text("ППО").tag("ППО")
                    Text("АВР").tag("АВР")
                    Text("НРД").tag("НРД")
                    Text("Тех. заявка").tag("Тех. заявка")
                }

                TextField("Часы", text: $workHours)
                    .keyboardType(.numberPad)

                TextField("Комментарий", text: $workNote, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("Добавить работы")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        showQuickWorkSheet = false
                    }
                    .disabled(isCreatingWork)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isCreatingWork ? "Создаём..." : "Создать") {
                        Task { await createWorkFromMap() }
                    }
                    .disabled(isCreatingWork || selectedGroupChatId.isEmpty)
                }
            }
        }
    }

    private func prepareQuickWorkCreation() async {
        let userId = (appState.currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            presentRouteError("Пользователь не найден")
            return
        }

        do {
            let chats = try await appState.client.fetchMyChats(userId: userId)
            let groups = chats.filter { ($0.type ?? "").lowercased() == "group" }
            if groups.isEmpty {
                presentRouteError("Нет группового чата для добавления работ")
                return
            }

            availableGroupChats = groups
            selectedGroupChatId = groups.first?.id ?? ""
            workType = "ППО"
            workHours = "8"
            workNote = ""
            showQuickWorkSheet = true
        } catch {
            presentRouteError("Не удалось загрузить групповые чаты: \(error.localizedDescription)")
        }
    }

    private func createWorkFromMap() async {
        let userId = (appState.currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let userName = (appState.currentUser?.name ?? appState.currentUser?.email ?? "Пользователь")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let address = routeTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let chatId = selectedGroupChatId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userId.isEmpty, !address.isEmpty, !chatId.isEmpty else {
            presentRouteError("Заполните данные для создания работ")
            return
        }

        let hours = max(1, Int(workHours.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8)
        isCreatingWork = true
        defer { isCreatingWork = false }

        do {
            let jobId = try await appState.client.createMapWorkJob(
                chatId: chatId,
                userId: userId,
                address: address,
                title: workType,
                plannedDurationHours: hours
            )

            var card: [String: JSONValue] = [
                "type": .string("work_card"),
                "job_id": .string(jobId),
                "title": .string(workType),
                "address": .string(address),
                "mileage_address": .string(address),
                "hours": .number(Double(hours)),
                "status": .string("created"),
                "creator_id": .string(userId),
                "creator_name": .string(userName.isEmpty ? "Пользователь" : userName),
                "assignee_id": .string(userId),
                "assignee_name": .string(userName.isEmpty ? "Пользователь" : userName),
                "created_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]

            let cleanNote = workNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanNote.isEmpty {
                card["description"] = .string(cleanNote)
            }

            let creatorDisplayName = userName.isEmpty ? "Пользователь" : userName
            let text = "Работы: \(workType)\nАдрес: \(address)\nЧасы: \(hours)\nКто завёл: \(creatorDisplayName)"
            card["text"] = .string(text)

            _ = try await appState.client.sendMessageContent(
                chatId: chatId,
                userId: userId,
                content: .object(card),
                type: "work_card"
            )

            showQuickWorkSheet = false
            workInfoText = "Работы добавлены в групповой чат"
            await reload()
        } catch {
            presentRouteError("Не удалось создать работы: \(error.localizedDescription)")
        }
    }

    private func chatDisplayName(_ chat: Chat) -> String {
        let name = (chat.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Групповой чат" : name
    }

    private func presentRouteError(_ text: String) {
        routeErrorText = text
        showRouteError = true
    }

    private func mapRect(for coordinates: [CLLocationCoordinate2D]) -> MKMapRect {
        guard let first = coordinates.first else {
            return .world
        }

        var rect = MKMapRect(origin: MKMapPoint(first), size: MKMapSize(width: 0, height: 0))
        for coordinate in coordinates.dropFirst() {
            rect = rect.union(MKMapRect(origin: MKMapPoint(coordinate), size: MKMapSize(width: 0, height: 0)))
        }

        if rect.size.width < 500 || rect.size.height < 500 {
            rect = rect.insetBy(dx: -2000, dy: -2000)
        }

        return rect
    }

    private func routeSummary(_ route: MKRoute) -> String {
        let km = route.distance / 1000
        let minutes = Int(route.expectedTravelTime / 60)
        return String(format: "Маршрут: %.1f км • ~%d мин", km, minutes)
    }

    private func handleArrivalCheck(current: CLLocationCoordinate2D) {
        guard !hasAskedArrivalForCurrentRoute else { return }
        guard let destination = routeEndCoordinate else { return }

        let from = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let to = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distance = from.distance(from: to)

        guard distance <= 90 else { return }
        hasAskedArrivalForCurrentRoute = true

        let cleanAddress = routeTo.trimmingCharacters(in: .whitespacesAndNewlines)
        arrivalPromptAddress = cleanAddress.isEmpty ? "Адрес маршрута" : cleanAddress
        showArrivalPrompt = true
    }

    private func routeCacheKey(from: String, to: String) -> String {
        let normalized = "\(from.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(to.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        let encoded = Data(normalized.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return "korneo.route.cache.\(encoded)"
    }

    private func saveRouteToCache(
        from: String,
        to: String,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        distance: Double,
        duration: Double,
        coordinates: [CLLocationCoordinate2D]
    ) {
        let payload = CachedRoute(
            from: from,
            to: to,
            startLat: start.latitude,
            startLon: start.longitude,
            endLat: end.latitude,
            endLon: end.longitude,
            distance: distance,
            duration: duration,
            coordinates: coordinates.map { [$0.latitude, $0.longitude] },
            savedAt: ISO8601DateFormatter().string(from: Date())
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: routeCacheKey(from: from, to: to))
    }

    private func loadRouteFromCache(from: String, to: String) -> Bool {
        let key = routeCacheKey(from: from, to: to)
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedRoute.self, from: data) else {
            return false
        }

        let coords = cached.coordinates.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        guard coords.count > 1 else { return false }

        activeRoute = nil
        cachedRouteCoordinates = coords
        routeStartCoordinate = CLLocationCoordinate2D(latitude: cached.startLat, longitude: cached.startLon)
        routeEndCoordinate = CLLocationCoordinate2D(latitude: cached.endLat, longitude: cached.endLon)
        hasAskedArrivalForCurrentRoute = false

        let km = cached.distance / 1000
        let minutes = Int(cached.duration / 60)
        routeInfoText = String(format: "Маршрут: %.1f км • ~%d мин • из кэша", km, minutes)
        navigationCameraPosition = .rect(mapRect(for: coords))
        return true
    }

    private func userMarkerColor(_ point: MapScreenViewModel.UserLocationPoint) -> Color {
        if point.isCurrent { return .green }
        if point.isRecent { return .orange }
        return .red
    }

    private func markerColor(for source: String) -> Color {
        switch source {
        case "job":
            return .blue
        case "installation":
            return .green
        default:
            return .red
        }
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2)
        }
    }
}

@MainActor
private final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let coordinate = locations.last?.coordinate {
            currentCoordinate = coordinate
        }
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
