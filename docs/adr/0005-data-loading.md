# ADR 0005: Rules data is loaded as JSON dictionaries through the Compendium

Status: accepted (Phase 1)

The plan (§4) suggested importing JSON into typed Godot `Resource` classes at build time. Phase 1 loads the JSON
directly instead: `Compendium.shared()` reads every `data/<folder>/*.json` once and looks entries up by id.

- One source of truth: the JSON files, validated in CI against `data/schemas` plus cross-file checks (every item,
  feat and spell id a file names must exist; later-phase references are reported, not failed).
- Agents edit and diff plain JSON; there is no generated layer to keep in sync.
- Typed code lives where it pays: runtime models (`Creature`, `Character`, `Choice`, `Breakdown`) are typed classes;
  static data stays dictionaries read through small accessors.
- Loading ~530 files takes well under a second headless.

Revisit if load time, editor inspection of data, or export size makes Resources worthwhile; a converter could then
be added without changing the data or the engine's callers.
