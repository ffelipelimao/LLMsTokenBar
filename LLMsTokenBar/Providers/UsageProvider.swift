import Foundation

protocol UsageProvider {
    var name: String { get }
    var providerType: LLMProviderType { get }
    var watchedDirectory: URL? { get }
    func fetchUsage() -> [TokenUsage]
}
