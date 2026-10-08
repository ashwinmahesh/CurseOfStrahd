# The big d20 and choosing who speaks

Date: 2026-10-08 · Improvement Ideas G11 and Q13, lane 20 (Story presentation).

## The big d20 (G11)
A check in a conversation rolls a large d20 at the top of the screen, where before it was only a line of text in the
box. The die tumbles through numbers for three quarters of a second and lands on the roll, gilt for a natural 20 and red
for a natural 1. Beside it: who rolls what against which DC, the roll in words (the die, each part of the bonus from the
check's Breakdown, anything added after such as Tactical Mind), the total and Success or Failure. Under Advantage or
Disadvantage the die not kept sits beside the other, smaller and dimmed. The box still shows the line and the full
detail, and a failed check still offers its aids there (Heroic Inspiration, Lucky Foot, Tactical Mind); spending one
rolls the die again. The d20 goes away with the next beat. Motion is off in headless runs and still captures (UiMotion).

The check beat (`DialogueRunner._check_beat`) carries the dice for it: `rolls`, `kept`, `modifier`, `parts`
({label, value} from the Breakdown), `extra`, `extra_label`, `advantage`, `disadvantage`, `auto_failed`.

Checks outside conversations (a locked door, a search) still report as a line in the HUD; they can take the same panel
once the exploration code hands it their dice.

## Choosing who speaks (Q13)
While a conversation offers options, a "Speaks: <name> (Tab)" button under the speaker's portrait names who speaks for
the party. It (or Tab) hands the voice to the next living party member: their bust takes the left side, the options
show their bonus and chance, and the checks those options make are theirs (`DialogueRunner.set_speaker`). An option a
tag gives to someone else ([Cleric], name:thistle) still goes to them, and a `check` statement still picks the best
party member, as before.

## Code
- `ui/dialogue/d20_roll.gd` (`D20Roll`, with its drawn die `D20Roll.D20Face`).
- `ui/dialogue/dialogue_ui.gd`: shows the d20 on a check beat; the Speaker button, Tab and `cycle_speaker`.
- `story/dialogue_runner.gd`: the check beat's dice; `set_speaker`, and `_check_info` for an option's check.
