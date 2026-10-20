# Eggs plan, package R2: Tser Pool and the Svalich road

Built from Part C ("R2") and Part D of the 2026-10-18 easter eggs plan (kept in the owner's vault). Six winks, all
hidden where the player has to look, none in a serious scene, none moving a main flag. Every new line was drafted by
Gemini through the ai-bridge (`brief_*.txt`, raw replies `raw_*.reply.txt`, the bridge's records `raw_*.messages.json`),
then edited by hand for length, canon and the Narrator's rules. All of them are unvoiced.

## What is where

| Nod | Where | What the player does | Reward |
|---|---|---|---|
| 2 The Tser Pool dog | `narrative/svalich_road/tser_camp.dialogue`, `dog_pet` | Pet the dog | `eggs_dog_tser`, one of the five good-dog marks |
| 4 The owlbear at Tser Pool | New NPC `tser_owl` (`data/npcs/tser_owl.json`, the existing owl sprite, portrait and stat block) at (31, 15) beside the stage, talking through `tser_camp:owl`; Animal Handling DC 12 eases the cap off; Speak with Animals has its say | Look at it, take its cap off, talk to it | approval thistle +1, wren +1; a laugh |
| 5a Bujor's admirer | `narrative/svalich_road/the_dancing_bear.dialogue`, `thanks`: an `interject class:druid` and Lavinia's reply, in both endings | Finish The Dancing Bear with a druid along | A laugh |
| 6 Fennimore's research assistant | `narrative/svalich_road/fennimore.dialogue`, `pocket` (Speak with Animals for its view) | Ask what's moving in his coat | A laugh; a Wren interject |
| 7 The other fellow's guide | `fennimore:rival`, once his own guide is started; item `rival_monster_guide` (gear, 2 gp) | Ask about rivals | The annotated guide |
| 8 A borrowed name | `narrative/svalich_road/madam_eva.dialogue`, `again`, when a hero is named Tav (`hero_named:tav`, E2) | Visit her after the reading | A laugh |

## Where the plan and the game differ

- The owl's reward is approval, not Heroic Inspiration: a conversation's `inspire` picks a hero by name, class,
  species, background or tag, and none of those means "whoever rolled". The cap comes off once.
- The owl's display name is plain ("A Barn Owl", "In a Bearskin Cap"); the chalk sign carries the joke.
- No Narrator file changed: the owl's lines live in its conversation.

## Gemini record

Four briefs, one reply each, sent to the `ai-bridge` project's Gemini target on 2026-10-20 with no model or effort
override. Edits (all shortened): the owl, 1A with 1B's "dares your fingers"; the cap 2B; the owl's speech 4B, with 4A's
"night wind"; the dog 5B, "he" made "it" (the dog's data says it/its). The druid 1A and 3B; Lavinia 2B and 4B. Fennimore
1A and 4A (one word changed: "pencil" for "lead"); the hamster 2B with 2A's "the wet shiny parts in the face"; Wren 3A.
The guide's title is 5A's, trimmed; its two notes are 5A's first and 5B's second. Eva 1A.
