# Overworld stealth: options

Ashwin's todo: "We need to improve stealth in the overworld. There really isn't a point to it right now."
This note says why, lays out three ways to give sneaking a point, and recommends one. Nothing here is built yet. The
rules today are in docs/rules/stealth.md and docs/rules/deviations.md (rows "Sneaking up" to "Hiding before a
fight"); the code is addons/dnd_core/world/exploration/location_stealth.gd.

## Why sneaking buys nothing today

Stepping into a fight's area starts that fight whether the party sneaks or not, and 51 of the 60 walk-in fights don't
show their foes before that step, so sneaking can't skip, scout or rob any of them. All it can buy is the 2024 Surprise
(Disadvantage on the foes' Initiative), which one low Stealth roll usually spoils, and starting hidden, which needs
Three-Quarters Cover from every foe.

The numbers behind that, from origin/main (af75ff142):

- **Walk-in fights.** 60 distinct encounters start on `enter_area`. Only 9 are `waiting` (foes standing in view
  before the fight): frozen_watch, cat_sleepers (at night), cauldron_coven, ghakis_keepers, wachter_cellar_cult,
  tower_night_visitors, night_streets_dead, den_guards, cellar_dig. The other 51 (11 of them Strahd's final battles)
  put their foes on the board only when the fight starts. Most fights (319 entries) start from a conversation,
  where sneaking plays no part.
- **Waiting fights still start on the step.** A waiting foe that never notices the party doesn't help: the leader
  stepping into the area starts the fight anyway (location_walk.gd `_check_areas`). So sneaking only lets the party
  walk *beside* a guarded room unseen, which it could already do by not going in. Six of the nine are side rooms;
  three stand on the only way through (the den mouth, the Ghakis yard, Barovia's square at night). Four hold a
  container that can only be had by fighting (watch_chest, spires_witch_shelf, ghakis_cart_box, overseer_pack).
- **Surprise is small and fragile.** In 2024 a surprised creature only has Disadvantage on Initiative. A foe is
  surprised only if it notices *none* of the party, and each member keeps one roll. The test party's paladin wears
  Chain Mail (Disadvantage, +0): he goes unnoticed by a bandit (passive Perception 10) about 1 time in 4, by vampire
  spawn (13) 1 in 8, by a wolf (15) 1 in 16.
- **Starting hidden** needs a total of 15 and Three-Quarters Cover from every foe at the moment the fight opens, which
  the compact maps rarely give a whole party.
- **Small leaks.** Stopping and starting sneaking out of sight rerolls every total for free. Sneaking resets on every
  map change, so a party can't arrive in a place already sneaking. The Wait screen refuses ("Not with foes in sight")
  anywhere in a place once any waiting foe there has been seen, because a seen foe keeps its figure and
  `WaitScreen.why_not` asks `nearest_waiting`, not who can see the party now.

## Fixes that come with any option

These are small, cost no fight its band, and make the stealth roll something the player can read and plan around.

1. **One roll per visit.** Each member's Stealth total is rolled when the party starts sneaking and kept until it
   leaves the place, rests or an hour passes; stopping and starting again keeps it. (Closes the free reroll.)
2. **Sneaking carries through exits.** A party that leaves a place sneaking arrives sneaking, with fresh totals.
3. **Show the totals.** While sneaking, each portrait wears its Stealth total (the weak link shows as a red number
   when a foe in view would notice it in any light). Today the totals are only in the roll log.
4. **Wait and Short Rest ask who can see you now.** `WaitScreen.why_not` uses `LocationStealth.foes_in_sight` (the
   rule the Short Rest already uses), so a party out of the foes' sight can wait; while sneaking, foes that wouldn't
   notice anyone don't count. Waiting through dawn sends a night-only waiting fight away, as coming back by day
   already does (night_streets_dead, tower_night_visitors, wachter_cellar_cult).

Moves: test_wait (a case for a seen foe out of sight), test_sight_cones, test_rest_rules; docs/rules/stealth.md, the
deviations "Sneaking up" row; the wiki's hand-written Rules/Sneaking, Stealing and the Watch page. No fight series.

**Built (branch `stealth`, piece 1):** all four. One roll per visit is `LocationStealth.kept` (a roll stands 60 minutes
of the clock, so a rest or a long Wait rerolls on the next look); the exit carry is `GameRoot.enter_location`'s
`sneaking` argument, applied after the arrival's own area checks; the totals are `ExploreHud` badges
(`LocationStealth.exposure`, coloured as `SightOverlay.eye_mood`); Wait and the Short Rest share `foes_in_sight`.
Tests: test_stealth_visit, test_pad_explore, test_layout.

**Built (branch `stealth`, piece 2):** Option A's slip-past rule for the nine fights that are `waiting` today (not the eight
conversions): `LocationStealth.step_in` and `_check_slipped`, the XP award through `Xp.talked_away`, guarded containers,
sleepers, the hover hints and the arrival rule (`LocationView.arrive_sneaking`). Tests: test_slip_past, test_xp.

**Built (branch `stealth`, piece 3):** all eight conversions, each its own commit: garden_sentry, court_post_watch,
crg_turret_guard, larders_jailers, cat_gargoyle_watch, peak_guardians, crg_courtyard_gargoyles and berez_scarecrows. Every
foe in view has a `facing`, what joins only when its fight starts is `unseen`, and each series starts where the foes first
notice a party walking in from the spawn the story uses (read off by walking it), with the doors that walk opened. Hit
Points were retuned to hold 4 to 6 in 8 from there: the Abbey garden's wisps 27 to 18, the jailers 60 to 135 (and three of
their horrors moved), the champion's gargoyles 134 to 110, the peak's 100, 87 and 77 to 55, 70 and 58, the courtyard's 77 and
84 to 64 and 68 (and six gargoyles moved north), and Berez's level 9 version by a third. The courtyard, the jailers' post and
the champion's tomb also hold their other real ways in (docs/story/fight_tuning_castle.md names the starts that no tuning
holds). `make validate` asks every fight made `waiting` since for its facings (`LEGACY_WAITING` lists the nine that predate
them). Yester Hill's wardens' camp and the winery's druids stay walk-in fights.

## Option A: Slip past (skip a guarded room, or rob it)

**Rule.** A `waiting` fight starts when one of its foes notices a party member, when the party attacks, or when the
leader steps into its area *without sneaking*. A sneaking party that steps in unnoticed starts nothing: the foes stand
where they are and keep checking every step (the cones, the 10 ft ring, light, cover, as now). Taking anything from a
container inside a waiting fight's area is a crime against its foes: it uses the F8 witness rule, so a foe that would
notice the taker starts the fight, and one looking the other way doesn't. A foe asleep (`surprise: enemies`) wakes
only to a party that isn't sneaking, or to a fight.

The party *slips past* a waiting fight when every member who entered its area has left it again unnoticed. In XP
mode that counts as cleverly avoiding it (2024 DMG): it pays as winning the version the party would have met, keyed
`_xp/fight/<id>` like the plan's talked-away fights, so fighting it later pays nothing more. In milestone mode the
payoff is the Hit Points, slots and time saved, and what was in the chest. The fight's own `flag` is not set by
slipping past, so what the story gates on it stays as if the fight were still to come: Vallaki's later fights still
read `wachter_cult_broken`, and the den's inner fights still want `den_guards_cleared`, Zuleika's word or Emil freed
(the last already a way in that needs no fight).

**More waiting fights.** Eight walk-in fights whose foes are watchers, not things bursting out of hiding, become
`waiting` with a `facing` each, so they can be seen from the doorway and planned around: court_post_watch
(court_post_rack), crg_turret_guard, larders_jailers (larders_jailers_chest), cat_gargoyle_watch (cat_champion_slab),
crg_courtyard_gargoyles (the castle gate courtyard, on the way in), peak_guardians (spires_hollow_guardian),
garden_sentry, berez_scarecrows (on the way to the hut stump). That makes 17 waiting fights, 5 of them on the only way
through. Yester Hill's wardens' camp and the winery's druids stay walk-in fights: F7 made them `waiting` once, and
they spotted the story bot from the summit path and the winery door, which forced optional fights and broke
test_phase5_exit.

**UI.** Stepping into a guarded area unnoticed toasts "Unnoticed: they haven't seen you". A container in a waiting
fight's area says on its hover hint "Guarded: taking from it where they'd see starts the fight" (the F8 owner hint).
Slipping past toasts "Slipped past the <fight>" (and the XP toast in XP mode). Hovering the edge of a guarded area
while not sneaking says "Stepping in starts the fight; sneak to pass unseen". The sight overlay and eyes stay as
they are.

**Moves.**
- Fights: none of the nine existing waiting fights changes for a party that fights (the series start them directly).
  The eight converted fights can now start from up to 30 ft out, before the doorway, so each is re-measured from its
  real entry and retuned if it leaves 5±1 (bosses 3/8): test_scaled_fights_castle_rooms (six of them),
  test_scaled_fights_regions and test_scaled_boss_fights (garden, scarecrows).
- Tests: test_sight_cones (slipping through, guarded containers, sleepers), test_stealing_and_crime (shared witness
  rule), test_xp_mode and test_xp (the slip-past award), phase 3-6 exits and test_storyqa_continuity (the story bot
  walks past rooms that now have foes in view; path-sensitive), side_quests_* and side_quest_bosses for the
  scarecrows.
- Wiki: each fight line (build_wiki.py `fight_block`) gains "waiting" so the tables show which fights can be slipped
  past; the hand-written Sneaking page.
- Docs: stealth.md, deviations rows "Slipping past" and "Guarded containers", docs/plans/xp_mode.md §6.

## Option B: Ambush (a free first round)

**Rule.** House rule on top of the 2024 one: a foe surprised *by a sneaking party that opens the fight* has
Disadvantage on Initiative and is also caught flat-footed through its first turn: it can't move, act or take
Reactions until that turn ends (the 2014 rule, and Baldur's Gate 3's). Starting hidden asks what the Hide action asks
and no more: Stealth 15 and out of every foe's line of sight or behind Three-Quarters Cover, so a member round the
corner starts hidden. Data `surprise` (36 entries, 16 on the party, 20 on foes) stays on the 2024 rule, so no
scripted ambush changes.

**UI.** The turn strip marks surprised foes with a "Surprised" badge and greys them through their first turn; the log
says "<foe> is caught unawares". The plan bar's hint and the Attack menu say "Sneaking: foes who haven't noticed you
lose their first turn". The portraits' Stealth totals (fix 3) matter most here.

**Moves.**
- Fights: no series moves (the autopilot doesn't sneak), but any fight a sneaking player opens gets a free round. On
  a sample of 8 fights I'd measure a sneak-open series to show how big that is; I expect +1 to +3 wins in 8, which
  cuts against the 5/8 tuning. Making it symmetric (scripted ambushes take the heroes' first turn too) would move
  all 36 `surprise` entries off their bands and need 36 retunes.
- Tests: test_sight_cones, test_plan_before_the_fight, test_combat_encounter (initiative and the skipped turn),
  test_turn_strip.
- Wiki: the glossary's Surprise entry (data/glossary/terms.json, also the in-game tooltip); the Sneaking page.
- Docs: deviations row "Surprise" (replaces "Surprise and noise").

## Option C: Quiet roads and lying low

**Rule.** The travel map gets a pace switch, by the 2024 table: Normal (3 miles an hour, Disadvantage on Stealth, as
now) or Slow (2 miles an hour, so each leg takes half as long again, and Advantage on Perception). When a road's table
rolls a fight, before it starts, each member rolls Stealth (Disadvantage at Normal pace) against the foes' best
passive Perception, and the party's best passive Perception (+5 at Slow pace) is checked against the foes' best
Stealth roll:

- spotted first and nobody noticed: a choice card, "Wolves ahead on the Old Svalich Road. They haven't seen you":
  **Go round** (no fight, no spoils, half an hour more), **Ambush** (the fight, foes surprised under the 2024 rule)
  or **Meet them** (the fight as now);
- spotted but someone noticed: the fight, nobody surprised (a scripted road ambush loses its Surprise);
- not spotted: as now.

Lying low (fix 4) is part of this option's pitch: with the Wait screen allowed out of sight, waiting out the night
beside a night-only fight is a real choice.

**UI.** The travel map's route panel shows the pace and the hours it costs; the choice card names the foes, the road
and what going round costs; the d20 panel shows the Stealth and Perception rolls.

**Moves.**
- Fights: the 43 road fight entries in 11 tables. Going round skips their spoils (RoadSpoils: "every random
  encounter pays") and their XP; an ambush only adds Disadvantage on Initiative, so test_scaled_road_fights holds.
  Slow pace means more hours on the road, so more Strahd's-attention and weather time.
- Tests: test_travel, test_road_spoils, test_road_grounds, test_scaled_road_fights (the vineyard road ambush when
  spotted), test_layout and test_pad_screens (the travel panel and the card), test_wait.
- Wiki: the road encounter tables (`event_words` and the fight lines) gain "can be avoided"; the travel page.
- Docs: docs/ui/travel_map.md, deviations rows "Travel pace" and "Spotting a road encounter".

## Recommendation: A, with the four fixes (Ashwin picked it, 2026-10-18)

Option A answers "there isn't a point" most directly: every guarded room becomes a choice between fighting it,
slipping past it and robbing it, the way Baldur's Gate 3's sight cones (which the game already copies) are used. It
keeps the 2024 Surprise rule and doesn't make any fight easier for a party that fights, so the 5/8 tuning holds; the
cost is re-measuring eight converted fights from their new entries. B is the cheaper build but hands a sneaking player a
free round in every fight they open, which undoes the harder fights asked for on 2026-10-13. C makes the roads better
but only pays off when a random roll comes up, and it touches the travel UI and 43 road fights.

If A is picked, the build order is: the four fixes, the slip-past rule and guarded containers on the nine existing
waiting fights, the XP award, then the eight conversions one at a time, each re-measured and retuned before the next.
