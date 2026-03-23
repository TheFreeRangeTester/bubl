import Foundation
import Observation

@Observable
final class PostViewModel {
    var step1Text: String = ""
    var step2Text: String = ""
    var isSubmitting = false
    var showCrisisPrompt = false
    var submitError: String?

    private let client = SupabaseConfig.client
    private let embeddingService = EmbeddingService()

    var canContinueStep1: Bool {
        step1Text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var canShare: Bool {
        canContinueStep1 && step2Text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    func trimLimits() {
        if step1Text.count > 140 {
            step1Text = String(step1Text.prefix(140))
        }
        if step2Text.count > 200 {
            step2Text = String(step2Text.prefix(200))
        }
    }

    func share(currentUserID: UUID, locale: String) async -> Bool {
        trimLimits()

        if crisisMatch(in: step2Text, locale: locale) {
            showCrisisPrompt = true
        }

        guard canShare else {
            submitError = String(localized: "post.validation")
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        struct NewBubl: Encodable {
            let user_id: UUID
            let activity_text: String
            let feeling_text: String
            let week_id: String
            let expires_at: Date
        }

        do {
            let payload = NewBubl(
                user_id: currentUserID,
                activity_text: step1Text.trimmingCharacters(in: .whitespacesAndNewlines),
                feeling_text: step2Text.trimmingCharacters(in: .whitespacesAndNewlines),
                week_id: WeekID.current(),
                expires_at: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
            )

            let bubl = try await client
                .from("bubls")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value as Bubl

            Task {
                try? await embeddingService.generateEmbedding(bublID: bubl.id, activityText: bubl.activityText)
            }

            submitError = nil
            return true
        } catch {
            submitError = String(localized: "post.error")
            return false
        }
    }

    private func crisisMatch(in text: String, locale: String) -> Bool {
        let dictionary: [String: [String]] = [
            "en": ["suicide", "kill myself", "hurt myself", "self harm", "can't go on"],
            "es": ["suicidio", "matarme", "hacerme daño", "autolesion", "no puedo seguir"],
            "pt": ["suicidio", "me matar", "machucar", "autoagressao", "nao aguento"]
        ]

        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let words = dictionary[locale] ?? dictionary["en"] ?? []
        return words.contains { normalized.contains($0) }
    }
}
