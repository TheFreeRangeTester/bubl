import CryptoKit
import Foundation
import Observation
import OSLog
import Supabase

enum SupabaseConfig {
    private static let fallbackURL = "https://gmomqwmrasnhhpvizkpn.supabase.co"
    private static let fallbackAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdtb21xd21yYXNuaGhwdml6a3BuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3Nzk4NDMsImV4cCI6MjA4OTM1NTg0M30.ooRb4LEwW8j1qGt7H2_jEHyCpJhilotQqRbmVenLmjM"
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
        if !bundled.isEmpty { return bundled }
        return fallbackURL
    }

    static var runtimeAnonKey: String {
        let override = UserDefaults.standard.string(forKey: anonOverrideKey) ?? ""
        if !override.isEmpty { return override }
        let bundled = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
        if !bundled.isEmpty { return bundled }
        return fallbackAnonKey
    }

    static var client: SupabaseClient {
        let urlString = runtimeURL
        let anonKey = runtimeAnonKey
        let url = URL(string: urlString) ?? URL(string: fallbackURL)!
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
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
            if containsAny(in: normalized, phrases: ["guitarra", "guitar", "demo", "song", "cancion", "canción"]) { return "music_creation" }
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
        let newSession = try await client.auth.signInAnonymously()
        session = newSession
        state = .signedIn
        try await bootstrapUserIfNeeded(userID: newSession.user.id)
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
    enum ActivityPreset: String, CaseIterable, Identifiable {
        case listening
        case reading
        case playing
        case watching
        case workingOn
        case training
        case cooking
        case living

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
            case .workingOn: return isSpanish ? "trabajando en" : "working on"
            case .training: return isSpanish ? "entrenando" : "training"
            case .cooking: return isSpanish ? "cocinando" : "cooking"
            case .living: return isSpanish ? "atravesando" : "going through"
            }
        }

        var promptLabel: String {
            switch self {
            case .listening: return isSpanish ? "escuchar" : "listening to"
            case .reading: return isSpanish ? "leer" : "reading"
            case .playing: return isSpanish ? "jugar" : "playing"
            case .watching: return isSpanish ? "ver" : "watching"
            case .workingOn: return isSpanish ? "estar con" : "working on"
            case .training: return isSpanish ? "entrenar" : "training"
            case .cooking: return isSpanish ? "cocinar" : "cooking"
            case .living: return isSpanish ? "estar en" : "going through"
            }
        }

        var suggestedSubcategory: BublSubcategory {
            switch self {
            case .listening: return .hobbiesMusic
            case .reading: return .hobbiesReading
            case .playing: return .hobbiesGaming
            case .watching: return .hobbiesOther
            case .workingOn: return .workSideProjects
            case .training: return .healthExercise
            case .cooking: return .hobbiesFood
            case .living: return .lifeDecisions
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
                ? "Quizás haya otras personas en algo parecido. Veamos qué opinan."
                : "There may be other people in something similar. Let's see what they think."
        }

        return isSpanish
            ? "Quizás haya otros \(detail). Veamos qué opinan."
            : "There may be others \(detail). Let's see what they think."
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
        let selectedSubcategory = selectedSubcategory.category == selectedCategory
            ? selectedSubcategory
            : BublSubcategory.defaultOption(for: selectedCategory)
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
}

