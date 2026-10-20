# The finale for the allies (Story Allies Presence Plan, package F1)

The earlier packages gave Ireena, Izek, Ezmerelda and Kasimir things to do between the regions. This one lets the castle notice. It
changes no story state: one side flag (`ireena_answered_strahd`) and a few lines that read what the other packages recorded.
**Kasimir's dinner and coffin lines are package K2's** (it already touches the gates); Izek's epilogues are package Z2's.

## Ireena answers him (`narrative/strahd/final.dialogue`, `ireena_answers`)

At the parley, when Strahd names his price, the menu gains **Let Ireena answer him**, offered once (`ireena_answered_strahd`) while
she travels with the party, knows whose face she wears (`ireena_knows_tatyana`: the Tome read to her and the statue told, package
I2) and trusts them (`ireena_trust >= 3`). She steps out of the line and answers by her own name, not as a price or a bride; he
answers courteously and calls her Tatyana to provoke. If she kept his third letter (`ireena_kept_letter`) she says so and that she
has stopped reading it, and he answers that too. It decides **nothing**: `strahd_parley` is still the party's to answer, the menu
comes back with the price still on it (including "Take her, then"), and her answer is only what she said.

## The tomb and the coffin

- `catacombs_sergei:ireena_first_sight`: if she has read the book (`ireena_knows_tatyana`) she tells Sergei's reflection she knew his
  face before the water showed it to her; otherwise the old line stands.
- `catacombs_coffin:ireena_stake`: two or more sword lessons (`ireena_lessons >= 2`, package I2) add a line about her steady hands;
  if she knows whose name he uses, her answer to "Tatyana." is that she knows her name from his pages and it is not hers (else the
  bare "No.").
- Over the coffin, an `interject` each for Ezmerelda (while he sleeps: nobody touches the stake until every hand is set; once he
  lies beaten: Rudolph would want it written down) and Izek (smaller in a box; "Stay behind my arm, Ireena", only while she is
  along).

## The dinner (`gates_dinner:start`)

Strahd greets Ezmerelda (Rudolph would never have approved) and Izek, when he has come with his sister ("the brother who found his
way to my gates"); each has a line back.

## Her epilogue (`data/endings/strahd_destroyed.json`, `strahd_triumphant.json`)

Her slide gains variants, before the usual ones: if the vampire is destroyed and she walks out with the party, she burned his last
letter (trust 4 and `ireena_kept_letter`) or spars with her brother before breakfast (three lessons). If he is not destroyed and
she is not carried to the castle or hidden behind Krezk's wall, she keeps the letter, or sleeps with a sword beside her bed. The
usual slides (the lady of the castle, the carriage at Krezk's gate, hiding and running) are untouched.

## Lines

24 new unvoiced lines: the parley 9, the tomb 1, the coffin 6, the dinner 4, the epilogue 4. Drafted by Gemini through the ai-bridge
(`docs/plans/gemini_allies/f1/`), edited. Two draft epilogue slides about keeping both names were dropped: that flag is package
Z2's, and Z2 already ends Izek's slide on it.

## Tests

`tests/unit/test_allies_finale.gd`: when Ireena can answer (along, knowing, trusting, once); that her answer sets nothing and the
price is still on the table; the kept letter; the tomb's two versions; the stake's two details; the coffin's interjects only for
those who are along; the dinner's greetings; her epilogue variants and the usual ones; her never naming him.
