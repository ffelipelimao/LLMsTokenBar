import Foundation
import SwiftUI
import UserNotifications

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

    // Hallucination risk (context-fill based)
    var hallucinationRisk: HallucinationRiskSummary = .empty
    var contextMetrics: [ContextMetrics] = []

    private let providers: [UsageProvider]
    private let aggregator = UsageAggregator()
    private let usageAPI = ClaudeUsageAPI()
    private var watchers: [DirectoryWatcher] = []
    private var localTimer: Timer?
    private var apiTimer: Timer?
    private var lastAPICall: Date = .distantPast
    private var previousMaxRiskLevel: HallucinationRiskSummary.Level = .low
    private var notificationsAuthorized = false
    private var notificationAuthRequested = false

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
        var allContextMetrics: [ContextMetrics] = []
        let today = Calendar.current.startOfDay(for: Date())
        for provider in providers {
            allRecords.append(contentsOf: provider.fetchUsage())
            allContextMetrics.append(contentsOf: provider.fetchContextMetrics(since: today))
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        todaySummary = aggregator.summary(for: allRecords, since: today)
        let yesterdayRecords = allRecords.filter { $0.timestamp >= yesterday && $0.timestamp < today }
        yesterdaySummary = aggregator.summary(for: yesterdayRecords, since: yesterday)

        providerSummaries = aggregator.summariesByProvider(
            for: allRecords,
            since: today,
            providers: providers.map(\.providerType)
        )

        let newRisk = aggregator.hallucinationRisk(from: allContextMetrics)
        handleRiskChange(previous: hallucinationRisk, next: newRisk)
        hallucinationRisk = newRisk
        contextMetrics = allContextMetrics.sorted { $0.fillPercent > $1.fillPercent }

        totalSessions = allRecords.count
        lastRefreshed = Date()
    }

    private func handleRiskChange(
        previous: HallucinationRiskSummary,
        next: HallucinationRiskSummary
    ) {
        let newLevel = next.maxLevel
        defer { previousMaxRiskLevel = newLevel }
        // Only fire when crossing UP into .high or .critical
        guard newLevel > previousMaxRiskLevel, newLevel >= .high else { return }
        notify(forLevel: newLevel, risk: next)
    }

    private func notify(
        forLevel level: HallucinationRiskSummary.Level,
        risk: HallucinationRiskSummary
    ) {
        requestNotificationAuthorizationIfNeeded { [weak self] authorized in
            guard let self = self, authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = level == .critical
                ? "Hallucination risk: critical"
                : "Hallucination risk: high"
            let pct = Int(risk.maxFillPercent.rounded())
            if let sid = risk.worstSessionId {
                let short = String(sid.prefix(8))
                content.body = "Session \(short) at \(pct)% context — accuracy likely degraded. Consider starting a fresh conversation."
            } else {
                content.body = "Context at \(pct)% — accuracy likely degraded."
            }
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "hallucination-risk-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func requestNotificationAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        if notificationsAuthorized { completion(true); return }
        if notificationAuthRequested { completion(false); return }
        notificationAuthRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationsAuthorized = granted
                completion(granted)
            }
        }
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
