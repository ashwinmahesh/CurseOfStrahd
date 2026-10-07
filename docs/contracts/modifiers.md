# Modifier vocabulary (data → rules engine)

Features, feats, species traits, items, spells and conditions change a creature through **modifiers**:
small JSON objects the engine reads (`rules/model/modifier.gd`). Every modifier carries its source, so
every number the UI shows can be broken down ("AC 17 = Chain Mail 16 + Defense 1"). Schema:
`data/schemas/common.schema.json#/$defs/modifier`. ADR 0003 explains the design.

A feature that can't be expressed with these gets `"implemented": "engine"` (bespoke code in
`rules/features/` reads its id) or `"implemented": "text"` (shown to the player; its system arrives in a
later phase, e.g. reactions in Phase 2). Never invent a new `stat` in data: add it here and in the engine.

## Values: formulas

A value is an integer or a formula string: terms joined by `+`/`-`. A term is an integer, `pb`, `level`
(character level), `class_level` (level in the class granting it), `slot_level`, `exhaustion`, `mod:<ability>`,
`score:<ability>`, optionally `N*term` or `term/N` (rounded down). `min` sets a floor.

    {"stat": "hp_max", "value": "2*level"}                        Tough
    {"stat": "initiative", "value": "pb"}                         Alert
    {"stat": "resource", ...}  → use the feature's "resource" block instead (below)

## Stats

