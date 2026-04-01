import AuthenticationServices
import SwiftUI
import UIKit

private func uiText(_ es: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "es" ? es : en
}

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var isPreviewMode = false

    var body: some View {
        Group {
            switch authManager.state {
            case .loading:
                ProgressView()
                    .tint(BublPalette.ink)
            case .signedOut:
                if isPreviewMode {
                    PreviewExperienceView {
                        isPreviewMode = false
                    }
                } else {
                    OnboardingView {
                        isPreviewMode = true
                    }
                }
            case .signedIn:
                FeedView()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: authManager.state)
        .background(BublPalette.page.ignoresSafeArea())
    }
}

private struct OnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var pendingNonce = ""
    @State private var errorMessage: String?
    @State private var devURL = SupabaseConfig.runtimeURL
    @State private var devAnonKey = SupabaseConfig.runtimeAnonKey
    let onEnterPreviewMode: () -> Void

    private var bundledURL: String {
        SupabaseConfig.runtimeURL
    }

    private var bundledAnonKey: String {
        SupabaseConfig.runtimeAnonKey
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Spacer(minLength: 24)

                Text("bubl")
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(BublPalette.ink)

                Text(uiText("Compartí cómo te está pegando algo que estás viviendo esta semana.", "Share how something you are living through is hitting you this week."))
                    .font(.bublRounded(.title3, weight: .medium))
                    .foregroundStyle(BublPalette.ink)

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingRule(icon: "timer", text: "Todo dura 7 dias")
                    OnboardingRule(icon: "person.crop.circle.badge.xmark", text: "Sin perfiles publicos ni followers")
                    OnboardingRule(icon: "ellipsis.message", text: "Sin chat privado")
                    OnboardingRule(icon: "heart.text.square", text: "Lo importante es como venis con eso")
                }
                .padding(18)
                .background(BublPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text(uiText("No compartas datos de contacto, redes o información para que te ubiquen.", "Do not share contact details, social handles, or identifying information."))
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)

                SignInWithAppleButton(.signIn) { request in
                    let nonce = authManager.makeNonce()
                    pendingNonce = nonce
                    request.requestedScopes = [.fullName]
                    request.nonce = authManager.sha256(nonce)
                } onCompletion: { result in
                    handleAuth(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    Task {
                        do {
                            try await authManager.signInAnonymouslyForDevelopment()
                        } catch {
                            let details = error.localizedDescription
                            errorMessage = uiText(
                                "No se pudo entrar en modo desarrollo. \(details)",
                                "Could not enter development mode. \(details)"
                            )
                        }
                    }
                } label: {
                    Text(uiText("Continuar en modo desarrollo", "Continue in development mode"))
                        .font(.bublRounded(.subheadline, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BublPalette.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                #if targetEnvironment(simulator)
                Button(action: onEnterPreviewMode) {
                    Text(uiText("Explorar UI sin login", "Explore UI without login"))
                        .font(.bublRounded(.subheadline, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BublPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BublPalette.ornament.opacity(0.12), lineWidth: 1)
                        )
                }
                #endif

                VStack(alignment: .leading, spacing: 10) {
                    Text(uiText("Config dev", "Dev config"))
                        .font(.bublRounded(.footnote, weight: .semibold))
                        .foregroundStyle(BublPalette.muted)

                    Text(configStatusText)
                        .font(.bublRounded(.caption))
                        .foregroundStyle(BublPalette.muted)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(uiText("Supabase URL", "Supabase URL"))
                                .font(.bublRounded(.footnote, weight: .semibold))
                                .foregroundStyle(BublPalette.muted)

                            Spacer()

                            Button(uiText("Pegar", "Paste")) {
                                if let pastedText = pastedFromClipboard() {
                                    devURL = pastedText
                                    errorMessage = nil
                                }
                            }
                            .font(.bublRounded(.caption, weight: .semibold))
                            .foregroundStyle(BublPalette.ink)
                        }

                        TextField("Supabase URL", text: $devURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.bublRounded(.footnote))
                            .padding(10)
                            .background(BublPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(uiText("Supabase ANON key", "Supabase ANON key"))
                                .font(.bublRounded(.footnote, weight: .semibold))
                                .foregroundStyle(BublPalette.muted)

                            Spacer()

                            Button(uiText("Pegar", "Paste")) {
                                if let pastedText = pastedFromClipboard() {
                                    devAnonKey = pastedText
                                    errorMessage = nil
                                }
                            }
                            .font(.bublRounded(.caption, weight: .semibold))
                            .foregroundStyle(BublPalette.ink)
                        }

                        TextField("Supabase ANON key", text: $devAnonKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.bublRounded(.footnote))
                            .padding(10)
                            .background(BublPalette.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button("Guardar config dev") {
                        SupabaseConfig.saveOverrides(
                            url: devURL.trimmingCharacters(in: .whitespacesAndNewlines),
                            anonKey: devAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        errorMessage = "Configuracion guardada."
                    }
                    .font(.bublRounded(.footnote, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                    Button(uiText("Usar config integrada", "Use bundled config")) {
                        devURL = bundledURL
                        devAnonKey = bundledAnonKey
                        errorMessage = bundledAnonKey.isEmpty
                            ? uiText("La app no trae una ANON key integrada en este build.", "This build does not include a bundled ANON key.")
                            : uiText("Config integrada cargada.", "Bundled config loaded.")
                    }
                    .font(.bublRounded(.footnote, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                    Button(uiText("Reset config dev", "Reset dev config")) {
                        SupabaseConfig.clearOverrides()
                        devURL = SupabaseConfig.runtimeURL
                        devAnonKey = SupabaseConfig.runtimeAnonKey
                        errorMessage = uiText("Config dev reseteada.", "Dev config reset.")
                    }
                    .font(.bublRounded(.footnote, weight: .semibold))
                    .foregroundStyle(BublPalette.muted)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.bublRounded(.footnote))
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .background(BublPalette.page.ignoresSafeArea())
    }

    private var configStatusText: String {
        let currentURL = devURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentAnonKey = devAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundledKeyAvailable = !bundledAnonKey.isEmpty
        return uiText(
            "URL actual: \(currentURL.isEmpty ? "vacia" : "ok") | ANON actual: \(currentAnonKey.isEmpty ? "vacia" : "ok (\(currentAnonKey.count))") | Key integrada: \(bundledKeyAvailable ? "si" : "no")",
            "Current URL: \(currentURL.isEmpty ? "empty" : "ok") | Current ANON: \(currentAnonKey.isEmpty ? "empty" : "ok (\(currentAnonKey.count))") | Bundled key: \(bundledKeyAvailable ? "yes" : "no")"
        )
    }

    private func pastedFromClipboard() -> String? {
        let pastedText = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pastedText.isEmpty else {
            errorMessage = uiText("El portapapeles está vacío.", "Clipboard is empty.")
            return nil
        }

        return pastedText
    }

    private func handleAuth(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            errorMessage = "No se pudo iniciar sesion."
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "No se pudo iniciar sesion."
                return
            }

            Task {
                do {
                    try await authManager.signInWithApple(idToken: idToken, nonce: pendingNonce)
                } catch {
                    errorMessage = "No se pudo iniciar sesion."
                }
            }
        }
    }
}

private struct PreviewExperienceView: View {
    @State private var myBubl = PreviewData.myBubl
    @State private var related = PreviewData.relatedBubls
    @State private var selectedForReactions: Bubl?
    @State private var selectedForReport: Bubl?
    @State private var showingPostFlow = false

    let onExit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(uiText("Modo preview del simulador. Nada de esto toca Supabase todavía.", "Simulator preview mode. None of this touches Supabase yet."))
                        .font(.bublRounded(.footnote))
                        .foregroundStyle(BublPalette.muted)

                    Button {
                        showingPostFlow = true
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(uiText("Probar flow de publicación", "Try posting flow"))
                                .font(.bublRounded(.headline, weight: .semibold))
                                .foregroundStyle(BublPalette.ink)
                            Text(uiText("Recorre el onboarding de post y simula publicar localmente.", "Go through the posting onboarding and simulate a local publish."))
                                .font(.bublRounded(.subheadline))
                                .foregroundStyle(BublPalette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    SectionHeader(
                        title: uiText("Tu semana", "Your week"),
                        subtitle: uiText("Una publicación mock para diseñar el estado con contenido propio.", "A mock post so you can design the state with your own content.")
                    )
                    BublCardView(bubl: myBubl, isOwnPost: true)

                    SectionHeader(
                        title: uiText("Tu burbuja", "Your bubble"),
                        subtitle: uiText("Mock data para revisar densidad, cards y navegación.", "Mock data to review density, cards, and navigation.")
                    )

                    ForEach(related) { bubl in
                        BublCardView(bubl: bubl, isOwnPost: false)
                            .onTapGesture { selectedForReactions = bubl }
                            .onLongPressGesture { selectedForReport = bubl }
                    }
                }
                .padding(20)
            }
            .navigationTitle("bubl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(uiText("Salir preview", "Exit preview"), action: onExit)
                        .font(.bublRounded(.subheadline))
                        .tint(BublPalette.muted)
                }
            }
            .sheet(isPresented: $showingPostFlow) {
                PreviewPostFlowSheet { previewBubl in
                    myBubl = previewBubl
                }
            }
            .sheet(item: $selectedForReactions) { bubl in
                PreviewReactionSheetView(bubl: bubl)
            }
            .sheet(item: $selectedForReport) { bubl in
                PreviewReportView(reportedBublID: bubl.id)
            }
            .background(BublPalette.page)
        }
    }
}

private struct PreviewPostFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var postViewModel = PostViewModel()
    @State private var step = 1
    @State private var showMatchingState = false

    let onPosted: (Bubl) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if step == 1 {
                        Step1View(viewModel: postViewModel) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                step = 2
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Step2View(
                            viewModel: postViewModel,
                            isSubmitting: postViewModel.isSubmitting,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    step = 1
                                }
                            },
                            onShare: submit
                        )
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                if showMatchingState {
                    MatchingBubbleView(message: postViewModel.matchingPrompt)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: step)
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: showMatchingState)
            .background(BublPalette.page.ignoresSafeArea())
        }
    }

    private func submit() {
        postViewModel.trimLimits()

        if BublGuardrails.containsCrisisLanguage(postViewModel.step2Text) {
            postViewModel.showCrisisPrompt = true
        }

        guard postViewModel.canShare else {
            postViewModel.submitError = uiText("Completá las dos partes antes de publicar.", "Complete both parts before publishing.")
            return
        }

        let activity = postViewModel.composedActivityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let feeling = postViewModel.step2Text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationError = BublGuardrails.validationError(activity: activity, feeling: feeling) {
            postViewModel.submitError = validationError
            return
        }

        Task {
            postViewModel.isSubmitting = true
            withAnimation { showMatchingState = true }
            try? await Task.sleep(for: .milliseconds(900))

            let previewBubl = PreviewData.makeMyBubl(activityText: activity, feelingText: feeling)
            onPosted(previewBubl)

            postViewModel.isSubmitting = false
            dismiss()
        }
    }
}

