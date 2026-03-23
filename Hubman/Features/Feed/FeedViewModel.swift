import Foundation
import Observation
import OSLog

@Observable
final class FeedViewModel {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bubl",
        category: "FeedSelection"
    )
    private let client = SupabaseConfig.client

    var myBubl: Bubl?
    var feed: [Bubl] = []
    var isLoading = false
    var selectedBubl: Bubl?
    var errorMessage: String?

    var hasPostedThisWeek: Bool { myBubl != nil }

    func refresh(currentUserID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let weekID = WeekID.current()
        let nowString = ISO8601DateFormatter().string(from: .now)

        log("Refreshing related bubls for user=\(currentUserID.uuidString) week=\(weekID)")

        do {
            myBubl = try await client
                .from("bubls")
                .select()
                .eq("user_id", value: currentUserID)
                .eq("week_id", value: weekID)
                .eq("is_active", value: true)
                .eq("is_flagged", value: false)
                .gt("expires_at", value: nowString)
                .order("created_at", ascending: false)
                .limit(1)
                .single()
                .execute()
                .value

            guard let myBubl else {
                log("No own bubl found for current week; skipping related selection")
                feed = []
                errorMessage = nil
                return
            }

            log("Own bubl base id=\(myBubl.id.uuidString) cluster=\(myBubl.clusterLabel ?? "nil") activity=\(myBubl.activityText)")

            if let cluster = normalizedClusterLabel(for: myBubl) {
                feed = try await client
                    .from("bubls")
                    .select()
                    .eq("week_id", value: weekID)
                    .eq("cluster_label", value: cluster)
                    .eq("is_active", value: true)
                    .eq("is_flagged", value: false)
                    .gt("expires_at", value: nowString)
                    .neq("user_id", value: currentUserID)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                log(
                    """
                    Related bubls selected with criterion=cluster_label:\(cluster) count=\(self.feed.count)
                    results=\(self.describe(self.feed))
                    """
                )
            } else {
                log("Own bubl has no cluster_label; related list is empty")
                feed = []
            }

            errorMessage = nil
        } catch {
            log("Failed to refresh related bubls: \(error.localizedDescription)")
            errorMessage = String(localized: "feed.error")
        }
    }

    private func describe(_ bubls: [Bubl]) -> String {
        guard !bubls.isEmpty else { return "[]" }
        return bubls
            .map { "\($0.id.uuidString){cluster=\($0.clusterLabel ?? "nil"), activity=\($0.activityText)}" }
            .joined(separator: ", ")
    }

    private func normalizedClusterLabel(for bubl: Bubl) -> String? {
        guard let cluster = bubl.clusterLabel?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !cluster.isEmpty else {
            return nil
        }
        return cluster
    }

    private func log(_ message: String) {
        print("[FeedSelection] \(message)")
        NSLog("[FeedSelection] %@", message)
        logger.info("\(message, privacy: .public)")
    }
}
