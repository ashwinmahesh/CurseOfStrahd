# The camp (F16, lane 24)

A Long Rest makes camp on the place's own map, near where the party stands, instead of only filling a screen, wherever
the place's own rest is risky: the wild and the road, a town's or village's streets, a house, a church, a manor, a
dungeon. The place's weather, light, music and visitors stay its own. Only somewhere that offers a safe night keeps
the plain rest screen (the owner, 2026-10-12).

## Where

`CampSite.makes_camp` (story/camp_site.gd): the place's own `rest` is `risky`. It goes by the place's rule, not the
Story difficulty's safe rests: on Story the party still makes camp, and its nights are never interrupted. The rest
screen (addons/dnd_core/ui/screens/rest_screen.gd) keeps the plain Long Rest where:

- the place's rest is `safe`: the Blue Water Inn, the Blood of the Vine, the Wizard of Wines' winery, the Krezkovs'
  house, the Mad Mage's hut, Van Richten's tower, the Tser Pool encampment and the Pool of the White Sun;
- a room is booked for the night here (Services, the `_room` flag);
- in the tutorial, and for a capture's own party (RestScreen._view);
- `rest: no` places allow no rest at all, and the Rod of Security's rest is taken from the inventory, as before. Daern's Instant Fortress is a place now (docs/story/fortress.md):
  its ground floor and sleeping floor are `rest: safe` (the plain rest screen) and its roof is `rest: no`.

`CampSite.setting` says what kind of camp it is: **indoors** (the map isn't outdoors, or its theme is dungeon),
**wild** (an outdoor map whose theme is forest, riverside, road, svalich_road, wilderness, shrine_yard or camp), else
**town** (a village's or a town's streets: village, vallaki).

The fire goes on the reachable square within 40 ft of the leader with its eight neighbours open, a seat for everyone
and the most open ground round it. The ground must be open, within 5 ft of the fire's height, and clear of the place's
own things: props, containers, doors, ways out, lights, people, traps, and areas a fight starts in. With no such square
within 40 ft, the nearest one anywhere the party can walk to; failing that, a smaller camp, the most seats first
(fewer seats and bedrolls, the rest standing on open squares near the fire). Only where no square the party can reach
will take a fire at all does the rest happen on the screen, and its log says why: "No room to make camp here, so the
party sleeps where it stands."

## What's there

- The pieces (existing models, `camp: true` in the place's props for the visit): the campfire with a taller flame and
  a light, the stew pot and woodpile beside it, a bedroll behind each seat, and the packs and (out of doors) a tent at
  the back where there's room. Indoors there's no tent. `examine:camp_*` lines in narrative/narrator/camp.dialogue; a
  camp indoors or in town tries its setting's own first (the piece's `say`: `examine:camp_fire:indoors`).
- The company round the fire, each facing it: the party, the companions waiting at camp (the bench, living), and the
  story's guests. Ratatouille stands at the stew pot. The leader walks about; the others stay where they sit.
- While the camp is up, the companions waiting at camp count as present for the story (`StoryState.camp_company`, not
  saved): `name:` conditions find them, their camp talks come up, and they see the choices made there
  (`Approval.witnesses`).

## The Narrator

camp:pitch, camp:night, camp:morning, camp:strike, `examine:camp_*` and the idle lines (`camp:<id>`, `camp:someone`,
`camp:guest:<npc>`, `camp:guest`) each try the setting's own trigger first (`camp:pitch:indoors`,
`camp:thistle:town`; CampSite.keys_for), then the plain one. A setting has a set of its own only where the wild's
lines speak of trees, woods, sky or open country; the lines that read right anywhere are repeated in it word for word,
so one voice clip serves both.

Every roster hero has idle lines of their own (`camp:<id>`, a test checks it, tests/unit/test_camp_idle_lines.gd): a hero with none says
`camp:someone`'s, which is for a custom hero. A guest has `camp:guest:<npc>` or the plain `camp:guest`; Izek has his own.

## Talking

Anyone who wants a word (`CampSite.talks`, the first talk in their camp file whose condition holds) has a speech bubble
over them, and the hover hint says "Thistle wants a word". Walking up to them (a click, or Talk in their menu) starts
it. Each companion has one word in the evening and one after the night. A romance talk is offered by the first of
the pair its condition names. The bubbles hide during a fight and go with the camp: a word not heard waits for the
next camp, or the rest screen after a Long Rest elsewhere, for as long as its condition holds. Anyone else says what they're doing, in the Narrator's words: `camp:<id>`,
`camp:guest:<npc>`, or `camp:someone` and `camp:guest` for everyone else.

