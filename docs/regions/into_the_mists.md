# Region design: Into the Mists (Phase 3)

Plan §6 row 1 (first half). Party level 1. Source: *Curse of Strahd*, the arrival in Barovia (the mists, the Old
Svalich Road, the Gates of Barovia), retold in our own words. Owner: the Into the Mists / Death House narrative
designer. The data and dialogue files listed in §8 are the source of truth for exact text.

## 1. What this region is for

The opening ten minutes: the party is delivered into Barovia by the mist, learns that the way back is closed, meets
the first sign that someone is watching (an organized wolf pack), passes the Gates of Barovia and reaches the village
edge, where Rose and Thorn beg them to save their baby brother from the house by the dead tree. Short on purpose:
one map, a few narrator beats, one optional fight.

Tone: ominous and a little wry. The jokes come from the party (pregen hooks, Tamsin's "large, organized dog").

## 2. Layout and scenes

One map, `into_the_mists_road` (32 x 24, outdoors, dim). The party walks east to west.

| Area (enter: trigger) | Cells | What happens |
|---|---|---|
| `mists_svalich_woods` | x 21-31 | Spawn `default` [30, 15] at the edge of the mist. The mist wall prop plays the arrival and the four pregens' hooks. A clearing holds a wolf-killed deer (Survival reads the pack); another holds an abandoned cart (loot). A wolf trap lies in the road. The narrows at [21, 15] are blocked by the wolf pack. |
| `mists_gates` | x 17-20 | A wayside shrine to the Morninglord, defaced. The Gates of Barovia: headless stone knights, iron gates that open by themselves (`mists_gates_opened`). The statues' heads lie in the weeds (search DC 12). |
| `mists_village_edge` | x 0-16 | Shuttered cottages, a crow on a barrel. Rose and Thorn in the road at [6, 14] / [6, 16]. Exit `into_the_village` [0, 15] leads to `village_of_barovia`, spawn `from_east_road`. Spawn `from_village` [1, 15] is for the village's east road coming back. |

### Scene flow

1. **The mist wall** (prop `mists_wall`, `into_the_mists/arrival:mist_wall`). Walking back into the fog turns the party
   around. First time: each pregen states why they came (Ilse's company and the S letter, Tamsin's locket, Hedda's
   raven dream, Silvain's lost colleague Aurel). Quest `into_the_mists` → `lost_in_mist`.
2. **The carcass** (optional, `arrival:carcass`). Survival DC 12 shows the wolves are a patrol: `mists_read_the_pack`.
3. **The pack in the narrows** (NPC `mists_wolves`, `into_the_mists/wolves:start`). The wolf blocks the only path.
   Intimidation 13, Animal Handling 12, Insight 10 (only if the pack was read), a wizard's Arcana 12, or a fight.
   Quest → `the_pack`.
4. **The Gates of Barovia.** They open on their own. Narration only.
5. **Rose and Thorn** (`death_house/rose_thorn:start`). The plea; quest `into_the_mists` → `village_edge` (success),
   `death_house` → `plea`. See docs/regions/death_house.md.

## 3. NPCs

| id | Name | Wants | Voice | Stat block |
|---|---|---|---|---|
| `mists_wolves` | The Wolves | to look at the newcomers and report | the Narrator speaks for them | wolf |
| `rose`, `thorn` | the Durst children (an illusion) | to lure strangers into Death House | docs/voice/rose.md, thorn.md | — |

The pregens' voices (docs/voice/ilse_varga.md, tamsin_tealeaf.md, hedda_ironvow.md, silvain_aster.md) carry the
interjections.

## 4. Quest

`into_the_mists` (Into the Mists): `lost_in_mist` → `the_pack` → `village_edge` (success). Each stage is reachable
independently; the journal shows whichever were reached.

## 5. Encounters

| id | Trigger | Monsters | XP | Party level | Difficulty (2024 DMG, 4 PCs) |
|---|---|---|---|---|---|
| `mists_wolves` | dialogue (failed check or "draw steel") | 3 wolves (two ahead in the narrows, one flanking from the trees behind) | 150 | 1 | Low (budget 200 / 300 / 400) |

Trap: `mists_wolf_trap` [25, 15], detect 11, disarm 11, Dex save 11, 1d6 piercing.

## 6. Choices and consequences

| Choice | Options | Flags | Downstream |
|---|---|---|---|
| The pack in the narrows | Intimidation, Animal Handling, Insight (if the tracks were read), Arcana (wizard), fight, wait | `mists_wolves_resolved`; `mists_wolves_cowed` or `mists_wolves_fought` | Gate narration, Death House banter. Strahd's wolves have reported the party; Phase 4 Strahd/wolf scenes may read how they met the pack. |
| Read the carcass | Survival DC 12 | `mists_read_the_pack` | Opens the easy Insight route past the wolves. |

## 7. Flags (data/flags/into_the_mists.json)

| Flag | Type | Set by | Read by |
|---|---|---|---|
| `mists_arrived` | bool | arrival:mist_wall | arrival:mist_wall |
| `mists_carcass_studied` | bool | arrival:carcass | arrival:carcass |
| `mists_read_the_pack` | bool | arrival:carcass | arrival:carcass, wolves:choose |
| `mists_wolves_resolved` | bool | wolves | map (wolf NPC `when`), narrator |
| `mists_wolves_cowed` | bool | wolves | narrator (gates), banter; Village / P4 may read |
| `mists_wolves_fought` | bool | encounter `mists_wolves` | narrator (gates), banter; P4 may read |
| `mists_gates_opened` | bool | door `barovia_gates` | narrator (gate statues) |

## 8. Files

- Location: data/locations/into_the_mists_road.json
- NPCs: data/npcs/mists_wolves.json (rose and thorn: see death_house.md)
- Quest: data/quests/into_the_mists.json
- Flags: data/flags/into_the_mists.json
- Dialogue: narrative/into_the_mists/{arrival, wolves}.dialogue, narrative/death_house/rose_thorn.dialogue,
  narrative/narrator/into_the_mists.dialogue

## 9. Hand-off to the Village of Barovia

- The village's east road should have an exit back onto this map (spawn `from_village`).
- The children in the road are this map's NPCs (`rose`, `thorn`), because Death House's exterior lot belongs to the
  village map. If the Village owner prefers them at the house gate, move the two `npcs` entries (with their `when`
  conditions) to `village_of_barovia`'s `death_house_lot`; the dialogue files work unchanged.
