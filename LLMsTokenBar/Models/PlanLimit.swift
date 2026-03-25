import Foundation

enum PlanType: String, CaseIterable, Identifiable {
    case pro
    case max100
    case max200
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pro: return "Pro ($20/mo)"
        case .max100: return "Max ($100/mo)"
        case .max200: return "Max ($200/mo)"
        case .custom: return "Custom"
        }
    }

    /// Approximate daily cost limit in USD
    /// These are estimates based on typical usage patterns
    var dailyCostLimit: Double {
        switch self {
        case .pro: return 5.0
        case .max100: return 50.0
        case .max200: return 100.0
        case .custom: return 50.0
        }
    }
}

final class PlanSettings {
    static let shared = PlanSettings()

    private let defaults = UserDefaults.standard
    private let planKey = "selectedPlan"
    private let customLimitKey = "customDailyLimit"

    var selectedPlan: PlanType {
        get {
            guard let raw = defaults.string(forKey: planKey),
                  let plan = PlanType(rawValue: raw) else { return .max100 }
            return plan
        }
        set { defaults.set(newValue.rawValue, forKey: planKey) }
    }

    var customDailyLimit: Double {
        get {
            let val = defaults.double(forKey: customLimitKey)
            return val > 0 ? val : 50.0
        }
        set { defaults.set(newValue, forKey: customLimitKey) }
    }

    var dailyCostLimit: Double {
        if selectedPlan == .custom {
            return customDailyLimit
        }
        return selectedPlan.dailyCostLimit
    }
}
