import Foundation
import Observation

@Observable
final class ReactionsViewModel {
    private let client = SupabaseConfig.client

    var reactions: [Reaction] = []
    var draft: String = ""
    var isLoading = false
    var errorMessage: String?

    func load(bublID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            reactions = try await client
                .from("reactions")
                .select()
                .eq("bubl_id", value: bublID)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = String(localized: "reactions.error")
        }
    }

    func submit(bublID: UUID, userID: UUID) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = String(trimmed.prefix(120))

        struct NewReaction: Encodable {
            let bubl_id: UUID
            let user_id: UUID
            let text: String
        }

        do {
            _ = try await client
                .from("reactions")
                .insert(NewReaction(bubl_id: bublID, user_id: userID, text: draft))
                .execute()
            draft = ""
            await load(bublID: bublID)
        } catch {
            errorMessage = String(localized: "reactions.error")
        }
    }
}
