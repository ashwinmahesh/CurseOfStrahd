# Ireena at camp, and the fights she watches (Story Allies Presence Plan, package I4)

Ireena travels with the party as a guest who does not fight (package E3: her NPC says `guest_fights: false`, so fight setup
leaves her out, her figure stands back as a bystander and the Narrator says why once). That is a gift and a grievance, and
this package gives her somewhere to say so: seven talks by the fire, and road lines and Narrator lines that fit someone who
watched.

## The camp talks (`narrative/camp/ireena.dialogue`)

After a Long Rest at camp a guest asks for a word the way a companion does (`CampTalk.who_asks` reads `guest:<npc>`,
docs/story/camp.md, "Guests ask too"): a speech bubble over her, "Ireena wants a word". The file offers the first talk whose
condition holds, one a rest, each once, so the later part of the story comes first:

| Talk | Offered when (she is along, and) | What she says |
|---|---|---|
| `castle_eve` | the party is level 9 and has not been to the castle gates | what she wants done if she is taken: no rescue at the price of the party, and a message for Ismark |
| `amber` | a dark gift was taken in the Amber Temple | she can smell the amber on them; the devil takes, and these were given |
| `pool` | she chose at the Pool of the White Sun (`ireena_pool_choice`) | two openings, promised or stayed, and the same two replies |
| `izek` | Izek was told she is his sister | what a sister owes a brother she does not remember |
| `window` | Strahd stood at her window (any way it ended, but not the churchyard gate) | she does not want to be watched asleep; she is ashamed she wanted to go |
| `burial` | her father is buried | formal and exact about the funeral; a hasty burial has its own line |
| `kept_back` | the party is level 4 | she has watched the fights from behind the line, and asks for sword practice at dawn |

Each ends after one reply to one of two things the party can say. Nothing rolls and nobody is judged; the only thing that
moves is `ireena_trust` (a side flag): up by one when the party takes her seriously, never down. No story flag moves.

## The fights she watches

- **Road lines after a won fight** (`narrative/banter/guest_ireena.dialogue`): `fight_glass` and `fight_father` were written
  when she fought ("it held"; "a terrible prophet") and are redrafted for someone kept back; `fight_count` (she keeps the
  ledger) and `fight_carry` (anything but standing idle) are new; `fight_plainly` stays. Five lines, each once.
- **The Narrator in a fight** (`narrative/narrator/keeps_back.dialogue`, `combat:keeps_back:ireena`): four more for the
  middle of one, beside E3's five: she shouts a warning, calls a name, weighs a stone, holds up the lantern. She never strikes
  and nothing strikes her.

## Lines

61 new or rewritten lines, all unvoiced (the camp talks 53, the road lines 4, the Narrator's 4, in Ireena's and the
Narrator's voices). Drafted by Gemini through the ai-bridge (`docs/plans/gemini_allies/i4/`), edited. The two road lines
that replace older ones (`fight_glass`, `fight_father`) leave their old recordings unused.

## Tests

`tests/unit/test_ireena_camp.gd`: she asks only while she is along and by her first name; each talk waits for its event; they
come one a night, the later story first, each once; the camp offers her bubble beside the companions'; every talk ends after
one reply by either option; trust only moves up, by the table in the test; the pool's two openings; the hasty burial; the file
never says the devil's name and nothing rolls; the road lines; the Narrator's.
