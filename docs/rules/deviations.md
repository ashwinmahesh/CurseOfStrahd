# Rule deviations

Every place the game departs from the 2024 rules, with the reason. A rule that simply isn't built yet is "not
started" in coverage.md, not a deviation.

| Rule | What the game does | Why | Revisit |
|---|---|---|---|
| Temporary Hit Points don't stack: "you decide whether to keep the ones you have or gain the new ones" | The engine keeps the higher amount automatically | Keeping the lower is never better outside contrived cases; saves a prompt in every combat | Phase 3: offer the choice when the new amount is lower and the old ones expire sooner |
| Combining game effects: the most potent of identical effects applies | Potency is approximated by the size of the effects' numbers (conditions weigh most); ties go to the most recent | The rules leave "most potent" to judgment | If two versions of the same spell ever compete in a way the approximation gets wrong |
| Frightened (positional parts) | Disadvantage applies whether or not the source is in sight; "can't move closer" is followed by the AI (Turned creatures flee) but not enforced on player moves | No player character is Frightened in the Phase 2 arena | Phase 3, with the first frightening enemy |
| Diagonal moves past a wall corner | A diagonal step is refused when either square beside it is a wall or low obstacle | The 2024 grid rules leave corners to the DM; this is the common table ruling and stops moving through wall seams | — |
| Climbing | Stepping up 5 ft (a dais step) costs no extra; a bigger rise costs 1 extra foot per foot climbed; drops over 10 ft are refused | Treats a 5 ft step as stairs; falling arrives with Phase 3 levels | Phase 3 |
| Initiative ties | Higher Dexterity first, then the party | The rules leave ties to the DM | — |
| Identical monsters | Share one Initiative roll and act one after another | 2024 DMG option for groups; keeps turns quick | — |
| Study DC | 10 + the monster's CR | The rules leave the DC to the DM | — |
| Grappling | A grappled creature can't move and escapes as the rules say; the grappler can't drag it | Dragging needs movement-cost plumbing; nobody grapples in the arena | Phase 3 |
| Weapon juggling | A character can attack with any weapon it carries (drawing it as part of the attack) and the previous one is assumed dropped or stowed | The 2024 free equip/unequip per attack covers most cases; tracking hands comes with the inventory UI | Phase 4 |
| Material components and focuses | Assumed carried (every pregen has a focus or pouch) | Inventory checks for costly components arrive with magic items | Phase 4 |
| Monster Hit Points | Average from the stat block | The 2024 default | — |
| Divine Spark (harm) | Always Radiant | Radiant is never worse than Necrotic against the Phase 2 enemies | Phase 3 |
| Ready | Readied spells are offered from the hotbar's right-click menu and trigger when an enemy comes within the spell's range | The 2024 trigger is any perceivable circumstance; range is the useful one in a grid fight | Phase 3, with custom triggers |
| D20 Test choices made in the middle of a roll (Indomitable, Stroke of Luck, Mage Slayer's Guarded Mind, Heroic Inspiration on a save, Tactical Mind) | Used automatically on a failure unless the creature's rule for it is "never" | A save can't pause the fight for a prompt; failing the save is almost always worse | When saves can pause like attacks do |
| Lucky's Advantage | Armed from the hotbar for the next D20 Test; Lucky against an attack is a prompt | The rule lets you decide after seeing the situation, before the roll | — |
| Portent | Assigned from the hotbar to a creature's next D20 Test | Same as the rule, chosen ahead of the roll | — |
| Cast-time choices | The first option is the default; the hotbar's right-click menu picks another | Keeps one click for the common case | — |
| Commander's Strike, Crown of Madness, Maneuvering Attack | The ally's attack target, the crowned creature's victim and the maneuvering ally are picked automatically (the best target in reach; the nearest ally) | Saves a second targeting step | With the targeting polish |
| Charger, Lunging Attack | "Moved this turn" stands in for "moved 5 (10) ft in a straight line toward the target" | The grid path isn't tracked as straight lines | — |
| Calm Emotions | Only the "indifferent" option; the Charmed/Frightened suppression option isn't offered | The enemy-pacifying option is the combat use | Phase 3 |
| Bestow Curse | The ability-check curse always picks Wisdom | One fewer choice | With the cast-time choice UI |
| Aura of Vitality | A Bonus Action on each of your turns (as the 2014 and, we believe, 2024 text); the data text said "no action" | Unsure of the 2024 wording; needs the owner's book | Check against the PHB |
| Disarming Attack | The dropped weapon is picked up at the start of the creature's next turn (its free object interaction) | Items on the ground aren't modelled | Phase 4 inventory |
| Levitate, Fly | No altitude on the grid: Levitate puts the target out of melee reach and stops its walking; flyers ignore ground terrain | The grid is flat | Phase 3 levels |
| Blink, Etherealness, Plane Shift | Blinking back lands on the same square; a monster that escapes this way leaves the fight | Saves a placement step; the escape is what matters in a fight | — |
| Loathsome Limbs | Severed arms and heads fight on as their own creatures sharing the body's Hit Points; severed legs only slow the body | Legs can't attack | — |
| Shape-Shift | The Werewolf shifts once into hybrid form (Bite and Longbow available); the Night Hag doesn't shift in a fight | The forms only change size and which attacks it can use | Phase 3 social scenes |
| Animate Dead, Find Familiar | Cast before the fight (precast); the undead and the familiar act on their caster's turn order, with no Bonus Action command needed | Commanding every turn would be a click per turn for the same result | — |
| Alert's Initiative swap | Not offered | Needs a start-of-combat choice screen | With the initiative UI |

