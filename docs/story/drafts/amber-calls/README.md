# The sarcophagi's calls: Gemini drafts (owner rule, 2026-10-18)

Each of the Amber Temple's sixteen vestiges calls to the party once, as it comes near and before anyone touches the
amber (Ashwin, 2026-10-18: "the sarcophagi speaking to the players, before we interact with them, like the description
says"). Sixteen short lines and one Narrator opener, drafted by Gemini through the ai-bridge, then edited for the voice
and for canon.

- `calls_brief.md`: the brief (setting, rules, the sixteen vestiges with their existing first-hearing lines for canon).
- `calls_reply_raw.json`: the bridge's record; Gemini's raw reply is in `message.result`.
- `calls_final.md`: every line as drafted and as it is in the game, with every edit and why.

How it plays: a prop entry's `approach: 3`, `call` and `call_when` (data/locations/amber_temple_faceless_god.json and
amber_temple_vault.json); `LocationNpcs._check_calls` starts the `~ <name>_call` node (narrative/amber_temple/
vestiges.dialogue) once a game when the leader comes within three squares and sees the block, unless the temple is
sealed, that vestige was already talked to, or its gift is taken. The first call of the game also plays the Narrator's
opener (flag `amber_calls_begun`). The book's own description of the voices could not be read here (no copy of the book
in the repository), so the calls are in the game's retelling of them, not its words.

All seventeen lines are unvoiced (no `make voice` from a lane).
