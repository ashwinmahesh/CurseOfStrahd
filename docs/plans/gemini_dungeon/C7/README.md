# Gemini drafts for package C7 (the main floor and the chapel)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`,
plain text, no routing; one message each, read until `done`. The bridge reports no model id for these turns.

| File | What it is |
|---|---|
| `brief_1.txt` | The Narrator's scenes for the entry dragons (K7), the archers' post and its mirrors (K10, K11), the chapel passage's knights (K14), the king's balcony (K28, K29) and the window below the overlook (K6): tone, style samples, the setting facts each scene may use, 20 labelled beats |
| `raw_reply_1.txt` | Gemini's reply, untouched (45 lines) |
| `messages_1.json` | The bridge's record of the exchange (ids, states) |
| `brief_2.txt` | The gaps: the balcony's location card, its arrival and cleared lines, the window's menu (three options, the first line, the climb back up) and the knights' journal note |
| `raw_reply_2.txt` | Gemini's reply, untouched |
| `messages_2.json` | The bridge's record of the second exchange |
| `brief_3.txt` | The balcony fight's opening line, once tuning had put the count's watchers along the rail (the balcony brief's "two dead in the thrones" was no longer the whole fight) |
| `raw_reply_3.txt` | Gemini's two alternatives, untouched |
| `messages_3.json` | The bridge's record of the third exchange |

The lines live in `narrative/narrator/castle_ravenloft_main_floor.dialogue`, `narrative/castle_ravenloft/entry_dragons.dialogue`
and `narrative/castle_ravenloft/overlook_window.dialogue`, with a few in the maps (`data/locations/castle_ravenloft_chapel_balcony.json`
summary and text, the fights' texts, a codex entry). They are unvoiced; the hand-off lists every one.

## Where each label went

- `entry_dragon_look`: both lines, as the variants of `examine:crg_entry_dragon`. `entry_dragon_rubble`: `examine:crg_entry_rubble`.
- `entry_dragons_wake`: lines 1 to 3 as the scene `entry_dragons:wake`; line 4 is the fight's opening text (below).
- `archers_post_enter`: line 1 is `open:crg_post_door` (the panel swings aside); lines 3 and 2 are the variants of `enter:crg_archers_post`.
- `post_mirror_look`: the variants of `examine:crg_post_mirror`; `post_mirror_turned`: `examine:crg_post_mirror_turned`; `post_rack`: `examine:crg_post_rack`.
- `faith_knights_look`: `examine:crg_faith_knights`; `faith_knights_trick` and `faith_knights_miss`: the Investigation check's success and failure lines.
- `landing_creak`: the variants of `enter:crg_balcony_landing`; `balcony_enter`: of `enter:crg_balcony`; brief 2's `balcony_arrival`:
  of `enter:castle_ravenloft_chapel_balcony`; its `balcony_cleared`: the variants of `enter:crg_balcony` once the dead have fallen.
- `balcony_throne_look`: `examine:crg_balcony_throne`. `window_found`: the variants of `search:crg_overlook_low_window`.
- `window_climb_rope`, `window_climb_bare`, `window_climb_slip` plus brief 2's `window_climb_back`, `window_tomb_landing`: the nodes of
  `overlook_window:start`; the three menu options and the first line are brief 2's `window_menu_*`.
- Brief 2: `balcony_location_summary` and `balcony_location_text` are the location's summary and text; `faith_codex` is the
  journal entry "The Watching Stone Knights".

## What was edited after the draft

- `entry_dragons_wake` line 4, "Four pairs of grey stone eyes fix on your backs, and the things drop from their perches.", became the
  fight's text "Four pairs of stone eyes turn to you, and the little dragons drop from their perches." (the party isn't turned away by
  then, and "the things" gave nothing away).
- `balcony_zombies_rise` (two lines) was replaced, once tuning had put Strahd's spawn along the rail (brief 3), by brief 3's first
  alternative, as drafted: "The two corpses slumped in the high thrones stiffen and rise as you step out onto the gallery. Along the
  rail, pale shapes in the dark turn their heads toward you as one." (the second alternative was not used).
- `window_tomb_landing`: "two white marble coffins" became "two stone coffins": the game's coffins are plain sarcophagi, and the book
  gives them no colour.
- `archers_post_enter` lines 1 to 3 were split across their triggers (a Narrator trigger plays one variant at a time, so a three-line
  scene would have shown one of them); `window_climb_slip` and `window_climb_back` run together as one scene.
- Kept as drafted: everything else, apart from the labelled beats' order. One canon note: Gemini's `post_mirror_look` has the count casting
  no reflection (a vampire's), which the brief offered; "three centuries dead" (the bow racks) follows the household's age.
