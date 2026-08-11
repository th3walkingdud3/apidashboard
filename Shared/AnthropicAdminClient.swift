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

    /// Fetches cost and token usage for today and month-to-date (UTC) and folds
    /// them into one snapshot for the widget/app to render.
    func fetchSnapshot() async throws -> DashboardSnapshot {
        let now = Date()
        let startOfToday = utcCalendar.startOfDay(for: now)
        let startOfMonth = utcCalendar.date(
            from: utcCalendar.dateComponents([.year, .month], from: now)
        )!

        async let orgTask = fetchOrganization()
        async let costTask = fetchAllCostBuckets(startingAt: startOfMonth, endingAt: now)
        async let usageTask = fetchAllUsageBuckets(startingAt: startOfToday, endingAt: now)

        let organization = try? await orgTask
        let costBuckets = try await costTask
        let usageBuckets = try await usageTask

        // Sum of completed daily buckets. The current UTC day is never
        // included here — the API doesn't return a bucket for it at all
        // until it closes — so this is "month-to-date excluding today,"
        // not "month-to-date as of this second."
        let finalizedMonthToDate = costBuckets.reduce(0.0) { total, bucket in
            total + bucket.results.reduce(0.0) { $0 + $1.amountInDollars }
        }

        let costEstimate = CostEstimator.estimate(from: usageBuckets, at: now)

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
            todayOutputTokens: outputTokens
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
