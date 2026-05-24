import Foundation

struct VisualEffects: OptionSet {
    let rawValue: Int
    static let ripple      = VisualEffects(rawValue: 1 << 0)
    static let trail       = VisualEffects(rawValue: 1 << 1)
    static let intensity   = VisualEffects(rawValue: 1 << 2)
    static let columnGlow  = VisualEffects(rawValue: 1 << 3)

    static let none: VisualEffects = []
    static let all: [Self] = [.ripple, .trail, .intensity, .columnGlow]

    var label: String {
        switch self {
        case .ripple:     return "Ripple"
        case .trail:      return "Trail"
        case .intensity:  return "Intensity Ring"
        case .columnGlow: return "Column Glow"
        default:          return ""
        }
    }

    private static let key = "EtherpadVisualEffects"
    static var current: VisualEffects {
        get { VisualEffects(rawValue: UserDefaults.standard.integer(forKey: key)) }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
            NotificationCenter.default.post(name: .visualEffectsChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let visualEffectsChanged = Notification.Name("EtherpadVisualEffectsChanged")
}
