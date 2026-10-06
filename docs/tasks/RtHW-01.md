---
id: RtHW-01
title: Finish Ravenloft: The Horrors Within from the book (backgrounds, Ebonbane, Harkon's Bite, Reanimator, a number check)
owner: Rules Engine
status: in_progress
depends_on: []
---

Owner decision 2026-10-06: merge what's built and leave the rest as a todo until the book's text is available (the
owner's D&D Beyond copy or screenshots of the pages; no pirated PDFs).

Built and merged into main (2a595b3c, branch `ravenloft-horrors`): Dhampir, Hexblood, Lupin and Reborn; Sharp Eye
and Survivor; the nine Ravenloft Dark Gifts (feat category `dark_gift`, any origin feat can be one); College of
Spirits, Grave Domain, Hollow Warden, Phantom, Shadow Sorcery and Undead Patron with their combat behaviour
(combat/ravenloft_features.gd). All of it was entered from the 2025 Unearthed Arcana (Horror Subclasses), reviews of the book and Van Richten's Guide to
Ravenloft, so every entry has `source.book: RtHW` and no `checked_against` yet.

Progress 2026-10-06 (from the book on D&D Beyond, the owner's account): the four species, Sharp Eye, Survivor,
Aberrant Anatomy, Echoing Soul, Gathered Whispers and Living Shadow are checked (`checked_against: RtHW`), with their
fixes in (Echoing Soul's drawback is a Constitution save; Living Shadow's drawback runs the next turn on the Shadow's
Will table; Feral Pounce only on an Attack-action hit on your turn; Howl needs no hearing; Sharp Eye keeps the use on a
failed check). The four backgrounds are in data/backgrounds. Reading further pages was stopped partway by a safety check
on copying the book, so the rest waits for the owner's go-ahead or another way to read it.

Still to do:
1. **Check against the book**: the six subclasses (least certain: Hollow Warden's Wrath of the Wild, Rot and Violence
   and Ancient Endurance; the Grave Domain's level 7 spells, which the playtest lists as Blight and Dispel Evil and
   Good), and the Dark Gifts Mist Walker, Second Skin, Symbiotic Being, Touch of Death and Watchers. Set
   `source.checked_against: "RtHW"` entry by entry and update docs/rules/deviations.md.
2. **Magic items**: Ebonbane and Harkon's Bite in the DMG magic item format, on main since c3e4f899
   (data/magic_items, docs/contracts/magic_items.md; an `icon` key in art/icons.json; placement through the coordinator
   to the magic items' treasure tables).
3. **Reanimator** (Artificer): needs the Artificer class from Eberron: Forge of the Artificer, which the game doesn't
   have. Owner to decide whether to add the class.
