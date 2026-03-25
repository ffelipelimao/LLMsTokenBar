import Foundation

enum LLMProviderType: String, CaseIterable, Identifiable {
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        }
    }

    var icon: String {
        switch self {
        case .claude: return "brain.head.profile"
        }
    }

    // Prices per million tokens (MTok) - Opus pricing
    var inputPricePerMTok: Double {
        switch self {
        case .claude: return 15.0
        }
    }

    var outputPricePerMTok: Double {
        switch self {
        case .claude: return 75.0
        }
    }

    var cacheReadPricePerMTok: Double {
        switch self {
        case .claude: return 1.50  // 90% discount on input
        }
    }

    var cacheCreationPricePerMTok: Double {
        switch self {
        case .claude: return 18.75  // 25% premium on input
        }
    }

    func estimateCost(inputTokens: Int, outputTokens: Int, cacheReadTokens: Int, cacheCreationTokens: Int) -> Double {
        let input = Double(inputTokens) / 1_000_000.0 * inputPricePerMTok
        let output = Double(outputTokens) / 1_000_000.0 * outputPricePerMTok
        let cacheRead = Double(cacheReadTokens) / 1_000_000.0 * cacheReadPricePerMTok
        let cacheCreate = Double(cacheCreationTokens) / 1_000_000.0 * cacheCreationPricePerMTok
        return input + output + cacheRead + cacheCreate
    }
}
