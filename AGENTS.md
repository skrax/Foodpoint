# AGENTS.md

Guidance for AI coding assistants working in this repo. See
[README.md](README.md) for a general project overview.

## What this is

Foodpoint is a solo-developer SwiftUI iOS prototype: scan a barcode (or
search by name for something with no barcode — produce, bulk goods), look
up the product on Open Food Facts, and save it into a flat, quantity-
tracked item list. It is early-stage — prefer small, direct changes over
speculative abstractions. (A prior "locations" feature — organizing items
into named places — was built and then deliberately scrapped; the flat
item list is the current, intentional design, not a placeholder.)

All business logic lives in local, UI-agnostic Swift packages (no
`import SwiftUI`, no view code anywhere in them): `FoodFoundation` holds
the shared domain types and product lookup; `PantryKit` holds the pantry's
state and CRUD logic on top of it; `MealKit` holds the meals feature's
state and logic on top of it too — a fully independent peer of `PantryKit`,
sharing nothing with it but `FoodFoundation` (each of the three with its
own unit test suite); `FoodpointKit` is a thin composition root exposing
all of this as a single `AppState`, plus the one place cross-domain
orchestration between `PantryKit` and `MealKit` lives (logging a meal
decrementing pantry stock, and undo restoring it — MK-3; its own,
smaller `FoodpointKitTests`). The `Foodpoint` app target is a thin driver:
SwiftUI views, the AVFoundation camera wrapper, and glue code that
reads/writes `appState.pantry.*`/`appState.meals.*`.
**New logic — state mutation, derived values, parsing, anything that isn't
literally rendering UI — belongs in a package, not in a view.** This split
exists specifically so that logic can be unit tested without a simulator;
don't undermine it by reaching for `@State`/view-local logic where a
testable `PantryStore` method (or a `FoodFoundation` type) would do.

## Build & test

