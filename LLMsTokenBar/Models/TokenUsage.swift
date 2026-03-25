import Foundation

struct TokenUsage: Identifiable {
    let id: String
    let provider: String
    let timestamp: Date
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let model: String?

    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens }
}
