import SwiftUI

struct MenuBarLabel: View {
    let summary: UsageSummary
    let fiveHourPercent: Double
    let sevenDayPercent: Double
    let hallucinationMaxLevel: HallucinationRiskSummary.Level

    var body: some View {
        Text("\(summary.formattedIO) · \(Int(sevenDayPercent))%")
            .foregroundStyle(tint)
    }

    private var tint: Color {
        guard HallucinationRiskSummary.isEnabled else { return .primary }
        switch hallucinationMaxLevel {
        case .critical: return .red
        case .high: return .orange
        case .moderate, .low: return .primary
        }
    }
}