private struct PreviewReactionSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let bubl: Bubl

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                BublCardView(bubl: bubl, isOwnPost: false)

                Text(uiText("Interacciones cortas", "Short reactions"))
                    .font(.bublRounded(.headline, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                ForEach(ReactionKind.allCases) { kind in
                    HStack {
                        Text(kind.label)
                            .font(.bublRounded(.body, weight: .semibold))
                        Spacer()
                        Text("\(PreviewData.reactionCount(for: kind))")
                            .font(.bublRounded(.body))
                            .foregroundStyle(BublPalette.muted)
                    }
                    .padding(14)
                    .background(BublPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text(uiText("Preview local: acá después conectamos la reacción real.", "Local preview: we'll wire the real reaction flow here later."))
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)

                Spacer()
            }
            .padding(16)
            .navigationTitle(uiText("Acompañar", "Support"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
            .background(BublPalette.page)
        }
    }
}

private struct PreviewReportView: View {
    @Environment(\.dismiss) private var dismiss

    let reportedBublID: UUID

    @State private var selectedReason = "Datos personales"
    @State private var showConfirmation = false

    private let reasons = [
        "Datos personales",
        "Acoso o odio",
        "Contenido sexual",
        "Autolesion o crisis",
        "Spam"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(uiText("Reportar publicación", "Report post"))
                    .font(.bublRounded(.title3, weight: .semibold))

                Picker("Motivo", selection: $selectedReason) {
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason).tag(reason)
                    }
                }
                .pickerStyle(.inline)

                Button(uiText("Enviar preview", "Send preview")) {
                    showConfirmation = true
                }
                .buttonStyle(BublPrimaryButtonStyle())

                Text(uiText("Preview local del flujo de reporte. No envía nada todavía.", "Local preview of the report flow. It does not send anything yet."))
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)

                Spacer()
            }
            .padding(20)
            .navigationTitle(String(localized: "report.nav"))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Gracias", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text(String(localized: "report.done.body"))
            }
            .background(BublPalette.page)
        }
    }
}

