import Foundation

struct UsageAggregator {
    func summary(
        for records: [TokenUsage],
        since date: Date,
        pricing: LLMProviderType = .claude
    ) -> UsageSummary {
        let filtered = records.filter { $0.timestamp >= date }
        let input = filtered.reduce(0) { $0 + $1.inputTokens }
        let output = filtered.reduce(0) { $0 + $1.outputTokens }
        let cacheRead = filtered.reduce(0) { $0 + $1.cacheReadTokens }
        let cacheCreate = filtered.reduce(0) { $0 + $1.cacheCreationTokens }
        let cost = pricing.estimateCost(
            inputTokens: input, outputTokens: output,
            cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate
        )
        return UsageSummary(
            inputTokens: input, outputTokens: output,
            cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate,
            sessionCount: filtered.count, estimatedCost: cost
        )
    }

    func todaySummary(for records: [TokenUsage], pricing: LLMProviderType = .claude) -> UsageSummary {
        summary(for: records, since: Calendar.current.startOfDay(for: Date()), pricing: pricing)
    }

    func weekSummary(for records: [TokenUsage], pricing: LLMProviderType = .claude) -> UsageSummary {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: Date()))!
        return summary(for: records, since: sevenDaysAgo, pricing: pricing)
    }

    func summariesByProvider(
        for records: [TokenUsage],
        since date: Date,
        providers: [LLMProviderType]
    ) -> [String: UsageSummary] {
        var result: [String: UsageSummary] = [:]
        for provider in providers {
            let providerRecords = records.filter { $0.provider == provider.displayName }
            result[provider.rawValue] = summary(for: providerRecords, since: date, pricing: provider)
        }
        return result
    }

    func hallucinationRisk(from metrics: [ContextMetrics]) -> HallucinationRiskSummary {
        guard !metrics.isEmpty else { return .empty }
        let avg = metrics.map(\.fillPercent).reduce(0, +) / Double(metrics.count)
        let worst = metrics.max { $0.fillPercent < $1.fillPercent }
        return HallucinationRiskSummary(
            averageFillPercent: avg,
            maxFillPercent: worst?.fillPercent ?? 0,
            worstSessionId: worst?.id,
            sessionsConsidered: metrics.count
        )
    }
}
