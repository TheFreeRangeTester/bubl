import AuthenticationServices
import SwiftUI

private func uiText(_ es: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "es" ? es : en
}

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            switch authManager.state {
            case .loading:
                ProgressView()
                    .tint(BublPalette.ink)
            case .signedOut:
                OnboardingView()
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
                            errorMessage = uiText("No se pudo entrar en modo desarrollo.", "Could not enter development mode.")
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

                VStack(alignment: .leading, spacing: 10) {
                    Text(uiText("Config dev", "Dev config"))
                        .font(.bublRounded(.footnote, weight: .semibold))
                        .foregroundStyle(BublPalette.muted)

                    TextField("Supabase URL", text: $devURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.bublRounded(.footnote))
                        .padding(10)
                        .background(BublPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    TextField("Supabase ANON key", text: $devAnonKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.bublRounded(.footnote))
                        .padding(10)
                        .background(BublPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("Guardar config dev") {
                        SupabaseConfig.saveOverrides(
                            url: devURL.trimmingCharacters(in: .whitespacesAndNewlines),
                            anonKey: devAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        errorMessage = "Configuracion guardada."
                    }
                    .font(.bublRounded(.footnote, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
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

private struct FeedView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = FeedViewModel()

    @State private var showingPostFlow = false
    @State private var selectedForReactions: Bubl?
    @State private var selectedForReport: Bubl?

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
                                Text(uiText("Publicá en dos pasos para ver reflexiones de personas que están en algo parecido.", "Post in two steps to see reflections from people in something similar."))
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
            .task { await refreshFeed() }
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
    @State private var showPersonalizingState = false

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
                    } else if step == 2 {
                        Step2View(
                            viewModel: postViewModel,
                            onBack: { step = 1 },
                            onContinue: { step = 3 }
                        )
                    } else {
                        Step3View(
                            viewModel: postViewModel,
                            isSubmitting: postViewModel.isSubmitting,
                            onBack: { step = 2 },
                            onShare: submit
                        )
                    }
                }

                if showPersonalizingState {
                    PersonalizingBubbleView()
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.88), value: showPersonalizingState)
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
            withAnimation {
                showPersonalizingState = true
            }
            let posted = await postViewModel.share(currentUserID: userID)
            if posted {
                onPosted()
                dismiss()
            } else {
                withAnimation {
                    showPersonalizingState = false
                }
            }
        }
    }
}

private struct PersonalizingBubbleView: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(BublPalette.accentSoft)
                    .frame(width: 126, height: 126)
                    .scaleEffect(animate ? 1.06 : 0.94)

                Circle()
                    .fill(BublPalette.card)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(BublPalette.ink)
                    )
                    .offset(y: animate ? -3 : 3)

                Circle()
                    .fill(BublPalette.accentSoft.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .offset(x: -62, y: -34)
                    .offset(y: animate ? -10 : 2)

                Circle()
                    .fill(BublPalette.ink.opacity(0.12))
                    .frame(width: 18, height: 18)
                    .offset(x: 56, y: 26)
                    .offset(y: animate ? 6 : -4)
            }
            .padding(.bottom, 8)

            VStack(spacing: 10) {
                Text(uiText("Armando tu burbuja", "Building your bubble"))
                    .font(.bublRounded(.title3, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)
                    .multilineTextAlignment(.center)

                Text(uiText("Estamos buscando personas en algo realmente parecido para que tu feed arranque con mejores señales.", "We're looking for people in something truly similar so your feed starts with better signals."))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(uiText("1. Qué estás viviendo esta semana?", "1. What are you living through this week?"))
                .font(.bublRounded(.title2, weight: .semibold))
                .foregroundStyle(BublPalette.ink)

            Text(uiText("Ejemplo: Estoy retomando piano después de tres años sin tocar.", "Example: I'm getting back to piano after three years without playing."))
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)

            TextEditor(text: $viewModel.step1Text)
                .font(.bublRounded(.body))
                .frame(minHeight: 180)
                .padding(10)
                .background(BublPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if viewModel.step1Text.isEmpty {
                        Text(uiText("¿Qué estás haciendo, atravesando o intentando esta semana?", "What are you doing, going through, or trying this week?"))
                            .font(.bublRounded(.body))
                            .foregroundStyle(BublPalette.muted)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }
                }
                .onChange(of: viewModel.step1Text) {
                    viewModel.trimLimits()
                }

            Text("\(viewModel.step1Text.count)/140")
                .font(.bublRounded(.caption))
                .foregroundStyle(BublPalette.muted)

            Button(String(localized: "common.continue"), action: onContinue)
                .buttonStyle(BublPrimaryButtonStyle())
                .disabled(!viewModel.canContinueStep1)
        }
        .padding(20)
    }
}

