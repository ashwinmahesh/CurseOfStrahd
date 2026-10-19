# Gemini drafts for package Z1 (Izek comes for Ireena)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, `GET /health` (version 2,
multi-project), project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not
touched. No model id was reported (`configured_model` and `reported_model` are null in the bridge's records). One conversation,
three messages (the conversation is stopped when the package is handed off).

| File | What it is |
|---|---|
| `brief_1.txt` | The three nights' news (omen, taken, escape) for the three speakers (Urwin, Father Lucian, the Town Guard) and the Narrator's refuge lines: the situation, the nodes, the canon limits, the format, the voice bibles with existing lines |
| `raw_reply_1.txt` | Gemini's reply, untouched: 29 lines and 4 option texts |
| `brief_2.txt` | Izek's room by night and by day: the first sight, the threat, the truth's tail, the fight's lead-in, Ireena alone, the way out. Lists the existing lines it must not repeat |
| `raw_reply_2.txt` | Gemini's reply, untouched: 32 lines and 7 option texts |
| `brief_3.txt` | Izek's room afterwards, two openings (after her escape, after a rescue or a threat); the menu after it already exists |
| `raw_reply_3.txt` | Gemini's reply, untouched: 6 lines |
| `messages_1.json` .. `messages_3.json` | The bridge's record of the conversation (ids, states) after each message |

The lines live in `narrative/allies/izek_takes.dialogue`: 65 new spoken lines (Narrator 15, Ireena 19, Izek 10, Urwin 7, Father
Lucian 7, Town Guard 7) and the party's option texts, all unvoiced. Eleven more lines in the file are copied word for word
from `narrative/vallaki/izek.dialogue` and `narrative/vallaki/ireena.dialogue`, so they keep the voices they have.

## What was edited after the drafts

Canon (checked against our data):

- **Where the chest and the chair are.** Izek's room has a chest of dolls at the wall and a washstand in another corner: "Beside
  the washstand, an open chest" became "Against the wall"; "the bent brass candlestick stands washed upon the basin" (a
  washstand, not a basin) became "has been washed and stood on the washstand". By day Ireena sits "in the chair at its foot".
- **Where Izek sits.** The brief said he sits in front of the door; Gemini read that as outside it. He sits inside, between her
  and the door: the guard's line "he just sits in the chair outside it" became "he just sits there between her and it". Her
  being "in the doorway" (the threat's line) became "Before I change my mind": she is in a chair.
- **Ismark.** "Her brother's post" would read as Izek, so "Ismark's post by the door is empty".
- **Invented numbers and clothes.** "I have counted thirty-four of my own face in that box" has no count in our data: "the
  dolls". Lucian "carried her out in her cloak" (she was in bed): "wrapped in her blanket".

Register and length (cut about 15%):

- Urwin's "If you mean to keep her, don't leave her long" misread the stakes: "I wouldn't leave her alone for long". Lucian
  and the guard lost a "friends" and a "though" ("Forgive me, friends, Izek" was a comma splice); the guard's second taking
  line lost "Just" and "up".
- Izek's second line in the room, "Look at her. She's warm, she has the candle, and nobody is going to touch a hair on her head",
  became short sentences (he is flat). Ireena's second line lost its second [angry] (every line of hers was angry).
- `alone_rescue` lost its second line ("Good. Walk beside me, not around me..."); `freed` lost its second sentence in the
  last line; `room_truth_after`'s "keep your cloak up in the wind" became "wrap up warm"; `after_hold_party` lost "to be sure
  what's left".
- Option texts: "Ireena, are you hurt? Has he harmed you?" lost the second question; "Come with us again. You're safer on the
  road with us." became the existing option's text, "Come with us again.", so the rejoin reads as everywhere else.
- `freed_back`: "At least there they ask my name before they shut the door" meant nothing: "At least there I can bar the door
  from my side."

Structure (mine, nothing to draft):

- The routers (`night`, `omen`, `taken`, `escape`, `omen_speaker`, `taken_who`, `escape_speaker`, `ireena_room`, `after_hold`) and the
  flags each stage sets.
- Eleven lines copied from the old scene so they keep their voices: "You're in my room.", the truth scene's Narrator line and
  Izek's and Ireena's lines (`room_truth`, `room_truth_ok`, `room_truth_ireena`), the failed plea, the failed threat. The brief told
  Gemini not to repeat them.
- `room_threat_fail` and `room_fight` use the old fight (`vallaki/izek:fight`) after Ireena's lead-in; `after_hold_menu` uses the
  old `at_home` menu's option texts and nodes.
- `alone_hurt` is `room_hurt`'s two lines again (the same text, so one recording).
