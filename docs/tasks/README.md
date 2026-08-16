# Foodpoint — Task Board

Source design docs: [design-brief.md](../design-brief.md),
[meals-feature-design.md](../meals-feature-design.md),
[package-architecture.md](../package-architecture.md).

---

## How this works

Each task is one file under `epic-*/ID-slug.md`, with YAML frontmatter:

```yaml
id: PA-1
epic: package-architecture
title: ...
status: backlog | ready | in-progress | done
depends_on: [PA-...]
design_doc: package-architecture.md#anchor
```

- **backlog** — defined, but a dependency isn't done yet
- **ready** — every dependency is `done`; can be started
- **in-progress** — actively being worked
- **done** — meets its Definition of Done, committed

**A task is only "ready" once every ID in its `depends_on` is `done`.**
When you finish a task, flip its `status` to `done`, then re-check any
tasks that named it as a dependency — flip those to `ready` if everything
*they* depend on is now also done. This file's tables are the
human-readable summary of that same state; keep them in sync by hand when
a status changes (or ask Claude to do it — it can grep every file's
frontmatter and regenerate the tables below).

## Dependency graph

```mermaid
graph TD
    PA1["PA-1 Rename to OpenFoodFactsKit"] --> PA2["PA-2 Extract FoodFoundation"]
    PA2 --> PA3["PA-3 Add product search"]
    PA2 --> PA4["PA-4 Extract PantryKit"]
    PA4 --> PA5["PA-5 Slim FoodpointKit"]

    PA5 --> MK1["MK-1 MealKit model + aggregation"]
    PA3 --> MK1
    MK1 --> MK2["MK-2 Composition editor"]
    PA3 --> MK2
    MK1 --> MK3["MK-3 Manual logging + orchestration"]
    MK2 --> MK3
    PA5 --> MK3
    MK3 --> MK4["MK-4 Templates + one-tap logging"]
    MK3 --> MK5["MK-5 Planning + tick-off"]
    MK3 --> MK6["MK-6 Range summary + consumption"]
```

## Epic 1 — Package Architecture Restructuring

Prerequisite for meals; no new user-facing behavior. See
[package-architecture.md](../package-architecture.md).

| ID | Title | Status | Depends on |
|----|-------|--------|-----------|
| [PA-1](epic-1-package-architecture/PA-1-rename-openfoodfacts-kit.md) | Rename OpenFoodFacts → OpenFoodFactsKit | ready | — |
| [PA-2](epic-1-package-architecture/PA-2-extract-food-foundation.md) | Extract FoodFoundation | backlog | PA-1 |
| [PA-3](epic-1-package-architecture/PA-3-add-product-search.md) | Add product search (no-barcode acquisition) | backlog | PA-2 |
| [PA-4](epic-1-package-architecture/PA-4-extract-pantry-kit.md) | Extract PantryKit | backlog | PA-2 |
| [PA-5](epic-1-package-architecture/PA-5-slim-foodpoint-kit.md) | Slim FoodpointKit to a composition root | backlog | PA-4 |

## Epic 2 — Meals Feature

See [meals-feature-design.md](../meals-feature-design.md). Depends on
Epic 1 being fully done (PA-5) before it can start in earnest, though
MK-1 only strictly needs PA-5 + PA-3.

| ID | Title | Status | Depends on |
|----|-------|--------|-----------|
| [MK-1](epic-2-meals-feature/MK-1-mealkit-model-and-aggregation.md) | MealKit core model and aggregation | backlog | PA-5, PA-3 |
| [MK-2](epic-2-meals-feature/MK-2-meal-composition-editor.md) | Meal composition editor and ingredient acquisition | backlog | MK-1, PA-3 |
| [MK-3](epic-2-meals-feature/MK-3-manual-logging-and-orchestration.md) | Manual logging loop and pantry orchestration | backlog | MK-1, MK-2, PA-5 |
| [MK-4](epic-2-meals-feature/MK-4-templates-and-one-tap-logging.md) | Templates and one-tap logging | backlog | MK-3 |
| [MK-5](epic-2-meals-feature/MK-5-planning-and-tick-off.md) | Planning and tick-off | backlog | MK-3 |
| [MK-6](epic-2-meals-feature/MK-6-range-summary-and-consumption.md) | Range summary and consumption surfaces | backlog | MK-3 |

## What's next

Only **PA-1** is unblocked right now — everything else waits on some part
of the package restructuring landing first. Epic 1 is a straight line
(PA-1 → PA-2 → {PA-3, PA-4 → PA-5}); Epic 2 fans out from MK-3 once the
core loop exists — MK-4, MK-5, and MK-6 don't depend on each other and can
happen in any order (or in parallel) once MK-3 is done.
