# Rules cards, interface sounds and motion (U1, A4, G9)

The UI kit's lane (Improvement Ideas, workstream 12). Everything lives in `ui/common/`; captures:
`make capture SCENE=res://tools/capture/ui_kit_capture.tscn NAME=uikit/after FRAMES=10 ARGS=--motion`.

## Rules words you can hover and pin (U1)

- **One glossary**: `data/glossary/terms.json`, read by `Glossary`. Each term has an id, a name, a kind ("Condition",
  "Action", "Weapon Mastery" ...), its text in our own words, optional `here` (how this game plays it where it
  differs, from docs/rules/deviations.md) and `see` (related terms). Conditions, the standard actions, weapon
  properties and masteries borrow their text with `from` (data/conditions, `ActionCatalog.ACTION_TEXT`,
  `PROPERTY_TEXT`, `MASTERY_TEXT`), so it's written once. tests/unit/test_rules_glossary.gd checks every condition,
  property and mastery has a term.
- **Gilded words**: `Glossary.bbcode(text)` links the first mention of each term; `TermText.make(text, size, colour,
  width)` is a RichTextLabel showing it, sized like a wrapped Label. `match` lists the phrases a term answers to (its
  name by default); `after` and `unless_next` keep ambiguous words to their meaning ("Heavy" only in a weapon's
  property list, never "Heavy armor"), and a Title Case match beside another capitalised word is left alone as part
  of a name ("Cone of Cold", "Flaming Sphere").
- **Where it shows**: `UiParts.rules_tip` (spells, features, items, conditions everywhere), `breakdown_tip` notes,
  feature rows' summaries, and any `UiParts.pill` whose text is a term ("Bloodied", "Concentration", "Bonus Action").
- **Cards**: every rich tooltip opens on the `TipCards` layer (layer 120, made by the `UiFeel` autoload) instead of
  the engine's tooltip. A card passes the pointer through like a tooltip, so a list reads row after row; after the
  pointer rests 0.6 s more (a gilt line runs along the card's top edge) it settles and the pointer can cross onto it
  and rest on its gilded words, which open cards beside it, as deep as you like. The chain closes 0.3 s after the
  pointer leaves it.
- **Pinning**: click a gilded word (left or right), right-click or middle-click a card, middle-click what opened it,
  or press the pin in its top edge. A pinned card wears a gilt clasp, drags by its top edge, and closes from its cross
  or a right-click; at most six stay pinned, and changing scene clears them.
- **For other screens**: give a control a rich tooltip with `UiParts.drawn/tipped/tip_button(..., tip)` or
  `control.set_meta(&"tip_card", func() -> Control: ...)`; put rules text in `TermText` so its words are gilded.
  A card is kept on screen and scrolls when it's taller than the screen.

## Interface sounds (A4)

From packs already in art/sourced (Kenney Interface and RPG Audio, OGA 80 CC0 RPG SFX), listed in art/audio.json:
`hover` (a soft tick when the pointer comes onto any enabled button, at most every 60 ms), `close` (a book closing
with a screen), `quill` (when the journal gains an entry or the codex a book; UiFeel watches the story), `pin` and
`unpin`, and three more takes for `coins`. Pages, cards and clicks were there already.

## Motion (G9)

`UiMotion` holds it all; it's off in headless runs and in still captures (a capture passes `--motion` to see it), and
`UiMotion.reduced` can turn it off for a Settings switch later. Each starts two frames late, so a screen's long build
frame doesn't swallow it.

- Screens rise into place from a touch smaller and fade in, the title arch a beat later (`UiKit.screen_frame`), and
  sink away when closed (`UiMotion.dismiss`, used by `game_root.close_screen`); a closing screen takes no input.
- The journal turns a page between Quests and Codex (`UiMotion.turn_page`).
- Tarokka cards land face down and flip face up (`UiMotion.flip_in`, from dialogue_ui).
- Hit Point bars roll to their new value: a gain fills up, a loss drops at once and the lost part drains away pale
  (`UiParts.roll_bar`, used by every `hp_bar`). Any label can roll a number: `UiMotion.roll(label, key, value, fmt)`
  remembers the last value shown under `key` (the purse's gold is the obvious next one).
