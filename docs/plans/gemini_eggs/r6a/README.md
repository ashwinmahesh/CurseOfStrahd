# Eggs plan, package R6a: companions at camp, on the road and in dreams

Built from Part C ("R6a") and Part D of the 2026-10-18 easter eggs plan (kept in the owner's vault). Every new line was
drafted by Gemini through the ai-bridge (`brief_*.txt`, raw replies `raw_*.reply.txt`, the bridge's records
`raw_*.messages.json`), then edited by hand. All of them are unvoiced.

## What is where

| Nod | Where | What the player does | Reward |
|---|---|---|---|
| 5b Thistle and the bear | `narrative/camp/thistle.dialogue`, `talk_bujor`, once The Dancing Bear is done | Hear her out | approval thistle +1 for two of the three answers |
| 11 Wren's unfinished song | `narrative/camp/wren.dialogue`, `talk_song`, any camp from Vallaki on; three lines, each hopeful, grim or silly (`eggs_song_1..3`); `rest:long:vallaki_blue_water_inn` in `narrative/narrator/nights.dialogue` gains a `[once]` line | Finish the verse | approval wren +2; Heroic Inspiration for the party; Encore (`data/achievements/r6a.json`) |
| 12 Quillon's colleague in red | `narrative/camp/kip.dialogue`, `quillon_rivals`, one more question at his first call | Ask whether there are others like him | A laugh |
| 18 Something behind the eye | `narrative/camp/ratatoille.dialogue` (and `silvain.dialogue` when Ratatouille isn't along), `talk_eye`, after the reedy inlet or the Berez marsh; Medicine DC 10 | Look under the lid | approval +1; `eggs_eye_checked`, part three of the sky-man |
| S3 "You threw a chair at it" | `narrative/banter/party_six.dialogue`, `ilse_wren_chair` and `godrick_liriel_chair`, once `eggs_threw_furniture` (E1) is set | Throw a chair in a fight | A laugh |
| 28 The hottest heart | `narrative/banter/party_six.dialogue`, `godrick_thistle_heart` | Walk with Godrick and Thistle | Warmth |
| 21 The visitor with a borrowed face | `narrative/narrator/nights.dialogue`, a `[once]` variant of `dream:amber_temple` once a dark gift is taken | Sleep at the Amber Temple | No joke |

## Where the plan and the game differ

- Quillon's question goes in his first call at the fire, which lives in `narrative/camp/kip.dialogue` (`quillon_rivals`),
  not in `narrative/companions/fine_print.dialogue`.
- Silvain gets the eye talk when Ratatouille isn't along, but no approval: he is a hero, not one of the six companions
  `approve` knows, and `make validate` refuses it. Ratatouille's comfort answer earns +1.
- The eye talk's callback to Van Richten's jar reads `visited:van_richtens_tower_interior`, not R5's flag
  `eggs_jar_seen`, so R6a validates and plays without R5 (a package may not name a flag that hasn't landed).
- Both new camp menus keep a way out as the last option: "Leave it for now" in the eye talk (a failed Medicine check
  loops back to the menu, so a try can be repeated) and "Not tonight, Wren" at the first line of the song. A camp talk
  plays once, so leaving it forfeits it.
- Thistle's opening line says "Bujor", not "Big Bujor": she calls Godrick "Big".
- The inn's night line and the dream use E2's `[once]` variant prefix.

## Gemini record

Four briefs; this package uses the first three replies (the fourth is R6b's), sent to the `ai-bridge` project's Gemini
target on 2026-10-20 with no model or effort override. Edits (all shortened): Thistle 1B, the HOME 2A and WOODS 2B lines,
3B, the tease A, lucky A, promise B. Wren's ask A; the lyrics as written, with "outlast the blight" for the grim third
line; the singing and after lines from A and B; the inn A. Ratatouille A with "begin to sprout"; Silvain A; the leech
WIN-A; the failures A; the hairpin B (Ratatouille) and A (Silvain); tease A; comfort A. Quillon A, Kip from B. The
banter B1-A (Ilse's count shortened), B2-B, B3-A. The dream A.
