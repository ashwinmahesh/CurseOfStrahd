# Ismark as a companion (Resume packages, Allies item 1)

Owner's ask (2026-10-21, "power up Ismark to match Ezmerelda"): Ismark Kolyanovich travels with the party as a guest (he joins
on the road west of the village, at the Vallaki gate and wherever Ireena rejoins). He fought as the town's Warrior Veteran (CR 3, 65 Hit Points), which left him
a passenger beside Ezmerelda (CR 8, 82 Hit Points, AC 17). He now fights as his own block,
`data/monsters/ismark_kolyanovich.json`, named by his NPC's `monster` and `guest_build.monster`
(`data/npcs/ismark.json`). Nothing else about him changes: the id of his creature in the party (`guest_ismark`), his sprite and
portrait, his dialogue and his reasons to stay (`guest_stays`) are as they were.

## The departures

A story ally's block is fixed (`StoryState.make_guest`): it never grows with the party, so these numbers are what he is at
every level he is along.

| | Warrior Veteran (what he was) | Ismark Kolyanovich | Ezmerelda d'Avenir (the mark) |
|---|---|---|---|
| Challenge Rating | 3 (700 XP) | 7 (2,900 XP) | 8 (3,900 XP) |
| Hit Points | 65 (10d8+20) | 90 (12d8+36) | 82 (11d8+33) |
| Armor Class | 17 | 17 (splint armor; Parry +2 against one melee hit) | 17 |
| Strength / Constitution / Charisma | 16 / 14 / 10 | 18 / 16 / 14 | 14 / 16 / 17 |
| Attacks a turn | 2 | 3 (Greatsword, or Heavy Crossbow for two of them) | 2 Rapier and a Handaxe or Shortsword |
| Greatsword | +5, 2d6+3 | +7, 2d6+4 | rapier +8, 1d8+5 |
| Heavy Crossbow | +3, 2d10+1 | +4, 2d10+1 | Fire Bolt +6, 2d10 |
| Proficiency Bonus | +2 | +3 | +3 |
| Saves | none fixed | Strength +7, Constitution +6 | none fixed |
| Alignment | neutral | lawful good (the book's) | chaotic good |

A full turn of blows (every attack hits) is 33 for him against 24 for her; she has Magic Missile, Mirror Image, Lightning
Bolt and Greater Invisibility besides. He is the one who holds the line; she is the one who changes the fight.

The 2024 Warrior Veteran is untouched: Vallaki's watch, the road's soldiers and every other fight still use it.

## Left alone

- Ezmerelda's own combat options (her spell list in the party's menu) and the camp lines some companions are missing are
  separate items on the same list. This package does not touch them.
- Gertruda stays a non-combatant while with the party; her item waits for the combat rules lane to land.
- Ismark has no new lines: nothing here is spoken, so nothing is drafted or voiced.
