import SwiftUI

struct Step2View: View {
    @Bindable var viewModel: PostViewModel
    let isSubmitting: Bool
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Label(String(localized: "common.back"), systemImage: "chevron.left")
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

            Text(String(localized: "post.step2.title"))
                .font(.bublRounded(.title2, weight: .semibold))
                .foregroundStyle(BublPalette.ink)

            TextEditor(text: $viewModel.step2Text)
                .font(.bublRounded(.body))
                .frame(minHeight: 200)
                .padding(10)
                .background(BublPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if viewModel.step2Text.isEmpty {
                        Text(String(localized: "post.step2.placeholder"))
                            .font(.bublRounded(.body))
                            .foregroundStyle(BublPalette.muted)
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                    }
                }
                .onChange(of: viewModel.step2Text) {
                    viewModel.trimLimits()
                }

            Text("\(viewModel.step2Text.count)/200")
                .font(.bublRounded(.caption))
                .foregroundStyle(BublPalette.muted)

            Button(action: onShare) {
                if isSubmitting {
                    ProgressView()
                        .tint(BublPalette.ink)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(String(localized: "post.share"))
                }
            }
            .buttonStyle(BublPrimaryButtonStyle())
            .disabled(!viewModel.canShare || isSubmitting)
        }
        .padding(20)
    }
}
