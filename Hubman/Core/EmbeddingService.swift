import Foundation
import Supabase

struct EmbeddingMatch: Decodable {
    let id: UUID
    let distance: Double
}

struct EmbeddingService {
    private let client = SupabaseConfig.client

    func generateEmbedding(bublID: UUID, activityText: String) async throws {
        struct Payload: Encodable {
            let bubl_id: UUID
            let activity_text: String
        }

        _ = try await client.functions.invoke(
            "generate-embedding",
            options: FunctionInvokeOptions(
                body: Payload(bubl_id: bublID, activity_text: activityText)
            )
        )
    }

    func matchBubls(bublID: UUID, limit: Int = 12) async throws -> [EmbeddingMatch] {
        struct Params: Encodable {
            let query_bubl_id: UUID
            let match_count: Int
        }

        let rows: [EmbeddingMatch] = try await client
            .rpc(
                "match_bubls_by_embedding",
                params: Params(query_bubl_id: bublID, match_count: limit)
            )
            .execute()
            .value

        return rows
    }
}
