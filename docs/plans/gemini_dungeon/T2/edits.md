# T2: what was kept from Gemini's drafts, and the edits

One brief (brief.md), sent through Ashwin's ai-bridge to Gemini (project ai-bridge, 2026-10-20); the raw reply is
gemini_reply.json (`result`). Three vestiges, fifteen slots each, and three Narrator lines for the vault. Almost everything was
kept as drafted: the lines already had the game's style (no dashes, one or two sentences), each voice is one idea (Zrin-Hala
gusting and loud, Delban cold and clipped, Vaund slippery and answering questions with questions) and each price names exactly
what the gift costs in the data. All 48 lines are new and unvoiced (three new speakers: `vestige_zrin_hala`, `vestige_delban`
and `vestige_vaund`, which the voice thread will cast).

| Slot | Used as | Edit |
|---|---|---|
| T2_ENTER_VAULT, T2_EXAMINE_BREACH | `enter:amber_temple_breached_vault`, `examine:breach_bricks` | "a draft slips from a seam" to "a draught" (the game's spelling); the rest as drafted. |
| T2_FIND_NICHE | `open:breach_niche_door` (the hidden door found) | Kept as drafted. |
| ZRIN_CALL, DELBAN_CALL, VAUND_CALL | the calls (`<id>_call`) | Kept as drafted (at most 28 words, no gift, offer, price, level, save or check: tests/integration/test_amber_calls.gd). |
| ZRIN_FIRST_NARR, DELBAN_FIRST_NARR, VAUND_FIRST_NARR, the three FIRST lines, BACK, WANT, OFFER, PRICE, LID_FAIL, ACCEPT, NOONE, REFUSE | the first hearing, the menu's answers and the endings, as in the other sixteen | Kept as drafted. |
| ZRIN_GIFTED_NARR, DELBAN_GIFTED_NARR, VAUND_GIFTED_NARR | what the amber does when someone with its gift comes near | `{name}` replaced: "as {name} steps near" became "as the one who carries its gift steps near" and the like (the line plays with no hero speaking, so `{name}` would show). |
| ZRIN_LID | `zrin_hala_lid` | "Zrin Hala" to "Zrin-Hala" (the vestige's name, as the book and the data spell it). |
| DELBAN_LID, VAUND_LID | the lids | Kept as drafted. |
| DELBAN_ACCEPT_NARR | `delban_accept` | "The color drains" to "The colour drains". |
| ZRIN_ACCEPT_NARR, VAUND_ACCEPT_NARR | the accept lines | Kept as drafted (`{name}` here is the hero who accepted, as in the other sixteen). |
