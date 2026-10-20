# Ireena's letters (Story Allies Presence Plan, package I3)

When the party leaves Ireena somewhere safe and goes on, she does not vanish. While she shelters (the Blue Water Inn or
St. Andral's, the Krezkovs' house, or her father's mansion after the party declined to take her) and the party is
somewhere else, a courier finds the party outdoors with a letter in her hand after something big that she would hear of.
The letters are the reason to go back: they never ask for anything and never say where to go, and the party answers them
only by visiting her (`narrative/allies/ireena.dialogue`, the check-in hub of package I1).

Lines: `narrative/allies/ireena_letters.dialogue` (40 lines, all unvoiced; Gemini's drafts, edited:
`docs/plans/gemini_allies/i3/`). Visits: `data/visits/ireena.json` (the ally visits engine, package E1:
`docs/regions/strahd_presence.md`, "Ally visits").

## When a letter comes

One visit, `ireena_letter`, on an arrival or a leg of a journey outdoors:

- She is met (`ireena_met`), not with the party, not held in the castle (`ireena_held_by_strahd`), and the party is not in
  the region she shelters in (a letter is for someone who is away: at the inn or St. Andral's, not in Vallaki; in Krezk,
  not in Krezk; at the mansion, not in the village).
- Something has happened that she has not written about: the festival is over, the Abbot wrote to the castle about her
  (`abbot_told_strahd`), the werewolf den's end is known (`wolf_pack_leader`), the winery's wine flows, the beacon at
  Argynvostholt burns, the party accepted the dinner invitation. The letter is picked in that order, one per visit.
- `cooldown_hours: 48` and `max: 6`: at least two days apart, six in a playthrough at the most, one for each event.
- Fewer than three letters are unanswered. At three she stops writing, however much happens.

The courier is never named: a carter's boy (the inn, the church), a pilgrim from Krezk, a village child (the mansion). The
letter is read as her lines; the party keeps it or tells the messenger they will come. Neither changes anything.

## What it costs to stay away

`ireena_letters_unanswered` counts the letters without a visit. Any check-in with her sets it back to 0 and:

- at 2, opens cold (`ireena_letters:cold`, two lines about the two letters sent and not answered); at 3, colder ("Three
  letters. I was starting to write the fourth to your graves"). Then the check-in goes on as usual into her days.
- at 3, once, a second visit (`ireena_silence`, after the party has seen Strahd on the ridge): a rider hands over a letter
  in black wax in Strahd's voice, courteous about how little the party's silence costs the party and how much it costs her,
  with one line for where she is. Her trust falls by one (`ireena_trust`); burn it or keep it.

Nothing else happens. She does not leave, change her refuge or die because the player was busy, and no quest or story flag
moves: `ireena_letters_sent`, `ireena_letters_unanswered`, `ireena_cold_now`, `ireena_sent_<event>` (six) and
`ireena_strahd_wrote_silence` are side flags (`data/flags/allies_ireena.json`).

## Hooks

- `data/visits/ireena.json`: the two visits; the file's `when` clauses are the conditions above.
- `narrative/allies/ireena.dialogue`: `checkin` copies the count into `ireena_cold_now` (2 or 3) before clearing it, and
  `greet` jumps to `allies/ireena_letters:cold` when it is set. No code.
- Z1 (Izek takes her to his room) adds `izek_holds_ireena`; while she is held there no letter should say she is at the inn.
  Package Z2, which builds on both, adds `not flag.izek_holds_ireena` to the letter visit's `when` once Z1 has landed.

## Tests

`tests/unit/test_ireena_letters.gd` (15 tests): when a courier comes (met, away, not held, outdoors, each of the four
places), the 48-hour spacing, the stop at three, six letters in all, which letter plays first and each variant, the
couriers, the two exits, that only side flags move, the cold check-in at all five places, Strahd's note (once, trust,
where she is, burn or keep), and the story bot's way out of each scene.
