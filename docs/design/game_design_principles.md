# Game Design Principles

How the *Curse of Strahd* game was designed, written so that a new project can build a different game world on the
same principles. Written 2026-10-24 from the project's memory, the plans and audits in the shared project folder, and
the public repo (github.com/ashwinmahesh/CurseOfStrahd, main at `09c02b09`: CLAUDE.md, docs/adr/, docs/rules/,
docs/plans/, docs/story/, docs/ui/, docs/voice/).

## How to use this document

- Every rule says **what** to do, **why** it exists, and a **concrete example** from Barovia. The example is there so
  you can see the rule applied; swap in your own world's places, people and monsters.
- Each rule carries the date the owner (Ashwin) decided it, where the sources record one, and a status:
  - **Standing**: decided and built, or decided and binding on all new work.
  - **Asked, not built yet**: decided by the owner, waiting for a lane to build it. Treat it as binding.
  - **Undecided**: an open question. A new project should decide it early.
  - **Superseded**: an older rule that a later one replaced. Kept because the history is the lesson.
- "The owner" is the person the game is for. "A lane" is one Claude working thread with its own git branch and
  working copy. "The builder" is the one thread that merges, tests and pushes. See Part 14.
- No secrets, keys or paid-account details are in this document. Where something costs money, the principle is how
  spending is approved, not what the account holds.

## Contents

1. Vision, pillars and tone
2. Rules fidelity
3. Combat design
4. Difficulty modes
5. Exploration, maps and the look of places
6. Story, quests and dialogue
7. Characters, monsters and companions
8. UI, UX and controller
9. Music, sound and voice
10. Art pipeline
11. Data-driven design and engine architecture
12. Testing tiers and fight guards
13. Release and patching
14. Workflow: lanes, the builder, batching and approvals
15. Open decisions
16. Starting a new world: a checklist
17. Appendix: decision log by date

---

## 1. Vision, pillars and tone

### 1.1 The pitch

A single-player, turn-based tactical RPG of a whole tabletop campaign, played on the current official D&D rules
(2024 Player's Handbook and Dungeon Master's Guide, 2025 Monster Manual), with Baldur's Gate 3's interface habits and
a gothic take on Square Enix's HD-2D look (Octopath Traveler II). The player leads a party of four through the whole
campaign, from the first scene to the last, in an order they choose.

For a new world: pick one published campaign (or one coherent setting) and commit to delivering **all of it**, faithfully,
rather than a slice. Faithfulness is what makes players who know the book trust the game.

### 1.2 The six pillars

These are what the game leads with (Showcase Plan, 2026-10-08). Every feature should serve at least one; a feature
that breaks one is out.

1. **The whole campaign.** Every region, playable in the order the player chooses, reshuffled each playthrough
   (the Tarokka reading moves the three treasures, the ally and the final battle room), with several endings.
2. **Tactical combat on the real rules, odds visible.** Every class, spell and feat does what its text says, and the
   player sees the chance and the damage before acting.
