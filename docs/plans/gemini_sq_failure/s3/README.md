# Package S3: Gemini briefs and raw replies

Package S3 of the Side Quest Failure Plan (docs: the vault's "Side Quest Failure Plan - 2026-10-18.md", Part E) fixes three
quests that could never finish: Escher's Petition after Escher is slain or frightened, A Knight, More or Less after the
beacon, The Last Lesson after Rahadin. Every new spoken or Narrator line and each new journal entry was drafted by
Gemini through Ashwin's ai-bridge (the packaged service, project `ai-bridge`, target `gemini`), then edited here. All of
them are unvoiced.

Each quest has the brief that was sent (`*.brief.txt`), the bridge's message log (`*.messages.json`) and Gemini's raw
reply (`*.reply.txt`). The edits were:

- **Mood tags.** Gemini wrote `Godrick: [sad]`; the game's form is `Speaker [mood]: text` for a named speaker and none
  at all for `interject name:` lines, so Godrick's and Wren's moods are dropped and Escher's kept.
- **Invented canon cut.** Escher "ruin the velvet", Godrick's oiled rag and the ladle "through his belt where it always
  rides", Wren's "threw the first punch ... right in the ribs", the "stopped practicing his steps at night" journal line.
- **Length.** Answers that repeated an image were merged, and Escher's journal entry and Wren's opening were shortened.
- **Facts checked against the data.** Escher's "that thing" for Querreth (the held stage's own journal calls it "it"),
  Godrick's wall and the sword (`ladle_wall_read`, `ladle_sword_shown`), Wren's `wren_rahadin_met` split between the two
  failure stages, and the doorways image (Wren's own line in `talk_rest`).
- **Made to cost something.** The Escher threat line now says what Escher will no longer do (wait on the roof) rather
  than letting the party off with a shrug; Godrick's and Wren's closing lines stay with the loss rather than promising a
  second try.
