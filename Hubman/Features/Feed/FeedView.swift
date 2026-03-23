import SwiftUI

struct FeedView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = FeedViewModel()

    @State private var showingPostFlow = false
    @State private var selectedForReactions: Bubl?
    @State private var selectedForReport: Bubl?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !viewModel.hasPostedThisWeek {
                        Button {
                            showingPostFlow = true
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(String(localized: "feed.prompt.title"))
                                    .font(.bublRounded(.headline, weight: .semibold))
                                Text(String(localized: "feed.prompt.subtitle"))
                                    .font(.bublRounded(.subheadline))
                                    .foregroundStyle(BublPalette.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .background(BublPalette.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if let mine = viewModel.myBubl {
                        Text(String(localized: "feed.yours"))
                            .font(.bublRounded(.headline, weight: .semibold))
                            .foregroundStyle(BublPalette.ink)
                        BublCardView(bubl: mine)
                            .onTapGesture { selectedForReactions = mine }
                    }

                    Text(feedHeader)
                        .font(.bublRounded(.headline, weight: .semibold))
                        .foregroundStyle(BublPalette.ink)

                    if viewModel.feed.isEmpty {
                        Text(String(localized: "feed.empty"))
                            .font(.bublRounded(.subheadline))
                            .foregroundStyle(BublPalette.muted)
                            .padding(.top, 6)
                    }

                    ForEach(viewModel.feed) { bubl in
                        BublCardView(bubl: bubl)
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
                ReportView(reportedBublID: bubl.id, reportedReactionID: nil)
            }
            .onChange(of: viewModel.hasPostedThisWeek) {
                if !viewModel.hasPostedThisWeek {
                    showingPostFlow = true
                }
            }
            .background(BublPalette.page)
        }
    }

    private var feedHeader: String {
        let cluster = viewModel.myBubl?.clusterLabel ?? String(localized: "feed.cluster.generic")
        return String(localized: "feed.cluster.header \(cluster)")
    }

    private func refreshFeed() async {
        guard let userID = authManager.session?.user.id else { return }
        await viewModel.refresh(currentUserID: userID)
        if !viewModel.hasPostedThisWeek {
            showingPostFlow = true
        }
    }
}

private struct PostFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var postViewModel = PostViewModel()
    @State private var step = 1

    let onPosted: () -> Void

    var body: some View {
        NavigationStack {
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
            .background(BublPalette.page.ignoresSafeArea())
            .alert(String(localized: "post.crisis.title"), isPresented: $postViewModel.showCrisisPrompt) {
                Link(String(localized: "post.crisis.link"), destination: URL(string: "https://ifightdepression.com")!)
                Button(String(localized: "common.dismiss"), role: .cancel) {}
            } message: {
                Text(String(localized: "post.crisis.body"))
            }
            .alert(String(localized: "common.error"), isPresented: .constant(postViewModel.submitError != nil)) {
                Button(String(localized: "common.ok")) { postViewModel.submitError = nil }
            } message: {
                Text(postViewModel.submitError ?? "")
            }
        }
    }

    private func submit() {
        guard let userID = authManager.session?.user.id else { return }

        Task {
            let posted = await postViewModel.share(currentUserID: userID, locale: authManager.userLocale)
            if posted {
                onPosted()
                dismiss()
            }
        }
    }
}