| stat | other keys | meaning |
|---|---|---|
| `ac` | value, when | flat AC bonus. Defense: `{"stat":"ac","value":1,"when":{"armor":"any"}}` |
| `ac_formula` | base, abilities, when | alternative base AC; the best formula wins. Mage Armor: `{"stat":"ac_formula","base":13,"abilities":["dex"],"when":{"armor":"none"}}` |
| `ac_min` | value | AC can't be lower than value (Barkskin 17) |
| `ability` | ability, value, max | +value to a score (max defaults to 20) |
| `ability_min` | ability, value | score becomes value if lower (Gauntlets of Ogre Power) |
| `save` | ability (or `all`), value | bonus to saving throws |
| `check` | skill or ability (or `all`), value | bonus to ability checks |
| `initiative` | value | bonus to Initiative |
| `passive` | skill, value | bonus to one passive score (Observant) |
| `attack` | value, when | bonus to attack rolls. Archery: `{"stat":"attack","value":2,"when":{"weapon":"ranged"}}` |
| `damage` | value, when | bonus to damage rolls. Dueling: `{"stat":"damage","value":2,"when":{"weapon":"one_handed_alone"}}` |
| `spell_dc`, `spell_attack` | value | bonus to spell save DC / spell attack rolls |
| `speed` | value, kind (default walk), when | +value ft; `when` sees the armor worn (Fast Movement: `{"armor":"not_heavy"}`, Unarmored Movement: `{"armor":"none","shield":false}`) |
| `speed_set` | value, kind | speed becomes value (Grappled: 0). `kind` may be `fly` etc. to grant a speed; value `"walk"` = equal to the walking Speed (Potion of Flying) |
| `hp_max` | value | + to Hit Point maximum (formulas recompute on level up) |
| `proficiency` | kind, value | kind = skill, save, armor, weapon, tool, language. value = id (`heavy`, `martial`, `thieves_tools`, `perception`, `str`, `common`) |
| `expertise` | value | double Proficiency Bonus with that skill or tool |
| `advantage` / `disadvantage` | on | on = `initiative`, `attack`, `attack:melee`, `attack:ranged`, `save:<ability>`, `save:all`, `save_vs:<condition>` (saves to avoid or end it), `check:<skill or ability>`, `check:all`, `check:choice` (one check the creature picks, e.g. Guidance), `death_save`, `concentration` |
| `attacked_with` | value (`advantage`/`disadvantage`), if_seen, unless_sense | attack rolls against this creature (Faerie Fire only for attackers that see it; Blur not against Blindsight or Truesight) |
| `auto_fail` | on | automatically fail those saves or checks (Paralyzed: `save:str`, `save:dex`) |
| `d20` | value | added to every D20 Test (Exhaustion: `-2*exhaustion`) |
| `resistance` / `vulnerability` / `immunity` | value | damage type, or `all` |
| `condition_immunity` | value | condition id |
| `darkvision` | value | range in ft; the longest source wins |
| `sense` | kind, value | blindsight, tremorsense, truesight range |
| `crit_range` | value | lowest natural d20 that is a Critical Hit (Improved Critical: 19) |
| `attacks_per_action` | value | attacks per Attack action (Extra Attack: 2); the highest source wins |
| `damage_die_min` | value, when | damage dice rolling below value count as value (Great Weapon Fighting: 3) |
| `bonus_die` / `penalty_die` | dice, on (array) | add/subtract a die to those d20 tests (Bless: `{"stat":"bonus_die","dice":"1d4","on":["attack","save:all"]}`) |
| `cantrip_damage` | value, when | add to cantrip damage (Potent Spellcasting: `mod:wis`) |
| `spell_damage` | value, when | add to one damage roll of a spell (Empowered Evocation: `mod:int`, when school evocation) |
| `healing_bonus` | value | add to healing from spells with a slot (Disciple of Life: `2+slot_level`) |
| `carry_size_step` | value | count as this many sizes larger for carrying capacity (Powerful Build: 1) |
| `reach` | value | + reach in ft |
| `spell` | value, ability, uses, always_prepared, at_level, at_class_level | grants a spell. `ability` is an ability id or `choice` (the player picks; species list it in `spellcasting_ability_choice`); from a class or subclass feature it defaults to that class's spellcasting ability and the spell uses that class's DC and attack. `uses: {"count":1,"recharge":"long"}` = once free per rest; `count` may be a formula (`"mod:wis"` with `"min": 1`), or `"count_column": "favored_enemy"` reads the class table |
| `flag` | value | a named switch bespoke code reads (`potent_cantrip`, `relentless_endurance`, `jack_of_all_trades`, `martial_arts`, `circle_forms`, `evasion`; `tireless`: a Short Rest also removes a level of Exhaustion; `celestial_resilience`: Temporary Hit Points of class level + Charisma modifier after a rest) |
| `extra_damage` | dice, type, on (`weapon`), vs, penalty | extra dice on weapon and Unarmed Strike hits (Crusader's Mantle, Enlarge +1d4; Reduce −1d4 with `penalty`) |
| `damage_penalty_die` | dice | subtract a die from the creature's weapon damage (Ray of Enfeeblement) |
| `attacked_penalty_die` | dice | attack rolls against the creature subtract the die (Blade Ward) |
| `attacked_with_by_type` | value, types | Advantage/Disadvantage only for attackers of these creature types (Protection from Evil and Good) |
| `condition_immunity_by_type` | conditions, types | can't be given these conditions by creatures of these types |
| `damage_reduction_die` | dice, type, once_per_turn | damage of that type is reduced by the die (Resistance cantrip) |
| `weapon_override` | items, die, ability, damage_type | reshapes a weapon or Unarmed Strike (Shillelagh, Alter Self) |
| `speed_percent` | value | Speed × value / 100 (Haste 200, Slow 50) |
| `size_step` | value | one size up or down while it lasts (Enlarge/Reduce, Large Form) |
| `inspiration_die` | die, on | a die the creature may add to one failed roll (Bardic Inspiration) |
| `retaliate` | value or dice, type, within | a creature that hits this one with a melee attack from within `within` ft takes the damage (Armor of Agathys `5*slot_level` Cold, Fire Shield 2d8) |
| `spell_list` | value | the granting class may also prepare spells from that class's list, and they count as its own (Magical Secrets: `cleric`, `druid`, `wizard`) |

### `when` filters
`armor`: `any` (wearing any armor), `none`, `light`, `medium`, `heavy`. `shield`: true/false.
`weapon`: `melee`, `ranged`, `finesse`, `thrown`, `one_handed_alone` (one melee weapon, nothing in the other
hand), `two_handed` (melee weapon held in two hands), `light`, `unarmed`. `spell`: true. `school`: a school.
`bloodied`: true (also on Advantage and Disadvantage sources: a berserker's Bloodied Frenzy). `item` / `ammo`: the weapon or ammunition an attack uses (a magic item's `"@self"`; `"unarmed_strike"`
for Unarmed Strikes), `base_item`: the mundane weapon underneath (Bracers of Archery: `longbow`). `spell_class`: the class whose spell it is (Potent Spellcasting: cleric). `spell_id`: one spell
(Agonizing Blast: `"@cantrip"`, the pick of the feature's own choice). `damage_type`: the spell's damage type
(Elemental Affinity: `"@element"`). `incapacitated`: false (Danger Sense; Advantage and Disadvantage sources see
the armor worn and whether the creature is Incapacitated). `armor` also takes `not_heavy`. A `when` value starting
with `@` names a pick of the same feature, like `value` does. Several keys = all must hold.

### `at_level`, `at_class_level`
`at_level`: the modifier starts at that character level (species spells at 3 and 5). For class features the level
comes from where the feature sits in the class table, so don't repeat it. `at_class_level`: the modifier starts
at that level in the class that granted it, for one choice whose parts arrive later (Circle of the Land's spells
at Druid 5, 7 and 9; Unarmored Movement's +5 ft steps at Monk 6, 10, 14 and 18).

## Resources and choices on a feature

    "resource": {"id": "healing_hands", "name": "Healing Hands", "max": 1, "recharge": "long"}
    "resource": {"id": "breath_weapon", "name": "Breath Weapon", "max": "pb", "recharge": "long"}
    "choice":   {"kind": "skill", "count": 1, "from": ["insight", "perception", "survival"]}

`recharge`: `short` (all back on a Short or Long Rest), `long`, `short_one` (one back on a Short Rest, all on
a Long Rest), `turn`, `round`, `dawn`, `none`.

Choice kinds pick the UI widget: skill, expertise, fighting_style, weapon_mastery, cantrip, spell, spellbook,
feat, ability_increase, subclass, invocation, metamagic, maneuver, language, tool, option, damage_type, size,
spellcasting_ability, lineage, beast_form. `filter` narrows the pool: `{"category": "origin"}`, `{"list": "wizard",
"level": 1}`, `{"proficient": true}`. A `kind: option` choice lists its options inline as features; so do
`maneuver`, `metamagic` and `invocation`, and a `fighting_style` choice may add inline options beside the feats
(Blessed Warrior, Druidic Warrior). `count_column` takes the count from the class table (Weapon Mastery,
Invocations, Metamagic, Known Forms).

More filters: spells `lists` (several class lists: Magical Discoveries), `ritual: true`, `granted: true` (the pick is
cast only through the feature's own `spell` modifier, never added to the class's spells: Mystic Arcanum; with an exact
`level` the count is capped by the spells of that level the game has), `known_only: true` (point
at a spell the class already knows instead of learning one; with `damaging: true` only damaging ones: Agonizing
Blast), `list` empty = any class's list (Pact of the Tome); tools `tool_kind` as one kind or a list (Monk:
artisan or musical instrument); weapon masteries `melee: true` (Barbarian); beast forms `cr_column` and
`fly_column` (the Druid table's Max CR and Fly Speed; the count is also capped by the Beasts in the bestiary).
Invocation options carry `prerequisites`: `{"level": 5, "invocation": "pact_of_the_blade", "cantrip": "damage"
| "attack"}`; ChoiceOptions blocks them with the reason.

## Classes

Beyond features, a class names `tool_choices` (a tool choice at level 1: Bard instruments) and, under
`multiclass.proficiencies`, how many of those a multiclass level gives. Pact Magic is `spellcasting.progression:
"pact"` with `pact_slots_column` and `pact_level_column`: its slots stay out of the multiclass caster level, all
share one level, and come back on a Short Rest (`Character.pact_magic()`); `spell_slots()` reports both pools by
level for casting code.

## Conditions

The 15 conditions are data too (`data/conditions/*.json`): modifiers plus `implies` (Paralyzed implies
Incapacitated). Positional rules (Prone, Grappled, auto-crits within 5 ft) are flags the combat code reads.

## Effects (spells and timed things)

Spells and features that create something with a duration use `effects`: `{"effect": "modifiers",
"params": {"modifiers": [...], "target": "self|creature|ally|enemy|area"}}`, `{"effect": "condition",
"params": {"condition": "prone"}}`, `{"effect": "temp_hp", ...}`, `{"effect": "light", "params": {"bright": 20, "dim": 20}}` (dim = feet beyond
the bright radius), `{"effect": "custom", "params": {"id": ...}}`.
The engine's `Effect` (rules/model/effect.gd) holds the source, duration and concentration link.

## Keys only magic items use (docs/contracts/magic_items.md)

`attuned_only` (works while attuned, worn or not: Berserker Axe's Hit Points), `carried` (while on your person: Luck
Blade's saves), `requires_worn` (other items worn and working too: Hammer of Thunderbolts), `requires_gem` (Helm of
Brilliance), and on `attacked_with`, `spell_only` (Spellguard Shield). Flags items set that the engine reads include
`proficiency_plus_1`, `speed_not_reduced`, `max_hit_dice`, `double_hit_dice`, `wound_closure`, `no_magic:<condition or
speed>`, `ignore_difficult_terrain`, `oa_disadvantage`, `sees_invisible`, `lantern_of_revealing`, `hard_to_perceive`,
`spell_attacks_ignore_half_cover`, `spell_turning`, `immune_magic_missile`, `web_immune`, `elemental_command:<element>`,
`bat_cloak`, `regeneration_ring`, `ioun_regeneration`, `kas_initiative`, `illusion`, `berserk` and the Cube of Force's
`cube_*`.

## Data-driven feature recipes and additional modifiers

`Character._walk_feature` retains feature `activation` and `roll_response` dictionaries. `FeatureRecipes` consumes them; descriptions alone never activate a feature.

- `activation`: `cost` (`magic`, `action`, `bonus`, `free`), optional `resource`, `targeting`, `count` (formula, minimum one), `range`, `duration`, spell-compatible `effects`, or `do: dodge`. Targets are validated before costs. `restore_slot` offers free restoration by expending an eligible slot only when a use is missing.
- `roll_response`: `resource`, `kind` (`save` or `d20`), optional `keys_any`, `scope` (`self` or `allies`), `range`, `cost` (`free` or `reaction`), `do` (`add_die` or `reroll`), and `dice`. Failed synchronous tests follow the existing per-feature auto/never reaction policy. `recharge: turn` replenishes on the owner's next turn.
- `temp_hp_bonus`: added to positive THP grants before comparison with existing THP.
- `ignore_resistance`: damage-type exceptions with attack/casting provenance filters; never grants immunity bypass.
- Conditional defense modifiers use `when` against the creature's current situation, including `bloodied`.
- `concentration_damage_immunity`: optional `school` or `spell_id` selects the maintained spell; prevents damage checks only. The `concentration_iron_mind` flag additionally survives ordinary Incapacitated/Stunned, but not Unconscious, Petrified, death, or replacing concentration.
- `speed_cap`: `value` caps final Speed, `kind` defaults to `all`. Lower existing Speed is preserved.
- Modifier `except` excludes matching D20 keys before `on` matches, e.g. `on: save:all`, `except: [save:con]`.
- Prepared spell modifiers may use `at_slot_level` and `prepared_for_classes`; maximum available casting/pact slot level determines eligibility, not remaining slots. Casting ability stays tied to the eligible class.

Activation recipes also support `do: teleport`, point targeting, `swap` with a willing Medium-or-smaller ally, and `upgrades` keyed by `at_level`. `restore_only` exposes slot restoration for an ability used from a spell action. A `summon_effect` recipe can require actual slot expenditure and a spell school, grant formula-based THP, and bind resistance to that THP grant. Defense `when.temporary_hp` checks remaining THP immediately; replacing a bound grant removes its dependent effect.

- `concentration_save_bonus`: for Constitution saves tagged `concentration` while the concentrated spell matches `school`, add the specified `ability` modifier (feat `@increased` resolves during character building), or `value` when no ability is given. It does not modify other Constitution saves or non-spell concentration.
- `after_cast_speed`: on the caster’s own turn after a spell slot is spent to cast a spell of `school`, apply `value` (formula context includes `slot_level`) as a Speed bonus until that turn ends. Same-source effects use normal strongest-effect stacking; free casts and cantrips do not trigger it.

A modifier’s `skill` may resolve a feature-local pick such as `@choice`, just as its `ability` can. Enchanting Conversationalist applies its Intelligence bonus only to its selected skill.

`weapon_ability` offers a proficient one-handed weapon an alternate ability for attack and damage when its modifier is higher; Unarmed Strikes are excluded. `prefer_one_handed` keeps Versatile weapons in a one-handed grip when the other hand is free. Bladesong uses these alongside its AC/Speed/check and concentration-save modifiers; its effect’s `ends_on_two_handed_attack` parameter ends it before a two-handed attack resolves.

`resource_restore` restores `value` uses of `resource` after a successful positive expenditure of `when_spent`. Failed or zero expenditures do not trigger it, and the destination resource’s normal maximum applies. Bladesong uses this to regain a use when Arcane Recovery is spent.

`ritual_duration`: `spell_id` and `value` (minutes): that spell cast as a Ritual outside a fight lasts at least this
long (Emerald Enclave Fledgling: Speak with Animals for 480 minutes).

`resource_cast` may name one `spell` instead of a `school` (Arcane Safeguard's Resistance, Spellfire Spark's Sacred
Flame); a feat-granted spell counts as known. `casting` is `action` or `bonus_action`; a cantrip cast this way spends
the feature's use too. A feature with `policy` (`auto` or `never`, and `policy_cost` for the label) acts on its own
in a fight, and the class tab offers Automatic and Off for it (Rallying Cry, Family First, Stand as One).

`exhaustion_relief`: `when_spent` (a resource) and `value`: spending that resource also removes that many levels of
Exhaustion (Necromancer's Grave Power with Arcane Recovery).

