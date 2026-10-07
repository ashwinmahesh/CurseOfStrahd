# The look of every screen

Owner request 2026-10-06: the character sheet was "a wall of text"; after its Baldur's Gate 3-style redesign, every
other screen and HUD was restyled to match. New screens should be built from the same pieces so they match without
a restyle pass.

## Where the pieces are

- `UiKit` (ui/common/ui_kit.gd): the theme every stock control falls back to, screen frames (crimson-black panel,
  gilt trim, title plaque), labels, buttons with icons, the display face.
- `UiParts` (ui/common/ui_parts.gd): the drawn pieces.
  - Numbers: `medallion` (ability), `shield` (Armor Class), `plaque` (Initiative, Speed, Proficiency), `figure`
    (a number in the book serif), `delta_badge` (▲/▼ on level up).
  - Bars and marks: `hp_bar` (crimson, Bloodied brighter, temporary HP in moonlight), `bar`, `pips` (slots,
    resources, Hit Point Dice), `mark` (proficient, Expertise, untrained), `pill` (Action, Concentration, Equipped).
  - Layout: `section` (heading with a gilt rule), `card`, `pane`, `row` (a row card), `click_row` (a row you pick),
    `tab_strip`, `party_chips`, `framed_portrait`, `fill_scroll`, `gap`, `caption`.
  - Buttons: `small_button` (inside rows), `primary_button` (the one that finishes a screen), `tip_button`,
    `light_up` (the chosen look).
  - Rules on hover: `rules_tip` (title, subtitle, facts, wrapped text), `breakdown_tip` (a Breakdown line by line),
    attached with `tipped`, `drawn` or `tip_button`. `feature_row` shows a feature with its full text on hover.
  - Icons: `add_icon(row, "item" | "spell", id)`, `icon_on_button`, `action_icon` (hotbar). They use the `Icons`
    helper (ui/common/icons.gd) when it exists, and add nothing when it doesn't.

## Shapes, not squares

Owner, 2026-10-06, pointing at the Crimson settings concept: "Everything shouldn't just be squares." So:
- Buttons are long hexagons (UiKit.button_style); the chosen or primary one carries lozenges at its points
  (`UiParts.light_up`, `primary_button`, `mark_ends`).
- Panels, cards and rows have bevelled corners (UiKit.style, `UiParts.card`); tabs have bevelled tops.
- Hit Points and load bars come to points (`UiParts.bar`).
- Each screen's title sits in a small pointed arch with a lozenge at its apex, and a flourish sits on the bottom
  border (UiKit.screen_frame).
- The pause menu is the concept itself, number for number (ui/screens/pause_menu.gd): the 280-unit arch scaled by
  1.5, its exact colours (`arch_*` in the UI palette), Georgia, and its button, slider and footer geometry. Other
  stand-alone menus can use the same pieces: `arch_points` + `gradient_fill` for the frame, `crest` at the apex,
  `curl` at the shoulders, `title_rule` under the title, `footer_wave` and `brackets` below.

## Rules of thumb

- Long rules text goes in a tooltip; the page keeps names, one-line summaries and tags.
- Every number's tooltip is its Breakdown (`breakdown_tip`).
- Rules text goes through `TermText` (or `rules_tip`, which uses it) so its rules words are gilded and open their
  glossary cards; a rich tooltip is a `tip` on `drawn`/`tipped`/`tip_button` or a "tip_card" meta Callable, never
  `_make_custom_tooltip` (docs/ui/rules_cards.md).
- Motion goes through `UiMotion` (short, skipped in tests and still captures); sounds through `Audio.sfx`.
- Group with `section` and `row`; pick with `click_row` or `light_up`; finish with one `primary_button`.
- Colours only from Look; state is told by shape or words as well as colour (Bloodied, ▲, ✓, !).
- Lists of many options read better in the plain face (`ThemeDB.fallback_font`), headings in the display face.

Captures: `make capture SCENE=res://tools/capture/ui_capture.tscn NAME=ui` (every party screen; `UI_ONLY=party,shop`
in the environment narrows it).
