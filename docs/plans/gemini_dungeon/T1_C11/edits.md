# T1 and C11: what was kept from Gemini's drafts, and the edits

One brief for both packages (brief.md), sent through Ashwin's ai-bridge to Gemini (project ai-bridge, 2026-10-20); the raw
reply is gemini_reply.json (`result`). Edits were for length, the game's style (no dashes, the Narrator's one or two
sentences) and canon (Vosk never owns the ambush outright).

## T1: the ambush under the faceless god

| Slot | Used as | Edit |
|---|---|---|
| T1_FIGHT_TEXT | `statue_ambush` text | Cut to two short sentences; "inside the statue's empty hood" became "at the god's head" (the shape stands behind the statue, not in it). |
| T1_WITHDRAW_SAY | the withdraw's `say` (Vosk) | The dash became a full stop; "when you are ready to discuss terms" cut to his pet phrase "Do come and find me". |
| T1_VOSK_KNOWS | vosk.dialogue `start`, after `statue_shape_withdrew` | Two sentences joined with a semicolon; "prospective" and "before we sit down to business" cut. |
| T1_VOSK_KNOWS_ALT | not used | "I had to see from above" owns the ambush outright. |
| T1_ENTER_GALLERY | `enter:arrow_slit_gallery` | Turned into "A cramped stone gallery, smelling of ..."; "blackened with fresh scorch marks" to "ringed with". |
| T1_ENTER_GALLERY_AFTER | its `[flag.statue_ambush_fought]` variant | Shortened; the skulls aren't said to lie in the gallery (they fly out to fight). |
| T1_EXAMINE_SLIT | `examine:arrow_slit` | "below you" became "before you" (the gallery is level with the hall). |
| T1_OPEN_RACK | not used | Written for the Staff of Frost, which the Tsolenka Pass already holds. |
| T1_OPEN_RACK_2 | `open:wardens_stave_rack` | From the second brief (brief_rack.md, gemini_reply_rack.json), for the scroll and the potion: "bites the skin with unmelting rime and holds" to "rimed with frost that never melts, with ... inside"; "pale, bitter draught that numbs the flesh" to "something bitter that numbs the skin". |
| T1_BANTER | not used | Left out: no banter node was needed. |

## C11: the guardians' curtain

| Slot | Used as | Edit |
|---|---|---|
| C11_ENTER_HALL | `enter:cat_guardians_hall` | "cold stone stair" to "stair hall"; the hum moved to the end. |
| C11_EXAMINE_KNIGHT | `examine:cat_bronze_knight` | "Green verdigris" to "Verdigris"; "the weight of what you carry" to "what you carry". |
| C11_EXAMINE_CURTAIN | `examine:cat_light_curtain` | "pale blue light" to "light"; "or the draught from the stairs" cut. |
| C11_WORTHY | guardians_curtain `above` (no gift) | "your skin" and "by a hair's breadth" cut. |
| C11_TURNED_BACK | guardians_curtain `above` (a gift) | "closes round your eyes like a sudden freeze, stealing" to "closes round you like a sudden frost and swallows". |
| C11_FROM_BELOW | guardians_curtain `below` | "Rising from the tomb below" cut; "not what climbs out of it" cut. |
| C11_LOCKED | the ward's `locked_text` | Rewritten for a ward that won't open rather than a second turning back: "The cold light closes where you touch it, and will not let you down." |
