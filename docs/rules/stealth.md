# Sneaking, noticing and Surprise (F7, lane 25)

How the game runs sneaking up on foes and opening a fight with Surprise, in our own words. The 2024 rules are the
source; the calls the rules leave to the DM are rows in deviations.md, and coverage.md lists what's tested.

## Turn-based exploring

Outside fights the player can switch exploring into rounds at any time: T, the Turn-based button on the hotbar, or
Exploring on the Settings page (one switch, kept in the player's settings, so a new place or the end of a fight starts
in rounds while it's on). Code: `addons/dnd_core/world/exploration/location_plan.gd`, panel `addons/dnd_core/ui/exploration/plan_bar.gd`.

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

Seventeen fights wait in plain view. Nine always did: the frozen watch at the Amber Temple's doors, the catacombs' sleepers
by night, the coven at its cauldron, Ghakis's keepers, the Wachters' cellar cult, the tower's night visitors, the village's
dead at night, the werewolf den's guards and the wine cellar's dig. Eight were walk-in fights before overworld stealth: the
Abbey garden's scarecrows (`garden_sentry`), Castle Ravenloft's guardroom (`court_post_watch`), the east turret post
(`crg_turret_guard`), the jailers' guardroom (`larders_jailers`), the gargoyles of the champion's tomb
(`cat_gargoyle_watch`), of the north tower peak (`peak_guardians`) and of the front courtyard by night
(`crg_courtyard_gargoyles`), and Baba Lysaga's scarecrows (`berez_scarecrows`). Only the foes that stand in plain view show:
a foe marked `unseen` (what bursts out when the fight starts, and the extras a fight brings that are spread about the
place) has no figure, notices no one and comes when the fight starts. Yester Hill's wardens' camp and the winery's druids
stay walk-in fights: they waited once, and a party on the summit path or at the winery door was noticed from outside,
which forced fights nobody had walked into.

A waiting foe faces a way, and its figure shows it: its entry's `facing` (every foe in view of a fight that waits since
overworld stealth has one: `make validate` asks for it), else toward the middle of its group (gathered round a fire, a
cauldron, a dig), else toward the middle of its fight's area. Before a fight it notices a
party member within 30 ft (the maps are compact; at 60 ft foes noticed parties walking past) in one of two ways
(owner, 2026-10-07, after Baldur's Gate 3's sight cones):

- **It hears them** within 10 ft, whatever way it faces and whatever the light, unless a wall or a closed door is
  between them.
- **It sees them** inside its sight cone (120°, centred the way it faces), with the member not behind Three-Quarters
  Cover. Its passive Perception is 5 lower when the member stands in dim light as the foe sees it (Lightly Obscured
  gives Disadvantage on sight; Darkvision sees darkness as dim light and dim light as bright).

Either way, a sneaking party is noticed only when the foe's passive Perception is at least the member's Stealth total.
A foe that turns, or walks a route, turns its cone with it. Fights keep the 2024 rules, which have no facing.

Foes check after every square the party moves, and when it starts or stops sneaking. A foe that notices someone
starts its fight at once, and that fight surprises no one. Foes marked `surprise: enemies` (asleep, say) never notice.
Stepping into the fight's area starts it too, unless the party is sneaking and none of its foes notices it: see Slipping
past a waiting fight, below.

## Sneaking

Sneaking (V) has each member roll Stealth, keeping the total as the Hide action keeps its total: one roll a visit.
Stopping and starting again keeps the totals (no free reroll). They stand until the party leaves the place or an hour
has passed on the clock since they were rolled (a Short or Long Rest passes it, and so does any Wait, which is an hour
at least), and then the next look at one rolls again. A member without a total (a guest who just joined) rolls when one is asked for.
Nothing about the roll is saved: a load in the middle of a visit rolls again.

A party that walks out through an exit to another place while sneaking arrives there sneaking and crouched, with fresh
rolls (a new place, new rolls). Only the ways between places carry it: the travel map, a cutscene and a load start the
party walking normally. A fight whose area the party arrives inside starts as it always did, when the place is built,
before the party sneaks, so it surprises no one.

**The totals on the portraits.** While the party sneaks, each member's portrait on the exploring HUD (guests too) wears
their kept total, coloured by the moods of the sight overlay's eyes, for the foes in plain view (shown waiting foes that
can act, not ones asleep, `surprise: enemies`):

- **red** when some foe would notice that member even in dim light (its passive Perception minus 5 is at least the
  total);
- **amber** when only bright light would give them away (its passive Perception is at least the total);
- **plain** when none would.

