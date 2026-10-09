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

## Into the Mists (level 1)

### The Last Traveller (`the_last_traveller`, narrative/into_the_mists/the_last_traveller.dialogue; batch 5)

The first side quest a new party can find: on the Old Svalich Road, at the edge of the fog the party came out of,
Ilarion (new NPC) sits on a stone in rags many years old and beautiful grey boots, asking what day it is. He went into
the fog last night to fetch a doctor over the mountains for his wife's fever, and it turned him round. **Twist:** his
night was fifty years; his little ones, Petra and Mihail, are Goodwife Petra who carries the water and Old Mihail the
sexton (Insight DC 11 sees the moss in his seams). **Escalation:** the moment he sets off, the count's wolves come out
of the fog for him.

- Fight `ilarion_wolves` on the road: level 1 five wolves, 250 XP (the autopilot wins 3 of 4 and loses two or three
  party members); level 2 six; level 3 a dire wolf leader and four wolves.
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
- Fight `teodor_errand` (village map, the east road by the churchyard gate): level 4+ the coachman (vampire spawn), 2
  Strahd zombies, 2 dire wolves, 2 swarms of bats (2,700 XP, High); level 3 the coachman at 60 HP, 2 Strahd zombies, a
  swarm (2,250 raw); below, the coachman at 45 HP with zombies. The coachman is an attention mark (`coachman`, +1).
- Rewards: Teodor's grave (container `teodor_grave`, opens once he tells you): 90 gp, 2 Potions of Healing, a Shield,
  +1 (uncommon). Heroic Inspiration for the party if he sees the sunrise.

### Cut After Noon (`cut_after_noon`, narrative/village_of_barovia/cut_after_noon.dialogue)

The woodcutters cut by noon. Grigore's son Luca stayed late and came home with a load of pale wood; he hasn't woken
since, and Grigore sold the load to Bildrath. **Twist:** it's blight seedwood (Nature DC 13 on the pile `late_wood` or
in Bildrath's storeroom; Medicine DC 13 finds the splinter in Luca's palm), and it wants the boy. **Escalation:** at
dusk the wood walks; Bildrath's load rolls up the street and the woodpile stands up. **The clever way:** get Bildrath's
load, talk Grigore into burning his winter (Persuasion DC 12 or 10 gp) and burn it all by day.

