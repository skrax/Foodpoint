import Foundation
import Testing
import FoodFoundation
@testable import MealKit

@Suite("Entry lifecycle — log, plan, markEaten, undo, delete")
struct EntryLifecycleTests {
    private func loggedIngredient(barcode: String = "0001", usesFromPantry: Bool = true) -> LoggedIngredient {
        LoggedIngredient(barcode: barcode, productName: "Bread", productBrand: "Acme", imageURL: nil, amount: 2, unitLabel: "slices", gramsResolved: 100, nutritionSnapshot: Fixture.nutrition(), usesFromPantry: usesFromPantry)
    }

    @Test("logEaten creates an entry with status eaten")
    func logEatenCreatesEatenEntry() {
        let store = MealStore()
        let entry = store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])

        #expect(entry.status == .eaten)
        #expect(store.entries.count == 1)
        #expect(store.entries[0].id == entry.id)
    }

    @Test("plan creates an entry with status planned")
    func planCreatesPlannedEntry() {
        let store = MealStore()
        let entry = store.plan(name: "Toast", date: day(1), slot: .breakfast, ingredients: [loggedIngredient()])

        #expect(entry.status == .planned)
    }

    @Test("markEaten transitions a planned entry to eaten and returns the finalized entry")
    func markEatenTransitionsPlannedEntry() {
        let store = MealStore()
        let planned = store.plan(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient(usesFromPantry: true)])

        let finalized = store.markEaten(planned.id)

        #expect(finalized?.status == .eaten)
        #expect(finalized?.ingredients.first?.usesFromPantry == true, "caller reads this to decide which pantry items to decrement (package-architecture.md §3.5)")
        #expect(store.entries.first?.status == .eaten)
    }

    @Test("markEaten on an already-eaten entry is a no-op returning nil")
    func markEatenNoOpOnAlreadyEaten() {
        let store = MealStore()
        let entry = store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])

        #expect(store.markEaten(entry.id) == nil)
    }

    @Test("markEaten on an unknown id returns nil")
    func markEatenUnknownID() {
        let store = MealStore()
        #expect(store.markEaten(UUID()) == nil)
    }

    @Test("undo reverses markEaten back to planned")
    func undoReversesMarkEaten() {
        let store = MealStore()
        let planned = store.plan(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])
        store.markEaten(planned.id)

        let reverted = store.undo(planned.id)

        #expect(reverted?.status == .planned)
        #expect(store.entries.first?.status == .planned)
    }

    @Test("undo on a planned entry (never eaten) is a no-op returning nil")
    func undoNoOpOnPlannedEntry() {
        let store = MealStore()
        let planned = store.plan(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])

        #expect(store.undo(planned.id) == nil)
    }

    @Test("removeEntry deletes and returns the removed entry")
    func removeEntryReturnsRemoved() {
        let store = MealStore()
        let entry = store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient(usesFromPantry: true)])

        let removed = store.removeEntry(entry.id)

        #expect(removed?.id == entry.id)
        #expect(store.entries.isEmpty)
    }

    @Test("removeEntry on an unknown id returns nil and leaves entries untouched")
    func removeEntryUnknownID() {
        let store = MealStore()
        store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])

        #expect(store.removeEntry(UUID()) == nil)
        #expect(store.entries.count == 1)
    }

    @Test("updateEntry replaces an entry in place by id")
    func updateEntryReplacesInPlace() {
        let store = MealStore()
        var entry = store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [loggedIngredient()])
        entry.name = "Toast with Jam"

        store.updateEntry(entry)

        #expect(store.entries.first?.name == "Toast with Jam")
    }

    // MARK: - Template CRUD

    @Test("addTemplate, updateTemplate, removeTemplate")
    func templateCRUD() {
        let store = MealStore()
        let template = MealTemplate(name: "Morning Toast", defaultSlot: .breakfast)
        store.addTemplate(template)
        #expect(store.templates.count == 1)

        var renamed = template
        renamed.name = "Weekday Toast"
        store.updateTemplate(renamed)
        #expect(store.templates.first?.name == "Weekday Toast")

        store.removeTemplate(template.id)
        #expect(store.templates.isEmpty)
    }

    @Test("updateTemplate on an unknown id is a no-op")
    func updateTemplateUnknownID() {
        let store = MealStore()
        store.addTemplate(MealTemplate(name: "Morning Toast", defaultSlot: .breakfast))

        store.updateTemplate(MealTemplate(name: "Ghost", defaultSlot: .lunch))

        #expect(store.templates.count == 1)
        #expect(store.templates[0].name == "Morning Toast")
    }
}