private enum PreviewData {
    static var myBubl: Bubl {
        makeMyBubl(
            activityText: uiText("trabajando en una app nueva con demasiadas ideas al mismo tiempo", "working on a new app with too many ideas at once"),
            feelingText: uiText("me entusiasma mucho, pero también me cuesta cerrar y no perderme en detalles.", "I am really excited, but it is also hard to finish and not get lost in details.")
        )
    }

    static var relatedBubls: [Bubl] {
        [
            makeRelatedBubl(
                activityText: uiText("armando un side project de noche", "building a side project at night"),
                feelingText: uiText("me está costando bajar la ansiedad de querer que salga perfecto.", "I am struggling to calm the anxiety of wanting it to be perfect.")
            ),
            makeRelatedBubl(
                activityText: uiText("reordenando mi semana para enfocarme mejor", "reworking my week to focus better"),
                feelingText: uiText("me sirve poner límites, pero todavía siento culpa cuando corto.", "Setting boundaries helps, but I still feel guilty when I stop.")
            ),
            makeRelatedBubl(
                activityText: uiText("volviendo a diseñar algo desde cero", "starting to design something from scratch again"),
                feelingText: uiText("me gusta sentir que vuelve la energía creativa, aunque voy lento.", "It feels good to have creative energy back, even if I am going slowly.")
            )
        ]
    }