Full Xcode (not just Command Line Tools) is required for the app. If
`xcode-select` points at the Command Line Tools, don't change it
system-wide — override per-command instead:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'generic/platform=iOS Simulator' build
```

Each package's unit tests (Swift Testing) run standalone via SPM, no Xcode
project or simulator needed — this is the fast, primary way to verify
business-logic changes:

```bash
cd Packages/FoodFoundation && swift test
cd Packages/PantryKit && swift test
cd Packages/MealKit && swift test
cd Packages/FoodpointKit && swift test
```

Run the relevant package's tests after any change to it, and add/update
tests for new or changed behavior — see "Testing conventions" below. There
is still no test target for the app/view layer; verify view changes by
building and, where practical, running the app in the simulator or on a
physical device (see "Deploying to a device" below).

## Documentation is mandatory here

Unlike the general default of writing minimal comments, **this repo
requires both of the following on every change that adds, edits, or
removes code:**

1. **Doc comments (`///`)** on new/changed types, properties, and
   non-trivial functions — explain *why*/*what this is for*, not just
   restate the signature. Every existing type in the codebase has one;
   match that standard for anything new.
2. **Update this file and README.md** whenever the change affects project
   structure, conventions, or the feature set they describe. Don't leave
   them describing a previous version of the app.

## Project structure & conventions

The Xcode project uses **file-system synchronized groups**
(`PBXFileSystemSynchronizedRootGroup`), meaning files added under
`Foodpoint/` on disk are picked up automatically — no `.pbxproj` editing
needed when adding a new file to the *app* target. Adding a file to either
*package* also needs no manifest edit (SPM picks up anything under a
target's `Sources`/`Tests` directory) — but adding a whole new package
does require hand-editing `project.pbxproj` (see "Adding a new package
dependency" below).

- `Foodpoint/` (app target) — SwiftUI views and camera glue only, nothing
  else:
  - `ScannerView.swift`, `ContentView.swift`, `FoodpointApp.swift` — the
    latter injects `AppState.shared` into the environment. `ContentView`'s
    root `TabView` has three tabs: Items, Scan, and Meals — the last is
    `Views/MealsView.swift` (MK-2/MK-3, restructured MK-5), now a thin
    `NavigationStack` shell hosting `Views/DayTimelineView.swift` (MK-5,
    see its own bullet below) — the real Meals tab home (day timeline,
    planning/tick-off, templates access, and range/consumption surfaces
    from MK-4/MK-6, both folded into the same screen) meals-feature-design.md
    §10 calls for. `ScannerView` is
    scan-only (UX-2): its single acquisition path is the camera
    (`FastFoodBarcodeScanner`) driving `fetchFoodData(for:)`. It has no
    search UI of its own — `Views/ProductSearchView.swift` (text search)
    is presented directly by `ItemsView`, not by `ScannerView`. Each
    `ProductSearchView` result row also has a separate `info.circle`
    button that pushes `Views/SearchResultDetailView.swift` (a thin wrapper
    around `ProductDetailCard`) to inspect that candidate's nutrition before
    committing — same nested-tappable-controls fix as
    `PackageVariantsView.row(for:)` (plain `HStack` +
    `.contentShape(Rectangle())` + `.onTapGesture` for the row tap, a
    separate `.buttonStyle(.plain)` `Button` for the info icon), and the
    push uses `.navigationDestination(item:)` on the search view's own
    `NavigationStack` rather than a sheet, so popping back doesn't re-run
    the search.
    `ScannerView` is also presentable as a sheet from elsewhere (currently
    `ItemsView`'s "•••" menu) via its `entryPoint: EntryPoint?` parameter
    (`.scan`/`.resolved(barcode:)`/`nil`) — non-`nil` auto-acts on appear
    (skipping the "No Product Scanned" landing screen, since the caller
    already expressed intent by picking a menu item) and shows a Cancel
    button; `nil` is today's Scan-tab-root behavior, unchanged.
    `.resolved(barcode:)` is how a `ProductSearchView` pick — presented and
    resolved to a barcode by `ItemsView` itself — still re-enters
    `ScannerView`'s `fetchFoodData(for:)` rather than reusing the
    already-fetched product, so there's exactly one code path past that
    point, not two to maintain. If you add another entry point into this
    flow, extend `EntryPoint` rather than duplicating `ScannerView`'s
    acquire/confirm/configure/save logic elsewhere — that duplication is
    exactly what this parameter exists to avoid. **FX-1**: `ItemsView` used
    to hand off from the search sheet to this sheet via two independent
    `.sheet(isPresented:)` modifiers (the search sheet's `onDismiss`
    flipping a second `Bool`), which raced UIKit's own dismiss/present
    timing and produced a real blank-sheet bug on the first attempt (see
    `ItemsView`'s bullet below) — fixed by switching to one `.sheet(item:)`
    over an `ActiveSheet` enum, not by adding a loading indicator (this view
    already had one: the `ProgressView` shown while `isLoading` is true
    below covers `fetchFoodData` for every entry point, including
    `.resolved(barcode:)`). **FX-2**: `scanAgain()` — called after a
    successful save to reopen the camera for the next scan — now checks
    `entryPoint` first: for `.resolved(barcode:)` (search-originated) it
    dismisses the sheet back to `ItemsView` instead, since there's no reason
    to surprise a search-only flow with a camera it never asked for;
    `.scan`/`nil` (camera-originated, including the Scan tab root) keep
    reopening the camera exactly as before.
  - `Views/` — SwiftUI views. Keep bodies declarative; push non-trivial
    logic into `PantryKit` (a new/extended `PantryStore` method, reached
    via `appState.pantry`) or a `FoodFoundation` computed property, rather
    than into the view. This applies just as much to `MealKit`-backed
    views: push new logic into a `MealStore` method (reached via
    `appState.meals`), not into `@State`/view-local functions.
    - `MealCompositionEditorView.swift` (MK-2) — the meal-composition
      editor: ingredient rows (amount field via `String.localizedDouble`,
      "Use from pantry" toggle defaulting on) plus a running nutrition
      footer with a completeness signal (`MealStore.completeness(for:)`,
      now `public` specifically so this view can call it live, ahead of
      any `MealEntry` existing). Four ingredient sources behind an
      "Add Ingredient" bottom-bar menu, per meals-feature-design.md §6.1:
      **from the pantry** (`MealIngredientPantryPickerView`, reading
      `appState.pantry.items` directly — the one source `MealKit` itself
      can't provide), **from history**
      (`MealIngredientHistoryPickerView`, reading
      `appState.meals.recentlyUsedIngredients()`, no network call),
      **scan** (`FastFoodBarcodeScanner`, reused verbatim from
      `ScannerView`), and **search** (`ProductSearchView`, reused
      verbatim) — both of the latter two funnel into one
      `beginAcquisition(barcode:)` function that calls
      `ProductLookup.fetch(barcode:)` then either appends a row directly
      (this barcode has a `appState.meals.lastKnownUnit(forBarcode:)`
      already) or presents `MealIngredientUnitSetupView`'s minimal
      weight/count + label prompt first (a barcode `MealKit` has never
      used before) — scoped to that one ingredient, never written back to
      `PantryKit` even if the same barcode is already configured there.
      Editing a row's amount recomputes grams/nutrition locally via
      `MealStore.makeIngredient` + `LoggedIngredient.impliedUnit`/
      `.impliedNutritionPer100g` (see the `MealStore.swift` bullet below)
      rather than re-fetching. Deliberately **does not** persist anything
      itself (MK-2's Scope explicitly excludes "actually saving/logging
      the meal") — it hands the composed `[LoggedIngredient]` to an
      `onDone` closure and lets the caller decide; `DayTimelineView` (MK-5,
      formerly `MealsView` itself pre-MK-5) is the real caller for ad-hoc
      logging, wiring `onDone` into `appState.meals.plan`/
      `appState.markMealEaten(_:)` depending on the selected date.
      `TemplateEditorView` (MK-4, see its own bullet below) is the first of
      the reuses this view's closure-based contract was built to anticipate:
      its `init(initialIngredients:title:onDone:)` (MK-4) pre-populates
      `rows` from an already-composed `[LoggedIngredient]` — used to reopen
      an existing template's ingredients for editing — and its `title` param
      ("New Meal"/"Edit Meal") replaces what used to be a hardcoded
      `.navigationTitle("New Meal")`. `formattedAmount` became a
      `private static func` so the new init can call it before `self` exists.
      **FX-3** (physical-device testing) fixed a real UX trap: "Add
      Ingredient" (bottom-bar) and "Done" (top-right `.confirmationAction`,
      finishes/saves the whole meal) used to be two anonymous corner
      buttons distinguished only by screen position, so the instinctive tap
      after adding a first ingredient — the top-right corner, to "close
      this and add another" — actually finished the meal instead. Fixed two
      ways, combined, neither adding friction to the common multi-ingredient
      case: (1) "Add Ingredient" moved from a left-aligned icon+text bottom-
      bar item to a centered `.buttonStyle(.borderedProminent)` button, so
      it visually reads as *the* next action; (2) the "Done" button's
      handler (`finishOrConfirmIfSingleIngredient()`) shows a
      `.confirmationDialog` ("Finish with just 1 ingredient?") only when
      `rows.count == 1` — the exact moment the mix-up tends to happen — with
      "Finish Meal"/"Keep Adding" options; 0 or 2+ ingredients still finish
      on a single tap, unchanged from before.
    - `MealIngredientPantryPickerView.swift`, `MealIngredientHistoryPickerView.swift`,
      `MealIngredientUnitSetupView.swift` (MK-2) — the four sources'
      picker sheets described above.
    - `MealsView.swift` (MK-2/MK-3, restructured MK-5) — the Meals tab
      root. As of MK-5 this is deliberately thin: it owns only the tab's
      `NavigationStack` and hosts `DayTimelineView`, which is where the
      actual screen (and all its state) now lives — this split keeps "the
      new Meals tab home screen" as one clearly-scoped file rather than an
      ever-growing `MealsView`.
    - `DayTimelineView.swift` (MK-5, meals-feature-design.md §10; day
      totals/menu/row-push folded in from MK-6) — the real Meals tab home:
      **Meals tab home is the day timeline, opening on today.** Date
      navigation (chevron buttons either side of a
      "Today"/"Tomorrow"/"Yesterday"/formatted-date label, tapping the
      label jumps back to today) drives `appState.meals.entriesGroupedBySlot(on:)`
      (see the `MealStore.swift` bullet below), rendered as one `List`
      `Section` per non-empty `MealSlot`. Below the date header sits
      `DayTotalsHeaderView` (see its own bullet) rather than a simpler
      inline eaten/planned line, so the timeline gets the full macro
      breakdown and completeness note for free. Planned rows get a thin
      accent-color outline to read as visually distinct from filled eaten
      rows (§10's "outlined rather than filled"), plus a prominent
      checkmark tick-off button; eaten rows keep MK-3's swipe-to-undo
      action unchanged. Tapping a row (its own `.contentShape(Rectangle())`
      + `.onTapGesture`, not a `NavigationLink` wrapping the tick-off
      `Button` — the same nested-tappable-controls-safe shape
      `PackageVariantsView.row(for:)`/UX-3 established) pushes
      `MealDetailView` via `.navigationDestination(item:)`, keyed on the
      entry's `id` rather than the entry itself since `MealEntry` isn't
      `Hashable`. A leading toolbar `Menu` reaches `RangeSummaryView`
      (week/month) and `MostConsumedView`. The "+" toolbar item is
      a `Menu` of the four `MealSlot`s (picking one sets `pendingSlot`,
      then presents `MealCompositionEditorView`) — composing entries always
      goes through the same editor MK-2/MK-3 already use, never a
      duplicate. Whether the composed ingredients land as `.planned` or
      `.eaten` is decided purely by whether `selectedDate` is a future day:
      a future day calls `appState.meals.plan` and stops — no pantry
      orchestration runs at all, so a plan has zero effect on stock or on
      today's totals until it's actually ticked off (meals-feature-design.md
      §5, verified explicitly by `MealPantryOrchestrationTests`'
      `planningNeverTouchesPantry`/`planningNeverAffectsTodaysEatenTotal`).
      Today (or an earlier day, treated the same as "I already ate this")
      goes through MK-3's original two-step `plan` + `appState.markMealEaten(_:)`
      path unchanged, including its soft insufficient-stock alert.
      Tick-off on a planned row calls the **same** `appState.markMealEaten(_:)`
      MK-3 built — "the same object in different states," never a parallel
      system (meals-feature-design.md §5) — and reuses the same
      insufficient-stock alert. Each planned row also shows
      `appState.stockShortfalls(for:)` (see the `FoodpointKit` bullet
      below) as a "needs 6 eggs, have 4"-style caption, recomputed live on
      every render rather than cached at plan time, since a plan must
      never reserve or hold inventory (meals-feature-design.md §12 #5).
      **FX-4**: each row's context menu now also offers "Edit Ingredients",
      setting `editingEntry` and presenting `MealCompositionEditorView`
      via `.sheet(item:)`, pre-populated from that init's
      `initialIngredients` parameter with `editingEntry.ingredients` and
      `title: "Edit Meal"`; its `onDone` calls
      `appState.updateMealIngredients(entry.id, ingredients:)` (see the
      `FoodpointKit` bullet below) instead of creating a new entry, so this
      one method transparently handles both the planned (plain
      `meals.updateEntry`) and eaten (pantry-reconciling) cases — the view
      doesn't branch on `entry.status` itself. `MealDetailView`'s own
      toolbar "Edit" button (see its own bullet below) reaches the
      identical flow; this is the same "swipe/context-menu-plus-detail-
      screen-button" duplication `TemplatesListView` already has for
      templates. The row-push `.navigationDestination(item:)` now passes
      `MealDetailView(entryID:)` directly rather than pre-resolving the
      `MealEntry` here — see `MealDetailView`'s own bullet for why.
      **FX-5**: each row's swipe actions and context menu now also offer
      "Delete", via `requestDelete(_:)` — a `.planned` entry deletes
      immediately (`appState.deleteMeal(entry.id)`, no pantry effect since
      planning never touched stock), while an `.eaten` entry sets
      `entryPendingDeletion` to show a confirmation alert first (its
      deletion restores real pantry stock), matching `TemplatesListView`'s
      own `templatePendingDeletion` confirmation pattern. `MealDetailView`'s
      own toolbar "Delete" button reaches an identically-shaped
      `requestDelete` flow. **FX-6**: composing an ad-hoc meal used to save
      it under a hardcoded `"Ad-hoc Meal"`/`"Planned Meal"` name — the
      composer's `onDone` now stashes the composed ingredients
      (`pendingComposedIngredients`) and shows `NameMealPrompt.swift`'s
      "Name This Meal" alert (`isShowingNamePrompt`, see that file's own
      bullet below) before the entry is actually persisted, rather than
      adding a name field to `MealCompositionEditorView` itself (which
      `TemplateEditorView` also reuses purely for ingredient composition,
      alongside its own separate template-name `TextField` — a second name
      field there would be redundant). `addEntry(name:ingredients:slot:)`
      trims the typed name and falls back to `"Ad-hoc Meal"`/`"Planned
      Meal"` only when it's left blank, so a blank name never blocks the
      save; template-instantiated entries are unaffected, still inheriting
      the template's own name.
    - `DayTotalsHeaderView.swift` (MK-6) — day totals header: eaten
      calories/macros with a completeness signal (§8.2), plus planned
      calories as a separate "planned +X" projection line
      (meals-feature-design.md §8.1's "eaten 1,240 kcal · planned +610"
      example) whenever `MealStore.dayTotal(for:)` reports any `.planned`
      entries for that day — built directly against `dayTotal`'s existing
      `eaten`/`planned` split (present since MK-1), so this degrades to
      "eaten only" today (no planning UI exists yet in this branch) and
      needs no rewrite once MK-5's planning screens create `.planned`
      entries.
    - `RangeSummaryView.swift` (MK-6) — week/month range summary: a
      segmented Week/Month picker, `MealStore.rangeSummary(from:to:)`'s
      per-day totals, its `averageEatenPerDay`, and its `caloricTrend`
      (new, `RangeNutritionSummary` computed property — compares the mean
      eaten calories across the first vs. second half of the range,
      `.flat` under a 5% difference or fewer than two days). Deliberately
      *description*, not *evaluation* — no goals/targets shown or implied
      (meals-feature-design.md §11).
    - `MostConsumedView.swift` (MK-6) — Meals tab's most-consumed list
      across all products over the trailing 30 days
      (`MealStore.mostConsumed(from:to:)`, meals-feature-design.md §9).
      `ConsumptionStats` only carries a barcode, so this view resolves each
      row's display name/image via `appState.meals.recentlyUsedIngredients()`
      (no network call), the same trick the composition editor's "from
      history" source uses.
    - `MealDetailView.swift` (MK-6; FX-4; FX-5) — one `MealEntry`'s ingredient
      rows, nutrition completeness total, and its nutrition-source
      provenance mix (`MealStore.provenanceMix(for:)`,
      meals-feature-design.md §8.3): a proportional bar plus counts of how
      many ingredients' `nutritionSnapshot` came from Open Food Facts vs.
      Custom vs. unknown-source. Pushed from `DayTimelineView`'s entry rows.
      **FX-4**: takes `entryID: MealEntry.ID` rather than a plain
      `MealEntry` value, and looks the entry up live from
      `appState.meals.entries` on every render (a computed `entry`
      property) instead of holding a snapshot captured once at push time —
      needed because this view's own new toolbar "Edit" button presents
      `MealCompositionEditorView(initialIngredients:title:onDone:)`
      pre-populated with the current ingredients and, on save, calls
      `appState.updateMealIngredients(entry.id, ingredients:)`; a
      once-captured `let entry: MealEntry` would keep showing the pre-edit
      ingredient list after that save until the screen was popped and
      re-pushed. Renders a "Meal Not Found" placeholder if the live lookup
      ever comes back `nil` — before FX-5 not reachable (nothing deleted an
      entry out from under this screen), but FX-5's own "Delete" button now
      makes it briefly reachable in the instant between deletion and
      `dismiss()` popping this screen, so the defensive handling earns its
      keep. **FX-5**: a toolbar "Delete" button alongside "Edit",
      `requestDelete(_:)`-shaped identically to `DayTimelineView`'s
      row-level affordance (see that view's bullet above) — a `.planned`
      entry deletes immediately, an `.eaten` entry confirms first via
      `isShowingDeleteConfirmation`. Either way a successful delete calls
      `appState.deleteMeal(entry.id)` then `dismiss()` (via
      `@Environment(\.dismiss)`) to pop back to the timeline, since `entry`
      no longer exists once its `MealEntry` is gone. The nutrition/provenance computed properties
      became functions taking the resolved `entry`/`completeness`/
      `provenance` as parameters rather than reading instance-level
      properties, since `entry` itself is now only available inside the
      `if let entry` branch, not stored as a field.
    - `ItemDetailView.swift` — an existing pantry-item detail screen
      (nutrition, quantity, "Package Sizes"/"Nutrition" management),
      **not new**; gained a **Consumption** section (MK-6,
      meals-feature-design.md §9): last eaten, times eaten, total amount
      over the last 30 days, via
      `appState.meals.consumptionStats(barcode:from:to:)` keyed by the
      item's barcode. This is the one place this file reaches into
      `appState.meals` — the cross-referencing-by-barcode this repo's
      `MealKit`-stays-ignorant-of-`PantryKit` rule pushes out to view/glue
      code (same pattern as MK-2's pantry-ingredient-source, just in the
      other direction). The displayed unit label is read from
      `appState.meals.recentlyUsedIngredients()` (what `MealKit` actually
      logged amounts in), not the pantry's own current unit, since the two
      are independently configured and can differ (§6.3).
    - `TemplatesListView.swift` (MK-4; log affordance restructured by FX-7) —
      the full templates screen: memorized meals, log-to-today via a
      trailing "+" `Menu` (`TemplateLogButton`, wired to
      `AppState.logTemplateAndMarkEaten`), creation via `TemplateEditorView`
      ("New Meal"), and per-template rename (swipe action + name alert)/
      edit (context menu → `TemplateEditorView`)/delete (swipe action or
      context menu + confirmation alert). Reachable from `DayTimelineView`'s
      leading toolbar menu (see its own bullet above), alongside
      `RangeSummaryView`/`MostConsumedView`. **FX-7**: each row's log
      affordance used to be a `bolt.fill` icon covering the whole row (no
      hint that tapping it logs to today right now); `templateRow` now hands
      `TemplateLogButton` only the row's descriptive content (name, slot,
      ingredient count) and lets that view append its own trailing "+" menu
      — see `TemplateLogButton`'s bullet below for the interaction itself.
    - `TemplateEditorView.swift` (MK-4) — the "New Meal" template editor,
      doubling as "Edit" for an existing template (`template: MealTemplate?`,
      `nil` for creation). A plain `Form` (name `TextField`, `defaultSlot`
      segmented `Picker`) around an "Edit Ingredients"/"Add Ingredients"
      button that presents `MealCompositionEditorView` as a sheet for the
      ingredient-composition part — this view only adds the metadata MK-2's
      editor doesn't collect. Editing re-instantiates the template's
      ingredients fresh (`appState.meals.instantiate(template)`) before
      handing them to the composition editor, matching a template being "a
      live recipe" rather than a frozen record. Saving demotes the
      composed `[LoggedIngredient]` back to `[TemplateIngredient]` via
      `TemplateIngredient.init(logged:)` (MealKit, see its bullet below)
      and calls `appState.meals.addTemplate`/`updateTemplate`.
    - `TemplateLogButton.swift` (MK-4; restructured by FX-7) — a reusable
      "add this template to today" control wrapping
      `AppState.logTemplateAndMarkEaten` with its own loading/error state,
      so `TemplatesListView`'s row (the only current caller) doesn't
      duplicate that async/error-handling glue. **FX-7**: previously the
      whole row was a `Button` showing a `bolt.fill` icon, which user
      testing found didn't communicate "logs this to today, right now."
      It's now a trailing "+" `Menu` listing every `MealSlot`
      (`template.defaultSlot` first, labeled "(Usual)"), deliberately
      mirroring `DayTimelineView.addMealMenu`'s own "+" pattern (same glyph,
      same tap-then-pick-a-slot shape) so "+" means the same thing
      everywhere in the Meals tab — and, as a side effect, makes logging to
      a slot other than the template's default possible from this screen
      for the first time. `label` is still a `@ViewBuilder`, but now scoped
      to the row's *descriptive* content only (name, slot, ingredient
      count) — this view appends its own trailing menu after it, rather
      than the caller rendering its own log icon inside `label`. The
      underlying `AppState.logTemplateAndMarkEaten` call, and its
      loading/error-alert handling, are unchanged by FX-7 — only the
      trigger UI changed.
    - `RememberMealPrompt.swift` (MK-4) — `RememberMealPromptModifier` +
      a `View.rememberMealPrompt(...)` extension: the "Remember this
      meal?" prompt shown after an ad-hoc log **for today only** (never for
      a future plan — nothing's actually been eaten yet), reusing
      `ScannerView`'s "New Package Size" alert **verbatim** in shape (name
      `TextField`, "Save Variant"/"Just This Once"/"Cancel", `presenting:`
      the pending ingredients rather than a bare `Bool` so the message
      closure can describe what's being remembered). Wired from
      `DayTimelineView.addEntry` — see that bullet above for how the
      insufficient-stock alert and the remember prompt are sequenced so
      they never show simultaneously. Factored into its own file/
      `ViewModifier` rather than inlined, the same "keep the host view's
      diff small" reason as `TemplatesListView`/`TemplateEditorView` above.
    - `NameMealPrompt.swift` (FX-6) — `NameMealPromptModifier` + a
      `View.nameMealPrompt(...)` extension: the "Name This Meal" alert shown
      right after `MealCompositionEditorView`'s `onDone` fires for an ad-hoc
      meal, before it's persisted — same `alert(presenting:)` + `TextField`
      shape `RememberMealPromptModifier` established, but with a single
      "Save" button rather than three, since (unlike the remember prompt,
      which offers to *additionally* save a template after a meal that's
      already been logged) this alert **is** the commit point for a meal
      that hasn't been saved yet; leaving the field blank and tapping
      "Save" still saves, via the caller's trim-and-fallback logic
      (`DayTimelineView.addEntry(name:ingredients:slot:)`). Factored into
      its own file/`ViewModifier` for the usual "keep the host view's diff
      small" reason, and also, concretely, because inlining this alert
      directly into `DayTimelineView`'s already-long modifier chain pushed
      the Swift compiler's type-checker over its complexity budget ("unable
      to type-check this expression in reasonable time") and broke the
      build — extracting it here fixed that too.
  - `Scanners/` — Barcode scanning. Wraps `AVFoundation`
    (`AVCaptureSession`) directly via `UIViewRepresentable`; not a
    SwiftUI-native camera API, and specifically not VisionKit's
    `DataScannerViewController` (device-only, unsupported in Simulator).
  - There is no `ViewModels/` folder — views that need local UI state
    (e.g. a text field's current string) just use `@State` directly. Only
    introduce a dedicated view model if a view's *UI* logic grows complex
    enough to warrant its own tests; state that represents saved/business
    data belongs in `PantryStore` (via `appState.pantry`), not a view model.

- `Packages/FoodpointKit/` (local package, product `FoodpointKit`) — the
  composition root, no `import SwiftUI` anywhere in it. Depends on
  `FoodFoundation`, `PantryKit`, and `MealKit` (all three re-exported —
  see below):
  - `Sources/FoodpointKit/AppState.swift` — the `@Observable` state
    container the app actually uses, via the `AppState.shared` singleton
    and `@Environment(AppState.self)`; `init()` is public rather than
    private specifically so tests can construct isolated instances instead
    of sharing global state across test cases. Holds `public let pantry =
    PantryStore()` and `public let meals = MealStore()` as independent
    peers (neither knows the other exists), plus a private
    `consumedAmounts: [UUID: Double]` (keyed by `LoggedIngredient.id`) used
    only by the orchestration extension below. Deliberately **no
    forwarding properties**: call sites go through
    `appState.pantry.*`/`appState.meals.*`, not `appState.*`, since
    re-declaring `PantryStore`'s/`MealStore`'s whole surface here would
    just be boilerplate duplicating an API one property away (see
    package-architecture.md §3.5). `@_exported import FoodFoundation`,
    `@_exported import PantryKit`, and `@_exported import MealKit` at the
    top mean any file that imports `FoodpointKit` (the app included) can
    use `Product`, `PantryStore`, `FoodItem`, `MealStore`, `MealTemplate`,
    etc. directly without importing those packages itself — keep those
    re-exports if you touch this file's imports.
  - The same file's `extension AppState` (MK-3, package-architecture.md
    §3.5) is this package's whole reason for existing beyond wiring — the
    one place allowed to know both `PantryKit` and `MealKit` exist:
    - `markMealEaten(_ entryID:) -> MealEntry?` — calls `meals.markEaten`,
      then for each ingredient with `usesFromPantry` on, calls
      `pantry.consume(barcode:amount:)`. `consume` clamps to zero rather
      than going negative if stock is short (meals-feature-design.md
      §4.4) instead of blocking; the amount actually taken (which can be
      less than what was logged) is remembered in `consumedAmounts`.
      No-op, including no pantry mutation, if `entryID` isn't currently
      `.planned` — matches `MealStore.markEaten`'s own contract.
    - `undoMealEaten(_ entryID:) -> MealEntry?` — calls `meals.undo`, then
      restores pantry stock for each `usesFromPantry` ingredient by
      exactly the amount recorded in `consumedAmounts` (not naively the
      full logged amount, which would over-restore after a clamp), via
      `pantry.restore(product:unit:amount:)`. `restore` re-creates the
      `FoodItem` if `consume` had fully depleted (and thus deleted) it —
      package-architecture.md §4.3's edge case — using the ingredient's
      own snapshotted `productName`/`productBrand`/`imageURL` plus its
      `impliedUnit`/`impliedNutritionPer100g` to reconstruct a `Product`/
      `ProductUnit`, since `LoggedIngredient` never stores those directly.
    - `insufficientStockIngredients(for entryID:) -> [String]` — a pure
      read of `consumedAmounts`, for the UI to call right after
      `markMealEaten(_:)` and surface meals-feature-design.md §4.4's soft
      inline note without threading `consume`'s return value through the
      call site by hand.
    - `stockShortfalls(for entryID:) -> [MealStore.StockShortfall]` (MK-5) —
      the day timeline's soft "needs 6 eggs, you have 4" signal
      (meals-feature-design.md §5, §12 #5). Wires `MealStore`'s pure
      `stockShortfalls(for:availableQuantity:)` comparison (see the
      `MealKit` bullet below) to `pantry.items`, since this is the one
      place both stores are visible. Computed fresh from current `pantry`
      quantities on every call — never reserves, holds, or otherwise
      mutates anything — and empty for an entry that isn't currently
      `.planned` (an eaten entry's pantry effect, if any, already
      happened).
    - `restorePantryConsumption(for ingredients:)` (private, FX-5) — the
      `consumedAmounts`-precise pantry-restore loop factored out of
      `undoMealEaten` so `updateMealIngredients` (reversing the OLD
      ingredient list) and `deleteMeal` (reversing a deleted `.eaten`
      entry's consumption for good) can share it too, rather than
      tripling the same loop across three methods. Restores each
      `usesFromPantry` ingredient by exactly the amount `consumedAmounts`
      recorded for it (falling back to `ingredient.amount` if untracked),
      via `pantry.restore` so a fully-depleted item is re-created.
    - `updateMealIngredients(_ entryID:ingredients:) -> MealEntry?` (FX-4) —
      saves an edited ingredient list back onto an existing entry, the
      orchestration behind `DayTimelineView`'s row context menu and
      `MealDetailView`'s toolbar "Edit" button reopening
      `MealCompositionEditorView(initialIngredients:title:onDone:)`. For a
      `.planned` entry this is a plain `meals.updateEntry` with the new
      list — planning never touches pantry stock, so there's nothing to
      reconcile. For an `.eaten` entry it reconciles the pantry delta:
      first restores exactly what was previously taken for each
      `usesFromPantry` ingredient on the OLD list (the same
      `consumedAmounts`-precise `pantry.restore` call `undoMealEaten`
      makes, same fallback-to-`amount` rule if this entry's consumption was
      never tracked through this `AppState` instance), then decrements
      `pantry` again for each `usesFromPantry` ingredient on the NEW list
      via `pantry.consume` (clamping to zero exactly as `markMealEaten`
      does), recording the freshly-consumed amounts in `consumedAmounts`
      keyed by the new ingredients' own `id`s so a later `undoMealEaten` or
      another edit still reconciles correctly.  `usesFromPantry`-off
      ingredients, old or new, never touch inventory, matching
      `markMealEaten`/`undoMealEaten`'s own rule. No-op, including no
      pantry mutation, if `entryID` isn't a known entry.
    - `deleteMeal(_ entryID:) -> MealEntry?` (FX-5) — deletes an entry
      outright via `meals.removeEntry`, distinct from `undoMealEaten`
      (which only reverts `.eaten` back to `.planned`, keeping the entry
      around). If the removed entry was `.eaten`, restores pantry stock for
      its `usesFromPantry` ingredients via the same `restorePantryConsumption`
      helper `undoMealEaten`/`updateMealIngredients` share, including the
      fully-depleted-item-recreation case. A removed `.planned` entry has
      no pantry effect — planning never touched stock. Either way, sweeps
      any leftover `consumedAmounts` bookkeeping keyed by the removed
      entry's ingredient ids. No-op, including no pantry mutation, if
      `entryID` isn't a known entry — matches `MealStore.removeEntry`'s own
      contract.
    - `logTemplateAndMarkEaten(_ template:date:slot:) async throws -> MealEntry?`
      (MK-4, meals-feature-design.md §7) — one-tap template logging's
      orchestration-aware counterpart to `MealStore.logTemplate`, which
      alone can't decrement pantry stock (same reason `MealStore.markEaten`
      alone can't). Follows the exact `meals.instantiate` → `meals.plan` →
      `markMealEaten(_:)` two-step path ad-hoc logging already uses, so a
      template tap behaves identically to a manually composed and logged
      meal. Not covered by `FoodpointKitTests` directly — `AppState.meals`
      has no `productResolver` injection seam of its own (unlike a
      directly-constructed `MealStore` in `MealKitTests`), so exercising
      this here would need a live network call, which this repo's tests
      never make; the pieces it composes are each already covered
      separately (`MealKitTests`' `TemplateInstantiationTests`/
      `TemplatePromotionTests`, this package's own
      `MealPantryOrchestrationTests`), and the method itself is exercised
      by manual verification.
  - `Tests/FoodpointKitTests/MealPantryOrchestrationTests.swift` — Swift
    Testing, covers only this orchestration (package-architecture.md
    §4.2's "much smaller `FoodpointKitTests`"), not `PantryStore`'s/
    `MealStore`'s own logic (that's `PantryKitTests`'/`MealKitTests`' job)
    beyond what's needed to prove the two are wired together correctly —
    the cases from meals-feature-design.md §14's "FoodpointKit
    (orchestration only)" list, plus the insufficient-stock/clamp and
    §4.3 recreate-on-undo cases, and (MK-5) that planning a future meal
    has zero effect on pantry quantities or on today's eaten total, plus
    `stockShortfalls`' live/non-reserving behavior.
  - `Tests/FoodpointKitTests/MealIngredientEditTests.swift` (FX-4) — Swift
    Testing, same scope discipline as `MealPantryOrchestrationTests`:
    covers only `AppState.updateMealIngredients(_:ingredients:)`. A
    planned entry's edit never touches pantry and keeps its `.planned`
    status; an eaten entry's edit reverses the old ingredient list's
    consumption and applies the new list's exactly (including the case
    where the new amount is smaller, and where it overshoots into a clamp
    — deleting the item, same as `markMealEaten`'s own clamp — and a
    subsequent `undoMealEaten` still re-creates it correctly); a mix of
    `usesFromPantry` on/off across old and new lists only reconciles the
    ingredients with the toggle on; and an unknown `entryID` is a no-op.
  - `Tests/FoodpointKitTests/MealDeletionTests.swift` (FX-5) — Swift
    Testing, same scope discipline again: covers only `AppState.deleteMeal(_:)`.
    A planned entry's deletion never touches pantry; an eaten entry's
    deletion restores exactly what `markMealEaten` decremented, including
    the clamped-amount case (restores only what was actually taken, not the
    full logged amount) and the fully-depleted-item-recreation case;
    `usesFromPantry`-off ingredients are unaffected on either a planned or
    an eaten entry's deletion; an unknown `entryID` is a no-op, including
    calling `deleteMeal` twice on the same entry.

- `Packages/PantryKit/` (local package, product `PantryKit`) — the
  pantry's state and CRUD logic, no `import SwiftUI` anywhere in it.
  Depends on `FoodFoundation` only — no dependency on `FoodpointKit`, and
  no dependency on `MealKit` either; the two are meant to stay decoupled
  peers, per package-architecture.md §1:
  - `Sources/PantryKit/PantryStore.swift` — the `@Observable` store.
    Construct a fresh `PantryStore()` in tests, never a shared singleton —
    it's a single mutable instance and tests may run in any order. Holds
    the flat `items: [FoodItem]` list, plus two parallel variant systems
    keyed by barcode, each with a default (`unitConfigs`/`nutritionConfigs`,
    persisted independently of `items` so they survive an item being fully
    consumed) and alternates (`unitVariants`/`nutritionVariants`). Go
    through the CRUD methods rather than mutating the dictionaries
    directly:
    - Package sizes: `allVariants(forBarcode:)`, `addUnitVariant(_:forBarcode:)`,
      `updateVariant(_:forBarcode:)`, `removeVariant(_:forBarcode:)` (guards
      against deleting the default), `makeDefault(_:forBarcode:)`, and
      `renameUnitLabel(_:forBarcode:)` (the count label — e.g. "slices",
      "bars" — is a barcode-wide property shared by every variant, so this
      renames it everywhere at once rather than letting one variant's label
      drift out of sync with its siblings; a no-op for weight-tracked units,
      whose label is always "g").
    - Nutrition: the same five methods with a `Nutrition`-suffixed/-infixed
      name (`allNutritionVariants`, `addNutritionVariant`,
      `updateNutritionVariant`, `removeNutritionVariant`,
      `makeNutritionDefault`), plus two specific to reconciling with Open
      Food Facts on re-scan: `pendingNutritionUpdate(from:forBarcode:)`
      (decides whether OFF's freshly-fetched data is new/changed enough to
      ask about — `nil` if it's missing, all-zero, or unchanged from
      what's remembered) and `setDefaultNutritionVariant`/
      `refreshNutritionVariant` (apply the user's choice from that
      prompt). See `ScannerView`'s `knownProductNutritionStatus` and
      `NutritionUpdateView` for how the app drives these.
    - Meal-driven consumption (MK-3, called only from `FoodpointKit`'s
      orchestration extension — see its bullet above — never from
      `MealKit`, which has no dependency on this package):
      `consume(barcode:amount:) -> Double` decrements an item, clamping to
      zero via the existing `setQuantity` zero-deletes behavior rather
      than duplicating it, and returns the amount actually taken (less
      than requested if stock was short, letting the caller detect and
      surface that); `restore(product:unit:amount:)` adds back to an
      existing item or fully re-creates one that was deleted at zero
      (package-architecture.md §4.3's undo edge case), preferring the
      barcode's own remembered `unitConfigs`/`nutritionConfigs` entries
      over whatever the caller passed, the same way `addProduct` treats
      its own first-save-wins defaults.
  - `Sources/PantryKit/Models/FoodItem.swift` — a saved product + quantity
    + unit. The one model type that lives here rather than in
    `FoodFoundation`, since it's pantry-state shaped (references a live
    `Product`), not a shared domain vocabulary type — `MealKit` will never
    have a `FoodItem` of its own.
  - `Tests/PantryKitTests/` — Swift Testing (`import Testing`, `@Test`,
    `#expect`), not XCTest. See "Testing conventions" below.

- `Packages/FoodFoundation/` (local package, product `FoodFoundation`) —
  shared domain types and product lookup, no dependency on `FoodpointKit`
  or the app. Depends on `OpenFoodFactsKit`:
  - `Sources/FoodFoundation/ProductLookup.swift` — the *only* file, in the
    whole dependency graph, that imports `OpenFoodFactsKit` and touches its
    `FoodProduct`/`SearchedProduct`/`Nutriments` DTOs directly; everywhere
    else works with `Product`/`Nutrition`. Two stateless entry points, both
    independent of any package's state (`PantryKit` and `MealKit` each call
    whichever they need directly, never through one another):
    `ProductLookup.fetch(barcode:)` for a known barcode, and
    `ProductLookup.search(query:)` for free-text search (no barcode
    needed) — see "Product search" below for why the latter maps a
    different DTO, not `FoodProduct` again.
  - `Sources/FoodFoundation/Models/` — Plain data types: `Product`/`Nutrition`
    (the app's own domain model, decoupled from OFF's wire format;
    `Nutrition` is `Codable`/`Equatable` so `MealKit`'s
    `LoggedIngredient.nutritionSnapshot` can embed and eventually persist
    it directly),
    `ProductUnit`/`UnitTrackingMode` (how a product's quantity is counted —
    by discrete count or by weight, with the grams-per-unit math used for
    per-unit nutrition — plus a stable `id` and user-facing `name` since a
    barcode can have several named variants; `ProductUnit` is also
    `Codable`/`Equatable` for the same reason, since `MealKit`'s
    `TemplateIngredient.unit` embeds it), `NutritionVariant`/
    `NutritionSource` (a named nutrition data set tagged `.openFoodFacts`
    or `.custom` — mirrors `ProductUnit`'s variant shape), `FoodCategory`
    (best-effort category/icon guess from Open Food Facts tags), and
    `NumericInput` (`String.localizedDouble` — see "Numeric text input"
    below). Note: `ProductUnit`/`NutritionVariant` are the plain *types*
    only — their per-barcode variant CRUD lives in `PantryKit.PantryStore`,
    not here (and `MealKit` has no equivalent per-barcode CRUD at all —
    see its bullet below).
    `Nutrition.isEffectivelyEmpty` (all fields nil-or-zero) is the check
    used to treat an Open-Food-Facts entry with no real data as "no data"
    instead of displaying zeroes — some OFF products carry a `nutriments`
    object with every field blank rather than omitting it.
  - `Tests/FoodFoundationTests/` — Swift Testing, same conventions as
    `PantryKitTests`.

- `Packages/MealKit/` (local package, product `MealKit`) — the meals
  feature's state and logic, no `import SwiftUI` anywhere in it — now
  UI-visible via the app's Meals tab (MK-2's composition editor, wired to a
  real "Save"/logging action plus pantry orchestration by MK-3, in
  `FoodpointKit`). Depends on `FoodFoundation` **only** — no dependency on
  `PantryKit`, checked by grep in this package's own acceptance criteria
  (MK-1); see package-architecture.md §1/§3.4 for the "treat `PantryKit`
  and `MealKit` like separate applications" rule this exists to enforce:
  - `Sources/MealKit/MealStore.swift` — the `@Observable` store. Construct
    a fresh `MealStore()` in tests, same rule as `PantryStore`. Holds
    `templates: [MealTemplate]` and `entries: [MealEntry]`, plus template
    CRUD (`addTemplate`/`updateTemplate`/`removeTemplate`) and entry
    CRUD/lifecycle:
    - `makeIngredient(barcode:productName:productBrand:imageURL:nutritionPer100g:amount:unit:nutritionSource:usesFromPantry:)` —
      `public static`, pure, and network-free: the actual
      `grams = amount × unit.gramsPerUnit` + nutrition-scaling arithmetic
      shared by `resolveIngredient` and `instantiate` below. Extracted
      specifically so `Foodpoint/Views/MealCompositionEditorView.swift`
      (MK-2) can rebuild a `LoggedIngredient` for a locally-edited amount
      without re-fetching — pair with `LoggedIngredient.impliedUnit`/
      `.impliedNutritionPer100g` (see the Models bullet below) to
      round-trip an already-resolved ingredient through this function
      again for a new amount. `nutritionSource` (MK-6) defaults to
      `.openFoodFacts`, true of every acquisition path that resolves via
      `ProductResolver`; only the app-layer "from pantry" source
      (`MealCompositionEditorView.addFromPantry`) passes something else,
      reading the barcode's actual currently-default source out of
      `appState.pantry.nutritionConfigs` — the one place `MealKit`'s own
      code stays ignorant of "custom" nutrition existing at all.
    - `resolveIngredient`/`resolveTemplateIngredient` — resolve a barcode
      and snapshot everything a `LoggedIngredient`/`TemplateIngredient`
      needs (name, brand, image, and, for the logged variant, nutrition
      via `makeIngredient`) immediately, one network call, right now —
      never deferred, so browsing an already-added ingredient later needs
      no further call.
    - `instantiate(_:)` — turns a `MealTemplate`'s ingredients into
      `LoggedIngredient`s by **re-resolving nutrition fresh** via
      `ProductLookup.fetch` every single time, never reusing a previous
      instantiation's cached value (meals-feature-design.md §4.1) — the
      network cost is accepted, same tradeoff re-scanning a barcode
      already has elsewhere in this app. `logTemplate`/`planTemplate` wrap
      this plus `logEaten`/`plan` for one-tap logging (MK-4's
      `TemplatesListView`/`TemplateLogButton` don't call these directly,
      though — see the `FoodpointKit` bullet's `logTemplateAndMarkEaten`
      for why one-tap logging needs the orchestration layer instead).
    - `recentlyUsedIngredients()` — every distinct barcode this store has
      ever logged, one `LoggedIngredient` each, most-recently-used entry
      first; reads straight off already-snapshotted fields, so — unlike
      scan/search — it's the "from history" ingredient source (§6.1 #2)
      and never makes a network call. `lastKnownUnit(forBarcode:)` is the
      companion lookup for the *unit*, checked by the composition editor
      before prompting its first-time unit setup — `nil` means this
      barcode has never been used as a `MealKit` ingredient before,
      deliberately never falling back to `PantryKit`'s own unit config for
      the same barcode even if one exists.
    - `logEaten`/`plan` — create an entry as `.eaten` or `.planned`
      directly from already-resolved ingredients.
    - `markEaten(_:)`/`undo(_:)` — transition `.planned` <-> `.eaten` and
      return the finalized/reverted `MealEntry`, **never touching
      inventory themselves**. The caller (`FoodpointKit.AppState.markMealEaten`/
      `.undoMealEaten`, MK-3) iterates `entry.ingredients` where
      `usesFromPantry` is `true` to decrement/restore the right pantry
      items — see package-architecture.md §3.5's example and the
      `FoodpointKit` bullet above. `removeEntry` follows the same "hand
      back what changed" contract, returning the deleted entry — its
      `FoodpointKit`-level caller is `AppState.deleteMeal(_:)` (FX-5, see
      that bullet above), which restores pantry stock for a removed
      `.eaten` entry's `usesFromPantry` ingredients the same way
      `undoMealEaten` does, and does nothing pantry-related for a removed
      `.planned` one.
    - `dayTotal(for:)`/`rangeSummary(from:to:)` — nutrition aggregation.
      `.eaten` and `.planned` totals are always kept separate, never
      summed (meals-feature-design.md §8.1), and every total is a
      `NutritionCompleteness` carrying `missingCount` alongside the sum —
      never trust/display a total without checking `isComplete` first
      (§8.2, mirrors `Nutrition.isEffectivelyEmpty`'s honesty principle).
      `rangeSummary` includes every calendar day in the range, even ones
      with zero entries, so `averageEatenPerDay` is a true per-day average,
      and its result (`RangeNutritionSummary`) has a `caloricTrend`
      computed property (MK-6) — a plain `.increasing`/`.decreasing`/`.flat`
      description (never a judgment; no goals/targets exist, §11) comparing
      the mean eaten calories across the range's first vs. second half.
      Both `dayTotal`/`rangeSummary` build on `completeness(for:)`, `public
      static` (not just `private`) specifically so the composition editor's
      live running footer (MK-2) can compute the same signal over whatever's
      currently in the editor, ahead of any `MealEntry` existing.
    - `provenanceMix(for:)` (MK-6) — mirrors `completeness(for:)`: tallies
      ingredients by `nutritionSource` (Open Food Facts vs. Custom vs.
      unrecorded) into a `NutritionProvenanceMix`, for a meal detail view's
      provenance-mix display (meals-feature-design.md §8.3).
    - `consumptionStats(barcode:from:to:)`/`mostConsumed(from:to:)` — how
      often/how much a product was eaten; counts every `.eaten` ingredient
      row regardless of `usesFromPantry` ("did I eat this" != "did it come
      from my shelf" — meals-feature-design.md §9). Used as-is by MK-6's
      `ItemDetailView` Consumption section and `MostConsumedView` — no
      changes needed to either method themselves, only new view-layer
      callers with a trailing-30-day range.
    - `entries(on:calendar:)`/`entriesGroupedBySlot(on:calendar:)` (MK-5) —
      the day timeline's pure queries (meals-feature-design.md §10):
      `entries(on:)` narrows `entries` to one calendar day (`.planned` and
      `.eaten` both included — status/visual distinction is the view's
      job); `entriesGroupedBySlot(on:)` further buckets that day's entries
      by `MealSlot`, in `MealSlot.allCases`' fixed order, including empty
      slots so the timeline renders a stable section list.
    - `StockShortfall`/`stockShortfalls(for:availableQuantity:)` (MK-5,
      meals-feature-design.md §5/§12 #5) — the pure comparison behind the
      day timeline's soft "needs 6 eggs, you have 4" signal on a planned
      entry. Takes availability as a closure rather than reading
      `PantryKit` directly (this package still has zero dependency on it)
      so the check stays pure and unit-testable in isolation;
      `FoodpointKit.AppState.stockShortfalls(for:)` (see its own bullet
      above) is the real caller, supplying a closure over `pantry.items`.
      A **read-only comparison against current stock, computed fresh every
      call** — nothing here reserves or holds any quantity. Ingredients
      with `usesFromPantry` off are never flagged, and a barcode with no
      reported availability (`nil`) is treated as `0` available.
    - `MealStore.init(productResolver:)` takes a `ProductResolver =
      @Sendable (String) async throws -> Product` closure, defaulting to
      `FoodFoundation.ProductLookup.fetch`. This is a testability seam
      only — production code never overrides it — since
      `OpenFoodFactsService` has no protocol/DI seam of its own to stub in
      tests; `MealKitTests`' `StubProductResolver` (an `actor`, for
      thread-safe call counting) is injected here instead of making live
      network calls, the same no-live-network rule
      `FoodFoundationTests`/`PantryKitTests` already follow.
  - `Sources/MealKit/Models/` — `MealTemplate` (name + default slot +
    `[TemplateIngredient]`, no nutrition, no date/history — a live recipe,
    re-resolved on each use), `MealEntry` (date + slot + status + name +
    optional `templateID` + `[LoggedIngredient]` — one row on the
    timeline), `TemplateIngredient` (barcode/productName/productBrand/
    imageURL/amount/`unit: ProductUnit`/usesFromPantry — `unit` isn't
    broken out in the design doc's summary ER diagram but is required to
    make `amount` meaningful and to support genuine one-tap logging
    without re-asking "weight or count?" every time; scoped to this
    ingredient alone, never shared with `PantryKit`'s per-barcode
    configuration even for the same barcode; also has `init(logged:)`
    (MK-4) — demotes an already-resolved `LoggedIngredient` back into a
    template row, dropping `nutritionSnapshot` and reconstructing `unit`
    via `impliedUnit`, since a template resolves nutrition fresh on every
    use rather than reusing a value frozen at promotion time. This is the
    conversion behind both `TemplateEditorView`'s "New Meal"/"Edit" save
    and `RememberMealPromptModifier`'s "Save Variant"), `LoggedIngredient`
    (same identity fields as `TemplateIngredient` plus `unitLabel`,
    `gramsResolved`, `nutritionSnapshot: Nutrition?`, and (MK-6)
    `nutritionSource: NutritionSource?` — all frozen at logging time, never
    re-touched afterward: **pantry state is live, meal history is frozen**,
    meals-feature-design.md §4.3; `nutritionSource` is `nil` whenever
    `nutritionSnapshot` is, since provenance is moot with no data to
    provenance). `LoggedIngredient` also has two computed properties,
    `impliedUnit`/`impliedNutritionPer100g`, that reconstruct (respectively)
    the `ProductUnit` and per-100g `Nutrition` this ingredient was logged
    with, by inverting the `gramsResolved`/`amount` ratio and the
    `scaled(by:)` call `makeIngredient` applied — what lets the "from
    history" ingredient source (§6.1 #2, MK-2) let the amount be edited
    without a network call, since `LoggedIngredient` itself doesn't store
    a full `ProductUnit`/raw per-100g `Nutrition`, only the frozen,
    already-scaled results. `MealSlot`
    (`.breakfast`/`.lunch`/`.dinner`/`.snack`, fixed — not user-configurable
    — with a `current(at:calendar:)` time-of-day default; also `Hashable`,
    MK-4, so `TemplateEditorView`'s `Picker(selection:)` can bind to it
    directly instead of round-tripping through `rawValue`), `MealStatus`
    (`.planned`/`.eaten`), and `NutritionCompleteness`/`DayNutritionTotal`/
    `RangeNutritionSummary` (+ `caloricTrend`, MK-6)/`ConsumptionStats`/
    `NutritionProvenanceMix` (MK-6, `MealStore.provenanceMix(for:)`'s
    result type) — the aggregation/stats result types `MealStore` returns.
    `FoodFoundation.NutritionSource` (already used by `PantryKit`'s
    `NutritionVariant`) picked up `Codable` conformance for this — it's
    otherwise unchanged, still the one provenance-tag type; `MealKit`
    reuses it rather than inventing its own.
  - `Sources/MealKit/NutritionMath.swift` — `internal` `+`/`/` operators on
    `FoodFoundation.Nutrition`, used only by this package's aggregation.
    Kept local to `MealKit` rather than added to `FoodFoundation`, since
    summing nutrition is a meals-specific concern nothing in `PantryKit`
    needs.
  - `Tests/MealKitTests/` — Swift Testing, same conventions as
    `PantryKitTests`/`FoodFoundationTests`; see `TestSupport.swift`'s
    `StubProductResolver`/`Fixture` for this package's fixture pattern.
    `IngredientCompositionTests.swift` (MK-2) covers the pure,
    network-free logic added for the composition editor —
    `makeIngredient`, the public `completeness(for:)`,
    `recentlyUsedIngredients()`, `lastKnownUnit(forBarcode:)`, and
    `LoggedIngredient.impliedUnit`/`.impliedNutritionPer100g` — all
    without a `StubProductResolver`, since none of it makes a resolver
    call. `ProvenanceMixTests.swift` (MK-6) covers `provenanceMix(for:)`
    and `makeIngredient`'s `nutritionSource` threading; `RangeTrendTests.swift`
    (MK-6) covers `RangeNutritionSummary.caloricTrend`'s increasing/
    decreasing/flat/empty-range cases — both new, pure, network-free
    suites in the same no-`StubProductResolver` style.
    `TemplatePromotionTests.swift` (MK-4) covers
    `TemplateIngredient.init(logged:)` (pure, no resolver) and
    `logTemplate`/`planTemplate`'s instantiate-and-log semantics (with a
    `StubProductResolver`, since `instantiate` does resolve) — the latter
    previously untested even though `instantiate` itself already was
    (`TemplateInstantiationTests.swift`, MK-3).

- `Packages/OpenFoodFactsKit/` (local package, product `OpenFoodFactsKit`) —
  all networking and wire-format types for Open Food Facts' APIs:
  `OpenFoodFactsService` (the client) with two methods hitting two
  different services — `fetchProduct(barcode:)` (the v2 product API,
  `world.openfoodfacts.org`) and `searchProducts(query:)` (search-a-licious,
  `search.openfoodfacts.org` — see "Product search" below for why it's a
  separate service, not a parameter on the v2 API) — plus `FoodProduct`/
  `SearchedProduct`/`Nutriments` (Decodable DTOs) and `OpenFoodFactsError`.
  Public so `FoodFoundation` can consume them, but treat them as
  **wire-format only** — never store one on a model or pass one outside
  `ProductLookup.swift`. Has no dependency on any other package
  (dependency direction is one-way: `Foodpoint` app -> `FoodpointKit` ->
  `PantryKit` -> `FoodFoundation` -> `OpenFoodFactsKit`).

All five packages build standalone (`cd Packages/<name> && swift build`),
and are kept free of any dependency on the app target — that's what makes
them unit-testable without a simulator.

## Numeric text input

Never parse a user-typed number with plain `Double(someText)`. A
`.decimalPad` keyboard shows "," as the decimal separator key in many
locales (e.g. German) — `Double.init?(String)` only ever accepts "." and
silently returns `nil` for "5,2", dropping the value as if never entered.
This was a real, previously-shipped bug. Always use
`someText.localizedDouble` (`FoodFoundation`'s `String` extension) instead,
in both the app and any new package code.

## Product search

Open Food Facts' v2/v3 product API does **not** support free-text search —
confirmed against the live API and current docs while building this, not
assumed. Text search goes through a genuinely different service,
search-a-licious (`search.openfoodfacts.org`), with its own response
shape. The one field that actually differs from `FoodProduct` (confirmed
by comparing real responses from both endpoints): **`brands` is an array**
on search results (`["Fresh Banana"]`) where the by-barcode endpoint
returns a single comma-separated string (`"Nutella, Ferrero"`). That's why
`SearchedProduct` is its own type rather than reusing `FoodProduct` — decode
one endpoint's JSON as the other's DTO and it silently fails or crashes.
`Product(searchedProduct:)` joins the array with `", "` so the rest of the
app never has to know which acquisition path a `Product` came from. The
nested `nutriments` object uses identical field names on both endpoints,
so `Nutriments`/`Nutrition.init(offNutriments:)` are reused unchanged.

If Open Food Facts' search API changes again, re-verify against the live
endpoint (`curl` it) rather than assuming the response shape — that's what
caught this the first time.

## Testing conventions

Every package's test target uses **Swift Testing**, not XCTest —
`import Testing`, `@Suite`/`@Test`, `#expect(...)`/`#require(...)`, `throws`
for tests that need to fail loudly on setup errors. Match this style for
new tests rather than introducing XCTest.

- Construct a fresh `PantryStore()` per test — never share a global
  singleton across tests, since it's a single mutable instance and tests
  may run in any order.
- Test business logic (`PantryStore`'s CRUD in `PantryKitTests`; model
  computed properties/static factories like `ProductUnit.make` in
  `FoodFoundationTests`) thoroughly; there is no view-layer test target,
  so don't try to test SwiftUI views here.
- `FoodFoundationTests/ProductMappingTests.swift` builds
  `OpenFoodFactsKit.FoodProduct` fixtures by decoding realistic JSON
  strings (`JSONDecoder().decode(FoodProduct.self, from:)`) rather than a
  memberwise initializer — the OFF package intentionally has no public
  memberwise init for its DTOs (only the synthesized `Decodable.init(from:)`),
  so this is also the only test approach that would actually notice a
  `CodingKeys` mistake.
- When you fix a bug, add a regression test for it in the same commit, in
  whichever package's test target actually owns the affected code — see
  `FoodFoundationTests/NumericInputTests.swift`'s comma-decimal test for
  the pattern (name the test after the bug, not just the feature).
- `MealKitTests` never makes a live network call: `MealStore` takes a
  `productResolver` closure (defaulting to `FoodFoundation.ProductLookup.fetch`
  in production), and tests inject `TestSupport.swift`'s
  `StubProductResolver` instead — an `actor` so its call count can be read
  safely from `async` test bodies. Use this same seam rather than adding a
  new one if `MealStore` grows another network-calling method.

## Adding a new package dependency

Adding a local Swift package to the Xcode project (a new package, not a
new file in an existing one) requires hand-editing `project.pbxproj` — this
project has no packages added via Xcode's GUI to copy prior art from; the
existing `OpenFoodFactsKit`/`FoodpointKit`/`FoodFoundation`/`PantryKit`
entries (all hand-added the same way) are the template. The shape needed
(see the existing `F00DFACE...` entries as a template):
1. A `PBXBuildFile` wrapping a `productRef` (in the app target's
   `Frameworks` build phase's `files`).
2. An `XCLocalSwiftPackageReference` (`relativePath` to the package
   directory) added to the project's `packageReferences`.
3. An `XCSwiftPackageProductDependency` referencing that package reference,
   added to the target's `packageProductDependencies`.
Generate fresh, non-colliding 24-hex-character object IDs for each (the
existing entries use an `F00DFACE...` prefix purely as a readable marker,
not a requirement) — then build immediately to confirm the graph resolves
before making further changes.

## Deploying to a device

If the user has granted standing permission to deploy to a connected
physical iPhone for the session, after building for the simulator also
build/install/launch on the device:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Foodpoint.xcodeproj -scheme Foodpoint \
  -destination 'id=<device-udid>' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device install app --device <device-udid> \
  <path-to>/Foodpoint.app

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun devicectl device process launch --device <device-udid> fseidl.Foodpoint
```

Find the device UDID with `xcrun xctrace list devices`. If launch fails
with a "device not unlocked" error, the build/install still succeeded —
just ask the user to unlock and open the app themselves.

## Style notes

- Prefer editing/extending existing files over introducing new
  abstractions or dependencies. This is a small prototype; don't add
  frameworks, DI containers, or layers it doesn't need yet.
- See "Documentation is mandatory here" above — this repo's comment
  policy is an explicit exception to the general minimal-comments default.
