# Side quests from rumours (sidequests lane)

Owner ask (2026-10-08): what people say when you ask "heard anything interesting?" should be side quests you can take
on; build the good rumours out, change the weak ones, make every quest interesting (a twist, a build-up, an
escalation) and pay rewards in proportion to the quest's level and effort. The full audit of every rumour and the plan
are in the vault note "Side Quests - Audit and Plan". This page is what's built.

## How a rumour works

- Each settlement's talkers answer **"Heard anything interesting?"**. A rumour sets a `*_rumor` flag and moves its quest
  to a `rumored` stage, so it shows in the journal with an objective that says whom to ask. A rumour never moves a quest
  backwards: it only starts one that hasn't started (`if not quest.<id>`).
- A rumour about a quest already in the game wires into it instead: the journal stage, or the place on the travel map.
- Once a quest is over, the same talkers say how it ended.
- Flags for every side quest live in one file, `data/flags/side_quests.json`.

## Rewards

Rarity follows docs/story/found_magic_items.md (uncommon up to level 4, rare from 5, no commons). Gold is set against
what the region's other quests pay. Each quest's items are listed there as Gifts or Tips.

## Keeping them finishable

tests/integration/test_side_quest_reach.gd reads the quest ids off this page's headings and checks each one: every
stage is set by a dialogue line or a fight; every place the quest uses (its NPCs, props and fights) is on the travel
map or through an exit from one; every item its lines give exists; and every open stage's hint names one of those
places or a place on the travel map. tests/integration/test_side_quests_endings.gd covers the endings the per-quest
tests didn't reach (Teodor into the woods, Sorin back up the mountain). Each quest's fight is played in
test_side_quest_fights.gd and, for the hard ones, simulated in test_side_quest_bosses.gd.

