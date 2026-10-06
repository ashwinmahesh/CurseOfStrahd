# ADR 0006: Builds are a record of keyed choices; every number is a Breakdown

Status: accepted (Phase 1)

- A character's `build` stores only decisions: species, background, base scores and method, the class of each level
  with its Hit Point roll, and `choices: {key: [picks]}`. Keys are stable paths such as `fighter.1.fighting_style`,
  `background.abilities`, `fighter.4.ability_score_improvement/ability_score_improvement.abilities`,
  `wizard.spellbook`. Nothing derived is saved, so data fixes reach old saves automatically.
- `Character.refresh()` walks the data in a fixed order and lists every `Choice` the build involves, with its picks.
  `ChoiceOptions` fills each with options and marks illegal ones with a reason and weak ones with a warning.
  `CharacterBuilder` and `LevelUpController` edit a copy of the build and preview it; picks for choices that no
  longer exist are pruned. The UI picks a widget by `Choice.kind`, so new content needs data, not UI code.
- Every number the UI shows comes back as a `Breakdown` (parts with labels, floors, overrides, notes for Advantage
  and automatic failures), e.g. "AC 17 = Chain Mail 16 + Defense 1". Plan §5.6 "Every number explains itself" is
  satisfied by the engine, not by UI code.
