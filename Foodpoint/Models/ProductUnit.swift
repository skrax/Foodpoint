import Foundation

enum UnitTrackingMode: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case count = "Count"

    var id: String { rawValue }
}

struct ProductUnit {
    var label: String
    var quantityPerPackage: Double
    var gramsPerUnit: Double?

    static let items = ProductUnit(label: "items", quantityPerPackage: 1, gramsPerUnit: nil)

    var trackingMode: UnitTrackingMode {
        label.lowercased() == "g" ? .weight : .count
    }

    // Total weight of one package, derived from however this unit is tracked.
    var packageWeight: Double? {
        switch trackingMode {
        case .weight:
            return quantityPerPackage
        case .count:
            guard let gramsPerUnit else { return nil }
            return gramsPerUnit * quantityPerPackage
        }
    }

    static func make(mode: UnitTrackingMode, packageWeight: Double?, countLabel: String, countPerPackage: Double?) -> ProductUnit {
        switch mode {
        case .weight:
            let weight = packageWeight ?? 1
            return ProductUnit(label: "g", quantityPerPackage: weight > 0 ? weight : 1, gramsPerUnit: 1)
        case .count:
            let label = countLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let count = countPerPackage ?? 1
            let gramsPerUnit: Double? = {
                guard let weight = packageWeight, weight > 0, count > 0 else { return nil }
                return weight / count
            }()
            return ProductUnit(
                label: label.isEmpty ? "items" : label,
                quantityPerPackage: count > 0 ? count : 1,
                gramsPerUnit: gramsPerUnit
            )
        }
    }
}
