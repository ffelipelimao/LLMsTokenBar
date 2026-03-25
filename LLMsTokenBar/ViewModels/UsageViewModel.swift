import Foundation
import SwiftUI

@Observable
final class UsageViewModel {
    var todaySummary: UsageSummary = .zero
    var yesterdaySummary: UsageSummary = .zero
    var providerSummaries: [String: UsageSummary] = [:]
    var lastRefreshed: Date = Date()
    var totalSessions: Int = 0

    // Real usage limits from Anthropic API
    var fiveHourUtilization: Double = 0
    var fiveHourResetsAt: Date? = nil
    var sevenDayUtilization: Double = 0
    var sevenDayResetsAt: Date? = nil
    var sevenDaySonnetUtilization: Double = 0
    var sevenDaySonnetResetsAt: Date? = nil

    private let providers: [UsageProvider]
    private let aggregator = UsageAggregator()
    private let usageAPI = ClaudeUsageAPI()
    private var watchers: [DirectoryWatcher] = []
    private var timer: Timer?

    init(providers: [UsageProvider] = [ClaudeCodeProvider()]) {
        self.providers = providers
        refresh()
        startWatching()
        startTimer()
    }

    func refresh() {
        refreshLocal()
        Task { @MainActor in
            await refreshFromAPI()
        }
    }

    private func refreshLocal() {
        var allRecords: [TokenUsage] = []
        for provider in providers {
            allRecords.append(contentsOf: provider.fetchUsage())
        }

        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        todaySummary = aggregator.summary(for: allRecords, since: today)
        let yesterdayRecords = allRecords.filter { $0.timestamp >= yesterday && $0.timestamp < today }
        yesterdaySummary = aggregator.summary(for: yesterdayRecords, since: yesterday)

        providerSummaries = aggregator.summariesByProvider(
            for: allRecords,
            since: today,
            providers: providers.map(\.providerType)
        )

        totalSessions = allRecords.count
        lastRefreshed = Date()
    }

    @MainActor
    private func refreshFromAPI() async {
        guard let limits = await usageAPI.fetchUsage() else { return }

        if let fh = limits.fiveHour {
            fiveHourUtilization = fh.utilization
            fiveHourResetsAt = fh.resetsAt
        }
        if let sd = limits.sevenDay {
            sevenDayUtilization = sd.utilization
            sevenDayResetsAt = sd.resetsAt
        }
        if let ss = limits.sevenDaySonnet {
            sevenDaySonnetUtilization = ss.utilization
            sevenDaySonnetResetsAt = ss.resetsAt
        }
        lastRefreshed = Date()
    }

    private func startWatching() {
        for provider in providers {
            guard let dir = provider.watchedDirectory else { continue }
            if let watcher = DirectoryWatcher(directory: dir, callback: { [weak self] in
                self?.refresh()
            }) {
                watchers.append(watcher)
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // Helper for formatting reset times
    func timeUntilReset(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
