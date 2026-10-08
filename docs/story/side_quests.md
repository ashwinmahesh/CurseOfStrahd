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

## Spoken lines

New lines are unvoiced until the voice thread records them: polite_caller.dialogue and cut_after_noon.dialogue in full
(new speakers Teodor and Luca), townsfolk.dialogue's gossip and gravedigger_teodor nodes, bildrath.dialogue's
news_grigore node and his two added lines (the windmill), and arik.dialogue's rumors node. The Tser Pool camp:
grey_mare.dialogue in full (Radu, Luminita), and tser_camp.dialogue's two added Zora lines.
