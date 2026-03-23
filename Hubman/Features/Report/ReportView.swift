import SwiftUI

struct ReportView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    let reportedBublID: UUID?
    let reportedReactionID: UUID?

    @State private var selectedReason = "Offensive"
    @State private var isSubmitting = false
    @State private var showConfirmation = false

    private let client = SupabaseConfig.client

    private let reasons = [
        String(localized: "report.reason.offensive"),
        String(localized: "report.reason.spam"),
        String(localized: "report.reason.harassment"),
        String(localized: "report.reason.other")
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "report.title"))
                    .font(.bublRounded(.title3, weight: .semibold))

                Picker(String(localized: "report.reason.label"), selection: $selectedReason) {
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
            .alert(String(localized: "report.done.title"), isPresented: $showConfirmation) {
                Button(String(localized: "common.ok")) { dismiss() }
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
                    reportedReactionID: reportedReactionID,
                    reason: selectedReason
                )

                _ = try await client
                    .from("reports")
                    .insert(payload)
                    .execute()

                showConfirmation = true
            } catch {
                showConfirmation = true
            }
        }
    }
}
