import Foundation

extension String {
    /// Parses user-typed decimal input, accepting either "." or "," as the
    /// decimal separator. `Double.init?(String)` only ever accepts "." —
    /// but a `.decimalPad` keyboard shows "," as the separator key in many
    /// locales (e.g. German), so typing "5,2" would otherwise silently fail
    /// to parse and the value would be dropped as if never entered.
    var localizedDouble: Double? {
        Double(replacingOccurrences(of: ",", with: "."))
    }
}
