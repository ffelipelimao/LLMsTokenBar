import SwiftUI

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LLM Usage")
                    .font(.headline)
                Spacer()
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Progress bar section
            VStack(spacing: 8) {
                UsageProgressBar(
                    percent: viewModel.usagePercent,
                    cost: viewModel.todaySummary.estimatedCost,
                    limit: viewModel.dailyLimit
                )

                HStack {
                    Text(viewModel.todaySummary.formattedCost)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    Text("/ \(String(format: "$%.0f", viewModel.dailyLimit))")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.usagePercent * 100))%")
                        .font(.system(.title3, design: .rounded, weight: .medium))
                        .foregroundStyle(barColor(for: viewModel.usagePercent))
                }
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
                        Text("\(viewModel.todaySummary.sessionCount)")
                            .font(.system(.body, design: .rounded, weight: .medium))
                        Text("sessions")
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

            // Settings panel
            if showSettings {
                Divider()
                SettingsSection(viewModel: viewModel)
            }

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

    private func barColor(for percent: Double) -> Color {
        if percent >= 0.9 { return .red }
        if percent >= 0.7 { return .orange }
        return .green
    }
}

// MARK: - Progress Bar

struct UsageProgressBar: View {
    let percent: Double
    let cost: Double
    let limit: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 6)
                    .fill(barGradient)
                    .frame(width: max(geo.size.width * percent, 0))
            }
        }
        .frame(height: 12)
    }

    private var barGradient: LinearGradient {
        if percent >= 0.9 {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
        if percent >= 0.7 {
            return LinearGradient(colors: [.green, .orange], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.green.opacity(0.8), .green], startPoint: .leading, endPoint: .trailing)
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

// MARK: - Settings

struct SettingsSection: View {
    @Bindable var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plan")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Picker("", selection: $viewModel.selectedPlan) {
                ForEach(PlanType.allCases) { plan in
                    Text(plan.displayName).tag(plan)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if viewModel.selectedPlan == .custom {
                HStack {
                    Text("Daily limit:")
                        .font(.caption)
                    TextField("$", value: $viewModel.customDailyLimit, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            Text("Daily limit: \(String(format: "$%.0f", viewModel.dailyLimit))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
