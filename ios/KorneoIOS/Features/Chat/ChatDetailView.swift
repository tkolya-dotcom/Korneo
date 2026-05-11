import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatDetailView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatDetailViewModel
    let chatName: String

    @State private var reactionTarget: Message?
    @State private var pendingDeleteMessage: Message?
    @State private var forwardMessageTarget: Message?
    @State private var showAttachmentImporter = false

    init(chatId: String, chatName: String, userId: String) {
        self.chatName = chatName
        _viewModel = StateObject(wrappedValue: ChatDetailViewModel(chatId: chatId, userId: userId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.typingUsersText.isEmpty {
                Text(viewModel.typingUsersText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }

            if viewModel.isLoading && viewModel.messages.isEmpty {
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else {
                List(viewModel.messages) { message in
                    messageCell(message)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                }
                .listStyle(.plain)
            }

            if let reply = viewModel.replyTarget {
                replyBar(reply)
            }

            Divider()
            HStack(spacing: 8) {
                Button {
                    showAttachmentImporter = true
                } label: {
                    Image(systemName: "paperclip")
                }
                TextField("Message", text: $viewModel.draftMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    Task { await viewModel.send() }
                }
                .disabled(viewModel.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)

            if let error = viewModel.errorText, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
            }
        }
        .navigationTitle(chatName)
        .task {
            viewModel.bind(client: appState.client)
            await viewModel.load()
            viewModel.startLiveUpdates()
        }
        .onDisappear {
            viewModel.stopLiveUpdates()
        }
        .onChange(of: viewModel.draftMessage) { _ in
            viewModel.draftDidChange()
        }
        .confirmationDialog(
            "Reaction",
            isPresented: Binding(
                get: { reactionTarget != nil },
                set: { if !$0 { reactionTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(["\u{1F44D}", "\u{2764}\u{FE0F}", "\u{1F525}", "\u{1F602}", "\u{1F62E}"], id: \.self) { emoji in
                Button(emoji) {
                    guard let target = reactionTarget else { return }
                    Task {
                        await viewModel.addReaction(message: target, emoji: emoji)
                        reactionTarget = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { reactionTarget = nil }
        }
        .confirmationDialog(
            "Delete message?",
            isPresented: Binding(
                get: { pendingDeleteMessage != nil },
                set: { if !$0 { pendingDeleteMessage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let target = pendingDeleteMessage else { return }
                Task {
                    await viewModel.deleteMessage(message: target)
                    pendingDeleteMessage = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteMessage = nil }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(
            isPresented: Binding(
                get: { forwardMessageTarget != nil },
                set: { if !$0 { forwardMessageTarget = nil } }
            )
        ) {
            NavigationStack {
                Group {
                    if viewModel.isLoadingForwardTargets {
                        ProgressView("Loading chats...")
                    } else if viewModel.forwardTargets.isEmpty {
                        ContentUnavailableView("No target chats", systemImage: "paperplane")
                    } else {
                        List(viewModel.forwardTargets) { chat in
                            Button {
                                guard let message = forwardMessageTarget else { return }
                                Task {
                                    let ok = await viewModel.forwardMessage(message, to: chat.id)
                                    if ok {
                                        forwardMessageTarget = nil
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.name ?? "Chat")
                                    Text(chat.type ?? "group")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Forward To")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            forwardMessageTarget = nil
                        }
                    }
                }
            }
            .task {
                await viewModel.loadForwardTargets()
            }
        }
        .fileImporter(
            isPresented: $showAttachmentImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                handleImportedFile(url)
            case .failure:
                break
            }
        }
    }

    @ViewBuilder
    private func messageCell(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let replyText = message.replyPreviewText {
                Text("-> \(replyText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let forwardedFrom = message.forwardedFromName {
                Text("Fwd: \(forwardedFrom)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(message.contentText.isEmpty ? "(empty)" : message.contentText)
            if let fileName = message.attachmentFileName {
                Text("File: \(fileName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let url = message.attachmentURL {
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }
            if !message.reactionsText.isEmpty {
                Text(message.reactionsText)
                    .font(.caption)
            }
            Text(shortTime(message.createdAt) ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reply") {
                viewModel.setReplyTarget(message)
            }
            Button("Reaction") {
                reactionTarget = message
            }
            Button("Forward") {
                forwardMessageTarget = message
            }
            Button("Copy") {
                UIPasteboard.general.string = message.contentText
            }
            if let url = message.attachmentURL, let link = URL(string: url) {
                Link("Open File", destination: link)
            }
            if viewModel.canDeleteMessage(message, role: appState.currentUser?.role) {
                Button("Delete", role: .destructive) {
                    pendingDeleteMessage = message
                }
            }
        }
    }

    private func replyBar(_ message: Message) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reply")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(previewText(for: message))
                    .font(.caption)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                viewModel.clearReply()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private func previewText(for message: Message) -> String {
        let text = message.contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count <= 70 { return text }
        return String(text.prefix(70)) + "..."
    }

    private func shortTime(_ raw: String?) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM HH:mm"
        return out.string(from: date)
    }

    private func handleImportedFile(_ url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent.isEmpty ? "file" : url.lastPathComponent
            let mimeType = mimeTypeForFile(url: url)
            Task { _ = await viewModel.sendAttachment(fileName: fileName, mimeType: mimeType, data: data) }
        } catch {
            // Ignore file read errors in UI layer; ViewModel will keep previous error state.
        }
    }

    private func mimeTypeForFile(url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let preferred = type.preferredMIMEType {
            return preferred
        }
        return "application/octet-stream"
    }
}
