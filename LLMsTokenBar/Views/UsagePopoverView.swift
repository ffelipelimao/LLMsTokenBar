import SwiftUI

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LLM Usage")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Usage limits from Anthropic
            VStack(spacing: 10) {
                UsageLimitBar(
                    label: "Session (5h)",
                    percent: viewModel.fiveHourUtilization,
                    resetText: "Resets in \(viewModel.timeUntilReset(viewModel.fiveHourResetsAt))"
                )

                UsageLimitBar(
                    label: "Weekly (All)",
                    percent: viewModel.sevenDayUtilization,
                    resetText: "Resets in \(viewModel.timeUntilReset(viewModel.sevenDayResetsAt))"
                )

                UsageLimitBar(
                    label: "Weekly (Sonnet)",
                    percent: viewModel.sevenDaySonnetUtilization,
                    resetText: "Resets in \(viewModel.timeUntilReset(viewModel.sevenDaySonnetResetsAt))"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            // Today details
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    TokenPill(label: "IN", value: viewModel.todaySummary.formattedInput, color: .blue)
                    TokenPill(label: "OUT", value: viewModel.todaySummary.formattedOutput, color: .purple)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(viewModel.todaySummary.formattedCost)
                            .font(.system(.body, design: .rounded, weight: .medium))
                        Text("\(viewModel.todaySummary.sessionCount) sessions")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Yesterday
            VStack(alignment: .leading, spacing: 8) {
                Text("Yesterday")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 16) {
                    TokenPill(label: "IN", value: viewModel.yesterdaySummary.formattedInput, color: .blue.opacity(0.6))
                    TokenPill(label: "OUT", value: viewModel.yesterdaySummary.formattedOutput, color: .purple.opacity(0.6))
                    Spacer()
                    Text(viewModel.yesterdaySummary.formattedCost)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Footer
            HStack {
                Text("Updated \(viewModel.lastRefreshed.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Refresh") { viewModel.refresh() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("·")
                    .foregroundStyle(.tertiary)
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }
}

// MARK: - Usage Limit Bar

struct UsageLimitBar: View {
    let label: String
    let percent: Double
    let resetText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                Spacer()
                Text("\(Int(percent))% used")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barGradient)
                        .frame(width: max(geo.size.width * percent / 100.0, 0))
                }
            }
            .frame(height: 8)

            Text(resetText)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var barColor: Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .green
    }

    private var barGradient: LinearGradient {
        if percent >= 90 {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
        if percent >= 70 {
            return LinearGradient(colors: [.green, .orange], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.blue.opacity(0.6), .blue], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Token Pill

struct TokenPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .medium))
        }
    }
}
