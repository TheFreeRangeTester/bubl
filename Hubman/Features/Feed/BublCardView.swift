import SwiftUI

struct BublCardView: View {
    let bubl: Bubl

    var body: some View {
        Text(bubl.feelingText)
            .font(.bublRounded(.body))
            .foregroundStyle(BublPalette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(BublPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}
