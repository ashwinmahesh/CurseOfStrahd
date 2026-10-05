# ADR 0003: Rules engine is a pure library that returns events (draft)

Status: draft — to be finished in Phase 1 with the effects system

- `rules/` never references nodes, scenes, autoloads or UI.
- Resolution functions take state + a DiceRoller and return result objects (e.g. `D20Test`) with a
  `describe()` for the combat log. Phase 1 adds an event list (`AttackRolled`, `DamageTaken`, `ConditionApplied` ...).
- Data files reference reusable effect primitives through `effect_ref` (`{"effect": id, "params": {...}}`, see
  `data/schemas/common.schema.json`). Only unique features get bespoke code in `rules/features/`.
