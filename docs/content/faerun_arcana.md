# Faerûn and Arcana content pack

This is a content-only expansion. It adds JSON entries and source-book identifiers to the data schema; it does not change `rules/`, `core/`, `combat/`, UI code, or existing content entries.

## Catalog coverage

| Book | Backgrounds | Subclasses | Feats | Spells | Magic-item entries |
| --- | ---: | ---: | ---: | ---: | ---: |
| Forgotten Realms: Heroes of Faerûn (`FRHoF`) | 18 | 8 | 34 | 19 | 1 |
| Arcana Unleashed (`AU`) | 10 | 8 | 29 | 33 | 70 |
| Forgotten Realms: Adventures in Faerûn (`FRAiF`) | — | — | — | — | 10 |

There are 240 new entries. Item variants have separate IDs: five familiar necklaces, five dragon-breath potions, and three rarity stages for each of the five evolving item families. Evolution between stages is manual. Templates supply eligible base weapons or armor.

The Faerûn items include both Harper Pin variants, all four Mechanical Wonders, Calimemnon Crystal, Crown of Horns, Orb of Damara, Tome of the Dragon, and Windskiff. D&D Beyond attributes Windskiff to Heroes of Faerûn, page 133; the remaining ten entries are attributed to Adventures in Faerûn. Individual item pages provided access when the Adventures chapter redirected to the store.

## Provenance

Entries were compared against these published chapters and individual item pages in the owner's signed-in Chrome session on October 6, 2026. Descriptions are written in our own words. Source PDFs and extraction scripts are not repository assets.

- [Heroes of Faerûn: Character Options](https://www.dndbeyond.com/sources/dnd/frhof/character-options)
- [Heroes of Faerûn: Magic of Faerûn](https://www.dndbeyond.com/sources/dnd/frhof/magic-of-faerun)
- [Arcana Unleashed: Character Options](https://www.dndbeyond.com/sources/dnd/au/chapter-1-character-options)
- [Arcana Unleashed: Spells](https://www.dndbeyond.com/sources/dnd/au/chapter-2-spells)
- [Arcana Unleashed: Magic Items](https://www.dndbeyond.com/sources/dnd/au/chapter-5-magic-items)

- [Adventures: Calimemnon Crystal](https://www.dndbeyond.com/magic-items/10771760-calimemnon-crystal)
- [Adventures: Crown of Horns](https://www.dndbeyond.com/magic-items/10771761-crown-of-horns)
- [Adventures: Silver Harper Pin](https://www.dndbeyond.com/magic-items/11054399-silver-harper-pin) and [Golden Harper Pin](https://www.dndbeyond.com/magic-items/11054448-golden-harper-pin)
- [Adventures: Mechanical Wonder](https://www.dndbeyond.com/magic-items/10771765-mechanical-wonder)
- [Adventures: Orb of Damara](https://www.dndbeyond.com/magic-items/10771767-orb-of-damara)
- [Adventures: Tome of the Dragon](https://www.dndbeyond.com/magic-items/10771768-tome-of-the-dragon)
- [Heroes: Windskiff](https://www.dndbeyond.com/magic-items/10771757-windskiff)

`source.checked_against` identifies the book used to verify source mechanics, not a claim of automated implementation. The source note distinguishes game-specific defaults from book values.

## Automation boundary

The existing data contracts implement starting abilities, proficiencies, equipment, feat ability increases, spell choices, spellcasting progressions, prepared-spell lists, passive defenses, weapon/armor bonuses, movement speeds, and supported item spell powers. Subclass and feat features retain the existing `implemented: data` / `implemented: text` distinction. Text-only features require manual adjudication.

Six spells use existing combat effects: **Laeral's Silver Lance, Inflict Doubt, Fractured Awareness, Entrancing Mirrors, Invulnerability, and Iron Body**. Laeral's chosen targets use the game's established enemy-area targeting convention. The other 46 spells are explicitly labeled **Reference-only** in both summary and text. Their metadata makes them available in spell lists, but casting them does not automate their described effects. Familiar and summoned-spirit entries link to their source stat blocks rather than inventing unsupported companion behavior.

Magic items label each unsupported property **Reference-only**. Items can combine working bonuses or spell powers with manual properties. An item power delegates to the existing spell implementation, including any limitations of that spell. Reference-only item properties have no action button. Artifacts are excluded from random treasure.

Other manual cases include Circle casting, conditional reactions, faction tactics, Arcane Shot options, familiar transformations, slot-threshold spells from the Adept feats, Vestige Patron's chosen domain spells, and alternative prerequisites for Purple Dragon Commandant and Spellfire Adept. Repeatable Boon of Magic School Mastery requires manually choosing a different school each time. No new modifier names or bespoke feature handlers are introduced.

## Content defaults

- Backgrounds include the book's equipment package A and the 50 GP option B. Fixed equipment choices use Dice Set, an Arcane Crystal, or an Amulet where needed. Cosmic Dawn Experiment uses Carpenter's Tools. Tool proficiency choices remain selectable. Shadowmasters Exile and Agent of the Ninth Quill's spikes use the game's pack of ten.
- Artificer is omitted from spell class lists because it is not an available class in this game.
- Item prices follow the existing rarity convention (half price for potions), rather than a price asserted by these books. Unspecified weight is 0; templated weapons and armor inherit their base item's weight. Artifact price 0 is a placeholder and does not make artifacts random loot.
- Existing icon keys are reused. No art pipeline or core file changes are needed.

## Validation

Verified on October 6, 2026:

- `make check`: passed; 1,919 data files, no schema/reference errors, no incorrect engine labels, and all four data-integrity tests passed. These build every subclass through level 11 and every background.
- `make -o import test FILES=test_icons.gd`: all seven tests passed after asset import.
- A temporary behavior probe exercised the six automated spells: damage, conditions, save/check/attack penalties, resistances/immunities, and concentration cleanup all passed. The probe was removed to keep the change limited to content and documentation.
- `git diff --check`: clean. Existing content, rules, core, combat, and UI files are unchanged; the only existing file edited is the source-book enum in the data schema.
