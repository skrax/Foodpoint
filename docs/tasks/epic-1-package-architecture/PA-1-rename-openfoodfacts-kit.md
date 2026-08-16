---
id: PA-1
epic: package-architecture
title: Rename OpenFoodFacts package to OpenFoodFactsKit
status: ready
depends_on: []
design_doc: package-architecture.md#31-openfoodfactskit-renamed-from-openfoodfacts
---

# PA-1 — Rename OpenFoodFacts package to OpenFoodFactsKit

## Story

As a developer, I want the Open Food Facts client package renamed to match
the naming convention of the other four packages, so later restructuring
diffs aren't tangled up with an unrelated rename.

## Scope

Purely mechanical — no behavior or API changes:

- `Packages/OpenFoodFacts/` → `Packages/OpenFoodFactsKit/`
- `Package.swift`: `name:`, product name, target name
- `project.pbxproj`: `XCLocalSwiftPackageReference` `relativePath`,
  `XCSwiftPackageProductDependency`
- Every `import OpenFoodFacts` → `import OpenFoodFactsKit` (currently only
  `FoodpointKit/ProductMapping.swift` and its test target)
- README.md / AGENTS.md project-layout references

## Acceptance criteria

- [ ] Package folder and `Package.swift` renamed
- [ ] `project.pbxproj` references updated; package graph resolves
- [ ] All imports updated
- [ ] `swift test` in the renamed package passes, unchanged assertions
- [ ] Full app build succeeds (simulator + device)
- [ ] README.md / AGENTS.md updated

## Out of scope

- Any new capability (search lands in PA-3)
- Any change to `OpenFoodFactsService`/`FoodProduct`/`Nutriments` behavior

## Definition of done

Builds clean on simulator and device, existing test suite passes unchanged,
docs updated, committed.
