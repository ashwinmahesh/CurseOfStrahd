# Dialogue busts

Date: 2026-10-08 · Improvement Ideas G1, lane 20 (Story presentation). Owner approved the look (two samples, Godrick and
Ireena) and the cast on 2026-10-08.

## What the player sees
In a conversation, large half-body busts stand either side of the dialogue box, behind it: the hero speaking for the
party on the left, facing right, and whoever they're talking to on the right, facing left. The one talking is lit and
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
erodes a pixel and feathers the edge, and saves `art/busts/<portrait id>.webp` (neutral) or `<id>_<mood>.webp`: WebP with
alpha, quality 90, about 0.15 MB each, in Git LFS, imported with VRAM compression and mipmaps (`tools/art/set_import.py`,
force-add the `.import`).

## Code
- `ui/dialogue/dialogue_busts.gd` (`DialogueBusts`): the two busts, which to show (`path_for`: the mood's bust, else the
  neutral one), lighting and breathing.
- `ui/dialogue/dialogue_ui.gd`: adds it under the box and feeds it each line, with the party's speaker
  (`DialogueRunner.portrait_of(runner.speaker)`) for the left side.
