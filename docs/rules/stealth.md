# Sneaking, noticing and Surprise (F7, lane 25)

How the game runs sneaking up on foes and opening a fight with Surprise, in our own words. The 2024 rules are the
source; the calls the rules leave to the DM are rows in deviations.md, and coverage.md lists what's tested.

## Turn-based exploring

Outside fights the player can switch exploring into rounds at any time: T, the Turn-based button on the hotbar, or
Exploring on the Settings page (one switch, kept in the player's settings, so a new place or the end of a fight starts
in rounds while it's on). Code: `world/exploration/location_plan.gd`, panel `ui/exploration/plan_bar.gd`.

- A round is six seconds; every ten rounds a minute passes on the clock.
- The player moves one party member at a time (whoever leads; 1-4, Tab or a click on a portrait picks them). Each
  member can move up to their Speed in a round. Difficult Terrain costs double, and so does passing through a
  companion's square, where nobody may stop (the 2024 rule for moving through an ally).
- Space (or End round) gives everyone their movement again. Guests stay where they are.
- Hovering the floor shows the walk as a trail with its cost against the leader's movement left; a red ring means
  too far for this round.
- Clicking a foe in plain view, the panel's Attack button, or Attack on a foe's right-click menu opens the fight from
  where everyone stands. A fight always rolls Initiative first (2024); nobody gets a free attack.

## Foes in plain view

An encounter marked `waiting` (started by stepping into an area) has foes standing where their fight puts them before
it starts. Each shows once a party member can see its square (the fight's own sight rules: walls and closed doors,
the light of the hour and the map, lamps and the lantern, Darkvision), and stays shown. Nobody walks through them.

A waiting foe notices a party member when all of these hold:

- the foe is up, and the member is within 30 ft of it (the maps are compact; at 60 ft foes noticed parties walking past);
- it can see the member, and the member doesn't have Three-Quarters Cover from it;
- the party isn't sneaking, or its passive Perception is at least the member's Stealth total. Its passive Perception
  is 5 lower when the member stands in dim light as the foe sees it (Lightly Obscured gives Disadvantage on sight;
  Darkvision sees darkness as dim light and dim light as bright).

Foes check after every square the party moves, and when it starts or stops sneaking. A foe that notices someone
starts its fight at once, and that fight surprises no one. Foes marked `surprise: enemies` (asleep, say) never notice.

## Sneaking

Sneaking (V) has each member roll Stealth once, keeping the total until the party stops sneaking (as the Hide action
keeps its total).

## Opening a fight

When the party opens a fight (an attack on a waiting foe, or stepping into the fight's area):

- **Surprise (2024):** if the party is sneaking, each foe that notices none of the party at that moment is
  surprised, which gives it Disadvantage on its Initiative roll. A party that isn't sneaking is heard coming and
  surprises no one. An encounter's own `surprise` (`party` or `enemies`) still decides when it's set.
- **Starting hidden:** a member nobody noticed, whose Stealth total meets the Hide action's DC 15 and who has
  Three-Quarters Cover from every foe, starts the fight hidden, with the Invisible condition from Hide: attacks
  against them have Disadvantage and theirs have Advantage, until they attack, cast a spell aloud, or a foe gets a
  clear view of them. Hiding ends with the fight.

## Stealing and crime (F8) and the town watch (F2)

Code: `story/crime.gd` (the record), `world/exploration/location_crime.gd` (the scene), the watch's dialogue in
`narrative/watch/`.

- **Who sees a crime:** anyone standing in the location who would notice the thief as a waiting foe would: within
  30 ft, in sight without Three-Quarters Cover, and, while the party sneaks, with a passive Perception at least the
  thief's Stealth total. A crime nobody sees costs nothing (the hint says "Nobody saw").
- **Owned things:** a container with an `owner` says so on its hover hint and when opened. Looking is free; taking
  anything from it while somebody sees is stealing.
- **Picking a pocket:** on a person's right-click menu. The leader makes a Dexterity (Sleight of Hand) check against
  the target's passive Perception (the 2024 rules leave the DC to the DM). Success lifts the coins their station
  gives (a noble's purse holds more than a farmer's) and anything their data puts in the pocket, once; anyone else who
  sees it makes it a crime. Failure, and the target catches the hand. The dead, spirits, Strahd's own and anyone
  hostile have no pocket to pick.
- **Private rooms:** an area with `private` (and optionally `open`, a condition such as `day`). Seen inside, the party
  is told to leave and has three more steps to do it; seen there after that, or after coming back, it's trespass.
- **Caught:** the victim's attitude drops a step (friendly, indifferent, hostile). In a town that keeps a watch
  (Vallaki and Krezk, `story/crime.gd` WATCH; a location may name another guard or none with `watch`), the offence
  counts in `crime_<region>` and a watchman comes at once: pay the fine (Vallaki 25 gp, then 50; Krezk 10, then 25),
  hand over what's in the purse, talk your way out (Persuasion or Deception DC 15 in Vallaki, Persuasion DC 15 or
  Intimidation DC 17 in Krezk; a failed check can't be tried again), or refuse and fight two of the watch. Paying,
  talking or the purse clears the count.
