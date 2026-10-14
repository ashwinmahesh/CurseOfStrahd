# Boss fights at 3 wins in 8

Owner (2026-10-14): every boss fight is won 3 times in 8 on Balanced, seeds 1-8, by the test party playing at full ability. The party is
the four pregens (Godrick the paladin, Liriel the Light cleric, Thistle the ranger, Ratatouille the Diviner wizard) on
tests/support/party_autopilot.gd with `PartyAutopilot.full`: on top of sharp play (Divine Smite on a sturdy foe, Spirit Guardians once foes
close in, Fireball on two) it heals a friend under a third with Healing Word, unleashes the Radiance of the Dawn on two foes within 30 ft,
lays hands on the fallen, brings out Sacred Weapon, blesses the party when no foe can be reached, marks its quarry with Hunter's Mark,
calls down Conjure Barrage and throws Cone of Cold. (Haste on the paladin was tried and left out: it cost the party wins.) Not modelled: Portent,
potions, Web and Hold Person, Guardian of Faith, buffs before the fight. `FightSeriesCase.BOSS_FIGHTS` lists the fights it plays; every other
fight is still tuned against sharp play alone (5 in 8). Rewards a quest earns are one step easier (4), Kostin's warning one step harder (2), and
where no Hit Point step lands on 3 the harder side (2) is kept. Timeouts count as losses and none is left.

Bands in the tests: 2-4 (rewards 3-5, Kostin 1-3). Measured over seeds 1-8 on 2026-10-14 (branch boss-3-of-8).

