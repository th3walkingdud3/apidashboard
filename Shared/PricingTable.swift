import Foundation

struct ModelPrice {
    let inputPerMTok: Double
    let cacheWrite5mPerMTok: Double
    let cacheWrite1hPerMTok: Double
    let cacheReadPerMTok: Double
    let outputPerMTok: Double
}

/// Client-side copy of Anthropic's published per-token pricing, used to turn
/// live (but dollar-free) token usage into an estimated spend figure — the
/// Cost Report API only ever reports *completed* UTC days, so there is no
/// live dollar figure to read from the server for "today."
///
/// This table is maintained by hand against platform.claude.com/docs/en/about-claude/pricing
/// and will drift if Anthropic changes prices or ships a model this doesn't
/// know about. `asOf` and `sourceURL` exist so the app can tell you when it
/// was last checked and link straight to the source to verify — see
/// ContentView's "Pricing" section.
enum PricingTable {
    /// Last verified against the live pricing page. Update this whenever the
    /// table below is re-checked, even if no numbers changed.
    static let asOf: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static let sourceURL = URL(string: "https://platform.claude.com/docs/en/about-claude/pricing")!

    /// Nudge to re-verify after this many days — pricing isn't guaranteed
    /// stable, and nothing here re-checks itself automatically.
    static let staleAfterDays = 45

    static var isPossiblyStale: Bool {
        let days = Calendar.current.dateComponents([.day], from: asOf, to: Date()).day ?? 0
        return days > staleAfterDays
    }

    /// 1.1x multiplier applies on Claude 4.6+ models when a request pins
    /// inference_geo to "us" instead of the "global" default.
    static let dataResidencyUSMultiplier = 1.1

    /// Batch API: 50% off input and output (and, per Anthropic's FAQ, this
    /// stacks with prompt-caching multipliers rather than replacing them).
    static let batchDiscountMultiplier = 0.5

    static let webSearchPricePerThousandSearches = 10.0

    /// Returns nil for anything not in the table below — callers must treat
    /// that as "can't price this," not as free. See CostEstimator.
    static func price(for modelID: String, at date: Date = Date()) -> ModelPrice? {
        if modelID == "claude-sonnet-5" {
            return date < sonnet5IntroEndsAt ? sonnet5Intro : sonnet5Standard
        }
        return catalog[modelID]
    }

    // Sonnet 5 introductory pricing ends 2026-08-31 (inclusive), UTC.
    private static let sonnet5IntroEndsAt: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    private static let sonnet5Intro = ModelPrice(
        inputPerMTok: 2, cacheWrite5mPerMTok: 2.50, cacheWrite1hPerMTok: 4,
        cacheReadPerMTok: 0.20, outputPerMTok: 10
    )
    private static let sonnet5Standard = ModelPrice(
        inputPerMTok: 3, cacheWrite5mPerMTok: 3.75, cacheWrite1hPerMTok: 6,
        cacheReadPerMTok: 0.30, outputPerMTok: 15
    )

    // Prices as published at `asOf`. Each model is keyed under both its
    // alias and (where one exists) its dated snapshot ID, since it's not
    // documented which form the Admin API's `model` field actually returns.
    private static let catalog: [String: ModelPrice] = {
        let fable5 = ModelPrice(inputPerMTok: 10, cacheWrite5mPerMTok: 12.50, cacheWrite1hPerMTok: 20, cacheReadPerMTok: 1, outputPerMTok: 50)
        let opus5 = ModelPrice(inputPerMTok: 5, cacheWrite5mPerMTok: 6.25, cacheWrite1hPerMTok: 10, cacheReadPerMTok: 0.50, outputPerMTok: 25)
        let opus41 = ModelPrice(inputPerMTok: 15, cacheWrite5mPerMTok: 18.75, cacheWrite1hPerMTok: 30, cacheReadPerMTok: 1.50, outputPerMTok: 75)
        let sonnet46 = ModelPrice(inputPerMTok: 3, cacheWrite5mPerMTok: 3.75, cacheWrite1hPerMTok: 6, cacheReadPerMTok: 0.30, outputPerMTok: 15)
        let haiku45 = ModelPrice(inputPerMTok: 1, cacheWrite5mPerMTok: 1.25, cacheWrite1hPerMTok: 2, cacheReadPerMTok: 0.10, outputPerMTok: 5)
        let haiku35 = ModelPrice(inputPerMTok: 0.80, cacheWrite5mPerMTok: 1, cacheWrite1hPerMTok: 1.60, cacheReadPerMTok: 0.08, outputPerMTok: 4)

        return [
            "claude-fable-5": fable5,
            "claude-mythos-5": fable5,

            "claude-opus-5": opus5,
            "claude-opus-4-8": opus5,
            "claude-opus-4-7": opus5,
            "claude-opus-4-6": opus5,
            "claude-opus-4-5": opus5,
            "claude-opus-4-5-20251101": opus5,

            "claude-opus-4-1": opus41,
            "claude-opus-4-1-20250805": opus41,
            "claude-opus-4-0": opus41,
            "claude-opus-4-20250514": opus41,

            "claude-sonnet-4-6": sonnet46,
            "claude-sonnet-4-5": sonnet46,
            "claude-sonnet-4-5-20250929": sonnet46,
            "claude-sonnet-4-0": sonnet46,
            "claude-sonnet-4-20250514": sonnet46,

            "claude-haiku-4-5": haiku45,
            "claude-haiku-4-5-20251001": haiku45,

            "claude-3-5-haiku-20241022": haiku35,
        ]
    }()
}
