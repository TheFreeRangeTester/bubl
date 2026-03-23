import SwiftUI

@main
struct HubmanApp: App {
    @State private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .preferredColorScheme(.light)
                .task {
                    await authManager.restoreSession()
                }
        }
    }
}

enum BublPalette {
    static let page = Color(red: 0.91, green: 0.98, blue: 0.97)
    static let card = Color(red: 0.97, green: 1.00, blue: 0.99)
    static let accent = Color(red: 0.13, green: 0.72, blue: 0.79)
    static let accentSoft = Color(red: 0.74, green: 0.93, blue: 0.94)
    static let accentLime = Color(red: 0.56, green: 0.86, blue: 0.39)
    static let ornament = Color(red: 0.37, green: 0.29, blue: 0.66)
    static let ink = Color(red: 0.09, green: 0.23, blue: 0.27)
    static let muted = Color(red: 0.36, green: 0.49, blue: 0.53)
}

extension Font {
    static func bublRounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}
