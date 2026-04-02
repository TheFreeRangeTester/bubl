import CryptoKit
import Foundation
import Observation
import OSLog
import Supabase

enum SupabaseConfig {
    private static let fallbackURL = "https://example.supabase.co"
    private static let urlOverrideKey = "dev.supabase.url"
    private static let anonOverrideKey = "dev.supabase.anon"

    static func saveOverrides(url: String, anonKey: String) {
        UserDefaults.standard.set(url, forKey: urlOverrideKey)
        UserDefaults.standard.set(anonKey, forKey: anonOverrideKey)
    }

    static func clearOverrides() {
        UserDefaults.standard.removeObject(forKey: urlOverrideKey)
        UserDefaults.standard.removeObject(forKey: anonOverrideKey)
    }

    static var runtimeURL: String {
        let override = UserDefaults.standard.string(forKey: urlOverrideKey) ?? ""
        if !override.isEmpty { return override }
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? ""
        return bundled
    }

    static var runtimeAnonKey: String {
        let override = UserDefaults.standard.string(forKey: anonOverrideKey) ?? ""
        if !override.isEmpty { return override }
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
        return bundled
    }

    static var client: SupabaseClient {
        let urlString = runtimeURL
        let anonKey = runtimeAnonKey
        let url = URL(string: urlString) ?? URL(string: fallbackURL)!
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    static var diagnostics: String {
        let trimmedURL = runtimeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = runtimeAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = URL(string: trimmedURL)?.host ?? "invalid"
        return "host=\(host) anon_len=\(trimmedKey.count)"
    }
}

enum WeekID {
    static func current(for date: Date = .now) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-%02d", year, week)
    }
}

enum BublGuardrails {
    static let blockedPatterns: [(Regex<Substring>, String)] = [
        (/#\w+/, "No compartas redes sociales o usernames."),
        (/(?i)\b(?:https?:\/\/|www\.)\S+/, "No compartas links."),
        (/(?i)\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b/, "No compartas emails."),
        (/(?x)\b(?:\+?\d[\d\s\-\(\)]{7,}\d)\b/, "No compartas telefonos.")
    ]

    static let crisisKeywords = [
        "suicidio", "matarme", "hacerme dano", "autolesion", "no puedo seguir",
        "suicide", "kill myself", "hurt myself", "self harm", "can't go on"
    ]

    static func validationError(activity: String, feeling: String) -> String? {
        let combined = "\(activity)\n\(feeling)"
        for (pattern, message) in blockedPatterns {
            if combined.contains(pattern) {
                return message
            }
        }
        return nil
    }

    static func containsCrisisLanguage(_ text: String) -> Bool {
        let normalized = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return crisisKeywords.contains { normalized.contains($0) }
    }
}

struct LegacyCategoryMapping {
    let clusterLabel: String
    let action: String
    let topic: String
    let tags: [String]
}

enum BublTopicInference {
    static func rankingTokens(activity: String, feeling: String) -> Set<String> {
        let stopwords: Set<String> = [
            "the", "and", "for", "this", "that", "with", "from", "because", "about", "after",
            "como", "para", "porque", "este", "esta", "estas", "estos", "muy", "pero", "ando",
            "week", "monthly", "latest", "listening", "building", "trying", "playing", "going",
            "album", "albums", "music", "songs", "song"
        ]

        let combined = normalizedText("\(activity) \(feeling)")
        let tokens = combined
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
            .map { $0.lowercased() }
            .filter { !stopwords.contains($0) }

        return Set(tokens)
    }