    static func reactionCount(for kind: ReactionKind) -> Int {
        switch kind {
        case .sameHere: return 8
        case .iGetIt: return 5
        case .beenThere: return 3
        case .rootingForYou: return 11
        }
    }

    static func makeMyBubl(activityText: String, feelingText: String) -> Bubl {
        Bubl(
            id: UUID(),
            userID: UUID(),
            activityText: activityText,
            feelingText: feelingText,
            categoryID: BublCategory.work.rawValue,
            subcategoryID: "work_side_projects",
            topicID: "building_projects",
            languageCode: Locale.current.language.languageCode?.identifier ?? "en",
            clusterLabel: "work_side_projects",
            weekID: WeekID.current(),
            createdAt: .now,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            isActive: true,
            isFlagged: false
        )
    }

    static func makeRelatedBubl(activityText: String, feelingText: String) -> Bubl {
        Bubl(
            id: UUID(),
            userID: UUID(),
            activityText: activityText,
            feelingText: feelingText,
            categoryID: BublCategory.work.rawValue,
            subcategoryID: "work_side_projects",
            topicID: "building_projects",
            languageCode: Locale.current.language.languageCode?.identifier ?? "en",
            clusterLabel: "work_side_projects",
            weekID: WeekID.current(),
            createdAt: .now,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
            isActive: true,
            isFlagged: false
        )
    }
}

