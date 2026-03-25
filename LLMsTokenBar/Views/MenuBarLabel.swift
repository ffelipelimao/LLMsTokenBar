import SwiftUI

struct MenuBarLabel: View {
    let summary: UsageSummary
    let fiveHourPercent: Double
    let sevenDayPercent: Double

    var body: some View {
        Text("\(summary.formattedIO) · \(Int(sevenDayPercent))%")
    }
}
