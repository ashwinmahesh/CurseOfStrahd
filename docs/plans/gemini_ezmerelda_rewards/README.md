# Gemini drafts for Ezmerelda's new Hunter's Ledger payments

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`, plain
text, no routing; the bridge was already running and was not touched. No model id was reported. One message (the bridge
takes at most 16,000 characters, so the facts for each name were trimmed to the first few sentences of the M2 brief's).

| File | What it is |
|---|---|
| `brief_1.txt` | The brief: voice bible, canon limits, format, thirteen names with what each now pays, her opening line, three journal texts |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `messages_1.json` | The bridge's record of the conversation |

Edits after the draft (all in `narrative/allies/ezmerelda.dialogue` and `data/quests/hunters_ledger.json`):
- Canon: `pay_wagon` struck "Iosif from the crossroads" (the wagon is the name, Iosif was only its bait), now "Cross the wagon
  off"; `pay_morgantha` called her "the baker" (now by name); `pay_kiril`'s "the meat with swords who beat Kiril in his own
  den" was garbled and repeated her leg story's territory, now "Kiril is struck from the book at last"; `pay_falls` ended
  "so the next traveller keeps his footing" (not in our facts), now "Spend it on silver."
- Fit: `pay_huntsman`, `pay_khazan`, `pay_lysaga` were two clauses joined with a semicolon, split in two sentences; her opening
  line was split into two sentences; `pay_falls`, `pay_fowlers`, `pay_wint` and `pay_sarkhaza` got small trims.
- Used as drafted: `pay_vine`, `pay_grandsire`, `pay_eye`, the three journal texts.
- Not new wording: the thirteen name-briefing and reaction lines, the milestone gifts and the closing keep their M2 text.