| Fight | Level | 5 in 8 line-up (before) | Line-up now | Wins now | Target |
|---|---|---|---|---|---|
| Izek's duel | 5 | Izek Strazni (110 HP), 4 Warrior Veterans | Izek Strazni (310 HP), 4 Warrior Veterans | 3/8 | 3 |
| Izek's festival rampage | 5 | Izek Strazni (225 HP), 2 Warrior Veterans, Bandit Captain, 2 Town Guards | Izek Strazni (225 HP), 5 Warrior Veterans, Bandit Captain, 2 Town Guards | 3/8 | 3 |
| The festival loyalists | 5 | Izek Strazni, 5 Warrior Veterans, 4 Town Guards, Bandit Captain | Izek Strazni (110 HP), 11 Warrior Veterans, 4 Town Guards, Bandit Captain | 3/8 | 3 |
| Izek in his room | 5 | Izek Strazni (145 HP), 3 Warrior Veterans, Town Guard | Izek Strazni (360 HP), 3 Warrior Veterans, Town Guard | 3/8 | 3 |
| The coven, all three hags | 6 | Night Hag (180 HP), 2 Night Hags, 3 Swarm of Rats | Night Hag (310 HP), 2 Night Hags (195 HP), 3 Swarm of Rats | 3/8 | 3 |
| Morgantha and Offalia | 6 | 2 Night Hags, 4 Dire Wolfs, 4 Swarm of Rats | 2 Night Hags (340 HP), 4 Dire Wolfs, 4 Swarm of Rats | 2/8 | 2 |
| Morgantha and Bella | 6 | 2 Night Hags, 6 Dire Wolfs, 3 Swarm of Rats | 2 Night Hags (220 HP), 12 Dire Wolfs, 3 Swarm of Rats | 3/8 | 3 |
| The Abbot's wrath | 7 | Deva (250 HP), 2 Mongrelfolks, 3 Berserkers, 2 Flesh Golems | Deva (500 HP), 2 Mongrelfolks, 3 Berserkers, 2 Flesh Golems | 3/8 | 3 |
| Vasilka defends the Abbot | 7 | Flesh Golem (160 HP), 9 Berserkers, 3 Mongrelfolks, Flesh Golem | Flesh Golem (400 HP), 9 Berserkers, 3 Mongrelfolks, Flesh Golem (320 HP) | 3/8 | 3 |
| Vladimir at the beacon | 8 | Vladimir Horngaard, 3 Revenants, Phantom Warrior, 2 Wights | Vladimir Horngaard (300 HP), 3 Revenants (195 HP), Phantom Warrior, 2 Wights | 3/8 | 3 |
| Vladimir's duel | 8 | Vladimir Horngaard, 3 Revenants, Revenant (80 HP) | Vladimir Horngaard (290 HP), 3 Revenants (190 HP), Revenant (80 HP) | 3/8 | 3 |
| Kiril's challenge, guards cleared | 8 | Kiril Stoyanovich, 4 Werewolfs, 3 Dire Wolfs, 3 Wolfs | Kiril Stoyanovich (225 HP), 4 Werewolfs (180 HP), 3 Dire Wolfs, 3 Wolfs | 3/8 | 3 |
| Kiril's challenge, Zuleika vouched | 8 | Kiril Stoyanovich, 5 Werewolfs, 5 Dire Wolfs | Kiril Stoyanovich (125 HP), 5 Werewolfs (95 HP), 5 Dire Wolfs | 3/8 | 3 |
| The den's reckoning | 8 | Kiril Stoyanovich, Emil Toranescu (45 HP), Werewolf (60 HP), 3 Werewolfs, 2 Dire Wolfs, Wolf | Kiril Stoyanovich (225 HP), Emil Toranescu (45 HP), Werewolf (150 HP), 3 Werewolfs (180 HP), 2 Dire Wolfs, Wolf | 3/8 | 3 |
| Lysaga and her hut | 9 | Baba Lysaga's Creeping Hut (110 HP), Baba Lysaga (100 HP) | Baba Lysaga's Creeping Hut (160 HP), Baba Lysaga (145 HP) | 3/8 | 3 |
| The masterless hut | 9 | Baba Lysaga's Creeping Hut (195 HP), 3 Swarm of Insects | Baba Lysaga's Creeping Hut (495 HP), 3 Swarm of Insects | 3/8 | 3 |
| Rahadin on the stair (Gertruda) | 10 | Rahadin (300 HP), 2 Strahd's Animated Armors, Strahd's Animated Armor (50 HP) | Rahadin (690 HP), 3 Strahd's Animated Armors, Strahd's Animated Armor (50 HP) | 3/8 | 3 |
| Rahadin in the hall | 10 | Rahadin, 2 Strahd's Animated Armors, Strahd's Animated Armor (90 HP) | Rahadin (265 HP), 2 Strahd's Animated Armors (220 HP), Strahd's Animated Armor (175 HP) | 3/8 | 3 |
| Rahadin in his chamber | 10 | Rahadin, 3 Strahd's Animated Armors | Rahadin (240 HP), 3 Strahd's Animated Armors (200 HP) | 3/8 | 3 |
| Two brides | 10 | 4 Vampire Spawns, 2 Strahd's Animated Armors | 4 Vampire Spawns (150 HP), 2 Strahd's Animated Armors (185 HP) | 2/8 | 2 |
| All three brides | 10 | 3 Vampire Spawns, 2 Strahd's Animated Armors | 3 Vampire Spawns (175 HP), 2 Strahd's Animated Armors (215 HP) | 2/8 | 2 |
| Vladimir at Strahd's tomb | 10 | Vladimir Horngaard, 4 Revenants, Revenant (80 HP) | Vladimir Horngaard (275 HP), 4 Revenants (180 HP), Revenant (80 HP) | 3/8 | 3 |
| Old Greytooth | 6 | Old Greytooth (195 HP), 2 Dire Wolfs, 3 Wolfs, Bandit Captain | Old Greytooth (290 HP), 2 Dire Wolfs, 3 Wolfs, Bandit Captain | 3/8 | 3 |
| Old Greytooth, Szoldar turned | 6 | Old Greytooth (240 HP), 2 Dire Wolfs, 3 Wolfs, Werewolf | Old Greytooth (310 HP), 2 Dire Wolfs, 3 Wolfs, Werewolf | 2/8 | 2 |
| Bone marshal, the column (L6) | 6 | The Bone Marshal (170 HP), 2 Wights, 6 Skeletons | The Bone Marshal (235 HP), 2 Wights, 6 Skeletons | 3/8 | 3 |
| Bone marshal, riders stood down (L8) | 8 | The Bone Marshal (190 HP), 3 Wights | The Bone Marshal (380 HP), 3 Wights | 3/8 | 3 |
| Bone marshal, the column (L8) | 8 | The Bone Marshal (270 HP), 3 Wights, 6 Skeletons, 2 Phantom Warriors | The Bone Marshal (310 HP), 3 Wights, 6 Skeletons, 2 Phantom Warriors | 3/8 | 3 |
| The Rag Queen | 9 | The Rag Queen (375 HP), 2 Banshees, 4 Scarecrows | The Rag Queen (715 HP), 2 Banshees, 4 Scarecrows | 3/8 | 3 |
| Vine Mother L6 with Adrian | 6 | The Vine Mother (200 HP), 3 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 3 Vine Blights, 5 Needle Blights | 4/8 | 3 |
| Vine Mother L6 | 6 | The Vine Mother (200 HP), 3 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 3 Vine Blights, 5 Needle Blights | 3/8 | 3 |
| Granny Ash | 6 | Granny Ash (145 HP), 3 Dire Wolfs, 4 Needle Blights | Granny Ash (360 HP), 3 Dire Wolfs, 4 Needle Blights | 3/8 | 3 |
| The Count's Huntsman L8 | 8 | The Count's Huntsman (240 HP), Nightmare, 6 Dire Wolfs | The Count's Huntsman (430 HP), Nightmare, 6 Dire Wolfs | 3/8 | 3 |
| Huntsman L8, hounds called (reward) | 8 | The Count's Huntsman (240 HP), Nightmare, 3 Dire Wolfs | The Count's Huntsman (470 HP), Nightmare, 3 Dire Wolfs | 4/8 | 4 |
| The Count's Huntsman L9 | 9 | The Count's Huntsman (290 HP), Nightmare, 6 Dire Wolfs | The Count's Huntsman (520 HP), 7 Nightmares, 6 Dire Wolfs | 3/8 | 3 |
| The Count's Huntsman L10 | 10 | The Count's Huntsman (390 HP), Nightmare, 8 Dire Wolfs | The Count's Huntsman (545 HP), 7 Nightmares, 8 Dire Wolfs | 3/8 | 3 |
| The Penitent L10 | 10 | The Penitent (480 HP), 5 Ghasts | The Penitent (625 HP), 5 Ghasts | 3/8 | 3 |
| The Penitent L9 | 9 | The Penitent (420 HP), 4 Ghasts | The Penitent (645 HP), 4 Ghasts | 3/8 | 3 |
| The Penitent L11 | 11 | The Penitent (590 HP), 10 Ghasts | The Penitent (780 HP), 10 Ghasts | 3/8 | 3 |
| The Tinker's Wagon L5 | 5 | The Tinker's Wagon (220 HP), Mimic | The Tinker's Wagon (220 HP), Mimic | 3/8 | 3 |
| The Tinker's Wagon L6 | 6 | The Tinker's Wagon (160 HP), 5 Mimics | The Tinker's Wagon (450 HP), 5 Mimics | 2/8 | 2 |
| The Grandsire L8 | 8 | The Grandsire (165 HP), 2 Werewolfs, 2 Dire Wolfs | The Grandsire (410 HP), 2 Werewolfs, 2 Dire Wolfs | 3/8 | 3 |
| The Grandsire L9 | 9 | The Grandsire (150 HP), 3 Werewolfs, 2 Dire Wolfs | The Grandsire (270 HP), 3 Werewolfs, 2 Dire Wolfs | 3/8 | 3 |
| Corvina | 10 | Corvina, the Doorkeeper, 4 Helmed Horrors | Corvina, the Doorkeeper (250 HP), 10 Helmed Horrors | 3/8 | 3 |
| Corvina, named (reward) | 10 | Corvina, the Doorkeeper (105 HP), 4 Helmed Horrors | Corvina, the Doorkeeper (105 HP), 10 Helmed Horrors | 4/8 | 4 |
| Sarkhaza as she is | 10 | Sarkhaza | Sarkhaza (300 HP) | 3/8 | 3 |
| Sarkhaza unchained L11 | 11 | Sarkhaza (212 HP) | Sarkhaza (375 HP) | 3/8 | 3 |
| Khazan, his name standing | 10 | Khazan (210 HP), 2 Specters | Khazan (315 HP), 2 Specters | 3/8 | 3 |
| Khazan unmade (reward) | 10 | Khazan (125 HP), 4 Specters, Wraith | Khazan (290 HP), 4 Specters, Wraith | 4/8 | 4 |
| The Eye Below | 10 | The Eye Below (135 HP), Dream-Gazer | The Eye Below (335 HP), Dream-Gazer | 3/8 | 3 |
| The Eye, both wardens' ways (reward) | 10 | The Eye Below (100 HP) | The Eye Below (335 HP) | 4/8 | 4 |
| Ash Effigy and Zorica L7 | 7 | The Ash Effigy (155 HP), Druid, 5 Twig Blights | The Ash Effigy (355 HP), Druid, 5 Twig Blights | 3/8 | 3 |
| Ash Effigy L8, Kostin doubting (reward) | 8 | The Ash Effigy (190 HP), 4 Twig Blights | The Ash Effigy (430 HP), 4 Twig Blights | 4/8 | 4 |
| Ash Effigy L8 with a druid | 8 | The Ash Effigy (205 HP), Druid, 4 Twig Blights | The Ash Effigy (480 HP), Druid, 4 Twig Blights | 3/8 | 3 |
| The Lantern Girl | 5 | The Lantern Girl, 4 Will-o'-Wisps | The Lantern Girl (90 HP), 8 Will-o'-Wisps | 3/8 | 3 |
| The Count's Likeness | 9 | The Count's Likeness (245 HP), 7 Guardian Portraits (40 HP) | The Count's Likeness (495 HP), 7 Guardian Portraits (40 HP) | 3/8 | 3 |
| Querreth | 10 | Querreth (335 HP), 2 Wraiths | Querreth (545 HP), 2 Wraiths | 3/8 | 3 |
| Querreth, forewarned (reward) | 10 | Querreth (280 HP), 2 Wraiths | Querreth (590 HP), 2 Wraiths | 4/8 | 4 |
| The Gilded Knight | 9 | The Gilded Knight (410 HP), 3 Animated Armors | The Gilded Knight (710 HP), 12 Animated Armors | 3/8 | 3 |
| The Forgotten Storm | 8 | The Forgotten Storm (240 HP), Air Elemental (60 HP) | The Forgotten Storm (430 HP), Air Elemental (60 HP) | 3/8 | 3 |
| The Amber guide | 10 | The Guide (155 HP), 2 Wraiths, 2 Shadows | The Guide (155 HP), 5 Wraiths, 2 Shadows | 3/8 | 3 |
| The Index | 9 | The Index (185 HP), 2 Mimics | The Index (390 HP), 2 Mimics | 3/8 | 3 |
| Grandfather Stone | 10 | Grandfather Stone (220 HP) | Grandfather Stone (395 HP) | 3/8 | 3 |
| Summit L5 | 5 | Tree Blight (84 HP), Druid (50 HP), 4 Twig Blights | Tree Blight (155 HP), Druid (50 HP), 4 Twig Blights | 3/8 | 3 |
| Summit L5, druids fled (reward) | 5 | Tree Blight (90 HP), 6 Twig Blights | Tree Blight (135 HP), 6 Twig Blights | 4/8 | 4 |
| Summit L5, struck first (reward) | 5 | Tree Blight (90 HP), Druid (45 HP), Druid, 4 Twig Blights | Tree Blight (180 HP), Druid (45 HP), Druid, 4 Twig Blights | 4/8 | 4 |
| Summit L5, Kostin warned them (harder) | 5 | Tree Blight (65 HP), Druid (50 HP), Druid (30 HP), 4 Twig Blights | Tree Blight (120 HP), Druid (90 HP), Druid (30 HP), 4 Twig Blights | 2/8 | 2 |
| Summit L6 | 6 | Tree Blight (158 HP), Druid (60 HP), 6 Twig Blights | Tree Blight (270 HP), Druid (60 HP), 6 Twig Blights | 3/8 | 3 |
| Summit L6, druids fled (reward) | 6 | Tree Blight (135 HP), 6 Twig Blights, 2 Vine Blights, 3 Needle Blights | Tree Blight (200 HP), 6 Twig Blights, 2 Vine Blights, 3 Needle Blights | 4/8 | 4 |
| Summit L6, struck first (reward) | 6 | Tree Blight (136 HP), Druid (58 HP), 2 Druids, 4 Twig Blights | Tree Blight (285 HP), Druid (58 HP), 2 Druids, 4 Twig Blights | 4/8 | 4 |
| Summit L6, Kostin warned them (harder) | 6 | Tree Blight (95 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | Tree Blight (210 HP), Druid (130 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | 2/8 | 2 |
| Summit L7 | 7 | Tree Blight (165 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | Tree Blight (260 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | 3/8 | 3 |
| Summit L7, druids fled (reward) | 7 | Tree Blight (125 HP), 6 Twig Blights, 3 Vine Blights, 3 Needle Blights | Tree Blight (200 HP), 6 Twig Blights, 3 Vine Blights, 3 Needle Blights | 4/8 | 4 |
| Summit L7, struck first (reward) | 7 | Tree Blight (125 HP), Druid (55 HP), 2 Druids, Berserker, 4 Twig Blights | Tree Blight (285 HP), Druid (55 HP), 2 Druids, Berserker, 4 Twig Blights | 4/8 | 4 |
| Summit L7, Kostin warned them (harder) | 7 | Tree Blight (110 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | Tree Blight (220 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | 2/8 | 2 |
| Vine Mother L5 | 5 | The Vine Mother (101 HP), Vine Blight, 3 Needle Blights | The Vine Mother (180 HP), Vine Blight, 3 Needle Blights | 3/8 | 3 |
| Vine Mother L7 | 7 | The Vine Mother (136 HP), 4 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 4 Vine Blights, 5 Needle Blights | 3/8 | 3 |
| Vine Mother L8 | 8 | The Vine Mother (200 HP), 5 Vine Blights, 6 Needle Blights, Tree Blight | The Vine Mother (340 HP), 5 Vine Blights, 6 Needle Blights, Tree Blight | 3/8 | 3 |
| Offalia in the bakery | 6 | Night Hag (300 HP), 5 Nightmares | Night Hag (285 HP), 8 Nightmares | 3/8 | 3 |
| Bella betrayed | 6 | Night Hag (250 HP), 3 Nightmares, 3 Dire Wolfs | Night Hag (250 HP), 6 Nightmares, 3 Dire Wolfs | 3/8 | 3 |
| Bella on the road | 6 | Night Hag (300 HP), 3 Nightmares | Night Hag (300 HP), 5 Nightmares | 2/8 | 2 |
| Offalia on the road | 6 | Night Hag (300 HP), 4 Nightmares | Night Hag (300 HP), 7 Nightmares | 3/8 | 3 |
| Morgantha alone | 6 | Night Hag (300 HP), 3 Swarm of Rats, 4 Nightmares | Night Hag (300 HP), 3 Swarm of Rats, 7 Nightmares | 3/8 | 3 |
| Lysaga at Marina's grave | 9 | Baba Lysaga (180 HP), 2 Swarm of Insects, 4 Scarecrows | Baba Lysaga (440 HP), 2 Swarm of Insects, 10 Scarecrows | 3/8 | 3 |
| Lysaga in her kitchen | 9 | Baba Lysaga (400 HP), 8 Swarm of Insects, 4 Scarecrows | Baba Lysaga (600 HP), 8 Swarm of Insects, 12 Scarecrows | 3/8 | 3 |
| The roc and its mate | 9 | Roc (190 HP), Roc (85 HP) | Roc (285 HP), Roc (85 HP) | 3/8 | 3 |
| Exethanter | 10 | Exethanter, 6 Flameskulls | Exethanter (100 HP), 6 Flameskulls, 8 Wraiths | 3/8 | 3 |
| Vosk unmasked | 10 | Arcanaloth (135 HP), 2 Flameskulls | Arcanaloth (320 HP), 2 Flameskulls | 3/8 | 3 |
| Vosk named and weakened (reward) | 10 | Arcanaloth (80 HP) | Arcanaloth (205 HP), 2 Flameskulls | 4/8 | 4 |
| Sarkhaza, the keepers' three tricks (reward) | 10 | Sarkhaza (125 HP) | Sarkhaza (515 HP) | 4/8 | 4 |
| Strahd woken by day (Sunsword) | 10 | Strahd von Zarovich (350 HP), 2 Swarm of Bats, Vampire Spawn | Strahd von Zarovich (455 HP), 2 Swarm of Bats, 7 Vampire Spawns | 3/8 | 3 |
| Strahd's dinner (Sunsword) | 10 | Strahd von Zarovich (375 HP), 3 Swarm of Bats, 2 Strahd's Animated Armors | Strahd von Zarovich (490 HP), 3 Swarm of Bats, 2 Strahd's Animated Armors, 3 Vampire Spawns | 3/8 | 3 |
| Strahd at the broken heart (Sunsword) | 10 | Strahd von Zarovich (350 HP), 2 Strahd's Animated Armors | Strahd von Zarovich (455 HP), 2 Strahd's Animated Armors, 6 Vampire Spawns | 3/8 | 3 |
| Final: the horseman's crypt | 10 | Strahd von Zarovich (375 HP), Nightmare, 2 Swarm of Bats, 2 Vampire Spawns | Strahd von Zarovich (565 HP), Nightmare, 2 Swarm of Bats, 5 Vampire Spawns | 3/8 | 3 |
| Final: his tomb | 10 | Strahd von Zarovich (350 HP), 2 Vampire Spawns | Strahd von Zarovich (410 HP), 5 Vampire Spawns | 3/8 | 3 |
| Final: the royal tomb | 10 | Strahd von Zarovich (400 HP), 3 Specters, 2 Vampire Spawns | Strahd von Zarovich (495 HP), 3 Specters, 8 Vampire Spawns | 3/8 | 3 |
| Final: Sergei's tomb | 10 | Strahd von Zarovich (350 HP), 3 Dire Wolfs, 2 Swarm of Bats, 3 Vampire Spawns | Strahd von Zarovich (455 HP), 3 Dire Wolfs, 2 Swarm of Bats, 7 Vampire Spawns | 3/8 | 3 |
| Final: the chapel | 10 | Strahd von Zarovich (350 HP), 6 Vampire Spawns | Strahd von Zarovich (455 HP), 12 Vampire Spawns | 3/8 | 3 |
| Final: the audience hall | 10 | Strahd von Zarovich (350 HP), 3 Dire Wolfs, 4 Vampire Spawns | Strahd von Zarovich (635 HP), 3 Dire Wolfs, 10 Vampire Spawns | 3/8 | 3 |
| Final: his study | 10 | Strahd von Zarovich (350 HP), 2 Swarm of Bats, 5 Vampire Spawns | Strahd von Zarovich (635 HP), 2 Swarm of Bats, 8 Vampire Spawns | 3/8 | 3 |
| Final: the treasury | 10 | Strahd von Zarovich (400 HP), Helmed Horror, 3 Vampire Spawns | Strahd von Zarovich (600 HP), Helmed Horror, 9 Vampire Spawns | 3/8 | 3 |
| Final: the donjon | 10 | Strahd von Zarovich (350 HP), 10 Skeletons, 4 Vampire Spawns | Strahd von Zarovich (520 HP), 10 Skeletons, 10 Vampire Spawns | 3/8 | 3 |
| Final: the overlook | 10 | Strahd von Zarovich (350 HP), 3 Swarm of Bats, Vampire Spawn | Strahd von Zarovich (590 HP), 3 Swarm of Bats, 4 Vampire Spawns | 3/8 | 3 |
| Final: the Heart of Sorrow | 10 | Strahd von Zarovich (350 HP), Helmed Horror, 2 Vampire Spawns | Strahd von Zarovich (455 HP), Helmed Horror, 8 Vampire Spawns | 3/8 | 3 |
| Strahd's test of strength L7 | 7 | Strahd von Zarovich, 2 Dire Wolfs | Strahd von Zarovich (355 HP), 2 Dire Wolfs | 3/8 | 3 |
| Strahd at the Blue Water Inn window L5 | 5 | Strahd von Zarovich (110 HP), Swarm of Bats | Strahd von Zarovich (170 HP), Swarm of Bats | 3/8 | 3 |
| Strahd at the Krezkovs' window L7 | 7 | Strahd von Zarovich (200 HP), Swarm of Bats | Strahd von Zarovich (360 HP), Swarm of Bats | 3/8 | 3 |
| Summit L5, circle broken (reward) | 5 | Tree Blight (74 HP), Druid (50 HP), 4 Twig Blights | Tree Blight (135 HP), Druid (90 HP), 4 Twig Blights | 4/8 | 4 |
| Summit L6, circle broken (reward) | 6 | Tree Blight (140 HP), Druid (60 HP), 6 Twig Blights | Tree Blight (215 HP), Druid (60 HP), 6 Twig Blights | 4/8 | 4 |
| Summit L7, circle broken (reward) | 7 | Tree Blight (100 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | Tree Blight (250 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | 4/8 | 4 |
