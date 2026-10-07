# Story cutscenes

Date: 2026-10-07 · Improvement Ideas G4, lane 20 (Story presentation).

## What earns one
Owner rule (2026-10-07): a cutscene shows, faithfully, anything the game's own views can't display accurately. The
map and the fights draw small cartoon figures in a lit diorama; they can't show Strahd sitting his black horse up on a
ridge, the whole valley from a crag, a reveal on a castle's scale. Those moments get a full-screen still picture that
shows exactly what is happening. No motion is needed: the picture fades up out of black and closes in very slowly on
its focus, which is enough to make a still feel alive.

## Data
`data/cutscenes/<id>.json` (schema `cutscene.schema.json`, read by `story/cutscenes.gd`):
- `title`, `summary`: our own words.
- `images`: the picture's takes, `{image, when}`, first match wins. `image` is `art/cutscenes/<image>.png`; `when` is
  a dialogue condition (`guest:ireena`, `flag.x`, empty for always). When no take holds, the cutscene is skipped and
  the scene plays as before. So a picture that shows Ireena carries `"when": "guest:ireena"`, and a second take
  without her can follow it.
- `focus`: where the slow push-in closes on, as a share of the picture's width and height (default the centre).
- `trigger` (places only): a Narrator key (`examine:bonegrinder_lookout`). Looking at that thing while exploring
  shows the picture with the narrator's line as its caption, instead of the line in the HUD's box.

`make validate` checks every picture exists, every trigger is a node in a `narrative/narrator/` file, and every
`cutscene <id>` in a conversation names a cutscene.

## In a conversation
`cutscene <id>` (docs/contracts/dialogue.md) puts the picture under the conversation. The lines that follow read as
captions on it: the narrator in the book's italic, anyone else with their name above their words, each still voiced
(ADR 0013) and kept in the History (H). Options, checks and notices bring the dialogue box back up over the picture.
`cutscene end`, or the conversation ending, takes it away. Another `cutscene <id>` fades to the next picture.

Example, the rider on the ridge (`narrative/strahd/visits.dialogue ~ watcher`):

```
~ watcher
appear strahd
set strahd_watcher_seen
cutscene strahd_watcher
Narrator: The road bends under a bare ridge. ...
```

## Controls
- A click, Space or Enter: the next caption (past the last one in a place's cutscene, it closes).
- Skip (top right): a conversation's captions go by unread up to the next choice, note or the end (they stay in the
  History); a place's cutscene closes.
- Esc: pauses, with Resume and Skip the scene. Esc again resumes. Nothing else moves on while it's paused.

## Code
- `story/cutscenes.gd` (`Cutscenes`): the data, the picture for the story now (`image`), `focus`, `for_trigger`.
- `ui/cutscene/cutscene_view.gd` (`CutsceneView`): the picture, its fade and push-in, the caption, Skip and the pause
  card. Motion is off in headless runs and still captures (UiMotion).
- `ui/cutscene/cutscene_player.gd` (`CutscenePlayer`): a place's cutscene while exploring, opened by
  `world/game_root.gd play_cutscene` from `LocationView.cutscene_requested`. It stands in as the open screen, so
  nothing in the world moves under it.
- `ui/dialogue/dialogue_ui.gd`: the `cutscene` beat, captions and Skip in a conversation.

## Art
Gemini (`gemini-3.1-flash-image`) through `tools/art/generate_gemini.py` with `--preamble
art/prompts/cutscene_preamble.txt --aspect 16:9 --size 2K` (2752x1536, about $0.10 a picture), and the cast's
turnarounds from `art/generated/characters/` as `--ref` so faces and clothes match the sprites. The party is drawn
hooded or from behind, since the player makes their own heroes. Takes are kept in `art/generated/cutscenes/`; the
chosen one is copied to `art/cutscenes/<image>.png` (Git LFS) with VRAM compression and mipmaps
(`tools/art/set_import.py`, force-add its `.import`). Each picture's prompt is recorded in `art/manifest.json`.

| Cutscene | Plays | Picture |
|---|---|---|
| strahd_watcher | The first journey out with Ireena (strahd/visits:watcher) | Strahd on his black horse on a ridge above the road, the hooded party and Ireena below |
