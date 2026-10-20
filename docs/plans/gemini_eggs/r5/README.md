# Eggs plan, package R5: the lake, Van Richten's Tower, Berez and Mount Baratok

Built from Part C ("R5") and Part D of the 2026-10-18 easter eggs plan (kept in the owner's vault). Every new line was
drafted by Gemini through the ai-bridge (`brief_*.txt`, raw replies `raw_*.reply.txt`, the bridge's records
`raw_*.messages.json`), then edited by hand. All of them are unvoiced.

## What is where

| Nod | Where | What the player does | Reward |
|---|---|---|---|
| 3b The patient spade, holes 2 and 3 | `data/locations/lake_inlet.json`, `inlet_hummock` at (5, 13), check `inlet_dig` (Athletics DC 10, needs a shovel); `data/locations/berez_marsh_track.json`, `marsh_spade_slab` at (22, 11), check `marsh_dig` (Athletics DC 12, needs a shovel) | Dig | 40 gp, a Potion of Greater Healing and note 2; 60 gp, `pedlars_spade_head` (gear, 25 gp) and note 3 |
| 17 The jar marked DO NOT | `data/locations/van_richtens_tower_interior.json`, check `jar_do_not` on `vrt_jars` (Arcana DC 13) | Look at the jar | Codex "The jar marked DO NOT"; `eggs_jar_seen` |
| 19 The hungry orb | `data/locations/mount_baratok_hut.json`: check `lift_furs` on `baratok_bed` (Investigation DC 15) finds it; `baratok_orb` at (3, 2) shows from then on and opens `narrative/mount_baratok/hungry_orb.dialogue`; feeding it a level 1 spell scroll lights the hearth | Lift the furs; feed the orb | Codex "Chalk on a rag"; Heroic Inspiration for the party |
| 20 A saucer on the sill | `narrative/narrator/berez.dialogue`, a second variant on `examine:baratok_cold_hearth` (and a third once the orb lit it) | Examine the hearth | A smile |
| 31 The meddler with the pipe | `narrative/mount_baratok/mordenkainen.dialogue`, `orb_owner`, on the restored Mordenkainen's menu once the orb is found | Ask whose it is | A laugh |

## Where the plan and the game differ

- The orb is found with Investigation (lifting the furs), and its reward comes from feeding it, not from an Arcana check:
  one check, one scene.
- The saucer is a variant on the hearth's own line rather than a new prop.
- The jar edits `van_richtens_tower_interior.json` and its Narrator file away from every hunk of the unmerged
  `v1-van-richten-tower`, so the two merge cleanly (a merge-tree trial shows no conflict). Its check is offered only
  `when` `not flag.eggs_jar_seen`, which is also what reads the flag until the later achievement does.
- The marsh slab is at (22, 11), not beside the road's random-fight spot at (20, 10): the new props keep two squares from
  every `foe_spots` entry too, not only from a map's fight starts.
- A scroll is never carried as the generic `spell_scroll_level_1` that rewards and shops name; it is always a particular
  spell (`spell_scroll__shield`). So `item:spell_scroll_level_1` in a condition, and `take spell_scroll_level_1`, now mean
  any Spell Scroll of that level (`StoryState.is_scroll_of`, documented in `docs/contracts/dialogue.md`). Without it the
  orb could never be fed. This is the package's one engine touch.
- Patient Spade, the hidden achievement for digging all three holes, is written by R7 (`data/achievements/r7.json`), not
  here: it reads `eggs_spade_first`, which is R1's flag (branch `eggs-r1`), and a package that names a flag that hasn't
  landed fails `make validate`. This package sets holes 2 and 3 (`eggs_spade_second`, `eggs_spade_third`).

## Gemini record

Three briefs, one reply each, sent to the `ai-bridge` project's Gemini target on 2026-10-20 with no model or effort
override. Edits (all shortened): the inlet 1B, 2A, 3A; note 2 4B; the slab 5A, 6A, 7B; note 3 8A. The furs 1A, the chalk
on the cloth moved into the codex; the failure 2A; the orb 3A; the feeding 4A; Mordenkainen 5A (5B named a real place
and was dropped); the saucer 6A. The jar 1A, 2A and 3A.
