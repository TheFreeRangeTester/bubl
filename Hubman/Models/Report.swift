import Foundation

struct ReportPayload: Codable {
    let reporterUserID: UUID
    let reportedBublID: UUID?
    let reportedReactionID: UUID?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterUserID = "reporter_user_id"
        case reportedBublID = "reported_bubl_id"
        case reportedReactionID = "reported_reaction_id"
        case reason
    }
}
