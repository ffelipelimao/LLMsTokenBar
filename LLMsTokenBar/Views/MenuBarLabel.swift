import SwiftUI

struct MenuBarLabel: View {
    let summary: UsageSummary
    let usagePercent: Double

    var body: some View {
        Text("\(summary.formattedIO) / \(summary.formattedCost) (\(Int(usagePercent * 100))%)")
    }
}
