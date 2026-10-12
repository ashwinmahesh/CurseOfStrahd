# The camp (F16, lane 24)

A Long Rest out in the wild makes camp on the place's own map, near where the party stands, instead of only filling
a screen. The place's weather, light, music and visitors stay its own. Towns, villages, inns, houses and dungeons keep
the rest screen as it was.

## Where

`CampSite.is_wild` (story/camp_site.gd): an outdoor map whose board theme is forest, riverside, road, svalich_road,
wilderness, shrine_yard or camp, in a place that allows a rest. The fire goes on the reachable square within 40 ft of
the leader with its eight neighbours open and the most open ground round it. The ground must be open, within 5 ft of
the fire's height, and clear of the place's own things: props, containers, doors, ways out, lights, people, traps,
and areas a fight starts in. With no such square within reach, the rest happens on the screen as before.

## What's there

- The pieces (existing models, `camp: true` in the place's props for the visit): the campfire with a taller flame and
  a light, the stew pot and woodpile beside it, a bedroll behind each seat, and a tent and the packs at the back where
  there's room. `examine:camp_*` lines in narrative/narrator/camp.dialogue.
- The company round the fire, each facing it: the party, the companions waiting at camp (the bench, living), and the
  story's guests. Ratatouille stands at the stew pot. The leader walks about; the others stay where they sit.
- While the camp is up, the companions waiting at camp count as present for the story (`StoryState.camp_company`, not
  saved): `name:` conditions find them, their camp talks come up, and they see the choices made there
  (`Approval.witnesses`).

## Talking

Anyone who wants a word (`CampSite.talks`, the first talk in their camp file whose condition holds) has a speech bubble
over them, and the hover hint says "Thistle wants a word". Walking up to them (a click, or Talk in their menu) starts
it. Each companion has one word in the evening and one after the night. A romance talk is offered by the first of
the pair its condition names. Anyone else says what they're doing, in the Narrator's words: `camp:<id>`,
`camp:guest:<npc>`, or `camp:someone` and `camp:guest` for everyone else.

## The night

The camp's panel (ui/exploration/camp_bar.gd) and the rest screen both offer **Sleep (8 hours)**, which is the Long
Rest (story/long_rest.gd, the same rules as the screen's: 16 hours since the last, the place's risk, wards, Alarm).
An interrupted night gives a Short Rest's benefits, and then the night's visitors come out of the dark, 25 to 40 ft
from the fire, from more than one side (data/camp/night_visitors.json): a group for the region's land (forest, marsh,
mountain, castle) and the party's milestone level, a die picking among several. Those waiting at camp keep back from
the fight. Afterwards the party can try to sleep again. Each group is played to the end eight times by the test
autopilot at the lowest level it comes for (tests/integration/test_night_visitors.gd): the party wins most nights,
and pays for it.

A full night brings back what a Long Rest does. Then the Narrator says the night's line (`rest:long:<place>`,
`rest:long:<region>`, `camp:night`, `rest:long`), the region's dream, and `camp:morning`. Strahd may come in the
night, as after any Long Rest. Afterwards the panel offers **Change prepared spells**, counted from the list the
night ended with, and **Break camp**. Breaking camp packs everything away (`camp:strike`), and the party falls in behind its leader. Leaving
the place, or anything that builds it again, ends the camp too.
