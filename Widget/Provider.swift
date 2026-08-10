import WidgetKit

struct DashboardEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardSnapshot?
    var hasAPIKey: Bool = true
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> Void) {
        if context.isPreview {
            completion(DashboardEntry(date: Date(), snapshot: .placeholder))
            return
        }
        let hasKey = KeychainHelper.load()?.isEmpty == false
        completion(DashboardEntry(date: Date(), snapshot: SharedCache.load(), hasAPIKey: hasKey))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> Void) {
        Task {
            let apiKey = KeychainHelper.load()
            var snapshot = SharedCache.load()

            if let apiKey, !apiKey.isEmpty {
                do {
                    let client = AnthropicAdminClient(apiKey: apiKey)
                    let fresh = try await client.fetchSnapshot()
                    SharedCache.save(fresh)
                    snapshot = fresh
                } catch {
                    // Network/auth failure — fall back to the last cached snapshot
                    // (still nil on first-ever run) rather than showing an error UI.
                }
            }

            let entry = DashboardEntry(
                date: Date(),
                snapshot: snapshot,
                hasAPIKey: apiKey?.isEmpty == false
            )

            // Requested cadence — the system throttles further based on its own
            // per-widget refresh budget, this is just an upper bound on our ask.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
