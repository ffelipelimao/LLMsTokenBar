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
    var apiError: String? = nil

    private let providers: [UsageProvider]
    private let aggregator = UsageAggregator()
    private let usageAPI = ClaudeUsageAPI()
    private var watchers: [DirectoryWatcher] = []
    private var localTimer: Timer?
    private var apiTimer: Timer?
    private var lastAPICall: Date = .distantPast

    // 5 minutes between API calls to avoid rate limiting
    private let apiInterval: TimeInterval = 300

    init(providers: [UsageProvider] = [ClaudeCodeProvider()]) {
        self.providers = providers
        refreshLocal()
        Task { @MainActor in
            await refreshFromAPI()
        }
        startWatching()
        startTimers()
    }

    /// Called by Refresh button — refreshes local + forces API call
    func refreshAll() {
        refreshLocal()
        lastAPICall = .distantPast  // reset cooldown
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
        guard Date().timeIntervalSince(lastAPICall) >= apiInterval else { return }
        lastAPICall = Date()

        guard let limits = await usageAPI.fetchUsage() else {
            apiError = "Rate limited or unavailable"
            return
        }

        apiError = nil

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
                // Directory changes only refresh local data, NOT the API
                self?.refreshLocal()
            }) {
                watchers.append(watcher)
            }
        }
    }

    private func startTimers() {
        // Local data: every 60 seconds
        localTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshLocal()
        }
        // API: every 5 minutes
        apiTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshFromAPI()
            }
        }
    }

    func timeUntilReset(_ date: Date?) -> String {
        guard let date = date else { return "--" }
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "expired" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
