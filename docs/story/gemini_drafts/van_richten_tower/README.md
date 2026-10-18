# Gemini drafts for Van Richten's Tower (Dungeon Expansion Plan V1)

Every new or rewritten line in narrative/van_richtens_tower/{the_lift, the_scaffold, the_study}.dialogue, the door's new nodes in
tower.dialogue, the Narrator's new and changed nodes in narrative/narrator/van_richtens_tower.dialogue and the hunter's-tower
quest's `inside` journal entry was drafted by Gemini through Ashwin's ai-bridge (his Google subscription, `agy`, no API key; the
packaged service at 127.0.0.1:8765, project `ai-bridge`), on 2026-10-18. Claude trimmed and canon-checked the drafts.

- `briefN.txt` is what was sent (the shared preamble plus that batch's slots); `replyN.json` is the bridge's message record
  (conversation, state, result) and `replyN.txt` the raw reply text, unedited.
- Brief 1: the door's poses, the ward, the scaffolding, the lift. Brief 2: Van Richten's room (armour, chest, head) and the
  four lantern-room rewrites. Brief 3: the scaffold's two options, the journal entry, the collapse, the dig-out and the antimagic
  ring. Brief 4: four collapse lines redrawn (the island's black wall cannot change, so it stays standing round the pit).
  Reply 4's four slots replace reply 3's.
- The lines in the game are the drafts with these edits (slot -> what changed); every slot not listed is exactly Gemini's text:

  - `WARD_FOUND`: "They hum under your breath, and" -> "They hum faintly, and"
  - `WARD_HIT`: "wet flagstone" -> "wet rock"
  - `WARD_HIT`: "a dozen long throats" -> "long throats"
  - `LIFT_DOWN`: "pay out the iron links link by link" -> "pay out the chains link by link"
  - `STUDY_ENTER`: "Beside the cold brazier, a pair" -> "By the door, a pair"
  - `HEAD_WHAT`: "The old doctor asked" -> "The old hunter asked"
  - `WARD_HIT_3`: "The third spark" -> "The third bolt"
  - `WARD_HIT_3`: "three floors drop" -> "the floors drop"
  - `RUBBLE_LOOK`: "the three rooms have dropped straight down into the cellar pit like nested boxes" -> "the rooms have dropped straight down into a pit like nested boxes"
  - `RUBBLE_NOTES`: "The fallen slate kept" -> "The fallen stone kept"
  - `HEAD_BYE`: "Put the iron back over my eyes" -> "Put the lid back over my eyes"
  - `HEAD_BYE`: "I have waited three winters in this box for someone to remember his manners." -> "I have waited a long while in this box for someone to remember their manners."

- Mechanical, not drafted: the head's option `(Cast Speak with Dead.)` prefix (the pattern of every Speak with Dead
  conversation), the exits' labels ("Stairs up to Van Richten's room", "Stairs down to the lantern room", "Out through the broken
  window to the scaffolding"), prop labels, and the Narrator's `once`/`cooldown` lines.
- Drafted and not used: `LIFT_OPT_RIDE` (the lift's menu opens straight from the platform or the figures), `RUBBLE_ENTER`
  (the dig is on the island, not in a hollow).

All of it stays unvoiced (no `make voice` from a lane): the hand-off names the voiced lines (everything but the option lines,
which are never voiced) for the voice thread.
