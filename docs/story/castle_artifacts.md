# The book's artifacts: the Icon of Ravenloft, Saint Markovia's Thighbone, the Gulthias Staff

Dungeon Expansion Plan package I1 (Ashwin, 2026-10-18: "add everything marked Gap from the dungeon audit"). Three
Curse of Strahd magic items in our own words, where the story puts them, and how each one plays. Branch
`castle-artifacts`. Rules text is ours; the flavour lines and the object labels were drafted by Gemini (below).

## What was checked, and against what

Each item's numbers were read against two sources that print the book's text (the 2016 Curse of Strahd, appendix
of magic items) and the two agreed on every number. `source.note` in each item file says the same.

| | dnd5e.wikidot.com | 5e.tools (CoS, pp. 221 to 222) | What they agree on |
|---|---|---|---|
| Icon of Ravenloft | wondrous-items:icon-of-ravenloft | items.json, "Icon of Ravenloft" | wondrous, legendary, attunement by a creature of good alignment; a 12-inch silver statuette of a kneeling cleric, 10 lb; within 30 ft anyone is under Protection from Evil and Good against fiends and undead (no attunement needed); Augury once until dawn, no components; usable as a holy symbol for Turn Undead or Turn the Unholy, +2 to the save DC; Cure Wounds, holding it, an action, a creature you can see within 30 ft regains 3d8 + 3 (not an undead, a construct or a fiend), once until dawn |
| Saint Markovia's Thighbone | wondrous-items:saint-markovias-thighbone | items.json, "Saint Markovia's Thighbone" | a rare mace, attunement; the properties of a Mace of Disruption; crumbles to dust once a battle ends in which it hit a vampire or a vampire spawn at least once; 4 lb |
| Gulthias Staff | wondrous-items:gulthias-staff | items.json, "Gulthias Staff" | a rare staff, attunement, 4 lb; animals within 30 ft are uneasy; 10 charges, 1d6 + 4 back at dusk; broken or burned it screams out to 300 ft and every blight that hears it dies; Vampiric Strike: a quarterstaff, 1 charge on a hit heals the damage dealt, each charge spent calls for a DC 12 Wisdom save or short-term madness; Blight Bane: blights and other evil plants don't see an attuned bearer as hostile unless harmed |

The Mace of Disruption's own numbers (2d6 Radiant against fiends and undead, a Wisdom DC 15 save at 25 Hit Points or
fewer, 20 ft of Bright Light and 20 ft of Dim Light) are the game's (`mace_of_disruption.json`); 5e.tools lists the same
numbers in the thighbone's entry. Neither source's page numbers were checked against a printed copy, so `source.page`
is left out and the pages are given here only as 5e.tools prints them.

## How each plays

- **Icon of Ravenloft** (`data/magic_items/icon_of_ravenloft.json`). Anyone within 30 ft of a creature who carries it is
  under Protection from Evil and Good against fiends and undead: attackers of those types have Disadvantage and can't
  charm or frighten them (`ItemPowers.refresh_auras`, called from `SpellZones.refresh_auras` as creatures move). The
  attuned bearer also has Augury once a dawn (read between fights, `FieldItems` `icon_augury`, `Oracles.cast`), Cure
  Wounds once a dawn (a spell recipe, `living_only` and the new `skip_types: ["fiend"]`), and a `turn_dc` +2 on Turn
  Undead (`CombatFeatures._turn_dc`, also the hotbar's label).
- **Saint Markovia's Thighbone** (`saint_markovias_thighbone.json`, a weapon of its own with a mace's numbers, as the Sunsword is a sword of its own). The Mace of Disruption's rules
  (`disruption`), plus `crumbles_on_vampire`: a hit on a vampire, a vampire spawn or Strahd marks the bone
  (`ItemPowers.relic_hit`, even when the hit kills), and when the fight ends (`CombatItems.fight_over`, called from
  `EncounterTurns._check_over`) it is gone from the pack.
