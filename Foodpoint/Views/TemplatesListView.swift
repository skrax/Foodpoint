import SwiftUI
import FoodpointKit

/// The full templates screen (MK-4, meals-feature-design.md §7) —
/// memorized meals, one-tap-to-log via a trailing "+" `Menu`
/// (`TemplateLogButton`, itself wired to `AppState.logTemplateAndMarkEaten`;
/// restructured by FX-7 from a whole-row `bolt.fill` button to mirror
/// `DayTimelineView.addMealMenu`'s "+" pattern — see that file's doc
/// comment), creation via `TemplateEditorView` ("New Meal"), and
/// per-template rename/edit/delete. Reachable from `MealsView` via a single
/// `NavigationLink` — kept in its own file specifically so `MealsView`'s
/// edit for this task stays small (two sibling tasks, MK-5/MK-6, also touch
/// that file in their own branches).
struct TemplatesListView: View {
    @Environment(AppState.self) private var appState

    @State private var isShowingNewTemplateEditor = false
    @State private var editingTemplate: MealTemplate?

    @State private var renamingTemplate: MealTemplate?
    @State private var renameText = ""

    @State private var templatePendingDeletion: MealTemplate?

    /// Alphabetical, so the list doesn't reorder itself as templates get
    /// logged (which never mutates a template) or edited (name changes are
    /// rare and a brief reorder on save is an acceptable tradeoff for a
    /// stable, scannable list the rest of the time).
    private var templates: [MealTemplate] {
        appState.meals.templates.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Templates Yet",
                    systemImage: "star",
                    description: Text("Save a meal as a template to add it to today from the + menu.")
                )
            } else {
                List {
                    ForEach(templates) { template in
                        templateRow(template)
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewTemplateEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingNewTemplateEditor) {
            TemplateEditorView(template: nil)
        }
        .sheet(item: $editingTemplate) { template in
            TemplateEditorView(template: template)
        }
        .alert(
            "Rename Template",
            isPresented: Binding(get: { renamingTemplate != nil }, set: { if !$0 { renamingTemplate = nil; renameText = "" } }),
            presenting: renamingTemplate
        ) { template in
            TextField("Name", text: $renameText)
            Button("Save") { renameTemplate(template) }
            Button("Cancel", role: .cancel) { renamingTemplate = nil; renameText = "" }
        } message: { _ in
            Text("Choose a new name for this template.")
        }
        .alert(
            "Delete Template?",
            isPresented: Binding(get: { templatePendingDeletion != nil }, set: { if !$0 { templatePendingDeletion = nil } }),
            presenting: templatePendingDeletion
        ) { template in
            Button("Delete", role: .destructive) {
                appState.meals.removeTemplate(template.id)
                templatePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { templatePendingDeletion = nil }
        } message: { template in
            Text("\"\(template.name)\" will be removed. Meals already logged from it are unaffected.")
        }
    }

    /// One template row: name/slot/ingredient-count content plus
    /// `TemplateLogButton`'s own trailing "+" menu (meals-feature-design.md
    /// §7's fast path, restructured by FX-7 to read as "add this to
    /// today" — see `TemplateLogButton`'s doc comment), with rename/edit/
    /// delete offered as swipe actions and a context menu rather than
    /// competing for the row's tap targets.
    private func templateRow(_ template: MealTemplate) -> some View {
        TemplateLogButton(template: template) {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(template.defaultSlot.id.capitalized) · \(template.ingredients.count) ingredient\(template.ingredients.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                templatePendingDeletion = template
            }
            Button("Rename") {
                renamingTemplate = template
                renameText = template.name
            }
            .tint(.blue)
        }
        .contextMenu {
            Button {
                editingTemplate = template
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                renamingTemplate = template
                renameText = template.name
            } label: {
                Label("Rename", systemImage: "textformat")
            }
            Button(role: .destructive) {
                templatePendingDeletion = template
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Renames `template` in place via `updateTemplate`, trimming
    /// whitespace and ignoring an all-whitespace name (leaves the template
    /// untouched rather than saving an empty label).
    private func renameTemplate(_ template: MealTemplate) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { renamingTemplate = nil; renameText = "" }
        guard !trimmed.isEmpty else { return }
        var updated = template
        updated.name = trimmed
        appState.meals.updateTemplate(updated)
    }
}
