# P5 cast art pass: the earlier regions' last NPCs, and three fixes from P4

Date: 2026-10-06 · Model: `gemini-3.1-flash-image` through `tools/art/generate.sh` and `tools/art/anim_keyframes.py`
(102 images: 13 turnarounds, 23 portraits, 66 attack strips, all in `art/generation_log.jsonl`; at most 2 calls at a time;
no fallback model, nothing downloaded) ·
Per-asset prompts and notes: `art/manifest.json` · Attacks: `art/anim/animations.json`.

## New characters (turnaround, walk + attack sheets, portraits)

| id | look | portraits | sprite flags | suggested `CombatToken.HEIGHTS` |
|---|---|---|---|---|
| alenka | eldest Vistana: crimson velvet bodice, black skirt with a crimson and gold hem, gold-fringed shawl, far too much silver | neutral (knowing), `smile` | none | 1.25 |
| mirabel | middle Vistana: plum bodice, candle-orange sash, plum and mustard skirts, loose curls | neutral (amused), `sly` | `SAT=1.3` | 1.22 |
| sorvia | youngest Vistana: moonlit-blue headscarf and skirt, navy bodice, bone apron with hands and stars, braids | neutral (earnest), `sad` | `SAT=1.3` | 1.15 |
| arik | grey, flat, empty-eyed barkeep: grey shirt, wine-red waistcoat, long bone apron, rag, pewter cup | neutral (blank), `weary` | `SAT=1.3` | 1.25 |
| doru | the priest's son as a vampire spawn: short brown hair, grey-lilac skin, red eyes, torn blood-stained blue quilted jacket, empty scabbard | neutral (pleading), `angry` | none | 1.22 |
| gustav_durst | ghast host: grey-lilac skin, frost-blue eyes, faded midnight-blue frock coat, cravat | neutral (courteous), `smile` | none | 1.3 |
| elisabeth_durst | ghoul: grey skin, frost-blue eyes, high bun with a silver comb, plum gown with black lace and a cameo | neutral (contempt), `sly` | `SAT=1.6` | 1.25 |
| durst_nursemaid | specter of a servant woman: frost-blue and moonlit-blue, frilled cap, grey-blue apron, hands cupped round no baby, skirt tapering to a wisp | neutral (worried), `sad` | `BODY=float` | 1.2 |
| lorghoth | towering heap of rotting rushes, mould, bile-green rot, cult-robe scraps, bones and candle stubs, a gaping mouth | neutral only | `BODY=lumber` | 1.9 |
| cult_shades | one robed shadow for the group: near-black violet hooded robe fraying into wisps, blood-red cord, two lilac eyes | neutral (chanting), `angry` | `BODY=float` | 1.3 |

- Moods: the tag each one's dialogue uses most (Alenka 4 `[smile]`, Mirabel 4 `[sly]`, Elisabeth 2 `[sly]`, the nursemaid
  4 `[sad]`). Ties: Doru 3 `[sad]`/3 `[angry]` → angry (the hunger, the one least like his pleading base); Gustav
  2 `[smile]`/2 `[sad]` → smile (the host); Sorvia 1/1 → sad (her secret). No tags: Arik → weary (barely different
  from his blank base, on purpose), the shades → angry (the refusal). Lorghoth has no lines, so only a base portrait.
- The Dursts are a ghast and a ghoul in their data, not ghosts, so they are solid, with the ghostly tint the family
  shares: grey-lilac skin, small frost-blue eyes, cold faded colours. The nursemaid and the shades are the see-through
  kind (frost-blue like the specter sheet; living shadow) and float (`BODY=float`).
- Doru has his own sheet now; `vampire_spawn` (drawn as a generic spawn) stays the monster's.
- Files follow P4: `art/generated/characters/<id>_turnaround.png` → `art/sprites/<id>/walk.png`/`.tres` and `attack.png`/`.tres`
  (`make sprite`, then `make anims ONLY=<id> GENERATE=1`); `art/generated/portraits/<id>[_<mood>]_portrait.png` →
  `art/portraits/<id>[_<mood>].png` (`make portrait … BG=ash_violet`). The NPC files already pointed at these ids.

## Fixes from the P4 notes

