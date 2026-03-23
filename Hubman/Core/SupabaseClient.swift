import Foundation
import Supabase

enum SupabaseConfig {
    static var client: SupabaseClient {
        let urlString = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String) ?? "https://example.supabase.co"
        let anonKey = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? "missing-anon-key"
        let url = URL(string: urlString) ?? URL(string: "https://example.supabase.co")!

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }
}

enum WeekID {
    static func current(for date: Date = .now) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-%02d", year, week)
    }
}