    static func inferredTopic(tokens: Set<String>, cluster: String?, text: String? = nil) -> String? {
        let normalized = text ?? tokens.joined(separator: " ")

        switch cluster {
        case "music":
            if containsAny(in: normalized, phrases: [
                "guitarra", "guitar", "piano", "violin", "violín", "bateria", "batería",
                "bajo", "acordes", "riff", "ensayando", "ensayo", "practicando",
                "practicar", "practice", "practicing", "volver a tocar"
            ]) { return "learning_instrument" }
            if containsAny(in: normalized, phrases: ["concert", "show", "gig", "festival", "tour", "recital"]) { return "live_shows" }
            if containsAny(in: normalized, phrases: ["playlist", "playlists", "album", "albums", "discography"]) { return "playlists" }
            if containsAny(in: normalized, phrases: ["band", "artist", "latest", "song", "songs"]) { return "artist_fandom" }
            return "general_music"
        case let value? where value.hasPrefix("work_"):
            if containsAny(in: normalized, phrases: ["review", "evaluation", "evaluacion", "evaluación", "feedback", "promotion", "performance"]) { return "reviews_feedback" }
            if containsAny(in: normalized, phrases: ["meeting", "meetings", "reunion", "reuniones", "slack", "focus", "foco", "drenado", "agotado", "burnout"]) { return "burnout_signals" }
            if containsAny(in: normalized, phrases: ["interview", "entrevista", "cv", "linkedin", "rechazo", "rechazos", "busqueda", "búsqueda"]) { return "job_search" }
            if containsAny(in: normalized, phrases: ["app", "project", "proyecto", "launch", "version", "onboarding"]) { return "building_projects" }
        case let value? where value.hasPrefix("study_"):
            if containsAny(in: normalized, phrases: ["exam", "final", "finales", "parcial"]) { return "exams" }
            if containsAny(in: normalized, phrases: ["course", "curso", "typescript", "skill", "practicar"]) { return "skills_learning" }
            if containsAny(in: normalized, phrases: ["campus", "facu", "universidad", "entregas", "grupal"]) { return "university_routine" }
            if containsAny(in: normalized, phrases: ["idioma", "english", "ingles", "inglés", "flashcards", "nativo"]) { return "language_practice" }
        case let value? where value.hasPrefix("health_"):
            if containsAny(in: normalized, phrases: ["gym", "gimnasio", "running", "correr", "workout", "rutina"]) { return "exercise_routine" }
            if containsAny(in: normalized, phrases: ["sleep", "dormir", "insomnia", "siesta", "celular", "midnight"]) { return "sleep_routine" }
            if containsAny(in: normalized, phrases: ["comida", "alimentacion", "alimentación", "nutrition", "meal"]) { return "nutrition" }
            if containsAny(in: normalized, phrases: ["anxiety", "ansiedad", "mental", "therapy", "terapia"]) { return "mental_health" }
        case let value? where value.hasPrefix("relationships_"):
            if containsAny(in: normalized, phrases: ["pareja", "partner", "charla", "distance", "distancia"]) { return "partner_connection" }
            if containsAny(in: normalized, phrases: ["viejos", "familia", "hermano", "familiar"]) { return "family_ties" }
            if containsAny(in: normalized, phrases: ["amiga", "amigo", "friends", "grupo"]) { return "friendship_dynamics" }
            if containsAny(in: normalized, phrases: ["ex", "cortar", "corte", "duelo", "soltando"]) { return "breakup_processing" }
        case let value? where value.hasPrefix("creativity_"):
            if containsAny(in: normalized, phrases: ["escrib", "texto", "draft", "borrador"]) { return "writing_process" }
            if containsAny(in: normalized, phrases: ["design", "portfolio", "visual", "feedback"]) { return "design_direction" }
            if containsAny(in: normalized, phrases: ["draw", "dibujo", "ilustracion", "ilustración", "sketch"]) { return "drawing_practice" }
            if containsAny(in: normalized, phrases: [
                "guitarra", "guitar", "piano", "violin", "violín", "bateria", "batería",
                "demo", "song", "cancion", "canción", "componer", "componiendo",
                "ensayando", "ensayo", "acordes", "riff", "practicando", "practice"
            ]) { return "music_creation" }
        case let value? where value.hasPrefix("life_"):
            if containsAny(in: normalized, phrases: ["mudo", "mudanza", "empacar", "casa"]) { return "moving_transition" }
            if containsAny(in: normalized, phrases: ["ordenar", "rutina", "cleanup", "organizar"]) { return "organization_reset" }
            if containsAny(in: normalized, phrases: ["plata", "gastos", "ahorrar", "finanzas"]) { return "financial_pressure" }
            if containsAny(in: normalized, phrases: ["decision", "decidir", "dije que no", "next step"]) { return "decision_weight" }
        case "gaming":
            if containsAny(in: normalized, phrases: ["resident evil", "survival horror", "horror"]) { return "survival_horror" }
            if containsAny(in: normalized, phrases: ["stardew", "animal crossing", "cozy"]) { return "cozy_games" }
            if containsAny(in: normalized, phrases: ["volvi", "volví", "saga", "years", "años"]) { return "old_favorite" }
        case "food":
            if containsAny(in: normalized, phrases: ["cocinar", "cooking", "receta", "recipes"]) { return "home_cooking" }
            if containsAny(in: normalized, phrases: ["horno", "bake", "baking"]) { return "baking" }
            if containsAny(in: normalized, phrases: ["ramen", "lugar", "place", "restaurant"]) { return "trying_places" }
        case "sports":
            if containsAny(in: normalized, phrases: ["partido", "match", "jugué", "jugue"]) { return "playing_match" }
            if containsAny(in: normalized, phrases: ["equipo", "team", "resultado"]) { return "watching_team" }
            if containsAny(in: normalized, phrases: ["nuevo deporte", "sport", "principiante"]) { return "learning_sport" }
        case "reading":
            if containsAny(in: normalized, phrases: ["novela", "novel"]) { return "novel_reading" }
            if containsAny(in: normalized, phrases: ["essay", "ensayo", "subray"]) { return "nonfiction_reading" }
            if containsAny(in: normalized, phrases: ["libros", "books", "engancharme"]) { return "reading_slump" }
        default:
            break
        }

        return cluster
    }

