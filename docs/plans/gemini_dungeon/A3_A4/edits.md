# A3 and A4: what was kept from Gemini's drafts, and the edits

One brief for both packages (brief.md), sent through Ashwin's ai-bridge to Gemini (project ai-bridge, 2026-10-20); the raw reply
is gemini_reply.json (`result`). A second one-slot brief (brief_more.md, gemini_reply_more.json) asked for the round table's
empty-room line once the knights have gone. Edits were for length, the game's style (no dashes, British spelling, the
Narrator's one or two sentences) and canon (nothing says which way the knights left). Every line is new and unvoiced. 31 lines: 27 Narrator lines, 3 in the round-table knights' talk and the hallway fight's text (one more, the gargoyle's line once the beacon is lit, is ours, not Gemini's).

## The Narrator (narrative/narrator/argynvostholt.dialogue)

| Slot | Used as | Edit |
|---|---|---|
| A3_ENTER_FLOOR | `enter:argynvostholt_third` | Kept as drafted. |
| A3_ENTER_HALL | `enter:holt_trapped_hall` | "their iron latches" to "their latches"; "The floorboards ... do not creak beneath" to "The boards ... don't creak under". |
| A3_HALL_OATH | the same trigger's variant for a party the knights spare (the oath, Godfrey's word or Godfrey) | "lean through the closed oak doors, fixing you with" to "lean out through the shut doors and look at you with"; "they find it in you" to "they find it". |
| A3_FIGHT_TEXT | `trapped_hall` encounter `text` | "Stone slabs grind" to "Stone grinds". |
| A3_ENTER_QUARTERS | `enter:holt_quarters_west` and `_east` | "flanked by empty armour stands at attention" to "between empty armour stands"; "folded with military precision under a finger's breadth" to "folded square under a finger's depth". |
| A3_ENTER_PASSAGE | `enter:holt_upper_passage` | "stretches eastward" to "runs east". |
| A3_ENTER_COLLAPSE | `enter:holt_collapsed_ceiling` | Cut to one sentence ("and the sky looks straight in"); the rain patter was dropped (the wing has no weather indoors). |
| A3_ENTER_AUDIENCE | `enter:holt_audience_hall` | "lost in the draughts under the roof" to "lost in the dark under the roof"; the comma before "a great stone chair" cut. |
| A3_EXAMINE_THRONE | `examine:holt_dragon_throne` | "wide enough for a beast, facing" to "wide enough for a beast and faces". |
| A3_ENTER_ROUND_TABLE | `enter:holt_round_table`, the variant while the knights are there | "circular" to "round"; "their hands" to "hands"; "None of them breathe ... look up as you enter" to "None of them breathes, and none of them looks up". |
| A3_ROUND_TABLE_EMPTY | the same trigger's variant once they have gone | "their legs having scraped clean grooves through a century of ash" to "their legs leaving clean tracks in the old ash"; "around" to "round". |
| A3_EXAMINE_TABLE | `examine:holt_round_table` | Kept as drafted. |
| A3_KNIGHT_LOOK | `round_table` (the knights' conversation) | "Beneath the visor" to "Behind the visor"; "slightly" to "a little". |
| A3_KNIGHT_SAYS | `round_table` | Kept as drafted. |
| A3_KNIGHT_ASK | the option in `round_table` | Kept as drafted. |
| A3_KNIGHT_ANSWER | `round_table_word` | "come down the stair" to "come up the stair" (they wait on the third floor; the stair they would come up from is the one from below). |
| A3_ENTER_CLOSET | `enter:holt_surcoat_closet` | Kept as drafted. |
| A3_ENTER_VAULT | `enter:holt_dragon_vault` | "Behind the pivoting stone" to "Behind the stone that turned"; "emptied this room" to "emptied it". |
| A3_SEARCH_VAULT | `search:holt_vault_flagstone` | "You run your fingers along the base of the back wall, where a loose flagstone tilts beneath your hand" to "Along the foot of the back wall a loose flagstone tilts under your hand"; "gritty hollow underneath" to "grit beneath it". |
| A3_ENTER_GALLERY | `enter:holt_upstairs_gallery` | "lancet" cut; "Dust motes drift through the dim, coloured light that stains the floorboards" to "Dust drifts through the dim coloured light on the floorboards". |
| A3_EXAMINE_WINDOWS | `examine:holt_stained_windows` | "In cracked glass, a silver dragon spreads its wings above" to "In the cracked glass a silver dragon spreads its wings over"; "an iron tower" to "a tower"; "lead cames" to "lead". |
| A3_ENTER_BEDROOM | `enter:holt_dragon_bedroom` | "This wide chamber holds no tapestries or hearth rug, only" to "No tapestries here and no hearth rug: only"; "and summer rain" to ", and of summer rain". |
| A3_EXAMINE_SHELVES | `examine:holt_empty_shelves` | "the places where" to "where". |
| A4_ENTER_ROOF | `enter:argynvostholt_roof` | "the round stone shaft of the beacon tower" to "the beacon tower". |
| A4_EXAMINE_GARGOYLE | `examine:holt_roof_gargoyle` | "the gale" to "the wind"; "If you listen too long, the hollow note" to "Listen too long and the hollow note". Its second variant (the beacon lit) is ours. |
| A4_EXAMINE_BALLISTA | `examine:holt_old_ballista` | "The great bow of ash wood" to "The great bow"; "its thick hemp cords" to "its cords"; "has turned" to "has gone". |
| A4_EXAMINE_BROKEN | `examine:holt_broken_ballista` | "point backward at" to "point back at"; "masonry" to "stone". |
| A4_EXAMINE_EDGE | `examine:holt_roof_edge` | "the slick slate lip" to "the slick lip of slate"; "jagged rocks of the ridge" to "rocks of the ridge". |
| A4_EXAMINE_HOLE | `examine:holt_roof_hole` | "the flooded passage" to "the passage"; "rainwater" to "water". |
| A4_EXAMINE_TURRET | `examine:holt_roof_turret` | "round stone turret" to "round turret"; "a sea of grey fog" to "grey fog". |