- **Gulthias Staff** (`gulthias_staff.json`, a weapon of its own with a quarterstaff's numbers). Vampiric Strike is a toggle that arms the next
  melee hit (as the Staff of Striking arms its charges): the hit spends the charge, heals the damage dealt, and the
  wielder makes a DC 12 Wisdom save or has 1d10 minutes of Disadvantage on ability checks and Wisdom saves. Blight
  Bane keeps lesser blights from attacking or casting at the attuned bearer until the bearer attacks one
  (`CombatItems.attack_blocked`). "Break the staff" (a Utilize action, fights only) kills every blight within 300 ft
  that is not a boss. See `docs/rules/deviations.md` for each choice.

## Where the story puts them

- **The Icon** is a new container, `crg_chapel_icon`, on the dais beside the altar in `castle_ravenloft_chapel.json`
  (cell 10, 2, open floor: no walkable square, prop or fight start moved). It is not the Tarokka spot
  (`crg_chapel_altar`, which keeps its treasure). In a playthrough where Strahd waits in the chapel it can only be
  taken once the final battle is won, like the altar's own find.
- **The Gulthias Staff** is a container, `druid_satchel`, in the fermenting hall of `wizard_of_wines_winery.json`
  (cell 20, 4), shown once `flag.winery_hall_cleared` (the druids' fight is won). It is one container, not loot on the
  hall fight's four variants, because the fight has four conditional line-ups and "each lasting item once" counts a
  repeat in each.
- **The Thighbone** is lifted from the lid of Saint Markovia's sarcophagus in crypt 6 of the Lesser Vaults (the catacombs
  lane, C1): the prop `cat_markovia_bone`, behind the dart plate, and the `lift` node of
  `narrative/castle_ravenloft/catacombs_crypts.dialogue` gives `saint_markovias_thighbone` once (a dialogue `give`, so it
  counts as its one placement in test_loot_distinct). It needs the crypts branches first.

## Prices

Unsellable story items, like the Sunsword (Ashwin, 2026-10-20: "stay unsellable story items like the Sunsword"): each
has `cost_gp` 0 and `quest_locked`, so the inventory won't sell, drop or stash it and no merchant buys it; each is in
`data/treasure/magic_prices.json`'s `excluded` as "story", so no merchant stocks it, and none has a price in the table.
(The first build priced them from Sane Magical Prices, 8,000 gp for the thighbone like a Mace of Disruption, 12,500 for
the staff like a Staff of Healing held to the rare band's top, 90,000 for the Icon at the legendary band's bottom; a
merchant who buys magic items would have paid half of that for the Icon. That went when Ashwin answered.)

## Art

Icons are game-icons.net silhouettes already in `art/sourced/game_icons`: `delapouite/kneeling` (the Icon),
`delapouite/bone-mace` (the thighbone), `lorc/evil-tree` (the staff), framed by `make icons`. Delapouite and Lorc are
already credited in `art/credits.json`; nothing was downloaded or generated. The Icon's container uses the existing
`reliquary_sealed` prop and the staff's the `satchel`.

## The Gemini drafts

Drafted through Ashwin's ai-bridge (the packaged service, target `gemini`, which runs Antigravity's `agy` in plan
mode on his Google subscription; no model or effort was chosen, and the bridge did not report which model answered).
Both briefs and both raw replies are kept here, unedited. What changed between draft and game is listed after them.

### Brief 1 (flavour for the three items)

```
You are drafting short flavour text for three magic items in a single-player computer RPG adaptation of the D&D adventure Curse of Strahd. The tone is restrained gothic horror: plain, concrete, a little sad, never jokey and never purple. Write in our own words; do not quote the adventure book.

Use ONLY the facts listed for each item. Do not invent names, places, dates, powers, numbers or history beyond them. Do not state any game mechanics or numbers (the rules text is written separately). Do not use em-dashes. British or American spelling is fine, but be consistent.

For each item return:
- "summary": one sentence, at most 28 words, naming what the thing looks like or is. It is shown as a one-line description in the inventory.
- "flavour": one or two sentences, at most 45 words in total, shown at the start of the item's description card. Past or present tense, third person, no second person ("you").
- "labels": three alternative short labels (at most 7 words each, sentence case, no full stop) for the object as it lies in the world, where the player clicks it. Only for the Icon (on the chapel altar). For the other two items leave "labels" as an empty list.

Style sample, for the same game, so you can match the length and voice:
  summary: "A platinum sunburst with a raven at its heart and a sunstone in the raven's claws."
  flavour: "Made long ago by the faithful who fought the valley's first vampire, and lost when its last keeper never came home. It is warm to the touch, even in Barovia."

ITEM 1: Icon of Ravenloft
Facts: a twelve-inch statuette of the purest silver, showing a cleric kneeling in supplication. It is heavy for its size. The archpriest Ciril Romulich, an old family friend, gave it to Strahd to consecrate the castle and its chapel. It now stands on the altar of the castle chapel, under dust.

ITEM 2: Saint Markovia's thighbone
Facts: the one remaining thighbone of Markovia, a priest of the Morninglord. She rose against Strahd after he became a vampire and marched on Castle Ravenloft; a great battle raged from the catacombs to the parapets. She never came home. Strahd walked with a limp and a grimace for a long time afterwards. It is said he trapped her in a crypt beneath his castle. As the rest of her body decayed, the essence of her saintliness passed partly into her bones. This bone can strike at the undead, and it crumbles to dust if it has been used on a vampire.

ITEM 3: The Gulthias Staff
Facts: a staff made from a branch of a Gulthias tree, a spongy black length of wood. The tree grew from a stake pulled out of something that should have stayed dead; the druids of Yester Hill grow blights (living plant monsters) from its seed and feed it. The staff's evil makes animals visibly uneasy when it is near. Red blood oozes from its pores when it is used. Blights do not see its bearer as an enemy. If it is broken or burned, it screams, and the blights that hear it die.

Return ONLY valid JSON, no commentary, in exactly this shape:
{"icon_of_ravenloft": {"summary": "", "flavour": "", "labels": ["", "", ""]}, "saint_markovias_thighbone": {"summary": "", "flavour": "", "labels": []}, "gulthias_staff": {"summary": "", "flavour": "", "labels": []}}
Finish without sending messages to anyone else.
```

