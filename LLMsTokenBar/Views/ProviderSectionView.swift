import SwiftUI

struct ProviderSectionView: View {
    let providerType: LLMProviderType
    let summary: UsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(providerType.displayName, systemImage: providerType.icon)
                .font(.subheadline)
                .bold()

            UsageDetailRow(label: "Input tokens", value: summary.formattedInput)
            UsageDetailRow(label: "Output tokens", value: summary.formattedOutput)
            UsageDetailRow(label: "Sessions", value: "\(summary.sessionCount)")
            UsageDetailRow(label: "Est. cost", value: summary.formattedCost)
        }
    }
}
