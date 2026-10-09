# Dialogue busts

Date: 2026-10-08 · Improvement Ideas G1, lane 20 (Story presentation). Owner approved the look (two samples, Godrick and
Ireena) and the cast on 2026-10-08.

## What the player sees
In a conversation, large half-body busts stand either side of the dialogue box, behind it: the hero speaking for the
party on the left, facing right, and whoever they're talking to on the right, facing left. The two always face each other
(owner, 2026-10-08): a bust drawn facing the other way is mirrored, unless a line's `[away]` cue turns someone away
(below). The one talking is lit and
the other dims; the Narrator dims both. Each bust breathes slowly (a 1.2% swell from its feet over 2.8 s, the two sides
out of step; off in headless runs and still captures, like all UiMotion). A new speaker's bust fades in. The small
portrait in the box stays as it was, so anyone without a bust still has a face. A cutscene's picture covers the busts.

## The cast
The ten pregen heroes and the 40 NPCs with the most lines (counted from `narrative/` on 2026-10-08: Ireena 186, Strahd
179, Madam Eva 83 ... Urwin 25). Each NPC also has every mood two or more of their lines use (`Speaker [mood]:`): 117
busts in all. Heroes have only their neutral bust: party lines carry no mood. Everyone else keeps their small portrait.

## Art
`tools/art/build_busts.py [--generate] [--moods] [--only id ...] [--sheet out.png]` builds them from
`tools/art/bust_recipes.json`: Gemini (the pinned `gemini-3.1-flash-image`, cartoon style preamble), 2:3 at 1K (about
$0.067 each). The neutral bust comes from the person's turnaround (the six heroes' HD redraws where they exist); each mood
is drawn from that neutral bust with only the expression changed, so the face and clothes match. Takes are kept in
`art/generated/busts/<id>_<mood>_<a, b ...>.png` (not imported, `.gdignore`); `use` picks one by `<id>_<mood>`.

The tool cuts each take out of its plain white background with a flood fill from the edges (the ink outline stops it),
then keys out every pocket of the same flat white that the outline closed off from the edges (inside a horn's curl,
between an arm and the body, between arrows or hair curls; owner report on Kip, 2026-10-08): a near-white region of 40
pixels or more as bright and flat as the background. Whites that belong to the figure and match that test (Morgantha's
smiling teeth) are named in the recipes' `keep_white`; `build_busts.py --recut` cuts every bust again. Then it
erodes a pixel and feathers the edge, and saves `art/busts/<portrait id>.webp` (neutral) or `<id>_<mood>.webp`: WebP with
alpha, quality 90, about 0.15 MB each, in Git LFS, imported with VRAM compression and mipmaps (`tools/art/set_import.py`,
force-add the `.import`).

## Code
- `ui/dialogue/dialogue_busts.gd` (`DialogueBusts`): the two busts, which to show (`path_for`: the mood's bust, else the
  neutral one), lighting and breathing.
- `ui/dialogue/dialogue_ui.gd`: adds it under the box and feeds it each line, with the party's speaker
  (`DialogueRunner.portrait_of(runner.speaker)`) for the left side.

## Facing each other
`data/busts/facing.json` records which way each person's bust was drawn (`left` or `right`, judged by where the face
looks, not the body, on 2026-10-08; a mood's bust faces as its person's unless listed by its own file name). `DialogueBusts.mirrored` flips a
bust (`flip_h`) when its side wants the other way: the left side faces right, the right side faces left. As drawn, the
NPCs face right (the prompt's `{SIDE}` asked for it) and eight of the ten heroes face left, so nearly every bust is
mirrored; Godrick, Hedda, Ireena (her body turns right but her face looks left; UI QA ART-02) and Argynvost face their
side's way as drawn. A new bust needs its facing in the file
(tests/integration/test_bust_facing.gd checks every one). Izek is drawn facing left (redrawn 2026-10-09 with Ashwin's
yes), so he isn't mirrored and his fiendish arm stays his right one.

## Turning away
A line's bracket can hold a turn cue beside its mood (docs/contracts/dialogue.md): `Ireena [sad, away]: ...` turns the
speaker's back on the other side for that line; `Narrator [away]: ...` turns the one being spoken to (the right side),
and `Narrator [away:party]: ...` the party's speaker. A Narrator line's turn holds through more Narrator lines until
that side speaks again; a line without the cue turns the speaker back, and someone new on a side faces the other side.
The bust dips for a moment as it turns (motion on).

Lines cued on 2026-10-08, from a scan of every `.dialogue` file for turning away, backs to the party, looking away and
out of windows:
- abbey_of_st_markovia/abbot.dialogue:93 (the Abbot doesn't look at you), clovin.dialogue:34 (Clovin looks away),
  unveiling.dialogue:169-170 (the Abbot turns to Vasilka and speaks to her)
- argynvostholt/beacon.dialogue:75 (Vladimir turns and goes down the stair)
- strahd/ireena.dialogue:49 (Strahd turns his face from the symbol's light)
- companions/lesson.dialogue:72 (Wren turns his back on Rahadin: away:party)
- castle_ravenloft/spires_pidlwick.dialogue:14, 86, 154 (Pidlwick's back to you; turning to show the keyhole; turning
  to be wound)
- vallaki/victor.dialogue:100 (Victor turns his back), tsolenka_pass/watch.dialogue:104-105 (the watchman never looks
  at you), mount_baratok/mordenkainen.dialogue:64 (his eyes go out of the window), yester_hill/approach.dialogue:81
  (Kostin walks away), lake_zarovich/landing.dialogue:55 (Bluto walks off the jetty)

Left without a cue: camp/thistle.dialogue:14, camp/godrick.dialogue:42 and camp/liriel.dialogue:39 (a hero turns away
in a party-only camp talk; their words come as interjections, which take no cue, and the left bust at that moment may be
someone else), vallaki/aftermath.dialogue:62 (Izek turns away, but the Baron is the bust on screen),
van_richtens_tower/van_richten.dialogue:41 (he looks away from Ezmerelda, not the party) and companions/dawn.dialogue:55
(Liriel turns from the sun to face the windows).

## Faces the story changes
An NPC's data can list `looks` (story/npc_looks.gd, NpcLooks): `[{when, portrait}]`, the first whose dialogue condition
holds wins, else their `portrait`. The id names their small portrait and their bust. Rictavio has one (owner,
2026-10-08): once he admits he is Rudolph van Richten (`flag.rictavio_unmasked`), his portrait, bust and combat HUD
portrait (CombatToken.portrait_id) become `van_richten` (Ashwin's pick B: long grey hair tied back, full beard,
spectacles, a scar, in Rictavio's coat), while his name, his sprite on the map and the board and his stat block stay
Rictavio's. His bust was drawn facing left, so it isn't mirrored; it has no moods yet, so every mood shows it.

