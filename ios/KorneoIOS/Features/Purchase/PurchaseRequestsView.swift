import SwiftUI

struct PurchaseRequestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PurchaseRequestsViewModel()
    @State private var showCreateSheet = false
    @State private var pendingDeleteItem: PurchaseRequest?
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView("Loading purchase requests...")
                } else if let error = viewModel.errorText, viewModel.items.isEmpty {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(viewModel.items) { item in
                        NavigationLink {
                            PurchaseRequestDetailView(viewModel: viewModel, item: item)
                                .environmentObject(appState)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayTitle(for: item))
                                    .font(.headline)
                                Text(item.status ?? "new")
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
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
            .navigationTitle("Purchase Requests")
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
            "Delete request?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(isDeleting ? "Deleting..." : "Delete", role: .destructive) {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
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
            return "Request #\(shortId)"
        }
        return "Request #\(item.id.prefix(8))"
    }
}