- Fight `woodpile_wakes` (dusk, Grigore's yard): level 4+ "The Woodpile" (shambling mound), 2 vine and 4 needle
  blights; level 3 the mound at 85 HP, 4 twig and 2 needle blights; below, blights only.
- Fight `woodpile_burns` (by day, the clever way): blights only, smaller.
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

- Fight `well_bride` (the well): level 3 Zinaida (banshee, her Deathly Wail drops anyone at 25 HP or less) and 2
  shadows (1,300 XP, High-ish with the wail); level 4 adds 2 specters; below, Zinaida at 40 HP and a shadow.
- Rewards: 60 gp in her silver coins and the charm she wore so the castle couldn't find her, an Amulet of Proof against
  Detection and Location (uncommon).

### The Burgomaster's Hound (`the_burgomasters_hound`, narrative/village_of_barovia/the_burgomasters_hound.dialogue; batch 4, level 2)

Bildrath's news gets a new topic: Kolyan's wolfhound, Lupu (new NPC, by the mansion door), howls every night at the
mansion's study wall, not at the wolves. Animal Handling DC 12 lets him lead the party to the study's cold corner (prop
`study_bricks`): new plaster over brick, dried garlic in the cracks, and something scratching on the other side.
**Twist:** a note in the mortar (Investigation DC 12): Kolyan's first son, Sergiu, let the thing at the window in during
the siege winter and came back hungry, and his father couldn't end it and walled him up. Lupu was Sergiu's dog.
**Escalation:** bless the bricks and seal them again (Religion DC 12: 60 gp in the desk, and the howling stops), or
break them open (Athletics DC 11) and face the Tenant with Lupu, who joins the party for the fight.

- Fight `hound_tenant` in the study: level 2 the Tenant (a ghast) and two starved servants (ghouls), 850 XP; level 3
  three servants; below 2 the Tenant at 24 HP and one. With Lupu, the autopilot wins 3 of 4 at level 2 and loses two
  party members a fight. It's the only side quest below level 3.
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

- Fight `oat_hunters` at her door: a werewolf ("A Pack Hunter") and a wolf at level 2, three wolves at level 3. The
  autopilot wins 2 of 4 at level 2 and 3 of 4 at level 3, losing one or two party members a fight.
- Reward: Agafia's grandmother's pair of speaking stones, Sending Stones (uncommon), one to keep and one for
  Parriwimple; and Bildrath decides it's charity.

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
  Elisabeth Durst (ghasts) and two robed ones (ghouls), unless the Dursts are already gone; then the robed one who
  carried Walter down (a ghast) and four more. The autopilot wins 4 of 4 against the Dursts and 3 of 4 against the
  robed ones at level 3, losing one or two party members a fight.
- Reward: her lucky stone, left on the lid, a Stone of Good Luck (uncommon). No still.

## The Tser Pool camp (level 4)

Talker: Zora ("Heard anything interesting?" is her old road question renamed). Radu's Nicu line now starts
`the_hanged_vistana` at `asked`, as Luminita's does.

### The Grey Mare (`the_grey_mare`, narrative/svalich_road/grey_mare.dialogue)

The black carriage that drives itself stopped by Radu's pen and left a purse; tonight Radu walked his grey mare,
Steaua, to the Ivlis crossroads. **Twist:** he didn't sell her for the money; the voice in the carriage promised Nicu
would ride home (Insight or Persuasion; if the party has seen the gallows they can tell him what that promise was
worth). **Escalation:** at the milestone she is being finished into one of the castle's black horses, a brand smoking
on her flank. Calm her (Animal Handling DC 14, one try, or a ranger, a druid, Animal Friendship), then break the brand
(Remove Curse, Protection from Evil and Good, holy water, or Religion DC 15, one try: "she hates priests"). Saved, she
bolts home and the carriage comes early; failed or left alone, she is black by midnight and fights for it.

- Props on the crossroads map: `grey_mare_milestone` (her, until the carriage comes) and `carriage_crossroads` (the
  carriage, until its escort is beaten). The pen's grey horse (`tser_horse_grey`) is gone while she's sold.
- Fight `carriage_escort` (east of the junction): level 4 the lead horse (nightmare), a wight footman, 2 specters, 4
  zombies (2,000 XP, High), plus Steaua as a second nightmare if she wasn't saved; level 5 adds a wight and a specter;
  below 4 the lead horse at 50 HP with specters and zombies. An attention mark (`black_carriage`, +1).
- Back at the camp Radu pays either way (`home` if she lived, given to Radu or Luminita; `mourned` if not): 120 gp of
  the castle's gold and a Rod of the Pact Keeper, +1 (uncommon).

### Called by Name (`called_by_name`, narrative/svalich_road/called_by_name.dialogue; batch 2)

Big Tobar's son Nelu followed his dead mother's voice toward Tser Falls (Zora's rumour, or Tobar). **Twist:** the voices
are will-o'-wisps in the gorge, feeding on grief and speaking in whatever voice brings you to the edge; Nelu is alive on
a ledge, and they've been calling his father in Nelu's voice. **Escalation:** at the falls after dark (prop
`gorge_voices` in the west glade) they call each companion by someone they lost (Godrick's Sir Pellam, Wren's Sorrel,
Thistle's grandda, Kip's Pip, Liriel's old teacher, Ratatoille's maman), and a Wisdom check (DC 14, the party's best)
decides whether someone is lured toward the edge, which starts the fight with the party surprised.

- Fight `falls_wisps` (the west glade): level 4 four will-o'-wisps (1,800 XP, High), level 5 five, below three.
- Then Nelu comes up (Athletics DC 13 on a rope, Misty Step or Spider Climb), and Tobar pays at the camp: 100 gp and an
  Efficient Quiver (uncommon). Nelu stays by the fire afterwards (`tser_nelu`).

### The Dancing Bear (`the_dancing_bear`, narrative/svalich_road/the_dancing_bear.dialogue; batch 7, level 3)

From level 3, Lavinia sits on the edge of the plank stage instead of dancing, with a broken chain across her knees:
Bujor (new NPC), the bear who has danced with her for nine years and never once pulled on his chain, broke it last
night and went up the deer path into the woods (Investigation DC 10: the link was pulled open, not cut). She gives the
party her tin whistle. The deer path (a new gated exit in the camp's north-west corner) leads to the old den
(data/locations/tser_woods_den.json, a new outdoor map with a vistas.json place). **Twist:** Bujor didn't run. He's
standing over a cub with its leg in a hunter's trap (the whistle calms him without a check, or Animal Handling DC 13),
and the trap has Old Marin's mark on it (Investigation DC 12): the black carriage pays a gold piece a pound for live
young. **Escalation:** opening the trap makes the cub scream, and the blights come out of the trees for the crying.

- Fight `den_blights` at the den: level 3 two vine blights, five needle blights and four twig blights (the autopilot
  wins 3 of 8, losing about three party members a fight); level 4 and up four vine blights, five needle blights and
  three twig blights (5 of 8).
- Then Bujor goes home to Lavinia's stage with the cub (he stands on the stage from then on), or into the den with it.
  Lavinia gives her grandmother's fan either way: a Wind Fan (uncommon) and 60 gp. Told whose trap it was, she sends
  the party to Old Marin, who confesses and pulls all eleven of his traps.

## Vallaki (level 5)

Talkers: the gate watch (gate:news, renamed) and Urwin (martikovs:rumors, renamed) wire into quests already built: the
bones start `bones_of_st_andral` and Arabelle starts `missing_arabelle` at new `rumored` stages, and the book club
starts `wachter_plot` at its own `rumored`. Arasek's road news (renamed "Heard anything interesting on the roads?")
puts Old Bonegrinder on the map. The watch adds Stella's rumour, Urwin the black roses.

### The Cat in the Window (`cat_in_the_window`, narrative/vallaki/cat_in_the_window.dialogue)

Lady Wachter's daughter Stella, locked in the bedroom at Wachterhaus, believes she's a cat. **Twist:** she isn't mad,
she's held (Insight DC 13, Arcana DC 14 or Detect Magic): at one of her mother's soirees she promised a stranger in
black she'd follow him like a cat follows cream, a black velvet ribbon with a silver bell holds the promise, and what
she sees, he sees; her mother ties the bow fresh every morning. **Breaking it:** Remove Curse (Liriel from level 6), a
Scroll of Remove Curse (Urwin's cellar, Vadoma, Rictavio, Lucian's services, or the scroll Lucian gives for her), not a
knife (cutting it rings the bell, an attention mark, and it ties itself again). **Escalation:** the master looks out of
her shadow one last time (`stella_shadow` in her bedroom).

- Fight `stella_shadow`: level 5 two wraiths ("The Master's Gaze", one at 50 HP) and 2 shadows (3,800 XP, High-ish);
  level 4 a wraith and 3 shadows (2,100, High); level 6+ two wraiths and 4 shadows; below, a wraith at 45 HP and 2
  shadows. Attention marks `stella_eyes` (+1) and, if the ribbon was cut, `stella_bell` (+1).
- Stella then goes to Father Lucian; in the vestry she gives 250 gp (her dowry), the Cloak of the Bat (rare; the
  master's present for her sixteenth birthday) and how the cellar panel at Wachterhaus opens.

### Black Roses (`black_roses`, narrative/vallaki/black_roses.dialogue)

Ilie the lamplighter's daughter Ana was taken last winter. **Twist one:** black roses come before a girl is taken, not
after, and they are on the chandler's step. **Twist two:** Ilie's scarf hides bite marks (Insight DC 13 or Medicine DC
12); Ana is the visitor and he has been feeding her so she won't go to anyone else. **The vigil:** at night Ana comes to
Mila Petrova's window in the lower town. Ask where she sleeps, talk her home to her grave (Persuasion DC 14), fight her
and the two girls she calls (`roses_street`), or let her go home to her father, who is found dead at the lake gate in
the morning (`ilie_fate` lost). **The grave:** three graves at the edge of St. Andral's churchyard (prop `ana_grave`):
dig them up by day (Athletics DC 12; they wake surprised and weak) or wait for them at night (`roses_graves`).

- Fights: `roses_street` at level 5 is Ana (50 HP), Irina and a swarm of bats; `roses_graves` by day has all three girls
  surprised at reduced HP, by night at full strength. Attention mark `roses` (+1).
- Rewards: Pyotr Petrov the chandler (by day in the lower town) pays 200 gp for Mila's life; Ilie gives Ana's mother's
  ring, a Ring of Resistance (Necrotic) (rare), once Ana is at rest.

### Ribbons (`ribbons`, narrative/vallaki/ribbons.dialogue; batch 2)

Daciana the ribbon girl writes down everyone who won't wear a festival ribbon ("it's not me who wants to know"); Anton in
the stocks points at her. She leaves the list under the lamp on Main Street at dusk (prop `ribbon_lamp`). **Twist:**
Watchman Dobre (lane 28's patrol) collects it and sells it three times: to the Baron's clerk (the stocks), to Wachterhaus
(her ladies visit whoever's in the stocks) and to a rider on a black horse at the west gate (the castle). **Escalation:**
the stake-out: follow him (Stealth DC 13) and catch the hand-off at the gate, or confront him at the lamp; Daciana can
leave the list blank to make the rider turn on him.

- Fights `ribbons_street` (Dobre and 3 of his lads, warrior veterans: 2,800 XP at level 5) and `ribbons_gate` (the same
  plus the rider and his man: 3,350); one more lad at 6+, one fewer below 5. Dobre leaves his beat once beaten.
- Daciana comes running after the fight: the satchel gives 250 gp of castle silver and an Arcane Grimoire, +2 (rare),
  and the lists go to Lucian and Urwin (the stocks empty), to the Baron (+100 gp, Dobre in his own stocks) or into the
  fire. Attention mark `lists` (+1).

### The Hunters at the Inn (`hunters_at_the_inn`, narrative/vallaki/hunters_at_the_inn.dialogue; batch 2, the book's pair)

Szoldar and his son Yevgeni (new NPCs in the Blue Water Inn's taproom; Urwin's rumour) offer half the Baron's 300 gp
for Old Greytooth. **Twist:** Arrigal pays Szoldar to bring strong strangers to the lake at dusk; the wolf is the castle's,
and the castle wants to see how you fight. Yevgeni says so (Persuasion DC 13, or a drink). **Escalation:** the hunt at
the Lake Zarovich landing at dusk (prop `greytooth_shore`), with Szoldar's bow on the rise behind the shacks unless he's
been turned (Intimidation DC 14) or left at the inn.

- **Boss: Old Greytooth** (data/monsters/old_greytooth.json, `source.book: custom`, drawn with the dire wolf's sprite):
  Huge, AC 15, 171 HP, two 2d10+5 bites that knock prone, a recharging howl (DC 15 Wis or Frightened), Legendary
  Resistance (2/day) and one extra bite a round as a legendary action. CR 8.
- Fight `greytooth_hunt`: level 6 Greytooth (150 HP), 2 dire wolves, 2 wolves; level 7 three dire wolves; level 8 adds
  a werewolf; Szoldar (bandit captain) on the rise unless dealt with, and he runs below 25 HP (`szoldar_fled`). The
  autopilot (tests/integration/test_side_quest_bosses.gd) wins about half its level 6 tries, losing three of four
  party members on the way. Attention mark `greytooth` (+1).
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

- Fight `raven_trap` under the pine: level 6 the Count's Fowler (a vampire spawn at 120 HP), a second fowler and 3
  swarms of bats, 3,750 XP; level 7 four swarms; below 6 the Fowler at 90 HP and two swarms. Surprised, the autopilot
  wins 2 of 4 at level 6 and loses two party members a fight. Killing them is a mark on Strahd's attention
  (`fowlers`, 1 point).
- Urwin's thanks, once: 200 gp and the mail his grandfather flew in, Elven Chain (rare).

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
  and Hold Person once a day, Legendary Resistance (2/day), and a look between turns. CR 8. Six copies come off the
  walls with it (guardian portraits at 30 HP).
- Fight `counts_likeness`. The autopilot wins 3 of 6 at level 9, losing three party members a fight.
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
  ghost, drawn with the wisp's sprite at a child's height, `art_height` 0.9): Small undead, AC 15, 90 HP, flies, two
  Cold Hands, a Lure that pulls a foe 20 ft toward her, Drowning Light (recharge 5-6, a 20-ft emanation, Restrained),
  Legendary Resistance (1/day), and a flicker between turns. CR 5. Two drowned lights (will-o'-wisps) come up with
  her.
- Fight `lantern_girl` on the jetty (my entries on data/locations/lake_zarovich.json). The autopilot wins 6 of 8 at
  level 5, losing about two party members a fight.
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
- Fight `tinkers_wagon` at the crossroads: level 5 the Wagon and 2 trinkets (mimics), 3,800 XP (the autopilot wins 2
  of 4 and loses three party members a fight); level 6 three trinkets; below 5 the Wagon at 110 HP and one.
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
- Fight `the_hunt` on the east road: level 8 the Huntsman, his mare (a nightmare) and 4 hounds (dire wolves), 6,500 XP,
  or 2 hounds once they're called (the autopilot wins 1 of 4 against the whole pack and 2 of 3 with the hounds called);
  level 9 six hounds (three called); level 10 eight (four called); below 8 the Huntsman at 130 HP with 3 hounds (1).
- Beating him is a mark on Strahd's attention (`huntsman`, 1 point).
- His saddlebag: 300 gp of quarry's purses and the iron ring he called the pack with, a Ring of Animal Influence (rare).

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

- Fight `squires_vigil` at the graves: level 8 the Gate Warden and two Knights Who Forgot (revenants) with 4
  men-at-arms (phantom warriors), 8,200 XP (the autopilot wins 2 of 4 and loses three party members a fight); level 9
  eight men-at-arms; level 7 one knight and five; below 7 the Warden at 90 HP and four.
- Godfrey writes Ioan's name right and Cosmin's under it, and gives the party Ioan's shield, left at the gate the night
  he rode: an Arrow-Catching Shield (rare), and 150 gp from the Order's chest. Not offered once the Order rests.

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
- Fight `gilded_knight` in the undercroft. The autopilot wins 3 of 8 at level 9 at full strength and 4 of 8 with the
  dragon's words, losing two or three party members a fight.
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

- Fight `drowned_landing`: level 8 the Bellringer (a wraith), the Lake's Undertow (a water elemental), 4 ghasts and 6
  ghouls (6,600 XP; the autopilot wins two of three and loses most of the party doing it); level 9 adds a second
  undertow and a drowned bride (a wight); below 8 a wight, 2 ghasts and 6 ghouls.
- Then cut the bell loose (Athletics DC 15, Water Breathing or the potion) or ring it once for the dead (Religion DC 14):
  200 gp of chapel silver and the drowned priest's Staff of Healing (rare).

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
- Fight `bone_marshal` at the gate: the whole column (level 6 the marshal, 2 lieutenants as wights and 6 skeleton riders,
  5,600 XP; level 8 a third wight and 2 phantom warriors; below 6 the marshal at 110 HP, one wight, six riders), or
  only the marshal and his lieutenants once the riders stand down. The autopilot wins 2 of 3 against the column at
  level 6 and 1 of 3 against the marshal and three lieutenants at level 8, losing three party members a fight.
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
- Fight `granny_ash` on the lane: level 6 Granny, 3 dire wolves ("Granny's Dog") and 4 needle blights (4,700 XP; the
  autopilot wins 2 of 4 and loses three party members a fight); level 7 adds 2 needle and 2 vine blights; level 8
  six needle blights and the hag garden's elm (a tree blight), 7,700 XP; below 6 Granny at 130 HP, one dog and 3
  needle blights.
- Endings (`mouse_fate`): `home` (named: Zamfira back with her mother, Ilka and Toma, on the step in the village),
  `keepers` (unnamed: Ilinca takes the girl with half-iron teeth) or `given` (the basket; the quest fails and the
  companions disapprove).
- Granny's basket: 300 gp and a Robe of Eyes (rare). The basket alone pays the 300 gp.

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
- Fight `vine_mother` at the foot of the row: level 6 the Vine Mother, 4 vine blights and 4 needle blights (4,500 XP; the
  autopilot wins 2 of 4 and loses three party members a fight); level 7 six vine and six needle blights; level 8 the
  same and the Sixth Row (a tree blight), 7,700 XP; below 6 the Vine Mother at 150 HP, 2 vine and 3 needle blights.
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
- Fight `rag_queen` in the field: level 9 the queen, 2 drowned brides (banshees) and 4 straw grooms (scarecrows), 8,900
  XP; level 10 a third bride, 2 more grooms and a swarm of insects; below 9 the queen at 200 HP, one bride and 4
  grooms. The autopilot wins 1 of 3 at level 9 and loses three party members a fight.
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
- Her eighth gift, which Clovin brings up to the wall: Boots of Levitation (rare). Afterwards she lands on Pavel's roof
  on Sundays, and Krezk's watchman has decided to be very calm about it.

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
- Fight `the_penitent` on the landing: level 10 the Penitent and 5 pilgrims' shadows (ghasts), 9,450 XP (the
  autopilot wins 2 of 4 and loses three party members a fight); level 11 eight shadows; level 9 four; below 9 the
  Penitent at 170 HP and three.
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
  150 HP), two of his hands (vampire spawn) and four stone birds (gargoyles). The autopilot wins 5 of 8 at level 9,
  losing about two party members a fight.
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
  6,800 XP (the autopilot wins 2 of 4 and loses two or three party members a fight); level 9 three werewolves; level 7
  one dire wolf fewer; below 7 the Grandsire at 140 HP with one of each.
- Krezk's bounty, from Dmitri: 300 gp and the iron bands that have hung in the watch house for the wolf that never
  came, Iron Bands of Bilarro (rare).

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
- Corvina's first ring, which he took off her desk the night they went up: a Ring of Telekinesis (very rare).

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
- Fight `corvina` in her crypt: level 10 Corvina and a door-warden (a helmed horror); named, she's down to 105 HP (the
  autopilot wins 2 of 3 named, 1 of 4 not, losing two to four party members a fight); level 9 and below, lighter.
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
- Fight `querreth` on the south tower roof. The autopilot wins 3 of 8 at level 10 caught unawares and 4 of 8
  forewarned, losing about three party members a fight.
- Then the party sits out the night with him and the sun comes up (`sq_escher_dawn`, a new still). Either he watches it
  and burns, and leaves a red velvet coat on the stones with the count's present in the pocket, or (Persuasion DC 15)
  the party talks him into waiting for a dawn the count isn't in, and he goes back down to his chair. Either way: a
  Helm of Brilliance (very rare, a crown full of captured daylight for a man who could never wear it) and 250 gp.
- Escher's suite, banter and narration follow him: once he's seen the dawn his chair is empty and his coats hang in
  the wardrobe without the red velvet one.

## Mount Ghakis (level 10)

### The Warm Snow (`the_warm_snow`, narrative/mount_ghakis/the_warm_snow.dialogue; batch 5, an owner-asked boss)

Sergeant Valcu reads the next entry in his log when he's asked for his report again (after The Frozen Pilgrims): smoke
on the north shoulder of Mount Ghakis, where nobody lives, snow that melts there in midwinter, and the count's black cart
going up every new moon with a cage on the back. There were faces in the cage this month. That puts the north shoulder
of Ghakis on the travel map (data/travel/mount_ghakis.json, a new region with its own loading card), two hours round
the gorge from the pass. **Escalation:** the count's keepers are unloading at an iron gate in the mountain, and the
cage holds his tithe, Doina and Petrache, charcoal-burners from below Krezk (new speakers); the keepers' log in their
post names what's inside. **Twist:** a red dragon, Sarkhaza (new speaker), who came through the mists forty years ago
after a dead silver dragon's gold and found the count waiting: chained by the neck, wings riveted shut, starved on
grave-salt, lying on the hoard she came for. She offers to burn the count out if the party pulls the pin from her
collar (Insight DC 16: she can't fly, and she means the villages below). **Second twist:** the hoard is gilt lead
(Investigation DC 15 before the fight, or after it), and under it, where she lay, is the silver's own coat of scales.

A mini-dungeon in two maps (data/locations/ghakis_shoulder.json, ghakis_lair.json): the shoulder and gate; then the
keepers' post, the larder, the anchor (the great drum her chain is wound on), the vent gallery and her cavern. The
keepers had three ways of going down to her safely, and each one is a lair trick that changes her fight:

- **Salt her meat** (the larder, Sleight of Hand DC 14; a bad job and she smells it): fed to her, she fights at 155 HP.
- **Haul her chain in** (the anchor's capstan, Athletics DC 17; one try): she starts the fight choking on the collar,
  surprised and 30 HP down.
- **Open the sluice** (the vent gallery): snowmelt drowns the cracks, and her lair can't act in the fight.
- Pulling the pin from her collar instead lets her loose at 215 HP, with no chain to haul.

- **Boss: Sarkhaza** (data/monsters/sarkhaza.json, `source.book: custom`, built down from the 2025 Monster Manual's
  adult red dragon, drawn with the draconic spirit's sprite at her own height, `art_height`): Huge dragon, AC 18,
  200 HP, Speed 20 and no flight, two Rends (reach 10, slashing and fire), Fire Breath (recharge 5-6, a 60-ft cone,
  DC 17 Dex, 11d6), Legendary Resistance (3/day), a Rend or a drag of her chain between turns, and her lair on
  initiative 20 (fire out of the cracks under two foes, or the roof coming down). CR 13. As she is, the autopilot wins
  1 in 4 at level 10 and loses three or four party members a fight; with all three tricks it wins 4 of 4 and loses one
  or two; unchained at level 11, 1 in 8.
- Fights on the way down: the keepers at the gate (`ghakis_keepers`: two wights and a helmed horror, waiting by the
  cart) and the vent gallery (`vent_fire`: a fire elemental at 150 HP and three flameskulls, the keepers who forgot the
  sluice). The autopilot wins both at level 10, losing about one party member a fight.
- Rewards: a Potion of Fire Resistance in the drivers' box and one in the slush by the cart (Perception DC 14); the
  keepers' strongbox, 300 gp and two more; the captain's rack, the Dragon Slayer the count gave his keepers in case
  (rare); her hoard, 900 gp of real coin from forty years of tithes in among the lead, and the silver's Dragon Scale
  Mail (very rare). Stills: `ghakis_shoulder` (the loading card) and `sq_sarkhaza` (her first meeting).

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
- **A phased fight.** While the name stands (`khazan_named`): 250 HP, two Visitors (specters), his lair; he can't be
  destroyed, and below 60 HP he comes apart into dust that goes up through the ceiling toward the door (`withdraw`,
  `khazan_withdrawn`). The autopilot drives him off 2 times in 4 at level 10, losing three party members a fight.
  Unmade at the door (Athletics DC 16, or chisel it out over a day), he forms again in his chair without it
  (`khazan_unmade`): 210 HP and two Visitors, no lair, no way back; given his name to die with, he starts the fight
  surprised. The autopilot wins 2 of 4, losing three a fight. A party that works it out first can unmake the name before
  they ever fight him.
- The hall of names (`remembered`): a banshee, two ghosts and six specters. The autopilot wins 3 of 4 at level 10.
- Rewards: Bracers of Defense (rare) in the drowned crypt's silt (Investigation DC 16); his coffer, once he's gone,
  800 gp and a Wand of the War Mage, +3 (very rare). Still: `sq_khazan` (his first meeting).

## The Amber Temple (level 10)

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
  and it starts the fight half back in its amber (surprised, 135 HP). The autopilot wins 2 of 4 against it as it is
  at level 10 (about three down, 10 rounds), and 3 of 4 with both (about two down).
- The hall of sleepers (`dreamed_eyes`): a woken amber golem at 130 HP and four dream-gazers. The autopilot wins all
  four at level 10, losing about one.
- Rewards: its hoard, 700 gp and a Spellguard Shield (very rare), the wardens' shield made against it. Telling
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
  with its sprite at Huge): Huge plant, AC 15, 175 HP (150 below level 8), two Ash Fists (reach 15), Choking Ash
  (recharge 5-6, a 30-ft cone, DC 16 Con, necrotic and Blinded), Regeneration 10 that cold stops, immune to fire and
  vulnerable to cold, Legendary Resistance (2/day), and a fist or a step between turns. CR 8. Embers (twig blights)
  crawl after it.
- Fight `ash_effigy` on the crown (my entries on data/locations/yester_hill_gulthias_tree.json). The autopilot wins 4
  of 8 at level 7 with Zorica beside it and 3 of 8 at level 8 against it alone, losing two or three a fight.
- Reward from Davian: 300 gp and Daern's Instant Fortress (rare). Still: `sq_ash_effigy` (it standing up).

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
cat_in_the_window.dialogue and black_roses.dialogue in full (new speakers Stella Wachter, Ana and Pyotr Petrov; also
Ilie and Father Lucian), the new lines in gate.dialogue (news: Stella), martikovs.dialogue (rumors: the roses),
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
own; Thistle's interject) and narrator/tser_woods_den.dialogue.
