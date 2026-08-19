import SwiftUI
import FoodpointKit

/// "Name This Meal" (FX-6) — shown right after `MealCompositionEditorView`'s
/// `onDone` fires for an ad-hoc (non-template) meal, before it's actually
/// persisted. Same `alert(presenting:)` + `TextField` shape
/// `RememberMealPromptModifier` already established for naming prompts in
/// this feature (a name `TextField` plus a "Save" button, `presenting:` the
/// pending ingredients so the message closure can describe the fallback
/// rather than a bare `Bool`).
///
/// Factored into its own file/`ViewModifier` for the same reason
/// `RememberMealPrompt.swift`/`TemplatesListView`/`TemplateEditorView` were:
/// keeps `DayTimelineView`'s own `body` smaller. This one additionally earns
/// its keep by working around a real Swift compiler limitation — inlining
/// this alert directly into `DayTimelineView`'s already-long modifier chain
/// pushed the type-checker over its complexity budget ("unable to
/// type-check this expression in reasonable time"), and extracting it here
/// fixed the build.
///
/// Only one button ("Save"): unlike the remember prompt (which offers to
/// *additionally* save a template after a meal that's already been logged),
/// this prompt **is** the commit point for a meal that hasn't been saved
/// yet — before FX-6, tapping "Done" in the composer already saved
/// unconditionally under a hardcoded name, so this alert doesn't introduce a
/// new way to back out, only a way to type a real name first. A left-blank
/// name still saves successfully: the caller's `onSave` receives whatever
/// was typed (untrimmed) and is responsible for the trim-and-fallback logic
/// (`DayTimelineView.addEntry(name:ingredients:slot:)`).
struct NameMealPromptModifier: ViewModifier {
    @Binding var isPresented: Bool
    /// The just-composed ingredients, carried by the alert's `presenting:`
    /// data — non-`nil` exactly while this prompt is showing.
    var pendingIngredients: [LoggedIngredient]?
    @Binding var name: String
    /// Whether the meal being named is a future plan (blank-name fallback
    /// text differs: "Planned Meal" vs. "Ad-hoc Meal") — purely for the
    /// message copy; the actual fallback substitution happens in the
    /// caller's `onSave`, not here.
    var isFutureDay: Bool
    var onSave: (_ ingredients: [LoggedIngredient]) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Name This Meal",
            isPresented: $isPresented,
            presenting: pendingIngredients
        ) { ingredients in
            TextField("Name (e.g. Chicken Salad)", text: $name)
            Button("Save") { onSave(ingredients) }
        } message: { _ in
            Text(isFutureDay
                ? "Leave blank to save as \"Planned Meal.\""
                : "Leave blank to save as \"Ad-hoc Meal.\"")
        }
    }
}

extension View {
    /// Attaches the "Name This Meal" prompt — see `NameMealPromptModifier`
    /// for the full rationale. `isPresented` gates the alert;
    /// `pendingIngredients` non-`nil` while it's showing is what actually
    /// drives `presenting:` (matching `ScannerView`'s `pendingUnit`/
    /// `RememberMealPromptModifier`'s own pattern) — callers are expected to
    /// set both together.
    func nameMealPrompt(
        isPresented: Binding<Bool>,
        pendingIngredients: [LoggedIngredient]?,
        name: Binding<String>,
        isFutureDay: Bool,
        onSave: @escaping (_ ingredients: [LoggedIngredient]) -> Void
    ) -> some View {
        modifier(NameMealPromptModifier(
            isPresented: isPresented,
            pendingIngredients: pendingIngredients,
            name: name,
            isFutureDay: isFutureDay,
            onSave: onSave
        ))
    }
}
