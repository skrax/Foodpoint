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
/// A barcode can have several `ProductUnit`s — one default plus any number
/// of named variants (e.g. "Default"/750g, "Small"/500g) — all stored under
/// `AppState.unitConfigs`/`unitVariants`, keyed by barcode, so they survive
/// even if the item is fully consumed and removed from `items`. `id` gives
/// each variant a stable identity for editing/selection independent of its
/// (possibly-edited) `name` or values.
struct ProductUnit: Identifiable {
    let id: UUID
    /// User-facing name for this package-size variant, e.g. "Default", "Small", "Large".
    var name: String
    /// User-facing unit name, e.g. "bars", "slices", or "g" for weight-tracked items.
    var label: String
    /// How much `label` one scanned package adds — used by `AppState.addProduct`
    /// when re-scanning a known barcode, instead of a flat `+1`.
    var quantityPerPackage: Double
    /// Grams represented by one `label` unit. `nil` when unknown (nutrition
    /// then falls back to Open Food Facts' raw per-100g figures).
    var gramsPerUnit: Double?

    init(id: UUID = UUID(), name: String = "Default", label: String, quantityPerPackage: Double, gramsPerUnit: Double?) {
        self.id = id
        self.name = name
        self.label = label
        self.quantityPerPackage = quantityPerPackage
        self.gramsPerUnit = gramsPerUnit
    }

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
    static func make(
        id: UUID = UUID(),
        name: String = "Default",
        mode: UnitTrackingMode,
        packageWeight: Double?,
        countLabel: String,
        countPerPackage: Double?
    ) -> ProductUnit {
        switch mode {
        case .weight:
            let weight = packageWeight ?? 1
            return ProductUnit(id: id, name: name, label: "g", quantityPerPackage: weight > 0 ? weight : 1, gramsPerUnit: 1)
        case .count:
            let label = countLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            let count = countPerPackage ?? 1
            let gramsPerUnit: Double? = {
                guard let weight = packageWeight, weight > 0, count > 0 else { return nil }
                return weight / count
            }()
            return ProductUnit(
                id: id,
                name: name,
                label: label.isEmpty ? "items" : label,
                quantityPerPackage: count > 0 ? count : 1,
                gramsPerUnit: gramsPerUnit
            )
        }
    }
}
