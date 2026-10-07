# Faerûn and Arcana content pack

The catalog contains the three books below. The gameplay follow-up extends shared rules and combat systems. The implementation audit is in progress; catalog presence and source verification do not imply full automation. See [rules coverage](../rules/coverage.md#faerûn-and-arcana-unleashed-gameplay-audit).

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

## Gameplay audit

The original import included six spell recipes and 46 reference entries. The follow-up is replacing reference entries with executable mechanics and extending reusable rules for features, saves, concentration, summons, spell weapons, and sustained actions. The coverage ledger records tested mechanics and remaining exceptions; it is the completion authority.

In combat, reference spells remain disabled with “Not automated yet” until a handler or recipe exists. Exploration spell effects remain part of the audit. Damage spells keep their damage classification. Feature `implemented: data` includes data-defined activation and roll-response recipes; a text summary alone never counts as gameplay implementation.

Magic items may still combine working bonuses or spell powers with reference properties. Item spell powers inherit the actual implementation and limitations of their spell. The item and feature audits remain open. Artifacts are excluded from random treasure.

## Content defaults

- Backgrounds include the book's equipment package A and the 50 GP option B. Fixed equipment choices use Dice Set, an Arcane Crystal, or an Amulet where needed. Cosmic Dawn Experiment uses Carpenter's Tools. Tool proficiency choices remain selectable. Shadowmasters Exile and Agent of the Ninth Quill's spikes use the game's pack of ten.
- Artificer is omitted from spell class lists because it is not an available class in this game.
- Item prices follow the existing rarity convention (half price for potions), rather than a price asserted by these books. Unspecified weight is 0; templated weapons and armor inherit their base item's weight. Artifact price 0 is a placeholder and does not make artifacts random loot.
- Existing icon keys are reused.

## Validation

The initial catalog import passed data integrity and icon checks. Gameplay regression evidence belongs to the current coverage ledger and test files. The full follow-up requires a fresh `make ci` pass after all mechanics and documentation are complete; the earlier content-only checks do not certify this work.
