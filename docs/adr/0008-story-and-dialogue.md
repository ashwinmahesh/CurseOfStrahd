# ADR 0008: Story state, dialogue files and the Narrator

Status: accepted (Phase 3)

## Context

Phase 3 brings conversations with skill checks, party interjections, quest journals and the Narrator (plan §5.4,
§5.5, §5.7). The plan's technical table named the Dialogue Manager addon. Writers are agents; their files must be
easy to write, diff and validate in CI without Godot, and the runtime must be testable headless like rules/ and
combat/.

## Decision

- **Our own plain-text format** (`docs/contracts/dialogue.md`), close in spirit to Dialogue Manager: `~ node`,
  `Speaker [mood]: line`, `* [Skill DC n] option -> ok | fail`, `if/elif/else/endif`, `set`, `quest`, `give/take`,
  `gold`, `attitude`, `xp milestone`, `check`, `interject <selector>:`, `combat`, `narrate`. Narrator files key nodes
  by trigger with `|` variants, `cooldown` and `once`. No third-party addon (none to download, update or trust), and
  `tools/data/dialogue_lint.py` parses the same grammar so `make validate` checks every jump, speaker, item, quest,
  encounter and flag. **The plan's Dialogue row should name this format instead of the addon** (the planning thread
  owns the plan).
- **`story/` is pure logic** (linted standalone like rules/ and combat/): `StoryState` (party, money, stash, flags,
  quests, attitudes, places, codex, Narrator memory, milestones, time, per-location state), `StoryConditions`,
  `DialogueFile`, `DialogueRunner` (beats the UI shows: line, options, check, notice, end), `Narrator`, `Banter`,
  `QuestLog`. `GameState` (core/) holds one `StoryState` and saves it.
- **Checks roll in the open** with the speaking character's real bonus (Advantage and Heroic Inspiration through the
  same `roll_d20`); an option tagged with a class, species, background or personality tag is spoken by the party
  member who has it. Party members speak only through interjections and banter; the player chooses every option.
- **The flag registry** is split by region (`data/flags/<region>.json`) so writers don't collide; CI fails on a flag
  that is read but never set, set but never read, or unregistered.
- **Milestone levelling** (plan §5.6 default): `xp milestone` lines raise the level the party may reach; each
  character levels up from the sheet or party screen.

## Consequences

- Writers learn one small grammar; validation catches broken references before anyone plays.
- Features Dialogue Manager has that we don't (inline expressions, translations) can be added to our grammar when a
  story needs them.
