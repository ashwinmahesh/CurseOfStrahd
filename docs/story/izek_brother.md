# Izek, her brother (Story Allies Presence Plan, package Z2)

Package Z1 (docs/story/izek_takes.md) is Izek while he does not know: he stands under her window and takes her to his room. This
package is what the book's Izek never gets and ours already chose: the party told him Ireena is his sister (`izek_told_truth`), he
left the Baron ("I'm done"), and then, until now, he vanished. He stays. He is somewhere the party can find him, he can watch her
door, and he can walk behind her.

**No story flag moves** beyond `strahd_window = "izek"` (a new value of a flag whose readers only ask whether it is set, or `taken`,
or `fight`: Strahd's attention, her first letter from him and the fight he withdraws from; none treats an unknown value
differently). Everything else is side flags (`data/flags/allies_izek.json`) and Ireena's trust.

## Where he is, stage by stage (`narrative/allies/izek.dialogue`, `data/locations/*.json` NPC entries)

| Stage | Where | When | What |
|---|---|---|---|
| The woods | `lake_zarovich_trail`, approach 6 | told, alive, not guarding, and not yet found or found less than a day ago | `woods`: digging with his bare scaled hand where he lost her. Ask what he is digging for; tell him Ireena asks after him; tell him what Emil saw. He says he will be at the burgomaster's grave tomorrow. |
| The grave | `village_of_barovia`, by `kolyan_grave`, approach 5 | a day after the first meeting | `grave`: he came to stand where the man who raised her lies. With Ismark in the party, the two big men measure each other and sit. Menu: let Ireena speak to him (if she is along), tell him about the rider, **go and sit by her door** (if she shelters), **walk with us** (if she is along). |
| Her door | the Blue Water Inn, St. Andral's, the Krezkovs' house, her father's mansion (declined) | `izek_guards_ireena`, she is there and not with the party, not held by Strahd | `guard`: a line for the place, then a menu: is there something you two haven't said (the three scenes), how is she, what Emil saw, the arm, the dolls, the castle. |
| The road | a guest (`data/npcs/izek.json`: `guest`, `guest_build` his own stat block, `guest_talk`, `guest_stays` while she is along) | she rejoins the party and he guards her | `with_her`: "She walks, I walk." A click opens `talk` (the arm, the dolls, the castle, the three scenes while she is along). Road lines in `narrative/banter/guest_izek.dialogue`. |

His whereabouts are discoverable through Ireena: her check-in news about Izek (package I1) now says a carter swears he is on the
lake trail with a spade, until the party has found him there.

**Where the plan and this differ.** The plan said he joins "once he knows the castle was there that night". Here he follows Ireena
whenever she rejoins the party (a guard who stayed behind in an empty room would be a loose end); what Emil saw changes what he says
(`talk_castle` waits for it) and nothing else. What Emil saw is set when the party hears Emil's account at the den
(`werewolf_den/emil:lake_night` sets `izek_rider_heard`).

## The three scenes between them (`sister_1`, `sister_2`, `sister_3`)

At her door (`guard`), at the grave when she is along, or by the camp fire when both travel with the party (`narrative/camp/izek.dialogue`:
Izek asks, three talks, each waiting for the one before), in order, each once, each adding one to Ireena's trust:

1. **The doll**: he gives her the first doll Blinsky ever carved. She says it has the scowl of a Vallaki turnip and keeps it.
2. **Their parents**: she asks; he has a hearth, a voice calling them in at dusk, a man's big hands. No names.
3. **The name**: he tells her what he shouted through the trees, **Viorela** (no other line in the game uses it). She chooses
   (`ireena_birth_name_kept`): "ireena" (Ireena only) or "both" (Ireena by day, and the other when it is only the two of them). The
   finale (F1) and the epilogue read it.

## Strahd at her window (`narrative/strahd/ireena.dialogue`)

While he guards her at the inn or in Krezk, the window scene has Izek awake in the doorway (his arm burns him awake) and a new first
option, **Let Izek take the window**: he puts himself in the casement, the vampire lord steps back from the heat ("The brother. How
very warm you keep her threshold"), and it goes on as any saved window does (`strahd_window = "izek"`, then `saved`: she comes
along or stays). Nothing else about the visit changes.

## Epilogues (`data/endings/strahd_destroyed.json`, `strahd_triumphant.json`)

Six slides each, topic `izek`, the first that holds: guarding with both names; guarding; told and alive; spurned and alive; dead
after the party knew; dead. None for an Izek the party never met.

## Not done

The plan's small errand for an Izek who died before Ireena knew (she asks for one doll from his chest to bury beside Kolyan) is not
built; her check-in already has her grief for him (package I1, `mind_izek`). It needs an item, a container entry and the grave's
dialogue, so it is better as its own small package.

## Lines

101 new unvoiced lines: `allies/izek.dialogue` 71 (Izek 46, Ireena 12, Narrator 12, Ismark 1), the road lines 9, the window scene
8, Ireena's hint 1, and 12 epilogue slides. Drafted by Gemini through the ai-bridge (`docs/plans/gemini_allies/z2/`), edited.
The line she joins on is the same text in two places (`with_her` and the mansion's `accept`), one recording.

## Tests

`tests/unit/test_izek_brother.gd` (21 tests): his places and when each holds (open floor too), the woods and the rider told from five
places, the grave (Ismark, the guard option only where she shelters, walking with her), her door in each place, the three scenes in
order and the name, the click's talk, joining her from every rejoin, the camp's three talks, his road lines, the window, the
readers of the window flag, Ireena's hint, the epilogues, and no story flag moves. `test_guest_lines.gd` lists him among the guests
who need lines.
