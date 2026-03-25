import Foundation

final class ClaudeCodeProvider: UsageProvider {
    let name = "Claude Code"
    let providerType = LLMProviderType.claude

    var watchedDirectory: URL? { projectsDirectory }

    private let projectsDirectory: URL

    init() {
        projectsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    func fetchUsage() -> [TokenUsage] {
        let jsonlFiles = findJsonlFiles(in: projectsDirectory)
        return jsonlFiles.compactMap { parseSession(at: $0) }
    }

    private func findJsonlFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            // Only top-level JSONL files (skip subagent files)
            if url.pathExtension == "jsonl" && !url.path.contains("/subagents/") {
                files.append(url)
            }
        }
        return files
    }

    /// Parse a single JSONL session file into a TokenUsage record.
    /// Each line is a JSON object; we sum usage from all assistant messages.
    private func parseSession(at url: URL) -> TokenUsage? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let sessionId = url.deletingPathExtension().lastPathComponent
        var inputTokens = 0
        var outputTokens = 0
        var cacheReadTokens = 0
        var cacheCreationTokens = 0
        var earliestTimestamp: Date?

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            // Extract timestamp from the first message that has one
            if earliestTimestamp == nil, let ts = extractTimestamp(from: obj) {
                earliestTimestamp = ts
            }

            // Sum usage from assistant messages
            guard let message = obj["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                continue
            }

            inputTokens += usage["input_tokens"] as? Int ?? 0
            outputTokens += usage["output_tokens"] as? Int ?? 0
            cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
            cacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
        }

        // Use file modification date as fallback timestamp
        let timestamp = earliestTimestamp ?? fileModificationDate(url) ?? Date.distantPast

        guard inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens > 0 else {
            return nil
        }

        return TokenUsage(
            id: sessionId,
            provider: name,
            timestamp: timestamp,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheReadTokens: cacheReadTokens,
            cacheCreationTokens: cacheCreationTokens,
            model: nil
        )
    }

    private func extractTimestamp(from obj: [String: Any]) -> Date? {
        // Try snapshot timestamp
        if let snapshot = obj["snapshot"] as? [String: Any],
           let ts = snapshot["timestamp"] as? String {
            return parseISO8601(ts)
        }
        // Try message timestamp
        if let message = obj["message"] as? [String: Any],
           let ts = message["timestamp"] as? String {
            return parseISO8601(ts)
        }
        // Try top-level timestamp
        if let ts = obj["timestamp"] as? String {
            return parseISO8601(ts)
        }
        return nil
    }

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func fileModificationDate(_ url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
}
