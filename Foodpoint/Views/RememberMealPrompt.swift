import SwiftUI
import FoodpointKit

/// "Remember this meal?" — shown after logging an ad-hoc meal (MK-4,
/// meals-feature-design.md §7). Reuses `ScannerView`'s "New Package Size"
/// variant-naming alert **verbatim** in shape: a name `TextField` plus
/// exactly the same three buttons, "Save Variant"/"Just This Once"/"Cancel"
/// (`ScannerView.swift` around its `isShowingVariantPrompt` alert) —
/// `presenting:` the pending data rather than a bare `Bool` so the message
/// closure can describe what's being remembered, the same structural trick
/// that alert uses. A user who's already seen this prompt while scanning a
/// new package size recognizes it instantly here, per the design doc's
/// explicit intent ("Meals should reuse that interaction verbatim").
///
/// Unlike `ScannerView`'s prompt — which gates whether the pantry item gets
/// saved at all — the meal here has *already* been logged by the time this
/// prompt appears (meals-feature-design.md §7 promotes something "already
/// logged"), so "Just This Once" and "Cancel" both just mean "don't save a
/// template," with no separate "undo the log" behavior. Kept as three
/// buttons anyway, matching the source shape verbatim as instructed, rather
/// than collapsing two now-equivalent options into one.
///
/// Factored out as its own `ViewModifier`/`View` extension rather than
/// inlined in `MealsView` (the only current call site) so that file's MK-4
/// edit stays a small, additive change — two sibling tasks (MK-5, MK-6)
/// also touch `MealsView.swift` in their own branches.
struct RememberMealPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    /// The ad-hoc meal's already-logged ingredients, carried by the alert's
    /// `presenting:` data so `onSaveVariant`/the message text can describe
    /// them without a second piece of optional state to keep in sync.
    var pendingIngredients: [LoggedIngredient]?
    @Binding var name: String
    var onSaveVariant: (_ ingredients: [LoggedIngredient]) -> Void
    var onJustThisOnce: () -> Void
    var onCancel: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Remember This Meal?",
            isPresented: $isPresented,
            presenting: pendingIngredients
        ) { ingredients in
            TextField("Name (e.g. Morning Toast)", text: $name)
            Button("Save Variant") { onSaveVariant(ingredients) }
            Button("Just This Once") { onJustThisOnce() }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: { ingredients in
            Text("Save this as a template so you can log it again with one tap. (\(ingredients.count) ingredient\(ingredients.count == 1 ? "" : "s"))")
        }
    }
}

extension View {
    /// Attaches the "Remember this meal?" prompt — see
    /// `RememberMealPromptModifier` for the full rationale. `isPresented`
    /// gates the alert; `pendingIngredients` non-`nil` while it's showing is
    /// what actually drives `presenting:` (matching `ScannerView`'s
    /// `pendingUnit` pattern) — callers are expected to set both together.
    func rememberMealPrompt(
        isPresented: Binding<Bool>,
        pendingIngredients: [LoggedIngredient]?,
        name: Binding<String>,
        onSaveVariant: @escaping (_ ingredients: [LoggedIngredient]) -> Void,
        onJustThisOnce: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        modifier(RememberMealPromptModifier(
            isPresented: isPresented,
            pendingIngredients: pendingIngredients,
            name: name,
            onSaveVariant: onSaveVariant,
            onJustThisOnce: onJustThisOnce,
            onCancel: onCancel
        ))
    }
}
