# ADR 0012: Magic items

Status: accepted (Phase 5, magic items thread)

## Context

The owner asked for every magic item of the 2024 Dungeon Master's Guide, each with its full and correct behaviour
(secondary effects included), placed randomly and appropriately through the game. The engine already had attunement,
item modifiers and potions of healing (Phase 4), a data-driven spell engine, and combat hooks for class features. About
470 items do very different things: bonuses that only need modifiers, weapons with on-hit rules, wands that cast spells
at their own DC, potions that last an hour, bags that hold things, figurines that become creatures, and story-sized
artifacts.

## Decision

- **Data first.** Every item is a file in `data/magic_items/` (schema: `data/schemas/item.schema.json`, format:
  `docs/contracts/magic_items.md`). The engine reads keys, never names: `modifiers`, `powers`, `recipes`,
  `weapon_rules`, `armor_rules`, `container`, `worn`/`held`, `magic.charges`, `light`, `travel`. Bespoke behaviour sits
  behind a named `custom` power or a `weapon_rules.special` id in `combat/item_specials.gd`, `combat/item_powers.gd`
  and `story/field_items.gd`, so data stays the source of truth for what an item has.
- **One item, many bases.** "Weapon, +1", "Flame Tongue" and "Armor of Resistance" are templates (`template` block) on
  any fitting mundane item. Their ids are `<template>__<base>` ("weapon_plus_1__longsword"), built by
  `Compendium.item_data` on first use (`MagicItems.combine`), so every existing call that takes an item id works, and
  proficiency, mastery, ammunition and icons fall back to the base (`base_item`). Spell Scrolls are templates on a spell
  ("spell_scroll__fireball", name "Spell Scroll (Fireball)").
- **Powers are spells where they can be.** A power names a spell (cast with the item's DC, or the wielder's) or an
  item `recipe` (a spell recipe inside the item, looked up as the spell `<item>__<recipe>`), and goes through the spell
  engine (`CombatItems.cast`). A Wand of Paralysis's ray, a Necklace of Fireballs' bead and a Potion of Flying's drink
  are recipes; Wand of Fireballs and Staff of Power cast the PHB spells. Spells the game later improves improve the
  items too.
- **Each item instance keeps its own state** in its inventory entry: charges, daily uses, day cooldowns, toggle time,
  a Helm of Brilliance's gems, prayer beads, a Robe of Useful Items' patches, stored spells, a bag's contents, an
  artifact's rolled properties. The state travels with the item (`Character.remove_one` / `add_item(id, qty, state)`)
  and is saved with the character.
- **Worn and held.** Worn items have a slot (one cloak, one pair of boots, two rings, any number of Ioun Stones);
  wands, rods and staffs work while held, but using one draws it (the game's weapon-juggling deviation). A weapon's own
  bonuses apply whenever you attack with it.
- **The clock.** Charges come back at dawn (or dusk) as `StoryState.advance_minutes` passes them, with dice seeded from
  the playthrough and the hour; regeneration items heal as time passes.
- **Treasure.** Random items are rolled per location the first time it's entered (`story/treasure.gd`), from the
  playthrough seed, by the party's level there (`data/treasure/levels.json`, after the DMG's guidance: tier 1 mostly
  common and uncommon, tier 2 mostly uncommon and rare), on the DMG's theme tables, and saved in the location's state.
  Curse of Strahd's fixed treasures and the Tarokka's stay where the story put them; artifacts and story items are off
  the random tables.

## Consequences

- A new magic item is a data file; a new kind of behaviour is a `custom` id or a `special` id plus its code.
- `make test` covers the framework and the representative items (`tests/unit/test_magic_items.gd`); the item data is
  validated by `make validate`.
- Deviations (things the grid or the story can't do yet: altitude, objects in fights, alignment) are listed in
  `docs/rules/deviations.md`.
