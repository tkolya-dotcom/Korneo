import SwiftUI

struct ArchiveView: View {
    private struct PendingUnarchive {
        let id: String
        let tab: ArchiveViewModel.Tab
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ArchiveViewModel()
    @State private var selectedTab: ArchiveViewModel.Tab = .tasks
    @State private var searchText = ""
    @State private var detailRow: ArchiveViewModel.Row?
    @State private var pendingUnarchive: PendingUnarchive?
    @State private var isUnarchiving = false

    var body: some View {
        Group {
            if viewModel.isLoading && filteredRows.isEmpty {
                ProgressView("Загрузка архива...")
            } else if let error = viewModel.errorText, filteredRows.isEmpty {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List {
                    Section {
                        Picker("Архив", selection: $selectedTab) {
                            Text(tasksTabTitle).tag(ArchiveViewModel.Tab.tasks)
                            Text(installationsTabTitle).tag(ArchiveViewModel.Tab.installations)
                            Text(avrTabTitle).tag(ArchiveViewModel.Tab.avr)
                        }
                        .pickerStyle(.segmented)
                    }

                    if filteredRows.isEmpty {
                        Section {
                            Text(emptyStateText)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(filteredRows) { row in
                            Button {
                                detailRow = row
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(row.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(row.statusLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(row.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(row.dateLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Детали", systemImage: "doc.text.magnifyingglass") {
                                    detailRow = row
                                }
                                Button("Разархивировать", systemImage: "tray.and.arrow.up") {
                                    pendingUnarchive = PendingUnarchive(id: row.id, tab: selectedTab)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    pendingUnarchive = PendingUnarchive(id: row.id, tab: selectedTab)
                                } label: {
                                    Label("Разархивировать", systemImage: "tray.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("Архив")
        .searchable(text: $searchText, prompt: "Поиск по названию, статусу, описанию")
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
        }
        .sheet(item: $detailRow) { row in
            NavigationStack {
                ScrollView {
                    Text(row.detailText)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .navigationTitle(row.title)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") {
                            detailRow = nil
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Восстановить из архива?",
            isPresented: Binding(
                get: { pendingUnarchive != nil },
                set: { if !$0 { pendingUnarchive = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isUnarchiving ? "Восстановление..." : "Разархивировать") {
                guard let pending = pendingUnarchive else { return }
                Task {
                    isUnarchiving = true
                    defer { isUnarchiving = false }
                    let ok = await viewModel.unarchive(id: pending.id, tab: pending.tab)
                    if ok {
                        pendingUnarchive = nil
                    }
                }
            }
            .disabled(isUnarchiving)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Запись вернётся в активный список.")
        }
    }

    private var currentRows: [ArchiveViewModel.Row] {
        switch selectedTab {
        case .tasks:
            return viewModel.tasks
        case .installations:
            return viewModel.installations
        case .avr:
            return viewModel.avr
        }
    }

    private var filteredRows: [ArchiveViewModel.Row] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return currentRows
        }
        return currentRows.filter { row in
            archiveSearchBlob(for: row).lowercased().contains(query)
        }
    }

    private func archiveSearchBlob(for row: ArchiveViewModel.Row) -> String {
        [row.title, row.subtitle, row.statusLabel, row.dateLabel, row.detailText].joined(separator: " ")
    }

    private var tasksTabTitle: String {
        "Задачи (\(viewModel.tasks.count))"
    }

    private var installationsTabTitle: String {
        "Монтажи (\(viewModel.installations.count))"
    }

    private var avrTabTitle: String {
        "AVR (\(viewModel.avr.count))"
    }

    private var emptyStateText: String {
        switch selectedTab {
        case .tasks:
            return "Нет архивных задач"
        case .installations:
            return "Нет архивных монтажей"
        case .avr:
            return "Нет архивных записей AVR"
        }
    }
}