    static func normalizedText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func containsAny(in text: String, phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }
}

struct LegacyEmbeddingService {
    private let client = SupabaseConfig.client

    struct Match: Decodable {
        let id: UUID
        let distance: Double
    }

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

    func matchBubls(bublID: UUID, limit: Int = 12) async throws -> [Match] {
        struct Params: Encodable {
            let query_bubl_id: UUID
            let match_count: Int
        }

        let rows: [Match] = try await client
            .rpc(
                "match_bubls_by_embedding",
                params: Params(query_bubl_id: bublID, match_count: limit)
            )
            .execute()
            .value

        return rows
    }
}

enum BublSubcategory: String, CaseIterable, Identifiable {
    case workCareer = "work_career"
    case workBurnout = "work_burnout"
    case workJobSearch = "work_job_search"
    case workSideProjects = "work_side_projects"
    case studyExams = "study_exams"
    case studySkills = "study_skills"
    case studyUniversity = "study_university"
    case studyLanguages = "study_languages"
    case healthExercise = "health_exercise"
    case healthSleep = "health_sleep"
    case healthNutrition = "health_nutrition"
    case healthMental = "health_mental"
    case relationshipsPartner = "relationships_partner"
    case relationshipsFamily = "relationships_family"
    case relationshipsFriends = "relationships_friends"
    case relationshipsBreakups = "relationships_breakups"
    case creativityWriting = "creativity_writing"
    case creativityDesign = "creativity_design"
    case creativityDrawing = "creativity_drawing"
    case creativityMusic = "creativity_music"
    case hobbiesMusic = "music"
    case hobbiesGaming = "gaming"
    case hobbiesFood = "food"
    case hobbiesSports = "sports"
    case hobbiesReading = "reading"
    case hobbiesOther = "hobbies_other"
    case lifeMoving = "life_moving"
    case lifeOrganization = "life_organization"
    case lifeFinances = "life_finances"
    case lifeDecisions = "life_decisions"

    var id: String { rawValue }

    var category: BublCategory {
        switch self {
        case .workCareer, .workBurnout, .workJobSearch, .workSideProjects: .work
        case .studyExams, .studySkills, .studyUniversity, .studyLanguages: .study
        case .healthExercise, .healthSleep, .healthNutrition, .healthMental: .health
        case .relationshipsPartner, .relationshipsFamily, .relationshipsFriends, .relationshipsBreakups: .relationships
        case .creativityWriting, .creativityDesign, .creativityDrawing, .creativityMusic: .creativity
        case .hobbiesMusic, .hobbiesGaming, .hobbiesFood, .hobbiesSports, .hobbiesReading, .hobbiesOther: .hobbies
        case .lifeMoving, .lifeOrganization, .lifeFinances, .lifeDecisions: .life
        }
    }

    var title: String {
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"
        return switch self {
        case .workCareer: isSpanish ? "Carrera" : "Career"
        case .workBurnout: "Burnout"
        case .workJobSearch: isSpanish ? "Búsqueda laboral" : "Job search"
        case .workSideProjects: isSpanish ? "Side project" : "Side project"
        case .studyExams: isSpanish ? "Exámenes" : "Exams"
        case .studySkills: isSpanish ? "Aprender skill" : "Skills"
        case .studyUniversity: isSpanish ? "Facu" : "University"
        case .studyLanguages: isSpanish ? "Idiomas" : "Languages"
        case .healthExercise: isSpanish ? "Ejercicio" : "Exercise"
        case .healthSleep: isSpanish ? "Sueño" : "Sleep"
        case .healthNutrition: isSpanish ? "Alimentación" : "Nutrition"
        case .healthMental: isSpanish ? "Salud mental" : "Mental health"
        case .relationshipsPartner: isSpanish ? "Pareja" : "Partner"
        case .relationshipsFamily: isSpanish ? "Familia" : "Family"
        case .relationshipsFriends: isSpanish ? "Amistades" : "Friends"
        case .relationshipsBreakups: isSpanish ? "Ruptura o duelo" : "Breakup or grief"
        case .creativityWriting: isSpanish ? "Escritura" : "Writing"
        case .creativityDesign: isSpanish ? "Diseño" : "Design"
        case .creativityDrawing: isSpanish ? "Dibujo" : "Drawing"
        case .creativityMusic: isSpanish ? "Música" : "Music"
        case .hobbiesMusic: isSpanish ? "Música" : "Music"
        case .hobbiesGaming: "Gaming"
        case .hobbiesFood: isSpanish ? "Comida" : "Food"
        case .hobbiesSports: isSpanish ? "Deporte" : "Sports"
        case .hobbiesReading: isSpanish ? "Lectura" : "Reading"
        case .hobbiesOther: isSpanish ? "Otro" : "Other"
        case .lifeMoving: isSpanish ? "Mudanza" : "Moving"
        case .lifeOrganization: isSpanish ? "Organización" : "Organization"
        case .lifeFinances: isSpanish ? "Finanzas" : "Finances"
        case .lifeDecisions: isSpanish ? "Decisiones" : "Decisions"
        }
        }

