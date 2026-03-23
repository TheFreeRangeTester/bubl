import SwiftUI

struct Step1View: View {
    @Bindable var viewModel: PostViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "post.step1.title"))
                .font(.bublRounded(.title2, weight: .semibold))
                .foregroundStyle(BublPalette.ink)

            TextEditor(text: $viewModel.step1Text)
                .font(.bublRounded(.body))
                .frame(minHeight: 180)
                .padding(10)
                .background(BublPalette.card)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if viewModel.step1Text.isEmpty {
                        Text(String(localized: "post.step1.placeholder"))
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

struct BublPrimaryButtonStyle: ButtonStyle {
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
