# Gemini drafts for Gertruda keeping out of fights (Resume packages, Allies item 2)

Rule (Ashwin, 2026-10-18): every new or rewritten line is drafted by Gemini through the ai-bridge on his subscription, then
edited. Method: the packaged service (`~/Documents/ai-bridge/SKILL.md`): discovery by `service.json`, authorized `GET /health`,
project `ai-bridge`, target `gemini`, plain text, no routing; the bridge was already running and was not touched. No model id
is reported in the bridge's records.

| File | What it is |
|---|---|
| `brief_1.txt` / `reply_1.reply.txt` | The first-fight line (three options) and eight regular lines for the Narrator (`combat:keeps_back:gertruda`) |
| `brief_2.txt` / `reply_2.reply.txt` | Six more regular lines, after the first set lost several to canon, with the taken images listed |
| `*.messages.json` | The bridge's record of each message |

Brief 1 said "a sixteen-year-old with four hit points" (the game's commoner has an average of 4); brief 2 dropped the number.

## What was edited after the drafts

Chosen: A1 for the first fight, and nine of the fourteen regular lines.

Canon (checked against our data):

- **A1**: "Nothing in the dark so much as glances her way" became "in the fight" (fights happen in daylight and indoors too).
- **A2, A3, B3, B7 dropped.** A3 had "steel comes out" and "her storybook"; A2 had "every claw and hungry eye" (not every foe has claws
  or hunger); B3 ("hungry gaze slides past") and B7 ("not one raised weapon angles toward") repeat Ireena's two lines for the same image.
- **B4 dropped** ("cold stone", "unbothered": she is frightened, and the place may have no stone).
- **B5**: "Ten paces behind your shoulder" became "Well behind your shoulder" (no distances in numbers, and a fight's squares vary).
- **B6 dropped**: "her worn book of tales" (the storybook is in her room at her mother's house, `data/locations/mad_marys_house.json`).
- **B8**: "the red work begin" became "the first blow fall".
- **C4**: "mud-stained hem" lost "mud-stained" (not every fight is outdoors). **C5 dropped** ("every foe surges past": one foe is a
  fight too, and the image is Ireena's again).

Register and length: none cut; every regular line is one sentence under 15 words and the first is under 30.

Structure (mine, nothing to draft): the `guest_fights: false` flag in `data/npcs/gertruda.json`, the node names and the cooldown
(copied from Ireena's), the contract and deviations rows, the test.
