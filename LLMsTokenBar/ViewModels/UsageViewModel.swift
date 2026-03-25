import Foundation
import SwiftUI

@Observable
final class UsageViewModel {
    var todaySummary: UsageSummary = .zero
    var yesterdaySummary: UsageSummary = .zero
    var providerSummaries: [String: UsageSummary] = [:]
    var lastRefreshed: Date = Date()
    var totalSessions: Int = 0
    var dailyLimit: Double = 0

    private let planSettings = PlanSettings.shared

    var usagePercent: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(todaySummary.estimatedCost / dailyLimit, 1.0)
    }

    var selectedPlan: PlanType {
        get { planSettings.selectedPlan }
        set {
            planSettings.selectedPlan = newValue
            dailyLimit = planSettings.dailyCostLimit
        }
    }

    var customDailyLimit: Double {
        get { planSettings.customDailyLimit }
        set {
            planSettings.customDailyLimit = newValue
            dailyLimit = planSettings.dailyCostLimit
        }
    }

    private let providers: [UsageProvider]
    private let aggregator = UsageAggregator()
    private var watchers: [DirectoryWatcher] = []
    private var timer: Timer?

    init(providers: [UsageProvider] = [ClaudeCodeProvider()]) {
        self.providers = providers
        self.dailyLimit = planSettings.dailyCostLimit
        refresh()
        startWatching()
        startTimer()
    }

    func refresh() {
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
}
