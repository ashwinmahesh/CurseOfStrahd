# Difficulty modes (F1)

Four modes, picked on the New game page after the party (ui/menu/difficulty_page.gd) and kept in the save as
`StoryState.options["difficulty"]`. Saves from before the modes have no entry and play as Balanced, which is the game
exactly as it played before. The rules live in one table, `combat/difficulty.gd` (`Difficulty.MODES`); the AI's side
is `combat/ai/ai_tactics.gd`. A boss is whatever `Difficulty.boss_entry` calls one (the boss bar's list too: `narrative/combat/bosses.json` by monster or
name, and any foe with legendary actions), not every Challenge Rating 5 foe; `Difficulty.damage_factor` gives the multiplier and
`EncounterDamage.deal_damage` applies it, the one place all combat damage passes.

| | Story | Balanced | Tactician | Honour |
|---|---|---|---|---|
| Enemy Hit Points | 25% fewer | stat block (or the fight's tuned number) | 20% more | 20% more |
| Inside the Hit Dice range | yes | — | yes | yes |
| Lighter boss versions for a low-level party | yes, also 25% fewer | yes | yes, also 20% more | no: back to the stat block (boss = legendary actions or CR 5+) |
| Boss damage (`boss_damage`) | the book's numbers | 25% more (owner, 2026-10-19), on everything a boss deals the other side, before the target's defenses; the log says "Boss: +N damage" | as Balanced | as Balanced |
| +2s, like Baldur's Gate 3 | party: attack rolls and saving throws | — | enemies: attack rolls, spell attacks, DCs of spells and actions | as Tactician |
| Boss to-hit and DCs (`boss_bonus`) | the book's numbers | by the lowest hero's level at the fight: +1 to level 4, +2 at 5-8, +3 from 9 (owner, 2026-10-25: "+1 to bosses before level 5, +2 from 5-8, and +3 for 9-11"; 12 and up keep +3), to attack rolls, spell attacks and DCs of spells and actions; shows as "Balanced +N" in the Breakdowns | the +2 every foe gets (no more on top) | as Tactician |
| Who enemies hit (`tactics`) | `kind`: spread blows, no killing-blow bonus | `standard`: as before | `sharp`: the hurt, the target its side is on, concentrating casters, healers | `ruthless`: sharp, and cruel foes strike heroes at 0 HP |
| Potion of Healing on armed humanoids | — | — | yes: drunk when Bloodied; badly hurt and pressed, Disengage and step back first; looted if unused | as Tactician |
| Enemy spellcasters | as before (a few spells) | the best spell of the whole list when it beats the weapon (owner, 2026-10-13: every foe with spells uses them when that's its best option) | as Balanced, and a scroll of their strongest harmful spell; an unread scroll is looted | as Tactician |
| A broken side flees | — | — (cowards still flee when Bloodied) | yes, except mindless, fearless and bosses | as Tactician |
| A foe with no way to any enemy, and no enemy with a way to it (walls, drops and bystanders in the way; doors and furniture count as ways through) | leaves after two of its turns in a row, except legendary creatures and Strahd | same | same | same |
| Shut doors on a foe's way to the party | opened (its object interaction) by any foe with hands and Intelligence 3 or more, not beasts, oozes, plants, constructs or swarms | same | same | same |
| Death | spared: Unconscious and Stable instead | rules | rules | rules |
| Long Rests in risky places | never interrupted | 1 in 6 | 1 in 6 | 1 in 6 |
| Saving | anywhere | anywhere | anywhere | one save (lane 16 builds it) |
| Changing mode | Settings, any time (lane 13 adds the row) | same | same | only at a new game; leaving is for good |

Owner decisions (2026-10-07): the modes are modelled on Baldur's Gate 3, +2s included, though the game plan's rule
had been "never the core math". Recommended and built while waiting for his word: an Honour party that is wiped out
carries on in Tactician (the run stops being an Honour run), and Story heroes can't die for good.

## How it fits together

- **A fight is set up** by `Difficulty.of_options(st.options).prepare(e)` in `LocationFights.start_encounter`, after
  the monsters are placed: one effect per enemy under the mode's name (its Hit Points and +2s, shown in its
  Breakdowns), potions for armed humanoids (`potions` meta on the combatant), and `arm(e)`.
- **`arm(e)`** sets `e.difficulty`, `Creature.spared_from_death` on the party and guests (never saved), and the
  party's Story effect (`fit_party`, which also takes another mode's off). A fight resumed from its round-start save
  calls `arm` with the mode the snapshot kept. Settings should call `fit_party` on each party member after a switch.
- **The AI** reads `e.difficulty.tactics` through `AiBrain.tactics` (AiTactics): `target_adjust` and `finish_scale`
  in the attack score, `fallen_plan` for Honour, `potion_turn` and `flee_turn` before the plan. Where the mode's
  `spells` is on (Balanced, Tactician, Honour) a caster's turn first weighs `AiBrain.spells` (AiSpells): each offensive
  spell of its list or its scroll, by expected damage plus the turn a condition takes away, against the weapon plan for
  the whole action; the spellcaster profile's own few (Phantasmal Killer, Magic Missile) are weighed with the rest
  there, and only its escape comes first. A creature that flees
  far enough leaves through `Legendary.leave(c, "fled")`: no more turns, no loot from it. In every mode, a turn with no
  attack in it (`finish_turn`) asks `stranded_turn`: a foe `cut_off` from every enemy for two of its turns in a row
  leaves the same way (`"cut off"`), so a fight nobody can finish ends (fight stalls lane, 2026-10-13). Closing in,
  a creature that opens doors (`AiBrain.door_opener`) walks round by the shut doors too and opens one it stands beside
  on its way (`_through_door`); the party's test autopilot does the same (mansion siege, 2026-10-13).
- **Monster DCs** take the monster's `spell_dc` modifiers (`MonsterActions.dc_bonus` for its save actions, and its
  spells' DC and attack in `MonsterActions.cast`). Lair actions, auras and grapple escape DCs don't yet.
- **Foes joining mid-fight** (Children of the Night) get the mode's numbers as `Encounter.add` places them.
- **Spoils**: potions the fallen foes still carried go into the fight's loot (`AiTactics.leftovers`).
- **Rests**: the rest screen treats a risky place as safe on Story.

## Hooks for other lanes

- Lane 13 (Settings): a Difficulty row listing `Difficulty.IDS` where `Difficulty.can_switch(from, to)`, the
  `describe()` lines as its tip, `switch_warning(from, to)` before leaving Honour, then
  `st.options["difficulty"] = to` and `fit_party` on each party member.
- Lane 16 (Saves): `Difficulty.named(...).one_save` marks a playthrough that keeps one save; after a wipe it offers
  carrying on in Tactician.

## Balance tool

`make balance ENC=<encounter> | LOCATION=<id> FIGHT=<fight> [LEVEL=n] [RUNS=n] [MODES="…"] [JSON=file]` plays a fight
`RUNS` times in each mode with the pregens on autopilot (tests/support/party_autopilot.gd) and prints wins, rounds,
heroes dropped and killed, foes that fled, potions drunk and the party's Hit Points lost.

## Still to come in lane 22

- Casters' buffs, heals and summons from their whole list (only harmful and hindering spells are weighed now).
- The tuning pass, after lanes 2 and 3 land, starting with Strahd's final fight.
- F13: surrender and captives, building on the broken-side rule.
