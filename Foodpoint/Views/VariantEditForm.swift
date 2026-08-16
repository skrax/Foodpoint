import SwiftUI
import FoodpointKit

/// Add or rename/resize a single package-size variant. Tracking mode is
/// locked to match the barcode's other variants (inferred from `existing`,
/// or from `templateMode` when adding the very first one) — only the name,
/// weight, count-tracked units' label, and count can change. Editing the
/// label here applies to every variant of this barcode at once (via
/// `AppState.renameUnitLabel`), since they're meant to share one counting
/// unit — see that method's doc comment.
struct VariantEditForm: View {
    let barcode: String
    let existing: ProductUnit?
    /// Whether `existing` is the barcode's default variant — if so, no
    /// delete option is offered (mirrors `AppState.removeVariant`'s guard).
    var isDefault: Bool = false
    var templateMode: UnitTrackingMode?
    var templateLabel: String?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var labelText = ""
    @State private var weightText = ""
    @State private var countText = ""
    @State private var isShowingDeleteConfirmation = false

    private var mode: UnitTrackingMode {
        existing?.trackingMode ?? templateMode ?? .count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Small, Large)", text: $name)
                }
                Section("Package size") {
                    Picker("Tracking", selection: .constant(mode)) {
                        ForEach(UnitTrackingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(true)

                    TextField("Weight (g)", text: $weightText)
                        .keyboardType(.decimalPad)

                    if mode == .count {
                        TextField("Count label (e.g. slices, bars)", text: $labelText)

                        TextField("Count (\(labelText.isEmpty ? "items" : labelText))", text: $countText)
                            .keyboardType(.decimalPad)
                    }
                }

                if existing != nil, !isDefault {
                    Section {
                        Button("Make Default") {
                            makeDefault()
                        }
                    }
                    Section {
                        Button("Delete Variant", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Package Size" : "Edit Package Size")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: populate)
            .alert("Delete \"\(name)\"?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func populate() {
        labelText = existing?.label ?? templateLabel ?? "items"
        guard let existing else { return }
        name = existing.name
        weightText = existing.packageWeight.map {
            $0.formatted(.number.precision(.fractionLength(0...2)))
        } ?? ""
        countText = existing.trackingMode == .count
            ? existing.quantityPerPackage.formatted(.number.precision(.fractionLength(0...2)))
            : ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = ProductUnit.make(
            id: existing?.id ?? UUID(),
            name: trimmedName.isEmpty ? "Variant" : trimmedName,
            mode: mode,
            packageWeight: weightText.localizedDouble,
            countLabel: labelText,
            countPerPackage: countText.localizedDouble
        )

        if existing != nil {
            appState.updateVariant(unit, forBarcode: barcode)
        } else {
            appState.addUnitVariant(unit, forBarcode: barcode)
        }
        if mode == .count {
            appState.renameUnitLabel(unit.label, forBarcode: barcode)
        }
        dismiss()
    }

    private func delete() {
        guard let existing else { return }
        appState.removeVariant(existing.id, forBarcode: barcode)
        dismiss()
    }

    /// Acts on the variant as stored, ignoring any unsaved edits still in
    /// the form fields — a deliberate, standalone action rather than an
    /// implicit side effect of Save.
    private func makeDefault() {
        guard let existing else { return }
        appState.makeDefault(existing.id, forBarcode: barcode)
        dismiss()
    }
}
