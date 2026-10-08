# Spare or capture (F13)

Beaten foes who can talk give up, and the party decides what happens to them. Owner picks, 2026-10-08 (built on the
recommendations while he looked): captives are dealt with right after the fight, and killing one is allowed, with
consequences. Knocking a creature out instead of killing it (the 2024 rule) is lane 2's part of F13.

## In the fight (`combat/ai/ai_tactics.gd`)

- **Who surrenders** (`AiTactics.can_surrender`): a humanoid foe that speaks a language, not a boss (legendary
  actions or CR 5 and up, `Difficulty.is_boss`), not a story character the fight names (Mother Ruxandra, Nikolai
  Wachter: their fate is the story's), not mindless and not Strahd. A stat block can opt out with
  `"never_surrenders": true`. Beasts flee instead (Tactician and Honour); undead, constructs and fiends fight on.
- **When**: on its turn, Bloodied, with its side broken (`AiTactics.broken`: half of those who began the fight down,
  fled or surrendered, or its leader fallen). In every difficulty mode; it's checked before potions and fleeing.
- **What it means**: an effect "Surrendered" (flags `surrendered` and `no_actions`, Speed 0). It stops acting, its
  Concentration ends, and its token shows "Surrendered". The encounter counts it as out of the fight
  (`EncounterTurns._check_over`), so a side that all gave up has lost. The party can still attack it.
- **Cutting one down**: `Captives.slain_after_surrender` counts surrendered foes that died; at the fight's end the
  companions who saw it react once (`Captives.CRUELTY`: Godrick -4, Wren -4, Liriel -3, Thistle -2).

## After the fight (`story/captives.gd`, `world/exploration/location_fights.gd`)

- **Captives** (`Captives.taken`): enemies alive at a won fight's end that surrendered, or that lane 2's knock-out
  rule left with the `knocked_out` flag and at least 1 Hit Point. Strongest first.
- **The conversation** (`Captives.conversation`): `narrative/captives/<kind>.dialogue`, by the fight
  (`Captives.BY_FIGHT`), then by the leading captive's stat block (`BY_MONSTER`), else `plain`. Kinds: `vistani`
  (Tser Pool), `wachter` (Lady Wachter's people), `vallaki_watch` (the Baron's watch, when the party sided against
  him), `wardens` (the druids' people at the winery and Yester Hill), `belview` (the abbey's mongrelfolk), `plain`.
- **What the party can do**: question them once (Intimidation or Persuasion; what they say is information only, no
  story flags yet), then let them go, hand them over where there's a watch (Vallaki, Krezk; the Martikovs at the
  winery), or kill them. Companions react through `approve`; the watch pays a small bounty.
- **Spent checks**: a failed social check is spent for good (owner rule, 2026-10-06). Each fight's captives are new
  people, so `Captives.forget_spent` clears the `captives/` files' spent checks before each conversation.
- **Order**: the spoils and any journey under way are held in `LocationFights._after_talk` while the conversation
  runs; `check_flag_encounters`, which runs as a conversation ends, hands them on (`_after_captives`).
- **Voice**: the captives' lines are Narrator lines and stay unvoiced until the voice thread records them with the
  owner's yes.

## Later

- Questioning that opens a codex entry, marks the map or sets story flags read elsewhere, once the regions' writers
  agree which flags a captive may set (setting `yester_hill_known` from a captive would skip Davian's Elvir line).
- Surrender in the Skirmish arena and the balance tool's autopilot (lane 15's file) leaving surrendered foes alone.
