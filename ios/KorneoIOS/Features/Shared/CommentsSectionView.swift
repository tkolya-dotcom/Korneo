import SwiftUI

struct CommentsSectionView: View {
    let entityType: String
    let entityId: String
    let currentUserId: String?
    let client: SupabaseClient

    @State private var comments: [EntityComment] = []
    @State private var draftText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading && comments.isEmpty {
                ProgressView("Загрузка комментариев...")
            } else if comments.isEmpty {
                Text("Пока нет комментариев")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comments) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.displayAuthor)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(shortDate(row.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(row.displayText.isEmpty ? "-" : row.displayText)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Добавить комментарий...", text: $draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            Button(isSaving ? "Отправка..." : "Отправить комментарий") {
                Task { await sendComment() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || trimmedDraft.isEmpty)
        }
        .task(id: entityId) {
            await loadComments()
        }
        .refreshable {
            await loadComments()
        }
    }

    private var trimmedDraft: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }
        do {
            comments = try await client.fetchComments(entityType: entityType, entityId: entityId)
            errorText = nil
        } catch {
            errorText = "Не удалось загрузить комментарии"
        }
    }

    private func sendComment() async {
        let text = trimmedDraft
        guard !text.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await client.addComment(
                entityType: entityType,
                entityId: entityId,
                content: text,
                userId: currentUserId
            )
            draftText = ""
            await loadComments()
            errorText = nil
        } catch {
            errorText = "Не удалось отправить комментарий"
        }
    }

    private func shortDate(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return raw }
        let out = DateFormatter()
        out.locale = Locale(identifier: "ru_RU")
        out.dateFormat = "dd.MM.yyyy HH:mm"
        return out.string(from: date)
    }
}
