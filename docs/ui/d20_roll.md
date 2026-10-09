# The big d20 and choosing who speaks

Date: 2026-10-08 · Improvement Ideas G11 and Q13, lane 20 (Story presentation). The emerald die: 2026-10-09 (owner:
"a good looking dice with a cinematic roll ... an emerald green color"; only for rolls the player makes).

## The big d20 (G11)
A d20 test the player makes rolls a large d20: an emerald, cut like a gem, with gold numerals. It is a real 3D die
(`D20Die`, drawn in a small 3D world of its own and shown as a picture beside the words), numbered like a real d20
(opposite faces add up to 21). It is thrown in from the lower left onto an unseen table, bounces lower each time with
a glassy clink, spins slower and slower, tips over one last edge and rocks back, and comes to rest square to the camera
on the true number. As it lands a band of light crosses it, the number swells, and a soft emerald glow lights behind
it; a natural 20 flashes gold with slow golden rays and a chime, a natural 1 goes red, shudders and thuds. The throw
takes about 1.5 seconds (fast combat halves it).

Beside the die: who rolls what against which DC (no DC for a death save, always 10). Once the die lands the rest
stamps in: the roll in words (the die, each part of the bonus from the check's Breakdown, anything added after such as
Bless or Tactical Mind), the total and the verdict (Success or Failure; Saved or Failed for a save; a caller can give
its own word), with a "Natural 20" or "Natural 1" tag. Under Advantage or Disadvantage both dice roll; the one not kept
lands smaller beside the other and greys out. An automatic failure shows the die greyed at once.

Where it rolls:
- **Conversations**: a check rolls the die in a panel at the top of the screen. The box still shows the line and the
  full detail, and a failed check still offers its aids there (Heroic Inspiration, Lucky Foot, Tactical Mind);
  spending one throws the die again. The die goes away with the next beat; clicking on continues as before.
- **The overworld**: picking a lock (Thieves' Tools) or forcing one (Athletics), picking a pocket (Sleight of Hand,
  against the mark's passive Perception), disarming a trap (Thieves' Tools), climbing out of a pit (Athletics),
  stabilizing the dying (Medicine), and the save against a trap or a pit that opens under a hero. `LocationView`
  emits `big_roll(test, who, label)` beside the line it already sends the HUD; the game root rolls it.
- **Fights**: the heroes' saving throws and death saves, fired by the combat HUD (Combat HUD lane), never enemies'
  rolls or attacks.

Those last two use `DiceRoll.show_roll(host, roll) -> Signal`: the panel comes up on a layer of its own (26, over the
HUDs and conversations, under menus) in the top third of the screen, rolls, holds the result a little over a second
and goes; the signal fires once it has gone, so a caller can await it. A click, a key or a controller button lands a
rolling die at once; another closes the panel. A roll asked for while one is up waits its turn (a botched disarm
springs its trap). Searching and sneaking still roll quietly in the HUD's line: their DCs are hidden.

Motion is off in headless runs and still captures (UiMotion): the die shows at rest at once and show_roll's signal
fires on the next frame, so awaiting it never stalls a test. The die's shader and numerals are readied when the game
starts (`D20Die.warm`), so the first roll doesn't hitch. The 3D world draws only while the die moves.

### The roll Dictionary
`DiceRoll.from_test(t: D20Test, who, label, kind = "")` builds one; `DiceRoll.from_beat(beat)` from a conversation's
check beat. Keys: `kind` ("check", "save", "death_save", "attack"), `natural` (the kept d20), `rolls` (both d20s under
Advantage or Disadvantage), `total`, `target` (DC or AC, 0 if hidden), `success`, `critical`, `fumble`, `who`, `label`;
optional `parts` [{label, value}], `modifier`, `extra`, `extra_label`, `advantage`, `disadvantage`, `auto_failed`,
`verdict`.

The check beat (`DialogueRunner._check_beat`) carries the dice for it: `rolls`, `kept`, `modifier`, `parts`
({label, value} from the Breakdown), `extra`, `extra_label`, `advantage`, `disadvantage`, `auto_failed`.

## Choosing who speaks (Q13)
While a conversation offers options, a "Speaks: <name> (Tab)" button under the speaker's portrait names who speaks for
the party. It (or Tab) hands the voice to the next living party member: their bust takes the left side, the options
show their bonus and chance, and the checks those options make are theirs (`DialogueRunner.set_speaker`). An option a
tag gives to someone else ([Cleric], name:thistle) still goes to them, and a `check` statement still picks the best
party member, as before.

## Code
- `ui/dice/dice_roll.gd` (`DiceRoll`): the panel, `show_roll`, `from_test`, `from_beat`, the words.
- `ui/dice/d20_die.gd` (`D20Die`): the 3D die, its throw (a function of time: `seek` steps it for captures), the
  landing's shine, `warm`.
- `ui/dice/d20_mesh.gd` (`D20Mesh`): the gem-cut icosahedron, its numbering and the turn that shows each number.
- `shaders/ui/emerald_die.gdshader` (the emerald, its back facets, the landing's light), `shaders/ui/die_feather.gdshader`
  (the die's picture fades out at its edges). Colours: `emerald_*` in the UI palette (tools/art/build_palette.py).
- Sounds: `die_bounce` and `die_land` in art/audio.json (Kenney glass, CC0); `radiant_chime` and `thud_heavy` for a
  natural 20 and 1.
- `ui/dialogue/dialogue_ui.gd`: shows the d20 on a check beat; the Speaker button, Tab and `cycle_speaker`.
- `story/dialogue_runner.gd`: the check beat's dice; `set_speaker`, and `_check_info` for an option's check.
- `world/exploration/location_view.gd` (`big_roll`) and its emitters in location_locks, location_crime,
  location_traps, pit_fall and location_care; `world/game_root.gd` rolls it and warms the die.
- Tests: tests/integration/test_dice_roll.gd, test_d20_and_speaker.gd, test_layout.gd (both panels).
- Captures: `make capture SCENE=res://tools/capture/d20_capture.tscn NAME=d20 FRAMES=30` (stills, then the throw frame
  by frame as <NAME>_seq_NNN.png).