### Raw reply 1

```
{"icon_of_ravenloft": {"summary": "A heavy statuette of pure silver showing a cleric kneeling in supplication.", "flavour": "The archpriest Ciril Romulich, an old family friend, gave this piece to Strahd to consecrate the castle and its chapel. Forgotten under the dust of the altar, the silver remains pure.", "labels": ["Dusty silver statuette", "Kneeling silver cleric", "Silver icon on the altar"]}, "saint_markovias_thighbone": {"summary": "The remaining thighbone of Markovia, a priest of the Morninglord who marched on Castle Ravenloft and never came home.", "flavour": "Her battle against Strahd raged from the catacombs to the parapets, leaving him with a lasting limp before he sealed her in a crypt below. As her body decayed, her saintliness passed into the bone.", "labels": []}, "gulthias_staff": {"summary": "A staff of spongy black wood cut from the Gulthias tree on Yester Hill.", "flavour": "Cut from a tree grown from an old stake and fed by the druids of Yester Hill, this dark wood makes nearby animals uneasy. Red blood oozes from its pores when used, and it screams if broken or burned.", "labels": []}}
```

### Brief 2 (labels for the staff's container)

```
Same project as before: a single-player RPG adaptation of Curse of Strahd, restrained gothic tone, our own words, no em-dashes, no mechanics or numbers, invent nothing beyond the facts given.

I need three alternative short labels (at most 7 words each, sentence case, no full stop) for a container the player sees on the floor of a winery's fermenting hall, after the player's party has beaten the three druids who were occupying it. It is a satchel the leader of the druids left behind. Inside it, wrapped in a cloth, is a black staff of spongy wood cut from a Gulthias tree. The label is a plain description of what the object looks like lying there, shown when the player points at it. It should hint that the druids left it behind in a hurry, and that it is a druid's pack, without naming the staff.

Examples of labels in this game for comparison: "Kostin's satchel", "A druid's pack", "The wizard's rack", "A tool chest", "The druids' bedrolls".

Return ONLY valid JSON, no commentary, in exactly this shape:
{"labels": ["", "", ""]}
Finish without sending messages to anyone else.
```

### Raw reply 2

```
{"labels": ["A druid's satchel, dropped in haste", "The druid leader's abandoned satchel", "A druid's hastily discarded pack"]}
```

### What was edited

- Icon: both drafted sentences are used as they are, after Gemini's one-line summary, in the item's `text`; the
  label "Silver icon on the altar" is the third offer.
- Thighbone: the drafted summary line is used as is. In the flavour, "leaving him with a lasting limp before he sealed
  her in a crypt below" became "and he walked with a limp long afterward. They say he sealed her in a crypt below"
  (the book calls the crypt a rumour), and "her saintliness passed into the bone" became "some of her saintliness
  passed into the bone" (the book says partly).
- Staff: the drafted summary line is used as is. The flavour keeps its first sentence and "Red blood oozes from its
  pores when used"; its last clause, "it screams if broken or burned", was cut because the rules text says it.
- Staff container: the first offered label, "A druid's satchel, dropped in haste", is used.
- Not drafted by Gemini: the `summary` fields and the rules text of each `text` (they are rules, and ours).
