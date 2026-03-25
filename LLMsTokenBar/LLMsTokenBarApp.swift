import SwiftUI

@main
struct LLMsTokenBarApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            UsagePopoverView(viewModel: viewModel)
        } label: {
            MenuBarLabel(
                summary: viewModel.todaySummary,
                fiveHourPercent: viewModel.fiveHourUtilization,
                sevenDayPercent: viewModel.sevenDayUtilization
            )
        }
        .menuBarExtraStyle(.window)
    }
}
