# ADR 0003: The rules engine is a pure library of creatures, modifiers and effects

Status: accepted (Phase 1)

- `rules/` never references nodes, scenes, autoloads or UI (`make lint` compiles every rules script on its own, so an
  autoload reference fails CI). Randomness comes in as a `DiceRoller` argument.
- **Creature** (characters, monsters, NPCs) holds runtime state: Hit Points, Temporary HP, conditions, exhaustion,
  death saves, effects, Concentration, resources. **Character** derives everything else from its `build` record and
  the data on every `refresh()`; **Monster** from its stat block.
- **Modifiers** (docs/contracts/modifiers.md) are how features, feats, species, items, spells and conditions change
  numbers. Data names a `stat`; the engine reads it. A feature the vocabulary can't express is a named `flag` that
  bespoke code reads, or `implemented: "text"` until its system exists. New stats are added to the contract and the
  engine together, never invented in data.
- **Effects** carry modifiers and/or conditions, a source and a duration (rounds, start/end of a creature's turn,
  minutes, rests). Identical effects don't stack: the most potent applies, then the most recent (deviations.md).
- **Concentration** links a caster to the effects it keeps alive on any creature; breaking it removes them. Effects
  hold their Concentration weakly so there are no reference cycles.
- **Every number is a Breakdown** (ADR 0006), and every roll goes through `Creature.roll_d20`, which gathers named
  Advantage/Disadvantage sources, automatic failures and bonus dice, so the combat log can explain it.
- **Events**: actions append plain dictionaries to `Creature.events` (`drain_events()` hands them to the caller);
  types are listed in docs/contracts/events.md. Combat and narrative code turn them into EventBus signals.