private struct FeedView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = FeedViewModel()

    @State private var showingPostFlow = false
    @State private var selectedForReactions: Bubl?
    @State private var selectedForReport: Bubl?
    @State private var hasLoadedFeedOnce = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.hasPostedThisWeek {
                        Button {
                            showingPostFlow = true
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(uiText("Tu burbuja de esta semana", "Your bubble this week"))
                                    .font(.bublRounded(.headline, weight: .semibold))
                                    .foregroundStyle(BublPalette.ink)
                                Text(uiText("Arrancá con una burbuja guiada y encontrá gente que esté en algo parecido.", "Start with a guided bubble and find people in something similar."))
                                    .font(.bublRounded(.subheadline))
                                    .foregroundStyle(BublPalette.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(
                                LinearGradient(
                                    colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(BublPalette.ornament.opacity(0.16), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let mine = viewModel.myBubl {
                        SectionHeader(title: uiText("Tu semana", "Your week"), subtitle: uiText("Esto es lo que compartiste para abrir tu burbuja.", "This is what you shared to open your bubble."))
                        BublCardView(bubl: mine, isOwnPost: true)
                    }

                    if let mine = viewModel.myBubl {
                        SectionHeader(
                            title: uiText("Tu burbuja", "Your bubble"),
                            subtitle: uiText("Esto está diciendo gente en la misma esta semana.", "This is what people in the same kind of situation are saying this week.")
                        )

                        if viewModel.feed.isEmpty {
                            EmptyBubbleCard(category: mine.category)
                        } else {
                            if viewModel.feed.count < 3 {
                                PartialBubbleCard()
                            }
                            ForEach(viewModel.feed) { bubl in
                                BublCardView(bubl: bubl, isOwnPost: false)
                                    .onTapGesture { selectedForReactions = bubl }
                                    .onLongPressGesture { selectedForReport = bubl }
                            }
                        }
                    } else {
                        LockedBubbleCard()
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.bublRounded(.footnote))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("bubl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if authManager.session?.user.id != nil {
                        Button(uiText("Reset week", "Reset week")) {
                            Task {
                                guard let userID = authManager.session?.user.id else { return }
                                await viewModel.deleteMyBublThisWeek(currentUserID: userID)
                                showingPostFlow = true
                            }
                        }
                        .font(.bublRounded(.footnote))
                        .tint(BublPalette.muted)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.signout")) {
                        Task { await authManager.signOut() }
                    }
                    .font(.bublRounded(.subheadline))
                    .tint(BublPalette.muted)
                }
            }
            .refreshable { await refreshFeed() }
            .task {
                await refreshFeed()
                hasLoadedFeedOnce = true
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active, hasLoadedFeedOnce else { return }
                Task {
                    await refreshFeed()
                }
            }
            .sheet(isPresented: $showingPostFlow) {
                PostFlowSheet {
                    Task {
                        await refreshFeed()
                    }
                }
            }
            .sheet(item: $selectedForReactions) { bubl in
                ReactionSheetView(bubl: bubl)
            }
            .sheet(item: $selectedForReport) { bubl in
                ReportView(reportedBublID: bubl.id)
            }
            .background(BublPalette.page)
        }
    }

    private func refreshFeed() async {
        guard let userID = authManager.session?.user.id else { return }
        await viewModel.refresh(currentUserID: userID)
    }
}

private struct PostFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var postViewModel = PostViewModel()
    @State private var step = 1
    @State private var showMatchingState = false

    let onPosted: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if step == 1 {
                        Step1View(viewModel: postViewModel) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                step = 2
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else if step == 2 {
                        Step2View(
                            viewModel: postViewModel,
                            isSubmitting: postViewModel.isSubmitting,
                            onBack: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    step = 1
                                }
                            },
                            onShare: submit
                        )
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }

                if showMatchingState {
                    MatchingBubbleView(message: postViewModel.matchingPrompt)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: step)
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: showMatchingState)
            .background(BublPalette.page.ignoresSafeArea())
            .alert(uiText("Si esto se siente demasiado pesado, buscá ayuda real.", "If this feels too heavy, please seek real-world help."), isPresented: $postViewModel.showCrisisPrompt) {
                Link(uiText("Ver recursos", "See resources"), destination: URL(string: "https://findahelpline.com")!)
                Button(String(localized: "common.dismiss"), role: .cancel) {}
            } message: {
                Text(String(localized: "post.crisis.body"))
            }
            .alert(uiText("No pudimos publicar", "We couldn't publish"), isPresented: Binding(
                get: { postViewModel.submitError != nil },
                set: { _ in postViewModel.submitError = nil }
            )) {
                Button(String(localized: "common.ok")) { postViewModel.submitError = nil }
            } message: {
                Text(postViewModel.submitError ?? "")
            }
        }
    }

    private func submit() {
        guard let userID = authManager.session?.user.id else { return }

        Task {
            withAnimation { showMatchingState = true }
            let posted = await postViewModel.share(currentUserID: userID)
            if posted {
                try? await Task.sleep(for: .milliseconds(1350))
                onPosted()
                dismiss()
            } else {
                withAnimation { showMatchingState = false }
            }
        }
    }
}