**No quest left stuck (Side Quest Failure Plan, package F3).** `tools/data/quest_strands.py`, run by `make validate`,
looks at every open stage of a side quest (not a main quest, not a companion's) and its ways on: the conversations that
move it to a later stage or an ending (a line whose `if` asks for a later stage first doesn't count), the fights whose
win does, and the places that open those conversations (an NPC's, a prop's, a container's, a door's, an encounter's
`dialogue`; camp talks and banter are always there). It reports a stage when one flag value set elsewhere in the story
(not where the quest itself moves on, and never cleared again) closes every way on at once, and no `closes` rule covers
the stage: what the Tser Pool camp turning did to Called by Name, The Dancing Bear, The Grey Mare, Radu's horse and
Fennimore's Guide, Tudorel's household to Florin's Grandson, and Exethanter's end to his notes (all found again on the
main before their fixes). It reads only `when`s and flags, so a stuck state made of items or a merchant's stock (The
Sun-Cake's eggs) is still a test's job. Its ALLOWED list names the stages a human has looked at, with why they can't
stick.

## How a side quest fails

Side quest failure plan (vault note "Side Quest Failure Plan - 2026-10-18", package F1). A failure is a story outcome
the player can see coming: a stage with `"ends": "failure"` closes the quest under the journal's Finished tab with a red
Failed pill. The engine's part:

- **A failure is final.** `StoryState.set_quest_stage` refuses every move out of a failure ending, except to the stages
  that ending lists in `"then": ["freed"]` (a comeback the story means to allow). A later line that would set a success
  over a failure is ignored, and says nothing. A success ending behaves as before: another ending may follow it. Every
  failure with a way back names it in its quest's data: The Children in the Pen (`left`, then `freed`), The Order of the
  Silver Dragon (`grudge`, then `rest`), Rose and Thorn (`left_behind`, then `at_rest`), The Pack in the Hills
  (`kiril_leads`, then `pack_broken`; still a success ending, so its `then` waits for the day it becomes a failure),
  and three the survey found in play: A Knight, More or Less (`unknighted`, then `knighted`: Godfrey can still knight
  Godrick later), The Hunter's Ledger (`ledger_closed`, then `ledger_struck`: a name struck later is a way back) and The
  Children in the Mill (`children_abandoned`, then `children_freed`: the hags can still be fought, until the package
  that moves that quest's point of no return decides otherwise).
- **The notice says which.** A quest that moves into a failure ending toasts "Quest failed: X" and tolls a low bell; into a
  success ending "Quest complete: X" (in Experience mode the line that also says the XP, so it is said once); any other move
  "Journal updated: X". The dialogue's `quest` line and a won fight's `quest` both use `StoryState.quest_notice`.
- **Clocks.** `quest_days.<id> >= n` counts whole days since the quest last moved to its current stage (its `at`, which a
  line that sets the stage it is already at no longer touches), and `days_since.<flag> >= n` counts from a flag stamped
  with `set <flag> = now`. Both are false until they start, so a clock only runs for a quest that has begun. A package
  uses them in a `when`, never as a hidden timer: the NPC names the time and the journal warns (closures, F1's second
  hand-off). Clock lengths are the plan's table: "tonight" is the next dawn, "a few days" is 3, "a week" is 7, a fever
  or a slow siege is 10, and a named event is that event.
- **Closures.** A quest that can run out on its own lists `closes` rules in its data: `{"stage": "taken", "when":
  "quest_days.x >= 3", "from": ["asked"], "leave": "<region>", "warn": "<journal line>", "old_saves": false}`. `stage`
  is one of the quest's endings (usually a failure; a quiet success is allowed). `when` is a condition, usually a clock
  or a flag the story has set; with `from` the rule waits for those open stages (default every open stage). `leave` makes
  it fire only as the party walks out of that region. `warn` is the amber line the journal shows under the objectives
  while the rule could still fire (the quest stands at a `from` stage), so no clock closes a quest unannounced.
  `old_saves: true` lets the rule also run when a save loads, to close a quest an earlier version left stuck (journal
  only, no notice); clocks and departures never run on load. `QuestClosures.sweep` (story/quest_closures.gd) looks at
  every open quest after a conversation or a fight, when the clock moves (LocationClock), on arrival, as the party
  leaves a region (LocationView) and on load; each quest it closes toasts "Quest failed: X" (or "Quest complete: X").
- **What the tools check.** `make validate` checks `then` and `closes` (the stage exists and is an ending, `from` names
  open stages, `leave` a region, the condition's flags are registered and set somewhere); `story_reach.py` and
  test_side_quest_reach.gd count a closure as the thing that sets its stage; and `fail_routes.py` now also refuses a failed
  roll of any skill that sets a side quest's failure ending before the next menu (a failed roll costs something but never
  ends a quest). The few that exist sit in its ALLOWED list until the package that reshapes them lands.
- **Heroes, gifts and older saves (package F2).** Two condition terms name a hero by pregen id: `fallen:thistle` (lost
  for good: the altar beneath Death House or the Deck of Many Things; dead and waiting for a raise isn't lost) and
  `gifted:liriel_dawnsong` (has taken a dark gift). Every companion's personal quest has a `lost` failure, just before its
  other endings, closed by `fallen:<hero>` (docs/story/personal_quests.md), and Carry the Dawn closes at `dawn_lost` when
  Liriel herself takes a gift. A rule's `warn_when` holds its journal warning back until the danger has shown itself
  (Liriel's waits for `visited:amber_temple_entrance`). The member pickers wear F4's broken seal too: the dark gift's on a
  hero whose quest a gift would close, the altar's on whoever has a quest open (`QuestClosures.closed_by_pick`). Three
  stuck states the stuck-quest lanes fixed in play close in older saves on load (`old_saves`): Escher's Petition at
  `refused` (Escher fought or turned hostile at Asked or Held), Exethanter's Notes at `lost` (his phylactery smashed, the
  library's shelf included) and The Hunter's Tower at `with_her` (Ezmerelda travelling at Inside, Van Richten not home).

## Into the Mists (level 1)

### The Last Traveller (`the_last_traveller`, narrative/into_the_mists/the_last_traveller.dialogue; batch 5)

The first side quest a new party can find: on the Old Svalich Road, at the edge of the fog the party came out of,
Ilarion (new NPC) sits on a stone in rags many years old and beautiful grey boots, asking what day it is. He went into
the fog last night to fetch a doctor over the mountains for his wife's fever, and it turned him round. **Twist:** his
night was fifty years; his little ones, Petra and Mihail, are Goodwife Petra who carries the water and Old Mihail the
sexton (Insight DC 11 sees the moss in his seams). **Escalation:** the moment he sets off, the count's wolves come out
of the fog for him.

- Fight `ilarion_wolves` on the road: level 1 three wolves and a rat, 160 XP; level 2 four (owner, 2026-10-25: the opening
  wolves hit too hard below level 3, so these are the book-sized packs again; they were five and a rat, and six); level 3 a
  dire wolf leader and seven wolves.
- At the well, Petra knows her father. He gives the party his wife's grandmother's boots, which walk on air a little:
  Winged Boots (uncommon). Old Mihail fills in the grave he dug fifty years ago.

## The Village of Barovia (level 3)

Talkers: Vasile and Petre (townsfolk:gossip, the village's three rumours), Arik (arik:rumors, one word at a time),
Bildrath (bildrath:news, with Grigore added to his topics). Wiring for quests already built: Bildrath's Morgantha line
sets `bonegrinder_rumor` (the mill on the map), his Mary line starts `find_gertruda` at `heard`, and Arik's empty casks
start `wizard_of_wines` at its new `rumored` stage.

### The Polite Caller (`polite_caller`, narrative/village_of_barovia/polite_caller.dialogue)

Widow Ileana's husband Teodor, three winters a vampire spawn, still knocks at her shutter every night and has never
asked to come in. **Twist:** he lives on wolves and is the reason the dead never scratch at her door; his master gave
him until tonight to get her to invite him in, and he came to say goodbye. **Escalation:** the master's coachman comes
for the door (`teodor_errand`), and Teodor can fight beside the party as a guest. **Choice at dawn:** the sunrise
with Ileana, the woods, or the party ends him (before the fight or after).

- Start: the widow at the grave by day (townsfolk:widow, after "Who was he?" or the rumour), or the gossips; Old Mihail
  adds Teodor's open grave (townsfolk:gravedigger_teodor).
- Vigil: by day, "wait with her until dark" (`time until 21`); at night Ileana stands at her door and Teodor comes to
  the shutter (approach). After the fight Ileana comes to the party (`polite_caller:dawn`).
- Fight `teodor_errand` (village map, the east road by the churchyard gate): level 4+ the coachman (vampire spawn), 3
  Strahd zombies, 4 dire wolves, 2 swarms of bats (3,300 XP); level 3 the coachman at full strength, 2 Strahd zombies and 4 dire wolves (3,000 XP); below, the coachman at 45 HP with zombies. Scaled up for 2024 heroes
  (2026-10-13): the sharp autopilot wins 5 of 8 at levels 3 and 4. The coachman is an attention mark (`coachman`, +1).
- Rewards: Teodor's grave (container `teodor_grave`, opens once he tells you): 90 gp, 2 Potions of Healing, a Shield,
  +1 (uncommon). Heroic Inspiration for the party if he sees the sunrise.

### Cut After Noon (`cut_after_noon`, narrative/village_of_barovia/cut_after_noon.dialogue)

The woodcutters cut by noon. Grigore's son Luca stayed late and came home with a load of pale wood; he hasn't woken
since, and Grigore sold the load to Bildrath. **Twist:** it's blight seedwood (Nature DC 13 on the pile `late_wood` or
in Bildrath's storeroom; Medicine DC 13 finds the splinter in Luca's palm), and it wants the boy. **Escalation:** at
dusk the wood walks; Bildrath's load rolls up the street and the woodpile stands up. **The clever way:** get Bildrath's
load, talk Grigore into burning his winter (Persuasion DC 12 or 10 gp) and burn it all by day.

- Fight `woodpile_wakes` (dusk, Grigore's yard): level 4+ "The Woodpile" (shambling mound), 2 vine and 4 needle
  blights; level 3 the mound at 85 HP, a twig and a needle blight (the sharp autopilot wins 4 of 8, the harder side: with the
  needle blight alone, 7); below, blights only.
- Fight `woodpile_burns` (by day, the clever way): blights only, smaller; at level 4 four vine, four needle and three
  twig blights (5 of 8).
- After either, Grigore comes to the party: the splinter (Medicine, Lesser Restoration or pulled), Luca wakes and tells
  of the man in the bear's hide who planted the seeds ("the hill wants the valley back"): `yester_hill_known` unless the
  Gulthias tree has burned.
- Rewards: Grigore's 40 gp (or refuse it); Bildrath's hush money, the Wraps of Unarmed Power, +1 (uncommon) and his 10%
  discount if the party hasn't haggled it.

### Six Feet (`six_feet`, narrative/village_of_barovia/six_feet.dialogue)

Old Mihail digs a grave every week before anybody dies, because a woman's voice comes up the village well at night
and says a name; this week it's his sister, Goodwife Petra. Arik's third rumour or Mihail himself starts it. **Twist:**
Petra tells the story (Zinaida went down the well forty years ago rather than marry the man the castle sent), and the
voice was never predicting deaths: she has been asking for a grave, and every grave Mihail dug was hers. **Escalation:**
bring her bones up from the bottom (prop `well_lip`, Athletics DC 13, by day or night) and she rises behind you. Her
name talks her down; so may Persuasion DC 14; otherwise she screams and fights (`well_bride`). Then lay her in the
grave Mihail dug for Petra (prop `sixfeet_grave`); he cuts her name on the back of the board.

- Fight `well_bride` (the well): level 3 Zinaida (banshee, her Deathly Wail drops anyone at 25 HP or less), 3 shadows, a specter and a swarm of rats (1,650 XP); level 4 three specters instead of one (2,050 XP); below, Zinaida at 40 HP and
  a shadow. The sharp autopilot wins 5 of 8 at levels 3 and 4 (2026-10-13).
- Rewards: 60 gp in her silver coins and the little blue stone she wore with them, an Elemental Gem (Blue Sapphire)
  (uncommon): broken, it calls up an Air Elemental for an hour.

### The Burgomaster's Hound (`the_burgomasters_hound`, narrative/village_of_barovia/the_burgomasters_hound.dialogue; batch 4, level 2)

Bildrath's news gets a new topic: Kolyan's wolfhound, Lupu (new NPC, by the mansion door), howls every night at the
mansion's study wall, not at the wolves. Animal Handling DC 12 lets him lead the party to the study's cold corner (prop
`study_bricks`): new plaster over brick, dried garlic in the cracks, and something scratching on the other side.
**Twist:** a note in the mortar (Investigation DC 12): Kolyan's first son, Sergiu, let the thing at the window in during
the siege winter and came back hungry, and his father couldn't end it and walled him up. Lupu was Sergiu's dog.
**Escalation:** bless the bricks and seal them again (Religion DC 12: 60 gp in the desk, and the howling stops), or
break them open (Athletics DC 11) and face the Tenant with Lupu, who joins the party for the fight.

- Fight `hound_tenant` in the study: level 2 the Tenant (a ghast), three starved servants (two ghouls and a zombie) and a
  giant rat; level 3 five servants (ghouls); below 2 the Tenant at 24 HP and one. With Lupu, the sharp autopilot wins 5
  of 8 at levels 2 and 3 (2026-10-13). It's the only side quest below level 3.
- Opened: 60 gp and the shirt of fine rings Kolyan bought his son before the siege, Mithral Armor (uncommon).

### The Oat Thief (`the_oat_thief`, narrative/village_of_barovia/the_oat_thief.dialogue; batch 6)

Bildrath's news gets a new topic, his stock: four sacks of oats a week go missing and the lock is never touched; he says
Parriwimple is a very poor liar. By night Parriwimple creeps up the north path with a sack on each shoulder (a night
entry on the village map); Persuasion DC 10, or befriending him first, gets it out of him faster, but he tells either
way, and the north path (a new exit, gated) opens on a new map, the charcoal-burners' hollow
(data/locations/woodcutters_hollow.json). There Agafia (new speaker) hides with three children. **Twist:** she ran
from the werewolf den when Kiril began taking children for the count's army, and hers were born to it; she keeps them
on oats so they never learn the taste of meat. **Escalation:** Parriwimple's sack has a hole in it, and the pack's
hunters come up the trail of oats; spotting it (Survival DC 12) catches them unawares, with a wolf left behind.

- Fight `oat_hunters` at her door: a werewolf ("A Pack Hunter") and two wolves at level 2, four wolves at level 3;
  with the trail read (the hunters caught unawares), three wolves at level 2, and three and a farm dog (a mastiff) at
  level 3. The sharp autopilot wins 5 of 8 in each (2026-10-13).
- Reward: Agafia's grandmother's bag, a Bag of Tricks (Tan) (uncommon), whose fuzzy balls get up as beasts that fight
  for the party until dawn; and Bildrath decides it's charity.
- **Reshaped (NPC plan batch 1, 2026-10-18):** the quest can be played by day as a small detective story. "Your stock"
  now offers the back room (Bildrath's storeroom): three clues, each a roll (Investigation DC 10 for the husks leading
  to the back door, Perception DC 11 for the enormous boot with the dragging left heel and the key hung high, Insight
  DC 12 for Bildrath talking about the thief like a relative; two clues move the journal to the new `suspect` stage),
  then "Name the thief": Arik, the village goat or the raven on the roof each cost ten minutes (and the Arik guess a
  little approval) and are spent; after two wrong guesses Bildrath names Parriwimple himself, and naming him needs no
  roll at all. Parriwimple confesses in the back room (Persuasion DC 10 asks Bildrath to go easy; failing it or saying
  nothing only docks his pay) and the hollow opens by day. At Agafia's door, once the trail is read (Survival DC 12),
  the fight can be avoided by laying a false trail to the river (Survival or Stealth DC 12): no fight (`xp fight`
  pays it), the same Bag of Tricks, a different thanks. A failed false trail, a missed trail or standing in the door
  is the fight, as before. The night meeting with Parriwimple on the north path is unchanged.

### The Nursemaid's Grave (`the_nursemaids_grave`, narrative/village_of_barovia/the_nursemaids_grave.dialogue; batch 5)

Old Mihail the gravedigger, asked whether there's anyone he couldn't bury (a new option in his menu, from level 3): a
girl in a nursemaid's cap stands at the churchyard wall by night and won't come through the gate. By night she's there
(`hours`, the Durst nursemaid's NPC on the village map). She knows the party if they hummed her the lullaby in Death
House. Her name is Veta, which nobody in that house ever said; her bones are folded in the attic trunk, and she wants
to lie with her son, Walter, not in the churchyard. **Escalation:** her bones from the trunk (a new option at the
trunk) down to the smallest crypt in the family row (a new option at Walter's crypt). **Twist:** his crypt is empty;
the robed ones cut his name over a box and gave him to the thing in the pit. Laying her in it anyway rouses the
house's keepers.

- Fight `nursemaid_keepers` in the family crypts (my entries on data/locations/death_house_dungeon_1.json): Gustav and
  Elisabeth Durst (ghasts), three robed ones (ghouls) and a giant rat, unless the Dursts are already gone; then the robed
  one who carried Walter down (a ghast), five more and a rat. The sharp autopilot wins 5 of 8 against the Dursts at
  level 3 and 4 against the robed ones (the harder side: without the rat, 6; 2026-10-13).
- Reward: her lucky stone, left on the lid, a Stone of Good Luck (uncommon). No still.

### The Lantern in the Roadhouse (`the_roadhouse_lantern`, narrative/svalich_road/the_roadhouse_lantern.dialogue; batch 9, level 2)

Arik's one-word rumours get a fourth, from level 2, once the other three are out: "Grey Goose. Lantern. No upstairs."
A new travel place, the Grey Goose (data/locations/svalich_roadhouse.json, a new outdoor map with a vistas.json place;
roads from the village and the crossroads), is a roadhouse on the Old Svalich Road that burned twenty winters ago. By
night a lantern hangs in the empty air where its upstairs window was, and the innkeeper's ghost, Wenzel (new NPC),
stands behind the charcoal counter telling travellers there's no room. **Twist:** the light isn't a welcome, it's a
warning. The guest book's last pages (an examine prop) show the winter the snow shut the road, a tinker and his boy,
and in a child's hand, "Mama made a stew"; Insight DC 12 sees him watching a trapdoor nailed shut with too many nails.
**Escalation:** his wife and sons, who fed on the guests, have been pushing the nails up from below all month.

- Fight `roadhouse_cellar` in the taproom: level 2 the innkeeper's wife and a son (ghouls), four giant rats and two
  rats (the sharp autopilot wins 5 of 8); level 3 and up two more sons, another ghoul and four giant rats (5 of 8;
  2026-10-13).
- By night afterwards Wenzel tells it, puts the lantern down on the hearth, and goes out with it. Under the
  hearthstone: 50 gp and his youngest's Pipes of the Sewers (uncommon).

### The Goatherd's Count (`the_goatherds_count`, narrative/village_of_barovia/the_goatherds_count.dialogue; batch 9, level 1)

Goodwife Petra at the well has a new answer: the goats on the hill are minded by her grandson Erno (new NPC), and
every evening for a week he's counted twenty-four of them when he only has twenty-three. A new travel place, the High
Pasture (data/locations/barovia_high_pasture.json, a new outdoor map with a vistas.json place; a road from the
village), has a dry-stone fold, goats (new NPC, the goat sprite), and at the top of the slope the white wall of the
mists. In the evening Erno counts them in, and the last through the gate is an old nanny goat with a cracked bell.
**Twist:** the collar says SNOWDROP: the nanny Petra's father Ilarion was leading the night he went into the mists
for a doctor, fifty years ago (The Last Traveller; with `ilarion_met` the party knows the boot mark scratched by her
name). The mists are giving back what they took. **Escalation:** they don't give anything back for nothing, and
wolves come out of the fog after her.

- Fight `pasture_wolves` on the pasture, in the evening: level 1 six mist wolves (the sharp autopilot wins 5 of
  8); level 2 and up two dire wolves and four wolves.
- Snowdrop goes down to Petra's kitchen (with `ilarion_home`, to her father by the fire), or back into the mists. A
  Potion of Animal Friendship (uncommon) and 25 gp either way.
- **Reshaped (NPC plan batch 1, 2026-10-18):** reading the bell now starts a race against the dusk instead of the
  fight: three beats (stragglers up the slope: Animal Handling or Athletics DC 10; a gap in the wall: Survival or
  Investigation DC 10; the cracked bell: Sleight of Hand DC 10 with Erno's scarf, or Animal Handling DC 12), each also
  open with no roll at all. Every miss or shrug loses a goat to the fog (`goat_strays`). Two lost and the mist sends
  the wolves, the fight as before; fewer and the flock is in, the white finds nothing to push at, no fight (`xp fight`
  pays it), and the choice for Snowdrop is the same. One goat lost is Erno's quiet line about the fog giving back
  what it likes.

### The Fourth Rumour (`the_fourth_rumour`, narrative/village_of_barovia/the_fourth_rumour.dialogue; NPC plan batch 1, level 1 on)

Vasile and Petre, who trade the same three rumours outside the Blood of the Vine "in turns", have never thought a
rumour could be made; they think it happens to you. The party offers them a fourth: the Baron of Vallaki is bald under
his wig, the burgomaster's old dog Lupu can count, or Bildrath gives discounts on Tuesdays. Sell it with a straight
face (Deception DC 11) or as a story (Performance DC 11), or just say it plainly (half-believed, no roll). A rumour
that isn't believed gets Vasile's own instead (the well has a bottom) and the party can try again. **Twist:** it
comes back wrong. Arik says it in one word (Wig. Counting dog. Tuesday.) and Goodwife Petra has it garbled (two
wigs, one to keep the other warm; the hound counts the dead in the churchyard; Tuesday only for those christened on one).
Back at Vasile and Petre the quest is done.

- No fight. Reward: 10 gp, Heroic Inspiration for the party, and a nod from Kip and Wren.
- The Tuesday rumour makes Bildrath honour it once, out of spite (`bildrath_discount`: the same 10% as haggling him
  down, for good), unless the party already has it.
- Later batches let the rumour come back from other regions.

## The Tser Pool camp (level 4)

Talker: Zora ("Heard anything interesting?" is her old road question renamed). Radu's Nicu line now starts
`the_hanged_vistana` at `asked`, as Luminita's does.

**The camp turning on the party (Failure Plan, T1).** Once `tser_pool_brawl_won` or `vistani_turned_hostile` is set the camp's
people are gone (the brawl hides Luminita and Stanimir as well), so four quests that end there each close somewhere the
party can still go: Called by Name at the lake camp, The Dancing Bear at the bare plank stage, The Grey Mare in the empty
pen, and The Hanged Man at the Crossroads with Arrigal, who takes Nicu's news (`the_hanged_vistana` `told` from `buried`
or `risen`, only after the brawl; no potion, no Luminita). None of them sets a main flag.

**Lost to time or a wrong choice (Failure Plan, T1 round two, 2026-10-20; Ashwin 2026-10-19: clocks yes, no failed roll ends
a quest).** Called by Name runs out three days after Big Tobar asks (`answered`), The Dancing Bear a day after the party
first backs away from the trapped cub (`torn`), The Grey Mare's `mourned` is a failure now, and the Hanged Man ends at
`unspoken` if the party tells Luminita the road was empty (offered once the gallows were seen, and marked as ending the
quest; final: neither she nor Stanimir can be told afterwards, and she moves her bedroll into the wagon by the ditch to
watch the road). The first three are below. Stanimir's Fire stays unfailable: its only way to lose is the camp's vote, a
roll.

### The Grey Mare (`the_grey_mare`, narrative/svalich_road/grey_mare.dialogue)

The black carriage that drives itself stopped by Radu's pen and left a purse; tonight Radu walked his grey mare,
Steaua, to the Ivlis crossroads. **Twist:** he didn't sell her for the money; the voice in the carriage promised Nicu
would ride home (Insight or Persuasion; if the party has seen the gallows they can tell him what that promise was
worth). **Escalation:** at the milestone she is being finished into one of the castle's black horses, a brand smoking
on her flank. Calm her (Animal Handling DC 14, one try, or a ranger, a druid, Animal Friendship, or Speak with Animals,
which also has her tell you what's hidden behind the milestone), then break the brand
(Remove Curse, Protection from Evil and Good, holy water, or Religion DC 15, one try: "she hates priests"). Saved, she
bolts home and the carriage comes early; failed or left alone, she is black by midnight and fights for it.

- Props on the crossroads map: `grey_mare_milestone` (her, until the carriage comes) and `carriage_crossroads` (the
  carriage, until its escort is beaten). The pen's grey horse (`tser_horse_grey`) is gone while she's sold.
- Fight `carriage_escort` (east of the junction): level 4 the lead horse (nightmare), a wight footman, 2 specters and a
  zombie (1,850 XP, High; the sharp autopilot wins 5 of 8, 2026-10-13), plus Steaua as a second nightmare and three more
  zombies if she wasn't saved; level 5 adds a wight and a specter;
  below 4 the lead horse at 50 HP with specters and zombies. An attention mark (`black_carriage`, +1).
- Back at the camp Radu pays either way (`home` if she lived, given to Radu or Luminita; `mourned` if not): 120 gp of
  the castle's gold and a Rod of the Pact Keeper, +1 (uncommon).
- **A decoy (NPC plan batch 2, 2026-10-18):** Radu can lend the troupe's Winter Horse (a cloth-and-straw play horse),
  and with lamp soot it can stand in the dark in Steaua's place. At the milestone the swap is offered before any
  calming is tried (a failed one-try calm loses her; the swap never does): Sleight of Hand DC 13, or Stealth DC 13 from
  the ditch. Clean, the carriage takes the straw horse and goes (`carriage_fooled`, no fight, `xp fight` pays it) and
  Steaua is home, `saved`; fumbled, or switched in plain sight, it is the escort fight with Steaua already away.
- **When the Tser Pool camp has turned on the party (Side Quest Failure Plan, T1, 2026-10-18).** Radu is gone with it
  (`tser_pool_brawl_won` or `vistani_turned_hostile`). Once the carriage is beaten (`carriage_beaten`), the empty horse
  pen (prop `tser_pen_empty`) closes the quest: a saved Steaua is found grey and alone with the castle's purse still on the
  gatepost (`home`, 120 gp, no rod and no approval from Radu); a mare lost leaves an empty place at the end of the pen and
  closes it as `empty_pen`, a failure.
- **Mourned is a failure (T1, 2026-10-20).** A mare the castle kept (`mourned`) ends the quest as a failure: Radu still
  pays the castle's 120 gp, but the bride-price rod stays tied to the gatepost with her black ribbon. The rod comes only
  with a saved Steaua. In Experience mode the quest pays no XP then.

### Called by Name (`called_by_name`, narrative/svalich_road/called_by_name.dialogue; batch 2)

Big Tobar's son Nelu followed his dead mother's voice toward Tser Falls (Zora's rumour, or Tobar). **Twist:** the voices
are will-o'-wisps in the gorge, feeding on grief and speaking in whatever voice brings you to the edge; Nelu is alive on
a ledge, and they've been calling his father in Nelu's voice. **Escalation:** at the falls after dark (prop
`gorge_voices` in the west glade) they call each companion by someone they lost (Godrick's Sir Pellam, Wren's Sorrel,
Thistle's grandda, Kip's Pip, Liriel's old teacher, Ratatouille's maman), and a Wisdom check (DC 14, the party's best)
decides whether someone is lured toward the edge, which starts the fight with the party surprised.

- Fight `falls_wisps` (the west glade): level 4 a will-o'-wisp, a shadow and two bats lured (the party surprised; the
  sharp autopilot wins 4 of 8, the harder side), two wisps and a shadow unlured, one of them out by the east pines so no Fireball takes all three (5 of 8); level 5 five wisps and two
  shadows lured, five and one unlured (5 of 8 each); below four a wisp and two bats (4 of 8 lured, 5 unlured). A wisp that vanishes can't
  be targeted but by an area spell (the invisibility rule, 2026-10-14), so there are far fewer than before, and the
  line-ups were chosen from ones that never run out the clock on seeds 1-8 (a lone wisp with nothing else to hit can
  leave the autopilot with no target). tests/integration/test_scaled_fights_barovia.gd holds all six at 4 to 6.
- Then Nelu comes up (Athletics DC 13 on a rope, Misty Step or Spider Climb), and Tobar pays at the camp: 100 gp and an
  Efficient Quiver (uncommon). Nelu stays by the fire afterwards (`tser_nelu`).
- **By day (NPC plan batch 2, 2026-10-18):** the same ledge is there in daylight, with no lights. From the lip a party
  member sees the boy, who hails them (he tells them the voices only come at dark); Athletics DC 13 on a rope, Survival
  DC 12 for the old goat path, Misty Step or Spider Climb all get him up, and the wisps are never met (`xp fight` pays
  the fight). A failed climb costs half an hour and he says to try again; "come back after dark" is the night fight as
  before. Once he's out, the falls are quiet at night.
- **When the Tser Pool camp has turned on the party (Failure Plan, T1).** Tobar is gone with the camp, so a boy brought
  out of the gorge (`nelu_found`) waits at the Vistani camp by the lake outside Vallaki's west gate (`tser_nelu` there,
  `called_by_name:nelu_away`) and the quest closes as `no_fire`, a failure: Nelu is alive, with no money and no quiver from
  his father and no way home. The `nelu_found` hint names both camps.
- **Three days (T1, 2026-10-20).** Tobar's ask stamps `nelu_asked_at`, and he names the time: three days on that ledge
  already, he won't last three more. The journal warns while it runs; three days later, at `asked` or `voices`, Nelu has
  answered (`answered`, a failure, by a `closes` rule). Afterwards the falls call for "Da" in Nelu's voice at night (no
  wisps' fight), and Tobar grieves at his wheels. Getting the boy off the ledge (`nelu_found`) stops the clock.

### The Dancing Bear (`the_dancing_bear`, narrative/svalich_road/the_dancing_bear.dialogue; batch 7, level 3)

From level 3, Lavinia sits on the edge of the plank stage instead of dancing, with a broken chain across her knees:
Bujor (new NPC), the bear who has danced with her for nine years and never once pulled on his chain, broke it last
night and went up the deer path into the woods (Investigation DC 10: the link was pulled open, not cut). She gives the
party her tin whistle. The deer path (a new gated exit in the camp's north-west corner) leads to the old den
(data/locations/tser_woods_den.json, a new outdoor map with a vistas.json place). **Twist:** Bujor didn't run. He's
standing over a cub with its leg in a hunter's trap (the whistle calms him without a check, or Animal Handling DC 13),
and the trap has Old Marin's mark on it (Investigation DC 12): the black carriage pays a gold piece a pound for live
young. **Escalation:** opening the trap makes the cub scream, and the blights come out of the trees for the crying.

- Fight `den_blights` at the den: level 3 two vine blights, five needle blights and four twig blights (the sharp autopilot wins 5 of 8); level 4 and up four vine blights, five needle blights and
  three twig blights (5 of 8).
- Then Bujor goes home to Lavinia's stage with the cub (he stands on the stage from then on), or into the den with it.
  Lavinia gives her grandmother's fan either way: a Wind Fan (uncommon) and 60 gp. Told whose trap it was, she sends
  the party to Old Marin, who confesses and pulls all eleven of his traps.
- **When the Tser Pool camp has turned on the party (Failure Plan, T1).** With no stage to bring him to, the choice at
  the den offers only the den (`choose`), and letting them go closes the quest as `no_stage`, a failure: no fan and no
  60 gp. A bear already led or let go (`found`) and a camp that turns afterwards is closed at the bare plank stage (prop
  `tser_stage_empty`).
- **A day (T1, 2026-10-20).** Backing away from the clearing at `asked` stamps `bear_backed_away` (the first time only)
  with a Narrator line: the brush is already creeping toward the cub. A day later, if the trap still isn't open, the
  blights have them both (`torn`, a failure): Bujor is gone from the clearing, the trap prop shows him dead in the fern
  and the jaws empty, and Lavinia, who knows what silence sounds like, dances alone. Opening the trap (`defended`) stops
  the clock.

### The Spiders' Gully (`the_spiders_gully`, narrative/svalich_road/the_spiders_gully.dialogue; batch 9, level 3)

From level 3, Iancu the knife-thrower at the Tser Pool camp stops throwing: his cousin Tsura (new NPC) rode the falls
path three days ago with a letter in her coat, and her horse came home with web on its saddle as thick as rope. A new
travel place, the Webbed Gully (data/locations/ivlis_spider_gully.json, a new outdoor map with a vistas.json place;
roads from the crossroads and to Tser Falls), is a gully off the falls path strung with web. Tsura hangs wrapped on a
ledge at the back, alive. **Twist:** the letter wasn't the camp's. It was hers, to her mother, saying she wasn't coming
back to be married, and the rings were round her neck. **Escalation:** every strand runs back to the cracks in the
walls; cutting her down brings the spiders (Nature DC 12 reads the web first, and they don't catch the party
unawares).

- Fight `gully_spiders` in the gully: three giant spiders and two swarms of spiderlings (swarms of insects). Caught
  unawares, the sharp autopilot wins 5 of 8 at level 3; with the web read first a rat comes down with them and it wins
  6, the reading's reward (2026-10-13).
- Tsura goes back to the camp to tell her mother herself, or on to Krezk; Iancu's line says which. She gives the party
  the wedding rings, Boon Companion's Bands (uncommon), and 40 gp.

### Stanimir's Fire (`stanimirs_fire`, narrative/svalich_road/stanimirs_fire.dialogue; NPC plan batch 2)

Once Stanimir has told his story, "We have a tale of our own" takes up his bet: a cask of plum wine against the claim that
nobody tells a better tale at his fire. Three rounds: a tale (Performance or Deception DC 12, or told plainly), a true
tale of the valley (History or Nature DC 12, or plainly), then the camp bangs its cups. Two good rounds win; an
entertainer in the party (Wren) works the crowd for one more. Lose and the forfeit is a dance on Lavinia's plank stage
in front of the camp. **Twist:** both prizes end the quest; the cask comes either way (Stanimir's Plum Wine, a small
cask, consumable).

- No fight, nothing locked: the plain tellings need no roll.

### Radu's Unsellable Horse (`radus_unsellable_horse`, narrative/svalich_road/radus_horse.dialogue; NPC plan batch 2)

Radu can't sell Dinte ("tooth"), a handsome dun gelding who bites everyone, and offers 15 gp to whoever finds him a home
(the pen prop `tser_dinte`; Animal Handling DC 12, a ranger or a druid is let near; a bite only costs a sleeve). The
party leads him out on a rope (no roll) to a buyer on the road: Costica, who has no horse and 3 gp and whom Dinte
doesn't bite, or Ambrose Fennimore, who pays 25 gp and is bitten at once. Radu pays when told.

- No fight. Reward: the buyer's gold and Radu's 15 gp, and Radu's version of the story, in which the party is very tall.
- **Lost, not stuck (sq-stuck, finding 126; Ashwin: side quests can be lost).** A camp that has turned on the party
  (`vistani_turned_hostile` or `tser_pool_brawl_won`) has no Radu to pay. Dinte's prop makes no new offer then (it stays if
  the offer was already made, so he can still be led out), and disappears from the pen once led out (`dinte_led`). A horse
  sold while the camp is hostile, or a buyer found before the camp turned and a visit to the buyer afterwards (an option on
  Costica's and Fennimore's menus), closes the quest at `unpaid`, a failure: the buyer's gold is the party's own, the story
  and the 15 gp are not coming (`radus_horse:camp_gone`).

### Fennimore's Guide: The Tser Pool (`fennimores_guide`, narrative/svalich_road/fennimore.dialogue; NPC plan batch 2)

Ambrose Fennimore (new NPC, at the Old Svalich crossroads signpost by day), a travel writer eleven years into the
valley and nine hundred pages into a guidebook, has rated the Tser Pool camp three stars and its plum stew excellent,
and isn't sure the stew is plum. Old Dorina (Persuasion DC 12 gently, or just tasting it, no roll) admits the pot has
not been emptied in sixty years and her wedding spoon is at the bottom. Fennimore rewrites the entry. His other chapters
come with the later regions.

- **Lost, not stuck (finding 127).** He warns, when he sets the errand, that the camp is touchy and that a closed camp means
  no ten gold. If the camp has turned (same two flags) he doesn't offer the errand at all; if it turns after, an option on
  his menu says so and the quest closes at `unverified`, a failure: the entry stays "plum?" and he pays nothing. A stew
  found out before the camp turned (`known`) is still paid. He doesn't leave his signpost ("starting the next chapter").
- No fight. Reward: 10 gp. Costica, the worst highwayman in Barovia, shares the crossroads (new NPC, svalich_road/
  costica.dialogue; no quest of his own), and the camp has new flavour: Dorina's pot, Zora's cord of knots, Petru's blades.

## Vallaki (level 5)

Talkers: the gate watch (gate:news, renamed) and Urwin (martikovs:rumors, renamed) wire into quests already built: the
bones start `bones_of_st_andral` and Arabelle starts `missing_arabelle` at new `rumored` stages, and the book club
starts `wachter_plot` at its own `rumored`. Arasek's road news (renamed "Heard anything interesting on the roads?")
puts Old Bonegrinder on the map. The watch adds Stella's rumour, Urwin the black roses.

### The Cat in the Window (`cat_in_the_window`, narrative/vallaki/cat_in_the_window.dialogue)

Lady Wachter's daughter Stella, locked in the bedroom at Wachterhaus, believes she's a cat. **Twist:** she isn't mad,
she's held (Insight DC 13, Arcana DC 14, Detect Magic, or Speak with Animals finding no cat to answer): at one of
her mother's soirees she promised a stranger in black she'd follow him like a cat follows cream, a black velvet ribbon
with a silver bell holds the promise, and what she sees, he sees; her mother ties the bow fresh every morning.
**Breaking it:** Remove Curse (Liriel from level 6), a Scroll of Remove Curse (Urwin's cellar, Vadoma, Rictavio,
Lucian's services, or the scroll Lucian gives for her), not a knife (cutting it rings the bell, an attention mark, and
it ties itself again). **Escalation:** the master looks out of her shadow one last time (`stella_shadow` in her
bedroom).

- Fight `stella_shadow`: level 5 one wraith ("The Master's Gaze": one, by the owner's call of
  2026-10-12), 12 shadows and a ghast (3,450 XP; the sharp autopilot wins 5 of 8); level 4 a wraith and 3 shadows (2,100,
  High); level 6+ two wraiths and 10 shadows (6 of 8, the easier side: twelve shadows were 6 too, eight 8); below, a wraith at 45 HP and 2
  shadows. Attention marks `stella_eyes` (+1) and, if the ribbon was cut, `stella_bell` (+1).
- Stella then goes to Father Lucian; in the vestry she gives 250 gp (her dowry), the Cloak of the Bat (rare; the
  master's present for her sixteenth birthday) and how the cellar panel at Wachterhaus opens.

### Black Roses (`black_roses`, narrative/vallaki/black_roses.dialogue)

Ignat the lamplighter's daughter Catalina was taken last winter. **Twist one:** black roses come before a girl is taken, not
after, and they are on the chandler's step. **Twist two:** Ignat's scarf hides bite marks (Insight DC 13 or Medicine DC
12); Catalina is the visitor and he has been feeding her so she won't go to anyone else. **The vigil:** at night Catalina comes to
Mila Petrova's window in the lower town. Ask where she sleeps, talk her home to her grave (Persuasion DC 14), fight her
and the two girls she calls (`roses_street`), or let her go home to her father, who is found dead at the lake gate in
the morning (`ilie_fate` lost). **The grave:** three graves at the edge of St. Andral's churchyard (prop `ana_grave`):
dig them up by day (Athletics DC 12; they wake surprised and weak) or wait for them at night (`roses_graves`).

- Fights: `roses_street` at level 5 is Catalina (50 HP), Irina and Daria, two swarms of bats and a swarm of
  rats; `roses_graves` by day has all three girls and two swarms of bats, surprised at reduced HP, by night at full
  strength. The sharp autopilot wins 5 of 8 at level 5 in the street and in the day's dig (2026-10-13). Attention mark `roses` (+1).
- Rewards: Pyotr Petrov the chandler (by day in the lower town) pays 200 gp for Mila's life; Ignat gives Catalina's mother's
  ring, a Ring of Resistance (Necrotic) (rare), once Catalina is at rest.

### Ribbons (`ribbons`, narrative/vallaki/ribbons.dialogue; batch 2)

Daciana the ribbon girl writes down everyone who won't wear a festival ribbon ("it's not me who wants to know"); Anton in
the stocks points at her. She leaves the list under the lamp on Main Street at dusk (prop `ribbon_lamp`). **Twist:**
Watchman Dobre (lane 28's patrol) collects it and sells it three times: to the Baron's clerk (the stocks), to Wachterhaus
(her ladies visit whoever's in the stocks) and to a rider on a black horse at the west gate (the castle). **Escalation:**
the stake-out: follow him (Stealth DC 13) and catch the hand-off at the gate, or confront him at the lamp; Daciana can
leave the list blank to make the rider turn on him.

- Fights `ribbons_street` (Dobre, 4 of his lads (warrior veterans) and a tough: 3,600 XP at level 5; the sharp
  autopilot wins 4 of 8, the harder side: without the tough, 6) and `ribbons_gate` (Dobre and 7 lads, the rider and his
  man: 6,150; 5 of 8); one more lad at 6+, one fewer below 5. Dobre leaves his beat once beaten.
- Daciana comes running after the fight: the satchel gives 250 gp of castle silver and an Arcane Grimoire, +2 (rare),
  and the lists go to Lucian and Urwin (the stocks empty), to the Baron (+100 gp, Dobre in his own stocks) or into the
  fire. Attention mark `lists` (+1).
- **A forged list and a hearing (NPC plan batch 3, 2026-10-18):** at the lamp the party can rewrite the list with names
  that don't exist (Horatiu Cornel, Mirela Nobody, Zamfir the Glad), wait for morning, and watch where it turns up: the
  Baron's clerk has a warrant for a man who isn't there (Persuasion DC 12), Lady Wachter's ladies have left a basket and a
  card at an empty stock (Investigation DC 12), and at dusk the castle's rider pays Dobre for a name that doesn't exist
  (Stealth DC 12). Two proofs of three win the hearing before the Baron: Dobre goes into his own stocks (`dobre_arrested`;
  no fight, `xp fight` pays it, and no mark on Strahd's attention), and Daciana comes next day for the same satchel, grimoire
  and choice of what becomes of the lists. Fewer proofs, or none, and Dobre laughs it off: the street fight, as before.

### Florin's Grandson (`florins_grandson`, narrative/vallaki/florins_grandson.dialogue; NPC plan batch 3)

Old Florin prays in the Village of Barovia's church that his grandson Tudorel, who went up the castle road two winters ago,
doesn't come back. He told the boy the castle pays well (Insight DC 12, or just ask). **Twist:** Tudorel is alive, a
footman in Lady Wachter's house in Vallaki (new NPC, in her parlour), warm, fed and ashamed, and sends his grandfather one
unsigned coin a month by Old Kolya's cart. Back at the church the party chooses what to tell Florin: the whole truth, that
the boy is dead and at peace, or that he is well and warm without whose livery. Each takes it differently (the truth and
the half-truth get the monthly coin that smells of good tea; the lie gets a candle).

**Wherever the household goes (sq-stuck, findings 119 to 121).** Tudorel stands in Wachterhaus while Lady Wachter keeps it;
in the burgomaster's mansion with her once she rules the town (`vallaki_backed == "wachter"`: the same talk); and in the
market square beside the stocks once her house has fallen (stocks, exposed or exiled after the festival), with his own first
meeting (`tudorel_square`: her ladyship is gone from the house, the livery is the only coat he owns). During the festival
itself nobody finds him. He speaks of Florin only while the quest stands at Asked. After the lie, Florin lights candles and
no longer prays against the boy's coming (`florin_after_lie`) and Tudorel thanks the party for giving him a clean end in the
old man's ears (`tudorel_after`).

- No fight, no rolls needed. Approval splits: Godrick, Thistle and Liriel for the truth, Kip and Wren for the lie, Ratatouille
  and Liriel for the half.

### Emanoil Wants to Be Bitten (`emanoil_wants_to_be_bitten`, narrative/vallaki/emanoil.dialogue; NPC plan batch 3)

Emanoil, a Vallaki clerk in black he can't afford, writes long bad poems to the castle and sleeps in a coffin from Henrik's
because he wants to be chosen and bitten (new NPC, outside Henrik's coffin shop by day). Three ways to end it: help him
write his letter to the castle (the carriage never stops for the post), read his poems and see they are about being unseen
(Insight DC 12) and send him to read them at the Blue Water Inn, or tell him what the castle's court is really like. He
sleeps with a candle burning in the coffin; he wants to be chosen, not bitten. Next time he has written an ode to the party.

- No fight. Reward: Heroic Inspiration for the party.

### The Sun-Cake (`the_sun_cake`, narrative/vallaki/the_sun_cake.dialogue; NPC plan batch 3)

Leontina, the Baron's cook (new NPC, in the burgomaster's mansion), has made four hundred and thirteen round suns for his
festivals and wants to make one that isn't. She needs eggs (Goodwife Marta, 1 gp or Persuasion DC 11), honey (Old Paraschiva
at the Vistani camp, 2 gp or Persuasion DC 11) and saffron (Vadoma, 5 gp or 3 with Persuasion DC 12). Baking: Ratatouille takes
over if he is along; otherwise Dexterity or Wisdom DC 12; or leave it to her. A good cake is a triumph (60 gp, Heroic
Inspiration); a collapsed one the Baron calls the Liquid Dawn and orders four hundred and fourteen of (20 gp).

- No fight. A gold piece buys each ingredient, so no roll stands in the way (Vadoma's haggle needs the 3 gp it costs).
- **Lost, not stuck (sq-stuck, findings 122 to 124).** Leontina warns the party to keep the Vistani's good will. Goodwife Marta
  sells the eggs after the council takes the town too. If Vadoma has been broken with the Tser Pool camp (`tser_pool_brawl_won`)
  she will not sell, there is no other saffron, and the quest closes at `failed` the moment the party asks: Leontina bakes the
  four hundred and fourteenth round cake, pays nothing, and the ingredient options go. Whoever rules the mansion tastes the
  finished cake: the Baron (before the festival, or if he rules), Lady Wachter (if she does) or the deposed Baron (if a council
  does); the pay is the same.

### The Hunters at the Inn (`hunters_at_the_inn`, narrative/vallaki/hunters_at_the_inn.dialogue; batch 2, the book's pair)

Szoldar and his son Yevgeni (new NPCs in the Blue Water Inn's taproom; Urwin's rumour) offer half the Baron's 300 gp
for Old Greytooth. **Twist:** Arrigal pays Szoldar to bring strong strangers to the lake at dusk; the wolf is the castle's,
and the castle wants to see how you fight. Yevgeni says so (Persuasion DC 13, or a drink), or Tudor does: one of
Greytooth's shepherds, dead in the reeds at the landing (prop `shepherd_remains`), who under Speak with Dead saw Szoldar
watch from the rise and take Arrigal's purse (docs/story/talking_creatures.md). **Escalation:** the hunt at
the Lake Zarovich landing at dusk (prop `greytooth_shore`), with Szoldar's bow on the rise behind the shacks unless he's
been turned (Intimidation DC 14) or left at the inn.

- **Boss: Old Greytooth** (data/monsters/old_greytooth.json, `source.book: custom`, drawn with the dire wolf's sprite):
  Huge, AC 15, 171 HP, two 2d10+5 bites that knock prone, a recharging howl (DC 15 Wis or Frightened), Legendary
  Resistance (2/day) and one extra bite a round as a legendary action. CR 8.
- Fight `greytooth_hunt`: level 6 Greytooth (171 HP), 2 dire wolves, 3 wolves; level 7 three dire wolves; level 8 adds
  a werewolf; Szoldar (bandit captain) on the rise unless dealt with, and he runs below 25 HP (`szoldar_fled`); with
  Szoldar turned or staying out of it, a castle wolf (werewolf) runs with the level 6 pack instead. The
  autopilot (tests/integration/test_side_quest_bosses.gd) wins 5 of 8 at level 6 with Greytooth at 195 HP, or at 240
  with Szoldar turned (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups). Since then (owner, 2026-10-13) its legendary strike costs one use, so it strikes twice a round, nothing else retuned: 2 of
  8, and 1 with Szoldar turned.
  Attention mark `greytooth` (+1).
- Yevgeni pays the whole bounty, 300 gp, and gives his father's Horn of Valhalla, Silver (rare).

### The Ravens' Ransom (`the_ravens_ransom`, narrative/vallaki/the_ravens_ransom.dialogue; batch 4, level 6)

Once the party knows what the Martikovs are (`keepers_of_the_feather_met`), Urwin's "Heard anything interesting?"
opens low across the bar: his younger boy, Bray (new NPC), flew out after dark on a dare to look at the castle, and a
silver cage hangs in a dead pine on the hill trail above Lake Zarovich (prop `raven_cage`) with a raven in it that
won't change back. It's a trap for whoever comes, and the Keepers can't be seen to. **Escalation:** the count's fowlers
wait in the branches. Perception DC 13 sees them first; Stealth DC 15 opens the cage before they move; walking up, or a
failed creep, gives them the surprise (`fowlers_ready`). **Twist:** they didn't want the boy, they wanted to send him
home: two small marks on his wrist (Insight DC 14) and his eyes on the castle. Remove Curse or a day of daylight and
prayer (Religion DC 14) clears it on the trail or later at the inn (Bray sits at the kitchen window and listens at
the cellar door until it's done); Urwin won't pay until he's himself.

- Fight `raven_trap` under the pine: level 6 the Count's Fowler (a vampire spawn at 120 HP), three more fowlers and
  3 swarms of bats, 7,350 XP; level 7 four swarms; below 6 the Fowler at 90 HP and two swarms. Surprised, the sharp
  autopilot wins 5 of 8 at level 6. Killing them is a mark on Strahd's attention
  (`fowlers`, 1 point).
- Urwin's thanks, once: 200 gp and the mail his grandfather flew in, Elven Chain (rare).
- **Under Lady Wachter's rule, or while the festival has Urwin out** (side quest failure plan, package S2; branch
  sq-stuck-2): Urwin's `urwin` ends every talk with one line when `vallaki_backed` is `wachter`, Danika's `danika` ends
  after her angry line, and the inn's Urwin is gone for the festival, so a Bray who was home and clear could never be
  paid. A boy at the inn who is home and clear now runs for his mother (`the_ravens_ransom:bray`), and Danika pays
  (`paid_inn`: begrudging under Wachter, warm and brisk in the festival; the same 200 gp and Elven Chain, once, through
  one `reward` node). Urwin's menu still pays in every other state. The quest stays `home` until paid, and a charmed Bray
  is still cleared first.

### The Count's Portraitist (`the_counts_portraitist`, narrative/vallaki/the_counts_portraitist.dialogue; batch 6, level 9)

Haralamb, who paints the Baron's wicker sun, sits on his doorstep on the east row in the evenings from level 9 (a new
entry for the sun painter), with red-gold paint on his hands. **Escalation:** a carriage with no driver took him to
the castle for eleven nights to paint a woman in white from the count's memory, with the count's own paints; now
every face he paints is hers, and he has sold three, to the Baron, to Lady Wachter and to Urwin at the inn. With
Ireena along, he knows her at once. **Twist:** (Arcana DC 14) the paint makes eyes of the castle, like the portraits on
its walls: the castle sees every room a copy hangs in, and the great canvas he was given to copy from is the eye they
all see through. His door (a new gated exit) opens on his studio (data/locations/vallaki_painters_studio.json), where the
count speaks to the party out of the painted woman's mouth.

- **Boss: the Count's Likeness** (data/monsters/the_counts_likeness.json, `source.book: custom`, built up from the
  guardian portrait and drawn with its sprite at Large, `art_height` 2.2): Large construct, AC 13, 181 HP (230 in this
  fight), a Frame Strike with reach and The Count's Regard (DC 16 Wis, 5d10 Psychic and Frightened), Hypnotic Pattern
  and Hold Person once a day, Legendary Resistance (2/day), and a look between turns. CR 8. Seven copies come off the
  walls with it (guardian portraits at 40 HP).
- Fight `counts_likeness`, the canvas at 245 HP. The autopilot wins 5 of 8 at level 9 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Burned, every copy in Vallaki goes blank. Haralamb scrapes the count's paints into clean pots and prays over them:
  Nolzur's Marvelous Pigments (very rare) and 150 gp. Still: `sq_counts_likeness` (the canvas, first seen).

### One Lantern Too Many (`one_lantern_too_many`, narrative/vallaki/one_lantern_too_many.dialogue; batch 5, festival week)

The town guard's news (a last line before "Always the festival", from level 5): festival nights the children carry
paper lanterns round the square for the Baron, thirty-one children and thirty-two lanterns. Old Sabin (new speaker, a
lantern stall in the market by day) makes them, and his hands make one too many without his knowing why. **Escalation:**
last night his grandson Sandu (new speaker) followed the extra one out of the west gate, toward the lake. Insight DC 12
on Sabin's hands brings it back to him. **Twist:** thirty years ago the Baron's first festival was a procession of
boats on Lake Zarovich; one turned over, the Baron wouldn't let the rest turn back ("All will be well"), and Sabin's
daughter Liliana went down holding her lantern up. By night she stands at the end of the fishers' jetty, a girl of
light, holding Sandu's hand. Somebody can turn back for her: take Bluto's boat out and dive for her lantern
(Athletics DC 13), and she goes out of her own accord; miss the dive, or plead, or draw, and she fights.

- **Boss: the Lantern Girl** (data/monsters/lantern_girl.json, `source.book: custom`, from the will-o'-wisp and the
  ghost, drawn as a girl of light: owner report 2026-10-13, "doesn't have a sprite", she had been the wisp's skull orb.
  She has her own sprite and portrait now (art/sprites/lantern_girl, art/portraits/lantern_girl: Liliana, a floating
  girl of candle-gold light holding up her lantern, lit from within by CombatToken.OWN_LIGHT; a stand-in on Rose's
  sheets came first), a child's height, 0.9): Small undead, AC 15, 90 HP, flies, two
  Cold Hands, a Lure that pulls a foe 20 ft toward her, Drowning Light (recharge 5-6, a 20-ft emanation, Restrained),
  Legendary Resistance (1/day), and a flicker between turns. CR 5. Four drowned lights (will-o'-wisps) come up with
  her.
- Fight `lantern_girl` on the jetty (my entries on data/locations/lake_zarovich.json). The autopilot wins 5 of 8 at
  level 5 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Sabin's thanks, once Sandu's home: 40 gp and the dream-catcher Liliana made the week before, a Dream Weaver (rare).
  Still: `sq_lantern_girl` (her first meeting).

## The River Ivlis crossroads by day (level 5)

### The Tinker's Wagon (`the_tinkers_wagon`, narrative/svalich_road/the_tinkers_wagon.dialogue; batch 4)

Zora's count at the Tser Pool camp gets a new line: Iosif, a tinker who used to be one of theirs, sells pots and Death
House trinkets from a green wagon at the crossroads, four travellers who bought from him never came past the camp, and
the wagon gets fatter. Iosif (new NPC, at the crossroads from 8:00 to 18:00) never gets down off the board. **Twist:**
Insight DC 13 catches him mouthing "don't"; Perception DC 14 sees wheels with no joins, a twitching shaft and a chain
from his ankle into the boards that isn't iron. The wagon is a mimic the size of a wagon, and Iosif has been its bait
for seven years. **Escalation:** once something's been seen, go for the chain, and the wagon stands up off its wheels.

- **Boss: the Tinker's Wagon** (data/monsters/tinkers_wagon.json, `source.book: custom`, from the 2025 Monster
  Manual's mimic, drawn with its sprite at Huge): Huge monstrosity, AC 14, 171 HP, two sticky pseudopods (reach 10,
  Grappled) and an acid bite, a spray of trinkets (recharge 5-6, Restrained), Legendary Resistance (1/day) and one
  more lash between turns. CR 7.
- Fight `tinkers_wagon` at the crossroads: level 5 the Wagon at 220 HP and a trinket (a mimic), 3,350 XP; level 6 the
  Wagon at 160 HP and five trinkets; below 5 the Wagon at 110 HP and one. The autopilot wins 5 of 8 at levels 5 and 6
  (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups); since then it lashes twice a round
  between turns, nothing else retuned (owner): 2 of 8 at level 5, 4 at level 6.
- The belly: 300 gp of travellers' money and the gem the thing kept to see with, a Gem of Seeing (rare). Iosif goes
  back to the Tser Pool camp and sits on the ground.

## The River Ivlis crossroads at night (level 8)

### The Count's Huntsman (`the_counts_huntsman`, narrative/svalich_road/the_counts_huntsman.dialogue; batch 3)

Old Paraschiva, the cook at the Vistani camp outside Vallaki, is the camp's rumour-giver: on cold nights a horn sounds
in the Svalich woods, and in the morning whoever the count is displeased with lies under the crossroads gallows, run
to death. Whose scent the Huntsman has follows Strahd's attention: once the party is `marked` (data/strahd/attention.json)
it's theirs ("three notes is for strangers"), otherwise Gavril the groom's, who sold the castle a painted horse
(`hunt_quarry`). The rule: the hunt ends under the gallows at moonrise, and a quarry who stands there and beats him
ends it for good. **Twist:** the Huntsman is Toader, a poacher the count ran down himself in his first winter, who stood
and turned at this crossroads and was made huntsman for it; every quarry since has become one of his hounds, and the
Vistani have scratched their names on cairns by the road (prop `quarry_stones`). **Escalation:** at night he stands on
the east road (Gavril waits by the junction if it's his scent). Reading the stones first lets the party call the
hounds by name, and most of the pack lies down (`hounds_called`).

- **Boss: the Count's Huntsman** (data/monsters/count_huntsman.json, `source.book: custom`, from the 2025 Monster
  Manual's revenant and wight, drawn with the revenant's sprite): Medium undead, AC 17, 165 HP, two attacks with a boar
  spear (reach 10) or black arrows (1d8+5 and 2d8 necrotic), a horn that frightens (recharge 5-6, 60 ft), Legendary
  Resistance (2/day), and a loosed arrow or a step into the trees between turns. CR 9.
- Fight `the_hunt` on the east road: level 8 the Huntsman at 240 HP, his mare (a nightmare) and 6 hounds (dire
  wolves), or 3 hounds once they're called (the autopilot wins 5 of 8, and 6 of 8 with the hounds called
  (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups));
  level 9 the Huntsman at 290 HP, six hounds (five called); level 10 at 390 HP, eight (five called), each about 5 wins
  in 8; below 8, the quest's fallback, the Huntsman at 130 HP with 3 hounds (1).
- Beating him is a mark on Strahd's attention (`huntsman`, 1 point).
- His saddlebag: 300 gp of quarry's purses and the iron ring he called the pack with, a Ring of Animal Influence (rare);
  across the saddle, the black bow he shot with, an Oathbow (very rare).

## Argynvostholt (level 8)

### The Squire (`the_squire`, narrative/argynvostholt/the_squire.dialogue; batch 3)

The Vallaki gate's news: Cosmin, a cooper's boy, ran north with a wooden sword to join the dead knights, and his
mother waits at the north gate every night. Sir Godfrey gets "Heard anything interesting?" (Argynvostholt's
rumour-giver): the boy sleeps on the squires' graves, because Vladimir told him the Order doesn't take the living,
and he said he'd wait until he wasn't. Cosmin (new NPC, on the last grave until the quest is done; at the gatehouse
after) wants the oath to clear his ancestor Ioan, written "fled" in the Order's chronicle. **Twist:** on the back of the
last headstone (Investigation DC 13) Ioan cut his own words: he made his brothers' stones, then rode with the dragon's
last word for the valley. Shown that, or once the party knows the dragon's last words, Godfrey remembers: he sent
Ioan on his own horse, and Vladimir wrote "fled". **Escalation:** the oath was never a squire's first; the vigil was. A
night at the graves with the banner, while the dead squires stand at their stones, and the men-at-arms of the last
battle come out of the courtyard for the only living things on the ridge.

- Fight `squires_vigil` at the graves: level 8 the Gate Warden and four Knights Who Forgot (revenants) with 4
  men-at-arms (phantom warriors), 11,800 XP (the sharp autopilot wins 5 of 8); level 9
  eight men-at-arms; level 7 one knight and five; below 7 the Warden at 90 HP and four.
- Godfrey writes Ioan's name right and Cosmin's under it, and gives the party Ioan's shield, left at the gate the night
  he rode: an Arrow-Catching Shield (rare), and 150 gp from the Order's chest. Not offered once the Order rests.
- NPC plan batch 5, without a fight: once Godfrey has remembered (stage `truth`), Cosmin can ask the Order's table to hear
  Ioan's case at the graves, once. Evidence is worth a vote each: the words on the back of the headstone, the dragon's last
  words, Godfrey's own account (always open), History DC 13 (the Order's rolls) and Persuasion DC 14. Three votes carry it,
  with the same reward as the vigil; short of that the table isn't moved and the vigil is still open. Sir Ottokar the Late
  rides in as the vote is called.

### Sir Ottokar the Late (`argynvostholt/ottokar`; NPC plan batch 5, comedy)

A dead knight (new NPC) who was late to the Order's last battle and has been late to everything since. He stands in the
grounds after any fight at Argynvostholt (the courtyard phantoms, the mausoleum watch, the lamp, the duel, the beacon, the
vigil) and asks whether he missed it, with three different apologies. He wants to be on time once. **Secret** (Insight DC 12
after he has said so): he was late because he stopped to help a farmer's wife with her cart, and would again. He goes when the
Order rests. No quest, no fight. The Phantom Warden (a reason for his door, then, on Insight, the herald he let in under a flag
of truce) and the Phantom Watchman at Tsolenka (who nods at any watchword, because he forgot it two centuries ago) have a
want and a secret in the same way.

### The Silver Hoard (`the_silver_hoard`, narrative/argynvostholt/the_silver_hoard.dialogue; batch 7, level 9)

From level 9, Sir Godfrey has a new question to answer: where did the dragon keep his hoard? He gave it away. Every
Midwinter the Order carried it down the valley and left a silver coin on every doorstep with a fire behind it, the
Dragon's Tithe. The last winter's tithe was chested in the undercroft the night the house fell, and the tithe-keeper
went down to it and never came up to the table again; Godfrey can't find his name. With the knights at rest, a
draught under the servants' table (a new examine prop, from level 9) gives the same start. The stair down (a new
gated exit in the servants' hall) opens on the undercroft (data/locations/argynvostholt_undercroft.json), where a
knight sits on the tithe chest under four hundred years of grown-over silver, counting (`sq_gilded_knight`, a new
still). **Twist:** (Insight DC 15) he isn't guarding the tithe for the valley: a squire's shield cut in two lies at
his feet, and he says the valley is the count's now and won't have the dragon's silver. **Escalation:** the escort's
empty harness rises with him. With the dragon's last words from The Squire (`vladimir_last_words_known` or
`ioan_cleared`), "Let them go home" makes him want the silver off him, and he fights at 140 HP.

- **Boss: the Gilded Knight** (data/monsters/gilded_knight.json, `source.book: custom`, built up from the 2025 Monster
  Manual's revenant and drawn with its sprite): Medium undead, AC 19, 178 HP, two Silvered Longsword blows with
  necrotic cold, a Covetous Glare that paralyzes (recharge 5-6, DC 16 Wis), Regeneration 10 that fire and radiant
  stop, Legendary Resistance (2/day), and a blow or a step between turns. CR 10. Three animated armours come with him
  ("An Escort's Harness").
- Fight `gilded_knight` in the undercroft. The autopilot wins 5 of 8 at level 9 with the knight at 410 HP in this
  fight (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups); the dragon's words make it easier.
- In his armour: a Golden Idol of Good Fortunes (very rare). Then the tithe chest: send it down to the valley (the Order
  rides it out at Midwinter, or the party carries it if the knights are at rest; 250 gp, and Godrick, Kip, Liriel,
  Wren and Thistle approve), or keep it (1,200 gp, and they don't).

## Lake Zarovich (level 8)

### The Bell Under the Lake (`bell_under_the_lake`, narrative/lake_zarovich/bell_under_the_lake.dialogue; batch 2)

Old Nistor, the last fisherman (lane 28), tells it once the Arabelle business is over: before the count dammed the Luna,
the hamlet of Pescari stood where the lake is, and the ones who wouldn't leave its chapel are still in it with the
bell. **Twist:** Bluto wasn't mad; his sacks were paying the bell, and now they've stopped. **Escalation:** after
moonrise (prop `bell_water` at the jetty's end) the drowned come up the shore for Bluto (if he's alive at the landing)
or for Nistor. Stand in front of him, or stand aside and let them take Bluto (`bluto_fate` becomes `drowned`); they rise
either way.

- Fight `drowned_landing`: level 8 the Bellringer (a wraith), the Lake's Undertow (a water elemental), 6 ghasts and 8
  ghouls (7,900 XP; the sharp autopilot wins 5 of 8); level 9 adds a second
  undertow and a drowned bride (a wight); below 8 a wight, 2 ghasts and 6 ghouls.
- Then cut the bell loose (Athletics DC 15, Water Breathing or the potion) or ring it once for the dead (Religion DC 14):
  200 gp of chapel silver and the drowned priest's Staff of Healing (rare).

### The Baron's Island (`the_barons_island`, narrative/lake_zarovich/the_barons_island.dialogue; batch 8, level 5)

From level 5, unless the council has the town, Old Nistor at the landing has a new answer: some nights the Baron's
boat rows out to the Reed Isle with somebody tied up in the bottom of it, somebody who was unhappy too loudly about
the festival, and rows back with nobody. He lends the party his boat (it leaks on the left). A new travel place, the
Reed Isle (data/locations/zarovich_reed_island.json, a new outdoor map with a vistas.json place; by boat from the
landing), holds Ostap (new NPC), a Vallaki cooper who said the festival was a waste of good wicker. **Twist:** they
didn't drown. Fourteen of Vallaki's unhappy are living on the island on reeds and fish, and are the only happy people
within a day's walk of the town. **Escalation:** tonight the boat comes back with another, and the boatmen saw the
smoke last time. The Baron, Izek, the festival and Ireena are only read (`vallaki_backed` for the hook and one line,
`guest:ireena` for Ostap's bow).

- Fight `reed_isle_boatmen` on the shingle, by night: the Boatmaster (a bandit captain), two veteran boatmen, four
  toughs, and something in the reeds (a giant constrictor snake). The sharp autopilot wins 5 of 8 at level 5.
- The castaways keep the boatmen's boat hidden and stay, or row home to Vallaki in daylight, singing. Either way Ostap
  gives the party the shackles the boatmen brought: Dimensional Shackles (rare) and 80 gp.
- **After the bell has started** (S2, sq-stuck-2): Old Nistor's `start` jumped straight into the bell's talk once
  `bell_under_the_lake` was anything but empty, and that talk never offered the island, so The Baron's Island could not
  be started by a party that had asked about the bell first. From level 5, unless the council has the town and while the
  island is not yet asked, he now asks first (`old_fisher:bell_or_island`, one greeting for the bell still ringing and one for
  the bell silenced): the bell, the island, or goodbye. A party that cannot ask about the island goes straight to the bell
  as before.
- NPC plan batch 4, without a fight: Ostap offers the vote (Persuasion DC 12 argues either side, or the castaways decide).
  To go home, the party rows them across in three crossings with a roll each (Athletics on the oars, Stealth to stay dark,
  Acrobatics to bail); two crossings seen and the boatmen land on the shingle as above. To stay, the party hides the
  island (Stealth or Survival DC 12); a missed roll and the boat lands. Either unseen ending is the same reward, and pays
  the fight's XP once.

## The Gates of Barovia (levels 6 and up)

### The Last Muster (`last_muster`, narrative/into_the_mists/last_muster.dialogue; batch 2, the book's skeletal riders)

Zora counts twelve riders going east every night after midnight, and none coming back; Vasile and Petre (once the
village's other two rumours are taken) hear lances knocking at the gates. **Twist:** they're the count's vanguard,
who took the valley's gate the night he conquered it, on the order "hold the gate until I come back", and he never
came back for them. **Escalation:** at the Gates after dark Marshal Dragomir (new NPC, the phantom warrior's sprite)
holds the gate. History DC 14, the soldier's rite (Religion DC 15) or Persuasion DC 15 stands the riders down; the
marshal still wants to be beaten, fairly, because only a lost battle can relieve him.

- **Boss: the Bone Marshal** (data/monsters/bone_marshal.json, `source.book: custom`, drawn with the phantom warrior's
  sprite): Large undead, AC 18, 150 HP, two grave-blade strokes (1d12+6 slashing and 1d8 necrotic, reach 10), Parry,
  Legendary Resistance (2/day) and a charge (one more stroke) between turns. CR 8.
- Fight `bone_marshal` at the gate: the whole column (level 6 the marshal at 170 HP, 2 lieutenants as wights at their
  full 82 HP and 6 skeleton riders; level 8 the marshal at 270 HP, a third wight and 2 phantom warriors; below 6 the
  marshal at 110 HP, one wight, six riders), or only the marshal and his lieutenants once the riders stand down (level 8:
  190 HP and three). Over seeds 1-8 the autopilot wins 5 of 8 against each of the column at levels 6 and 8 and the
  marshal and three lieutenants at level 8 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
  Since then (owner) the marshal charges twice a round between turns, nothing else retuned: the column 2 of 8 at levels
  6 and 8, the marshal and his lieutenants 4.
- The pay chest: 200 gp and the marshal's blade, a +2 longsword (rare).

## Old Bonegrinder's lane (level 6)

### The Fourth Sister (`the_fourth_sister`, narrative/old_bonegrinder/the_fourth_sister.dialogue; batch 3)

Once the Sarnov children are out of the mill and Morgantha is dead, Vasile and Petre's gossip says Goodwife Sarnov
walks up the miller's lane every morning for one plain pastry from a girl who sells them there, and that the girl has
her husband's eyes. The girl, Mouse (new NPC, on the lane from 7:00 to 19:00), is Old Bonegrinder's rumour-giver:
"Heard anything interesting?" gets Granny's coming for her thirteenth birthday, and the iron coming in at her gums.
**Twist:** she is Morgantha's fourth, a stolen girl raised to be a hag, and the Sarnovs' first baby, Zamfira, who
"died" in her cradle the night Morgantha sat up with her (Ilinca's "since the baby died" in the mill is the clue).
Goodwife Sarnov (new NPC, on her step in the village once the children are out) gives the name and the mark on her
wrist; Mouse's wrist confirms it (`mouse_named`). **Escalation:** on the next night at her hut (prop `mouse_hut`),
Morgantha's mother, Granny Ash, comes out of the trees. Named, the girl stands behind the party; unnamed, Persuasion
DC 15 holds her (`mouse_stayed`). Granny offers the girl for a basket of coins and her word never to come back.

- **Boss: Granny Ash** (data/monsters/granny_ash.json, `source.book: custom`, from the 2025 Monster Manual's annis
  hag, drawn with the night hag's sprite): Large fey, AC 17, 184 HP, two iron claws (reach 10) and a bite, a Crushing
  Hug (recharge 5-6) that restrains and crushes, Legendary Resistance (2/day) and a rake between turns. CR 8.
- Fight `granny_ash` on the lane: level 6 Granny at 145 HP, 3 dire wolves ("Granny's Dog") and 4 needle blights
  (the autopilot wins 5 of 8 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups); since
  then she rakes twice a round between turns, nothing else retuned (owner): 4 of 8); level 7 adds 2 needle and 2 vine blights; level 8 six needle blights and the hag garden's elm (a tree
  blight), 7,700 XP; below 6 Granny at 130 HP, one dog and 3 needle blights.
- Endings (`mouse_fate`): `home` (named: Zamfira back with her mother, Ilka and Toma, on the step in the village),
  `keepers` (unnamed: Ilinca takes the girl with half-iron teeth) or `given` (the basket; the quest fails and the
  companions disapprove).
- Granny's basket: 300 gp and a Robe of Eyes (rare). The basket alone pays the 300 gp.
- NPC plan batch 4, without a fight: in her offer, "Hags bargain" plays Granny at riddles. She asks three (a river, an
  echo, and the name she ate); the party answers each from a short list or works it out (Investigation DC 12). Two right win:
  she keeps her word, leaves the basket and goes back to the deep wood, and the girl goes home or to the Keepers as the name
  decides. The third riddle is won by saying Zamfira, which only a party that learned the name can. Two wrong and it is the
  old fight, with the old options still there.

## The Wizard of Wines (level 6)

### The Black Row (`the_black_row`, narrative/wizard_of_wines/the_black_row.dialogue; batch 3)

Once the Martikovs are home, Andrei the picker won't touch the Seventh Row (it comes up black in the night and is gone
by morning), and Davian, the region's new rumour-giver ("Heard anything interesting?" in his menu once the winery is
reclaimed), asks the party to find out who picks it. By day the row (prop `seventh_row`) shows what it is to Nature DC
13 (one blight grown up into every rootstock) and who visits it to Investigation DC 13 (raven feathers, a man's bare
feet). **Twist:** after midnight the picker is Adrian, who eats the black grapes because they make him dream of Elvir
alive and not angry, and the veins on his hands are going dark like the leaves. The row is a cutting of the Gulthias
tree Kostin planted on Ruxandra's last order; it has its own roots now, so it lives even if the tree on the hill burned,
and if Elvir is buried at the end of the row it has been drinking from his grave. **Escalation:** the reconciliation, or
the truth of Elvir's order, or Persuasion DC 15 brings Adrian round, and he fights beside the party (`adrian_against_row`,
a guest until Davian's report); otherwise he flies off and the party cuts the root alone. Either way the row stands up.

- **Boss: the Vine Mother** (data/monsters/vine_mother.json, `source.book: custom`, from the 2025 Monster Manual's tree
  and vine blights, drawn with the tree blight's sprite): Huge plant, AC 15, 210 HP, two branches (reach 15) and a
  grasping vine that drags and crushes, a cone of black wine (recharge 5-6, Poisoned), Legendary Resistance (2/day), a
  lash and a creeping move between turns. CR 8.
- Fight `vine_mother` at the foot of the row: she rises right behind the Seventh Row, her branches in reach of the
  party at its basket, with the row's vines between them (the heroes reach her round its end, or shoot). Level 6 the
  Vine Mother at 200 HP, 3 vine blights and 5 needle blights (4,450 XP); level 7 at 136 HP, four vine and five needle
  blights; level 8 at 200 HP, five vine and six needle blights and the Sixth Row (a tree blight), 7,600 XP; below 6
  the Vine Mother at 101 HP, a vine and 3 needle blights. From the basket (seeds 1-8) the test party, playing as the
  owner does (smites, Spirit Guardians, Fireball), wins 5 of 8 at levels 5 to 8 (the owner's 5 in 8 on Balanced,
  2026-10-13); with Adrian along it wins 6 at levels 5 and 6, 5 at level 8 and 4 at level 7, where no setting made him
  help. (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points and helpers in this note are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)
- Davian pays once: 250 gp and the wand the Wizard of Wines left in the press-house rack, a Wand of Fireballs (rare).

## Vallaki and Castle Ravenloft (level 10)

### The Toymaker's Masterpiece (`toymakers_masterpiece`, narrative/vallaki/toymakers_masterpiece.dialogue; batch 2, the book's Blinsky and the jester)

Goodwife Marta (townsfolk:marta_rumor) says Blinsky asks every stranger whether they've been up to the castle, and
whether a jester his old master made still walks there. Blinsky (a new menu option) tells it: Fritz von Weerg's jester
for the count's children, and he would give his whole shop to see how von Weerg did the knees. **Twist:** the jester is
Pidlwick II, who is afraid of toymakers ("THEY OPEN YOU UP"), and who once pushed the first Pidlwick down a stair. On
his stair (or travelling with the party) Persuasion DC 14 talks him round, or, if the party has played with him, wound
him or learned his secret, telling him Blinsky is as lonely as he is; he joins if he isn't with the party already. At
Blinsky Toys he won't come past the door until he's talked round. **Escalation:** the visit goes beautifully until
Blinsky climbs his narrow stair and Pidlwick goes still at the bottom of it. Knowing his secret, the party can step in
and tell Blinsky (`blinsky_told`: he builds a ramp) or step in and say nothing; anyone can just watch, and Pidlwick
doesn't push: "I DIDN'T. THAT IS NEW."

- No fight: the one gentle quest in batch 2. Its cost is the trip into the castle.
- Endings: Pidlwick stays at Blinsky Toys (`home`; he leaves the party and juggles in the window), or, when he is the
  marionette card's ally, he stays with the party and promises to come back after the castle (`promised`).
- Reward either way: Blinsky's masterwork, a Figurine of Wondrous Power (Obsidian Steed) (very rare).

## Krezk (level 7)

Talker: the watchman (gate:news, renamed). Wiring: Ilya's sickness starts `the_burgomasters_son` at `heard` (if
nothing has yet), the stopped wine starts `wizard_of_wines` at `rumored`, and the children taken from the farms below
the wall set `werewolf_rumor` and start `wolves_in_the_hills` at `heard`. Kasha Varo's graves answer adds the toys.

**The Burgomaster's Son** (`the_burgomasters_son`, narrative/krezk/anna.dialogue; S2, sq-stuck-2): `frail` waited for a
Cleric's prayer or the Abbot's hands. With no Cleric in the party and the Abbot slain, or left at the abbey when the
party fled it, nothing could ever finish it. Anna, on the next visit, now closes it at **`recovering`** (a success: Ilya
mends slowly under her care, 40 gp for the stone he won't need, no Amulet of Health). `ilya_fate` stays `frail`, so the
endings and Dmitri read what they always did; a party that has a Cleric keeps the prayer, and one that gains a Cleric
later can still take `recovering` to `healed`.

### Lighter Than It Should Be (`lighter_than_it_should_be`, narrative/krezk/lighter_than_it_should_be.dialogue)

Somebody leaves carved toys on the five Krezkov graves at the Pool of the White Sun (prop `krezkov_toys`); Old Pavel
the carver says they're cut with a thumbnail, not a knife. **The vigil:** after midnight a goat-legged figure comes over
the north wall and sings Anna's lullaby in Anna's voice. **Twist:** he is Sorin, the Krezkovs' first son: Anna carried
him up the mountain with the fever twenty years ago against Dmitri's wishes, and the Abbot sent down a nailed coffin
full of stones (dig the eldest grave to see it). Dmitri calls Ilya his last son. **Escalation:** while the Abbot holds
the abbey (no `abbot_fate`), the abbey comes for its stray (`sorin_pursuers` at the pool). **Climax:** the family scene
at the Krezkov house: Persuasion DC 15, Insight DC 13, the coffin of stones, or Ilya asking his brother to carve a wolf
brings Sorin `home`; otherwise he stays at the pool with Kasha (`pool`) or goes back up the mountain (`mountain`).

- Fight `sorin_pursuers`: level 7 two flesh golems ("A Bride Before Vasilka"), 3 Belview Brutes (berserkers, as the
  Krezk doc stands them in) and 4 mongrelfolk (5,150 XP, Moderate); level 8 a third bride; below 7 one bride, 2 Brutes,
  4 mongrelfolk.
- Rewards in every ending: Anna's 400 gp (a dowry for a daughter they never had) and Dmitri's grandfather's mail, an
  Armor, +1 (rare, chain mail).

### The One-Horned Billy (`one_horned_billy`, narrative/krezk/one_horned_billy.dialogue; batch 2)

Stelian the goatherd (townsfolk:goatherd) says the one-horned billy turned up last spring already grown, with a
woman's silver ring jammed on his horn. **Twist:** the ring reads D. AND V. BEREZ (Animal Handling DC 14), and
there's a man behind the goat's eyes (Insight DC 13, or Speak with Animals). Remove Curse, cast or from a scroll,
turns him back into Dragos, the ferryman of Berez (new NPC, by the pens once he's freed), whom Baba Lysaga cursed for
refusing to row her across. **Escalation:** she kept his wife Vera and stitched her into the Rag Queen, a scarecrow
made of every drowned bride's wedding dress, which walks the scarecrow field by Lysaga's stump (prop `rag_queen_post`)
whether Lysaga's at home or not.

- **Boss: the Rag Queen** (data/monsters/rag_queen.json, `source.book: custom`): Large construct, AC 16, 260 HP, two
  claws (3d8+6 slashing, Frightened), a glare (recharge 5-6, DC 16, Frightened and Paralyzed), Legendary Resistance
  (2/day), a rake between turns, and Regeneration 15 that fire stops. CR 10.
- Fight `rag_queen` in the field: level 9 the queen at 375 HP, 2 drowned brides (banshees) and 4 straw grooms
  (scarecrows); level 10 a third bride, 2 more grooms and a swarm of insects; below 9 the queen at 200 HP, one bride and
  4 grooms. The autopilot wins 5 of 8 at level 9 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Dragos pays once: 500 gp of brides' dowries and a Dancing Sword (very rare, a longsword) Lysaga took off a knight.

### Clovin's Audience (`clovins_audience`, narrative/krezk/clovins_audience.dialogue; batch 2)

The Krezk watchman's news: a Belview came down from the abbey at midsummer and asked to tell them a joke, and Lazar
threw a bucket of water over him. Clovin (new options at the abbey, also once the Abbot's fate is settled) has written
jokes on the backs of the Abbot's letters for forty years and wants one audience that could choose not to laugh.
Dmitri says yes without a roll if the party gave him back a son (`ilya_fate` healed or `sorin_fate` home), otherwise
Persuasion DC 15; refused, Clovin comes down in a monk's hood. **Escalation:** the show at dusk in the square by the
shrine (Clovin stands there from 17:00 to 21:00 while it's booked). Three beats can land, counted in `clovin_laughs`:
the warm-up (Wren, if he's in the party, or Performance DC 13), the advice when his Abbot jokes die (Insight DC 13
reads the crowd: they'll laugh at a man who's had a hard time, never at the Abbot), and Watchman Lazar's heckling
(Performance or Persuasion DC 14; in a hood, Lazar pulls it off). **Twist:** Clovin's last joke is his grandmother
Floarea's, and Old Pavel laughs until he cries: it was their father's. Pavel was the boy who barred Krezk's gate behind
the sick Belviews sixty years ago, took the neighbours' name, and has carved a sun every day since.

- No fight.
- The hat: 250 gp if two beats landed, 150 gp for one, 75 gp (Pavel's own pockets) for none; and in every ending
  Pavel's father's Ring of the Ram (rare).
- Afterwards Pavel goes up the mountain with soup on Sundays, and the watchman is told to let Clovin in on feast days.

### Mother's Ninth Improvement (`mothers_ninth_improvement`, narrative/abbey_of_st_markovia/mothers_ninth_improvement.dialogue; batch 3)

Clovin gets "Heard anything interesting?" (the abbey's rumour-giver): Mother has been talking about Krezk, and, if
Pavel is family, he's asked her to Sunday soup. Mother (new NPC, in the darkest corner of the wards kitchen) won't
talk while the Abbot is improving; once `abbot_fate` is set she takes off her blanket. **Twist:** she is the baby
carried up the mountain sixty years ago (Pavel's niece), her nine gifts include a heron's legs that won't take the
mountain, and the ninth is a pair of great grey wings the Abbot stitched shut with silver wire so she wouldn't fly to
heaven early. She doesn't want heaven; she wants Krezk. **Escalation:** her boys in the cells first (the abbey's own
cells scene, either way: freed, she's glad; fought, she grieves and goes anyway); then the wire (Sleight of Hand DC 14
or Medicine DC 13; a failure still gets it out, painfully); then the courtyard wall, where she has to believe the one
thing the Abbot told her that might be true (Persuasion DC 13, Wren's advice, or a held hand). Nature DC 14 shouts her
down onto Pavel's roof; otherwise she lands in Krezk's goat pens.

- No fight.
- Her eighth gift, which Clovin brings up to the wall: Winged Boots (uncommon; Boots of Levitation until 2026-10-13,
  swapped in older saves when they load). Afterwards she lands on Pavel's roof
  on Sundays, and Krezk's watchman has decided to be very calm about it.

### The Waystone (`the_waystone`, narrative/krezk/the_waystone.dialogue; batch 8, level 6)

From level 6, Clovin's "Heard anything interesting?" ends with Lark, his cousin's girl, who goes over the Abbey wall
every night after the last bell, down the Krezk road toward the old stone with the sun cut into it. A new travel place,
the Waystone (data/locations/krezk_road_waystone.json, a new outdoor map with a vistas.json place; roads from Krezk
and Vallaki), opens with the rumour. By day the candle is burnt to nothing; by night Lark (new NPC, a Belview with a
lark's feathers and legs) kneels at the stone lighting a new one, and sings in her dead mother's voice. **Twist:** the
candle is for her brother Yanko (new NPC), who went over the wall two winters ago and was taken by the wolves, not
eaten: he comes to the edge of the light every night as a young werewolf to hear her sing (Insight DC 12 sees his
eyes). **Escalation:** the pack has noticed him going soft and comes down the road for both of them. The pack's flags
are only read (`wolf_pack_leader` for one line).

- Fight `waystone_wolves` at the stone, by night: four of Kiril's hunters (werewolves), a dire wolf and two wolves.
  The sharp autopilot wins 4 of 8 at level 6, the harder side (with one wolf, 6).
- Then Yanko comes into the light. Talked down (Persuasion DC 13) he's a boy again, and goes with Lark to Great-uncle
  Pavel in Krezk if Mother's Ninth Improvement found him; otherwise he lies down at her feet as a wolf. Lark gives the
  party the Abbot's Wand of Slumber (rare), and Yanko a traveller's old purse, 120 gp. Clovin's news says how it ended.
- NPC plan batch 4, by day: the tracks in the mud (prop `waystone_tracks`, Survival DC 12, retried freely) lead to
  Yanko's lair under a fallen pine and show that Lark comes to the stone at noon, during the Abbot's prayers. Lark
  (day placement once the tracks are followed) can sing him out in daylight: Persuasion DC 12 steadies her, Stealth DC 13
  keeps the pack off. A missed Stealth roll is the old fight at the stone; a missed Persuasion roll only shakes the song.
  The reward is the same. After a won fight Lark waits by day as well as by night.

### Dumitru's Visitor (`dumitrus_visitor`, narrative/krezk/dumitrus_visitor.dialogue; NPC plan batch 4)

Dumitru, the boy who waits inside Krezk's gate for visitors who never come (talk to him: "Who are you waiting for?"),
writes weekly letters to his Uncle Marius in Vallaki, who died long ago, and keeps them in a tin. He wants one real
visitor. The party can come as Marius's old friends (Deception DC 12; he sees through it kindly, and the quest goes on),
or ask Ambrose Fennimore at the Old Svalich crossroads to walk up the road. Fennimore then stands inside Krezk's gate until
the visit, and leaves the tin a rating (four stars). Nothing is behind a roll that has no plain way round.

- No fight. Reward: 20 gp (cousins) or 40 gp (Fennimore), companions' approval.
- **Sq-stuck (findings 131, 132).** Fennimore's spot inside the gate has Dumitru's hours (9:00 to 17:00, not in a storm), so the
  visit can't play at night with Dumitru's lines spoken while he is indoors. The friends story is still offered at the Fennimore
  stage; if it ends the quest first, Fennimore never comes and Dumitru's later greeting is the plain one: only the real visit
  sets `fennimore_visited_krezk`, which the "four stars" greeting reads (saves made before this fix that completed the
  Fennimore visit get the plain greeting).

### Old Silviu's Wedding Cask (`silvius_wedding_cask`, narrative/wizard_of_wines/silvius_cask.dialogue; NPC plan batch 4)

Once the winery is the family's again, Old Silviu the cooper (at his casks by day) wants the last cask of the year Elvir
was born carried to Vallaki for his daughter Dana's wedding at noon in the square. The road is bad, and there are three
precautions: padding the cask against the ruts (Athletics DC 12, or 3 gp for good straw and rope), a wolf that has
learned carts mean food (Animal Handling DC 12, or 2 gp for scraps), and thirsty hands (Persuasion DC 12, or 1 gp for
Silviu's lead and tallow seal). How many held decides how the cask arrives: all three is a triumph (60 gp), one or two a
little shaken (40 gp), none vinegar (25 gp). Dana (new NPC, in Vallaki's square while the cask is on the road) takes it and
Master Costel makes a speech about it, whatever it is. The wedding happens regardless.

- No fight. Every precaution has a plain coin way, and skipping them all only turns the wine to vinegar.

## The Tsolenka Pass (level 10)

### The Frozen Pilgrims (`the_frozen_pilgrims`, narrative/tsolenka_pass/the_frozen_pilgrims.dialogue; batch 3)

Sergeant Valcu of the dead Tsolenka watch is the pass's rumour-giver ("Heard anything interesting?" at the challenge,
"Anything to report?" once the party has passed): forty-one years ago nine pilgrims from Vallaki went round his gate by
the goat path to ask the amber never to be cold again, and their lamp is on the landing, in the ice. The ice of the
gorge wall (prop `pilgrims_ice`) shows nine kneeling in a row, and Mother Ecaterina (new speaker) at the front with
the lamp lit, alive. **Twist:** the amber answered them exactly: never to be cold again, by becoming the cold (Arcana
DC 16: she's the knot the gift is tied to, and the cold has to go somewhere). **Escalation:** the last rites (Religion
DC 14, or a cleric's) let all nine go quietly; breaking her out wakes the other eight fused into the Penitent.

- **Boss: the Penitent** (data/monsters/the_penitent.json, `source.book: custom`, from the 2025 Monster Manual's frost
  giant, drawn with the amber golem's sprite at Huge): Huge undead, AC 16, 210 HP, two frozen fists (reach 10), a
  freezing embrace (recharge 5-6, DC 16, Restrained), Legendary Resistance (2/day), and a fist or a step between turns.
  CR 11.
- Fight `the_penitent` on the landing: level 10 the Penitent at 480 HP and 5 pilgrims' shadows (ghasts); level 11 at 590
  HP and ten shadows; level 9 at 420 and four; below 9 the Penitent at 170 HP and three. What its fists can't reach it
  pelts with ice torn from itself (Hurled Ice, 60/240 ft), so a hero fallen on the narrow landing no longer strands it.
  The autopilot wins 5 of 8 at levels 9 and 10 and 4 of 8 at 11 (the harder side: at 575 HP, 6) (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- The rites: 400 gp of the pilgrims' offerings. Breaking her out: 500 gp, and her frosted lamp-pole with all the cold
  in it, a Staff of Frost (very rare).

### The Last Egg (`the_last_egg`, narrative/tsolenka_pass/the_last_egg.dialogue; batch 6)

Tibor (new speaker), a Vistani egg-hunter camped at the Tsolenka landing from level 9: the roc of Mount Ghakis lays once
in eleven years, this is the year, and his buyer pays 400 gp, split with whoever carries the sack. Insight DC 15: two
neat marks on his wrist; he's been told to fetch. **Escalation:** the nest on the roc's shelf (a new prop, shown once
the quest is known) holds an egg as tall as a child, hatching as the party arrives. **Twist:** the buyer doesn't wait
for deliveries: the stone birds on the tower drop off it, and the count's falconer (new speaker) lands among them to
take the chick. Step back and let him (400 gp from Tibor, the quest fails, and a mark on Strahd's attention,
`roc_egg`), or stand between him and the nest.

- Fight `last_egg` on the shelf (my entries on data/locations/tsolenka_pass.json): the Falconer (a vampire spawn at
  150 HP), two of his hands (vampire spawn) and six stone birds (gargoyles). The sharp autopilot wins
  5 of 8 at level 9.
- Defended: the mother roc comes back to her chick and lets the party be, on the bridge or anywhere
  (`roc_driven_off`); in the bones under the nest, 300 gp and a Belt of Hill Giant Strength (rare). Still: `sq_last_egg`.

### The Pack's Runt (`the_packs_runt`, narrative/krezk/the_packs_runt.dialogue; batch 4, level 8)

Once the den's children are home (`den_children_freed`), the Krezk watchman's news says Petru (new NPC, speaking as
Little Petru so his lines don't go to the Tser Pool knife-grinder), the smallest of the five, sleeps in the goat pens
now and the goats don't mind him, and something bigger than a wolf circles the farms below the wall. **Twist:** the moon came for Petru in the den before the rescue; he's a wolf nearly all the way
(Insight DC 13), and the pack's eldest, the Grandsire, licked his face after and said the runt was his. Remove Curse
(cast, or a scroll) lifts it, and far off something howls at the loss. **Escalation:** at night by the pens the
Grandsire comes over the wall with the old wolves; he offers the pack's word to take no more Krezk children in
exchange for the runt (`given`: the quest fails and the companions disapprove), or he fights.

- **Boss: the Grandsire** (data/monsters/the_grandsire.json, `source.book: custom`, from the 2025 Monster Manual's
  werewolf, drawn with its sprite at Large): Large monstrosity, AC 16, 180 HP, a bite that knocks you Prone and two
  claws, Pack Tactics, a howl that frightens (recharge 5-6), Legendary Resistance (2/day), and a bite or a lope
  between turns. CR 9.
- Fight `grandsire` in Krezk's square: level 8 the Grandsire, 2 old wolves of the pack (werewolves) and 2 dire wolves,
  6,800 XP, the Grandsire at 165 HP; level 9 three werewolves and the Grandsire at 150 HP (the autopilot wins 5 of 8 at
  both (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups)); level 7
  one dire wolf fewer; below 7 the Grandsire at 140 HP with one of each.
- Krezk's bounty, from Dmitri: 300 gp and the iron bands that have hung in the watch house for the wolf that never
  came, Iron Bands of Bilarro (rare).

### The Guide to the Temple (`the_guide_to_the_temple`, narrative/tsolenka_pass/the_guide.dialogue; batch 8, level 10)

Once the party has passed the Tsolenka gate, from level 10, the dead sergeant has a new answer: nobody went up his
road, but three times this winter lanterns went up the goat path round his tower, and one came down each time. Last
night, a man, a woman and a sledge with something small on it, coughing. A new travel place, the Goat Path Camp
(data/locations/amber_road_camp.json, a new outdoor map with a vistas.json place; a road from the Tsolenka Pass),
holds the guide (new NPC and boss), Remus and Floarea from Vallaki (new NPCs), and their daughter on the sledge, going
to ask the Amber Temple for a cure. **Twist:** (Medicine DC 14) it isn't lung fever: the guide has been keeping her
sick with sleep-root in her tea, and admits it when confronted: something in the amber pays him a year for every
family he brings to its door. Insight DC 15 sees him watching the sledge like a drover. **Escalation:** nobody turns
back on his mountain; tell the family to go home and he gets up anyway. The temple's vestige and dark-gift flags are
never set or read, and The Frozen Pilgrims isn't touched.

- **Boss: the Guide** (data/monsters/amber_guide.json, `source.book: custom`, drawn with the scout's sprite): Medium
  humanoid, AC 16, 135 HP (170 in this fight), an Ice Axe and an Amber Bolt, a Whiteout that blinds (recharge 5-6),
  Hold Person and Cone of Cold once a day, Legendary Resistance (2/day), and a bolt or a step between turns. CR 10.
  Two of his shadows stand up off the snow with him (shadows), and two of the ones he led up before (wraiths).
- Fight `amber_guide` at the camp, the guide at 155 HP: the autopilot wins 5 of 8 at level 10 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Floarea, an herb-wife who smelled the sleep-root and told herself she was wrong, pours out the tea; without it the
  child will wake with only a cough. In the guide's pack: a Rod of Alertness (very rare) and 400 gp.

## Mount Baratok (level 9)

### The Mage's Lost Pages (`the_mages_lost_pages`, narrative/mount_baratok/the_mages_lost_pages.dialogue; batch 4)

Once Mordenkainen is himself (`mordenkainen_restored`), he gets "Heard anything interesting?" (the mountain's
rumour-giver): the witch's jar gave him back almost everything, but there are pages missing, letters in a small
slanted hand he knows better than his own, with no name to it. The storm he forgot he'd ordered blew them out of the
hut. Three on the mountain (props `corvina_letter_birds`, `corvina_letter_ring`, `corvina_letter_overlook`): Perception
DC 14 finds each, or digging out the ice, glass or drift finds it in half an hour. **Twist:** they're from Corvina, his
apprentice, and the last, in pencil, says "Master, go. I'll hold the door." He didn't lose to the count; he ran while
she held it. Under it, in the count's hand: "She holds my doors still." **Escalation:** he wants to go up the road
tonight; his promise to come with the party (or Persuasion DC 16) holds him, or he rages and the hut freezes from the
inside.

- No fight. It leads to The Unnamed Crypt (batch 4, the castle).
- **Whatever order (Ashwin, 2026-10-19).** His name can come back by the jar, Greater Restoration, the spellbook with its
  last page, or talking him back; the letters can be found before or after; he can be taken as Madam Eva's ally before
  or after. All end with the letters read and the quest `named` (tests/integration/test_mage_pages_orders.gd). "We found
  three letters that belong to you" is on his menu at the hut and on the road without asking for news first; as an ally he
  has a `guest_talk` (`mordenkainen:companion`, with "Nothing. Let's go." as the exit), the gift "The three lost letters"
  under Give..., and if the party already holds all three when he joins, he asks for them there and then.
- Corvina's first ring, which he took off her desk the night they went up: a Ring of Telekinesis (very rare).

### The Forgotten Storm (`the_forgotten_storm`, narrative/mount_baratok/the_forgotten_storm.dialogue; batch 7, level 8)

From level 8, the mage on the mountain, mad or himself again, has an answer about the lightning that lands on the ring
of glass every evening. Mad, he told it something once and can't remember what, it's getting angrier, and he's fairly
sure it wants him. Restored, he knows: the night he ran from the castle he called a storm down behind him to cover the
road and told it to bring Corvina after him (The Mage's Lost Pages). It never found her, and it comes back every
evening to say so. At the ring of glass (a new examine prop at its heart) the party waits for dusk, and the storm comes
down and asks where she is. **Twist:** (Arcana DC 15) under the mage's order, in another hand, the count has written
two more words into the spell: and him. **Escalation:** it doesn't wait long for an answer. With her name (her letter
from the ring, or Mordenkainen), the party can tell it she's at rest (The Unnamed Crypt), and it lets go without a
fight; or that she's in the castle, and it breaks itself against the sky going there and comes back weaker. The mage
stays where he is and as he is; nothing here touches find_the_ally or his ally flags.

- **Boss: the Forgotten Storm** (data/monsters/forgotten_storm.json, `source.book: custom`, built up from the 2025
  Monster Manual's air elemental and drawn with its sprite at Huge, `art_height` 3.2): Huge elemental, AC 15, 152 HP
  (140 in this fight), two Thunderous Slams with 15-ft reach, Lightning on two creatures (recharge 5-6, DC 16 Dex) and a
  Whirlwind (recharge 4-6), a lair action as the evening's lightning lands, Legendary Resistance (1/day), and a gust
  or a slam between turns. CR 9. A squall comes with it (an air elemental at 60 HP).
- Fight `forgotten_storm` on the mountain, the storm at 240 HP: the autopilot wins 4 of 8 at level 8, the harder side
  (at 237, 6) (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups); sent east first, at 110 HP, it's the easier fight.
- In the glass where it stood: the brass censer the mage dropped on the road forty years ago, a Censer of Controlling
  Air Elementals (rare). The mage's thanks: 250 gp.

## Castle Ravenloft (level 10)

### The Unnamed Crypt (`the_unnamed_crypt`, narrative/castle_ravenloft/the_unnamed_crypt.dialogue; batch 4)

Pidlwick II gets "Heard anything interesting?" (the castle's rumour-giver, in his stair menu and when he travels with
the party): a lady in the catacombs holds doors for the count all night and has no name on her box; everybody has a
name on their box, even the horse. The crypt at the end of the east row (prop `unnamed_crypt`) has no name cut into it
and handprints in the dust on the lid from the inside. **Twist:** it's Corvina, Mordenkainen's apprentice (The Mage's
Lost Pages), made one of the count's spawn for holding the door while her master ran; she holds the count's doors now.
**Escalation:** with her name from Mordenkainen (`corvina_name_known`), saying it before she rises weakens what holds her
(`corvina_named`), but she can't stop; without it, the lid is all there is.

- **Boss: Corvina, the Doorkeeper** (data/monsters/corvina.json, `source.book: custom`, from the 2025 Monster Manual's
  vampire spawn and mage, drawn with the vampire spawn's sprite): Medium undead, AC 16, 165 HP, claws with necrotic
  chill or arcane bolts of force, Slam the Door (recharge 5-6, a 30-ft cone that pushes), Regeneration 10 that radiant
  stops, Legendary Resistance (2/day), and a bolt or a step between turns. CR 12.
- Fight `corvina` in her crypt: level 10 Corvina and four door-wardens (helmed horrors); named, she's down to 105 HP
  with four (the autopilot wins 4 of 8 as she is and 6 of 8 named (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups)); level 9 and below, lighter.
- In her crypt: 500 gp in a currency nobody here has seen, and a Rod of Absorption (very rare). Her name goes on the
  crypt, and Mordenkainen has a line for it.

### Escher's Petition (`escher_petition`, narrative/castle_ravenloft/escher_petition.dialogue; batch 6)

From level 10, Escher's menu has a new question: what's the paper he keeps turning over? Every night for nine years
he has slid the same petition under the count's door, one line, Let me see the sun, and last night an answer came back
under his: Yes. He wants company on the south tower roof before dawn, and he'll pay with the one present the count gave
him that he could never use. **Twist:** (Insight DC 15) he has folded the paper so only the one word shows. The rest
is Bring your friends: I should like them to watch. He wanted the sun more than he wanted the party to come back down,
and says so. **Escalation:** by night Escher waits at the south tower parapet (a new entry on the roofs; his chair in
the suite is empty by night while the petition stands). Querreth, the devil the count bound to his roofs to bring back
whatever of his tries to leave, comes down off the keep to chain Escher to the sunrise and take the guests to the
larder. Everyone who ever asked to go up hangs in its chains. Without the rest of the note, the party is caught
unawares.

- **Boss: Querreth** (data/monsters/querreth.json, `source.book: custom`, built on the 2025 Monster Manual's devils and
  drawn with the fiendish spirit's sprite at Large, `art_height` 2.6): Large fiend, AC 17, 180 HP, flies, two hooked
  Chains with 10-ft reach that grapple and a burning Claw, The Chains Answer (recharge 5-6, three creatures within
  30 ft, DC 16 Str, 4d10 and Restrained), Magic Resistance, Legendary Resistance (2/day), and a lash or a wingbeat
  between turns. CR 11. Two of the ones who asked before come with it (wraiths, "One Who Asked").
- Fight `querreth` on the south tower roof, Querreth at 335 HP: the autopilot wins 5 of 8 at level 10 caught unawares,
  and 7 of 8 forewarned with him at 280 HP (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Then the party sits out the night with him and the sun comes up (`sq_escher_dawn`, a new still). Either he watches it
  and burns, and leaves a red velvet coat on the stones with the count's present in the pocket, or (Persuasion DC 15)
  the party talks him into waiting for a dawn the count isn't in, and he goes back down to his chair. Either way: a
  Helm of Brilliance (very rare, a crown full of captured daylight for a man who could never wear it) and 250 gp.
- Escher's suite, banter and narration follow him: once he's seen the dawn his chair is empty and his coats hang in
  the wardrobe without the red velvet one.
- **Refused** (failure, stage `refused`): turning on Escher while the petition stands (`asked` or `held`) ends it on the
  spot, in spires_escher:attack (steel drawn) and :scared (the Intimidation about opening his curtains at dawn). The
  roof entry reads the quest, so nobody waits at the parapet for a petition that is over, and no helm or gold changes
  hands. Before this the quest stayed open and a copy of a slain Escher kept the parapet at night. A finished petition
  (`done`, `waited`) is never overwritten, and with no petition at all nothing starts. Old saves with the petition open
  and Escher already slain or frightened are left for the old-save closures (the failure plan's F2).

### The Boyar's Petition (`boyars_petition`, narrative/castle_ravenloft/boyars_petition.dialogue; NPC plan batch 6)

Boyar Vintila Crainic has waited 206 years in the audience hall to present a petition about a boundary stone. Ask him what a
petition needs and he explains the form: four seals of the household. Each of the four ghost servants lends theirs for one
small thing the wedding night stopped: Ghenadie the Valet (sit on the edge of the master's bed), Anghel Daskal (write the line he
dictates), Nicodim the Verger (stand witness at the chapel door) and Vlaicu the Lamplighter (count the tower stair with him,
to two hundred and nine). With the four seals the petition goes to the Steward in the dining hall, who receives it, and the
Boyar learns his stone is under Lake Zarovich now and is entirely satisfied.

- No fight, no roll. Reward: 120 gp and the companions' approval.
- "Which seals do we still lack?" names only the seals not yet lent (`boyars_petition:seals_lack`; the whole form again when
  none are, and no option at all once the four are held; sq-stuck, finding 130).

### Gogu (`castle_ravenloft/gogu`; NPC plan batch 6, comedy)

A living gargoyle (new NPC) on the keep roof, afraid of heights, who wants a lower ledge and drops things on guests when the wind
rises, blaming the ravens (Insight DC 12 sees the loose slate in his claw). The party can carry him down to the Gates (Athletics
DC 14; a failed lift drops him two feet and can be tried again); there he sits on a low ledge, and the ravens blame him.

Small additions in the castle, all in the same files as the household: Lord Thale sold his horses for cards the first night;
Sir Lothar Brandt is glad his priest lies in the crypts (Insight DC 13; the plan had the priest escaping, which the book's
Brandt line contradicts); the Steward once laid a place for himself and was punished (Insight DC 13); Helga wants a mirror that
works and sells the brides what guests say (Insight DC 13); Lady Celestine never was beautiful, she made the others laugh; and
Lief Lipsiege saved a coin a year for the gate (Insight DC 12), then gives the party the forty coppers, which the Dead
Halberdier takes. The village goat is eating a tapestry in the great entry while the Hall Broom sweeps round it, and Ambrose
Fennimore, once his first chapter is done, is on the cliff road outside the gates rating the castle: the last chapter of his guide.

## Mount Ghakis (level 10)

### The Warm Snow (`the_warm_snow`, narrative/mount_ghakis/the_warm_snow.dialogue; batch 5, an owner-asked boss)

Sergeant Valcu reads the next entry in his log when he's asked for his report again (after The Frozen Pilgrims): smoke
on the north shoulder of Mount Ghakis, where nobody lives, snow that melts there in midwinter, and the count's black cart
going up every new moon with a cage on the back. There were faces in the cage this month. That puts the north shoulder
of Ghakis on the travel map (data/travel/mount_ghakis.json, a new region with its own loading card), two hours round
the gorge from the pass. **Escalation:** the count's keepers are unloading at an iron gate in the mountain, and the
cage holds his tithe, Doina and Petrache, charcoal-burners from below Krezk (new speakers); the keepers' log in their
post names what's inside. **Twist:** an ancient red dragon, Sarkhaza (new speaker), who came through the mists forty years ago
after a dead silver dragon's gold and found the count waiting: chained by the neck, wings riveted shut, starved on
grave-salt, lying on the hoard she came for. She offers to burn the count out if the party pulls the pin from her
collar (Insight DC 16: she can't fly, and she means the villages below). **Second twist:** the hoard is gilt lead
(Investigation DC 15 before the fight, or after it), and under it, where she lay, is the silver's own coat of scales.

A mini-dungeon in two maps (data/locations/ghakis_shoulder.json, ghakis_lair.json): the shoulder and gate; then the
keepers' post, the larder, the anchor (the great drum her chain is wound on), the vent gallery and her cavern. The
keepers had three ways of going down to her safely, and each one puts her in a state for her fight (her stat block's
`states`, shown on her sheet; the encounter's versions in ghakis_lair.json turn them on):

- **Salt her meat** (the larder, Sleight of Hand DC 14; a bad job and she smells it): fed to her, she fights
  grave-salted: slowed (Speed halved, -2 AC and Dexterity saves, no Reactions, an action or a Bonus Action), one Rend
  on her turn and one legendary action a round.
- **Haul her chain in** (the anchor's capstan, Athletics DC 17; one try): the chain snaps her head back by the collar as
  the fight opens, and she is caught unready (surprised). She doesn't choke on it in the fight (owner, 2026-10-19:
  "just get rid of the chain choking her altogether"): she has her Fire Breath and her spells from the start.
- **Open the sluice** (the vent gallery): snowmelt drowns the cracks, and the fight isn't in her lair: no lair
  actions, three legendary actions and four Legendary Resistances instead of four and five.
- On her chain in every fight but one: Speed 20, no climbing. Pulling the pin from her collar instead lets her off it
  (Speed 40, climbing 40), with no chain to haul.

- **Boss: Sarkhaza** (data/monsters/sarkhaza.json; owner, 2026-10-18: "she is supposed to be an ancient red dragon").
  The 2025 Monster Manual's Ancient Red Dragon, drawn with the draconic spirit's sprite at her own height
  (`art_height` 5), and lying across her gold until she rises in a drawing of her own (art/sprites/lying/sarkhaza.png): Gargantuan, AC 22, 507 HP, three Rends (+17, reach 15, 2d8 + 10 slashing and 3d6 fire), Fire
  Breath (recharge 5-6, a 90-ft cone, DC 24 Dex, 26d6), Spellcasting (Charisma, DC 23: Command and Scorching Ray at
  will, Fireball once), Legendary Resistance (4/day, 5 in her lair), three legendary actions (four in her lair:
  Commanding Presence, Fiery Rays, Pounce), and her cavern on initiative 20 (fire out of the cracks under two foes, or
  the roof coming down). CR 24. What the story adds is on her sheet: her wings riveted shut (no Fly Speed, the
  book's is 80 ft.) and the chain. The fight is for level 11, the game's cap (the Amber Temple is the last milestone,
  and Ghakis is on its road). Her first Fire Breath takes a level 11 party: the full-ability test party wins 0 of 8 in
  every version, with or without the keepers' tricks (2026-10-19, once the choke went; it won 3 of 8 with all three
  tricks while the hauled-in collar choked her breath for a minute). By the owner's rule nothing was retuned for it
  (docs/story/boss_fights.md).
- **Her cavern, 2026-10-26** (owner: "expand its lair in size", "larger piles of gold ... similar to ... the vault on
  Argynvostholt", "we dont need stronger minions", and the fight's tuning kept): the hoard hall (`hoard_hall`) is 49 squares
  wide instead of 26 (the map grew to 56 columns; nothing that stood there moved but the shackles, now on the new east
  wall), with ten drifts of gold coin (`gold_hoard`, the vault's coin heaps in gold, scale 2.4 to 3.2) and two more ember
  lights. Her Pounce, like every legendary move, provokes no Opportunity Attack at all, a Sentinel's included.
- Fights on the way down: the keepers at the gate (`ghakis_keepers`: eight wights, three revenants and a helmed
  horror, waiting by the cart) and the vent gallery (`vent_fire`: a fire elemental at 150 HP, two flameskulls, the
  keepers who forgot the sluice, and three wights). The sharp autopilot wins each 5 of 8 at level 10.
- Rewards: a Potion of Fire Resistance in the drivers' box and one in the slush by the cart (Perception DC 14); the
  keepers' strongbox, 300 gp and two more; the captain's rack, the Dragon Slayer the count gave his keepers in case
  (rare); her hoard, 900 gp of real coin from forty years of tithes in among the lead, and the silver's Dragon Scale
  Mail (very rare); in the tithes, an Ioun Stone (Mastery) (legendary). Stills: `ghakis_shoulder` (the loading card) and `sq_sarkhaza` (her first meeting).

### The Mountain's Heart (`the_mountains_heart`, narrative/mount_ghakis/the_mountains_heart.dialogue; batch 10, level 10)

Once her grandmother is back in her mound (The Barrow on Yester Hill), Freydis has news from home, from level 10: the
mountain folk's Grandfather Stone, the spirit asleep in Mount Ghakis who keeps the passes open, is walking. The count's
men cut a quarry in the mountain's south face last spring and dug out something that shone, and her cousins are up
there in chains cutting stone, one a week lost to the rockfalls. From level 10 the mountain folk's cairn at the
Tsolenka landing (a new examine prop) is cracked down the middle, with GRANDFATHER WALKS scratched at its foot. Either
puts the Ghakis Quarry on the travel map (data/locations/ghakis_quarry.json), two hours round the mountain from the
pass. **Twist:** Grandfather isn't raging; he's looking for his heart. The overseer crated it for the castle, ran when
the floor started walking, and chained the captives beside the crate as bait, so whatever came for the heart would eat
them first. **Escalation:** touch the crate and the quarry floor stands up. Then the heart goes back into the quarry
wall, or the party keeps it.

- **Boss: Grandfather Stone** (data/monsters/grandfather_stone.json, `source.book: custom`, built up from the 2025
  Monster Manual's earth elemental and drawn with its sprite at Huge, `art_height` 3.4): Huge elemental, AC 18, 207 HP
  (185 in this fight), vulnerable to thunder, two Slams (reach 10, 3d10+6), the Ground Shrugs (recharge 5-6, four
  creatures within 30 ft, DC 17 Dex, 4d10 and prone), Legendary Resistance (2/day), a Slam or a burrow between turns,
  and lair actions as the quarry's faces come down and the floor opens round someone's legs. CR 11. He comes alone.
- Fight `grandfather_stone` in the quarry, the Stone at 220 HP: the autopilot wins 5 of 8 at level 10 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Rewards: the overseer's pay chest under the wagon, 400 gp, either way. The heart carried home: the captive's
  father's Belt of Giant Strength (Stone Giant) (very rare). The heart kept: it cools into a Stone of Controlling Earth
  Elementals (rare), and the mountain folk leave without a word.

## Van Richten's Tower (level 10)

### The Name Over the Door (`the_name_over_the_door`, narrative/van_richtens_tower/the_name_over_the_door.dialogue; batch 5, an owner-asked boss)

Mordenkainen's "Heard anything interesting?", once Corvina's name is back and the party is level 10: Khazan, archmage to
the old kings, who built the tower on the tarn, never died ("his sort move downstairs"), and something under the tower
is getting fat on being remembered. In the tower hall a cold hearthstone with frost in its cracks (prop
`vrt_hearthstone`, shown from level 10 or once the quest is known) lifts on a stair (Investigation DC 13, or half an
hour) down to Khazan's undercroft (data/locations/khazan_undercroft.json): the stair foot, the hall of names, a crypt
the lake has got into, and his study. **Escalation:** the hall's books open and the people written in them come out;
in the study Khazan's book of names ends with Ezmerelda's, Van Richten's and, ink still wet, the reader's own.
**Twist:** he became a lich the cheap way. His phylactery is his name, cut over the tower door, which everyone who
comes in says to open it; every one of them kept him. He tells the party if they've read the book, or Arcana DC 16
works it out. **Second twist:** without his name he doesn't know who he is, and asks to hear it once more.

- **Boss: Khazan** (data/monsters/khazan.json, `source.book: custom`, built down from the 2025 Monster Manual's lich,
  drawn with Exethanter's sprite): Medium undead, AC 18, 190 HP, two Eldritch Bursts (+10, 4d10 force) or a Paralyzing
  Touch and a burst, Fireball and Lightning Bolt twice a day, Cone of Cold and Hold Monster once, Disrupt Life,
  Legendary Resistance (3/day), a burst, a step or Disrupt Life between turns, and his undercroft on initiative 20
  (every name he knows, whispered; the cold of the lake overhead). CR 14.
- **A phased fight.** While the name stands (`khazan_named`): 210 HP, two Visitors (specters), his lair; he can't be
  destroyed, and below 30 HP he comes apart into dust that goes up through the ceiling toward the door (`withdraw`,
  `khazan_withdrawn`). The autopilot drives him off 5 times in 8 at level 10 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
  Unmade at the door (Athletics DC 16, or chisel it out over a day), he forms again in his chair without it
  (`khazan_unmade`): 125 HP, four Visitors and a remembered knight (a wraith), no lair, no way back; given his name to
  die with, he starts the fight surprised. The autopilot wins 6 of 8, the easier fight for unmaking him. A party that works it out first can unmake the name before
  they ever fight him.
- The hall of names (`remembered`): a banshee, five ghosts, five specters and three wraiths. The sharp autopilot wins 5
  of 8 at level 10.
- Rewards: Bracers of Defense (rare) in the drowned crypt's silt (Investigation DC 16); his coffer, once he's gone,
  800 gp, a Wand of the War Mage, +3 (very rare) and his Robe of the Archmagi (legendary). Still: `sq_khazan` (his first meeting).

### The Drowned Library (`the_drowned_library`, narrative/van_richtens_tower/the_drowned_library.dialogue; batch 10, level 9)

Once Khazan is unmade (The Name Over the Door), Mordenkainen's news is a dream of a small voice coming up a well,
asking him not to come down; and from level 9 an old well-head on the shore of Lake Baratok (a new examine prop by
the tower) whispers the same: don't come down, don't read anything, don't touch the desk. A gated exit down the
well-shaft opens on the Drowned Library (data/locations/drowned_library.json), Khazan's library cut into the rock
under the lake, half flooded. On top of the furthest bookcase, Xaver (new NPC, the nothic's sprite): Khazan's last
apprentice, three hundred years down there and gone to a nothic from hunger for what he couldn't read. **Twist:** the
whispering thing in the dark is the frightened one. The predator is the great catalogue desk, which has eaten eleven
readers and filed their things (Insight DC 13: his eye never leaves it). **Escalation:** open one drawer and every
drawer opens, and the reading chairs stand up. Van Richten, Ezmerelda and the tower's own plot are never read or set.

- **Getting down (Ashwin, 2026-10-19: "How to climb down old head well to reach drowned library?").** Examining the well-head
  (prop `vrt_wellhead`, level 9 and up) starts the quest at `asked` and offers "Climb down the well-shaft." (five minutes,
  then the library's `from_shore` spawn) or "Leave it be."; the shaft square beside it (exit `vrt_well_down`, open once the
  quest has begun) still leads down on its own. The exit carries `sets_quest` (a new exit field, data/schemas/location.schema.json,
  `LocationWalk._exit_moves_quest`), so walking straight down also moves a `rumored` quest to `asked`.
  tests/integration/test_well_climb.gd.
- **Boss: the Index** (data/monsters/the_index.json, `source.book: custom`, built up from the 2025 Monster Manual's
  mimic and drawn with its sprite at Huge, `art_height` 2.4): Huge monstrosity, AC 14, 157 HP (135 in this fight), a
  Bite and two long Pseudopods that grapple, a Spray of Pages (recharge 5-6, three creatures, DC 15 Dex, acid),
  Legendary Resistance (2/day), a reach or a shift between turns, and lair actions as the shelves come down and the
  lake comes in. CR 9. Two reading chairs come with it (mimics).
- Fight `the_index` in the library, the Index at 185 HP: the autopilot wins 5 of 8 at level 9 (2026-10-13, retuned for the sharp test party to 5 in 8; the boss versions were retuned again on 2026-10-14 to 3 in 8 for the party at full ability, so the Hit Points and helpers below are the 5 in 8 ones: see docs/story/boss_fights.md for the current line-ups).
- Xaver comes down off his bookcase for the first time in three hundred years and gives the party the one book he
  saved: a Manual of Quickness of Action (very rare). The desk's drawers give up eleven readers' purses, 350 gp.

### The Hunter's Ledger (`hunters_ledger`, narrative/allies/ezmerelda.dialogue; Story Allies Presence Plan, package M2)

Ezmerelda d'Avenir keeps a book of the valley's killers, each with a price beside the name, and pays for proof: gold for the
six easier names and one magic item from her wagon for each of the seven hardest. It is the recurring reason to go back to her, not a test: there is no deadline, no penalty and no fight she
didn't see coming (a name she briefs is words only). Her hub, `allies/ezmerelda:talk`, carries the ledger and four
topics that each play once (Rudolph, her leg, the Vistani, and what she thinks of where the party is going; the hub
offers at most the three first, newest first). It opens from where she stands (one menu option each in her tower,
abbey and yard conversations, `ledger_door`) and from clicking her while she travels (`guest_talk` in
data/npcs/ezmerelda.json). The quest starts at `heard` the first time any of those opens it.

**The three names.** The ledger offers at most three of thirteen names at a time: first the kills the story recorded that
she hasn't paid for yet (oldest first), then hunts in the region the party stands in, then the hardest hunts the party's
lowest level reaches. A name the story can no longer end by a kill (Morgantha after the bargain or Bella's pact, the
Grandsire after Petru is given up, Kiril once he leads the pack, Lysaga after she was bought off or broken) is never
offered as a hunt. The kills are the flags the regions already set, so the ledger reads and never writes the story.

| Name | Flag read | Fought in | Named from level | Pays (once) |
|---|---|---|---|---|
| Dragan, the werewolf at Tser Falls | `falls_werewolf_slain` | svalich_road | 3 | 1,000 gp |
| The Tinker's Wagon | `wagon_slain` | svalich_road | 4 | 1,250 gp |
| The count's fowlers | `fowlers_slain` | lake_zarovich | 5 | 1,500 gp |
| The Vine Mother | `vine_mother_slain` | wizard_of_wines | 5 | 1,750 gp |
| Morgantha | `morgantha_slain` | old_bonegrinder | 5 | 2,000 gp |
| Wintersplinter | `yester_hill_resolved` | yester_hill | 6 | 2,500 gp |
| The Count's Huntsman | `huntsman_slain` | svalich_road | 7 | +1 Ring Mail (rare) |
| The Grandsire | `grandsire_slain` | krezk | 7 | +2 Battleaxe (rare) |
| Kiril Stoyanovich | `kiril_defeated` or `den_broken` (the reckoning) | werewolf_den | 7 | +2 Spear (rare) |
| Khazan | `khazan_destroyed` | van_richtens_tower | 7 | Sun Blade (rare) |
| Baba Lysaga | `lysaga_dead` | berez | 8 | +2 Greataxe (rare) |
| Sarkhaza | `sarkhaza_slain` | mount_ghakis | 9 | +2 Scale Mail (very rare) |
| The Eye Below | `eye_below_slain` | amber_temple | 9 | +3 Maul (very rare) |
| Dragan, the werewolf at Tser Falls | `falls_werewolf_slain` | svalich_road | 3 | 10 bolts |
| The Tinker's Wagon | `wagon_slain` | svalich_road | 4 | 3 alchemist's fire, 10 bolts |
| The count's fowlers | `fowlers_slain` | lake_zarovich | 5 | 3 holy water, 10 bolts |
| The Vine Mother | `vine_mother_slain` | wizard_of_wines | 5 | scroll of protection (plants), 3 alchemist's fire |
| Morgantha | `morgantha_slain` | old_bonegrinder | 5 | scroll of protection (fiends), 2 holy water, 2 antitoxin |
| Wintersplinter | `yester_hill_resolved` | yester_hill | 6 | 3 alchemist's fire, 6 +1 bolts |
| The Count's Huntsman | `huntsman_slain` | svalich_road | 7 | scroll of protection (undead), potion of resistance (necrotic), 3 holy water |
| The Grandsire | `grandsire_slain` | krezk | 7 | 10 +1 bolts |
| Kiril Stoyanovich | `kiril_defeated` or `den_broken` (the reckoning) | werewolf_den | 7 | 10 +1 bolts |
| Khazan | `khazan_destroyed` | van_richtens_tower | 7 | scroll of protection (undead), potion of resistance (necrotic), 4 holy water |
| Baba Lysaga | `lysaga_dead` | berez | 8 | 6 +2 bolts, 3 alchemist's fire |
| The Eye Below | `eye_below_slain` | amber_temple | 9 | scroll of protection (aberrations), 8 +2 bolts |
| Sarkhaza | `sarkhaza_slain` | mount_ghakis | 11 | 2 potions of resistance (fire), 8 +2 bolts |

**What she pays (Ashwin, 2026-10-19).** The old hunter's goods (bolts, holy water, scrolls, healing draughts by level) were
too slight for the names they paid for. The six easier names now pay gold, a thousand or more and growing with the name,
at any party level; the seven hardest pay one magic item each from her wagon, a lasting 2024 DMG item that nothing else in the
story hands out (tests/unit/test_loot_distinct.gd keeps each kind to one place), rare from level 7 and very rare for the two
level 9 names (rarity follows docs/story/found_magic_items.md: rare from level 5, very rare from level 9). The pick for each
name and why is below. The fourth name struck still brings her spare light crossbow (a +1 Light Crossbow, uncommon) and the
eighth a dagger (Mage Breaker, rare); each is the only one of its kind among the ledger's own gifts
(tests/unit/test_loot_distinct.gd; Dmitri Krezkov also sells a Mage Breaker from party level 5, so it is not one of a kind
in the story). The first payment warms her (`ezmerelda_trust` +1), the seventh moves the quest to `half_struck`, and the
thirteenth ends it (`ledger_struck`); after that the ledger option goes.

| Name | Why that reward |
|---|---|
| Dragan, the Tinker's Wagon | The first two names are the road's: 1,000 and 1,250 gp buy a party at level 3 or 4 a real kit (the wagon's own quest pays 300 gp more). |
| Fowlers, the Vine Mother, Morgantha | Level 5 hunts: 1,500, 1,750 and 2,000 gp, in the range of a rare item's shop price. |
| Wintersplinter | The last gold name, 2,500 gp, before the hunts that deserve steel. |
| The Huntsman | +1 Ring Mail (rare): heavy armour, AC 15 with no Dex limit to worry about, for a party in need of a better coat. |
| The Grandsire | +2 Battleaxe (rare): a martial weapon, versatile (1d8 or 1d10) with the Topple mastery. |
| Kiril | +2 Spear (rare): a simple weapon (thrown, versatile), so a Cleric or Druid can use it as well as a Fighter. |
| Khazan | Sun Blade (rare, attunement): radiant, a finesse longsword, extra damage against Undead and a light in the dark, for the lich's own cellar. |
| Baba Lysaga | +2 Greataxe (rare): the d12 weapon for a Barbarian or Fighter. |
| Sarkhaza | +2 Scale Mail (very rare): medium armour, AC 16 plus up to 2 Dex, at the level very rare items begin. |
| The Eye Below | +3 Maul (very rare): 2d6 two-handed with Topple, the last hunt's prize. |

**Closing the book short (sq-stuck, findings 133 to 135).** Kiril killed in the den's reckoning (`den_broken`, the "pack
broken" ending) counts as his death everywhere the ledger reads `kiril_defeated`. A party that has struck every name in
reach but spared some (Kiril left to lead the pack, Petru given to the Grandsire, Morgantha bargained with or Bella's pact,
Lysaga bought off or broken: the four the ledger never briefs) is offered the book's close when it opens the ledger at level 9
with nothing left to offer (`ledger_none` to `ledger_spared_close`). Closing it moves the quest to `ledger_closed`, a failure;
leaving it open changes nothing, and a name killed after all is paid as usual and can still bring `ledger_struck` (the quest
can move from the failure to that success). The `half_struck` hint no longer promises a ledger option on her road meetings,
which have none: it opens only from where she stands or by clicking her as a guest.

- Flags: `ezmerelda_ledger_paid` (how many are paid), `ledger_paid_<name>`, the gifts, the heard topics, and the working
  flags the picks use (`ledger_pick_*`, `hub_pick_*`, `ledger_named`, `ledger_ready`, `hub_slots`: recomputed on every
  visit, not state), all in data/flags/allies_ezmerelda.json. Stories are hers and use only the facts our data holds for
  each name.
- Lines: 87 spoken (Ezmerelda and the Narrator), drafted by Gemini through the ai-bridge and edited
  (docs/plans/gemini_allies/M2/), all unvoiced. The thirteen payment lines, her opening line and the quest's journal were
  redrafted by Gemini for the new payments (2026-10-19; docs/plans/gemini_ezmerelda_rewards/) and edited. Test: tests/unit/test_ezmerelda_ledger.gd.

## The Amber Temple (level 10)

### Exethanter's Notes (`exethanters_notes`, narrative/amber_temple/exethanters_notes.dialogue; NPC plan batch 5)

Exethanter, who forgets nearly everything, has five notes unpinned and out of order, and cannot recall what he was doing this
morning. Ask him (option in his menu): the party puts the scraps in order, choosing each next one (a wrong choice only earns a
mild correction and the same step again; an Investigation roll shows which was written first). The right order, read from the
notes alone, is water, fire, leaves, waiting, pouring: he was making tea. He makes a cup for the party in the cold temple.

- No fight and no roll that matters. Reward: Heroic Inspiration, companions' approval. Dialogue and data only: it touches
  no Amber Temple map.
- **Lost with him (sq-stuck, finding 129; the notes do not outlive the lich).** Smashing his phylactery (`lid_smash`) while the
  quest is open closes it at `lost`, a failure: the five scraps slide to the floor and stay out of order. Smash it first and the
  quest never starts, and his released talk (`smashed_after`) offers no notes.

### The Amber Debt (`the_amber_debt`, narrative/amber_temple/the_amber_debt.dialogue; batch 5, an owner-asked boss)

Exethanter, from level 10: under all the notes pinned to his sleeve is an old one in his own hand, "DO NOT GO BELOW THE
VAULT. YOU SEALED IT. YOU DO NOT REMEMBER WHY. THAT IS WHY." (an option added to his menu). In the vault a crack across
the floor weeps warm amber, and something deep in it blinks (prop `vault_weeping_crack`, shown from level 10 or once
the quest is known); under the slab (Athletics DC 15, or half an hour) a stair goes down to a lair the wardens sealed
under their own vaults (data/locations/amber_deep.json): the weeping stair, the hall of sleepers (travellers and
wardens in amber, one of them a month old), the wardens' archive and the chamber of the Eye. **Escalation:** the hall's
amber blinks back and the dreamed eyes come out of it. **Twist:** the wardens couldn't kill the thing that came up from
under the mountain, only sing it to sleep, and when the song stopped holding, Exethanter gave it his memory: while he
forgets it, it can't remember itself. Everyone who has helped him remember anything has been waking it.

- **Boss: the Eye Below** (data/monsters/the_eye_below.json, `source.book: custom`, from the 2025 Monster Manual's
  beholder, with its own sprite from the beholder's turnaround): Large aberration, AC 18, 180 HP, flies, a Bite and
  two eye rays a turn from six (Paralyzing, Fear and Amber, which Restrains; Enervation, Disintegration and
  Telekinetic), Legendary Resistance (3/day), a glare or a drift between turns, and a lair on initiative 20 that
  dreams up eyes (dream-gazers, at most two at once) or sets the amber round a foe's feet. Its great eye is still
  clouded with amber, so no antimagic cone. CR 13. New creature: the dream-gazer (data/monsters/dream_gazer.json,
  from the gazer, the beholder's sprite small with `art_height`).
- **Lair tricks** from the wardens' book: **the mirrors** in the hall turned toward its chamber, and its dreamed eyes
  fight their reflections (no lair, no gazer beside it); **the lullaby** sung to the end (Performance DC 15, one try),
  and it starts the fight half back in its amber (surprised, 100 HP). As it is it fights at 135 HP: the autopilot wins
  5 of 8 at level 10 (2026-10-13, retuned for the sharp test party: the owner's 5 in 8 on Balanced), and more with the wardens' ways.
- The hall of sleepers (`dreamed_eyes`): two woken amber golems (one at 130 HP) and ten
  dream-gazers. The sharp autopilot wins 4 of 8 at level 10, the harder side (with four gazers, 6).
- Rewards: its hoard, 700 gp, a Spellguard Shield (very rare), the wardens' shield made against it, and a
  warden's Ring of Spell Turning (legendary). Telling
  Exethanter it's dead lets him burn the old note. Still: `sq_eye_below` (its first meeting).

## Yester Hill (level 7)

### The Druid Who Came Back (`the_druid_who_came_back`, narrative/yester_hill/the_druid_who_came_back.dialogue; batch 5)

Davian's "Heard anything interesting?", once the Black Row is under way and the Gulthias tree has burned (level 7): a
lantern goes round and round the burned crown of Yester Hill at night, like somebody digging. **Escalation:** someone
came back to plant on it, by night only (`hours`): Mother Ruxandra, if the party spared her ("the tree will call me
back"), with a cutting she carried against her skin; else Kostin, if he walked away from the hill doubting, with a
clean young tree from a valley where the trees only drink rain; else Zorica (new speaker), the circle's youngest, who
was on the Krezk road the night it burned. **Twist:** whatever is planted, the old tree's roots under the hill take
it, and Wintersplinter's ash stands up round it as the Ash Effigy, which fire can't hurt now: it has burned once.
Kostin stands aside (and stays to keep the hill afterwards); Ruxandra fights beside it; Zorica fights unless talked
down (Persuasion DC 15, one try).

- **Boss: the Ash Effigy** (data/monsters/ash_effigy.json, `source.book: custom`, built up from the tree blight, drawn
  with its sprite at Huge): Huge plant, AC 15, 175 HP (below level 8, 150, or 155 with Zorica or Ruxandra beside it; at
  level 8, 190 alone with four embers, 205 with a druid beside it), two Ash Fists (reach 15), Choking Ash (recharge 5-6, a 30-ft cone, DC 16 Con, necrotic and
  Blinded), Regeneration 10 that cold stops, immune to fire and vulnerable to cold, Legendary Resistance (2/day), and
  a fist or a step between turns. CR 8. Embers (twig blights) crawl after it.
- Fight `ash_effigy` on the crown (my entries on data/locations/yester_hill_gulthias_tree.json). The test party,
  playing as the owner does, wins 5 of 8 at levels 7 and 8 with Zorica or Ruxandra beside it (five embers at level 7,
  four at 8), and 6 of 8 at level 8 alone, a little easier as Kostin's doubts earned (the owner's 5 in 8 on Balanced,
  2026-10-13). (Retuned again on 2026-10-14: the boss fights are now 3 in 8 for the test party at full ability, so the Hit Points and helpers in this note are the 5 in 8 ones; the current line-ups are in docs/story/boss_fights.md.)
- Reward from Davian: 300 gp and Daern's Instant Fortress (rare). Still: `sq_ash_effigy` (it standing up).

### The Barrow on Yester Hill (`the_barrow_on_yester_hill`, narrative/yester_hill/the_barrow.dialogue; batch 7)

From level 7, Freydis of the mountain folk (new NPC) sits at the foot of the hill with a spade and two sacks. Her
people from the Balinoks buried their dead in the stoneless mounds there for longer than the count has had teeth; the
druids dug them up and stacked the skulls in cairns up the barrow slope. She wants her grandmother, Silverjaw, the
skull with the silver wire through its jaw, and can't go up herself without killing druids. History DC 13 warns that
bones bound into a cairn are set to watch. **Twist:** the first the druids bound, the one at the head of the watch, is
Silverjaw. **Escalation:** lifting her skull from the cairn (a new examine prop on the slope) wakes the whole watch.
The quest never sets or changes a druid, Wintersplinter or gem flag; it reads `yester_hill_resolved` for one line.

- Fight `hill_watch` on the slope: Silverjaw (a wight at 140 HP) with barrow-wardens (wights) and the hill's watch
  (ghouls). Unwarned, the party is surprised, against three wardens, five ghouls and a
  ghast: the sharp autopilot wins 5 of 8 at level 7. Warned, four wardens and three ghouls and no surprise: 3 of 8.
- Freydis lays her grandmother in the oldest mound facing the mountains and sings her in (tell her what got up, or
  spare her). Silverjaw's Blood Amulet (rare) and 150 gp.

## Ireena's errands (any refuge; Story Allies Presence Plan, package I2)

Ireena Kolyana is kept out of the fights and left at a refuge (the Blue Water Inn, St. Andral's, the Krezkovs' house), in
her father's mansion if the party would not take her, or on the road beside them. These are the reasons to go back to
her, each a small errand that moves her toward knowing who she is. Her check-in (narrative/allies/ireena.dialogue,
docs/story/ireena_checkin.md) gains one option, "There is something we wanted to speak with you about.", whenever one of
them is on offer; it opens `asks` in narrative/allies/ireena_errands.dialogue, a menu of what there is to talk about. The
hub's last offer node hands over to `prepare` there, which works out what is on offer and sets the `ireena_ask_*` flags
(recomputed before every menu; nothing else reads them). Every path comes back to the check-in's menu or ends the
conversation, and nothing here sets a story flag: only the side flags in data/flags/allies_ireena.json and the two quests
below move. Ignoring her costs only the chance: nothing is lost by not asking. The door for every errand is the check-in
at the place she stands (a quest that began only from a guest click would not count for the reach test; the grave prop
carries the same file).

### Rosemary for Kolyan (`flowers_for_kolyan`, narrative/allies/ireena_errands.dialogue; Story Allies Presence Plan, package I2)

Once her father is buried, and while she shelters at the inn, the church or in Krezk (not in the mansion, where she can go
herself, and not on the road, where there is no village to send them to) and the party has not raised him, she asks the
party to lay a pressed sprig of rosemary on Kolyan's grave in the churchyard of the Village of Barovia and to tell her how
it looks. The grave prop (`kolyan_grave`, data/locations/village_of_barovia.json) now opens `allies/ireena_errands:grave`:
with the quest at `given` it plays the laying (Ismark is there if he stayed behind, so not when he guards her, is in Krezk or
travels with the party; if Speak with Dead was cast there, the Narrator recalls the voice and Kolyan has one remembered
line), and moves the quest to `laid`; in every other state it plays the old node (`village_of_barovia/kolyan:grave`)
unchanged, so raising him and Speak with Dead work as before. Back with her the party answers how the grave looks (the
plain truth, a kind lie she sees through, or that Ismark was there) and she tells the one story about her father she has
never told (`done`). Reward: Heroic Inspiration for the party (`inspire party`; dialogue selectors cannot pick the current
speaker) and one point of `ireena_trust`. If Kolyan is raised before the sprig is laid she keeps it and the quest ends at
`alive`, also a success.

- Stages: `given`, `laid`, `done` (success), `alive` (success). No roll, no fight, no gold.
- Flags: `ireena_ismark_at_grave` (so the party can tell her he was there).

### What He Wants With Me (`what_he_wants`, narrative/allies/ireena_errands.dialogue; Story Allies Presence Plan, package I2)

When she has told the party her dream of the lake (the check-in's topic) and something has made her wonder (Tamsin showed her
the locket, the Abbot's candles, the falls, Marina's statue, the pool, the Tome carried, or a trip to Berez), the check-in's
talk option offers "You look as though you have something to ask us." She asks the party for what tells the story of the face
she wears: the book he wrote about himself, and anything else with her face (two voices, by whether she has been to the pool).
The party then reads the **Tome of Strahd** aloud to her (the item's codex text is our whole canon for it: the conqueror,
Sergei, Tatyana, the wedding day, the fall, "he chose all of it"; three hours pass; the Narrator ends on a door closing
somewhere far off, and no story flag is set, the item's own "Read it through" does that) and tell her about **Marina's
statue** in Berez (the word, the line under it, the face; if the party also went down to the vault, the girl on the bier).
Either order. When both are done (a statue she saw herself on the road counts) she says it plainly: she is not Tatyana and
not Marina, and he keeps what he loses (`knows`, `ireena_knows_tatyana`, one point of trust). If the rumour of the pool is
known (`the_pool_of_the_white_sun` at `rumored`) and she is not with the party, she then asks to be taken to Krezk, through the
existing rejoin nodes (`vallaki/ireena:rejoin` from the inn and the church, `krezk/ireena:rejoin` in Krezk,
`village_of_barovia/ireena:krezk` from the mansion). It never sets `ireena_pool_choice` or moves the pool's quest: the pool
stays the pool's.

- Stages: `asked`, `tome_read`, `statue_told`, `knows` (success). No roll, no fight.
- Flags: `ireena_tome_read`, `ireena_statue_told`, `ireena_knows_tatyana` (the finale, F1, reads the last), `ireena_wants_later`
  (the party put the ask off, so a pending first sword lesson is raised next time).

#### Sword lessons (no quest)

From the second check-in, with a Fighter, a Paladin or a Ranger in the party, or Ezmerelda along, Ireena asks to be taught
(she cannot be in the fights, so the one thing left is to know how to hold a blade when the fight comes to her). If the
party puts the first ask off, it can offer the lesson itself from the same menu ("Have you got a moment for another sword
lesson?"). Three lessons, one try per check-in, each half an hour: grip and footing (Athletics DC 11), reading an
opponent (Insight DC 12, a roll in the scene and not an option, so a miss spends nothing and the lesson is offered again
next check-in), then the party's choice for the last (one cut over and over, Athletics DC 13, or how to fall, Acrobatics
DC 13, with a quiet line she never explains). The best of the party rolls. A lesson that lands adds one to `ireena_lessons`
and one to `ireena_trust`; one that does not changes nothing and costs the afternoon. Ezmerelda has an aside in each when she
is along. The lessons change no numbers; the finale (F1) reads `ireena_lessons`.

- Flags: `ireena_lesson_asked`, `ireena_lesson_tried` (reset by every check-in), `ireena_lessons`.

#### His letters to her (no quest)

While she shelters (not on the road, not when he holds her), the vampire writes to her, three letters spaced by the story:
after his call at her window or the churchyard gate (`strahd_window` set), after the festival (`vallaki_backed`), and with the
dinner (`strahd_invitation`). She shows each one in the check-in's talk menu ("What is that letter in your hand?"), one at a
time and in order, and asks what the party would do (burn it, or keep it as proof). The third she says she burned
(`ireena_kept_letter`, set whether or not anyone notices: she kept it). The party can take her word, ask what it said, or
see through her (Insight DC 14): then she reads one line of it and tells them her secret, that some nights she wants to
lift the window latch, and asks them to stop her. A miss costs only the confession: the other answers are still there and the
secret stays hers (`ireena_secret_shared` adds one to her trust). The finale and her epilogues read the two flags.

- Flags: `ireena_heard_letter1`, `ireena_heard_letter2`, `ireena_kept_letter` (the third letter told), `ireena_secret_shared`.

- Lines: 106 spoken (Ireena, the Narrator, Strahd's six letter lines, Ismark's two and Kolyan's one at the grave, Ezmerelda's three
  lesson asides), drafted by Gemini through the ai-bridge and edited (docs/plans/gemini_allies/I2/), all unvoiced.
  Test: tests/integration/test_ireena_errands.gd.

## Spoken lines

New lines are unvoiced until the voice thread records them: polite_caller.dialogue and cut_after_noon.dialogue in full
(new speakers Teodor and Luca), townsfolk.dialogue's gossip and gravedigger_teodor nodes, bildrath.dialogue's
news_grigore node and his two added lines (the windmill), and arik.dialogue's rumors node. The Tser Pool camp:
grey_mare.dialogue in full (Radu, Luminita), and tser_camp.dialogue's two added Zora lines. Batch 2, Tser Pool:
called_by_name.dialogue in full (new speaker Nelu; also Big Tobar), tser_camp.dialogue's new Zora lines (Nelu) and its
nelu node. Batch 2, Vallaki: ribbons.dialogue and hunters_at_the_inn.dialogue in full (new speakers Szoldar and
Yevgeni; also Daciana, Watchman Dobre), townsfolk.dialogue's grumbler_who node and the added ribbon_refuse lines, and
martikovs.dialogue's new rumours lines (the hunters). Batch 2, Lake
Zarovich: bell_under_the_lake.dialogue in full (Old Nistor, Bluto) and old_fisher.dialogue's added option. The Gates:
last_muster.dialogue in full (new speaker Marshal Dragomir), tser_camp.dialogue's new zora_road lines (the riders) and
townsfolk.dialogue's new gossip lines (the riders). Vallaki:
cat_in_the_window.dialogue and black_roses.dialogue in full (new speakers Stella Wachter, Catalina and Pyotr Petrov; also
Ignat and Father Lucian), the new lines in gate.dialogue (news: Stella), martikovs.dialogue (rumors: the roses),
arasek.dialogue (roads: the windmill) and the polite_caller.dialogue sunrise line rewritten as a break in the mist. Krezk:
six_feet.dialogue in full (new speaker Zinaida;
also Old Mihail and Goodwife Petra), the new lines in townsfolk.dialogue (goodwife after the burial, gravedigger after it)
and arik.dialogue (rumors: "Mihail. Digs early."). lighter_than_it_should_be.dialogue in full (new speaker Sorin; also Anna, Dmitri, Ilya, Kasha and Old Pavel), the new
lines in krezk gate.dialogue (news: Ilya, the stolen children, the toys), kasha.dialogue (graves: the toys) and, on
sq-krezk, black_roses.dialogue's lines naming the third girl (Daria, renamed from Sorina). Batch 2, Krezk and
Berez: one_horned_billy.dialogue in full (new speaker Dragos; also Stelian) and townsfolk.dialogue's two new goatherd
lines (Stelian: the ring, and the ferryman). Batch 2, Vallaki
and the castle: toymakers_masterpiece.dialogue in full (Blinsky, Pidlwick II) and townsfolk.dialogue's new
marta_rumor node (Goodwife Marta: the jester). Batch 2, Krezk and
the abbey: clovins_audience.dialogue in full (Clovin Belview, Dmitri, Old Pavel, Watchman Lazar; Wren's interject),
gate.dialogue's two new news lines (the bucket, feast days) and townsfolk.dialogue's new carver line (Old Pavel: soup). Batch 3, Old
Bonegrinder: the_fourth_sister.dialogue in full (new speakers Mouse, Granny Ash and Goodwife Sarnov; also Ilinca) and
the village townsfolk.dialogue's new gossip lines (Vasile and Petre: the Sarnov woman, and three children again). Batch 3, the
Wizard of Wines: the_black_row.dialogue in full (Davian, Adrian; companions' interjects), hands.dialogue's two new
picker lines (Andrei) and davian.dialogue's two new menu options. Batch 3, the
crossroads: the_counts_huntsman.dialogue in full (new speaker the Huntsman; also Old Paraschiva and Gavril). Batch 3, the
abbey: mothers_ninth_improvement.dialogue in full (new speaker Mother; also Clovin and Wren's interject), Pavel's new
carver line and the watchman's new news line in Krezk (the roof). Batch 3,
Argynvostholt: the_squire.dialogue in full (new speaker Cosmin; also Sir Godfrey) and the Vallaki gate's new news line. Batch 3, the
Tsolenka Pass: the_frozen_pilgrims.dialogue in full (new speaker Mother Ecaterina; also Sergeant Valcu). Batch 4, the
Village of Barovia: the_burgomasters_hound.dialogue in full (Bildrath; companions and Ireena's interjects; Lupu
doesn't speak). Batch 4, the
crossroads by day: the_tinkers_wagon.dialogue in full (new speaker Iosif the Tinker; also Zora's three new lines). Batch 4,
Vallaki: the_ravens_ransom.dialogue in full (new speakers Bray and the Fowler; also Urwin and Danika). Batch 4,
Krezk: the_packs_runt.dialogue in full (new speakers Little Petru and the Grandsire; also the Krezk watchman). Batch 4,
Mount Baratok: the_mages_lost_pages.dialogue in full (Mordenkainen; the letters are Narrator). Batch 4,
Castle Ravenloft: the_unnamed_crypt.dialogue in full (new speaker Corvina; also Pidlwick II) and Mordenkainen's new
line in the_mages_lost_pages.dialogue. Batch 5,
Into the Mists: the_last_traveller.dialogue in full (new speaker Ilarion; also Goodwife Petra) and Old Mihail's new
gravedigger line in the village townsfolk.dialogue. Batch 5, Mount Ghakis: the_warm_snow.dialogue in full (new speakers
Sarkhaza, Doina and Petrache; also Sergeant Valcu's new log lines and the companions' interjects) and
narrator/mount_ghakis.dialogue. Batch 5, Van Richten's Tower: the_name_over_the_door.dialogue in full (new speaker
Khazan; also Mordenkainen's news and the companions' interjects) and narrator/khazan_undercroft.dialogue. Batch 5,
the Amber Temple: the_amber_debt.dialogue in full (new speaker the Eye Below; also Exethanter's old note and his
thanks, and the companions' interjects), narrator/amber_deep.dialogue, and Mordenkainen's new line in
the_mages_lost_pages.dialogue ("Corvina. I still say it every morning...", once he has thanked the party). Batch 5,
Yester Hill: the_druid_who_came_back.dialogue in full (new speaker Zorica; also Davian, Ruxandra and Kostin, and a
blunt interject). Batch 5,
the Village of Barovia: the_nursemaids_grave.dialogue in full (the Durst nursemaid, named Veta, and Old Mihail). Batch 5,
Vallaki and Lake Zarovich: one_lantern_too_many.dialogue in full (new speakers Old Sabin, Sandu and the Lantern Girl;
also the town guard) and gate.dialogue's news jump. Batch 6,
the Village of Barovia: the_oat_thief.dialogue in full (new speaker Agafia; also Bildrath and Parriwimple, and a kind
interject) and narrator/woodcutters_hollow.dialogue. Batch 6,
the Tsolenka Pass: the_last_egg.dialogue in full (new speakers Tibor and the Falconer; a blunt interject). Batch 6,
Vallaki: the_counts_portraitist.dialogue in full (Haralamb and the Count's Likeness, new speaker; a blunt interject) and
narrator/vallaki_painters_studio.dialogue. Batch 6,
Castle Ravenloft: escher_petition.dialogue in full (new speaker Querreth; also Escher, a blunt interject and
Godrick's and Liriel's) and Escher's two new greetings in spires_escher.dialogue ("My dawn-sellers..." and the
petition option). Batch 7,
Argynvostholt: the_silver_hoard.dialogue in full (new speaker the Gilded Knight; also Sir Godfrey, the Narrator, a
blunt interject and Godrick's) and narrator/argynvostholt_undercroft.dialogue, and Godfrey's new menu option. Batch 7,
the Tser Pool camp: the_dancing_bear.dialogue in full (Lavinia and Old Marin; a new NPC, Bujor, with no lines of his
own; Thistle's interject) and narrator/tser_woods_den.dialogue. Batch 7,
Yester Hill: the_barrow.dialogue in full (new speakers Freydis and Silverjaw; a blunt interject). Batch 7,
Mount Baratok: the_forgotten_storm.dialogue in full (new speaker the Forgotten Storm; also the mad mage and Mordenkainen,
the Narrator and a blunt interject), and the mage's two new menu options. Batch 8,
the Krezk road: the_waystone.dialogue in full (new speakers Lark and Yanko; also Clovin and the Narrator, and a kind
interject) and narrator/krezk_road_waystone.dialogue. Batch 8,
the Amber Temple road: the_guide.dialogue in full (new speakers the Guide, Remus and Floarea; also the Tsolenka
sergeant, the Narrator and a blunt interject) and narrator/amber_road_camp.dialogue. Batch 8,
Lake Zarovich: the_barons_island.dialogue in full (new speaker Ostap; also Old Nistor, the Narrator and a blunt
interject) and narrator/zarovich_reed_island.dialogue. Batch 9,
the Old Svalich Road: the_roadhouse_lantern.dialogue in full (new speaker Wenzel, the innkeeper's ghost; also Arik,
the Narrator and a blunt interject) and narrator/svalich_roadhouse.dialogue. Batch 9,
the Tser Falls path: the_spiders_gully.dialogue in full (new speaker Tsura; also Iancu, the Narrator and a blunt
interject) and narrator/ivlis_spider_gully.dialogue. Batch 9,
the Village of Barovia: the_goatherds_count.dialogue in full (new speaker Erno; also Goodwife Petra, the Narrator
and a kind interject) and narrator/barovia_high_pasture.dialogue. Batch 10,
Van Richten's Tower and Lake Baratok: the_drowned_library.dialogue in full (new speaker Xaver; also Mordenkainen,
the Narrator and a blunt interject) and narrator/drowned_library.dialogue. Batch 10,
Mount Ghakis and Yester Hill: the_mountains_heart.dialogue in full (new speaker the Mountain Captive; also Freydis,
the Narrator and a blunt interject) and narrator/ghakis_quarry.dialogue. NPC plan batch 1 (2026-10-18), the Village of
Barovia: the_fourth_rumour.dialogue in full (Vasile, Petre, Arik, Goodwife Petra, Bildrath); in townsfolk.dialogue the
gossip's nothing-new nodes and the wrong rumour, petra_correction, Petre's coat, Anca's letters and secret, and the
goat in the shop, the church and at the gate; indoor_folk.dialogue's Goodwife Viorica (candle, secret) and Goodwife
Sorina; customers.dialogue's Iulian and Lucia; arik.dialogue's three nothings; bildrath.dialogue's ledger;
parriwimple.dialogue's book; vistani.dialogue's nicknames; and the new back-room, confession, false-trail and
getting-the-flock-in nodes in the_oat_thief.dialogue and the_goatherds_count.dialogue. NPC plan batch 6 (2026-10-18), Castle Ravenloft: boyars_petition.dialogue, gogu.dialogue and last_chapters.dialogue in full (new
speaker Gogu; also the Boyar, the four ghost servants, the Steward, Fennimore and the Narrator); the wants and secrets of Lord
Thale, Sir Lothar Brandt, Lady Celestine, Helga Ruvak, the Steward and Lief Lipsiege; and the Dead Halberdier's toll. NPC plan
batch 5 (2026-10-18), Argynvostholt, the Tsolenka watch and the Amber Temple:
ottokar.dialogue and exethanters_notes.dialogue in full (new speaker Sir Ottokar the Late; also Exethanter, Vladimir Horngaard,
Sir Godfrey Gwilym, Cosmin, the Phantom Warden, the Phantom Watchman and the Narrator); the hearing nodes of the_squire.dialogue;
the Warden's reasons in mausoleum.dialogue and the Watchman's watchword in watch.dialogue. NPC plan batch 4 (2026-10-18), Krezk and
the lake, the winery and the den: silvius_cask.dialogue, sprig.dialogue and vadu_children.dialogue in full (new speakers Dana
and the rescued children Ioana, Zamfir and Codruta; also Old Silviu, Master Costel, Kip and the Narrator); the winery
hands in hands.dialogue; the riddle nodes of the_fourth_sister.dialogue (Granny Ash and Mouse); and, in Krezk,
profira.dialogue and dumitrus_visitor.dialogue in full (new speaker Madam Profira; also Dumitru, Fennimore, the
Krezk Watchman and the companions' interjects); in gate.dialogue the Watchman's refusals, his wish to say yes and the
burgomaster's list; in townsfolk.dialogue Stefan, Goodwife Rodica, Goodwife Sanda and Cezar; in pool_folk.dialogue Old
Simion and Widow Catrina; Ilarie's secret in trail_hunter.dialogue; the Belviews at the gate and the well; the by-day
nodes of the_waystone.dialogue; and the vote, crossings and hiding nodes of the_barons_island.dialogue. NPC plan batch 3 (2026-10-18), Vallaki: florins_grandson.dialogue, emanoil.dialogue and the_sun_cake.dialogue in full
(new speakers Emanoil, Leontina and Tudorel; also Old Florin, Goodwife Marta, Old Paraschiva, Vadoma, the Baron and the
Narrator); the forged-list, proof and hearing nodes in ribbons.dialogue; the Baron's decrees; Lydia's key; the Town Guard's
inspection of cheer; Anton, Old Smaranda, Gheorghe, Old Kolya, Master Costel, the Festival Herald, the Lockup Warden,
Gunther, Vadoma and Old Varvara; and Piccolo's admission in blinsky.dialogue. The Count's Portraitist (level 9) was not
reshaped: its boss fight is tuned to the sharp party and was left alone for the later batches. NPC plan batch 2 (2026-10-18),
the Tser Pool camp and the crossroads: stanimirs_fire.dialogue, radus_horse.dialogue, fennimore.dialogue and
costica.dialogue in full (new speakers Costica and Ambrose Fennimore); in called_by_name.dialogue the by-day nodes; in
grey_mare.dialogue the decoy nodes; in tser_camp.dialogue Dorina's pot, Zora's cord and Petru's blades; and one new
option in stanimir.dialogue.

Story Allies Presence Plan, package I2 (2026-10-18), Ireena's errands: narrative/allies/ireena_errands.dialogue in full (Ireena, Strahd's letters, Ismark and Kolyan at the grave, Ezmerelda's lesson asides, the Narrator).
