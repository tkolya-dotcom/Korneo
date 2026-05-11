import SwiftUI

struct PurchaseRequestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PurchaseRequestsViewModel()
    @State private var showCreateSheet = false
    @State private var pendingDeleteItem: PurchaseRequest?
    @State private var isDeleting = false
    @State private var searchText = ""
    @State private var selectedStatusRaw = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Загрузка заявок...")
                } else if let error = viewModel.errorText, viewModel.items.isEmpty {
                    ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List {
                        Section("Фильтр") {
                            Picker("Статус", selection: $selectedStatusRaw) {
                                Text("Все статусы").tag("")
                                ForEach(PurchaseRequestStatus.allCases) { status in
                                    Text(status.displayLabel).tag(status.rawValue)
                                }
                            }
                        }

                        if filteredItems.isEmpty {
                            Section {
                                Text("Нет подходящих заявок")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(filteredItems) { item in
                                NavigationLink {
                                    PurchaseRequestDetailView(viewModel: viewModel, item: item)
                                        .environmentObject(appState)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(displayTitle(for: item))
                                            .font(.headline)
                                        Text(statusLabel(for: item.status))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if let address = item.receiptAddress, !address.isEmpty {
                                            Text(address)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let materials = viewModel.materialPreviewByRequestId[item.id], !materials.isEmpty {
                                            Text(materials)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        } else if let comment = item.comment, !comment.isEmpty {
                                            Text(comment)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if canDelete(item: item) {
                                        Button(role: .destructive) {
                                            pendingDeleteItem = item
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Заявки на закупку")
            .searchable(text: $searchText, prompt: "Поиск заявок")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePurchaseRequestView(viewModel: viewModel)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Удалить заявку?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Удаление..." : "Удалить", role: .destructive) {
                guard let item = pendingDeleteItem else { return }
                Task {
                    isDeleting = true
                    defer { isDeleting = false }
                    let ok = await viewModel.delete(id: item.id)
                    if ok {
                        pendingDeleteItem = nil
                    }
                }
            }
            .disabled(isDeleting)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private var filteredItems: [PurchaseRequest] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.items.filter { item in
            if !selectedStatusRaw.isEmpty, (item.status ?? "") != selectedStatusRaw {
                return false
            }
            if query.isEmpty {
                return true
            }
            let haystack = [
                displayTitle(for: item),
                item.comment ?? "",
                item.receiptAddress ?? "",
                item.status ?? ""
            ]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(query)
        }
    }

    private func canDelete(item: PurchaseRequest) -> Bool {
        guard let user = appState.currentUser else { return false }
        if user.role?.hasManagerRights == true { return true }
        return user.id == item.createdBy
    }

    private func displayTitle(for item: PurchaseRequest) -> String {
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        if let comment = item.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
            return comment
        }
        if let shortId = item.shortId {
            return "Заявка #\(shortId)"
        }
        return "Заявка #\(item.id.prefix(8))"
    }

    private func statusLabel(for raw: String?) -> String {
        guard let raw, let status = PurchaseRequestStatus(rawValue: raw) else {
            let clean = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? "Черновик" : clean
        }
        return status.displayLabel
    }
}
