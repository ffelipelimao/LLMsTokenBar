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
            if let error = viewModel.apiError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

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

            HallucinationRiskList(metrics: viewModel.contextMetrics)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

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
                Button("Refresh") { viewModel.refreshAll() }
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

// MARK: - Hallucination Risk List

struct HallucinationRiskList: View {
    let metrics: [ContextMetrics]

    private var duplicatedNames: Set<String> {
        var counts: [String: Int] = [:]
        for m in metrics { counts[m.projectName, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    private func displayLabel(for metric: ContextMetrics) -> String {
        if duplicatedNames.contains(metric.projectName) {
            return "\(metric.projectName) · \(metric.id.prefix(6))"
        }
        return metric.projectName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hallucination Risk")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if metrics.isEmpty {
                Text("No active sessions today")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(metrics) { metric in
                        HallucinationRiskRow(metric: metric, displayLabel: displayLabel(for: metric))
                    }
                }
            }
        }
    }
}

struct HallucinationRiskRow: View {
    let metric: ContextMetrics
    let displayLabel: String

    private var rowColor: Color {
        let p = metric.fillPercent
        if p >= 90 { return .red }
        if p >= 75 { return .orange }
        if p >= 50 { return .yellow }
        return .green
    }

    private var tokenCaption: String {
        let used = Self.formatTokens(metric.lastMessageContextTokens)
        let window = Self.formatTokens(metric.contextWindowSize)
        if let model = metric.model {
            return "\(used) / \(window) · \(Self.shortModelName(model))"
        }
        return "\(used) / \(window)"
    }

    private var tooltip: String {
        var parts: [String] = [metric.id]
        if let path = metric.projectPath { parts.append(path) }
        if let model = metric.model { parts.append(model) }
        parts.append("\(metric.lastMessageContextTokens.formatted()) / \(metric.contextWindowSize.formatted()) tokens")
        return parts.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(displayLabel)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Text("\(Int(metric.fillPercent))%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(rowColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(rowColor)
                        .frame(width: max(geo.size.width * min(metric.fillPercent, 100) / 100.0, 0))
                }
            }
            .frame(height: 5)

            Text(tokenCaption)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .help(tooltip)
    }

    private static func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            let m = Double(count) / 1_000_000.0
            return m >= 10 ? "\(Int(m))M" : String(format: "%.1fM", m)
        }
        if count >= 1_000 {
            return "\(count / 1_000)K"
        }
        return "\(count)"
    }

    private static func shortModelName(_ raw: String) -> String {
        var s = raw
        if s.hasPrefix("claude-") { s.removeFirst("claude-".count) }
        return s
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
