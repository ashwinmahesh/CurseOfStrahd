# Gemini drafts for package I1 (Ireena's check-in hub)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription,
then edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): project `ai-bridge`, target `gemini`, plain
text, no routing; the bridge was already running and was not touched. No model id was reported by the bridge. One
conversation, six messages.

| File | What it is |
|---|---|
| `brief_1.txt` | The check-in's logic, her five situations (inn, church, Krezk, mansion, road), the greetings, three stages of her days at each place, the goodbyes and the party's option texts; her voice bible and ten of her existing lines; the canon limits and the format |
| `raw_reply_1.txt` | Gemini's reply, untouched |
| `brief_2.txt` | The first half of the news reactions (15 nodes: the dinner, Strahd's attention, a dark gift, Mordenkainen, Berez, the Sunsword, the Holy Symbol, the Tome, the beacon, the Abbot's four ends) |
| `raw_reply_2.txt` | its reply |
| `brief_3.txt` | The second half (18 nodes: Van Richten and Ezmerelda, the hags, the den, the children, Yester Hill, the wine, Izek, the festival, the bones, the reading) |
| `raw_reply_3.txt` | its reply |
| `brief_4.txt` | Her topics (father by how he was buried, the marks, the dream, Izek, Tatyana at the pool) and their option texts |
| `raw_reply_4.txt` | its reply |
| `brief_5.txt` | Redrafts and two variants the engine needs: Ilya still ill, Krezk after the pool, the Ezmerelda reunion line, the freed children's second line, the Tarokka reading (it repeated a joke already in the game), the marks that have not healed |
| `raw_reply_5.txt` | its reply |
| `brief_6.txt` | Four single lines whose facts I had to keep true in every playthrough: the burial before the windmill, the third road line, the witch's second line, the refused carriage |
| `raw_reply_6.txt` | its reply |
| `messages.json` | The bridge's record of the whole conversation (ids, states), all six messages |

The lines live in `narrative/allies/ireena.dialogue`: 126 spoken lines, all Ireena's, all new and unvoiced, and 13 option
texts (what the party says, from Gemini's option rows; the game does not voice those).

## What was edited after the drafts

Gemini wrote 136 spoken lines; ten were replaced by its own later redrafts (briefs 5 and 6), which leaves the 126 in the
game, and 41 of those went in as written. The rest, grouped:

- **Contractions.** Gemini wrote formally ("I do not", "I cannot", "it is"); Ireena's existing lines are plain and
  contracted ("I'm not made of glass", "Don't argue"). Done in about thirty lines.
- **Canon.** `life_inn_3`: the Martikovs are innkeepers, not "vintners" (the wine is the Wizard of Wines'). Berez: the
  witch killed Marina and let him drown the village (the flag text), she did not drown it "to cure him" and did not
  "butcher" her; "dead in the reeds" and "a marsh full of skulls" were new places and facts, cut. `news_abbot_wedding`:
  "out of a white dress" cut (her figure wears no white dress; the lesson of the chapel package), and the bride is "a bride
  who wasn't me", not "my debt at the castle gate". Den: "a winter", "oak boards" and "the iron latch" are not in our data
  (the siege is a month old in Ismark's bible); "a worse one" for Kiril cut. The beacon's light is not "silver" in our data.
  The dolls are carved by Blinsky for Izek, so "carving my face" became "having my face carved". "My mother's hair" is
  "my first mother's" (Kolyan's wife is "Mother" in her other lines). The festival: "soggy wicker suns", "wet torches" and
  "wooden palisades" were new details, cut. The bones are "in the crypt", not "under the altar stone". The father topic
  says "Father" (she never says "Kolyan" except to others) and "treated him", not "his bones". The dream: "a dark lake",
  and "a white dress I've never owned" (her voice bible has it), not "white silk". The Tatyana topic: "white flowers" (the
  pool scene's words), and "since she was a child", not "twenty years" (Kolyan found her at eight or nine). `life_krezk_1`:
  "the wall", not "the gatehouse wall". `life_mansion_3` and others: tense and "it's".
- **Facts that depend on the playthrough.** `news_hags_abandoned_1` assumed the night's vigil; `life_road_3` claimed
  "something has been pacing us since noon"; `news_berez_dead_2` named a drowned village for a version where she does not
  know the truth; `news_dinner_declined_2` did not parse. All four went back to Gemini (brief 6) and its answers are used,
  trimmed. `mind_bites_1` said the marks had turned into scars (they do not heal); redrafted in brief 5.
- **Option text.** "Let's get moving again while the light holds" became "Let's keep moving" (it must work at night);
  "You've gone quiet. Is something on your mind?" became "Is something on your mind?" (she hasn't gone quiet).
- **Trimmed.** `news_children`'s first line lost "tonight"; `news_reunion` lost "That loud showman" and "the mist" (she
  has no "before the mist"); `news_children_2` lost "tonight"; `life_krezk_2_sick` was one long sentence, now two.

## Structure (mine, nothing to draft)

The greeting plays only at a refuge. The `life` node picks the place from the story's own flags (the inn, St. Andral's,
Krezk, the mansion, the road) and keeps a visit count per place for the stage, so moving her from the inn to the church starts
the church's three stages and does not skip them. The news and the topics are chains of nodes that each check "fewer than
three told so far, the story condition, not told before", so the file's order is "newest first" and a visit tells at most
three. The variants (Ilya well, Krezk after the pool, the Keepers) are conditions on the stage's last line.
