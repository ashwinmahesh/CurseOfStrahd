# C6: what was kept from Gemini's drafts, and the edits

One brief (brief.md), sent through Ashwin's ai-bridge to Gemini (project ai-bridge, 2026-10-20); the raw reply is
gemini_reply.json (`result`). Edits were for length, the game's style (British spelling, no dashes, the Narrator's one or two
sentences, "mould" and "grey" as the other castle files have them) and canon. Every question has a true and a false answer in the
dialogue; which one is told depends on the order the questions are asked in (the third and the seventh answers given are false).
Nothing is voiced yet: all 49 distinct lines below are new and unvoiced (13 Narrator trigger lines, 34 in the conversations, the seven answers' shared first line counted once, and the two fight texts).

## The Narrator (narrative/narrator/castle_ravenloft_court.dialogue)

| Slot | Used as | Edit |
|---|---|---|
| C6_ENTER_PASSAGE | `enter:court_vermin_passage`, and the second sentence as `examine:court_vermin_guard` | Split in two (the look closer is its own examine line); "flanking" to "either side of"; "you hear their coats" to "you can hear its coat" (one guard). |
| C6_EXAMINE_DOOR | `examine:court_steel_door_relief` | "the relief of a crowned horseman riding above jagged peaks and a pack of wolves" to "a crowned horseman riding above jagged peaks among a pack of wolves". |
| C6_ENTER_DINING | `enter:court_count_dining` | "beneath" to "under", "gray" to "grey". |
| C6_ENTER_DINING_BURST | the same trigger's `[flag.court_groom_taken]` variant | "The ancient wedding cake ... scattering stale crumbs" to "The wedding cake ... and stale crumbs lie scattered". |
| C6_EXAMINE_CAKE | `examine:court_wedding_cake` | "mold" to "mould", "summit" to "top". |
| C6_EXAMINE_LUTE | `examine:court_wedding_lute` | "with its strings" to ", its strings". |
| C6_ENTER_CLOSET | `enter:court_capes_closet` | "upon" to "on", "proving" to "proof". |
| C6_ENTER_HEROES | `enter:court_hall_of_heroes` | "collapsed roof" to "fallen roof", "whose stone faces" to "whose faces". |
| C6_ENTER_PARAPETS | `enter:castle_ravenloft_parapets` | "suits of dark plate armour pace with a rhythmic, hollow clank" to "suits of dark plate pace with a hollow, rhythmic clank". |
| C6_ENTER_MAIDS | `enter:court_maids_hall` | "draped" to "hung", "on the covers" cut, "small standing mirror" to "small mirror". |
| C6_EXAMINE_MIRROR | `examine:court_maids_mirror` | "small looking-glass around" to "little looking-glass round". |
| C6_ENTER_SERVANTS | `enter:court_servants_upper` | "this freezing attic" to "a freezing attic". |
| C6_FIGHT_VERMIN | `court_vermin` encounter `text` | Kept as drafted. |
| C6_FIGHT_PARAPETS | `court_parapet_watch` encounter `text` | Kept as drafted. |

## The conversations (narrative/castle_ravenloft/court_west_wing.dialogue)

| Slot | Used as | Edit |
|---|---|---|
| C6_EXAMINE_GROOM | `groom` | "face-down" to "face down". |
| C6_TAKE_GROOM | `groom_take` | "leaving the little bride on the cake even more alone" to "and leave the little bride on the cake more alone". |
| C6_HARP_INTRO | `harp` | "gleaming cleanly" to "gleaming clean". |
| C6_HARP_FAIL | `harp_fail` | "against the stone walls" to "off the stone". |
| C6_HARP_GHOST | `ghost`, first line | "translucent" to "see-through". |
| C6_GHOST_1 | `ghost`, second line | "The little ghost touches a hand to his bells, ... and speaks in a voice like dry leaves" cut to "He touches his bells, which make no sound at all"; the dash became a full stop. |
| C6_GHOST_2 | `ghost_feast` | Kept as drafted. |
| C6_GHOST_3 | `ghost_died` | "glances upward" to "glances up". |
| C6_GHOST_4 | `ghost_double`, first line | "at the mention of the clockwork toy" cut. |
| C6_GHOST_5 | `ghost_double`, second line | "The jester leans closer, his voice dropping to a brittle whisper" to "He leans closer, his voice a brittle whisper"; the dash became a full stop. |
| C6_GHOST_6 | `ghost_bye` | "pointed cap" to "cap", "practiced" to "practised", "straight through" to "through", ", so pray" to ". Pray". |
| C6_HEROES_LIGHTNING | `statues`, the first look | "A flash of lightning splits" to "Lightning splits"; "an expression of mortal terror" to "mortal terror". |
| C6_HEROES_ASK | the first line of each answer (`q1` to `q7`) | "draft" to "draught", "the cracked pedestal" to "a cracked pedestal", "within" to "inside". |
| C6_HEROES_DONE | `statues`, once all seven have answered | "No further breath stirs ... leaving only wet stone" to "No breath stirs ... any more: only wet stone". |
| C6_Q1_TRUE, C6_Q1_FALSE | `q1` | True: the hollow voice cut after "does not lift". False: "the statue's motionless jaw as it speaks" to "a motionless jaw". |
| C6_Q2_TRUE, C6_Q2_FALSE | `q2` | True: "as though the stone itself were grieving" cut; the semicolon to a full stop. False: "That red crystal" to "That crystal heart" (the drafted "red" crystal contradicted the heart being clear); sentence split. |
| C6_Q3_TRUE, C6_Q3_FALSE | `q3` | True: "heavy with four centuries of shame" cut; "and drove over the castle walls" to "and who went over the castle walls" (Tatyana threw herself from the walls; Strahd did not push her). False: "the house he brought to ruin" to "the house he ruined". |
| C6_Q4_TRUE, C6_Q4_FALSE | `q4` | True: "secret vault" to "vault"; "through the rain" to "into the rain". False: kept as drafted. |
| C6_Q5_TRUE, C6_Q5_FALSE | `q5` | True: "seems to grow colder still as a grieving voice answers from within" to "grows colder still". False: "ancient pride" to "old pride"; "waiting for the horn that will never sound again" to "waiting for a horn that will never sound". |
| C6_Q6_TRUE, C6_Q6_FALSE | `q6` | True: "our household guards turned their blades against him" to "our guards turned their blades on him". False: "as a solemn voice speaks through the patter of rain" cut. |
| C6_Q7_TRUE, C6_Q7_FALSE | `q7` | True: "both grief and hope for the bloodline's end" to "grief and with hope for the line's end"; "will finally have peace" to "will have peace". False: the comma to a full stop. |
| C6_DRESS_OUT | `dress` | "floorboards" to "floor"; "keeping impeccable time" to "keeping time". |
| C6_DRESS_TOUCH | `dress_touch` | "on the floorboards" cut. |
| C6_DRESS_LEAVE | `dress_leave` | One sentence into two ("... dusty dark. It seems to be ..."). |
| C6_EXAMINE_WARDROBE | `wardrobe` | Kept as drafted. |
| C6_EXAMINE_LADDER_MIRROR | `ladder` | "where iron rungs descend" to ", where iron rungs go down"; "stair" to "stair's". |