Hovering the badge says what it means ("Stealth 7: the Wolf would notice them in any light"), and the controls card
(F1, the pad's Show controls) says it for the pad. Members who are down wear none.

## Slipping past a waiting fight

A fight that waits in plain view (a `waiting` encounter started by stepping into an area, with at least one foe that
isn't `unseen`) is a guarded room the party may fight, rob or pass by. It starts when the leader steps into its area,
unless the party is sneaking and no foe notices it:

- **Stepping in sneaking.** Each of the fight's foes that isn't asleep checks whether it notices any member, by the rule
  of every step (its sight cone, the 10 ft ring, light and cover, its passive Perception against the member's kept
  Stealth total). If one does, it starts the fight ("Wolf spots Ilse"), and nobody is surprised. If none does, nothing
  starts: "Unnoticed: the Wolf hasn't seen you". The foes stay where they are and keep checking every step.
- **Stepping in without sneaking** starts the fight as it always did. So does **stopping sneaking** while the leader
  stands in the area, whether or not a foe would have noticed them there. A fight whose foes are all `unseen` has no one
  to slip past: it starts on the step, however the party moves.
- **Slipping past.** When every member and guest who is up has left the area again, with the fight not started, the
  party has slipped past it ("Slipped past the Wolf"). In Experience mode that pays what winning the version the party
  would have met pays, once a fight (`Xp.talked_away`, `_xp/fight/<id>`: the 2024 DMG counts foes cleverly avoided as
  overcome), so fighting it later pays nothing more; in Milestone mode there is only the toast. Slipping past sets no
  flag and marks nothing done: the fight is still there, and starts when the party next steps in openly. A slip in
  progress isn't saved; a load forgets it.
- **Sleepers.** A foe asleep (`surprise: enemies`) notices nobody: a sneaking party steps in beside it and starts
  nothing, and a party that isn't sneaking starts the fight with the sleepers surprised, as the fight says.
- **Arriving.** A party that comes through an exit sneaking is sneaking when the new place looks at its areas, so it may
  slip into a fight's area where it arrives (the village square at night, the den's mouth), and a foe that notices it at
  the spawn starts its fight at once.
- **Guarded containers.** A container inside a waiting fight's area says so on its hover hint ("Guarded: taking from it
  where they'd see starts the fight"). Opening it asks the same notice rule of the leader (the kept total while
  sneaking, none when not): a foe that would notice them starts the fight and nothing is taken; if none would, the
  take goes through and the fight doesn't start. A sneaking party that slipped in can rob a chest the foes don't face.
- **Hover.** While the party isn't sneaking, a square inside the area of a waiting fight whose foes it can see says
  "Stepping in starts the fight; sneak to pass unseen". A fight the party hasn't seen gives nothing away.

Code: `LocationStealth.step_in`, `_check_slipped`, `start_guarded_here`, `guard_take`, `guarded_hint`;
`LocationFights._trigger_encounter` asks `step_in` before it starts an area's fight.

## Waiting and resting in sight

Wait (H) and the Short Rest both refuse while foes are in sight, and both ask who can see the party now
(`LocationStealth.foes_in_sight`): a waiting foe the party saw once keeps its figure, but it blocks nothing once no one
in the party can see it. While the party sneaks, a foe in sight that would notice none of the party (the same notice
rule, with each member's kept total) doesn't block either. A fight that waits only by night (a `when` of `night`) goes
with the dark: waiting through dawn drops its foes, as coming back by day does.

## Opening a fight

When the party opens a fight (an attack on a waiting foe, or stepping into the fight's area):

- **Surprise (2024):** if the party is sneaking, each foe that notices none of the party at that moment is
  surprised, which gives it Disadvantage on its Initiative roll. A party that isn't sneaking is heard coming and
  surprises no one. An encounter's own `surprise` (`party` or `enemies`) still decides when it's set.
- **Starting hidden:** a member nobody noticed, whose Stealth total meets the Hide action's DC 15 and who has
  Three-Quarters Cover from every foe, starts the fight hidden, with the Invisible condition from Hide: attacks
  against them have Disadvantage and theirs have Advantage, until they attack, cast a spell aloud, or a foe gets a
  clear view of them. Hiding ends with the fight.
- **Sneaking ends:** once the surprise and the hiding are read, the fight ends the party's sneaking: nobody stays
  crouched in it, and the party walks normally afterwards until the player chooses V again (a fresh Stealth roll if an
  hour has passed).

## Who can see you (U10)

While the party sneaks or explores turn-based, or while the player holds **L**, each foe in plain view shows the
squares it can see and wears an eye (`addons/dnd_core/world/exploration/sight_overlay.gd`, after Baldur's Gate 3's sight cones).
While the party sneaks or L is held, so does everyone standing in the place, since they would see a theft or a
trespass (below):

- **red** when it would notice one of the party who stepped into its sight even in dim light (always, when the party
  isn't sneaking);
- **amber** when only bright light would give the party away (dim light takes 5 off its passive Perception);
- **gold** when the party's Stealth beats it either way.

The squares each watcher covers are tinted on the ground in its eye's colour (a square several cover takes the most
dangerous): its sight cone out to 30 ft (in its line of sight, without Three-Quarters Cover) and the 10 ft ring it
hears all round. Hovering a square says when a foe in plain view, or (while sneaking) anyone here, would notice the
leader there (in turn-based mode the walk's ring turns red too), before anyone moves. Foes the party can't see yet
show no eye, and the warning never names them.

## Stealing and crime (F8) and the town watch (F2)

Code: `story/crime.gd` (the record), `addons/dnd_core/world/exploration/location_crime.gd` (the scene), the watch's dialogue in
`narrative/watch/`.

- **Who sees a crime:** anyone standing in the location who would notice the thief as a waiting foe would: within
  30 ft and in their sight cone (the way their figure faces) without Three-Quarters Cover, or within 10 ft by ear,
  and, while the party sneaks, with a passive Perception at least the thief's Stealth total. Behind someone's back
  and out of earshot, nobody sees a thing. A crime nobody sees costs nothing (the hint says "Nobody saw").
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