@Observable
final class FeedViewModel {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bubl",
        category: "FeedSelection"
    )
    private var client: SupabaseClient { SupabaseConfig.client }
    private let embeddingService = LegacyEmbeddingService()

    var myBubl: Bubl?
    var feed: [Bubl] = []
    var isLoading = false
    var errorMessage: String?

    var hasPostedThisWeek: Bool { myBubl != nil }

    func refresh(currentUserID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let weekID = WeekID.current()
        let nowString = ISO8601DateFormatter().string(from: .now)

        log("Refreshing related bubls for user=\(currentUserID.uuidString) week=\(weekID)")

        do {
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

            guard let mine = myBubl else {
                log("No own bubl found for current week; skipping related selection")
                feed = []
                errorMessage = nil
                return
            }

            log(
                """
                Own bubl base id=\(mine.id.uuidString) category=\(mine.category.rawValue)
                cluster=\(mine.clusterLabel ?? "nil") activity=\(mine.activityText)
                """
            )

            let allResponse = try await client
                .from("bubls")
                .select()
                .eq("week_id", value: weekID)
                .eq("is_active", value: true)
                .eq("is_flagged", value: false)
                .gt("expires_at", value: nowString)
                .neq("user_id", value: currentUserID)
                .order("created_at", ascending: false)
                .limit(150)
                .execute()

            let allRows = try JSONDecoder.bublDecoder.decode([Bubl].self, from: allResponse.data)
            let embeddingMatches = try? await embeddingService.matchBubls(bublID: mine.id, limit: 24)
            if let embeddingMatches {
                let summary = embeddingMatches
                    .map { "\($0.id.uuidString)=\(String(format: "%.3f", $0.distance))" }
                    .joined(separator: ", ")
                log("Embedding ranking loaded count=\(embeddingMatches.count) matches=[\(summary)]")
            } else {
                log("Embedding ranking unavailable; falling back to heuristic ordering")
            }
            feed = curatedFeed(from: allRows, mine: mine, embeddingMatches: embeddingMatches ?? [])
            errorMessage = nil
        } catch {
            log("Failed to refresh related bubls: \(error.localizedDescription)")
            errorMessage = "No pudimos cargar tu burbuja."
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

    private let maxEmbeddingDistance = 0.38
    private let embeddingDistanceSlack = 0.08

    private func curatedFeed(from items: [Bubl], mine: Bubl, embeddingMatches: [LegacyEmbeddingService.Match]) -> [Bubl] {
        let orderedCategories = [mine.category] + mine.category.fallbackOrder
        var selected: [Bubl] = []
        var seen = Set<UUID>()
        var activityFingerprintCounts: [String: Int] = [:]
        let normalizedMineCluster = normalizedClusterLabel(for: mine)
        let mineTokens = rankingTokens(for: mine)
        let mineTopic = inferredTopic(for: mine)
        let embeddingRanks = Dictionary(uniqueKeysWithValues: embeddingMatches.enumerated().map { ($1.id, $0) })
        let embeddingDistances = Dictionary(uniqueKeysWithValues: embeddingMatches.map { ($0.id, $0.distance) })

        log(
            """
            Curating related bubls with criterion=category+cluster+fallbacks primary=\(mine.category.rawValue)
            cluster=\(normalizedMineCluster ?? "nil")
            inferred_topic=\(mineTopic ?? "nil")
            strict_cluster_mode=\(normalizedMineCluster != nil)
            fallbacks=\(mine.category.fallbackOrder.map(\.rawValue).joined(separator: " > "))
            candidates=\(items.count)
            """
        )

        for category in orderedCategories {
            if normalizedMineCluster != nil && category != mine.category {
                log("Stopping before fallback category=\(category.rawValue) because strict_cluster_mode is enabled")
                break
            }

            let categoryMatches = items
                .filter { $0.category == category && !seen.contains($0.id) }
                .sorted { rank(lhs: $0, rhs: $1, relativeTo: mine, mineTokens: mineTokens, embeddingRanks: embeddingRanks) }

            let rawSameClusterMatches = categoryMatches.filter {
                guard let normalizedMineCluster else { return false }
                return normalizedClusterLabel(for: $0) == normalizedMineCluster
            }
            let sameClusterMatches = filterDistantEmbeddingMatches(
                rawSameClusterMatches,
                embeddingDistances: embeddingDistances
            )
            let otherCategoryMatches = categoryMatches.filter { candidate in
                guard let normalizedMineCluster else { return true }
                return normalizedClusterLabel(for: candidate) != normalizedMineCluster
            }

            log(
                """
                Category pass=\(category.rawValue)
                same_cluster_matched=\(sameClusterMatches.count) same_cluster_candidates=\(self.describe(sameClusterMatches, relativeTo: mineTokens, embeddingRanks: embeddingRanks, embeddingDistances: embeddingDistances))
                other_matched=\(otherCategoryMatches.count) other_candidates=\(self.describe(otherCategoryMatches, relativeTo: mineTokens, embeddingRanks: embeddingRanks, embeddingDistances: embeddingDistances))
                """
            )

            for item in sameClusterMatches {
                guard shouldInclude(item, fingerprintCounts: &activityFingerprintCounts) else { continue }
                seen.insert(item.id)
                selected.append(item)
                if selected.count >= 12 {
                    log("Related bubls final selection count=\(selected.count) results=\(self.describe(selected))")
                    return selected
                }
            }

            if normalizedMineCluster != nil && category == mine.category {
                log("Strict cluster mode active; skipping other clusters and category fallbacks after same-cluster selection")
                break
            }

            for item in otherCategoryMatches {
                guard shouldInclude(item, fingerprintCounts: &activityFingerprintCounts) else { continue }
                seen.insert(item.id)
                selected.append(item)
                if selected.count >= 12 {
                    log("Related bubls final selection count=\(selected.count) results=\(self.describe(selected))")
                    return selected
                }
            }
        }

        log("Related bubls final selection count=\(selected.count) results=\(self.describe(selected))")
        return selected
    }

    private func describe(_ bubls: [Bubl]) -> String {
        guard !bubls.isEmpty else { return "[]" }
        return bubls
            .map { "\($0.id.uuidString){category=\($0.category.rawValue), subcategory=\($0.canonicalSubcategoryID ?? "nil"), activity=\($0.activityText)}" }
            .joined(separator: ", ")
    }

    private func describe(_ bubls: [Bubl], relativeTo mineTokens: Set<String>, embeddingRanks: [UUID: Int], embeddingDistances: [UUID: Double]) -> String {
        guard !bubls.isEmpty else { return "[]" }
        return bubls
            .map {
                let score = similarityScore(for: $0, mineTokens: mineTokens, mineCluster: nil)
                let embeddingRank = embeddingRanks[$0.id].map(String.init) ?? "nil"
                let embeddingDistance = embeddingDistances[$0.id].map { String(format: "%.3f", $0) } ?? "nil"
                return "\($0.id.uuidString){category=\($0.category.rawValue), subcategory=\($0.canonicalSubcategoryID ?? "nil"), topic=\(inferredTopic(for: $0) ?? "nil"), embedding_rank=\(embeddingRank), embedding_distance=\(embeddingDistance), score=\(String(format: "%.3f", score)), activity=\($0.activityText)}"
            }
            .joined(separator: ", ")
    }

    private func filterDistantEmbeddingMatches(_ candidates: [Bubl], embeddingDistances: [UUID: Double]) -> [Bubl] {
        let distances = candidates.compactMap { embeddingDistances[$0.id] }
        guard let bestDistance = distances.min() else {
            return candidates
        }

        let threshold = min(maxEmbeddingDistance, bestDistance + embeddingDistanceSlack)
        let filtered = candidates.filter { candidate in
            guard let distance = embeddingDistances[candidate.id] else { return true }
            return distance <= threshold
        }

        if filtered.count != candidates.count {
            log("Filtered distant embedding matches best_distance=\(String(format: "%.3f", bestDistance)) threshold=\(String(format: "%.3f", threshold)) kept=\(filtered.count) dropped=\(candidates.count - filtered.count)")
        }

        return filtered.isEmpty ? candidates : filtered
    }

    private func normalizedClusterLabel(for bubl: Bubl) -> String? {
        guard let cluster = bubl.canonicalSubcategoryID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !cluster.isEmpty else {
            return nil
        }
        return cluster
    }

    private func rank(lhs: Bubl, rhs: Bubl, relativeTo mine: Bubl, mineTokens: Set<String>, embeddingRanks: [UUID: Int]) -> Bool {
        let lhsEmbeddingRank = embeddingRanks[lhs.id]
        let rhsEmbeddingRank = embeddingRanks[rhs.id]

        if let lhsEmbeddingRank, let rhsEmbeddingRank, lhsEmbeddingRank != rhsEmbeddingRank {
            return lhsEmbeddingRank < rhsEmbeddingRank
        }
        if lhsEmbeddingRank != nil && rhsEmbeddingRank == nil {
            return true
        }
        if lhsEmbeddingRank == nil && rhsEmbeddingRank != nil {
            return false
        }

        let mineCluster = normalizedClusterLabel(for: mine)
        let lhsScore = similarityScore(for: lhs, mineTokens: mineTokens, mineCluster: mineCluster)
        let rhsScore = similarityScore(for: rhs, mineTokens: mineTokens, mineCluster: mineCluster)

        if abs(lhsScore - rhsScore) > 0.001 {
            return lhsScore > rhsScore
        }

        return lhs.createdAt > rhs.createdAt
    }

    private func similarityScore(for candidate: Bubl, mineTokens: Set<String>, mineCluster: String?) -> Double {
        let candidateTokens = rankingTokens(for: candidate)
        guard !mineTokens.isEmpty, !candidateTokens.isEmpty else { return 0 }

        let overlap = mineTokens.intersection(candidateTokens)
        let unionCount = mineTokens.union(candidateTokens).count
        let jaccard = unionCount > 0 ? Double(overlap.count) / Double(unionCount) : 0

        let properNounBoost = overlap.filter { $0.count >= 5 }.isEmpty ? 0.0 : 0.15
        let phraseBoost = sharedPhraseBoost(candidate: candidate, mineTokens: mineTokens)
        let topicBoost = inferredTopicBoost(for: candidate, mineTokens: mineTokens, mineCluster: mineCluster)

        return jaccard + properNounBoost + phraseBoost + topicBoost
    }

    private func sharedPhraseBoost(candidate: Bubl, mineTokens: Set<String>) -> Double {
        let combined = normalizedText("\(candidate.activityText) \(candidate.feelingText)")
        let boosters = mineTokens.filter { token in token.count >= 6 && combined.contains(token) }
        return boosters.isEmpty ? 0.0 : min(0.2, Double(boosters.count) * 0.05)
    }

    private func rankingTokens(for bubl: Bubl) -> Set<String> {
        BublTopicInference.rankingTokens(activity: bubl.activityText, feeling: bubl.feelingText)
    }

    private func normalizedText(_ text: String) -> String {
        BublTopicInference.normalizedText(text)
    }

    private func shouldInclude(_ bubl: Bubl, fingerprintCounts: inout [String: Int]) -> Bool {
        let fingerprint = activityFingerprint(for: bubl)
        let count = fingerprintCounts[fingerprint, default: 0]
        let limit = duplicateLimit(for: bubl)

        guard count < limit else {
            log("Skipping duplicate-heavy candidate id=\(bubl.id.uuidString) subcategory=\(bubl.canonicalSubcategoryID ?? "nil") fingerprint=\(fingerprint)")
            return false
        }

        fingerprintCounts[fingerprint] = count + 1
        return true
    }

    private func duplicateLimit(for bubl: Bubl) -> Int {
        if normalizedClusterLabel(for: bubl) == "music" {
            return 3
        }
        return 2
    }

    private func activityFingerprint(for bubl: Bubl) -> String {
        normalizedText(bubl.activityText)
            .replacingOccurrences(of: #"\(\d+(?:st|nd|rd|th)? weekly variant\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferredTopicBoost(for candidate: Bubl, mineTokens: Set<String>, mineCluster: String?) -> Double {
        let mineTopic = BublTopicInference.inferredTopic(tokens: mineTokens, cluster: mineCluster)
        let candidateTopic = inferredTopic(for: candidate)

        guard let mineTopic, let candidateTopic else { return 0 }
        return mineTopic == candidateTopic ? 0.35 : 0
    }

    private func inferredTopic(for bubl: Bubl) -> String? {
        if let topicID = bubl.canonicalTopicID, !topicID.isEmpty {
            return topicID
        }
        guard normalizedClusterLabel(for: bubl) != nil else { return nil }
        return BublTopicInference.inferredTopic(
            tokens: rankingTokens(for: bubl),
            cluster: normalizedClusterLabel(for: bubl),
            text: normalizedText("\(bubl.activityText) \(bubl.feelingText)")
        )
    }

    private func log(_ message: String) {
        print("[FeedSelection] \(message)")
        NSLog("[FeedSelection] %@", message)
        logger.info("\(message, privacy: .public)")
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
