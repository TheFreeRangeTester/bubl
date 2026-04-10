import AuthenticationServices
import SwiftUI
import UIKit

private func uiText(_ es: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "es" ? es : en
}

private enum BublLogoStyle {
    case full
    case mark
}

private struct BublLogoArtwork: View {
    let width: CGFloat
    let height: CGFloat
    let glow: Bool
    let style: BublLogoStyle

    var body: some View {
        Group {
            if let uiImage = UIImage(named: "BublLogo.png") ?? UIImage(named: "BublLogo") {
                if style == .full {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                        .frame(width: width * 1.18, height: height * 1.18)
                        .offset(y: -height * 0.18)
                        .clipped()
                }
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: min(width, height) * 0.28, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: min(width, height) * 0.22, style: .continuous))
        .shadow(color: glow ? BublPalette.accent.opacity(0.28) : BublPalette.ink.opacity(0.08), radius: glow ? 22 : 8, x: 0, y: glow ? 10 : 4)
    }
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

                BublLogoArtwork(width: 164, height: 164, glow: true, style: .full)

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
                                "No se pudo entrar en modo desarrollo. \(details) [\(SupabaseConfig.diagnostics)]",
                                "Could not enter development mode. \(details) [\(SupabaseConfig.diagnostics)]"
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
    @State private var animateEmptyState = false
    @State private var pulseEmptyHero = false
    @State private var revealOpenedBubble = false
    @State private var revealRelatedBubble = false
    @State private var revealNewVoicesBanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.hasPostedThisWeek {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                showingPostFlow = true
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(uiText("Tu burbuja de esta semana", "Your bubble this week"))
                                            .font(.bublRounded(.headline, weight: .semibold))
                                            .foregroundStyle(BublPalette.ink)

                                        Text(uiText("Abrila con algo simple y honesto. Nosotros encontramos voces que estén en una parecida.", "Open it with something simple and honest. We'll find voices that are in something similar."))
                                            .font(.bublRounded(.subheadline))
                                            .foregroundStyle(BublPalette.ink.opacity(0.76))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer(minLength: 0)

                                    BublLogoArtwork(width: 132, height: 132, glow: false, style: .full)
                                        .scaleEffect(pulseEmptyHero ? 1.0 : 0.985)
                                        .opacity(pulseEmptyHero ? 1.0 : 0.96)
                                        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: pulseEmptyHero)
                                }

                                HStack(spacing: 10) {
                                    FeedPromiseChip(title: uiText("2 pasos", "2 steps"), systemImage: "list.bullet.rectangle")
                                    FeedPromiseChip(title: uiText("Sin chat", "No chat"), systemImage: "bubble.left")
                                    FeedPromiseChip(title: uiText("Esta semana", "This week"), systemImage: "calendar")
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text(uiText("Podés empezar por algo así:", "You can start with something like:"))
                                        .font(.bublRounded(.footnote, weight: .semibold))
                                        .foregroundStyle(BublPalette.ink.opacity(0.72))

                                    HStack(spacing: 8) {
                                        ForEach([
                                            uiText("practicando guitarra", "practicing guitar"),
                                            uiText("aprendiendo francés", "learning French"),
                                            uiText("atravesando una mudanza", "going through a move")
                                        ], id: \.self) { sample in
                                            Text(sample)
                                                .font(.bublRounded(.caption, weight: .medium))
                                                .foregroundStyle(BublPalette.ink)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 8)
                                                .background(BublPalette.card.opacity(0.82))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }

                                HStack {
                                    Text(uiText("Crear mi bubl", "Create my bubl"))
                                        .font(.bublRounded(.subheadline, weight: .semibold))
                                        .foregroundStyle(BublPalette.ink)

                                    Spacer()

                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(BublPalette.ink)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(22)
                            .background(
                                ZStack {
                                    LinearGradient(
                                        colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.62)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )

                                    Circle()
                                        .fill(BublPalette.card.opacity(0.26))
                                        .frame(width: 180, height: 180)
                                        .offset(x: 120, y: -76)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(BublPalette.ornament.opacity(0.16), lineWidth: 1)
                            )
                            .shadow(color: BublPalette.accent.opacity(0.12), radius: 18, x: 0, y: 10)
                            .scaleEffect(showingPostFlow ? 0.985 : 1)
                        }
                        .buttonStyle(.plain)
                        .opacity(animateEmptyState ? 1 : 0)
                        .offset(y: animateEmptyState ? 0 : 22)
                    }

                    if let mine = viewModel.myBubl {
                        SectionHeader(title: uiText("Tu semana", "Your week"), subtitle: uiText("Esto es lo que compartiste para abrir tu burbuja.", "This is what you shared to open your bubble."))
                        BublCardView(bubl: mine, isOwnPost: true)
                            .opacity(revealOpenedBubble ? 1 : 0)
                            .offset(y: revealOpenedBubble ? 0 : 18)
                    }

                    if let mine = viewModel.myBubl {
                        VStack(alignment: .leading, spacing: 16) {
                            if viewModel.hasUnseenRelatedBubls && revealNewVoicesBanner {
                                NewVoicesBanner(count: viewModel.newRelatedCount)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

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
                                ForEach(Array(viewModel.feed.enumerated()), id: \.element.id) { index, bubl in
                                    BublCardView(bubl: bubl, isOwnPost: false)
                                        .onTapGesture { selectedForReactions = bubl }
                                        .onLongPressGesture { selectedForReport = bubl }
                                        .opacity(revealRelatedBubble ? 1 : 0)
                                        .offset(y: revealRelatedBubble ? 0 : 24 + CGFloat(index * 6))
                                }
                            }
                        }
                        .opacity(revealRelatedBubble ? 1 : 0)
                        .offset(y: revealRelatedBubble ? 0 : 26)
                    } else {
                        LockedBubbleCard()
                            .opacity(animateEmptyState ? 1 : 0)
                            .offset(y: animateEmptyState ? 0 : 30)
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
            .task {
                guard !animateEmptyState else { return }
                withAnimation(.spring(response: 0.52, dampingFraction: 0.88).delay(0.08)) {
                    animateEmptyState = true
                }
                pulseEmptyHero = true
            }
            .onChange(of: scenePhase) {
                guard scenePhase == .active, hasLoadedFeedOnce else { return }
                Task {
                    await refreshFeed()
                }
            }
            .onChange(of: viewModel.myBubl?.id) {
                if viewModel.myBubl == nil {
                    revealOpenedBubble = false
                    revealRelatedBubble = false
                    revealNewVoicesBanner = false
                    return
                }

                revealOpenedBubble = false
                revealRelatedBubble = false

                withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                    revealOpenedBubble = true
                }

                withAnimation(.spring(response: 0.52, dampingFraction: 0.9).delay(0.12)) {
                    revealRelatedBubble = true
                }
            }
            .onChange(of: viewModel.newRelatedCount) {
                guard viewModel.hasUnseenRelatedBubls else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        revealNewVoicesBanner = false
                    }
                    return
                }

                revealNewVoicesBanner = false
                withAnimation(.spring(response: 0.46, dampingFraction: 0.88).delay(0.08)) {
                    revealNewVoicesBanner = true
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
                BublLogoArtwork(width: 170, height: 170, glow: true, style: .full)
                    .scaleEffect(animate ? 1.04 : 0.96)

                Circle()
                    .fill(BublPalette.accentSoft.opacity(0.8))
                    .frame(width: 34, height: 34)
                    .offset(x: -86, y: -48)
                    .offset(y: animate ? -12 : 5)

                Circle()
                    .fill(BublPalette.ink.opacity(0.12))
                    .frame(width: 24, height: 24)
                    .offset(x: 78, y: 28)
                    .offset(y: animate ? 10 : -4)

                Circle()
                    .fill(BublPalette.card.opacity(0.84))
                    .frame(width: 22, height: 22)
                    .offset(x: 70, y: -44)
                    .offset(y: animate ? -8 : 6)

                Circle()
                    .fill(BublPalette.accentLime.opacity(0.32))
                    .frame(width: 18, height: 18)
                    .offset(x: -62, y: 56)
                    .offset(y: animate ? 7 : -3)
            }
            .padding(.bottom, 8)

            VStack(spacing: 10) {
                Text(uiText("Estamos armando tu burbuja de esta semana", "We're shaping your bubble for this week"))
                    .font(.bublRounded(.title3, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.bublRounded(.body))
                    .foregroundStyle(BublPalette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(BublPalette.ink.opacity(0.18 + (animate ? Double(index) * 0.12 : 0.04)))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.0 + (Double(index) * 0.08) : 0.82)
                }
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BublPalette.page.opacity(0.96).ignoresSafeArea())
        .task {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct Step1View: View {
    @Bindable var viewModel: PostViewModel
    let onContinue: () -> Void
    @State private var showsPresetPicker = true

    private var isChoosingAction: Bool {
        showsPresetPicker || viewModel.selectedPreset == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StepFlowHeader(
                    eyebrow: uiText("Paso 1 de 2", "Step 1 of 2"),
                    title: uiText("Abramos de qué va tu burbuja", "Let's open what your bubble is about"),
                    subtitle: uiText("Primero marcamos la acción. Después completás el qué para que el interés quede bien claro.", "First we anchor the action. Then you fill in the what so the interest feels precise."),
                    progress: 0.5,
                    accentIcon: "sparkles"
                )

                ZStack {
                    if isChoosingAction {
                        ComposerCard {
                            BubblePrompt(
                                title: uiText("Estoy...", "I'm..."),
                                subtitle: uiText("Tocá para elegir la acción que más se parezca a lo tuyo", "Tap to choose the action that feels closest to your situation")
                            )

                            if let selectedPreset = viewModel.selectedPreset, !showsPresetPicker {
                                Text(selectedPreset.label)
                                    .font(.bublRounded(.subheadline, weight: .semibold))
                                    .foregroundStyle(BublPalette.ink)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(BublPalette.accentSoft)
                                    .clipShape(Capsule())
                            }

                            if showsPresetPicker {
                                BubbleOptionCloud(
                                    presets: PostViewModel.ActivityPreset.allCases,
                                    selectedPreset: viewModel.selectedPreset
                                ) { preset in
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                                        viewModel.applyPreset(preset)
                                        showsPresetPicker = false
                                    }
                                }
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                    } else if let selectedPreset = viewModel.selectedPreset {
                        ComposerCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text(uiText("Ahora completá el qué.", "Now fill in the what."))
                                        .font(.bublRounded(.headline, weight: .semibold))
                                        .foregroundStyle(BublPalette.ink)

                                    Spacer()

                                    Button(uiText("Cambiar", "Change")) {
                                        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
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
                                                Text(uiText("guitarra, francés, una serie nueva, un side project, mi mudanza...", "guitar, French, a new show, a side project, my move..."))
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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                    }
                }
                .animation(.spring(response: 0.36, dampingFraction: 0.88), value: isChoosingAction)

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

                StepFlowHeader(
                    eyebrow: uiText("Paso 2 de 2", "Step 2 of 2"),
                    title: uiText("Dale el tono a tu burbuja", "Give your bubble its tone"),
                    subtitle: uiText("Acá entra cómo te está pegando. Eso ayuda a que el espacio se sienta más cercano a vos.", "This is where how it feels comes in. It helps the space feel closer to what you're going through."),
                    progress: 1.0,
                    accentIcon: "heart.text.square"
                )

                ComposerCard {
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
                }

                Button(action: onShare) {
                    if isSubmitting {
                        ProgressView()
                            .tint(BublPalette.ink)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(uiText("Abrir mi burbuja", "Open my bubble"))
                    }
                }
                .buttonStyle(BublPrimaryButtonStyle())
                .disabled(!viewModel.canShare || isSubmitting)
            }
            .padding(20)
        }
    }
}

private struct StepFlowHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let progress: CGFloat
    let accentIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(BublPalette.accentSoft)
                        .frame(width: 74, height: 74)

                    BublLogoArtwork(width: 92, height: 92, glow: false, style: .mark)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow.uppercased())
                        .font(.bublRounded(.caption, weight: .semibold))
                        .foregroundStyle(BublPalette.muted)

                    Text(title)
                        .font(.bublRounded(.title3, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                }
            }

            Text(subtitle)
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(BublPalette.card)
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(proxy.size.width * progress, 10), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [BublPalette.card, BublPalette.accentSoft.opacity(0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topTrailing) {
            BublLogoArtwork(width: 46, height: 46, glow: false, style: .mark)
                .opacity(0.18)
                .offset(x: 8, y: -8)
        }
    }
}

