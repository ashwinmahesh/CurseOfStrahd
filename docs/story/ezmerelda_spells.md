# Ezmerelda's spells on the hotbar (Resume packages, Allies item 3)

Todo (Next week.md, 2026-10-20): "Ezmerelda's combat options are missing some of the things she can do ... She is a spellcaster but I
don't see her spells list."

## Why it was missing

A story ally fights as a stat block (`StoryState.make_guest`; Ezmerelda's is `data/monsters/ezmerelda_davenir.json`, a 7th-level
wizard's spells under `spellcasting`: at-will cantrips, then Magic Missile, Shield and Protection from Evil and Good 4 a day, Darkvision,
Knock and Mirror Image 3 a day, Clairvoyance, Lightning Bolt and Magic Circle 3 a day, Greater Invisibility once). The AI casts from that
block (`MonsterActions.spells_now` and `cast`), but the player's hotbar only built a Spells tab from a hero's own spellcasting
(`ActionCatalog.tabs_for`, `_spells`, and `SpellCaster.castable`, which look at a Character). So a stat-block caster the player runs had
her attacks (Fire Bolt among them) and nothing else. The same held for every ally and summoned or shaped monster that casts from a block.

## What it does now (in the core, addons/dnd_core, branch ezmerelda-spells)

- `ActionCatalog.has_block_spells(c)`: a monster whose block lists spells, who is not a hero's shape that keeps its own spellcasting.
  `tabs_for` gives it the Spells tab.
- `_stat_block_spells` lists every spell of the block, in the block's order: the level the block casts it at (`levels`, else the spell's
  own), "at will" or "N left today", the dice. A spell with no uses left today is greyed ("None left today"); a Reaction spell says
  it is cast when it triggers (Shield and the like are answered by the Reaction prompt as before); one with no effect in a fight says so
  (Light, Detect Magic, Knock ...); the usual action, Bonus Action and Antimagic checks apply.
- Casting goes through `MonsterActions.cast` (what the AI uses): the block's Spell save DC and spell attack bonus (with the bonuses to a
  monster's own, Tactician's +2), no slot, Counterspell and Concentration as ever, and a use of an N-a-day spell is spent only when the
  cast goes off. The player and the AI share one count (`cast_<spell>` on the combatant), so a use the AI spent shows on the tab.
- The hover and the detail panel read the block's numbers (`_block_preview`, `_spell_details`): save DC 14 for Ezmerelda, the damage
  dice at the block's level. There is no upcast (`level_choices` is empty) and no Ready entry in the right-click menu (the game's
  `ui/combat/combat_hud.gd` skips it for a `stat_block` action).

## Left alone

- Reaction spells (Shield, Counterspell) are not cast from the bar; they come as they did, when their trigger does.
- A stat-block spell has no Ready form and no Metamagic or class options: those belong to a hero's sheet.
- Bonus Action spells the block lists under `bonus_actions` rather than `spellcasting` (the mage's Misty Step) are not on the tab.
- The unit tests: the core's `tests/unit/test_stat_block_spells_tab.gd` (the mage's block), the game's `tests/unit/test_ezmerelda_spells.gd`
  (hers, and every other story ally whose block casts), `tests/integration/test_ezmerelda_spells_hud.gd` (the HUD's tab, the slot text
  and the right-click menu).
