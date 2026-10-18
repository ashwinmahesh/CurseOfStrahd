# Daern's Instant Fortress

The 2024 Dungeon Master's Guide's item (rare, wondrous, requires attunement): a 1-inch adamantine statuette that a
Magic action sets down on the ground and grows, at its command word, into a square adamantine tower 20 feet on a side
and 30 feet high, arrow slits in every wall and a battlement on top. Two floors inside, a ladder, staircase or ramp (the
owner's pick) between them, a trapdoor to the roof. One door at ground level on the side that faces you, opened only at
your command (a Bonus Action; Knock and the like can't). Creatures and loose objects where it appears are pushed clear.
Roof, door and walls have AC 20 and 100 Hit Points, are immune to Bludgeoning, Piercing and Slashing damage except from
siege equipment and resist everything else; only a Wish spell repairs it. Repeating the command word shrinks it back, but
only if nobody is inside. Ashwin's todo (2026-10-17): "It should spin up a fortress in the overworld that can be entered."
(Before this the item only gave a Long Rest from the inventory and built nothing.)

## What the game does

- **Raise the fortress** (the item's first power; story/field_items.gd `instant_fortress`, story/fortress_site.gd): out of
  doors only (a map with `outdoors` that isn't a dungeon's open-air stonework: not a castle's roofs, nothing under a
  roof). The plot is the nearest 4 x 4 block of open squares to the leader on level ground or a gentle slope (at most
  10 ft across; the tower's footing makes up the difference and the door is a step at most from the ground in front of
  it), clear of the place's things (props, containers, doors, exits, lights, people, traps) and of anyone's feet, with
  the square in front of the door free and nothing the party could reach cut off. A fight's start area doesn't count:
  the tower is only walls. The door looks south when it can (the opening camera looks north), else east or west,
  else north. No such plot (a lane three squares wide, a hillside, a crowded square): the card says there is no clear
  ground. This is the book's push-clear rule made a plot choice, so nobody stands where it grows.
- **It stands on the map**: the squares are walls to walking, sight and the fights on that map; the tower is drawn over
  them (world/look/fortress_tower.gd), dark adamantine plates, arrow slits, a toothed battlement and the door lit along its
  seam, and it opens a round window onto the party when it stands between them and the camera, as the walls do (SeeThrough). It rises out of the ground when raised. It is kept in
  `StoryState.flags["_fortress"]` ({at, cell, door, front, looks, by}), so it is there when the party comes back, in a
  save, and while the party is inside.
- **Walk in at the door** (or click the tower): the exit leads to `daerns_fortress`, the ground floor. A stair along the
  east wall (the 2024 text lets the owner choose a ladder, staircase or ramp) goes up to `daerns_fortress_upper`, the
  sleeping floor; its trapdoor goes up to `daerns_fortress_roof`, the battlement. Their way out is the door, which leads to
  the map the tower stands on, at the square in front of the door (`LocationView.create` lays this over the maps'
  data: story/fortress_site.gd `overlay`).
- **Fold the fortress** (the second power): from outside, on the map it stands on, with nobody inside (the party in any
  of its three maps counts). The squares are open again. The statuette itself never leaves the holder's pack (the
  item's powers are used from there); leave the map and the tower stays where it is: the second power is refused "out
  of earshot" until the party is back, and a second tower can't be raised meanwhile. Nothing in the game attacks the
  tower, so its Hit Points and Wish are in the item's text only.

## Resting inside

The book says nothing about resting in it, which makes it the safest shelter the party can carry: the door opens only
at its owner's word, and a Long Rest needs only that no hostile creature gets in. The game's rest rules apply as they do
to any place: plain rests only where they are safe (an inn, a booked room, a safe place), a camp everywhere else.

- `daerns_fortress` and `daerns_fortress_upper` are `rest: safe`: the rest screen's plain Long Rest, never interrupted
  by the 1-in-6 (`LongRest.take`), the 16 hours since the last Long Rest still apply, and a visit of Strahd's that may
  come to blows still can (he comes as mist through an arrow slit, as the test_night_rest case "even in Daern's
  Instant Fortress" always had it). The three maps are one building to `RestRules.building_of`, and have no enemies.
- `daerns_fortress_roof` is `rest: no`: open air thirty feet up.
- The item no longer gives a Long Rest from the inventory; the Rod of Security still does.

## Narrator lines

narrative/narrator/daerns_fortress.dialogue (`item:fortress:rise` and `:fold`, `enter:` for the three maps, three
`examine:` props, `rest:long:` for the two floors) was drafted by Gemini through Ashwin's ai-bridge (2026-10-18) and
trimmed and corrected here (iron became adamantine, grass and mud went because the tower can stand anywhere, no
keyhole, no bolts). The brief and the raw reply are kept in docs/story/fortress/. None of these lines is voiced yet:
the voice thread voices them.

## Hooks (for the build thread)

LocationView.create (overlay on the view's copy of the location), LocationView._ready (stand), LocationMagic
.apply_spell_effect ("fortress_raise", "fortress_fold"), FieldItems (options, use, `instant_fortress`), the inventory's two
FieldItems.options calls (the live state), catalog `exits` rules, moods and `place_looks` for the three maps.
