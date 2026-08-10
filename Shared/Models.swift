import Foundation

/// A point-in-time snapshot of spend and usage, computed from the Anthropic
/// Admin API and cached for the widget to render without a network round trip
/// on every timeline reload.
struct DashboardSnapshot: Codable, Equatable {
    let generatedAt: Date
    let organizationName: String?
    let todaySpendDollars: Double
    let monthToDateSpendDollars: Double
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let todayRequestCount: Int

    static let placeholder = DashboardSnapshot(
        generatedAt: Date(),
        organizationName: "Preview Org",
        todaySpendDollars: 4.21,
        monthToDateSpendDollars: 87.53,
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
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case uncachedInputTokens = "uncached_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case outputTokens = "output_tokens"
    }

    var totalInputTokens: Int {
        (uncachedInputTokens ?? 0) + (cacheReadInputTokens ?? 0)
    }
}