    var clusterLabel: String { rawValue }

    var legacyTopic: String {
        switch self {
        case .workCareer: "career"
        case .workBurnout: "burnout"
        case .workJobSearch: "job_search"
        case .workSideProjects: "side_projects"
        case .studyExams: "exams"
        case .studySkills: "learning"
        case .studyUniversity: "university"
        case .studyLanguages: "languages"
        case .healthExercise: "exercise"
        case .healthSleep: "sleep"
        case .healthNutrition: "nutrition"
        case .healthMental: "mental_health"
        case .relationshipsPartner: "partner"
        case .relationshipsFamily: "family"
        case .relationshipsFriends: "friends"
        case .relationshipsBreakups: "breakups"
        case .creativityWriting: "writing"
        case .creativityDesign: "design"
        case .creativityDrawing: "drawing"
        case .creativityMusic: "music_creation"
        case .hobbiesMusic: "music"
        case .hobbiesGaming: "gaming"
        case .hobbiesFood: "food"
        case .hobbiesSports: "sports"
        case .hobbiesReading: "reading"
        case .hobbiesOther: "hobbies"
        case .lifeMoving: "moving"
        case .lifeOrganization: "organization"
        case .lifeFinances: "finances"
        case .lifeDecisions: "decisions"
        }
    }

    var legacyTags: [String] {
        [category.rawValue, legacyTopic]
    }

    static func options(for category: BublCategory) -> [BublSubcategory] {
        allCases.filter { $0.category == category }
    }

    static func defaultOption(for category: BublCategory) -> BublSubcategory {
        options(for: category).first!
    }
}

extension BublCategory {
    func legacyMapping(subcategory: BublSubcategory?) -> LegacyCategoryMapping {
        let selectedSubcategory: BublSubcategory = (subcategory?.category == self ? subcategory : nil)
            ?? BublSubcategory.defaultOption(for: self)
        let action: String

        switch self {
        case .work: action = "working_on"
        case .study: action = "learning"
        case .health, .relationships: action = "caring"
        case .creativity: action = "creating"
        case .hobbies, .life: action = "other"
        }

        return LegacyCategoryMapping(
            clusterLabel: selectedSubcategory.clusterLabel,
            action: action,
            topic: selectedSubcategory.legacyTopic,
            tags: selectedSubcategory.legacyTags
        )
    }
}

@Observable
final class AuthManager {
    enum DevAuthError: LocalizedError {
        case missingURL
        case invalidURL(String)
        case missingAnonKey
        case signInFailed(String)
        case bootstrapFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingURL:
                return "Supabase URL is empty."
            case .invalidURL(let value):
                return "Supabase URL is invalid: \(value)"
            case .missingAnonKey:
                return "Supabase ANON key is empty."
            case .signInFailed(let details):
                return "Anonymous auth failed. \(details)"
            case .bootstrapFailed(let details):
                return "Anonymous auth succeeded, but bootstrap failed. \(details)"
            }
        }
    }

    enum State {
        case loading
        case signedOut
        case signedIn
    }

    private(set) var state: State = .loading
    private(set) var session: Session?
    private(set) var userLocale: String = Locale.current.language.languageCode?.identifier ?? "en"

    private var client: SupabaseClient { SupabaseConfig.client }
    #if targetEnvironment(simulator)
    private let allowDevBypass = true
    #else
    private let allowDevBypass = false
    #endif

    func restoreSession() async {
        do {
            let current = try await client.auth.session
            if current.isExpired {
                state = .signedOut
                return
            }

            session = current
            state = .signedIn
            try await bootstrapUserIfNeeded(userID: current.user.id)
        } catch {
            if allowDevBypass {
                do {
                    try await signInAnonymouslyForDevelopment()
                } catch {
                    state = .signedOut
                }
            } else {
                state = .signedOut
            }
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Ignore sign out errors and clear local state anyway.
        }
        session = nil
        state = .signedOut
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let newSession = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        session = newSession
        state = .signedIn
        try await bootstrapUserIfNeeded(userID: newSession.user.id)
    }

    func signInAnonymouslyForDevelopment() async throws {
        let urlString = SupabaseConfig.runtimeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let anonKey = SupabaseConfig.runtimeAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !urlString.isEmpty else {
            throw DevAuthError.missingURL
        }
        guard URL(string: urlString)?.scheme != nil else {
            throw DevAuthError.invalidURL(urlString)
        }
        guard !anonKey.isEmpty else {
            throw DevAuthError.missingAnonKey
        }

        do {
            let newSession = try await client.auth.signInAnonymously()
            session = newSession
            state = .signedIn

            do {
                try await bootstrapUserIfNeeded(userID: newSession.user.id)
            } catch {
                throw DevAuthError.bootstrapFailed(error.localizedDescription)
            }
        } catch let error as DevAuthError {
            throw error
        } catch {
            throw DevAuthError.signInFailed(error.localizedDescription)
        }
    }

    func bootstrapUserIfNeeded(userID: UUID) async throws {
        struct UserUpsert: Encodable {
            let id: UUID
            let locale: String
        }

        let locale = Locale.current.language.languageCode?.identifier ?? "en"
        userLocale = locale

        _ = try await client
            .from("users")
            .upsert(UserUpsert(id: userID, locale: locale))
            .execute()
    }

    func makeNonce() -> String {
        let bytes: [UInt8] = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
    }

    func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

