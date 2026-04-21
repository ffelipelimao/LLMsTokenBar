import Foundation

struct ContextMetrics: Identifiable {
    let id: String
    let lastMessageContextTokens: Int
    let contextWindowSize: Int
    let model: String?
    let timestamp: Date
    let projectPath: String?

    var fillPercent: Double {
        guard contextWindowSize > 0 else { return 0 }
        return Double(lastMessageContextTokens) / Double(contextWindowSize) * 100.0
    }

    var projectName: String {
        guard let path = projectPath, !path.isEmpty else { return String(id.prefix(8)) }
        return (path as NSString).lastPathComponent
    }
}

struct HallucinationRiskSummary {
    let averageFillPercent: Double
    let maxFillPercent: Double
    let worstSessionId: String?
    let sessionsConsidered: Int

    enum Level: Int, Comparable {
        case low = 0
        case moderate = 1
        case high = 2
        case critical = 3

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var averageLevel: Level { Self.level(for: averageFillPercent) }
    var maxLevel: Level { Self.level(for: maxFillPercent) }

    private static func level(for pct: Double) -> Level {
        if pct >= 90 { return .critical }
        if pct >= 75 { return .high }
        if pct >= 50 { return .moderate }
        return .low
    }

    static let empty = HallucinationRiskSummary(
        averageFillPercent: 0,
        maxFillPercent: 0,
        worstSessionId: nil,
        sessionsConsidered: 0
    )
}