private struct MatchingBubbleView: View {
    @State private var animate = false
    let message: String

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 144, height: 144)
                    .scaleEffect(animate ? 1.08 : 0.92)

                Circle()
                    .fill(BublPalette.card)
                    .frame(width: 96, height: 96)
                    .overlay(
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(BublPalette.ink)
                    )
                    .offset(y: animate ? -3 : 3)

                Circle()
                    .fill(BublPalette.accentSoft.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .offset(x: -72, y: -38)
                    .offset(y: animate ? -12 : 4)

                Circle()
                    .fill(BublPalette.ink.opacity(0.12))
                    .frame(width: 20, height: 20)
                    .offset(x: 64, y: 28)
                    .offset(y: animate ? 8 : -4)
            }
            .padding(.bottom, 8)

            VStack(spacing: 10) {
                Text(uiText("Veamos qué opinan", "Let's see what they think"))
                    .font(.bublRounded(.title3, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.bublRounded(.body))
                    .foregroundStyle(BublPalette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            ProgressView()
                .tint(BublPalette.ink)
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BublPalette.page.opacity(0.96).ignoresSafeArea())
        .task {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct Step1View: View {
    @Bindable var viewModel: PostViewModel
    let onContinue: () -> Void
    @State private var showsPresetPicker = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(uiText("Contanos qué estás haciendo", "Tell us what you're into"))
                    .font(.bublRounded(.title2, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                Text(uiText("La idea es arrancar con una burbuja simple y agradable, como si la app te estuviera preguntando suave.", "The idea is to start with a soft, simple bubble, like the app is gently asking you."))
                    .font(.bublRounded(.subheadline))
                    .foregroundStyle(BublPalette.muted)

                BubblePrompt(
                    title: "I'm...",
                    subtitle: uiText("Tocá para elegir el tipo de situación", "Tap to choose the kind of moment")
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showsPresetPicker.toggle()
                    }
                }

                if showsPresetPicker {
                    BubbleOptionCloud(
                        presets: PostViewModel.ActivityPreset.allCases,
                        selectedPreset: viewModel.selectedPreset
                    ) { preset in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.applyPreset(preset)
                            showsPresetPicker = false
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let selectedPreset = viewModel.selectedPreset {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Text(uiText("Ahora completá qué es eso.", "Now fill in what that is."))
                                .font(.bublRounded(.headline, weight: .semibold))
                                .foregroundStyle(BublPalette.ink)

                            Spacer()

                            Button(uiText("Cambiar", "Change")) {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    showsPresetPicker = true
                                }
                            }
                            .font(.bublRounded(.footnote, weight: .semibold))
                            .foregroundStyle(BublPalette.muted)
                        }

                        HStack(spacing: 8) {
                            Text(selectedPreset.label)
                                .font(.bublRounded(.subheadline, weight: .semibold))
                                .foregroundStyle(BublPalette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(BublPalette.accentSoft)
                                .clipShape(Capsule())

                            TextEditor(text: $viewModel.step1Text)
                                .font(.bublRounded(.body))
                                .frame(minHeight: 120)
                                .padding(10)
                                .background(BublPalette.card)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if viewModel.step1Text.isEmpty {
                                        Text(uiText("pokemon Pokopia, un libro raro, una serie nueva, un side project...", "pokemon Pokopia, a weird book, a new show, a side project..."))
                                            .font(.bublRounded(.body))
                                            .foregroundStyle(BublPalette.muted)
                                            .padding(.horizontal, 16)
                                            .padding(.top, 18)
                                    }
                                }
                                .onChange(of: viewModel.step1Text) {
                                    viewModel.trimLimits()
                                }
                        }

                        Text(uiText("Así se va a leer: ", "This will read as: ") + viewModel.composedActivityText)
                            .font(.bublRounded(.footnote))
                            .foregroundStyle(BublPalette.muted)

                        Text("\(viewModel.step1Text.count)/100")
                            .font(.bublRounded(.caption))
                            .foregroundStyle(BublPalette.muted)
                    }
                }

                Button(uiText("Seguir", "Continue"), action: onContinue)
                    .buttonStyle(BublPrimaryButtonStyle())
                    .disabled(!viewModel.canContinueStep1)
                    .padding(.top, 4)
            }
            .padding(20)
        }
    }
}

