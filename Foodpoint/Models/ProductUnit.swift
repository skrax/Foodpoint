import Foundation

/// Whether a product's quantity is tracked by discrete count (bars, slices,
/// sticks) or by weight (grams). Drives which fields the unit-config UI
/// shows in `ScannerView` and `ItemDetailView`.
enum UnitTrackingMode: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case count = "Count"

    var id: String { rawValue }
}

/// Describes how one product's quantity is counted and, optionally, how
/// much one count-unit weighs (used to derive nutrition-per-unit from
/// Open Food Facts' per-100g figures via `Nutriments.scaled(by:)`).
///
/// Configured once per barcode and stored in `AppState.unitConfigs`, so it
/// survives even if the item is fully consumed and removed from `items`.
struct ProductUnit {
    /// User-facing unit name, e.g. "bars", "slices", or "g" for weight-tracked items.
    var label: String
    /// How much `label` one scanned package adds — used by `AppState.addProduct`
    /// when re-scanning a known barcode, instead of a flat `+1`.
    var quantityPerPackage: Double
    /// Grams represented by one `label` unit. `nil` when unknown (nutrition
    /// then falls back to Open Food Facts' raw per-100g figures).
    var gramsPerUnit: Double?

    /// Default unit for a product that hasn't been configured yet.
    static let items = ProductUnit(label: "items", quantityPerPackage: 1, gramsPerUnit: nil)

    /// Inferred from `label`: a "g" label means this unit is weight-tracked.
    var trackingMode: UnitTrackingMode {
        label.lowercased() == "g" ? .weight : .count
    }

    /// Total weight of one package, derived from however this unit is tracked.
    /// Lets the unit-edit UI show back the original bag weight the user entered.
    var packageWeight: Double? {
        switch trackingMode {
        case .weight:
            return quantityPerPackage
        case .count:
            guard let gramsPerUnit else { return nil }
            return gramsPerUnit * quantityPerPackage
        }
    }

    /// Builds a `ProductUnit` from the Weight/Count config form's raw inputs.
    ///
    /// In `.count` mode, `gramsPerUnit` is derived as `packageWeight / countPerPackage`
    /// (e.g. a 750g bag with 15 slices → 50g/slice) rather than requiring the
    /// user to compute it themselves.
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
