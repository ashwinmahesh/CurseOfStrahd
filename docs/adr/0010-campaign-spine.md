# ADR 0010: The campaign spine: Tarokka, travel, guests and shops

Status: accepted (Phase 4)

## Context

Phase 4 (plan §10) turns the opening into a campaign: Madam Eva's Tarokka reading reshuffles where the three
treasures, the ally and the final fight are (plan §5.5); the party travels Barovia on a map with random encounters
and day and night; Ireena, Ismark and later allies travel with the party as guests (plan §5.6 roster); and the party
buys and sells. Writers fill these with data the way they fill locations and dialogue (ADR 0008, 0009), so each piece
needs a data format the validator can check, and the engine reads.

## Decision

- **The reading is data plus a seeded draw.** `data/tarokka/cards.json` lists the 54 cards; `data/tarokka/outcomes.json`
  maps every common card to a place for each of the three treasures, and every high card to an ally and to the
  room where Strahd waits. `story/tarokka.gd` draws once per playthrough from `StoryState.seed` (5 cards: three common
  for the Tome, the Holy Symbol and the Sunsword, two high for the ally and the enemy), stores the reading in
  `StoryState.tarokka`, and answers conditions like `tarokka.sword.region == vallaki`. Places in regions that aren't
  built yet are ids the validator lists as pending, like other later-phase references.
- **Travel is a node map.** `data/travel/barovia.json` holds places (each an entry into a location and spawn) and
  roads (hours, a random-encounter table). Travelling advances the clock; each leg rolls its table's day or night
  chance (a tenth of it on a road already walked, a leg to a place already visited or a journey to one, 2026-10-19; it was
  40% from 2026-10-18). A random fight
  plays on a road map with the table's monsters; an event plays a conversation.
  The journey then waits (`StoryState.travel_resume`) only while the party stands on a road map (`Travel.is_road_scene`):
  no autosave is written between setting out and reaching it, and entering any other place drops a record left over,
  so a fight won elsewhere never carries the party on to the journey's end (2026-10-18: Take All in Ghakis's lair
  sent the party to Vallaki).
- **Day and night** come from `StoryState.minute_of_day`: outdoor light follows the hour, and data uses `night`,
  `day` and `hour >= n` conditions (shops close, the dead walk).
- **Guests are story allies the player commands.** A guest is an NPC with a stat block (or a fixed character build)
  that joins with the dialogue statement `join <npc>` and leaves with `leave <npc>`. Guests follow in exploration,
  appear in the party frames marked as guests, and fight on the party's side under the player's control (no AI).
  Their level and gear are set by the story, not built by the player.
- **Shops are NPC data.** An NPC with a `shop` block sells and buys; the dialogue statement `shop` opens the shop
  screen for the speaker. Prices come from item `cost_gp` times the shop's markup; selling pays a share.
  A shop's `magic` list (Ashwin, 2026-10-14) sells magic items at their own `cost_gp` (Sane Magical Prices) whatever
  the markup, once the party's milestone level reaches the item's rarity (story/trade.gd magic_stock).

## Consequences

- Writers can add a region's travel node, random encounters, merchants and guests without code.
- Two seeds give two readings; tests pin the seed.
- The castle rooms, ally scenes and treasure rooms the reading points to are placeholders until Phases 5 and 6.
