import Foundation

struct ClaudeUsageLimits {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?

    struct UsageWindow {
        let utilization: Double  // 0-100
        let resetsAt: Date
    }
}

final class ClaudeUsageAPI {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetchUsage() async -> ClaudeUsageLimits? {
        guard let token = readAccessToken() else { return nil }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        return parseResponse(data)
    }

    private func readAccessToken() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let jsonStr = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let json = try? JSONSerialization.jsonObject(with: Data(jsonStr.utf8)) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    private func parseResponse(_ data: Data) -> ClaudeUsageLimits? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return ClaudeUsageLimits(
            fiveHour: parseWindow(json["five_hour"]),
            sevenDay: parseWindow(json["seven_day"]),
            sevenDaySonnet: parseWindow(json["seven_day_sonnet"])
        )
    }

    private func parseWindow(_ obj: Any?) -> ClaudeUsageLimits.UsageWindow? {
        guard let dict = obj as? [String: Any],
              let utilization = dict["utilization"] as? Double,
              let resetsAtStr = dict["resets_at"] as? String else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: resetsAtStr)
            ?? ISO8601DateFormatter().date(from: resetsAtStr)
            ?? Date()

        return ClaudeUsageLimits.UsageWindow(utilization: utilization, resetsAt: date)
    }
}
