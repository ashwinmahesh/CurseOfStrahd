# UI polish and quality of life (2026-10-07)

Status: items 1 to 8 are built (all on the polish branch, most on main). The owner then asked for a more modern
look as well (2026-10-07), which became the second wave at the end of this file.

Ranked from a capture play-through of main at 055db1a3 (title, the opening road, the village and Morgantha, the Death
House attic and its locked door, a ghoul fight in the dungeon, the arena from first move to a wipe, the travel map and
every party screen) and the owner's playtest notes since Phase 3. Rule changes stay with their owners; this is
presentation and flow only. Captures: captures/pol/ (local).

## 1. Autosave
A wipe today sends the player back to their last manual save, which may be the title screen. The game saves itself to
an "autosave" slot on arriving somewhere new and after a rest (never in a fight), the Load list names it
"Autosave", and the game-over screen offers "Back to the last autosave" first. The autosave never becomes the game's
own slot, so F5 still saves where it did.

## 2. Combat HUD fit and finish
- Action buttons cut their names off ("2 Spear (th", "3 Arcane F", "Ready attack on appro"): names wrap or shrink to
  fit, the thrown variant reads "Spear, thrown".
- Party frames spill when someone is down (the DOWN mark widens the name, "Dying 0✓ 0✗, Mage Armor" wraps under the
  frame) and the guest frame covers "F1: controls": DOWN becomes a red pill under the bar, status chips stay on one
  clipped line with the full list in the tooltip, and the F1 hint moves below the turn order.
- The combat log takes a quarter of the screen over the fight: it opens compact (the last lines, scrolling), keeps
  its minimize button, and L or a click on its title opens it full.
- Floating status labels ("Prone · Dying") get cut by the hotbar and the screen edge: they stay inside the view.

## 3. Hold Alt to show what you can use
Like BG3: while Alt is held, every door, exit, container, person, body and item in view gets its name on a small
plate (locked doors and looted containers say so). Hidden things stay hidden.

## 4. Exploration HUD
- The command bar's ten icons get their hotkey letter in a corner; Sneak and Split light up while they're on.
- Under the place name, the current objective (the newest open quest step), which opens the journal on a click.
- Toasts queue instead of replacing each other, so two quick messages are both read.

## 5. Conversations
- Options already chosen in this conversation are dimmed (still clickable), so it's clear what's left to ask.
- A scroll-back of the conversation so far (the mouse wheel or Up over the text box) for a missed line.

## 6. Settings
The pause menu gets a Settings page beside the volumes: windowed or fullscreen, combat speed (normal or fast, which
halves enemy movement and the pauses between their moves), and how long the Narrator's box stays up.

## 7. Small screens
- Rest: "Heal up" spends each character's Hit Point Dice until they're nearly full, one click instead of many.
- Loot: the window is as tall as its contents, and Space takes everything.
- Exploring: F1 shows a controls card like the one in fights.

## 8. A fade between places
Walking through an exit or arriving from the road fades to black and back instead of cutting.

## Left alone (owned elsewhere or already done)
Pause menu, title and screen frames are the Crimson scheme already (the sheet layout thread). The minimap, travel
map and traps (map thread), the party picker and creator (creator thread), combat rules, cover and Advantage display
(audit thread). Walls already fade in front of the party.

## Second wave: a more modern look (owner, 2026-10-07)
- A Modern finish beside Classic, Modern by default (owner's pick): smooth light, no palette snap, relief from
  normal maps, AgX tone mapping with bloom on flames, deeper contact shadows and bounced light, a thin haze, a
  diorama's depth of field (docs/art/style_bible.md "Two finishes").
- Smooth 768 px tiles for all 45 world textures, made from their own swatches (docs/art/textures.md).
- Gothic cursors that say what a click will do (use, talk, attack, locked, look), from the game-icons silhouettes.
- A gilt glow on whatever the mouse is over while exploring.
- Save names that never leave their box (owner report), Heal up on the rest screen.