private struct ComposerCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [BublPalette.card.opacity(0.98), BublPalette.card.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(BublPalette.ornament.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: BublPalette.ink.opacity(0.04), radius: 18, x: 0, y: 10)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
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

                    Text(isOwnPost ? uiText("Tu post", "Your post") : uiText("Esta semana", "This week"))
                        .font(.bublRounded(.caption, weight: .semibold))
                        .foregroundStyle(isOwnPost ? BublPalette.ink.opacity(0.62) : BublPalette.muted)
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(isOwnPost ? BublPalette.card.opacity(0.88) : BublPalette.accentSoft.opacity(0.56))
                        .frame(width: 42, height: 42)

                    Image(systemName: isOwnPost ? "sparkles" : "bubble.left.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BublPalette.ink.opacity(isOwnPost ? 0.92 : 0.7))
                }
            }

            Text(bubl.feelingText)
                .font(.bublRounded(.body, weight: .semibold))
                .foregroundStyle(BublPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text(uiText("Esto viene de", "This comes from"))
                    .font(.bublRounded(.caption, weight: .semibold))
                    .foregroundStyle(BublPalette.muted)

                Text(bubl.activityText)
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                isOwnPost
                    ? BublPalette.card.opacity(0.72)
                    : BublPalette.page.opacity(0.7)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(20)
        .background(
            Group {
                if isOwnPost {
                    LinearGradient(
                        colors: [BublPalette.card, BublPalette.accentSoft.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    LinearGradient(
                        colors: [BublPalette.card, BublPalette.card.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isOwnPost ? BublPalette.accent.opacity(0.16) : BublPalette.accent.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: isOwnPost ? BublPalette.accent.opacity(0.12) : Color.black.opacity(0.05), radius: isOwnPost ? 16 : 10, x: 0, y: isOwnPost ? 10 : 6)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BublPalette.accentSoft, BublPalette.card],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(uiText("Tu burbuja todavía no se abrió.", "Your bubble hasn't opened yet."))
                        .font(.bublRounded(.headline, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)
                    Text(uiText("Primero compartís lo tuyo. Después aparece la gente más parecida a eso.", "You share yours first. Then the people closest to that start showing up."))
                        .font(.bublRounded(.subheadline))
                        .foregroundStyle(BublPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                FeedStepRow(
                    number: "1",
                    title: uiText("Elegí una acción", "Pick an action"),
                    subtitle: uiText("aprendiendo, practicando, viendo, atravesando...", "learning, practicing, watching, going through...")
                )
                FeedStepRow(
                    number: "2",
                    title: uiText("Completá el qué", "Fill in the what"),
                    subtitle: uiText("guitarra, francés, una serie, una mudanza...", "guitar, French, a show, a move...")
                )
                FeedStepRow(
                    number: "3",
                    title: uiText("Aparece tu burbuja", "Your bubble opens"),
                    subtitle: uiText("y empezamos a mostrarte voces parecidas", "and we start showing similar voices")
                )
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [BublPalette.card, BublPalette.card.opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(BublPalette.accent.opacity(0.10), lineWidth: 1)
        )
    }
}

private struct FeedPromiseChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.bublRounded(.caption, weight: .semibold))
        }
        .foregroundStyle(BublPalette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BublPalette.card.opacity(0.76))
        .clipShape(Capsule())
    }
}

private struct FeedStepRow: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.bublRounded(.caption, weight: .bold))
                .foregroundStyle(BublPalette.ink)
                .frame(width: 24, height: 24)
                .background(BublPalette.accentSoft)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.bublRounded(.subheadline, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
                Text(subtitle)
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)
            }
        }
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

private struct NewVoicesBanner: View {
    let count: Int

    private var titleText: String {
        if Locale.current.language.languageCode?.identifier == "es" {
            return count == 1
                ? "Tu bubl sumó 1 voz nueva"
                : "Tu bubl sumó \(count) voces nuevas"
        }

        return count == 1
            ? "Your bubl has 1 new voice"
            : "Your bubl has \(count) new voices"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(BublPalette.accentSoft)
                    .frame(width: 34, height: 34)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.bublRounded(.subheadline, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                Text(uiText("Aparecieron desde la última vez que abriste tu burbuja.", "These showed up since the last time you opened your bubble."))
                    .font(.bublRounded(.footnote))
                    .foregroundStyle(BublPalette.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [BublPalette.card, BublPalette.accentSoft.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(BublPalette.ornament.opacity(0.12), lineWidth: 1)
        )
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
