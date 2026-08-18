import Foundation

/// A lightweight grouping for the day timeline — "Morning Toast" is
/// breakfast, "Leftover Rice" is lunch. Deliberately a fixed enum rather
/// than user-defined categories: this app avoids speculative
/// configurability, and a custom-slot system only earns its complexity if
/// someone actually asks for it (meals-feature-design.md §4.5).
///
/// `Hashable` (MK-4) specifically so a template editor's `Picker(selection:)`
/// can bind directly to a `MealSlot` value rather than round-tripping
/// through `rawValue` — every case has no associated data, so this adds no
/// real behavior beyond what `Equatable` already implies.
public enum MealSlot: String, CaseIterable, Identifiable, Codable, Equatable, Hashable {
    case breakfast, lunch, dinner, snack

    public var id: String { rawValue }

    /// The slot implied by the current time of day, so a new entry can be
    /// defaulted without asking (meals-feature-design.md §4.5: "auto-selected
    /// by time of day"). Boundaries are approximate meal windows, not
    /// user-configurable: before 11:00 is breakfast, before 15:00 lunch,
    /// before 21:00 dinner, otherwise snack.
    public static func current(at date: Date = Date(), calendar: Calendar = .current) -> MealSlot {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case ..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<21: return .dinner
        default: return .snack
        }
    }
}