**Guests ask too.** A story ally travelling with the party (a `guest:<npc>` in the conditions, `StoryState.guests`) sits
at the fire with the company, and a talk whose opening condition names `guest:<npc>` is offered while that ally is
along: the same bubble over her, "Ireena wants a word", one word each evening and morning, and the rest screen's button
after a Long Rest taken somewhere that keeps it. `CampTalk.who_asks` reads the condition for the first `name:<companion>`
or `guest:<npc>` it names who is here, in the order it names them, so a talk written for two people puts the one who
asks first; `CampSite.asker` gives the id the camp seats that person by, which is a companion's character id and a
guest's creature id, `guest_<npc>` (the key of `LocationCamp.people`, so the mark and the click find her). A guest's
talks go in `narrative/camp/<npc>.dialogue` like a companion's, each `talk_` node opening with its `if` (a companion's
file has at least two talks; a guest's or the Sunsword's, which asks through whoever carries it with `item:sunsword`, at
least one: test_every_camp_talk_opens_with_a_condition). Approval stays the companions': a guest has none, and an
`approve` line in her talk moves the companions who watch, as in any scene. A guest who isn't along asks nothing, and her
talks wait.

## The night

The camp's panel (addons/dnd_core/ui/exploration/camp_bar.gd) and the rest screen both offer **Sleep (8 hours)**, which is the Long
Rest (story/long_rest.gd, the same rules as the screen's: 16 hours since the last, the place's risk, wards, Alarm).
An interrupted night (an hour in) brings the night's visitors out of the dark before the rest's benefits: the party
fights with what it had when it lay down (the owner, 2026-10-13). They come 25 to 40 ft
from the fire, from more than one side, or 15 to 60 ft off where a cramped house has no room that far
(data/camp/night_visitors.json): a group for the party's milestone level and the lie of the land, a die picking among
several. A town's streets and indoors have their own (the file's `settings`: cutthroats, the churchyard's dead and
Strahd's spawn in town; rats, shadows and the dead, and a wraith indoors, never a wolf pack in a house; Castle Ravenloft's halls and roofs have the castle's own, bats and the dead and, from level 7, vampire spawn: `region_settings`); in the wild,
the region's land (forest, marsh, mountain, castle). Where none can be placed, the night is just restless, as the
rest screen's is: a Short Rest's benefits for the hour slept, and the party can try to sleep again. Those waiting at
camp keep back from the fight. Once it's won the party lies down again by itself and sleeps the night out, an hour
more for the fight (the 2024 rules' resumed rest; the 16 hours since the last don't stop it), and the morning
follows as after any night; with foes still waiting in the place, nobody sleeps again (story/long_rest.gd,
`LongRest.resume`; game root `_sleep_again`). A visit of Strahd's that may come to blows comes before the rest's
benefits too, and the night goes on the same way once he's gone. Each
group is played to the end eight times by the test autopilot at the lowest level it comes for, with the party as an
interrupted night finds it (half its Hit Points and half its spell slots spent, and nothing back, since the fight comes before the rest's
benefits), and is
tuned to be won exactly as often in those eight (seeds 1-8) as the owner set on 2026-10-13 18:05: 5 of 8 at every
level, for the sharp test autopilot that smites, opens with Spirit Guardians and throws Fireball as he plays
(tests/integration/test_night_visitors.gd, `target_wins`; a timeout would count as a loss, and fails the test besides).
Groups are played at levels 1, 4 and 7, each tuned to 5 wins. A change to how fights roll their dice can move a count, so the test allows one win either way (`DRIFT`): it
fails only when a group drifts by two or more, and then the group needs tuning again. Each group is also tuned to
cost the party 2 to 3 heroes down per win on average (printed by the test, not asserted, like the other fight series). The wild's groups are
played in an open field; the town's in the Village of Barovia and the indoor ones
in the burgomaster's mansion, from the camp the party makes on arriving there.

A full night brings back what a Long Rest does. Then the Narrator says the night's line (CampSite.night_keys:
`rest:long:<place>`, `rest:long:<region>`, `camp:night:<setting>`, `camp:night`, `rest:long`), the region's dream, and
`camp:morning`. A place's own night comes first (Death House's lives on `rest:long:death_house`), except that one
written for sleeping behind walls carries `[indoors]` and one for the open air `[not indoors]` (the Village of
Barovia's shutters, the abbey's cart shed, Argynvostholt's door, the Martikovs' house; Tsolenka's rock, Van Richten's
shore), so a camp where it doesn't fit passes over it to the camp's own. Strahd may come in the night, as after any
Long Rest. Afterwards the panel offers **Change prepared spells**, counted from the list the
night ended with, and **Break camp**. Breaking camp packs everything away (`camp:strike`), and the party falls in behind its leader. Leaving
the place, or anything that builds it again, ends the camp too.

## Rests elsewhere

In a safe place, under a booked roof and where no fire will go, the rest screen takes the Long Rest as before
(story/long_rest.gd for both). For an
hour after any Long Rest (`LongRest.MORNING_MINUTES`, `StoryState.morning`, not saved), opening the rest screen again
still offers the companions' words and the change of prepared spells, counted from the list the night ended with.
Strahd's night visit waits until the rest screen, or a talk started from it, is closed (game root `_strahd_holds`),
instead of closing it and taking the morning with it. Closing the screen with a word still waiting puts up a hint
("Thistle wants a word: open Rest (R) to talk"). The Rod of Security (from the inventory) and a night on Daern's Instant Fortress's floors take the same Long
Rest (the guests, the miles walked, the spells cast on waking), with the night's lines, the hint and Strahd's chance.
