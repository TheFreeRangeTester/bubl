import Foundation

struct Bubl: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let activityText: String
    let feelingText: String
    let clusterLabel: String?
    let weekID: String
    let createdAt: Date
    let expiresAt: Date
    let isActive: Bool
    let isFlagged: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case activityText = "activity_text"
        case feelingText = "feeling_text"
        case clusterLabel = "cluster_label"
        case weekID = "week_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case isFlagged = "is_flagged"
    }
}
