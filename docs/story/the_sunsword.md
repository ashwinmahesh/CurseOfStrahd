# The Sunsword speaks (NPC plan Part D, 2026-10-18)

The Sunsword, Sergei's sentient blade, has lines of its own while somebody carries it. It speaks in a bright, ringing, courtly
voice, a little too loud, with the manners of a court four centuries gone. It is vain about its light, rude about other weapons,
bored by shopping and impatient with a dawdling bearer. It calls Strahd "the elder brother" and never uses his name (a test
checks every line). It is tender about Sergei and Ireena. Its secret: it is afraid of being broken again, which shows when its
bearer falls, at the castle, and once at a camp. Every line was drafted by Gemini through the ai-bridge and edited
(docs/plans/gemini_sunsword/). All of it is unvoiced; the voice is designed later by the castle voices lane.

## Where it speaks

| Moment | How | Lines |
|---|---|---|
| Waking when first carried, and the attunement | banter, `quest_found`, `quest_attune` (the next area entered) | 8 |
| First drawn; ashes (the first fight in the dead's country) | banter, `fight_first`, `fight_ashes` | 4 |
| Places it knows: the Pool of the White Sun, Sergei's tomb, Argynvostholt, the castle | banter, `place_*` | 10 |
| Idle remarks on a long walk: dawdling, shops, other weapons, its light | banter, `idle_*` | 8 |
| After a won fight, and after one against the dead | banter, `fight_after_1`, `fight_after_2`, `fight_undead` | 5 |
| A critical hit, a kill, a fallen hero; a fight begins; a fight is won | Narrator triggers in narrative/narrator/sunsword.dialogue | 14 |
| Strahd's grievance letter, the dinner, the parley, the Ireena offer, yielding | `if item:sunsword` lines in strahd/attention, castle_ravenloft/gates_dinner, strahd/final | 10 |
| The sleeping count's coffin: drawing it, and ending him | castle_ravenloft/catacombs_coffin (`wake_sun`, `sunsword`) | 5 |
| Ireena beside it; Sergei's pool | banter `idle_ireena`; krezk/pool `the_pool` | 6 |
| A camp talk with its bearer (level 8 and up, once): the fear | narrative/camp/sunsword.dialogue | 5 |
| Left in the stash; its bearer running from the count | banter `idle_stash`, `idle_running` | 4 |

## How it works

- `story/banter.gd`: the Sunsword counts as a guest while a party member carries it (`Banter._with_party`); its `idle_stash`
  node plays while it lies in the party's stash instead. Nodes in narrative/banter/guest_sunsword.dialogue play once each.
- `data/npcs/sunsword.json` (speaker "Sunsword") and `art/portraits/sunsword.png` (the item's icon, larger).
- A fight: the existing Narrator triggers `combat:crit`, `combat:kill` and `combat:fall` carry `[item:sunsword]` variants, which
  are preferred while it is carried; `combat:sunsword_start` and `combat:sunsword_victory` are said next to `combat:start` and
  `combat:victory` in addons/dnd_core/world/exploration/location_fights.gd (those keys have their own cooldowns and `once`, which would silence it).
  The Narrator says them for now; the Sunsword's own voice needs a speaker hook in the combat log, which is the voice lane's call.
- `story/camp_talk.gd`: the offer reads "Sunsword wants a word", and at camp it is made through whoever carries it (`who_asks`).