3. **Your party: you control everyone.** The player commands every party member and every story guest who joins.
   The AI only drives enemies and bystanders. (Plan pillar 2. This is why "auto-resolve party fights" and "AI
   companions" were ruled out, 2026-10-07.)
4. **A world that notices you.** Stealth and surprise, crime and a watch, schedules, weather, day and night, and the
   villain's attention rising as the party defies him.
5. **A gothic HD-2D look.** Hand-drawn 2D characters in a lit 3D world: lanterns casting shadows, rain on cobbles, the
   castle on its crag.
6. **Fully voiced.** A Narrator in the style of Baldur's Gate 3, locals with the setting's accent, and the party
   talking among themselves.

### 1.3 Tone: dread, shown and not told

- **The world is cruel; the Narrator is not.** The Narrator is an old gothic storyteller, fond of the party the way a
  gravedigger is fond of the weather: "with interest, without illusions" (docs/voice/narrator.md). Rules every
  Narrator line follows:
  1. Second person, present tense ("You step inside").
  2. One or two sentences; the second is usually the turn (irony, dread, a dry joke).
  3. Ominous and dryly funny, never cruel. Laugh at the house and the dark, never at the player's bad roll or a death.
  4. No facts the party hasn't earned. Hidden things are revealed only by a check or a discovery.
  5. No modern slang, no winks at the player, no game terms ("HP", "roll", "level"). A passed check is "your fingers
     find the catch", never "you passed".
  6. Concrete senses over adjectives ("your breath fogs indoors", not "cold").
  7. The scariest places get the thinnest humour; some lines carry no joke at all. Silence is a tool.
  8. Combat lines are one sentence, under 15 words, and rare (3+ round cooldown).
  9. Never "suddenly". Never "you are terrified": show the cold and let the player be terrified.
- **The villain's courtesy is a cat's** (Strahd Menace, Tone Options, 2026-10-08). The audit found Strahd had become
  the funniest, most likeable person in every scene: he mocked himself, defiance cost nothing, his cruelty was only
  reported, his threats were vague and the narration admired him. The recommended tone ("the velvet knife"): he stays
  perfectly polite, the self-mockery goes, every courtesy carries a threat that **names a person, a place or a time**,
  he speaks of the heroine as his property, and each meeting leaves a mark on somebody. Show cruelty on screen at
  least once before the midpoint. *Status: recommended; the sources do not record his final pick (see Part 15).*
- **Comedy exists, but in its place.** Recurring comic-relief characters and running gags were asked for (2026-10-17)
  so the dread has relief; the Narrator and the serious scenes stay straight.
- **Every place its own look and mood** (standing). Variety comes from hue, material and air, not from sunshine:
  Barovia stays overcast everywhere (Region Variety Plan, 2026-10-12).

### 1.4 The look, and how it changed

The first style bible (approved 2026-10-06) was "gothic horror as a 1990s Saturday-morning cartoon", every pixel
snapped to a 49-colour palette. A day later (2026-10-07) the owner picked **HD-2D** as the default ("Modern"): 2D ink
characters walking through a lit, painted 3D world with no ink lines of its own. The palette-snapped look survives
as "Classic", **frozen**: new work only has to keep it working, not keep it current.

Lessons for a new project:

- **Decide the look with target frames before code** (Improvement Ideas W1): repaint a few real captures in two or
  three directions and let the owner pick (he chose "option A's effects in option B's grim tone"). It cost about 16
  images and saved weeks.
- Characters are 2D and crisp, the world is 3D and lit. Characters keep their ink outline; the world gets none
  (2026-10-07). Sprites are never blurred by the depth-of-field (his rule).
- Octopath's hallmarks to aim for: tilt-shift edge blur (Wide by default), bloom on flames only, light shafts, soft
  shadows from lamps, sprites lit by the scene with rim light and reflections, weather on surfaces (wet cobbles,
  footprints in snow), a colour grade per region and time of day, vistas past the map's edge.
- Banned (style bible and Visual Polish Plan): photorealism, film grain and dither, chromatic aberration everywhere,
  motion blur, lens flares, pure black, neon colours outside the palette, chibi proportions, modern objects, text or
  watermarks in images.

### 1.5 Faithful to the source, ours in words

- Book facts only from a checked source. When a reference gives only a room's name, the lane writes the contents in
  its own words and labels them as its own; it never presents a guess as the book (Dungeon Expansion Plan,
  2026-10-18).
- Data `text` and `summary` fields are always our own words, never copied from the books (CLAUDE.md).
- Some departures from the book are kept on purpose because they play better ("Kept as ours" lists in the dungeon
  plan). Name them, give the reason, and leave them alone.

---

## 2. Rules fidelity

### 2.1 The rule sources (standing)

- **2024 Player's Handbook** in full (owner, 2026-10-05; personal use), **2024 Dungeon Master's Guide**, **2025
  Monster Manual**. The SRD 5.2.1 is the import starting point and is credited (CC BY 4.0).
- **Check the text before changing a rule.** Every todo that touches a rule says "check the 2024 PHB text first"
  (rest rules, Steel Wind Strike, Pounce, Spiritual Weapon's concentration).
- A data file's `source.checked_against` is set only after every number was compared with that source.
- Where the 2025 Monster Manual has no stat block (Strahd, custom bosses), use the campaign book's block (2026-10-06)
  or design one and flag it as custom.

### 2.2 Every departure is written down (standing)

- `docs/rules/deviations.md` holds one row per departure: **the rule**, **what the game does**, **why**, and **what
  would close the row**. A rule that simply isn't built yet is "not started" in `coverage.md`, not a deviation.
- `make validate` checks both docs against the built phases and the data, so a stale row fails CI.
- Every lane records each departure it makes, in the same change.

Examples of owner house rules (each a deviation row):

| House rule | Date | Why |
|---|---|---|
| Divine Smite is the 2014 rule: no Bonus Action, not a spell, any number of melee hits a turn while slots last, **asked after every hit** | 2026-10-08 | He prefers the 2014 paladin |
| Reaction spells don't count toward the one-slot-spell-per-turn limit | 2026-10-13 | Ratatouille wasn't offered Shield after casting earlier in his turn |
| Flanking (2024 DMG optional rule) on, with a setting to turn it off | 2026-10-12 | Rewards moving round a foe |
| High ground: +2 to ranged attacks from 10 ft above, -2 from 10 ft below | 2026-10-07 | From BG3, so climbing is worth a turn |
| Shared party turns: adjacent party members in initiative act together, switching freely | 2026-10-09 | From BG3; lets the party plan together |
| Prepared spells change any time outside combat, no rest needed | 2026-10-14 | Resting only to swap spells is a chore |
| Eldritch Blast as a War Caster reaction fires **one** beam | 2026-10-19 | A reaction is one attack, like the opportunity attack it replaces |
| Legendary Resistance only against condition effects, or damaging spells of level 5+ that deal **no** damage on a save | 2026-10-21 | Bosses shouldn't burn resistances on half-damage blasts |
| Legendary actions only after a **player character's** turn | 2026-10-24 | Asked, not built yet |
| Readying a spell while concentrating keeps the concentration; a readied spell can be un-readied next round | 2026-10-21 | Asked, not built yet |
| Traps are found only by an explicit check (Search, Find Traps), never passively | 2026-10-08 | Finding a trap should be a choice |
| Raise Dead at the temple of every town; the ordeal is -4 for 10 days | 2026-10-07, 10-15 | A way back from death everywhere |
| Merchants' prices follow attitude; one Persuasion haggle per merchant, a failure is final | 2026-10-08 | Failed social checks are spent |
| Instant attunement (still three items), plus a setting to remove the limit entirely | early; setting asked 2026-10 | Attuning is a chore; the setting is player choice |
| The heroine can be a non-combatant guest (`guest_fights: false`): no turn, can't be targeted | 2026-10-18 | A 9 HP noble made players leave her behind and lose her story |

### 2.3 Every spell and item must be useful (standing)

- **A spell or item that does nothing in the game gets a use, or leaves the game** (2026-10-12). Leaving means
  `"playable": false` (and `removed` for spells) in its data. **Never delete the data file.** 55 spells left this way
  (Create Food and Water, Sending, Teleportation Circle, most 7th-9th level spells with no use), then Detect Thoughts
  (2026-10-13). Subclasses and items that granted them lose that power; old saves swap them for a spell of the same
  level on load.
- **Give utility spells a real answer in the game's terms** instead of removing them: tricks cantrips grant Advantage
  on one skill's checks outside fights (Druidcraft on Nature, Minor Illusion on Deception); divinations read the
  current place (Augury says whether something is still hidden or a fight still waits here); ward spells protect a
  rest; Find the Path keeps a day's roads free of random encounters.
- **Cantrip scrolls: left out.** Spellbook loot holds only spells a Wizard can learn.
- **Magic items are book-exact** (2024 DMG), with every secondary effect. The engine reads keys, never names.
- **Loot is generous** and **each lasting magic item turns up once** in the whole game (2026-10-17: the Amulet of
  the Devout had been placed six times).
- **Finds lean to combat across every class** (2026-10-17), so every hero gets something.
- **Hoards fit their owner and the level they're met at**: rares up to level 7, a very rare from level 8, legendary
  only for the four deadliest villains at level 10 (Hoard upgrades, 2026-10-15). No fixed quota.
- **Prices** come from one guide (Sane Magical Prices, 2026-10-14) but are held inside each rarity's band around the
  DMG value (2026-10-17, after a 60,000 gp Handaxe of Warning): uncommon 200-1,250 gp, rare 1,250-12,500, and so on.
  Nothing bought sells back for more. Merchants who sell magic items also buy them, at half price.
- **Story artifacts are unsellable** (the Icon of Ravenloft, Saint Markovia's thighbone, the Gulthias Staff).
- **Every playable spell scroll is sold by some merchant** (asked 2026-10-21).

### 2.4 The engine explains itself (standing)

- **Every number on screen is a Breakdown**: "AC 17 = Chain Mail 16 + Defense 1". The engine produces it; the UI only
  shows it (ADR 0006).
- **One dice roller** for every roll, seeded, logging a reason for each. Every new game and every load reseeds it, so
  reloading never replays the same rolls (2026-10-07). What the world holds (the reading, treasure placement, shop
  stock) comes from a playthrough seed and stays the same across loads.
- **Rolls in the open**: dialogue checks show who rolls and their chance before the player picks, then throw a big
  animated d20 with the DC, every bonus and Advantage's second die. Every ability that adds to or rerolls a d20
  (Heroic Inspiration, Bardic Inspiration, Dark One's Own Luck, Bless) shows the added die in the same green style and
  says whether the roll then succeeded (asked 2026-10-21).
- **Spells that need a choice ask for it**: Command offers five words, Suggestion four game-ready suggestions,
  Chromatic Orb asks where it leaps.

---

## 3. Combat design

### 3.1 Baldur's Gate 3's interface, the tabletop's rules

- **Fights happen where you stand.** Exploration and combat share one 5 ft grid, so a fight starts on the map exactly
  where everyone is (ADR 0009). No separate battle screen.
- **Know the odds before you act.** Hovering a foe shows the hit chance, damage and Advantage with its reasons.
- **AoE previews**: a pale gold outline of the area, every target's HP and chance to fail the save, and a
  friendly-fire warning. Cones and lines aim at **any** angle, not just the 8 grid directions.
- **Blocked actions name the real reason** ("Not with foes in sight", "No line of effect"), never a silent greyed
  button.
- **Saving throws show after the attack animation and the damage**, not before, so the beat reads in order.
- **Multi-attack spells show and sound every attack**: each Eldritch Blast beam has its own effect and sound
  (asked 2026-10-21).
- **A combat log where every line opens its math**, an arrangeable hotbar (favourites, hidden), a radial menu on a
  controller, **undo a move** when nothing came of it, and an **autosave at the start of every round**.
- **Impact**: a freeze on heavy hits, a push-in on crits, slow motion on the last foe, the camera turning to a big
  spell, boss name plates and health bars, a fight-start colour pulse with no screen transition.

### 3.2 Reactions ask, never guess (standing)

- When a player-controlled creature could react, the fight **pauses** and asks (ADR 0007). Each reaction has a rule
  the player sets: Ask (default), Always or Never.
- If a reaction has several ways to pay, it asks which: Hellish Rebuke and Backlash ask; Shield does not; **Absorb
  Elements must ask too**, including when the save succeeds but still deals half damage (2026-10-23, 10-24).
- **Counterspell is offered for every enemy spell** to any party member who can cast it (slot, reaction, range, line
  of sight), whatever path the enemy's spell took (2026-10-24, after Strahd's Fireball got no prompt).
- **Divine Smite asks every time.**
- A bug report pattern to remember: "a reaction fired automatically" is always a bug under this rule.

### 3.3 Targeting rules (standing)

- Spells that choose targets let the player choose them (Slow; Steel Wind Strike up to five).
- Polymorph works on enemies. Party summons count as allies.
- Invisible foes can't be targeted except by areas. They stay in the initiative list and can't be clicked there to
  reveal them; moving into their square gives no "an enemy is here" message (asked 2026-10-21).
- Creatures (heroes and foes) may share a square, within a size budget (heroes 2026-10-12, foes 2026-10-19).
- Turn-order names are cut at 10 characters.

### 3.4 Encounter design (standing, with the newest rules asked and not yet built)

- **Foes start spread out.** No 20 ft burst may catch every foe at the start, and with 3 or more foes they must not all
  fit inside one 20 ft fireball (2026-10-15; a unit test checks every fight). A rug room where one Fireball caught 7 of
  8 foes had to be redone.
- **Fight length**: non-boss fights should average **2-3 rounds, 4 at most**; bosses may run longer (2026-10-24,
  asked). Levers: book HP, fewer foes, higher to-hit and damage, focus fire. Never make the party weaker to get there.
- **Big monsters need big rooms.** The lich's and the dragon's lairs had to be made "a lot bigger" (2026-10-21,
  10-23). Size the arena for the fight, not the fight for the arena.
- **Rewards make the fight easier, warnings make it harder.** A quest that earns the party an edge (the hounds called
  off, the foe's true name learned) gives a weaker version of the fight; a foe warned by the party's choices gives a
  harder one. One encounter id, several versions keyed by level and flags.
- **Every fight can end.** A foe with no way to reach the party, and no party member able to reach it, leaves after two
  of its turns. A fight that can't end is a bug that blocks a release.

### 3.5 Boss philosophy: hit harder, never more Hit Points

This is the rule that changed most, and the history is the lesson.

| Date | Rule | What happened |
|---|---|---|
| 2026-10-13 | Non-boss fights: the test party wins 5 in 8 on Balanced | Measured with an autopilot party over 8 seeds |
| 2026-10-14 | Bosses: the full-ability test party wins 3 in 8 | Reached mostly by raising boss HP 2 to 4 times the book (Rahadin 795 HP, the Gilded Knight 710) |
| 2026-10-19 | Bosses deal +25% damage on Balanced and harder (not Story) | "Bosses only", never eased |
| 2026-10-19 | No re-tuning when a rule changes; the builder accepts new fight results | The 3-in-8 tuning was a one-time job |
| 2026-10-21 | "The current battles are absolute jokes." Plan every boss: powerful minions placed intelligently, lair actions that change the battlefield, phases, real tactics (Counterspell, Shield). Stat blocks may be modified when the design needs it, recorded as deviations | Plan first, in docs/plans/, then build, one branch per boss |
| 2026-10-21 | Tune against **the owner's actual party** (his save, read-only), not a generic party | Generic pregens out-damaged the book in ways his party didn't |
| **2026-10-23/24** | **Difficulty comes from hitting harder, not from HP. Every monster (not just bosses) goes back to its Monster Manual HP.** Compensate with **+1 to +3 to hit and about +30% damage**, better abilities and lair actions | Asked, not built yet. Brother Anatol and his spawn at 315 HP each, and 200 HP rat swarms, were the examples |

Why the change: inflated HP made fights long and dull (the player chips at a sponge for ten rounds) and players read
it as unfair. Damage and abilities make a fight dangerous **and** short.

Standing boss rules:

- **Never ease a boss.** Fix a boss that's too easy by making it more dangerous, never by weakening the party.
- **Bosses are planned**, not stat-padded: where each minion spawns and stands (cover, flanks, guarding casters,
  blocking approaches, arriving in waves), lair actions that are strong and change the battlefield each round,
  phases, and counterplay for the party.
- **Bosses use their whole kit**: foes cast Shield and Counterspell (the lich who never did was a bug); legendary
  actions are used, 3 per round when the block says 3; custom legendary bosses strike twice.
- **Legendary Resistance** only against conditions or high-level all-or-nothing damage spells (2.2).
- **Abilities target the right side**: the Huntsman's frightening horn affected his own hounds, a bug (2026-10-23).
- **Some numbers are right as they are**: the ancient red dragon's breath (about 124 damage) stays; the owner
  withdrew his complaint after playing it (2026-10-23). Its fight gets better lair actions and a bigger lair, **no
  stronger minions**, and gold piles worth the name.
- **Who counts as a boss** must be explicit. The code calls anything with legendary actions or CR 5+ a boss, which
  wrongly gives plain CR 5 spawn the +25%. *Undecided: a narrower definition, such as an explicit boss flag.*
- **The villain hits like the villain**: Strahd's unarmed strike and bite went from +9 to **+14** to hit (2026-10-24).
- **The final villain can't be killed by accident.** He is destroyed only in his coffin; at 0 HP elsewhere he turns
  to mist and flees there. His protective ward (while the Heart of Sorrow stands) must be **visible** in fights, with
  hints pointing to how to break it (asked 2026-10-24, after the owner thought Strahd was simply immune).

### 3.6 Enemy AI (standing, with 2026-10-24 asks)

- AI scores every move by **expected damage**, with behaviour profiles per monster (brute, skirmisher, spellcaster,
  coward...), focus fire, retreats, and a bespoke brain for the main villain (mist, bat and wolf shapes, charm,
  summons).
- **Every foe with spells uses them** when a spell is its best option (2026-10-13), weighing each spell's expected
  damage plus the turn a condition takes away against its weapon.
- **Foes don't catch themselves or their allies** in their own areas: they move or place the area first (asked
  2026-10-21 and again 10-24).
- **Melee when melee is better**: a foe whose melee hits harder or more often than its ranged option closes in when it
  can (asked 2026-10-24).
- **Don't walk away from a target in reach** if leaving would provoke an opportunity attack and the nearby target can
  take the foe's best attack (asked 2026-10-24).
- **Doors are no barrier** to foes with hands and Intelligence 3+.
- **Legendary actions spread their targets.**
- **Each monster rolls its own initiative** (todo 2026-10-20; the code still groups identical monsters, as the DMG
  allows: decide which you want early).
- **Fleeing**: the party should be able to flee by leaving the map. *Undecided: opportunity attacks, whether the whole
  party must leave, pursuit, which story fights block it, what happens to the fight afterwards* (asked 2026-10-24).

---

## 4. Difficulty modes

Modelled on Baldur's Gate 3, +2s included (owner, 2026-10-07, though the plan had said "never touch the core math").
Picked at a new game and kept in the save.

| | Story | Balanced | Tactician | Honour |
|---|---|---|---|---|
| Party | +2 to attacks and saves; nobody dies (Unconscious and Stable instead) | book | book | book |
| Enemies | gentler targeting | book | +2 to attacks and DCs, sharper targeting, drink potions, flee when broken | as Tactician, cruel foes strike the fallen |
| Bosses | book damage | +25% damage | +25% | +25%, full stat block |
| Long Rest interruptions | never | 1 in 6 | 1 in 6 | 1 in 6 |
| Saving | anywhere | anywhere | anywhere | one save; a wipe carries on in Tactician |

Notes:

- The 2026-10-07 table also had enemy HP changing by mode (Story -25%, Tactician and Honour +20%, inside the Hit Dice
  range). Under the 2026-10-24 rule (HP stays at book value, difficulty from damage) a new project should vary
  **damage and to-hit** by mode instead of HP. *Status: the mode table is built; reconciling it with the HP rule is
  part of the HP rollback, not yet done.*
- **Milestones or XP** is a second choice at a new game (XP Mode Plan, 2026-10-14). XP comes from foes, quests,
  places, finds, checks, traps and lore, sized from the 2024 DMG's budgets; each foe gives 40% of its XP because the
  game fields more foes than the book. Two guardrails keep tuned fights tuned: a milestone always lifts the party to
  the milestone level, and the party can never be more than one level ahead (extra XP waits in a reserve). Validated
  with a simulator over 600 runs per player type before building. Lesson: **simulate a levelling system against the
  real fight data before shipping it.**
- A settings option to turn off random road encounters, default on (asked 2026-10-23). New settings always default to
  today's behaviour.

---

## 5. Exploration, maps and the look of places

### 5.1 Draw the land, then lay the grid over it (2026-10-19, standing)

The owner: "We don't need to draw our real world maps as a battle grid. It can look like a real natural map that we just
overlay a grid on top afterwards. That's the design principle we should be using." And: "why are all of our mountain tops
flat? ... Things should look natural."

1. **The rules grid never changes for looks.** Rows, heights, exits, spawns and fights stay; only the drawing changes.
2. **Bend the side the party can't stand on.** A natural outline (a crag's foot, a wood's edge, a shore, a cliff's
   lip) wanders into rock, wood, water or void squares, never into a walkable one. A walkable square keeps its middle
   clear and its ground within a few centimetres of where a token stands.
3. **No seam runs along a grid line outdoors** for more than a square, unless it's built (a wall, a kerb, a jetty).
4. **Built things stay built.** Houses, castles, dungeons and interiors keep straight lines; ruins break.
5. **Shapes come from noise seeded by the place**, never one shape stamped everywhere.
6. **The battle grid is an overlay**, shown around the active creature in a fight, whole in the tactical view, hidden
   outside fights (a setting: in fights, always, never). Never painted into the ground textures.
7. **Small steps** wherever a 5 ft raised block would otherwise read as a cube to step onto.

### 5.2 Every place its own look (standing)

- **A colour script** (Region Variety Plan, 2026-10-12): every region has a dominant hue, one accent, its own daylight
  (not only at dusk), its own mist colour and thickness, ground, plant mix, particle and horizon. **No two neighbours on
  the travel map share a signature.** The audit found 54 outdoor places that were "nearly one place" by day (one key
  light, one grey mist, one forest of seven tree models, one grass).
- **Make the central feature visible and true to its words.** The Amber Temple plan (2026-10-18) found the faceless god
  buried in a wall block and sixteen different prisoners drawn as one identical knee-high box, while the text said
  "taller than a man". Rule: what the narration describes, the scene shows.
- **Scale things to what they are**: an ancient dragon's skeleton, the dragon's desk and chair, a 30 ft sentinel, a
  witch's walking hut. Too-small landmarks came up again and again.
- **Lying-down creatures are shown lying down; upright coffins stand upright.**
- **Interiors look like the person who lives there** (Interiors Audit, 2026-10-08). The model room is Madam Eva's tent:
  walls and floor match the description, everything the narration names is there, and the room is filled with what its
  owner would keep. A furnishing layer fills one wall face in three and one edge square in four, never beside doors,
  exits or people. Room styles follow the setting (no nursery wallpaper in a werewolf cave).
- **Exteriors** (Exterior Audit, 2026-10-08) must: match the words and the module; be lively (people, carts, things to
  find: three or four finds a place); show the setting's mist; not be flat; and have big usable things (platforms,
  climbable trees, outcrops that give high ground).
- **Outdoor maps have vistas** (a `vistas.json` entry): when the camera tilts up, the horizon shows the region's
  landmarks (the castle on its crag, the lake, the mountains).

### 5.3 Walls and the camera (standing)

- **Buildings never collapse or cut away near the party.** No x-ray cut-outs: whatever blocks the view **fades**
  (2026-10-17: "walls collapse down when looking from certain angles... I don't like this behaviour"). Walls stay full
  height from every side.
- Exploration camera: 40 degrees down, turns in 90 degree steps (so sprites need 8 drawn directions).

### 5.4 Stealth that buys something (2026-10-18, standing)

The audit found sneaking bought nothing: stepping into a fight's area started it either way. The owner picked
**"Slip past"**:

- A guarded fight with foes in view starts when a foe notices someone, when the party attacks, or when the leader steps
  in **without** sneaking. A sneaking party that isn't noticed starts nothing and can pass, or rob a chest the guards
  can't see.
- One Stealth roll per member per visit (no free rerolls), shown on each portrait; red when a foe in view would notice
  that member.
- Before a fight, foes see in a 120 degree cone the way they face and hear within 10 ft (from BG3, 2026-10-07). In
  fights nobody has facing.
- Sneaking carries through exits. Sneaking ends when combat starts (asked 2026-10-21).
- Slipping past counts as "cleverly avoiding" the fight for XP.

### 5.5 Rest and camp (standing)

- **Short Rests anywhere outside combat** unless foes are awake and in sight (2026-10-12).
- **Long Rests are refused in a building or dungeon while enemies remain anywhere in it** (2026-10-09); towns, inns and
  the open road are fine.
- **A camp is made wherever resting is risky**, with a 1 in 6 chance of night visitors, fought before the rest's
  benefits.
- **Every new rest place needs** a `~ rest:long:<id>` night line and a region dream.
- **A long rest (or its benefits) inside the final dungeon** once the floor is cleared, or another mechanism that fits
  the book (asked 2026-10-24; the lane proposes which).
- Spells that ward a place protect a rest (Tiny Hut, Private Sanctum).
- **Dead party members stay in the party** (their slot isn't lost); Story mode never kills them.
- A booked inn room gives a small bonus so buying one has a reason.

### 5.6 Travel and the living world (standing)

- **Travel is a node map** with road hours, arrival time, and a warning before travelling after dark. Each region
  ships its own travel file, merged at load, so writers never edit one shared map.
- **Random encounters** roll per leg, by day or night; a road already walked rolls only 10% of the normal chance
  (2026-10-19). Never mid-road autosaves that could carry a party on after a fight elsewhere.
- **Walk speed +25% in exploration only** (fights keep book speed).
- Townsfolk keep schedules (home, work, tavern), towns have hours, seeded weather changes travel and sends people
  indoors.
- **NPCs who lead the party somewhere walk there with them**; in another map, the player confirms "follow now or come
  back later" (2026-10-18).
- **Party guests can be talked to and given things** (2026-10-18: "I have the key. How do I give it to him?").
- A map of the current location with every exit named, as a toggle inside the map screen, no spoilers of undiscovered
  places (asked 2026-10-24).

---

## 6. Story, quests and dialogue

### 6.1 The campaign's spine

- **Open after the opening.** After the first chapters the regions can be done in any order; each gives one level
  milestone, so the party is never locked out by level.
- **A reshuffle per playthrough** (the Tarokka reading) moves treasures, the ally and the final room. The draw comes
  from the playthrough seed, so loads keep it.
- **The villain is present from the start**: data-driven visits (a trigger, a condition, once or a cooldown, and a
  conversation, letter or fight), and a hidden measure of his attention (servants killed, treasures held, defiance)
  that brings his visits and spies closer.
- **Several endings chosen by flags** (at least three reachable by play; five built), each with epilogue slides that
  read the flags (which towns survived, each ally's fate).
- **After the ending the player can keep playing**: finish side quests, loot, rest, with a dawn-changed world
  (asked 2026-10-24). The finished state goes to a **new** save slot and never overwrites the player's manual save (a
  real bug the owner hit).
- **The villain's death gets its due**: a dying speech and a full epilogue before the dawn card (asked 2026-10-24).

### 6.2 Conversation rules (standing)

1. **Every conversation has an exit.** A forced fight or forced choice gets a way out; where the fiction allows,
   walking away is the failure.
2. **Failed social checks are spent.** A failed Persuasion, Intimidation, Deception, Performance or Insight option
   can't be retried, so **no menu may depend on a single social check**.
3. **A failed check never locks a quest.** Every check a side quest needs has a second way on: another skill, a
   price, time, another person who knows, or the fight. A lint (`fail_routes`) walks every quest with every roll
   failed.
4. **Not everything gives information.** Some NPCs don't know, are wrong, lie, refuse, or tell a joke that dies
   (2026-10-17). Every "heard anything interesting?" menu handing over a hook was the anti-pattern.
5. **Choose who speaks**: the player picks the hero who talks for the party; options tagged with a class, species or
   background are spoken by the member who has it.
6. **Party members speak through interjections and banter**; the player chooses every option.
7. **Conversation history** and marks on options already asked.

### 6.3 Side quests (standing)

- **Side quests never change main flags.** They may read them. Where a failure would naturally change something the
  main story reads, the quest stays unfailable or sets a side flag of its own.
- **Side quests can fail** (2026-10-18: "To allow for more replayability"). The aim is not punishment: a failure
  ends with a visible story and changes the world. Rules from the Side Quest Failure Plan:
  1. A failure is a story outcome, not a dead end: a journal entry with a Failed mark and something changed in the
     world. Never blocks the main story or another quest's only route.
  2. **Foreseeable from the fiction**: someone says what a choice will cost before it can close a quest; a clock
     shows a warning line in the journal while it runs.
  3. No punishing soft-locks: a failure lands at the point of no return, not before.
  4. Replayability first: a failure must change what the player sees later (an empty house, a person moved, another
     route). "You get less gold" alone is not enough.
  5. Local consequences only; never kill a villager who carries other quests, a reshuffle ally or a companion.
  6. Four ways to fail: a choice, a story beat elsewhere, a clock (tonight = next dawn, a few days = 3, a week = 7),
     a climax roll. Clocks start when the quest names the time, never at the rumour.
- **Side quests must be varied** (2026-10-17). The audit found 25 of 50 rumour quests were exactly "talk to someone,
  wait for dark, fight". Mix investigations, social quests, races, puzzles, escorts and quests with no fight at all.
- **No quest may get stuck for good.** An event that removes an NPC who closes a quest must also close or reroute
  it. A lint checks every stage can be reached.
- **Sort side quests in the journal by region**; the HUD's next objective shows its quest name.

### 6.4 People worth talking to (standing)

- **Every NPC has something unique (a story, feature or trait), something they want, and a secret** (2026-10-17). Not
  all of it needs a quest or drama.
- **NPC names are unique** across the game (speaker ids A-Z, no duplicates).
- **Major story allies stay present** (Story Allies Presence Plan, 2026-10-18; "I left Ireena at the temple and have
  had no contact with her for the rest of the game"):
  1. One conversation hub per ally, opened wherever they stand and while they travel.
  2. The hub reacts to what the party did since the last visit (up to three newest topics, each once).
  3. **Ignoring someone costs warmth, never the story**: colder lines, a smaller gift, an epilogue line; never a lost
     quest or ally.
  4. Allies write letters and meet the party on the road, spaced so a letter and a villain's visit never land
     together.
  5. Guests grow with the party (a stat block by level), so players don't leave them behind for being weak.
- **Companion approval** (2026-10-07): each companion likes or dislikes choices and says so; approval opens the best
  ending of their personal quest, camp scenes and romances. **Heroic Inspiration for playing in character.**

### 6.5 Cutscenes (standing)

- **A cutscene shows what the game's own views can't** (2026-10-07): the villain on his horse on a ridge, a whole
  valley from a crag, a reveal on a castle's scale. A full-screen still that fades up from black, drawn whole with
  black bars, caption low.
- **Every cutscene has at least two pictures** (2026-10-14), except minor ones, which are named and listed in the test
  (`ONE_PICTURE`). Lanes say which ids they consider minor.
- **A new picture at each new beat** of a long conversation (2026-10-12: "it's kind of boring looking at the same image
  for multiple phases of dialogue").
- **Stills never show hero faces.** The party is drawn hooded, from behind or at a distance, because the player may
  have a custom hero.
- **A picture shows exactly who is there**: alternative takes by condition (one with the heroine present, one
  without). Characters in pictures match their sprites and portraits (the tinkerer drawn female when he is male had
  to be redone).
- **Pictures bring their own music** for the rest of the conversation (sorrow, tension, dread, dawn, sacred moods).
- **Re-triggerable lore**: reading the villain's tome plays its cutscene every time, told mostly in his own voice,
  with the Narrator filling in what he didn't write, and it is sad and tragic (2026-10-18/20).

### 6.6 How dialogue is written (standing, 2026-10-18)

- **All new or rewritten dialogue is drafted by Gemini** through the owner's ai-bridge on his subscription (never an
  API key; never start the bridge). The lane reviews and edits the draft for length, canon and the dialogue format,
  and keeps **the brief and the raw reply** beside the work (docs/plans/gemini_*/ with a README).
- **Mechanical fixes** (typos, flags, speaker ids) don't need Gemini.
- **New lines stay unvoiced** until a voice job is approved (Part 9).
- **Add lines, don't edit voiced ones**: editing a voiced line throws away a paid clip.
- One small plain-text dialogue grammar (ADR 0008), linted in CI: every jump, speaker, item, quest, encounter and flag
  must exist. Writers learn one grammar.

### 6.7 Easter eggs and references (2026-10-18)

- **Winks, not copies.** No name, quote, art, music or sound from the referenced game. Each nod reads as ordinary
  in-world content to someone who never played it.
- **Hidden where the player has to look** (a search spot, an option at the bottom of a menu, a camp talk); never in a
  cutscene, a main conversation or a serious scene.
- **Small rewards only**: a laugh, a codex entry, Inspiration, a trinket, a hidden achievement. No lasting magic item,
  main flag or quest.
- **The Narrator never winks.** Out-of-world jokes live only in out-of-world text (achievement names).

---

## 7. Characters, monsters and companions

- **Every monster has a portrait.** Every character sprite walks and attacks in 8 directions (a test checks).
- **Distinct things look distinct**: a Vampire must not share a Vampire Spawn's sprite; a statue gargoyle and a waking
  one need their own states; a boy squire is a boy.
- **Heroes get the fuller set**: walk, idle, attack, cast, hurt and die, cut from video clips into sprite sheets; real
  motion, not a puppet rig (the owner wants the hero animation to show real motion).
- **Summons have sprites** (Guardian of Faith, Bigby's Hand).
- **Six companions** with their own art, voice, accent, personal quest, camp talks and approval; a custom hero can take
  a slot. Up to four travel at once; benched companions keep their level and bank the levels they missed.
- **Allies are balanced against each other**: a recruitable ally should be about as strong as the others who join at
  that point (Ismark brought up to Ezmerelda, asked 2026-10-21; numbers to be proposed by the lane).
- **Monster stat blocks are the book's.** HP at book value (Part 3.5). Custom monsters are proposed and flagged as
  custom.

---

## 8. UI, UX and controller

### 8.1 Standing rules

- **UI never overflows.** A layout test opens every screen at 1080p, 1440p, a small window, 16:10 and 4:3 and fails on
  text or buttons spilling out or cut without an ellipsis. Every new screen joins it.
- **Every screen has a way back.**
- **Full controller support** (2026-10-08): D-pad or stick moves focus, A chooses, B goes back, X opens the item menu,
  Y explains (again to pin), LB/RB step tabs, LT/RT change character, Start confirms. Focus lands on the screen in
  front; a visible focus frame in pad mode; button pictures switch with the device (Xbox, PlayStation, Nintendo);
  controller rebinding beside keys.
- **The character sheet is Baldur's Gate 3-style**, not a wall of text (2026-10-06). Long rules text goes in a
  tooltip; the page keeps names, one-line summaries and tags.
- **Rules words you can hover and pin**: Prone, Concentration, Bloodied open their definitions, which can hold further
  terms.
- **Shapes, not squares** (2026-10-06): long hexagon buttons, bevelled panels, pointed bars, arched titles.
- **A crimson, black and aged-gold interface** with gothic trim; three bundled fonts so every platform looks the same.
- **Colour is never the only signal**: state is also told by shape or words (Bloodied, ▲, ✓, !).
- **Rarity colour frames only the item picture**, not the whole row (2026-10-17).
- **Inventory**: separate Potions and Quest tabs, an Attuned filter, search, junk with sell-all, paper doll, drag and
  drop between heroes. Scrolls and potions don't show under "Magic". Lists keep their scroll position when buying or
  selling. Hover previews wait 0.75 s.
- **Settings persist** across reloads (the attunement setting reverting was a bug). New settings default to the
  current behaviour.
- **Errors you can see**: a small notice instead of a grey screen when a script fails, and an in-game bug report
  (F12) that saves the report, a screenshot and the save.
- **What's new on launch**, a "Previously in..." recap on loading an old save, chapter jump-in saves.
- **Spell selection never silently replaces** a chosen spell when at the limit: the player unselects one first (todo
  2026-10-23).

### 8.2 Captures for anything visual

Every visual change is handed off with before and after captures, drawn off screen. Never open a game window that
can take focus from the owner's work.

---

## 9. Music, sound and voice

### 9.1 Music (standing)

- **Free tracks only** (CC0, CC BY, public domain), kept untouched with their licence, every title credited.
  Downloads need the owner's typed yes.
- **Music follows the place, the scene and the fight**: moods per place and region; a cutscene picture can bring its
  own mood for the rest of a conversation; boss fights raise the music.
- Owner picks: the opening is **Toccata and Fugue in D minor**; **Dark Descent** for big battles; **Stronghold** in the
  castle; castle music **shuffles** between rounds; a **dread** theme when key castle NPCs speak; **no organ in the
  castle**; no lively tavern tune in the villain's castle; **Chopin's Marche funèbre** is a favourite; lonely piano
  pieces in the castle ("find more songs like it").
- Somber places sound somber (a hero's grave should use music like the castle's, not a jaunty theme).

### 9.2 Sound (standing)

- Every hit and miss sounds; critical hits have their own sting; each beam of a multi-beam spell plays its sound.
- Enemies have battle cries, taunts, pain and death lines; beasts have noises. Named villains stay quiet in fights
  unless designed otherwise.
- Sound choices are made by ear by the owner in A/B rounds where it matters (combat sounds took three rounds).

### 9.3 Voice (standing)

- **Everything spoken is voiced**: the Narrator, NPCs, the party (in each hero's voice), and the custom hero's two
  voice choices. **Not voiced**: options, rolls, notices, books and letters, and lines holding a run-time name.
- **One clip per line, keyed by the line's text** (`<speaker>/<sha1(text)[:16]>.mp3`): only new or changed lines cost
  anything, the same line twice shares a clip, and the game works with any mix of voiced and silent lines.
  Consequence: **editing a voiced line forces a paid re-voice**, so add new lines instead of rewording old ones.
- **Only lines on main can be voiced.**
- **Accents**: locals speak with the setting's accent (Barovians, the Vistani and Strahd with a strong, clearly
  audible Romanian accent); outsiders keep their own. Each line carries a direction tag for its mood, plus the
  speaker's accent tag (2026-10-08: "capture the accent and the emotional tone of each line").
- **The Narrator stays on the model of his original lines** without tags (2026-10-08: the other model's Narrator
  lines were "horrible" next to the originals). Consistency of a long-running voice beats a newer model.
- **Every voice is designed from a written voice bible** (age, timbre, accent, rhythm, temperament), one file per
  speaker. Nothing is cloned from a real person. Children use ready-made library voices.
- **Casting rooms**: for each new character the voice lane designs three options and the owner picks one on a page
  where he can listen (picked so far: Rahadin D, Anghel Daskal C, Lief B, Cyrus B, Sgt Valcu A, Celestine B, Amber
  Sentinel A, Patrina on Helga Ruvak's voice, Pidlwick II on Peanut, Sarkhaza booming E, the Sunsword B; Ireena keeps her
  own voice).
- **Quote before spending**: every voice job is quoted first; the owner types the exact approval in the voice thread.
  **One voice lane at a time.** Minor characters' designed voices can be released after their lines are made, to
  stay within voice slots; their clips stay.
- Sentient items can speak (the Sunsword got lines and a voice, 2026-10-18).

---

## 10. Art pipeline

- **Free assets first.** CC0 or clearly free licences only, kept untouched with their licence in a sourced folder and
  credited. Every download waits for the owner's typed yes with its file name, source, licence and size.
- **Paid art only with approval**: quote the cost first, then the owner's typed yes in that lane's own thread. Image
  generation goes through one script with the model pinned, every call logged in a shared ledger with a stop point per
  key; a tool that stops at its limit reports instead of overriding.
- **Characters come from one pipeline** (a 5-view turnaround on a plain white background, cut into 8 directions) so
  the style stays consistent; free packs are for props, sounds and UI.
- **Colours only from the palette** (the world's and the UI's lists).
- **3D models**: free CC models (a dragon skull, a skeleton, a walking hut) or code-built primitives. Blender runs only
  when the owner says the Mac is idle.
- **Video for motion**: hero animations are cut from short image-to-video clips into sprite sheets (video as a source
  of in-between frames, not as the playback format, which cost too much CPU). Quote clip counts and cost first; walk and
  idle first.
- **Stills never show hero faces** (6.5).
- **Never fall back to plain boxes** for new content.

---

## 11. Data-driven design and engine architecture

The engine is code; the game is data. Writers (Claude lanes) add content without touching code.

- **Rules data is JSON**, loaded once through one compendium, validated against schemas plus cross-file checks (every
  id a file names must exist) (ADR 0005). Agents edit and diff plain JSON; there is no generated layer.
- **Pure logic libraries**: `rules/`, `combat/` and `story/` never touch scenes, nodes or UI, take the dice roller as an
  argument, and compile standalone in CI. The whole fight runs headless, which is what makes fight tests possible.
- **Modifiers are a contract**: data names a stat; the engine reads it. A new stat is added to the contract and the
  engine together, never invented in data. Bespoke behaviour sits behind a named id.
- **A character is a record of choices** (species, background, scores, keyed picks per level). Nothing derived is
  saved, so data fixes reach old saves automatically.
- **Templates**: "Weapon +1" or "Flame Tongue" on any fitting base item; spell scrolls on any spell. Item powers cast
  through the spell engine, so improving a spell improves its items.
- **Locations are data**: map rows (floor, wall, low cover, difficult terrain, heights), areas, exits, doors, props,
  containers, lights, traps, NPCs, fights with triggers and level versions, narration keys, rest rules.
- **Region packages own their files** (a design doc, locations, dialogue, flags, quests, travel file), so parallel
  writers never collide.
- **The flag registry is split by region**; CI fails on a flag that is read but never set, set but never read, or not
  registered.
- **Saves**: a change to what a save holds bumps the save version and adds an upgrade step; a library of golden saves
  from every old version loads in every test run. The owner is told before any save version bump.
- **Never touch the owner's saves or settings**. Read his save read-only when a lane needs it (tuning against his
  party).
- **Logs are append-only** (the generation log). Large binaries go to LFS only when added or changed since the LFS
  cut-over; never migrate old files.
- **One world unit is one 5 ft square**; scenes are built in code; static types everywhere.

---

## 12. Testing tiers and fight guards

- **An in-house headless test runner** (no third-party addon). Any script error fails the run, so a script that fails
  to compile can't hide behind a green count. Tests run in parallel processes.
- **Tiers by risk** (the builder runs them per batch):
  - **Quick** (lint, compile, data validation, the change's own tests): audio, art and data.
  - **Small code**: quick plus the phase-exit playthroughs, continuity, side quest tests, side-quest bosses, night
    visitors, cutscenes (and voice-over for voiced dialogue).
  - **Full CI**: combat and targeting changes.
  - Sprite and video animation branches merge without tests.
- **Fight series**: every fight is played by an autopilot party over fixed seeds, and its win count must stay in its
  band. Timeouts count as losses. Never weaken a test to pass.
- **Fight guards that do hold a release**: crashes, script errors, and fights that cannot end. **Fight outcomes don't
  hold a push or earn the owner a question** (2026-10-19): when a rule change moves a fight's win rate, the expectation
  follows the measured value.
- **Playthrough bots** walk the whole campaign to each ending. They are path-sensitive: never move an existing
  walkable square, spawn, exit or fight start; extend maps, don't redraw them.
- **Content lints**: every quest reachable with every roll failed; no stuck quests; every cutscene two pictures unless
  listed; every monster a portrait; every sprite 8 directions; every icon credited; every conversation linted.
- **A capture for anything visual.** Never mark an owner sign-off as passed.

---

## 13. Release and patching

- **Any engine project-file change costs players a full download** (about 4 GB here). Batch those changes into one
  release.
- **Releases need the owner's typed yes** in the release thread. Version numbers step by patch (1.0.10 live, next
  1.0.11).
- **The public site keeps spoilers inside the wiki section only.** The wiki is regenerated from the game data after
  content lands (standing yes for wiki redeploys); hand-written prose outside the generated blocks is kept.
- **Spoiler line for public writing**: the premise, region names, the reshuffle as a mechanic, the companions, the
  counts (three treasures, an ally, five endings) are fine; what the reading reveals, who the ally can be, the
  treasures' places, the endings' content are not.
- **Intellectual property**: the game uses a commercial campaign and the full Player's Handbook under a personal-use
  decision. Content beyond the SRD is never distributed as data text. *Before any public download, decide: friends
  only, an SRD-only cut with renamed places, or permission from the rights holder* (Showcase Plan, 2026-10-08). A new
  world built on SRD-only rules and original lore avoids this question entirely.

---

## 14. Workflow: lanes, the builder, batching and approvals

### 14.1 Plan with the strong model, build with the fast one

- Big asks get a **plan first** (an audit of what exists with numbers, the rules every package follows, numbered
  packages one lane can each build, waves of at most three lanes on different files, costs, and the owner's
  **forks**, each with a recommended default). Then lanes build one package per hand-off.
- Model policy (2026-10-21): plans and hard work on the stronger model when the owner asks; lanes on the faster model
  at high effort; the builder on the smallest model. Pass the model and effort on every lane start.
- When usage runs out, pause lanes and keep a **held-asks list** so nothing the owner asked for is lost; resume per
  area on his word, one batched message per lane.

### 14.2 Lanes

- **One lane = one thread, one working copy, one branch per task.** Lanes never push or merge main.
- **Fewer lanes** (2026-10-19): small asks go into a standing **area lane** (combat rules, UI, quests, bosses, magic
  items, allies, voice, video sprites, HUD, buildings, wiki), one clean branch per task.
- **Hand-off format**: branch, commit hash, files, and the shared "hook" functions it touched; `make check` green;
  the tests it names; captures for anything visual; lines that need voicing; departures recorded.
- **Hook files** (the story state, dialogue runner, main menu, combat view and HUD, game root, location view, explore
  HUD, encounter, Makefile, CLAUDE.md): one branch per hook per batch unless the functions differ.
- **Conflicts**: ask the lane for a clean branch on current main rather than resolving it for them.
- **Resource caps on a shared machine**: limited test and import slots, a reserved share for the builder, no Godot
  windows that steal focus, stop lanes if the disk runs low.
- **Clean up**: a done lane removes its working copy.

### 14.3 The builder

- One thread merges hand-offs onto an integration branch, runs the right test tier once per batch, drops and names a
  failing branch, and pushes the passing batch. **Only the builder pushes main.**
- After a landing: verify the remote (commit range, no stray merges or trailers, one author, large files stored
  correctly), tell same-area lanes, ask landed lanes to clean up, re-run the wiki if content changed, ask the voice
  lane to quote new lines, and tell the owner what landed.
- **The owner is the only commit author.** No co-author or tool-attribution lines in commits (project rule,
  2026-10-15).

### 14.4 Approvals

- **If the owner asked for a step, that is his approval** for that ask, once.
- **Typed approvals** for anything paid (voice, image and video generation), downloads, installs, release and site
  deploys, pushes to main that the machine's guard blocks, credential reads and branch deletes: the owner types the
  exact words in that lane's own thread. A changed price needs a fresh yes. A "yes" in the project chat is the decision,
  not the approval.
- **No-cost forks**: build the recommended default and say so, rather than waiting.
- **Never ask for or store keys; never echo them.**
- **Keep lanes quiet**: don't message lanes between resumes except for the owner's direct questions.

### 14.5 How the owner gives work

- **"TODO - ..."** messages go to a next-week todo file (done, in progress, not started, with the lane and commit
  for each), screenshots saved beside it.
- **Bug reports** come from inside the game with the save, a screenshot and the log. Reproduce first, then fix, then
  say what caused it.
- **Questions get answers from the code**, with file and line, and say when something was read and not run.

---

## 15. Open decisions

Decide these early in a new project; in this one they are still open (as of 2026-10-24).

| Question | Where it stands |
|---|---|
| Villain tone: velvet knife (A), mask slips (B) or cat and mouse (C) | A recommended 2026-10-08 with one B-style slip; final pick not recorded in the sources |
| Who counts as a boss for +25% damage | Code: legendary actions or CR 5+; the owner's rule is bosses only. A narrower definition (an explicit flag) is proposed |
| HP rollback vs. the difficulty table's HP changes | Rule decided (book HP, hit harder); reconciling the mode table is pending |
| Fleeing combat | Asked 2026-10-24; opportunity attacks, whole party or not, pursuit, which fights block it, the fight's aftermath all open |
| A long rest inside the final dungeon | Asked 2026-10-24; floor-cleared rest with vampire interruptions, or a sanctuary/shrine/ally refuge; the lane proposes |
| Post-ending play | Asked 2026-10-24; the world state after the villain dies, and the save-slot fix, are for a lane to design |
| Monster initiative: shared per type (DMG option) or each its own | The deviation says shared; a 2026-10-20 todo asks for separate rolls |
| Inspiration on statement checks | Only the best roller is offered it today; the lane must ask before changing |
| The skeleton easter egg ("Withers") | His "No withers from Baldur's Gate" (2026-10-20) is ambiguous: ask before dropping nod 22 |
| Talking skulls asking the same three questions | From the book by design; giving each skull its own questions was offered, no answer yet |
| Iron knight at 300 HP | Flagged to him; falls under the HP rollback |
| Public distribution | Friends only, SRD-only cut, or permission; undecided |

---

## 16. Starting a new world: a checklist

1. **Pick the source and the rules.** One campaign or setting, delivered whole. Current official rules, checked
   against the text. Decide the licence position first (SRD-only and original lore is the clean path).
2. **Write the pillars and the tone guide** before content: what the game leads with, the Narrator's rules, the
   villain's voice, what is never allowed. Write one voice bible per main character.
3. **Pick the look with target frames** before building any of it, and set a colour script so no two neighbouring
   regions share a signature.
4. **Build the engine as pure, headless libraries** (rules, combat, story) with one dice roller, Breakdowns for every
   number, a reaction pipeline that always asks, and data loaded from JSON with cross-checks.
5. **Set the guards on day one**: the layout test, golden saves, flag lint, dialogue lint, fight series with bands,
   the fight-spread test, the stuck-quest and failed-roll lints, portraits for every monster, 8 directions for every
   sprite.
6. **Make content as region packages** that own their files, each with its travel file, flags, quests and dialogue.
7. **Draw the land, then lay the grid.** Natural outlines on the side the party can't stand on; built things straight;
   the grid an overlay.
8. **Monsters at book HP; make them hit harder** when a fight is too easy; plan bosses (minions, lair actions, phases);
   aim for 2-3 round normal fights.
9. **Write dialogue through one drafting pipeline**, keep the brief and the reply, keep every conversation's exit,
   and spend failed social checks.
10. **Voice per line keyed by text**, quote before spending, add lines rather than edit voiced ones.
11. **Free assets first**, paid art and voice only with a typed yes after a quote.
12. **Run the work as lanes and a builder**: plans with forks and defaults, one branch per task, batched merges,
    one author, the owner's saves untouched.
13. **Write every departure down** (deviations), every decision with its date (this document's appendix), and keep a
    held-asks list and a todo file the owner can read.

---

## 17. Appendix: decision log by date

All dates 2026. "Asked" means decided by the owner and not yet built.

- **10-05** Full 2024 PHB as the rules source, personal use. SRD 5.2 as the import base.
- **10-06** Style bible approved; one image model pinned; free asset packs allowed (CC0 or clearly free); voice-over
  with ElevenLabs; the Narrator designed in the style of BG3's; Barovians with a strong Romanian accent; the BG3-style
  character sheet and "shapes, not squares"; never open Godot windows that take focus; Strahd uses the campaign
  book's numbers.
- **10-07** HD-2D "Modern" look the default, "Classic" frozen; characters keep ink outlines, the world doesn't;
  difficulty modes modelled on BG3 with +2s; reseed dice on every load; LFS for new binaries; sight cones before
  fights; high ground ±2; locals on the accent-keeping voice model; cutscenes for what the views can't show; Raise Dead
  ordeal -4 for 10 days; temple uses scrolls; approval, romances and Inspiration for playing in character.
- **10-08** Every line directed with mood and accent tags; the Narrator stays on his original model; three bundled
  fonts; traps only found by explicit checks, armed in fights; 2014 Divine Smite; only costly consumed components
  tracked; tilt-shift edge blur; interiors furnished like their owner's home (Madam Eva's tent as the model); five
  rules for exteriors; full controller support asked; natural slopes; prices rounded up to whole gold; Strahd tone
  options written (A recommended).
- **10-09** Long Rests refused in dungeons while enemies remain; Long Jump with an arc; shared party turns; two weapon
  sets with a free swap; a hero at 0 HP wakes from the party's Long Rest.
- **10-12** Flanking on (with a setting); heroes may share squares; small decor is open floor; Short Rests anywhere
  outside combat; useless spells get a use or leave the game; a new cutscene picture at each beat; the colour script
  for region variety.
- **10-13** Reaction spells exempt from one-slot-spell-per-turn; every foe with spells uses its best one; non-boss
  fights at 5 wins in 8; the villain's harassment fights run until beaten; Detect Thoughts out.
- **10-14** Bosses at 3 wins in 8 (superseded 10-23/24); every cutscene at least two pictures; XP mode as a choice;
  prepared spells change any time outside combat; magic item prices from Sane Magical Prices; every magic item the
  story doesn't need is for sale.
- **10-15** Every fight starts spread out (the Fireball rule); Raise Dead in every town; hoards scaled to owner and
  level; commits have one author.
- **10-17** NPC trait, want and secret; side quest variety; comedy and failure dialogue; magic item prices in rarity
  bands; each lasting item once; magic sellers buy at half; finds lean to combat across classes; inventory Potions
  and Quest tabs; rarity frames the picture; music audit (scene moods); walls never collapse, blockers fade.
- **10-18** Side quests can fail (plan rules); story allies stay present (plan rules); BG3 easter eggs as winks;
  dungeons extended with rooms that carry the book, never redrawn; the Amber Temple made beautiful; overworld stealth
  option A (slip past); the heroine as a non-combatant guest; the Tome cutscene in 3-4+ scenes; the ancient red dragon
  from the 2025 MM; dialogue drafted by Gemini through the ai-bridge; NPCs lead the party; guests can be talked to.
- **10-19** Draw the land, then lay the grid; bosses +25% damage on Balanced and harder; Eldritch Blast reaction is one
  beam; foes may share squares; known road legs 10% encounters; no re-tuning when a rule changes; fight outcomes don't
  hold a push; fewer lanes (area lanes).
- **10-20** The Tome reading as a conversation in Strahd's voice, re-triggerable; work paused for quota.
- **10-21** Plan every boss (minions, lair actions, phases; stat blocks may change); the lich's stat block; Legendary
  Resistance rule; tune against the owner's own party; per-beam effects and sounds; readied spells and concentration;
  invisible foes in the initiative list; model policy.
- **10-23** Difficulty from hitting harder, not HP; Absorb Elements must ask; the dragon's breath stays; dragon lair
  bigger, more gold, no stronger minions; the Huntsman's horn affects enemies only; random encounters can be turned off;
  characters' art matches their gender.
- **10-24** Monster Manual HP for every monster, +1 to +3 to hit and about +30% damage as compensation; non-boss fights
  2-3 rounds, 4 at most; legendary actions only after a player character's turn; Strahd +14 to hit; melee preference
  and no needless opportunity attacks for the AI; Counterspell for every enemy spell; fleeing combat (design open);
  post-ending play; finished saves never overwrite manual saves; a long rest in the castle; a current-location map;
  Gertruda as a non-combatant while she travels with the party.
