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

## Rules of thumb

- Long rules text goes in a tooltip; the page keeps names, one-line summaries and tags.
- Every number's tooltip is its Breakdown (`breakdown_tip`).
- Group with `section` and `row`; pick with `click_row` or `light_up`; finish with one `primary_button`.
- Colours only from Look; state is told by shape or words as well as colour (Bloodied, ▲, ✓, !).
- Lists of many options read better in the plain face (`ThemeDB.fallback_font`), headings in the display face.

Captures: `make capture SCENE=res://tools/capture/ui_capture.tscn NAME=ui` (every party screen; `UI_ONLY=party,shop`
in the environment narrows it).
