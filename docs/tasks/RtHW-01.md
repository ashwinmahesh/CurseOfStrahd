---
id: RtHW-01
title: Finish Ravenloft: The Horrors Within from the book (backgrounds, Ebonbane, Harkon's Bite, Reanimator, a number check)
owner: Rules Engine
status: todo
depends_on: []
---

Owner decision 2026-10-06: merge what's built and leave the rest as a todo until the book's text is available (the
owner's D&D Beyond copy or screenshots of the pages; no pirated PDFs).

Built and merged on branch `ravenloft-horrors`: Dhampir, Hexblood, Lupin and Reborn; Sharp Eye and Survivor; the nine
Ravenloft Dark Gifts (feat category `dark_gift`, any origin feat can be one); College of Spirits, Grave Domain, Hollow
Warden, Phantom, Shadow Sorcery and Undead Patron with their combat behaviour (combat/ravenloft_features.gd). All of it
was entered from the 2025 Unearthed Arcana (Horror Subclasses), reviews of the book and Van Richten's Guide to
Ravenloft, so every entry has `source.book: RtHW` and no `checked_against` yet.

Still to do:
1. **Check every RtHW number against the book** and set `source.checked_against: "RtHW"` entry by entry. Least
   certain: Hollow Warden's published Wrath of the Wild (activation, AC bonus, aura save and condition, the retribution
   trigger), Rot and Violence and Ancient Endurance; the Dark Gift drawback DCs (13 + PB) and each gift's details; the
   species' use counts (Vampiric Bite, Howl, Knowledge from a Past Life) and the Lupin's and Reborn's sizes, speeds and
   senses; Sharp Eye and Survivor; the Grave Domain's level 7 spells (the playtest lists Dispel Evil and Good).
   Update the matching rows in docs/rules/deviations.md as each one is confirmed.
2. **Backgrounds**: Haunted One, Investigator, Mist Wanderer and Spirit Medium (abilities, feat or Dark Gift, skills,
   tool, equipment), in data/backgrounds.
3. **Magic items**: Ebonbane and Harkon's Bite in the DMG magic item format (data/magic_items, an `icon` key from
   art/icons.json, placement through the magic items' treasure tables).
4. **Reanimator** (Artificer): needs the Artificer class from Eberron: Forge of the Artificer, which the game doesn't
   have. Owner to decide whether to add the class.
