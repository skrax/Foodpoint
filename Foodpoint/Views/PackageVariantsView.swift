import SwiftUI

/// Lists every package-size variant remembered for a barcode, with rename/
/// resize, add, and delete. Used both from `ScannerView` (to pick a variant
/// for the current scan) and from `ItemDetailView` (to manage a product's
/// variants directly).
struct PackageVariantsView: View {
    enum Mode {
        /// Tapping a row applies it via `onSelect` and dismisses. Used when
        /// scanning, to choose which package size this scan represents.
        case select(onSelect: (ProductUnit) -> Void)
        /// Tapping a row opens it for editing. Used from an item's detail view.
        case manage
    }

    let barcode: String
    let mode: Mode
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var editingVariant: ProductUnit?
    @State private var isAddingVariant = false

    private var variants: [ProductUnit] {
        appState.allVariants(forBarcode: barcode)
    }

    private var defaultID: UUID? {
        appState.unitConfigs[barcode]?.id
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(variants) { variant in
                    row(for: variant)
                        .swipeActions {
                            if variant.id != defaultID {
                                Button(role: .destructive) {
                                    appState.removeVariant(variant.id, forBarcode: barcode)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .navigationTitle("Package Sizes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingVariant = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingVariant) { variant in
                VariantEditForm(barcode: barcode, existing: variant)
            }
            .sheet(isPresented: $isAddingVariant) {
                VariantEditForm(
                    barcode: barcode,
                    existing: nil,
                    templateMode: variants.first?.trackingMode,
                    templateLabel: variants.first?.label
                )
            }
        }
    }

    private func row(for variant: ProductUnit) -> some View {
        Button {
            switch mode {
            case .select(let onSelect):
                onSelect(variant)
                dismiss()
            case .manage:
                editingVariant = variant
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(variant.name)
                            .font(.headline)
                        if variant.id == defaultID {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    Text(description(for: variant))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editingVariant = variant
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.primary)
    }

    private func description(for variant: ProductUnit) -> String {
        let weight = (variant.packageWeight ?? variant.quantityPerPackage).formatted(.number.precision(.fractionLength(0...2)))
        switch variant.trackingMode {
        case .weight:
            return "\(weight) g"
        case .count:
            let count = variant.quantityPerPackage.formatted(.number.precision(.fractionLength(0...2)))
            return "\(weight) g (\(count) \(variant.label))"
        }
    }
}