@Observable
final class PostViewModel {
    private struct ClassificationResolution {
        let category: BublCategory
        let subcategory: BublSubcategory
    }

    enum ActivityPreset: String, CaseIterable, Identifiable {
        case listening
        case reading
        case playing
        case watching
        case doing
        case learning
        case practicing
        case creating
        case workingOn
        case training
        case cooking
        case goingThrough

        var id: String { rawValue }

        private var isSpanish: Bool {
            Locale.current.language.languageCode?.identifier == "es"
        }

        var label: String {
            switch self {
            case .listening: return isSpanish ? "escuchando" : "listening to"
            case .reading: return isSpanish ? "leyendo" : "reading"
            case .playing: return isSpanish ? "jugando" : "playing"
            case .watching: return isSpanish ? "mirando" : "watching"
            case .doing: return isSpanish ? "haciendo" : "doing"
            case .learning: return isSpanish ? "aprendiendo" : "learning"
            case .practicing: return isSpanish ? "practicando" : "practicing"
            case .creating: return isSpanish ? "creando" : "creating"
            case .workingOn: return isSpanish ? "trabajando en" : "working on"
            case .training: return isSpanish ? "entrenando" : "training"
            case .cooking: return isSpanish ? "cocinando" : "cooking"
            case .goingThrough: return isSpanish ? "atravesando" : "going through"
            }
        }

        var promptLabel: String {
            switch self {
            case .listening: return isSpanish ? "escuchar" : "listening to"
            case .reading: return isSpanish ? "leer" : "reading"
            case .playing: return isSpanish ? "jugar" : "playing"
            case .watching: return isSpanish ? "ver" : "watching"
            case .doing: return isSpanish ? "hacer" : "doing"
            case .learning: return isSpanish ? "aprender" : "learning"
            case .practicing: return isSpanish ? "practicar" : "practicing"
            case .creating: return isSpanish ? "crear" : "creating"
            case .workingOn: return isSpanish ? "estar con" : "working on"
            case .training: return isSpanish ? "entrenar" : "training"
            case .cooking: return isSpanish ? "cocinar" : "cooking"
            case .goingThrough: return isSpanish ? "estar en" : "going through"
            }
        }

        var suggestedSubcategory: BublSubcategory {
            switch self {
            case .listening: return .hobbiesMusic
            case .reading: return .hobbiesReading
            case .playing: return .hobbiesGaming
            case .watching: return .hobbiesOther
            case .doing: return .lifeOrganization
            case .learning: return .studySkills
            case .practicing: return .creativityMusic
            case .creating: return .creativityDesign
            case .workingOn: return .workSideProjects
            case .training: return .healthExercise
            case .cooking: return .hobbiesFood
            case .goingThrough: return .lifeDecisions
            }
        }
    }

    var selectedPreset: ActivityPreset?
    var step1Text: String = ""
    var step2Text: String = ""
    var selectedCategory: BublCategory = .life
    var selectedSubcategory: BublSubcategory = .lifeMoving
    var isSubmitting = false
    var showCrisisPrompt = false
    var submitError: String?

