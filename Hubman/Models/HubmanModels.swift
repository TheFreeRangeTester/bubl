import Foundation

enum BublCategory: String, CaseIterable, Identifiable, Codable {
    case work
    case study
    case health
    case relationships
    case creativity
    case hobbies
    case life

    var id: String { rawValue }

    var title: String {
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"
        return switch self {
        case .work: isSpanish ? "Trabajo" : "Work"
        case .study: isSpanish ? "Estudio" : "Study"
        case .health: isSpanish ? "Salud" : "Health"
        case .relationships: isSpanish ? "Relaciones" : "Relationships"
        case .creativity: isSpanish ? "Creatividad" : "Creativity"
        case .hobbies: isSpanish ? "Hobbies" : "Hobbies"
        case .life: isSpanish ? "Vida personal" : "Life"
        }
    }

    var subtitle: String {
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"
        return switch self {
        case .work: isSpanish ? "Laburo, proyectos, foco, cansancio" : "Work, projects, focus, burnout"
        case .study: isSpanish ? "Aprender, practicar, rendir, volver a intentar" : "Learning, practice, exams, trying again"
        case .health: isSpanish ? "Energía, descanso, cuerpo, hábitos" : "Energy, rest, body, habits"
        case .relationships: isSpanish ? "Pareja, familia, amistades, vínculos" : "Partner, family, friends, connection"
        case .creativity: isSpanish ? "Escribir, diseñar, tocar, crear algo" : "Writing, design, making, creating"
        case .hobbies: isSpanish ? "Juegos, música, cocina, deporte, intereses" : "Games, music, food, sports, interests"
        case .life: isSpanish ? "Cambios, orden, decisiones, semana en general" : "Changes, routines, decisions, life stuff"
        }
    }

    var fallbackOrder: [BublCategory] {
        switch self {
        case .work: [.life, .study]
        case .study: [.work, .life]
        case .health: [.life, .relationships]
        case .relationships: [.life, .health]
        case .creativity: [.hobbies, .life]
        case .hobbies: [.creativity, .life]
        case .life: [.work, .relationships, .health]
        }
    }
}

enum ReactionKind: String, CaseIterable, Identifiable, Codable {
    case sameHere = "same_here"
    case iGetIt = "i_get_it"
    case beenThere = "been_there"
    case rootingForYou = "rooting_for_you"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sameHere: "Yo tambien"
        case .iGetIt: "Te entiendo"
        case .beenThere: "Me paso"
        case .rootingForYou: "Estoy con vos"
        }
    }
}

struct Bubl: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let activityText: String
    let feelingText: String
    let categoryID: String?
    let subcategoryID: String?
    let topicID: String?
    let languageCode: String?
    let clusterLabel: String?
    let weekID: String
    let createdAt: Date
    let expiresAt: Date
    let isActive: Bool
    let isFlagged: Bool

    var category: BublCategory {
        if let categoryID, let category = BublCategory(rawValue: categoryID) {
            return category
        }
        guard let legacySubcategory = subcategoryID ?? clusterLabel else { return .life }

        if legacySubcategory.hasPrefix("work_") || legacySubcategory == "work" {
            return .work
        }
        if legacySubcategory.hasPrefix("study_") || legacySubcategory == "learning" {
            return .study
        }
        if legacySubcategory.hasPrefix("health_") || legacySubcategory == "health" || legacySubcategory == "fitness" {
            return .health
        }
        if legacySubcategory.hasPrefix("relationships_") || legacySubcategory == "relationships" {
            return .relationships
        }
        if legacySubcategory.hasPrefix("creativity_") || legacySubcategory == "creativity" {
            return .creativity
        }
        if ["gaming", "music", "food", "sports", "reading", "hobbies_other"].contains(legacySubcategory) {
            return .hobbies
        }
        if legacySubcategory.hasPrefix("life_") || legacySubcategory == "travel" {
            return .life
        }

        return .life
    }

    var canonicalSubcategoryID: String? {
        subcategoryID ?? clusterLabel
    }

    var canonicalTopicID: String? {
        topicID
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case activityText = "activity_text"
        case feelingText = "feeling_text"
        case categoryID = "category_id"
        case subcategoryID = "subcategory_id"
        case topicID = "topic_id"
        case languageCode = "language_code"
        case clusterLabel = "cluster_label"
        case weekID = "week_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case isFlagged = "is_flagged"
    }
}

struct Reaction: Identifiable, Codable, Hashable {
    let id: UUID
    let bublID: UUID
    let userID: UUID
    let type: String?
    let createdAt: Date

    var kind: ReactionKind? {
        guard let type else { return nil }
        return ReactionKind(rawValue: type)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bublID = "bubl_id"
        case userID = "user_id"
        case type
        case createdAt = "created_at"
    }
}

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
