# The aid prompt after a failed skill check in a place

A skill check on something in a place (the right-click menu's `check:<id>` lines, `LocationChecks`) used to say how it failed,
hurt whoever tried and set off its fight as soon as the die landed, and only then leave Heroic Inspiration and the other aids
on the thing's menu; spending one meant the reroll's success ran on top of a failure already told.

Now a failure an aid could turn waits. `LocationChecks._settle` asks the view (`LocationView.ask_aid`, signal `aid_asked`); the
game root puts `CheckAidPrompt` up over the place once the big d20 has gone (`GameRoot._ask_aid`, `_prompting`):

- "Ilse rolled 11 on Arcana against DC 25, and missed." and one line for each aid `CheckAids.options` gives the roller (Heroic
  Inspiration, Lucky Foot, Tactical Mind, Dark One's Own Luck), numbered 1 to n, then **Let it stand**.
- 1 to 9 pick a line, Esc or the pad's B lets it stand; the mouse and the pad's A pick as usual. Nothing behind it moves.
- Let it stand: the failure happens (the Narrator's line, the damage, the encounter set off by `check:<id>:failure`).
- An aid: the roll is made again (the big d20 throws it, `big_roll`), then the check ends as the new roll ends it: a success
  never meets the failure's line, damage or fight, a miss lets the failure happen, and a roller with another aid left is asked
  again (`LocationChecks._aided`).

A check with no aid to spend, or a view no game is listening to (the headless tests), resolves at once as before. The thing's menu
no longer carries `check_aid:` lines. Conversations keep their own aid button in the dialogue box (docs/ui/d20_roll.md).
