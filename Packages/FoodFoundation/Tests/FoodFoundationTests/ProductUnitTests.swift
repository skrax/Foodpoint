import Testing
@testable import FoodFoundation

@Suite("ProductUnit")
struct ProductUnitTests {
    @Test("count mode derives grams-per-unit from weight and count")
    func countModeDerivesGramsPerUnit() {
        let unit = ProductUnit.make(mode: .count, packageWeight: 750, countLabel: "slices", countPerPackage: 15)
        #expect(unit.label == "slices")
        #expect(unit.quantityPerPackage == 15)
        #expect(unit.gramsPerUnit == 50)
        #expect(unit.trackingMode == .count)
        #expect(unit.packageWeight == 750)
    }

    @Test("weight mode always uses grams with a 1:1 ratio")
    func weightModeUsesGrams() {
        let unit = ProductUnit.make(mode: .weight, packageWeight: 500, countLabel: "ignored", countPerPackage: nil)
        #expect(unit.label == "g")
        #expect(unit.quantityPerPackage == 500)
        #expect(unit.gramsPerUnit == 1)
        #expect(unit.trackingMode == .weight)
        #expect(unit.packageWeight == 500)
    }

    @Test("count mode with no weight leaves grams-per-unit unknown")
    func countModeWithoutWeightHasNoGramsPerUnit() {
        let unit = ProductUnit.make(mode: .count, packageWeight: nil, countLabel: "bars", countPerPackage: 20)
        #expect(unit.gramsPerUnit == nil)
        #expect(unit.packageWeight == nil)
    }

    @Test("non-positive inputs fall back to 1 rather than zero/negative")
    func nonPositiveInputsFallBackToOne() {
        let weight = ProductUnit.make(mode: .weight, packageWeight: -5, countLabel: "", countPerPackage: nil)
        #expect(weight.quantityPerPackage == 1)

        let count = ProductUnit.make(mode: .count, packageWeight: 100, countLabel: "bars", countPerPackage: 0)
        #expect(count.quantityPerPackage == 1)
    }

    @Test("blank count label falls back to \"items\"")
    func blankLabelFallsBackToItems() {
        let unit = ProductUnit.make(mode: .count, packageWeight: 100, countLabel: "   ", countPerPackage: 5)
        #expect(unit.label == "items")
    }

    @Test("label alone determines tracking mode")
    func labelDeterminesTrackingMode() {
        let grams = ProductUnit(label: "g", quantityPerPackage: 1, gramsPerUnit: 1)
        #expect(grams.trackingMode == .weight)

        let bars = ProductUnit(label: "bars", quantityPerPackage: 1, gramsPerUnit: nil)
        #expect(bars.trackingMode == .count)
    }
}
