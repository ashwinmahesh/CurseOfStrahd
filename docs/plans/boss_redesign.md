# Boss redesign plan (2026-10-26)

Owner's asks this plan follows (resume package, boss fights item 6, and the rules since): every boss gets a look, harder
**through damage, abilities, lair actions and Counterspell/Shield tactics, never Hit Points**; stat blocks may change;
one branch per boss or small group, easiest first. Fights keep the book's line-ups (2026-10-25), bosses fight at their
stat block's Hit Points (2026-10-26), and nothing is re-measured unless the owner asks (2026-10-25). Already in the game
for every boss: 25% harder hits, +1 to hit and DCs to level 4, +2 at 5-8, +3 from 9 (Balanced), legendary actions only
after a hero's turn, Legendary Resistance only against conditions and big no-damage spells.

New tools this uses (all on main or in the hand-off stack): `legendary_strikes` (a strike only a legendary option uses),
a teleporting legendary option with a burst (`teleport`, `ft`, `burst`), stat-block spell slots (`slots`, `prepared`),
a Reaction that casts Counterspell or Shield (`reactions[].cast`, the mage's Protective Magic), lair actions of the kinds
the engine runs (save + damage + condition, and the few specials), and fight-only `states` (the swarm-of-rats pattern).

## Done or waiting

| Boss | State |
|---|---|
| Brother Anatol | Vampire block, his hunger state (+1, 1d6 Necrotic). On main. |
| Sarkhaza | Bigger cavern, gold drifts, Pounce draws no Sentinel strike; tuning kept by the owner. Handed off. |
| Strahd | Unarmed Strike and Bite +14. Handed off. More below. |
| Khazan | His chosen CR 23 block is built, held: it wipes a level 10 party in round 1-2. Waiting on the owner's pick. |

## The plan, easiest first

**Group 1: legendary options at one use each (data only, one branch).** The 2025 Monster Manual prices every legendary
option at one use; our custom bosses still charge two or three for their strikes, so most of them take one option a
round. At one use each they act after every hero's turn, which is where a boss's damage comes from:
Strahd's Bite (2), Corvina's Bolt (2), the Huntsman's Loose (2), the Grandsire's Snap (2), the Ash Effigy's Fist (2), the
Penitent's Fist (2), the Vine Mother's Lash (2), the Eye Below's hard Glare (2). Each stays "not again until its next
turn" where the 2025 book marks a big one that way.

**Group 2: casters get Counterspell and Shield (data only, one branch).** A Reaction that casts them (the mage's
Protective Magic), so the party's big spells can be answered and a hit turned aside: Strahd (3/day), Baba Lysaga (3/day),
Exethanter (at will, as the lich he once was), the Guide (2/day), the Count's Likeness (2/day: it is a painting that
copies its sitter). Vosk already counters.

**Group 3: the book's lieutenants get legendary actions (data only, one branch per boss).**
- Rahadin: two uses: a scimitar attack, or a step that provokes nothing; his Deathly Choir stays.
- Vladimir Horngaard: two uses: a greatsword attack, or Vengeful Glare.
- Kiril Stoyanovich: two uses: a bite, or a howl that lets one wolf of his pack attack (an at-will strike on a minion,
  run as a `legendary_strikes` save-or-move option).
- Izek Strazni: a Reaction (Parry, +3 AC against one melee hit) instead of legendary actions: he is a level 4-5 fight.

**Group 4: lairs that have none yet (data, existing lair kinds; one branch per lair).**
- Baba Lysaga in her hut: the hut lurches (each creature makes a Dex save or falls Prone), swarms out of the walls (a
  swarm of insects arrives once).
- The hags' loft at Old Bonegrinder: the oven roars (fire on two foes, Dex save half), the grain bins burst (rats).
- The Rag Queen's field: the scarecrows turn their heads (Wis save or Frightened until her next turn).
- Argynvostholt's beacon (Vladimir's stand): the dead knights' banners (one foe Restrained by phantom hands, Str save).

**Group 5: needs engine work (one branch each, after the owner looks).**
- The hags' Coven Spellcasting: done 2026-10-27 (owner: "Build it"). The three hags' last stand puts each in the night
  hag's `coven` state: the 2014 Monster Manual's shared spells and slots while two sisters stand within 30 ft
  (MonsterActions.coven_casting; docs/rules/deviations.md).
- The amber golems (Sentinel, Vault Guardian): done 2026-10-27 (owner: "Build it"). Two legendary uses a round (Amber
  Fist, Amber Bolt, Grinding Stride) and a lair in all three of their fights: the amber hardens round a foe (Str save
  or Restrained) or bursts into shards at two (Dex save, 2d10 Piercing).
- The brides (Volenta, Ludmilla, Anastrasya): done 2026-10-27 (owner: "stop counting them as bosses, but could we give
  them each the vampire stat block?"): each fights on the Vampire's block in her own look, marked `boss: false`.

**Left as they are:** the Roc, Patrina, Lorghoth, Wintersplinter, Vasilka, Doru, Escher, the Abbot: book blocks that
already do what their fights need; their fights are story beats or attrition.

## How each branch is checked

The quick check, the content tests that load the boss's places, and a before/after table of what changed. No win-rate
runs (owner's rule, 2026-10-25), so the tuning series' expectations go stale; the builder's full run reports them.