    private var client: SupabaseClient { SupabaseConfig.client }
    private let embeddingService = LegacyEmbeddingService()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bubl",
        category: "EmbeddingGeneration"
    )

    var canContinueStep1: Bool {
        selectedPreset != nil && step1Text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var canContinueStep2: Bool {
        step2Text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var canShare: Bool {
        canContinueStep1 && canContinueStep2
    }

    func trimLimits() {
        if step1Text.count > 100 {
            step1Text = String(step1Text.prefix(100))
        }
        if step2Text.count > 220 {
            step2Text = String(step2Text.prefix(220))
        }
    }

    var composedActivityText: String {
        let detail = step1Text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedPreset else { return detail }
        guard !detail.isEmpty else { return selectedPreset.label }
        return "\(selectedPreset.label) \(detail)"
    }

    var opinionPrompt: String {
        let detail = composedActivityText
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"

        guard !detail.isEmpty else {
            return isSpanish
                ? "¿Y? ¿Qué opinás sobre eso?"
                : "And? How do you feel about that?"
        }

        return isSpanish
            ? "¿Y? ¿Qué opinás sobre estar \(detail)?"
            : "And? How do you feel about \(detail)?"
    }

    var matchingPrompt: String {
        let detail = composedActivityText
        let isSpanish = Locale.current.language.languageCode?.identifier == "es"

        guard !detail.isEmpty else {
            return isSpanish
                ? "Estamos reuniendo voces que estén en algo parecido a lo que compartiste."
                : "We're gathering voices that are in something similar to what you shared."
        }

        return isSpanish
            ? "Estamos armando una burbuja alrededor de \(detail), con gente que esté en algo parecido esta semana."
            : "We're shaping a bubble around \(detail), with people in something similar this week."
    }

    func applyPreset(_ preset: ActivityPreset) {
        selectedPreset = preset
        selectedCategory = preset.suggestedSubcategory.category
        selectedSubcategory = preset.suggestedSubcategory
    }

    func share(currentUserID: UUID) async -> Bool {
        trimLimits()

        let activity = composedActivityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let feeling = step2Text.trimmingCharacters(in: .whitespacesAndNewlines)

        if BublGuardrails.containsCrisisLanguage(feeling) {
            showCrisisPrompt = true
        }

        guard canShare else {
            submitError = "Completá las dos partes antes de publicar."
            return false
        }

        if let validationError = BublGuardrails.validationError(activity: activity, feeling: feeling) {
            submitError = validationError
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        struct NewBubl: Encodable {
            let user_id: UUID
            let activity_text: String
            let feeling_text: String
            let category_id: String
            let subcategory_id: String
            let topic_id: String
            let language_code: String
            let cluster_label: String
            let week_id: String
            let expires_at: Date
        }

        struct LegacyBubl: Encodable {
            let user_id: UUID
            let activity_text: String
            let feeling_text: String
            let action: String
            let topic: String
            let tags: [String]
            let cluster_label: String
            let week_id: String
            let expires_at: Date
        }

        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        let initialSubcategory = selectedSubcategory.category == selectedCategory
            ? selectedSubcategory
            : BublSubcategory.defaultOption(for: selectedCategory)
        let resolvedClassification = resolveClassification(
            activity: activity,
            feeling: feeling,
            initialSubcategory: initialSubcategory
        )
        let selectedCategory = resolvedClassification.category
        let selectedSubcategory = resolvedClassification.subcategory
        let inferredTopicID = BublTopicInference.inferredTopic(
            tokens: BublTopicInference.rankingTokens(
                activity: activity,
                feeling: feeling
            ),
            cluster: selectedSubcategory.clusterLabel,
            text: BublTopicInference.normalizedText("\(activity) \(feeling)")
        ) ?? selectedSubcategory.legacyTopic
        let legacyMapping = selectedCategory.legacyMapping(subcategory: selectedSubcategory)

        do {
            do {
                let bubl = try await client
                    .from("bubls")
                    .insert(
                        NewBubl(
                            user_id: currentUserID,
                            activity_text: activity,
                            feeling_text: feeling,
                            category_id: selectedCategory.rawValue,
                            subcategory_id: selectedSubcategory.rawValue,
                            topic_id: inferredTopicID,
                            language_code: Locale.current.language.languageCode?.identifier ?? "en",
                            cluster_label: selectedSubcategory.clusterLabel,
                            week_id: WeekID.current(),
                            expires_at: expiresAt
                        )
                    )
                    .select()
                    .single()
                    .execute()
                    .value as Bubl

                do {
                    try await embeddingService.generateEmbedding(
                        bublID: bubl.id,
                        activityText: "\(activity)\n\(feeling)"
                    )
                    self.logEmbedding("Generated embedding for bubl=\(bubl.id.uuidString)")
                } catch {
                    self.logEmbedding("Failed to generate embedding for bubl=\(bubl.id.uuidString): \(error.localizedDescription)")
                }
            } catch {
                let bubl = try await client
                    .from("bubls")
                    .insert(
                        LegacyBubl(
                            user_id: currentUserID,
                            activity_text: activity,
                            feeling_text: feeling,
                            action: legacyMapping.action,
                            topic: legacyMapping.topic,
                            tags: legacyMapping.tags,
                            cluster_label: legacyMapping.clusterLabel,
                            week_id: WeekID.current(),
                            expires_at: expiresAt
                        )
                    )
                    .select()
                    .single()
                    .execute()
                    .value as Bubl

                do {
                    try await embeddingService.generateEmbedding(
                        bublID: bubl.id,
                        activityText: "\(activity)\n\(feeling)"
                    )
                    self.logEmbedding("Generated embedding for bubl=\(bubl.id.uuidString)")
                } catch {
                    self.logEmbedding("Failed to generate embedding for bubl=\(bubl.id.uuidString): \(error.localizedDescription)")
                }
            }

            submitError = nil
            return true
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("duplicate") || message.contains("unique") {
                submitError = "Ya publicaste esta semana. Esperá a la siguiente."
            } else {
                submitError = "No se pudo publicar. \(error.localizedDescription)"
            }
            return false
        }
    }

    private func logEmbedding(_ message: String) {
        logger.info("\(message, privacy: .public)")
        NSLog("[EmbeddingGeneration] %@", message)
        print("[EmbeddingGeneration] \(message)")
    }

    private func resolveClassification(activity: String, feeling: String, initialSubcategory: BublSubcategory) -> ClassificationResolution {
        let normalized = BublTopicInference.normalizedText("\(activity) \(feeling)")

        if containsAny(in: normalized, phrases: [
            "animal crossing", "stardew", "minecraft", "fortnite", "valorant", "league of legends",
            "zelda", "mario kart", "pokemon", "pokémon", "elden ring", "the sims", "sims",
            "videojuego", "videojuegos", "gaming", "gamer", "switch", "nintendo", "playstation",
            "xbox", "steam", "pc gaming", "cozy game", "cozy games"
        ]) {
            return ClassificationResolution(category: .hobbies, subcategory: .hobbiesGaming)
        }

        if containsAny(in: normalized, phrases: [
            "guitarra", "guitar", "piano", "violin", "violín", "bateria", "batería",
            "bajo", "ensayo", "band", "banda", "cancion", "canción", "songwriting",
            "componer", "componiendo", "improvisar", "riff", "acordes", "acordes"
        ]) {
            return ClassificationResolution(category: .creativity, subcategory: .creativityMusic)
        }

        if containsAny(in: normalized, phrases: [
            "idioma", "idiomas", "ingles", "inglés", "english", "frances", "francés",
            "portugues", "portugués", "japones", "japonés", "language exchange",
            "duolingo", "vocabulario", "grammar", "gramatica", "gramática"
        ]) {
            return ClassificationResolution(category: .study, subcategory: .studyLanguages)
        }

        if containsAny(in: normalized, phrases: [
            "dibujo", "dibujando", "drawing", "illustration", "ilustracion", "ilustración",
            "sketch", "croquis"
        ]) {
            return ClassificationResolution(category: .creativity, subcategory: .creativityDrawing)
        }

        if containsAny(in: normalized, phrases: [
            "diseno", "diseño", "design", "figma", "ux", "ui", "brand", "branding"
        ]) {
            return ClassificationResolution(category: .creativity, subcategory: .creativityDesign)
        }

        if containsAny(in: normalized, phrases: [
            "escribiendo", "escribir", "writing", "novela", "cuento", "poema", "poesía",
            "poesia", "essay", "ensayo"
        ]) {
            return ClassificationResolution(category: .creativity, subcategory: .creativityWriting)
        }

        if containsAny(in: normalized, phrases: [
            "partido", "partidos", "match", "torneo", "torneos", "tenis", "futbol", "fútbol",
            "basket", "basquet", "básquet", "golf", "surf", "paddle", "padel", "pádel"
        ]) {
            return ClassificationResolution(category: .hobbies, subcategory: .hobbiesSports)
        }

        if initialSubcategory == .healthExercise,
           containsAny(in: normalized, phrases: [
               "practicar", "practicando", "practice", "practicing", "volver a tocar",
               "volver a escribir", "volver a dibujar"
           ]) {
            if containsAny(in: normalized, phrases: ["guitarra", "guitar", "piano", "violin", "violín", "bateria", "batería"]) {
                return ClassificationResolution(category: .creativity, subcategory: .creativityMusic)
            }
        }

        return ClassificationResolution(category: initialSubcategory.category, subcategory: initialSubcategory)
    }

    private func containsAny(in text: String, phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }
}

@Observable
final class FeedViewModel {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bubl",
        category: "FeedSelection"
    )
    private var client: SupabaseClient { SupabaseConfig.client }

    var myBubl: Bubl?
    var feed: [Bubl] = []
    var isLoading = false
    var errorMessage: String?

    var hasPostedThisWeek: Bool { myBubl != nil }

    func refresh(currentUserID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let weekID = WeekID.current()

        log("Refreshing related bubls for user=\(currentUserID.uuidString) week=\(weekID)")

        do {
            try await loadLiveFeedViaRPC(currentUserID: currentUserID, weekID: weekID)
            errorMessage = nil
        } catch {
            log("RPC live feed failed; falling back to direct queries: \(error.localizedDescription)")

            do {
                try await loadLiveFeedFallback(currentUserID: currentUserID, weekID: weekID)
                errorMessage = nil
            } catch {
                log("Failed to refresh related bubls after fallback: \(error.localizedDescription)")
                errorMessage = "No pudimos cargar tu burbuja. \(error.localizedDescription)"
            }
        }
    }

    func deleteMyBublThisWeek(currentUserID: UUID) async {
        do {
            _ = try await client
                .from("bubls")
                .delete()
                .eq("user_id", value: currentUserID)
                .eq("week_id", value: WeekID.current())
                .execute()

            myBubl = nil
            feed = []
            errorMessage = nil
        } catch {
            errorMessage = "No pudimos reiniciar esta semana."
        }
    }

    private func describe(_ bubls: [Bubl]) -> String {
        guard !bubls.isEmpty else { return "[]" }
        return bubls
            .map { "\($0.id.uuidString){category=\($0.category.rawValue), subcategory=\($0.canonicalSubcategoryID ?? "nil"), activity=\($0.activityText)}" }
            .joined(separator: ", ")
    }

    private func loadLiveFeedViaRPC(currentUserID: UUID, weekID: String) async throws {
        struct Params: Encodable {
            let current_user_id: UUID
            let current_week_id: String
            let match_count: Int
        }

        let response = try await client
            .rpc(
                "get_my_live_bubl_feed",
                params: Params(
                    current_user_id: currentUserID,
                    current_week_id: weekID,
                    match_count: 12
                )
            )
            .execute()

        let payload = try JSONDecoder.bublDecoder.decode(FeedPayload.self, from: response.data)
        myBubl = payload.myBubl
        feed = payload.relatedBubls

        guard let myBubl else {
            log("No own bubl found for current week; skipping related selection")
            feed = []
            return
        }

        log(
            """
            Own bubl base id=\(myBubl.id.uuidString) category=\(myBubl.category.rawValue)
            subcategory=\(myBubl.canonicalSubcategoryID ?? "nil") activity=\(myBubl.activityText)
            """
        )
        log(
            """
            Live feed loaded from RPC count=\(feed.count)
            results=\(self.describe(feed))
            """
        )
    }

    private func loadLiveFeedFallback(currentUserID: UUID, weekID: String) async throws {
        let nowString = ISO8601DateFormatter().string(from: .now)

        let mineResponse = try await client
            .from("bubls")
            .select()
            .eq("user_id", value: currentUserID)
            .eq("week_id", value: weekID)
            .eq("is_active", value: true)
            .eq("is_flagged", value: false)
            .gt("expires_at", value: nowString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()

        let myRows = try JSONDecoder.bublDecoder.decode([Bubl].self, from: mineResponse.data)
        myBubl = myRows.first

        guard let myBubl else {
            feed = []
            log("Fallback live feed found no own bubl for current week")
            return
        }

        if let subcategory = myBubl.canonicalSubcategoryID, !subcategory.isEmpty {
            feed = try await client
                .from("bubls")
                .select()
                .eq("week_id", value: weekID)
                .eq("is_active", value: true)
                .eq("is_flagged", value: false)
                .gt("expires_at", value: nowString)
                .eq("subcategory_id", value: subcategory)
                .neq("user_id", value: currentUserID)
                .order("created_at", ascending: false)
                .limit(12)
                .execute()
                .value

            if feed.isEmpty, myBubl.subcategoryID == nil {
                feed = try await client
                    .from("bubls")
                    .select()
                    .eq("week_id", value: weekID)
                    .eq("is_active", value: true)
                    .eq("is_flagged", value: false)
                    .gt("expires_at", value: nowString)
                    .eq("cluster_label", value: subcategory)
                    .neq("user_id", value: currentUserID)
                    .order("created_at", ascending: false)
                    .limit(12)
                    .execute()
                    .value
            }
        } else {
            feed = []
        }

        log(
            """
            Live feed loaded from direct-query fallback count=\(feed.count)
            results=\(self.describe(feed))
            """
        )
    }

    private func log(_ message: String) {
        print("[FeedSelection] \(message)")
        NSLog("[FeedSelection] %@", message)
        logger.info("\(message, privacy: .public)")
    }
}

private struct FeedPayload: Decodable {
    let myBubl: Bubl?
    let relatedBubls: [Bubl]

    enum CodingKeys: String, CodingKey {
        case myBubl = "my_bubl"
        case relatedBubls = "related_bubls"
    }
}

@Observable
final class ReactionsViewModel {
    private var client: SupabaseClient { SupabaseConfig.client }

    var reactions: [Reaction] = []
    var errorMessage: String?

    func load(bublID: UUID) async {
        do {
            let response = try await client
                .from("reactions")
                .select()
                .eq("bubl_id", value: bublID)
                .order("created_at", ascending: false)
                .execute()

            reactions = try JSONDecoder.bublDecoder.decode([Reaction].self, from: response.data)
        } catch {
            errorMessage = "No pudimos cargar las reacciones."
        }
    }

    func count(for kind: ReactionKind) -> Int {
        reactions.filter { $0.kind == kind }.count
    }

    func submit(kind: ReactionKind, bublID: UUID, userID: UUID) async {
        struct NewReaction: Encodable {
            let bubl_id: UUID
            let user_id: UUID
            let type: String
        }

        do {
            _ = try await client
                .from("reactions")
                .upsert(
                    NewReaction(bubl_id: bublID, user_id: userID, type: kind.rawValue),
                    onConflict: "bubl_id,user_id"
                )
                .execute()

            await load(bublID: bublID)
        } catch {
            errorMessage = "No pudimos guardar tu reaccion."
        }
    }
}

extension JSONDecoder {
    static var bublDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
