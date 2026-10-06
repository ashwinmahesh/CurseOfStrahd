# Rule deviations

Every place the game departs from the 2024 rules, with the reason. A rule that simply isn't built yet is "not
started" in coverage.md, not a deviation.

| Rule | What the game does | Why | Revisit |
|---|---|---|---|
| Temporary Hit Points don't stack: "you decide whether to keep the ones you have or gain the new ones" | The engine keeps the higher amount automatically | Keeping the lower is never better outside contrived cases; saves a prompt in every combat | Phase 3: offer the choice when the new amount is lower and the old ones expire sooner |
| Combining game effects: the most potent of identical effects applies | Potency is approximated by the size of the effects' numbers (conditions weigh most); ties go to the most recent | The rules leave "most potent" to judgment | If two versions of the same spell ever compete in a way the approximation gets wrong |
| Frightened (positional parts) | Disadvantage applies whether or not the source is in sight. "Can't willingly move closer" is enforced for everyone (Phase 3) and read strictly: no square closer to a visible source than where the move began | The roll code has no line-of-sight context yet; the strict reading never lets a frightened creature end closer | Phase 4: Disadvantage only while the source is in sight |
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
| After a won fight | Dying party members are stabilized at 0 Hit Points (their friends tend them) | Rolling death saves every 6 seconds out of combat with nobody hostile adds nothing; the rules let anyone stabilize them with a DC 10 Medicine check | — |
| Forcing a lock | A Strength (Athletics) check against the lock's DC + 2 | The rules leave forcing to the DM; slightly harder than picking keeps Thieves' Tools worth carrying | — |
| Disarming a trap | Failing by 5 or more springs it | A common table ruling; the 2024 rules leave failure to the DM | — |
| Long Rest interruption | In a "risky" place, a 1 in 6 chance; an interrupted rest gives a Short Rest's benefits | Random encounters arrive with travel in Phase 4 | Phase 4 |
| Group Stealth for surprise | The party's lowest Stealth total is compared with each enemy's passive Perception | The rules leave group stealth to the DM; the lowest roll is the one that gets heard | — |
| Exploration movement | On the grid, one square at a time, followers stepping into the square ahead | ADR 0009: one geometry for exploring and fighting | — |
| Flying | A flyer moves over the grid at its Fly Speed like a walker: no altitude, so it can't pass over walls, pits or other creatures, and it isn't out of melee reach | The maps have no vertical space yet; Death House's animated weapons and broom need to move | Phase 5, with elevation in the bigger maps |
| Ready | Readied spells are offered from the hotbar's right-click menu and trigger when an enemy comes within the spell's range | The 2024 trigger is any perceivable circumstance; range is the useful one in a grid fight | Phase 3, with custom triggers |
| D20 Test choices made in the middle of a roll (Indomitable, Stroke of Luck, Mage Slayer's Guarded Mind, Heroic Inspiration on a save, Tactical Mind) | Used automatically on a failure unless the creature's rule for it is "never" | A save can't pause the fight for a prompt; failing the save is almost always worse | When saves can pause like attacks do |
| Lucky's Advantage | Armed from the hotbar for the next D20 Test; Lucky against an attack is a prompt | The rule lets you decide after seeing the situation, before the roll | — |
| Portent | Assigned from the hotbar to a creature's next D20 Test | Same as the rule, chosen ahead of the roll | — |
| Cast-time choices | The first option is the default; the hotbar's right-click menu picks another | Keeps one click for the common case | — |
| Commander's Strike, Crown of Madness, Maneuvering Attack | The ally's attack target, the crowned creature's victim and the maneuvering ally are picked automatically (the best target in reach; the nearest ally) | Saves a second targeting step | With the targeting polish |
| Charger, Lunging Attack | "Moved this turn" stands in for "moved 5 (10) ft in a straight line toward the target" | The grid path isn't tracked as straight lines | — |
| Disarming Attack | The dropped weapon is picked up at the start of the creature's next turn (its free object interaction) | Items on the ground aren't modelled | Phase 4 inventory |
| Levitate, Fly | No altitude on the grid: Levitate puts the target out of melee reach and stops its walking; flyers ignore ground terrain | The grid is flat | Phase 3 levels |
| Blink, Etherealness, Plane Shift | Blinking back lands on the same square; a monster that escapes this way leaves the fight | Saves a placement step; the escape is what matters in a fight | — |
| Loathsome Limbs | Severed arms and heads fight on as their own creatures sharing the body's Hit Points; severed legs only slow the body | Legs can't attack | — |
| Shape-Shift | The Werewolf shifts once into hybrid form (Bite and Longbow available); the Night Hag doesn't shift in a fight | The forms only change size and which attacks it can use | Phase 3 social scenes |
| Animate Dead, Find Familiar | Cast before the fight (precast); the undead and the familiar act on their caster's turn order, with no Bonus Action command needed | Commanding every turn would be a click per turn for the same result | — |
| Alert's Initiative swap | Not offered | Needs a start-of-combat choice screen | With the initiative UI |
| Wild Shape known forms | The number of known forms is capped by the Beast stat blocks the game has that fit the Druid's CR and Fly Speed limits (two at Druid 2-7 today) | The choice can't dead-end while the bestiary is small; the count grows by itself as Beasts are added | When the bestiary has enough Beasts |
| Repeatable Eldritch Invocations | Agonizing Blast, Eldritch Spear, Repelling Blast and Lessons of the First Ones can each be taken once | A choice pick is unique per option; taking one twice needs a second sub-choice | If a player asks for it |
| Iron Mind (Gloom Stalker) | The player picks Wisdom, Intelligence or Charisma saves; the rule says Wisdom unless already proficient | The option text says so; enforcing it needs a "lacks proficiency" check on options | — |
| Polymorph and Wild Shape forms | The creature becomes the Beast's stat block with its own Hit Points kept (Wild Shape also keeps Int, Wis, Cha and Proficiency Bonus); its gear, class features and spells wait until it changes back | A full merge of character and stat block is a large system; these are the parts a fight uses | — |
| Mounted combat | Any willing ally a size larger can be mounted (half your Speed); a ridden ally is a controlled mount that moves on its rider's turn and can't attack; a mount moved against its will makes its rider save (DC 10 Dex) or fall Prone; an uncontrolled (independent) mount isn't offered | Every mount in the game so far is a friendly summon | When hostile riders appear |
| Banishment | The banished creature leaves the grid; a native of another plane banished for 10 rounds doesn't return | Same as the rule, counted in rounds | — |
| Conjure Animals | The caster's free move of the pack is a separate free action once per turn; Advantage on Strength saves within 5 ft of the pack is applied | The pack moving "when you move" needs a combined move | — |
| Conjure Minor Elementals | The extra damage type is picked for you each attack: whichever the target doesn't resist | Saves a prompt per attack | — |
| Call Lightning | No stormy weather bonus | The game has no weather yet | With weather |
| Wall of Fire | A straight wall along the cast direction or a ring 20 ft across (burning on its inside); a straight wall burns on the side its direction points left of | Free-form wall shapes need a drawing tool | With the targeting polish |
| Dissonant Whispers, Confusion, Compulsion | The fleeing or compelled creature takes the farthest square along its path, provoking Opportunity Attacks as it goes | "Safest path" is the DM's call | — |
| Heat Metal | What's heated is picked for you: a held metal weapon first, else worn metal armor | Saves a choice of object | — |
| Wild Magic Surge | A condensed 8-result table of the surge's combat effects | The full table is mostly out-of-combat whimsy | With the full table |
| Reactions that happen during a save or at the start of another creature's turn (Countercharm, Bend Luck, Cosmic Omen, Restore Balance, Dark One's Own Luck, Branches of the Tree, Inspiring Movement, Tandem Footwork, Fanatical Focus) | Used automatically when they'd help, unless the creature's rule for it is "never" | Same reason as the other mid-roll choices | When saves can pause like attacks do |
| Pact of the Chain familiars | The eight special forms use 2025 Monster Manual numbers as we know them, not yet checked against the book; a familiar only attacks when its warlock gives up an attack (or with Investment of the Chain Master's command) | The forms are built in code from the warlock's casting; checking needs the owner's book | Check against the MM |
| Cosmic Omen | The omen (Weal or Woe) is drawn when a fight starts rather than at the last Long Rest | Rests don't keep a dawn roll yet | — |
| Gaze of Two Minds | The link lets you cast from the ally's space; perceiving through its senses isn't modelled | Sight sharing has no use on a grid where the player sees everything | — |

