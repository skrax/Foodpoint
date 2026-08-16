import Testing
@testable import FoodFoundation

@Suite("String.localizedDouble")
struct NumericInputTests {
    @Test("period-decimal input parses normally")
    func periodDecimalParses() {
        #expect("5.2".localizedDouble == 5.2)
    }

    @Test("comma-decimal input parses too")
    func commaDecimalParses() {
        // The actual regression: a decimalPad shows "," as the separator
        // key in many locales (e.g. German), and Double.init?(String)
        // alone silently fails to parse "5,2", dropping the value.
        #expect("5,2".localizedDouble == 5.2)
    }

    @Test("whole numbers parse regardless of separator")
    func wholeNumbersParse() {
        #expect("250".localizedDouble == 250)
    }

    @Test("empty string yields nil")
    func emptyStringYieldsNil() {
        #expect("".localizedDouble == nil)
    }

    @Test("non-numeric text yields nil")
    func nonNumericTextYieldsNil() {
        #expect("abc".localizedDouble == nil)
    }
}
