import SwiftUI

struct ArchiveView: View {
    private struct PendingUnarchive {
        let id: String
        let tab: ArchiveViewModel.Tab
    }

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ArchiveViewModel()
    @State private var selectedTab: ArchiveViewModel.Tab = .tasks
    @State private var detailRow: ArchiveViewModel.Row?
    @State private var pendingUnarchive: PendingUnarchive?
    @State private var isUnarchiving = false

    var body: some View {
        Group {
            if viewModel.isLoading && currentRows.isEmpty {
                ProgressView("Loading archive...")
            } else if let error = viewModel.errorText, currentRows.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                List {
                    Section {
                        Picker("Archive", selection: $selectedTab) {
                            Text(tasksTabTitle).tag(ArchiveViewModel.Tab.tasks)
                            Text(installationsTabTitle).tag(ArchiveViewModel.Tab.installations)
                            Text(avrTabTitle).tag(ArchiveViewModel.Tab.avr)
                        }
                        .pickerStyle(.segmented)
                    }

                    if currentRows.isEmpty {
                        Section {
                            Text(emptyStateText)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(currentRows) { row in
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
                                Button("Details", systemImage: "doc.text.magnifyingglass") {
                                    detailRow = row
                                }
                                Button("Unarchive", systemImage: "tray.and.arrow.up") {
                                    pendingUnarchive = PendingUnarchive(id: row.id, tab: selectedTab)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    pendingUnarchive = PendingUnarchive(id: row.id, tab: selectedTab)
                                } label: {
                                    Label("Unarchive", systemImage: "tray.and.arrow.up")
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
        .navigationTitle("Archive")
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
                        Button("Close") {
                            detailRow = nil
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Restore from archive?",
            isPresented: Binding(
                get: { pendingUnarchive != nil },
                set: { if !$0 { pendingUnarchive = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isUnarchiving ? "Restoring..." : "Unarchive") {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The record will return to the active list.")
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

    private var tasksTabTitle: String {
        "Tasks (\(viewModel.tasks.count))"
    }

    private var installationsTabTitle: String {
        "Installations (\(viewModel.installations.count))"
    }

    private var avrTabTitle: String {
        "AVR (\(viewModel.avr.count))"
    }

    private var emptyStateText: String {
        switch selectedTab {
        case .tasks:
            return "No archived tasks"
        case .installations:
            return "No archived installations"
        case .avr:
            return "No archived AVR records"
        }
    }
}
