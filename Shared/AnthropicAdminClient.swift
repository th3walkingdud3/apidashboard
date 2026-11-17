import Foundation

/// Thin client over the Anthropic Admin API's usage & cost reporting endpoints.
/// Requires an Admin API key (`sk-ant-admin...`) — see
/// https://platform.claude.com/docs/en/api/administration-api
struct AnthropicAdminClient {
    let apiKey: String

    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - Public API

    /// Validates the key and returns the organization it belongs to.
    func fetchOrganization() async throws -> OrganizationInfo {
        let request = makeRequest(path: "organizations/me", queryItems: [])
        return try await send(request, as: OrganizationInfo.self)
    }

    /// Fetches cost and token usage for today and month-to-date, and folds
    /// them into one snapshot for the widget/app to render.
    ///
    /// "Today" for token usage (and the live spend estimate derived from it)
    /// uses the device's *local* calendar day — usage_report/messages
    /// supports fine-enough granularity (hourly) to compute that accurately.
    /// "This month" for finalized spend uses the *UTC* calendar month,
    /// because cost_report only ever returns whole UTC-day buckets — there's
    /// no way to ask it for a locally-aligned range. In practice this means
    /// the very edge of the month can be off by at most one day; "today"
    /// resetting at the wrong time of day (the bug this was chasing) would
    /// have happened every single day, so that's the one worth fixing.
    /// How many finalized days the spend sparkline shows, before today's
    /// live estimate is appended as the final point.
    private static let sparklineHistoryDays = 7

    func fetchSnapshot() async throws -> DashboardSnapshot {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let startOfMonth = utcCalendar.date(
            from: utcCalendar.dateComponents([.year, .month], from: now)
        )!
        // cost_report buckets are always keyed at UTC midnight — the
        // historical lookup below has to anchor to *that*, not to local
        // midnight, or every lookup silently misses by the UTC offset.
        let startOfTodayUTC = utcCalendar.startOfDay(for: now)
        let sparklineStart = utcCalendar.date(
            byAdding: .day, value: -Self.sparklineHistoryDays, to: startOfTodayUTC
        )!
        // Cover whichever is further back — the sparkline's trailing window
        // or the start of the calendar month — in one request.
        let costRangeStart = min(startOfMonth, sparklineStart)

        async let orgTask = fetchOrganization()
        async let costTask = fetchAllCostBuckets(startingAt: costRangeStart, endingAt: now)
        async let usageTask = fetchAllUsageBuckets(startingAt: startOfToday, endingAt: now)

        let organization = try? await orgTask
        let costBuckets = try await costTask
        let usageBuckets = try await usageTask

        // Sum of completed daily buckets on/after the start of the current
        // UTC month. The current UTC day is never included — the API
        // doesn't return a bucket for it until it closes — so this is
        // "month-to-date excluding today," not "as of this second."
        let finalizedMonthToDate = costBuckets
            .filter { $0.startingAt >= startOfMonth }
            .reduce(0.0) { total, bucket in
                total + bucket.results.reduce(0.0) { $0 + $1.amountInDollars }
            }

        // Last N finalized days, oldest first, for the sparkline. A day with
        // no bucket at all (no spend, not "still open") is a real $0, not a
        // gap — fill it in rather than compressing the timeline.
        let dailyTotalsByStart = Dictionary(
            costBuckets.map { ($0.startingAt, $0.results.reduce(0.0) { $0 + $1.amountInDollars }) },
            uniquingKeysWith: { first, _ in first }
        )
        // 1...N, not 0..<N: daysAgo=0 would be the current UTC day, which
        // cost_report never has a bucket for — that's not "no spend," it's
        // "not asked yet," and today is already covered by the estimate
        // appended below. Including it would draw a fake zero dip right
        // before today's point.
        var spendHistory: [Double] = (1...Self.sparklineHistoryDays).reversed().map { daysAgo in
            let day = utcCalendar.date(byAdding: .day, value: -daysAgo, to: startOfTodayUTC)!
            return dailyTotalsByStart[day] ?? 0
        }

        let costEstimate = CostEstimator.estimate(from: usageBuckets)
        spendHistory.append(costEstimate.estimatedDollars)

        let inputTokens = usageBuckets.reduce(0) { total, bucket in
            total + bucket.results.reduce(0) { $0 + $1.totalInputTokens }
        }
        let outputTokens = usageBuckets.reduce(0) { total, bucket in
            total + bucket.results.reduce(0) { $0 + ($1.outputTokens ?? 0) }
        }

        return DashboardSnapshot(
            generatedAt: now,
            organizationName: organization?.name,
            finalizedMonthToDateSpendDollars: finalizedMonthToDate,
            estimatedTodaySpendDollars: costEstimate.estimatedDollars,
            unpricedUsageCount: costEstimate.unpricedResultCount,
            todayInputTokens: inputTokens,
            todayOutputTokens: outputTokens,
            spendHistoryDollars: spendHistory
        )
    }

    // MARK: - Paginated fetches

    private func fetchAllCostBuckets(startingAt: Date, endingAt: Date) async throws -> [CostReportBucket] {
        var buckets: [CostReportBucket] = []
        var page: String?
        repeat {
            var items = [
                URLQueryItem(name: "starting_at", value: iso8601(startingAt)),
                URLQueryItem(name: "ending_at", value: iso8601(endingAt)),
                URLQueryItem(name: "bucket_width", value: "1d"),
                URLQueryItem(name: "limit", value: "31"),
            ]
            if let page { items.append(URLQueryItem(name: "page", value: page)) }
            let request = makeRequest(path: "organizations/cost_report", queryItems: items)
            let response = try await send(request, as: CostReportResponse.self)
            buckets.append(contentsOf: response.data)
            page = response.hasMore ? response.nextPage : nil
        } while page != nil
        return buckets
    }

    private func fetchAllUsageBuckets(startingAt: Date, endingAt: Date) async throws -> [MessagesUsageBucket] {
        var buckets: [MessagesUsageBucket] = []
        var page: String?
        repeat {
            var items = [
                URLQueryItem(name: "starting_at", value: iso8601(startingAt)),
                URLQueryItem(name: "ending_at", value: iso8601(endingAt)),
                // Hourly, not daily: the Admin API never returns a "1d" bucket for
                // the still-in-progress current UTC day, so daily granularity made
                // "today" always look like zero usage. Hourly buckets do show up
                // progressively through the day.
                URLQueryItem(name: "bucket_width", value: "1h"),
                URLQueryItem(name: "limit", value: "24"),
                // Needed for CostEstimator to price each result correctly —
                // without grouping, model/service_tier/inference_geo come
                // back null on every result. Array params need the `[]`
                // suffix — plain repeated `group_by=x&group_by=y` 400s.
                URLQueryItem(name: "group_by[]", value: "model"),
                URLQueryItem(name: "group_by[]", value: "service_tier"),
                URLQueryItem(name: "group_by[]", value: "inference_geo"),
            ]
            if let page { items.append(URLQueryItem(name: "page", value: page)) }
            let request = makeRequest(path: "organizations/usage_report/messages", queryItems: items)
            let response = try await send(request, as: MessagesUsageReportResponse.self)
            buckets.append(contentsOf: response.data)
            page = response.hasMore ? response.nextPage : nil
        } while page != nil
        return buckets
    }

    // MARK: - Request plumbing

    private func makeRequest(path: String, queryItems: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AdminAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw AdminAPIError.httpError(status: http.statusCode, message: message)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AdminAPIError.decodingFailed
        }
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
