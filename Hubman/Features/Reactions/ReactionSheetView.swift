import SwiftUI

struct ReactionSheetView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReactionsViewModel()

    let bubl: Bubl

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(bubl.feelingText)
                    .font(.bublRounded(.body, weight: .medium))
                    .foregroundStyle(BublPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(BublPalette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if viewModel.reactions.isEmpty {
                    Text(String(localized: "reactions.empty"))
                        .font(.bublRounded(.subheadline))
                        .foregroundStyle(BublPalette.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.reactions) { reaction in
                                Text(reaction.text)
                                    .font(.bublRounded(.body))
                                    .foregroundStyle(BublPalette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(BublPalette.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField(String(localized: "reactions.placeholder"), text: $viewModel.draft, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.bublRounded(.body))
                        .padding(12)
                        .background(BublPalette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: viewModel.draft) {
                            if viewModel.draft.count > 120 {
                                viewModel.draft = String(viewModel.draft.prefix(120))
                            }
                        }

                    Button(String(localized: "common.send")) {
                        submit()
                    }
                    .buttonStyle(BublPrimaryButtonStyle())
                    .frame(width: 90)
                }
            }
            .padding(16)
            .navigationTitle(String(localized: "reactions.title"))
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

    private func submit() {
        guard let userID = authManager.session?.user.id else { return }
        Task {
            await viewModel.submit(bublID: bubl.id, userID: userID)
        }
    }
}
