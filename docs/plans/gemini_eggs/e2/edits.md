# E2: the stubborn lock's two Narrator lines

Drafted by Gemini through Ashwin's ai-bridge (service v2.0.0, project `ai-bridge`, target `gemini`, 2026-10-18, his
subscription, no API key). `brief.md` is what was sent, `reply.json` the bridge's whole record of the exchange (brief,
reply, state) and `reply.txt` Gemini's reply verbatim. Nothing is voiced: the two lines are named in the hand-off for the
voice thread (neither holds `{name}`, so both can be).

The brief names no game, studio or character: it describes the wink ("failing the same lockpick again and again") and
says to allude to the feeling through the lock's own character. The reply contains no outside name either.

The game's file is `narrative/narrator/death_house.dialogue`, beside `check:unlock:success|failure`, in two nodes
(`check:unlock:stubborn`, `check:unlock:at_last`), each with the node-level `once`.

## What was kept and what was cut

| Key | Gemini's | Final | Why |
|---|---|---|---|
| stubborn | S3 "Deep in the grease and rust, a heavy tumbler settles back with the smug click of a host who has decided you are staying for dinner." | "Deep in the rust, a heavy tumbler settles back with the smug click of a host who has decided you are staying for supper." | The one that says "enjoying itself" outright (a host's smugness) and is a joke on the lock, not the player. Cut "grease and" (a new lock isn't greasy; 21 words, down from 25). "Dinner" became "supper": the dinner is Strahd's, a plot beat. |
| at_last | A1 "The bolt slides back with a long, rusted scrape, like an old guard stepping aside now that the formality of refusal has been properly observed." | "The bolt slides back with a long rusted scrape, like an old guard stepping aside once the formality of refusal has been observed." | The dignity the plan asks for: a guard who held out as long as honour required. Cut "properly" and the comma; "now that" became "once" (23 words, down from 26). |

Left out: S1 ("the keyhole knows your rhythm better than you do": a jab at the player, which the Narrator's rule 3 forbids),
S2 ("{name}'s breath" frost: odd, and it would not be voiceable), A2 ("Having made its point to the cold dark": the second
sentence repeats the first's idea) and A3 ("Even cold iron eventually grows tired of keeping the same company": it reads
as the lock sulking, not giving with dignity).

Checks: neither line names a place, a person, a tool or a game; no game terms (no "try", "roll", "fail"); second
sentence turn is the lock's, never the player's. Both carry `[not (visited:death_house_ground and not flag.death_house_completed)]`
so neither plays inside the Death House (the Narrator's rule 7: the scariest places keep their humour thin; the house's own
lock lines stay as they were).
