# Gemini drafts for package I2 (Ireena's errands)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`, plain text, no
routing; the bridge was already running and was not touched (health: version 2, multi-project). No model id was reported by
the bridge. One conversation, seven requests, all answered (none failed, none resent).

| File | What it is |
|---|---|
| `brief_1.txt` | The shared context (Ireena, the vampire's visits, her voice bible and nine of her lines, Ismark's, Kolyan's and the Narrator's voices, the canon limits and the format) and the first errand, the sprig for her father's grave: her ask, the grave scene (Ismark, Kolyan once spoken to), the report back in three answers, her story, the case where he was raised first |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `brief_2.txt` | The three sword lessons (grip and footing, reading an opponent, then the drill or the fall), each with its pass and its miss, Ezmerelda's asides and the party's option texts |
| `raw_reply_2.txt` | its reply |
| `brief_3.txt` | What He Wants With Me: her ask in two voices (before and after the pool), the Tome of Strahd read to her (the item's codex text is the whole canon), Marina's statue and the bier, what she knows at the end, the way to Krezk |
| `raw_reply_3.txt` | its reply |
| `brief_4.txt` | Strahd's three letters to her and her reactions; the third she says she burned, and an Insight roll finds the one she kept (her secret) |
| `raw_reply_4.txt` | its reply |
| `brief_5.txt` | Redrafts of the lines whose facts did not hold in the game (the sprig's ask, Ismark at the grave, Kolyan raised, the first letter written so it is true of a window or a church gate) and the journal text of the two quests |
| `raw_reply_5.txt` | its reply |
| `brief_6.txt`, `raw_reply_6.txt` | The check-in menu's option (it has to fit her "Go on" answer), one line of the ask that mentioned a dream she doesn't have, and the bier |
| `brief_7.txt`, `raw_reply_7.txt` | The statue and the bier once more: the player can't answer her line by line, so each scene opens on one Narrator line that tells what the party tells her, and she only reacts |
| `messages.json` | The bridge's record of the whole conversation (ids, states), all seven requests with their replies |

The lines live in `narrative/allies/ireena_errands.dialogue`: 106 spoken lines (Ireena 67, the Narrator 26, Strahd's letters 7,
Ismark 2, Kolyan 1, Ezmerelda's three asides in the lessons), all new and unvoiced, and 31 option texts (what the party says; the
game does not voice those). Gemini wrote 154 spoken lines over the seven requests, 40 of them redrafts of lines from an
earlier reply (114 distinct); 106 are in the game.

## What was edited after the drafts

- **Contractions.** Gemini wrote formally ("I do not", "I cannot", "it is"); Ireena's existing lines are plain and contracted.
  Done in about sixty lines. Strahd's lines stay formal, as his voice bible has them.
- **Cut for length (about 15%).** Eleven lines out: the second half of the sprig's ask (merged into the third), "Turned earth, a
  plain marker, and dead stalks. Good." (the party had just said it), the second line of the fall ("Tuck the shoulder, keep the hilt
  clear..."), "Don't spare me a line of it" and the merge of the last two lines of the ask after the pool, "He killed his own brother
  for a borrowed coat of youth..." (the Narrator's line above it says as much), the last of the four statue reactions ("he took a whole
  town over it"), the second line of his first letter ("A dutiful daughter keeps inside..."), "Well? Does this one go to the grate
  or the pack?" (the options ask it), the merge of the two answers about what the third letter said, and the last line of the
  confession ("Put that look away now...").
- **Canon.**
  - *The sprig.* "Father's ledger" is Gemini's, kept; "kitchen smoke" kept (it is only a smell). "Timber tariffs" were new canon: now
    "the village accounts". "Council table" and the line about Father doing the same across it: cut.
  - *Ismark.* The first draft had a fence and a ledger desk; the redraft is shovels and swords, and "headstone" is "board" (the grave
    has a board).
  - *Kolyan.* The first Narrator line said the party "called him back" (they cast Speak with Dead); the redraft is "the voice that
    answered your questions". His line lost its [angry] (his portrait has no moods).
  - *The lessons.* "Iron" is "blade" (the practice blade is blunted); "tomorrow" is "another day" (the next check-in may be days off);
    "strike from the dark" cut; "ten minutes" is "half an hour" (a lesson takes half an hour of game time); "five years behind" is "years behind" (a number nobody gave); "against the floor" is "against the
    ground" (the lesson can be out of doors).
  - *The ask after the pool and before it.* The candles that lean toward her (she wasn't there) and "a dream of a high stone room"
    (the dream is a lake) are gone; the first line is Gemini's redraft about people looking at her.
  - *The Tome.* Gemini's "light in his step" for Sergei is the codex's "had everything Strahd lacked"; "wedding morning" is "wedding
    day"; "threw herself into the mist ... shafts" is the codex's "fell to the mists rather than be his, the guards shot him and he
    did not die". The "latch clicks home" image kept.
  - *The statue.* "Drowned village" and "drowned a whole town" cut (Ireena hasn't been told the village was drowned); "headstone" is
    "statue"; the Narrator line that tells what the party tells her had "her own face" for the statue's face, which could be read
    as the statue's own; I added one sentence, "Then you tell her whose face the statue wears." And it is split in two lines (a line
    over sixty words fails `make validate`).
  - *The bier.* The first draft said the scratch was "red and fresh" and that he "did not let the first one finish dying before he came
    looking for me" (the girl died long before Ireena was born); the redraft is the final question and "the next body on a slab", and I
    cut "before her blood went cold" (a guess).
  - *Strahd's letters.* The first draft had him beneath her window and the bolt drawn; the redraft is "called in the dark", true of a
    window or a churchyard gate. The signature "Strahd." at the end of three lines is gone (the seal is the signature, and a voiced
    line would say his name). The third letter "stopped on the road with your invitation" is "came the same night as your invitation"
    (the carriage came for the party, not for her). "Put it with the first" is "keep it somewhere dry" (the first may have been burned).
  - *Quests.* Gemini named the first one "Rosemary for Kolyan" and its hint names the inn, St. Andral's and Krezk; I kept the name and
    added Vallaki to the hints (the reach test wants a place on the travel map). I did not use its stage hint for `asked` as written
    (it was three sentences).
- **Facts that depend on the playthrough.** The sprig is only offered while she shelters; the report has an answer about Ismark only
  if he was at the grave; Kolyan speaks only if he was once asked at the grave; the bier only if the party went down into the vault;
  the Krezk ask only while the rumour of the pool is known. All of that is data in `ireena_errands.dialogue`, none of it Gemini's.
- **Option text.** The check-in's option was "Is there anything you need from us?"; her answer is "Go on", so it is "There is something
  we wanted to speak with you about." (brief 6). Three of the other options are in the party's contracted voice.

## Structure (mine, nothing to draft)

- `prepare` (the last node of the check-in's offer chain) works out what is on offer and sets `ireena_ask_*` (recomputed before every
  menu, read only by `asks`); the check-in's menu shows one option when any is set. `asks` is the sub-menu; the errands end back
  in the check-in's menu or at the end of the conversation.
- The grave prop's dialogue is `allies/ireena_errands:grave`: the sprig laid with the quest at `given`, the old node
  (`village_of_barovia/kolyan:grave`) otherwise.
- Lessons: one try per check-in (`ireena_lesson_tried`, reset in `checkin`), rolled by the best of the party; the Insight lesson is a
  `check` line in the scene, not an option, so a miss spends nothing.
- The Insight option over the third letter has two other answers beside it, and its success moves no quest.
- Flags: 23 new ones in `data/flags/allies_ireena.json`, no story flag set. Three that the finale (F1) will read
  (`ireena_knows_tatyana`, `ireena_kept_letter`, `ireena_secret_shared`) are also read here, only to close the errands once told,
  which is what `make validate` wants of a flag that is set (`ireena_lessons` is a real counter here).
