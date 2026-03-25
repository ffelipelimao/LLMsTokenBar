import Foundation

struct UsageSummary {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let sessionCount: Int
    let estimatedCost: Double

    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens }

    var ioTokens: Int { inputTokens + outputTokens }
    var formattedIO: String { Self.formatTokens(ioTokens) }
    var formattedTotal: String { Self.formatTokens(totalTokens) }
    var formattedInput: String { Self.formatTokens(inputTokens) }
    var formattedOutput: String { Self.formatTokens(outputTokens) }
    var formattedCacheRead: String { Self.formatTokens(cacheReadTokens) }
    var formattedCacheCreation: String { Self.formatTokens(cacheCreationTokens) }

    var formattedCost: String {
        String(format: "$%.2f", estimatedCost)
    }

    static let zero = UsageSummary(
        inputTokens: 0, outputTokens: 0,
        cacheReadTokens: 0, cacheCreationTokens: 0,
        sessionCount: 0, estimatedCost: 0
    )

    private static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }
}
