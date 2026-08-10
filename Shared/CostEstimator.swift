import Foundation

/// Turns raw usage buckets into an estimated dollar figure using
/// PricingTable. Pure/testable on purpose — no networking here.
enum CostEstimator {
    struct Result {
        let estimatedDollars: Double
        /// Usage results this couldn't price: unrecognized model ID, or a
        /// service tier this table doesn't model (only "standard" and
        /// "batch" are handled — priority/flex tiers are not).
        let unpricedResultCount: Int
    }

    static func estimate(from buckets: [MessagesUsageBucket], at date: Date = Date()) -> Result {
        var total = 0.0
        var unpriced = 0

        for bucket in buckets {
            for result in bucket.results {
                guard let modelID = result.model,
                      let price = PricingTable.price(for: modelID, at: date) else {
                    unpriced += 1
                    continue
                }

                let tier = result.serviceTier ?? "standard"
                guard tier == "standard" || tier == "batch" else {
                    unpriced += 1
                    continue
                }
                let tierMultiplier = tier == "batch" ? PricingTable.batchDiscountMultiplier : 1.0
                let geoMultiplier = result.inferenceGeo == "us" ? PricingTable.dataResidencyUSMultiplier : 1.0
                let multiplier = tierMultiplier * geoMultiplier

                let uncached = Double(result.uncachedInputTokens ?? 0)
                let cacheRead = Double(result.cacheReadInputTokens ?? 0)
                let cache5m = Double(result.cacheCreation?.ephemeral5mInputTokens ?? 0)
                let cache1h = Double(result.cacheCreation?.ephemeral1hInputTokens ?? 0)
                let output = Double(result.outputTokens ?? 0)

                let tokenCost = (
                    uncached * price.inputPerMTok
                        + cacheRead * price.cacheReadPerMTok
                        + cache5m * price.cacheWrite5mPerMTok
                        + cache1h * price.cacheWrite1hPerMTok
                        + output * price.outputPerMTok
                ) / 1_000_000 * multiplier

                let searches = Double(result.serverToolUse?.webSearchRequests ?? 0)
                let searchCost = (searches / 1000) * PricingTable.webSearchPricePerThousandSearches

                total += tokenCost + searchCost
            }
        }

        return Result(estimatedDollars: total, unpricedResultCount: unpriced)
    }
}