private struct Step2View: View {
    @Bindable var viewModel: PostViewModel
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Label("Atras", systemImage: "chevron.left")
                        .font(.bublRounded(.subheadline, weight: .semibold))
                }
                .tint(BublPalette.muted)
                Spacer()
            }

            Text(viewModel.step1Text)
                .font(.bublRounded(.footnote))
                .foregroundStyle(BublPalette.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(BublPalette.accentSoft)
                .clipShape(Capsule())

            Text(uiText("2. ¿Cómo venís con eso?", "2. How are you feeling about it?"))
                .font(.bublRounded(.title2, weight: .semibold))
                .foregroundStyle(BublPalette.ink)

            Text(uiText("Ejemplo: Estoy motivado, pero también frustrado porque olvidé mucho.", "Example: I feel motivated, but also frustrated because I forgot a lot."))
                .font(.bublRounded(.subheadline))
                .foregroundStyle(BublPalette.muted)

            TextEditor(text: $viewModel.step2Text)
                .font(.bublRounded(.body))
                .frame(minHeight: 200)
                .padding(10)
                .background(BublPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if viewModel.step2Text.isEmpty {
                        Text(uiText("¿Qué te genera emocionalmente esta situación?", "How is this situation affecting you emotionally?"))
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

            Button(uiText("Elegir categoría", "Choose category"), action: onContinue)
                .buttonStyle(BublPrimaryButtonStyle())
                .disabled(!viewModel.canContinueStep2)
        }
        .padding(20)
    }
}

private struct Step3View: View {
    @Bindable var viewModel: PostViewModel
    let isSubmitting: Bool
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onBack) {
                        Label("Atras", systemImage: "chevron.left")
                            .font(.bublRounded(.subheadline, weight: .semibold))
                    }
                    .tint(BublPalette.muted)
                    Spacer()
                }

                Text(uiText("3. Elegí una categoría", "3. Choose a category"))
                    .font(.bublRounded(.title2, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                LazyVStack(spacing: 10) {
                    ForEach(BublCategory.allCases) { category in
                        Button {
                            viewModel.selectedCategory = category
                            viewModel.selectedSubcategory = BublSubcategory.defaultOption(for: category)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.title)
                                        .font(.bublRounded(.body, weight: .semibold))
                                    Text(category.subtitle)
                                        .font(.bublRounded(.footnote))
                                        .foregroundStyle(BublPalette.muted)
                                }
                                Spacer()
                                if viewModel.selectedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BublPalette.ink)
                                }
                            }
                            .padding(14)
                            .background(
                                viewModel.selectedCategory == category
                                ? LinearGradient(
                                    colors: [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [BublPalette.card, BublPalette.card],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(
                                        viewModel.selectedCategory == category
                                        ? BublPalette.ornament.opacity(0.22)
                                        : BublPalette.accent.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(uiText("Afiná un poco más", "Narrow it down a bit"))
                        .font(.bublRounded(.headline, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)

                    Text(uiText("Así priorizamos gente en algo más parecido dentro de \(viewModel.selectedCategory.title.lowercased()).", "This helps us prioritize people in something more similar within \(viewModel.selectedCategory.title.lowercased())."))
                        .font(.bublRounded(.footnote))
                        .foregroundStyle(BublPalette.muted)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(BublSubcategory.options(for: viewModel.selectedCategory)) { subcategory in
                            Button {
                                viewModel.selectedSubcategory = subcategory
                            } label: {
                                Text(subcategory.title)
                                    .font(.bublRounded(.footnote, weight: .semibold))
                                    .foregroundStyle(BublPalette.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 10)
                                    .background(
                                        LinearGradient(
                                            colors: viewModel.selectedSubcategory == subcategory
                                            ? [BublPalette.accentSoft, BublPalette.accentLime.opacity(0.42)]
                                            : [BublPalette.card, BublPalette.card],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                viewModel.selectedSubcategory == subcategory
                                                ? BublPalette.ornament.opacity(0.22)
                                                : BublPalette.accent.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text(uiText("Preview", "Preview"))
                    .font(.bublRounded(.headline, weight: .semibold))
                    .foregroundStyle(BublPalette.ink)

                BublCardView(
                    bubl: Bubl(
                        id: UUID(),
                        userID: UUID(),
                        activityText: viewModel.step1Text.trimmingCharacters(in: .whitespacesAndNewlines),
                        feelingText: viewModel.step2Text.trimmingCharacters(in: .whitespacesAndNewlines),
                        categoryID: viewModel.selectedCategory.rawValue,
                        subcategoryID: viewModel.selectedSubcategory.rawValue,
                        topicID: nil,
                        languageCode: Locale.current.language.languageCode?.identifier ?? "en",
                        clusterLabel: viewModel.selectedSubcategory.clusterLabel,
                        weekID: WeekID.current(),
                        createdAt: .now,
                        expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now,
                        isActive: true,
                        isFlagged: false
                    ),
                    isOwnPost: false
                )

                Button(action: onShare) {
                    if isSubmitting {
                        ProgressView()
                            .tint(BublPalette.ink)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(uiText("Publicar", "Post"))
                    }
                }
                .buttonStyle(BublPrimaryButtonStyle())
                .disabled(!viewModel.canShare || isSubmitting)
            }
            .padding(20)
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
