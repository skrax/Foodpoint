# Foodpoint — Design Brief

**Purpose of this document:** ground design decisions for a new, large feature by
describing what Foodpoint currently is — how a user actually moves through the
app, what every screen lets them do, what data does and doesn't exist, and
where the current design already works well or falls short. It intentionally
does not propose the new feature itself; it's the "current state" half of the
brief, so the person or model designing the feature (Fable) isn't guessing at
context or re-deriving it from the source.

---

## 1. What Foodpoint is today

Foodpoint is a solo-developer, early-stage iOS prototype for tracking pantry
inventory. The entire product is one loop: **scan a barcode → look up the
product on Open Food Facts → save it into a flat, quantity-tracked list.**
There are no accounts, no backend of its own, no sync, and (see §7) no data
persistence between app launches — it is genuinely a prototype, not a
shipped product with real users beyond the developer.

Two tabs make up the whole app: **Items** (browse/manage what's saved) and
**Scan** (add to or update the list). Nothing else is reachable from a tab
bar or menu — every other screen is a sheet opened from one of these two.

A "locations" feature (organizing items into named places — pantry, fridge,
freezer) was previously built in full and then deliberately scrapped in favor
of the current single flat list. That's relevant context: multi-location
tracking has already been tried once and removed, not simply never
considered.

## 2. Navigation map

```
ContentView (TabView)
├── Items tab
│   └── ItemsView (flat, alphabetical list)
│       └── ItemDetailView (per item, pushed)
│           ├── sheet → PackageVariantsView (.manage)
│           │             └── sheet → VariantEditForm
│           └── sheet → NutritionVariantsView
│                         └── sheet → NutritionVariantEditForm
└── Scan tab
    └── ScannerView
        ├── sheet → camera (FastFoodBarcodeScanner + ViewfinderOverlay)
        ├── (new barcode)  → unitConfigFields inline
        │                     └── sheet → NutritionVariantEditForm (new)
        ├── (known barcode) → knownUnitFields inline
        │                     ├── sheet → PackageVariantsView (.select)
        │                     ├── sheet → NutritionVariantsView
        │                     └── sheet → NutritionUpdateView (conditional)
        └── alert → variant-name prompt (Save Variant / Just This Once)
```

Every "management" screen (`PackageVariantsView`, `NutritionVariantsView`)
is reachable from **two** places — the scan screen and the item detail
screen — and both lead to the same underlying `AppState` data, keyed by
barcode, not by the specific item or scan session.

## 3. Screen inventory

| Screen | Reached from | Purpose |
|---|---|---|
| `ItemsView` | Items tab | Flat, alphabetically-sorted list of every saved product. Empty state if nothing saved. |
| `ItemDetailView` | Tapping an item row | Per-100g and per-unit nutrition, editable quantity (±1 buttons + free-text), entry points to manage package sizes / nutrition. Auto-dismisses if quantity is driven to 0. |
| `ScannerView` | Scan tab | Camera trigger, then (for the currently scanned product) either full unit setup (new barcode) or a fast weight-only re-entry (known barcode), plus Save/Discard. |
| `PackageVariantsView` | "Package Sizes" button (Scan or Item Detail) | List of every named package-size variant for a barcode; add, rename/resize, delete (not the default), set default. Two modes: `.select` (scan flow — picking a size fills the weight field) and `.manage` (item detail — pure CRUD). |
| `VariantEditForm` | Row tap / pencil / "+" in `PackageVariantsView` | Edit one package-size variant: name, weight, (for count-tracked units) count label and count, make-default, delete. |
| `NutritionVariantsView` | "Nutrition" button (Scan or Item Detail) | List of every nutrition data set for a barcode, each tagged "Open Food Facts" or "Custom"; add, edit, delete (not the default), set default. Mirrors `PackageVariantsView` exactly. |
| `NutritionVariantEditForm` | Row tap / pencil / "+" in `NutritionVariantsView`, or the "Add Nutrition Values" banner on a new scan | Edit one nutrition data set (7 fields, per 100g). Open-Food-Facts-sourced entries are read-only; only Custom entries can be typed into. |
| `NutritionUpdateView` | Automatically, when re-scanning finds Open Food Facts data that's new or changed since last seen | Side-by-side comparison of the current vs. updated Open Food Facts values; pick one or defer ("Later"). |

## 4. Core user flows

### 4.1 Scanning a brand-new product
1. Scan tab → "Scan Food Barcode" → camera sheet opens full-screen with a
   viewfinder overlay.
2. First EAN-13/UPC-E/EAN-8 detected fires haptic feedback and closes the
   camera automatically — no manual capture button, no barcode format
   picker.
3. App calls Open Food Facts over the network; a spinner ("Fetching product
   details…") is the only feedback during the wait.
4. On success, a product card (image, name, brand, category badge,
   Nutri-Score, nutrition facts if OFF had any) appears, followed by a
   **fully editable** setup: Weight/Count tracking-mode picker, package
   weight, and (if Count) a count label and count-per-package field with a
   live "≈ Xg per slice" preview. If OFF had no usable nutrition data, a
   banner offers "Add Nutrition Values" — this saves immediately and
   independently of the main Save button.
5. Tapping "Save" creates the item, and the entered unit becomes this
   barcode's **permanent default** for every future scan. The camera
   reopens automatically for the next item — the loop is designed for
   rapid, repeated scanning, not one-and-done.
6. If the OFF lookup fails (no network, or the barcode isn't in OFF's
   database), the user sees a plain error screen and can only try scanning
   again — there's no manual/offline way to add a product.

### 4.2 Re-scanning a known product, same size
1. Same scan → lookup steps, but because the barcode already has a saved
   unit config, the form is a **narrower** re-entry: tracking mode is shown
   but disabled, the weight field is pre-filled, and (for count-tracked
   items) the count is derived and shown read-only from the fixed
   grams-per-unit — nothing to retype.
2. Save matches the (unchanged) weight against the barcode's known
   variants, and — since it matches the default — increments the existing
   item's quantity immediately. No prompts.

### 4.3 Re-scanning with a different package size
1. Same as 4.2, but the user edits the weight field to a size that doesn't
   match any known variant.
2. Save triggers an alert: name this size (e.g. "Small") and choose "Save
   Variant" (remembered for future scans, selectable from Package Sizes) or
   "Just This Once" (used for this save only, not remembered).

### 4.4 Managing package-size variants
1. From either the scan screen or an item's detail view, "Package Sizes"
   opens a list of every variant for that barcode — the default first,
   tagged "Default" — each showing name and a weight/count summary.
2. Swipe-to-delete works on any non-default row; the default can't be
   deleted this way (or via the edit form's delete button, which is hidden
   for it).
3. Tapping a row (or its pencil) opens the edit form: rename, reweigh,
   recount, and — since today's change — rename the shared count label
   (e.g. correct "slice" to "bar"); this now updates every variant of the
   barcode at once, since they're meant to share one counting unit. A
   non-default variant can also be promoted with "Make Default", which
   demotes the previous default into the list rather than discarding it.
4. "+" adds a new named variant, pre-filled with the barcode's existing
   tracking mode and label (both of which stay locked for a *new* variant
   — only an edit can rename the label).

### 4.5 Managing nutrition variants
Structurally identical to 4.4 (same list/edit/default/delete pattern), with
one difference: Open-Food-Facts-sourced entries are **read-only** — their
fields are disabled, with a footnote explaining that a Custom entry should
be added instead if OFF's numbers are wrong. Only Custom entries can be
typed into, renamed, or deleted.

### 4.6 Reviewing changed Open Food Facts data
If a re-scan's live OFF fetch differs meaningfully from what's remembered
for that barcode (a real diff — tiny floating-point drift doesn't count,
and an unchanged fetch doesn't re-prompt), the scan screen shows a "Review"
button instead of the plain "Nutrition" one. Tapping it shows the current
and updated values side by side; picking one sets it as the default (the
other becomes an alternate), or "Later" leaves the choice unresolved and
simply remembers OFF's new numbers so the same diff isn't surfaced again on
the next scan.

### 4.7 Browsing and adjusting the pantry
1. Items tab shows every saved product, alphabetically, with category icon,
   name, brand, and current quantity — no search, filter, or grouping.
2. Tapping an item opens detail: nutrition (per 100g, and per practical unit
   like "per bar" if a weight-per-unit is known), a quantity stepper
   (±1 buttons or free-text entry), and the Package Sizes / Nutrition
   management buttons.
3. Driving quantity to 0 — via the minus button or typing 0 directly —
   removes the item outright and the detail view dismisses itself. There is
   no confirmation before this, unlike deleting a variant.

## 5. Data model

Everything lives in one `@Observable` in-memory class (`AppState`), keyed by
barcode:

- **`Product`** — id (barcode), name, brand, image URL, Nutri-Score,
  category tags, and a mutable `nutrition` field kept in sync with whichever
  nutrition variant is currently the barcode's default.
- **`FoodItem`** — one per barcode currently in the pantry: the product, a
  remaining `quantity`, and the `ProductUnit` it's tracked in. No purchase
  date, no expiration date, no price, no location/shelf, no notes, no photo
  other than OFF's.
- **`ProductUnit`** — how a barcode's quantity is counted: `.weight` (label
  always "g") or `.count` (a free-text label like "bars" or "slices", plus
  optional grams-per-unit for per-serving nutrition math). A barcode can
  have several named variants (Default + alternates), but **all variants of
  one barcode share the same tracking mode and label** — that's a
  deliberate constraint, not an oversight, and it's what makes "rename this
  barcode's label" a barcode-wide operation rather than a per-variant one.
- **`NutritionVariant`** — a named per-100g nutrition data set, tagged
  `.openFoodFacts` or `.custom`. Same default+alternates shape as
  `ProductUnit`.
- **`FoodCategory`** — a coarse, cosmetic-only guess (icon + label) derived
  from OFF's category tags via keyword matching. Not stored, not
  user-editable, and not currently used to filter or group anything in the
  UI — it only decorates rows and cards.

Notably absent from the model entirely: **any date field** (purchase,
opened, expiration), **location/place**, **price/cost**, **notes/photos
beyond OFF's**, **multi-user or household concepts**, and **any grouping
above "one flat list of barcodes."**

## 6. Interaction patterns already established

A new feature that wants to feel native to this app should recognize (and
where sensible, reuse) these recurring patterns rather than inventing new
ones:

- **Provenance badges.** Anything that could come from Open Food Facts or
  from the user is tagged with a small colored badge (blue = Open Food
  Facts, orange = Custom) everywhere it's shown — the product card, the
  variant lists, the update-review screen. This is the app's strongest,
  most consistent trust signal.
- **Default + named alternates.** Both package sizes and nutrition data use
  the identical shape: one default (persists independently of the item
  itself), any number of named alternates, and five mirrored operations
  (list all / add / update / remove-guards-default / make-default). This
  pattern is proven, unit-tested, and reusable for any future "several
  named configurations of the same thing" need.
- **Fast path vs. management screen.** The common case (re-scanning the
  usual size) gets a narrow, low-friction inline form; the uncommon case
  (renaming, adding, deleting, choosing a default) is pushed one tap away
  into a dedicated list screen. Nothing forces the user through full CRUD
  UI for routine use.
- **Reuse over re-entry.** A barcode is only ever configured "from scratch"
  once. Every later scan defaults to what's already known and only asks a
  question (name this new size? use OFF's new numbers?) when something
  actually differs from what's remembered.
- **Explicit save, with one exception.** Nothing is committed until the
  user taps a visible "Save" — except nutrition entered via the "Add
  Nutrition Values" banner on a new scan, which commits immediately,
  independent of the surrounding Save button. Worth knowing about since
  it's the one inconsistency in an otherwise explicit-save app.
- **Confirm destructive, except quantity-to-zero.** Deleting a variant
  always asks for confirmation; driving an item's quantity to 0 (which
  deletes the item) does not.

## 7. Strengths

- **Frictionless core loop.** Point the camera, get product info back, tap
  once to save. No forms to fill in for the common case.
- **Zero setup cost.** No accounts, no login, nothing to configure before
  the first scan — Open Food Facts is queried anonymously.
- **Takes "how is this counted" seriously.** Most simple pantry trackers
  either force everything into a single unit or ignore nutrition math
  entirely. Foodpoint lets nutrition be shown per practical serving ("per
  bar") derived from a user-supplied package weight and count, not just
  OFF's raw per-100g figures.
- **A genuinely reusable variant pattern**, proven twice already (package
  sizes, then nutrition), with full unit-test coverage in `FoodpointKit` —
  a strong, low-risk foundation if the new feature also needs "several
  named configurations of one thing."
- **Correct locale-aware numeric input.** Every numeric field parses both
  "5.2" and "5,2" — a real bug that was found and fixed everywhere, not
  just where it was first reported, and is now guarded by a regression
  test and documented for future contributors.
- **Clean separation of business logic from UI.** All state and rules live
  in the UI-agnostic `FoodpointKit` package with its own test suite; the
  app is a thin SwiftUI driver on top. A large new feature's *logic* can be
  designed and verified without touching a simulator.

## 8. Weaknesses

- **No persistence at all.** `AppState` is a plain in-memory `@Observable`
  singleton — there is no `UserDefaults`, file, `SwiftData`, or `CoreData`
  usage anywhere in the app. Force-quitting Foodpoint (or letting iOS evict
  it) silently erases the entire pantry, every configured unit, and every
  nutrition entry. This is the single largest structural fact to weigh
  before committing to any big feature: is durable storage now in scope, or
  does the new feature also have to assume state that vanishes on restart?
- **A barcode is the only way in.** Every item must be a real, scannable
  EAN-13/UPC-E/EAN-8 that Open Food Facts already knows about. There is no
  manual/offline product entry, no way to type a barcode that failed to
  scan, and no path at all for fresh produce, bulk bins, homemade food, or
  regional products missing from OFF's crowdsourced database.
- **No freshness tracking.** No purchase date, no expiration date, no
  "opened on" — arguably the single most-wanted feature of a pantry app
  (what's about to go bad) is entirely absent from the data model, not just
  the UI.
- **One flat list, one implicit location.** Multi-location tracking
  (pantry/fridge/freezer) was built once and explicitly removed; there is
  currently no way to distinguish where something is, and no household or
  multi-user concept at all.
- **No search, filter, or grouping** in the item list — `FoodCategory`
  exists and is computed, but is purely decorative today; it doesn't drive
  any organization of the list.
- **No graceful failure path.** A failed OFF lookup (offline, or an unknown
  barcode) is a dead end — retry by scanning again, nothing else.
- **No accessibility or localization investment.** No
  `accessibilityLabel`/`accessibilityHint` usage and no
  `Localizable.strings`/`String(localized:)` anywhere — all copy is
  hardcoded English.
- **Single device, no sync.** Everything lives in one process's memory on
  one phone; there's no concept of a second device or a shared household
  pantry.

## 9. Pain points (concrete, from actually using the app)

- Force-quitting the app loses everything — no warning, no recovery.
- Scanning a product OFF doesn't recognize (common for regional or
  house-brand groceries) is a dead end with no manual fallback.
- Every single scan — even of a barcode already fully configured — still
  makes a live network call before the "known product, just increment
  quantity" fast path is even shown; there's no offline mode.
- There's no way to remove or adjust an item straight from `ItemsView` —
  you must navigate into `ItemDetailView` first, even to just discard one
  item.
- Nothing tells you what's about to expire, what you're low on, or what you
  haven't touched in a while — the list is just a static inventory count.
- The package-size/nutrition management screens are one unlabeled icon-only
  button away from the scan/detail screens; a first-time user has no strong
  cue that variants exist at all until they go looking.
- Switching a product from count-tracking to weight-tracking (or vice
  versa) isn't possible without deleting it and starting over — the mode
  picker is permanently locked once set.

## 10. Gains — what already works and shouldn't be broken

- The **provenance-badge convention** (Open Food Facts vs. Custom) should
  extend to any new data type the feature introduces that could plausibly
  come from either an external source or the user.
- The **default + alternates pattern**, with its five mirrored CRUD
  operations, is the app's proven way of handling "one main configuration,
  several named others" — a new feature needing that shape should reuse it
  rather than reinvent it.
- The **fast-path-vs-management-screen split** keeps the common case
  (re-scan, adjust quantity) fast while still making full control
  available a tap away — worth preserving as the interaction model for any
  new frequent action.
- The **"only ask when something actually changed"** instinct behind
  `pendingNutritionUpdate` (and the matching-variant check on save) avoids
  nagging; a new feature with recurring prompts should apply the same
  change-detection discipline rather than asking every time.
- The **FoodpointKit / thin-SwiftUI-driver split** means a big feature's
  core logic can be designed, written, and unit-tested independently of
  the UI — use this boundary rather than pushing new logic into views.

## 11. Constraints to design within

- iOS only (SwiftUI, `@Observable`/Observation, iOS 17+), no watchOS/macOS
  app, no web presence.
- No backend of Foodpoint's own — Open Food Facts is the only external
  service, queried anonymously with no API key and no rate-limit handling.
- Solo-developer, early-stage codebase — the existing convention (see
  `AGENTS.md`) is to favor small, direct changes over speculative
  abstraction; a big feature should still fit that spirit where possible
  rather than introducing heavy new infrastructure unless the feature
  genuinely requires it (e.g. persistence, which currently doesn't exist at
  all).
- No accessibility, localization, or multi-device/sync work has been done
  anywhere in the codebase yet — treat all three as unstarted, not
  partially done, if the new feature depends on any of them.

## 12. Open questions worth resolving before/while designing the new feature

- Does this feature require durable storage? If so, that's arguably a
  bigger architectural decision than the feature itself, since nothing
  persists today.
- Does it need a way to add items that aren't scannable barcodes (produce,
  homemade food, items missing from OFF)?
- Does it need dates (expiration, purchase) — and if so, does that belong
  on `ProductUnit` (per package size) or a new concept entirely?
- Does it need to distinguish where something is (reviving some version of
  the scrapped locations feature), or is a flat list still the right model
  for it?
- Should it reuse the default+alternates variant pattern, or does it need a
  genuinely different data shape?
- Is single-device/no-sync acceptable for this feature, or does it assume
  a household/multi-user context that doesn't exist yet?
