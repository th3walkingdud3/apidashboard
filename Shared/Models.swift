import Foundation

/// A point-in-time snapshot of spend and usage, computed from the Anthropic
/// Admin API and cached for the widget to render without a network round trip
/// on every timeline reload.
struct DashboardSnapshot: Codable, Equatable {
    let generatedAt: Date
    let organizationName: String?

    /// Sum of *completed* UTC-day cost_report buckets this month. Excludes
    /// today by construction — the Admin API never returns a bucket for the
    /// still-in-progress current day, so this figure alone under-reports.
    let finalizedMonthToDateSpendDollars: Double

    /// Client-computed estimate for today, since cost_report has no live
    /// figure: today's token usage (from the hourly usage endpoint) priced
    /// against PricingTable. Not authoritative — see unpricedUsageCount.
    let estimatedTodaySpendDollars: Double

    /// Count of usage results this snapshot couldn't price (unrecognized
    /// model ID, or a service tier/geo combination not in PricingTable).
    /// Nonzero means estimatedTodaySpendDollars is a floor, not exact.
    let unpricedUsageCount: Int

    let todayInputTokens: Int
    let todayOutputTokens: Int
    let todayRequestCount: Int

    /// "This month, including today's live estimate" — the headline figure.
    var monthToDateSpendDollars: Double {
        finalizedMonthToDateSpendDollars + estimatedTodaySpendDollars
    }

    static let placeholder = DashboardSnapshot(
        generatedAt: Date(),
        organizationName: "Preview Org",
        finalizedMonthToDateSpendDollars: 83.32,
        estimatedTodaySpendDollars: 4.21,
        unpricedUsageCount: 0,
        todayInputTokens: 812_000,
        todayOutputTokens: 143_000,
        todayRequestCount: 214
    )
}

enum AdminAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(status: Int, message: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Admin API key saved yet."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .httpError(let status, let message):
            return "Anthropic API error (\(status)): \(message)"
        case .decodingFailed:
            return "Couldn't parse the API response."
        }
    }
}

// MARK: - /v1/organizations/me

struct OrganizationInfo: Decodable {
    let id: String
    let name: String
}

// MARK: - /v1/organizations/cost_report

struct CostReportResponse: Decodable {
    let data: [CostReportBucket]
    let hasMore: Bool
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

struct CostReportBucket: Decodable {
    let startingAt: Date
    let endingAt: Date
    let results: [CostReportResult]

    enum CodingKeys: String, CodingKey {
        case startingAt = "starting_at"
        case endingAt = "ending_at"
        case results
    }
}

struct CostReportResult: Decodable {
    /// Cost in lowest currency units (cents) as a decimal string, e.g.
    /// "123.78912" for USD means $1.2378912. Divide by 100 for dollars.
    let amount: String
    let currency: String

    var amountInDollars: Double {
        (Double(amount) ?? 0) / 100
    }
}

// MARK: - /v1/organizations/usage_report/messages

struct MessagesUsageReportResponse: Decodable {
    let data: [MessagesUsageBucket]
    let hasMore: Bool
    let nextPage: String?

    enum CodingKeys: String, CodingKey {
        case data
        case hasMore = "has_more"
        case nextPage = "next_page"
    }
}

struct MessagesUsageBucket: Decodable {
    let startingAt: Date
    let endingAt: Date
    let results: [MessagesUsageResult]

    enum CodingKeys: String, CodingKey {
        case startingAt = "starting_at"
        case endingAt = "ending_at"
        case results
    }
}

struct MessagesUsageResult: Decodable {
    let uncachedInputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreation: CacheCreation?
    let outputTokens: Int?
    let model: String?
    let serviceTier: String?
    let inferenceGeo: String?
    let serverToolUse: ServerToolUse?

    enum CodingKeys: String, CodingKey {
        case uncachedInputTokens = "uncached_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreation = "cache_creation"
        case outputTokens = "output_tokens"
        case model
        case serviceTier = "service_tier"
        case inferenceGeo = "inference_geo"
        case serverToolUse = "server_tool_use"
    }

    /// All input tokens processed this bucket, including cache writes —
    /// for the "tokens today" display, not for cost math (see CostEstimator,
    /// which prices each token category at its own rate).
    var totalInputTokens: Int {
        (uncachedInputTokens ?? 0)
            + (cacheReadInputTokens ?? 0)
            + (cacheCreation?.ephemeral5mInputTokens ?? 0)
            + (cacheCreation?.ephemeral1hInputTokens ?? 0)
    }
}

struct CacheCreation: Decodable {
    let ephemeral1hInputTokens: Int?
    let ephemeral5mInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
        case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
    }
}

struct ServerToolUse: Decodable {
    let webSearchRequests: Int?

    enum CodingKeys: String, CodingKey {
        case webSearchRequests = "web_search_requests"
    }
}