private struct Step2View: View {
    @Bindable var viewModel: PostViewModel
    let isSubmitting: Bool
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button(action: onBack) {
                        Label("Atras", systemImage: "chevron.left")
                            .font(.bublRounded(.subheadline, weight: .semibold))
                    }
                    .tint(BublPalette.muted)

                    Spacer()
                }

                BubblePrompt(
                    title: viewModel.opinionPrompt,
                    subtitle: uiText("Decilo en pocas palabras, como te salga.", "Say it in a few words, however it comes out.")
                )

                Text(viewModel.composedActivityText)
                    .font(.bublRounded(.footnote, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())

                TextEditor(text: $viewModel.step2Text)
                    .font(.bublRounded(.body))
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(BublPalette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if viewModel.step2Text.isEmpty {
                            Text(uiText("me está dando nostalgia, me re enganché, me está frustrando más de lo que pensé...", "it's making me nostalgic, I'm really into it, it's frustrating me more than I expected..."))
                                .font(.bublRounded(.body))
                                .foregroundStyle(BublPalette.muted)
                                .padding(.horizontal, 16)
                                .padding(.top, 18)
                        }
                    }
                    .onChange(of: viewModel.step2Text) {
                        viewModel.trimLimits()
                    }

                Text("\(viewModel.step2Text.count)/220")
                    .font(.bublRounded(.caption))
                    .foregroundStyle(BublPalette.muted)

                Button(action: onShare) {
                    if isSubmitting {
                        ProgressView()
                            .tint(BublPalette.ink)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(uiText("Buscar bubls parecidos", "Find related bubls"))
                    }
                }
                .buttonStyle(BublPrimaryButtonStyle())
                .disabled(!viewModel.canShare || isSubmitting)
            }
            .padding(20)
        }
    }
}

private struct BubblePrompt: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.bublRounded(.title3, weight: .semibold))
                .foregroundStyle(BublPalette.ink)

            Text(subtitle)
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [BublPalette.card, BublPalette.accentSoft.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(BublPalette.card)
                .frame(width: 26, height: 26)
                .offset(x: 18, y: 12)
        }
    }
}

