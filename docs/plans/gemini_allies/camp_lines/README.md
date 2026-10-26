# Gemini drafts for the missing camp lines (Resume packages, Allies item 4)

Todo (Next week.md, 2026-10-20): "some party lines during camp are missing their lines". Reading: the Narrator's idle camp lines
(`narrative/narrator/camp.dialogue`, `camp:<id>`, `camp:guest:<npc>`) are keyed by creature, and Hedda, Ilse, Silvain and Tamsin had
none (they fell back to the generic `camp:someone`), nor did Izek (he fell back to `camp:guest`). The other six heroes had their own.

**Found while building it:** Hedda, Ilse, Silvain and Tamsin are the original four, retired from the roster (`data/pregens` `roster: false`,
`CampSite.retired`): in a new game the roster is the six companions, who already had lines, and a retired hero never sits by the fire from
the bench. These four sets therefore only show for an old save with one of them in the party; Izek's is the one a new game hears. If
Ashwin meant something else by "party lines during camp are missing their lines" (the nearest candidate is unvoiced camp talks, see the
hand-off), these twelve lines are still unvoiced and harmless.

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then edited.
Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`, project
`ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id is reported
in the bridge's records.

| File | What it is |
|---|---|
| `brief_1.txt` / `reply_1.reply.txt` | Five candidates for each of the four heroes: three plain and two for the night |
| `brief_2.txt` / `reply_2.reply.txt` | Six candidates for Izek, the guest |
| `brief_3.txt` / `reply_3.reply.txt` | Four more plain candidates for Hedda, after two of her first three repeated another hero's image |
| `*.messages.json` | The bridge's record of each message |

## What was chosen and what was edited

Three lines each (two plain, one `[night]`), as the others have. A camp is made anywhere, so none says anything of the sky, trees or
weather, and none has an `:indoors` or `:town` set of its own.

- **Hedda**: C1 (bandages) and the tallow line from brief 3 (C3, "Stone remembers" is her own phrase), and N1 (the morning prayer whose words come
  out cold). Dropped: her sunburst held to the coals (Liriel holds her holy symbol to the fire), the pot (Ratatouille's), a spark of light in
  her palm (says too much of her secret), pebbles in rows and counting turns (Ilse counts), a satchel she ties with her teeth (the logic did not hold).
- **Ilse**: C1 (forty stones, her company), C2 with "gives the largest piece to the nearest pack" made "hands out the largest piece to whoever
  sits nearest", and N2 with "the wax S" made "the ornate S on it" and "still unbroken" cut (the letter is sealed and signed S in her
  sheet; nothing says it has a wax seal). Dropped: arrows (she carries a greatsword; the arrows were invented) and the watch (spare).
- **Silvain**: C2, C3 and N2. C2's "using a thread of pale blue light to see by" became "by a bead of pale blue light"; N2's "beside the dead
  ash" became "beside the low fire" (the fire may still burn). Dropped C1 (Technically, spare) and N1 (spare).
- **Tamsin**: C1 and C2 (a typo, "TAMSIN", fixed) and N1 (the locket). Dropped C3 (the "open dark" and the exits; he fears one-door rooms) and N2.
- **Izek**: 2 (the carving), 4 (eating last, "tin" made "it") and 6 (awake after the talk dies down, now `[night]`). Dropped 1 and 5
  (they name Ireena: the camp line cannot rely on her being along), 3 (a clumsy knot is Kasimir's craft).

Register and length: none cut; every line is one or two sentences under 35 words. No line states a hero's secret or names a villain.

Structure (mine, nothing to draft): the node names, the `[night]` conditions, the place of each node, the test.
