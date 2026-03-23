import Foundation

struct Reaction: Identifiable, Codable, Hashable {
    let id: UUID
    let bublID: UUID
    let userID: UUID
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case bublID = "bubl_id"
        case userID = "user_id"
        case text
        case createdAt = "created_at"
    }
}