private struct BubbleOptionCloud: View {
    let presets: [PostViewModel.ActivityPreset]
    let selectedPreset: PostViewModel.ActivityPreset?
    let onSelect: (PostViewModel.ActivityPreset) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(presets) { preset in
                Button {
                    onSelect(preset)
                } label: {
                    Text(preset.label)
                        .font(.bublRounded(.body, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: selectedPreset == preset
                                    ? [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.45)]
                                    : [BublPalette.card, BublPalette.card],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(BublPalette.ornament.opacity(selectedPreset == preset ? 0.22 : 0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ReactionSheetView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReactionsViewModel()

    let bubl: Bubl

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                BublCardView(bubl: bubl, isOwnPost: false)

                Text(uiText("Interacciones cortas", "Short reactions"))
                    .font(.bublRounded(.headline, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                ForEach(ReactionKind.allCases) { kind in
                    Button {
                        submit(kind: kind)
                    } label: {
                        HStack {
                            Text(kind.label)
                                .font(.bublRounded(.body, weight: .semibold))
                            Spacer()
                            Text("\(viewModel.count(for: kind))")
                                .font(.bublRounded(.body))
                                .foregroundStyle(BublPalette.muted)
                        }
                        .padding(14)
                        .background(BublPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text(uiText("No hay comentarios ni chat. Solo una señal corta para acompañar.", "No comments or chat. Just a short signal to show support."))
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.bublRounded(.footnote))
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle(uiText("Acompañar", "Support"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
            .task {
                await viewModel.load(bublID: bubl.id)
            }
            .background(BublPalette.page)
        }
    }

    private func submit(kind: ReactionKind) {
        guard let userID = authManager.session?.user.id else { return }
        Task {
            await viewModel.submit(kind: kind, bublID: bubl.id, userID: userID)
        }
    }
}

private struct ReportView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    let reportedBublID: UUID

    @State private var selectedReason = "Datos personales"
    @State private var isSubmitting = false
    @State private var showConfirmation = false

    private let client = SupabaseConfig.client
    private let reasons = [
        "Datos personales",
        "Acoso o odio",
        "Contenido sexual",
        "Autolesion o crisis",
        "Spam"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(uiText("Reportar publicación", "Report post"))
                    .font(.bublRounded(.title3, weight: .semibold))

                Picker("Motivo", selection: $selectedReason) {
                    ForEach(reasons, id: \.self) { reason in
                        Text(reason).tag(reason)
                    }
                }
                .pickerStyle(.inline)

                Button(action: submit) {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .tint(BublPalette.ink)
                    } else {
                        Text(String(localized: "report.submit"))
                    }
                }
                .buttonStyle(BublPrimaryButtonStyle())

                Spacer()
            }
            .padding(20)
            .navigationTitle(String(localized: "report.nav"))
            .navigationBarTitleDisplayMode(.inline)
            .alert("Gracias", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text(String(localized: "report.done.body"))
            }
            .background(BublPalette.page)
        }
    }

    private func submit() {
        guard let userID = authManager.session?.user.id else { return }

        isSubmitting = true
        Task {
            defer { isSubmitting = false }

            do {
                let payload = ReportPayload(
                    reporterUserID: userID,
                    reportedBublID: reportedBublID,
                    reportedReactionID: nil,
                    reason: selectedReason
                )

                _ = try await client
                    .from("reports")
                    .insert(payload)
                    .execute()
            } catch {
                // We still confirm so people do not get stuck retrying reports.
            }

            showConfirmation = true
        }
    }
}

private struct BublCardView: View {
    let bubl: Bubl
    let isOwnPost: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(bubl.category.title)
                    .font(.bublRounded(.caption, weight: .semibold))
                    .foregroundStyle(BublPalette.ornament)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())

                Spacer()

                Text(isOwnPost ? uiText("Tu post", "Your post") : uiText("Esta semana", "This week"))
                    .font(.bublRounded(.caption))
                    .foregroundStyle(BublPalette.muted)
            }

            Text(bubl.feelingText)
                .font(.bublRounded(.body, weight: .medium))
                .foregroundStyle(BublPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(bubl.activityText)
                .font(.bublRounded(.footnote))
                .foregroundStyle(BublPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(BublPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BublPalette.accent.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.bublRounded(.headline, weight: .semibold))
                .foregroundStyle(BublPalette.ink)
            Text(subtitle)
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)
        }
    }
}

private struct LockedBubbleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiText("Tu burbuja todavía no se abrió.", "Your bubble hasn't opened yet."))
                .font(.bublRounded(.headline, weight: .semibold))
                .foregroundStyle(BublPalette.ink)
            Text(uiText("Compartí lo que estás viviendo esta semana y te mostramos personas en algo parecido.", "Share what you're going through this week and we'll show you people in something similar."))
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)
        }
        .padding(20)
        .background(BublPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct EmptyBubbleCard: View {
    let category: BublCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiText("Todavía no encontramos otras personas en algo tan parecido esta semana.", "We haven't found other people in something this similar this week yet."))
                .font(.bublRounded(.headline, weight: .semibold))
                .foregroundStyle(BublPalette.ink)
            Text(uiText("Cuando aparezcan, te las vamos a mostrar acá.", "As soon as they show up, we'll display them here."))
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)
        }
        .padding(20)
        .background(BublPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PartialBubbleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(uiText("Por ahora hay pocas voces en esta burbuja.", "For now there are only a few voices in this bubble."))
                .font(.bublRounded(.headline, weight: .semibold))
                .foregroundStyle(BublPalette.ink)
            Text(uiText("Cuando aparezcan más, las vas a ver acá.", "As more show up, you'll see them here."))
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)
        }
        .padding(20)
        .background(BublPalette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct OnboardingRule: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(BublPalette.ink)
            Text(text)
                .font(.bublRounded(.body))
                .foregroundStyle(BublPalette.ink)
        }
    }
}

private struct BublPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bublRounded(.headline, weight: .semibold))
            .foregroundStyle(BublPalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BublPalette.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
