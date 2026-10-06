# ADR 0007: The combat grid and the Encounter

Status: accepted (Phase 2)

## Context

Phase 2 (plan §5.3) adds tactical combat: a 5 ft grid over the 3D levels, the 2024 action economy, Opportunity
Attacks and other reactions that the player answers, areas of effect, enemy AI and a HUD that explains every number.
It has to stay testable without a scene (ADR 0001) and keep the rules library pure (ADR 0003).

## Decision

- **`combat/` is pure logic** like `rules/`: RefCounted classes, no nodes, no autoloads, compiled standalone by
  `make lint`. It takes a DiceRoller. Scenes show it; they never decide anything.
- **The grid is data.** `CombatGrid` is built from rows of characters (`.` floor, `#` wall, `=` low cover, `~`
  Difficult Terrain, `1`-`4` raised floor, space = void) stored in `data/encounters/<id>.json`, so the rules and the
  3D dressing (`world/combat/arena_board.gd`) read the same map. Cell (x, z) is world x..x+1, z..z+1 (ADR 0004).
- **2024 grid rules:** every square costs 5 ft, diagonals included; Difficult Terrain doubles; diagonals can't cut a
  wall's corner; climbing more than 5 ft costs extra; distance is the larger axis gap (height counts); Large creatures
  are 2x2. Creatures: allies, Incapacitated, Tiny and two-sizes-different creatures can be passed; an enemy's square is
  Difficult Terrain; nobody ends a move in an occupied square.
- **Cover and sight by corner lines** (`cover_between`): from the attacker's best corner to the four corners of the
  target square, walls blocking 1-2 lines give Half Cover, 3 Three-Quarters, 4 Total. Creatures and low walls give at
  most Half Cover (degrees don't add); a line along the seam of two wall squares is blocked; an attacker 10+ ft above
  a low wall sees over it. Areas of effect include a square when its center is inside the shape and the origin has a
  line to it.
- **`Encounter` owns a fight:** initiative (surprise, shared rolls for identical monsters), the turn order, each
  `Combatant`'s turn state (Action, Bonus Action, Reaction, movement, attacks left in the Attack action, Action
  Surge, Light-weapon extra attack), short-lived **marks** (Help, Vex, Sap, Guiding Bolt, Steady Aim, Shocking Grasp),
  grapples, and the `CombatLog`. Every command returns a `CombatResult` (`ok` and `reason` when refused).
- **Reactions pause, never guess.** When a player-controlled creature could react (Opportunity Attack, Shield,
  Uncanny Dodge, a readied attack, Heroic Inspiration), the command stores a `ReactionRequest` with a continuation
  and returns paused; `answer_reaction(use)` resumes it. `then(result, next)` chains continuations, so a move, a
  spell or a whole AI turn carries on after the answer, and a second prompt inside the first works. Per-reaction
  rules the player sets (ask, always, never) replace the prompt (plan §5.3). AI creatures decide through `AiBrain`.
- **Spells and features are separate collaborators:** `SpellCaster` (slots, one slot-spell per turn, free castings,
  Concentration, range and line of effect, attacks, saves with cover, healing, effects with repeated saves, plus the
  special cases), `CombatFeatures` (Sneak Attack, Second Wind, Action Surge, Steady Aim, Channel Divinity), and
  `AiBrain` (behavior profiles from monster data). `ActionCatalog` turns all of it into hotbar entries with costs,
  reasons and previews, so the HUD never computes rules.
- **Events for animation.** The encounter appends plain dictionaries (`move`, `attack`, `damage`, `heal`, `spell`,
  `turn`, `round`, `death`, ...) that the scene drains and animates (docs/contracts/combat.md).

## Consequences

- The whole fight runs headless: unit tests per rule, an AI test, and a soak test that plays the arena to the end
  for many seeds (a test-only autopilot plays the party).
- New maps are data. New monsters fight with their stat blocks and an `ai_profile`; special monster actions need
  engine work as they come (Phase 4+).
- Lighting and obscurement, readied spells, and the Approach and Drop words of Command are not in Phase 2
  (deviations.md, coverage.md).