| Note | Fix |
|---|---|
| Gunther's green tunic reads grey | The tunic was a low-chroma green the quantizer keeps on the grey ramp, and no `SAT` fixed it. The turnaround was redrawn from the old one (`--ref`) with only the tunic changed to a clear moss green (`gunther_arasek_turnaround_v2.png`); walk sheet, all five attack strips and both portraits redone from it (portraits also from the old ones, so the face and smile stay). It now reads green, a little bright (moss and sickly). |
| Stanimir's fiddle missing in the side view | Redrawn from the old turnaround with the fiddle and bow in his right hand, visible in all five views (`stanimir_turnaround_v2.png`), `SAT=1.3` as before; walk sheet and attack strips redone; his attack's wind-up now moves the fiddle to the left hand. Portraits unchanged. |
| Ireena's dress has blue patches | A re-render only: `SAT=1.3` (now in her `sprite_flags`) turns the dress into one dusky blue on the walk and attack sheets. Her portraits are unchanged: the sources paint the dress blue-grey and candle-tan, and `SAT=1.3` there made it patchier and streaked her hair crimson. |

Also: `data/npcs/mists_wolves.json` pointed its portrait at `mists_wolves`, which has no art (its sprite already
uses `wolf`); it now uses the `wolf` portrait. `tools/art/check_npc_art.py` lists none of the earlier regions' NPCs any
more; what it still lists are later regions' NPCs that other passes are adding.

## Quantizer notes (for the next pass)

- Dusty mauves and faded wine reds have no palette neighbour of their own and snap to rust, leather or umber.
  Elisabeth's first gown (faded wine red) went rust brown at `SAT` 1.0 and 1.3, patchy red and brown at 1.6 and loud
  crimson at 2.0, so she was redrawn in plum, which needs `SAT=1.6` on the walk sheet (brown at 1.0, patchy at 1.3). Ask Gemini for saturated purples and reds, not dusty ones.
- The opposite case: grey-lilac undead skin in a portrait is just chromatic enough to snap to bright lilac.
  `SAT=0.65` (a desaturation; `cutout.saturate` takes k < 1) keeps Elisabeth's face grey while her violet gown holds.
- Gemini's filter (`PROHIBITED_CONTENT`, no image) refused Mirabel's base portrait six times before the same prompt went
  through; Alenka's and Sorvia's, worded the same way, passed first time. Refusals are not logged (only images are).

## Not right yet (for art QA)

- Mirabel's draped plum overskirt snaps to tan/leather on the sheet (the bodice and lower skirt stay purple).
- Arik's skin reads grey, which suits a man with no soul but makes him look half-undead next to the Dursts.
- Sorvia's sad portrait (`SAT=1.3`, so the headscarf stays blue like her base) has a small orange patch on the chin.
- Elisabeth's portrait face is mottled pewter and silver after `SAT=0.65`: reads as dead skin, but noisier than the rest.
- Gunther's new green is brighter than the "dark green" the P4 prompt asked for, and his attack strips drew it darker,
  so a few strike frames (E and W) snap back to grey.
- Lorghoth's five views stand close together (the cut found all five). Its strike strips draw it slumped into a low
  heap, so the slam reads as the mound collapsing forward.
- Gustav's back-view wind-up frames keep a few loose pixels under his feet, and his coat shows a red lining in the N
  strike (Gemini's addition).
- The six attack strips `render_attack.py --check` flagged (Alenka front34 and back, Arik front34, Mirabel side,
  Sorvia back, the shades' back) were redrawn once by `make anims` and then passed.

## Capture

`make capture SCENE=res://tools/art/preview/character_preview.tscn NAME=p5_cast FRAMES=30
ARGS="--ids=alenka,sorvia,arik,doru,gustav_durst,elisabeth_durst,durst_nursemaid,cult_shades"` →
`captures/p5_cast_lineup.png`, `_walk.png`, `_close.png` (Doru, Gustav, Elisabeth). Eight is what the line-up fits
across the frame; Mirabel, Lorghoth and the three fixed sheets were checked on their sheets only. The preview stands
every one of them at its default 1.25 (the table's heights are not in `CombatToken.HEIGHTS` yet: world/ is the lead's).
Everything reads on the cobbles under the palette pass, the shades included; Elisabeth's gown is the most saturated
thing in the line-up.
