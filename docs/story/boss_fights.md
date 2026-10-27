# Boss fights at 3 wins in 8

**Hit Points since 2026-10-26** (owner, 2026-10-24: "all the battles where you made them harder by beefing up the HP. Bring the HP back down and just have monsters hit harder", "Apply this everywhere, not just bosses"): every boss fights at its stat block's Hit Points. The raised Hit Points the tables below give (and the lighter ones for low-level versions) are gone from the data, 196 fight entries in all; what makes a boss hard now is the bosses' 25% harder hits and their +1 to +3 to hit and DCs by the party's level on Balanced. The win counts below were measured before and not again (owner's rule).

**Line-ups since 2026-10-25** (owner: "for pretty much all battles in the book, we can remove extra enemies we added and just leave them how they are in the book", then "Yes for boss fights"): in the book's boss fights every boss and every story foe stays as it is now (stat block, Hit Points, the bosses' 25% harder hits), and the other foes go back to the number and kinds the fight was first entered with from the module (git history's first version; Vallaki's guards keep their own stat block, which came before the scale-up). The extra spawn, armour, wolves, nightmares and blights the line-ups below list are gone from the data, as are the intro sentences that brought them in; the win counts are the ones measured before. The side quests' bosses keep their line-ups.

Owner (2026-10-14): every boss fight is won 3 times in 8 on Balanced, seeds 1-8, by the test party playing at full ability. The party is
the four pregens (Godrick the paladin, Liriel the Light cleric, Thistle the ranger, Ratatouille the Diviner wizard) on
tests/support/party_autopilot.gd with `PartyAutopilot.full`: on top of sharp play (Divine Smite on a sturdy foe, Spirit Guardians once foes
close in, Fireball on two) it heals a friend under a third with Healing Word, unleashes the Radiance of the Dawn on two foes within 30 ft,
lays hands on the fallen, brings out Sacred Weapon, blesses the party when no foe can be reached, marks its quarry with Hunter's Mark,
calls down Conjure Barrage and throws Cone of Cold. (Haste on the paladin was tried and left out: it cost the party wins.) Not modelled: Portent,
potions, Web and Hold Person, Guardian of Faith, buffs before the fight. `FightSeriesCase.BOSS_FIGHTS` lists the fights it plays; every other
fight is still tuned against sharp play alone (5 in 8). Rewards a quest earns are one step easier (4), Kostin's warning one step harder (2), and
where no Hit Point step lands on 3 the harder side (2) is kept. Timeouts count as losses and none is left.

Bands in the tests: 2-4 (rewards 3-5, Kostin 1-3; Sarkhaza in every version, 0-1). Measured over seeds 1-8 on 2026-10-14
(branch boss-3-of-8); Sarkhaza's rows on 2026-10-18 (branch sarkhaza-ancient).

| Fight | Level | 5 in 8 line-up (before) | Line-up now | Wins now | Target |
|---|---|---|---|---|---|
| Izek's duel | 5 | Izek Strazni (110 HP), 4 Warrior Veterans | Izek Strazni (280 HP), 6 Warrior Veterans | 3/8 | 3 |
| Izek's festival rampage | 5 | Izek Strazni (225 HP), 2 Warrior Veterans, Bandit Captain, 2 Town Guards | Izek Strazni (225 HP), 2 Warrior Veterans, Bandit Captain, 2 Town Guards | 6/8 | 3 |
| The festival loyalists | 5 | Izek Strazni, 5 Warrior Veterans, 4 Town Guards, Bandit Captain | Izek Strazni, 5 Warrior Veterans, 4 Town Guards, Bandit Captain | 6/8 | 3 |
| Izek in his room | 5 | Izek Strazni (145 HP), 3 Warrior Veterans, Town Guard | Izek Strazni (360 HP), 3 Warrior Veterans, Town Guard | 3/8 | 3 |
| The coven, all three hags | 6 | Night Hag (180 HP), 2 Night Hags, 3 Swarm of Rats | Night Hag (310 HP), 2 Night Hags (195 HP), 3 Swarm of Rats | 3/8 | 3 |
| Morgantha and Offalia | 6 | 2 Night Hags, 4 Dire Wolfs, 4 Swarm of Rats | 2 Night Hags (340 HP), 4 Dire Wolfs, 4 Swarm of Rats | 2/8 | 2 |
| Morgantha and Bella | 6 | 2 Night Hags, 6 Dire Wolfs, 3 Swarm of Rats | 2 Night Hags (110 HP), 12 Dire Wolfs, 3 Swarm of Rats | 3/8 | 3 |
| The Abbot's wrath | 7 | Deva (250 HP), 2 Mongrelfolks, 3 Berserkers, 2 Flesh Golems | Deva (350 HP), 2 Mongrelfolks, 3 Berserkers, 2 Flesh Golems | 3/8 | 3 |
| Vasilka defends the Abbot | 7 | Flesh Golem (160 HP), 9 Berserkers, 3 Mongrelfolks, Flesh Golem | Flesh Golem (400 HP), 9 Berserkers, 3 Mongrelfolks, Flesh Golem (320 HP) | 3/8 | 3 |
| Vladimir at the beacon | 8 | Vladimir Horngaard, 3 Revenants, Phantom Warrior, 2 Wights | Vladimir Horngaard (340 HP), 3 Revenants (220 HP), Phantom Warrior, Wight | 3/8 | 3 |
| Vladimir's duel | 8 | Vladimir Horngaard, 3 Revenants, Revenant (80 HP) | Vladimir Horngaard (290 HP), 3 Revenants (190 HP), Revenant (80 HP) | 3/8 | 3 |
| Kiril's challenge, guards cleared | 8 | Kiril Stoyanovich, 4 Werewolfs, 3 Dire Wolfs, 3 Wolfs | Kiril Stoyanovich (175 HP), 4 Werewolfs (140 HP), 4 Dire Wolfs, 3 Wolfs | 3/8 | 3 |
| Kiril's challenge, Zuleika vouched | 8 | Kiril Stoyanovich, 5 Werewolfs, 5 Dire Wolfs | Kiril Stoyanovich (145 HP), 5 Werewolfs (110 HP), 5 Dire Wolfs | 3/8 | 3 |
| The den's reckoning | 8 | Kiril Stoyanovich, Emil Toranescu (45 HP), Werewolf (60 HP), 3 Werewolfs, 2 Dire Wolfs, Wolf | Kiril Stoyanovich (185 HP), Emil Toranescu (45 HP), Werewolf (125 HP), 3 Werewolfs (150 HP), 2 Dire Wolfs, Wolf | 3/8 | 3 |
| Lysaga and her hut | 9 | Baba Lysaga's Creeping Hut (110 HP), Baba Lysaga (100 HP) | Baba Lysaga's Creeping Hut (160 HP), Baba Lysaga (145 HP) | 3/8 | 3 |
| The masterless hut | 9 | Baba Lysaga's Creeping Hut (195 HP), 3 Swarm of Insects | Baba Lysaga's Creeping Hut (520 HP), 3 Swarm of Insects | 3/8 | 3 |
| Rahadin on the stair (Gertruda) | 10 | Rahadin (300 HP), 2 Strahd's Animated Armors, Strahd's Animated Armor (50 HP) | Rahadin (795 HP), 3 Strahd's Animated Armors, Strahd's Animated Armor (50 HP) | 3/8 | 3 |
| Rahadin in the hall | 10 | Rahadin, 2 Strahd's Animated Armors, Strahd's Animated Armor (90 HP) | Rahadin (600 HP), 3 Strahd's Animated Armors (120 HP) | 2/8 | 2 |
| Rahadin in his chamber | 10 | Rahadin, 3 Strahd's Animated Armors | Rahadin (615 HP), 3 Strahd's Animated Armors (120 HP) | 3/8 | 3 |
| Two brides | 10 | 4 Vampire Spawns, 2 Strahd's Animated Armors | Ludmilla and Volenta, each a Vampire (195 HP), not bosses (2026-10-27) | not run | - |
| All three brides | 10 | 3 Vampire Spawns, 2 Strahd's Animated Armors | Ludmilla, Volenta and Anastrasya, each a Vampire (195 HP), not bosses (2026-10-27) | not run | - |
| Vladimir at Strahd's tomb | 10 | Vladimir Horngaard, 4 Revenants, Revenant (80 HP) | Vladimir Horngaard (275 HP), 4 Revenants (180 HP), Revenant (80 HP) | 3/8 | 3 |
| Old Greytooth | 6 | Old Greytooth (195 HP), 2 Dire Wolfs, 3 Wolfs, Bandit Captain | Old Greytooth (435 HP), 2 Dire Wolfs, 3 Wolfs, Bandit Captain | 3/8 | 3 |
| Old Greytooth, Szoldar turned | 6 | Old Greytooth (240 HP), 2 Dire Wolfs, 3 Wolfs, Werewolf | Old Greytooth (420 HP), 2 Dire Wolfs, 3 Wolfs, Werewolf | 2/8 | 2 |
| Bone marshal, the column (L6) | 6 | The Bone Marshal (170 HP), 2 Wights, 6 Skeletons | The Bone Marshal (200 HP), 2 Wights, 4 Skeletons | 3/8 | 3 |
| Bone marshal, riders stood down (L8) | 8 | The Bone Marshal (190 HP), 3 Wights | The Bone Marshal (380 HP), 3 Wights | 3/8 | 3 |
| Bone marshal, the column (L8) | 8 | The Bone Marshal (270 HP), 3 Wights, 6 Skeletons, 2 Phantom Warriors | The Bone Marshal (150 HP), 3 Wights, 6 Skeletons, 2 Phantom Warriors | 3/8 | 3 |
| The Rag Queen | 9 | The Rag Queen (375 HP), 2 Banshees, 4 Scarecrows | The Rag Queen (715 HP), 2 Banshees, 4 Scarecrows | 3/8 | 3 |
| Vine Mother L6 with Adrian | 6 | The Vine Mother (200 HP), 3 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 3 Vine Blights, 5 Needle Blights | 4/8 | 4 |
| Vine Mother L6 | 6 | The Vine Mother (200 HP), 3 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 3 Vine Blights, 5 Needle Blights | 3/8 | 3 |
| Granny Ash | 6 | Granny Ash (145 HP), 3 Dire Wolfs, 4 Needle Blights | Granny Ash (360 HP), 3 Dire Wolfs, 4 Needle Blights | 3/8 | 3 |
| The Count's Huntsman L8 | 8 | The Count's Huntsman (240 HP), Nightmare, 6 Dire Wolfs | The Count's Huntsman (430 HP), Nightmare, 6 Dire Wolfs | 3/8 | 3 |
| Huntsman L8, hounds called (reward) | 8 | The Count's Huntsman (240 HP), Nightmare, 3 Dire Wolfs | The Count's Huntsman (400 HP), Nightmare, 3 Dire Wolfs | 4/8 | 4 |
| The Count's Huntsman L9 | 9 | The Count's Huntsman (290 HP), Nightmare, 6 Dire Wolfs | The Count's Huntsman (520 HP), 5 Nightmares, 5 Dire Wolfs | 3/8 | 3 |
| The Count's Huntsman L10 | 10 | The Count's Huntsman (390 HP), Nightmare, 8 Dire Wolfs | The Count's Huntsman (380 HP), 7 Nightmares, 8 Dire Wolfs | 3/8 | 3 |
| The Penitent L10 | 10 | The Penitent (480 HP), 5 Ghasts | The Penitent (625 HP), 5 Ghasts | 3/8 | 3 |
| The Penitent L9 | 9 | The Penitent (420 HP), 4 Ghasts | The Penitent (645 HP), 4 Ghasts | 3/8 | 3 |
| The Penitent L11 | 11 | The Penitent (590 HP), 10 Ghasts | The Penitent (920 HP), 10 Ghasts | 3/8 | 3 |
| The Tinker's Wagon L5 | 5 | The Tinker's Wagon (220 HP), Mimic | The Tinker's Wagon (220 HP), Mimic | 3/8 | 3 |
| The Tinker's Wagon L6 | 6 | The Tinker's Wagon (160 HP), 5 Mimics | The Tinker's Wagon (450 HP), 5 Mimics | 2/8 | 2 |
| The Grandsire L8 | 8 | The Grandsire (165 HP), 2 Werewolfs, 2 Dire Wolfs | The Grandsire (330 HP), 2 Werewolfs, 2 Dire Wolfs | 3/8 | 3 |
| The Grandsire L9 | 9 | The Grandsire (150 HP), 3 Werewolfs, 2 Dire Wolfs | The Grandsire (310 HP), 3 Werewolfs, 2 Dire Wolfs | 3/8 | 3 |
| Corvina | 10 | Corvina, the Doorkeeper, 4 Helmed Horrors | Corvina, the Doorkeeper (360 HP), 10 Helmed Horrors | 3/8 | 3 |
| Corvina, named (reward) | 10 | Corvina, the Doorkeeper (105 HP), 4 Helmed Horrors | Corvina, the Doorkeeper (305 HP), 8 Helmed Horrors | 4/8 | 4 |
| Sarkhaza as she is (an ancient red, 2026-10-18) | 11 | Sarkhaza (200 HP, the old adult red), 2 Wights | Sarkhaza (507 HP), chained, in her lair | 0/8 | 0 |
| Sarkhaza unchained, salted, the sluice open | 11 | Sarkhaza (212 HP) | Sarkhaza (507 HP), grave-salted, off her chain, no lair | 0/8 | 0 |
| Khazan, his name standing | 10 | Khazan (210 HP), 2 Specters | Khazan (the CR 23 block, 315 HP), 2 Wraiths | 0/8 | 0 (kept as written) |
| Khazan unmade (reward) | 10 | Khazan (125 HP), 4 Specters, Wraith | Khazan (the CR 23 block, 315 HP), 5 Wraiths | 0/8 | 0 (kept as written) |
| The Eye Below | 10 | The Eye Below (135 HP), Dream-Gazer | The Eye Below (335 HP), Dream-Gazer | 3/8 | 3 |
| The Eye, both wardens' ways (reward) | 10 | The Eye Below (100 HP) | The Eye Below (335 HP) | 4/8 | 4 |
| Ash Effigy and Zorica L7 | 7 | The Ash Effigy (155 HP), Druid, 5 Twig Blights | The Ash Effigy (355 HP), Druid, 5 Twig Blights | 3/8 | 3 |
| Ash Effigy L8, Kostin doubting (reward) | 8 | The Ash Effigy (190 HP), 4 Twig Blights | The Ash Effigy (430 HP), 4 Twig Blights | 4/8 | 4 |
| Ash Effigy L8 with a druid | 8 | The Ash Effigy (205 HP), Druid, 4 Twig Blights | The Ash Effigy (480 HP), Druid, 4 Twig Blights | 3/8 | 3 |
| The Lantern Girl | 5 | The Lantern Girl, 4 Will-o'-Wisps | The Lantern Girl (90 HP), 8 Will-o'-Wisps | 3/8 | 3 |
| The Count's Likeness | 9 | The Count's Likeness (245 HP), 7 Guardian Portraits (40 HP) | The Count's Likeness (495 HP), 7 Guardian Portraits (40 HP) | 3/8 | 3 |
| Querreth | 10 | Querreth (335 HP), 2 Wraiths | Querreth (520 HP), 2 Wraiths | 3/8 | 3 |
| Querreth, forewarned (reward) | 10 | Querreth (280 HP), 2 Wraiths | Querreth (570 HP), 2 Wraiths | 4/8 | 4 |
| The Gilded Knight | 9 | The Gilded Knight (410 HP), 3 Animated Armors | The Gilded Knight (710 HP), 12 Animated Armors | 3/8 | 3 |
| The Forgotten Storm | 8 | The Forgotten Storm (240 HP), Air Elemental (60 HP) | The Forgotten Storm (430 HP), Air Elemental (60 HP) | 3/8 | 3 |
| The Amber guide | 10 | The Guide (155 HP), 2 Wraiths, 2 Shadows | The Guide (155 HP), 5 Wraiths, 2 Shadows | 3/8 | 3 |
| The Index | 9 | The Index (185 HP), 2 Mimics | The Index (390 HP), 2 Mimics | 3/8 | 3 |
| Grandfather Stone | 10 | Grandfather Stone (220 HP) | Grandfather Stone (395 HP) | 3/8 | 3 |
| Summit L5 | 5 | Tree Blight (84 HP), Druid (50 HP), 4 Twig Blights | Tree Blight (155 HP), Druid (50 HP), 4 Twig Blights | 3/8 | 3 |
| Summit L5, druids fled (reward) | 5 | Tree Blight (90 HP), 6 Twig Blights | Tree Blight (135 HP), 6 Twig Blights | 4/8 | 4 |
| Summit L5, struck first (reward) | 5 | Tree Blight (90 HP), Druid (45 HP), Druid, 4 Twig Blights | Tree Blight (180 HP), Druid (45 HP), Druid, 4 Twig Blights | 4/8 | 4 |
| Summit L5, Kostin warned them (harder) | 5 | Tree Blight (65 HP), Druid (50 HP), Druid (30 HP), 4 Twig Blights | Tree Blight (120 HP), Druid (90 HP), Druid (30 HP), 4 Twig Blights | 2/8 | 2 |
| Summit L6 | 6 | Tree Blight (158 HP), Druid (60 HP), 6 Twig Blights | Tree Blight (200 HP), Druid (60 HP), 6 Twig Blights | 4/8 | 4 |
| Summit L6, druids fled (reward) | 6 | Tree Blight (135 HP), 6 Twig Blights, 2 Vine Blights, 3 Needle Blights | Tree Blight (200 HP), 6 Twig Blights, 2 Vine Blights, 3 Needle Blights | 4/8 | 4 |
| Summit L6, struck first (reward) | 6 | Tree Blight (136 HP), Druid (58 HP), 2 Druids, 4 Twig Blights | Tree Blight (285 HP), Druid (58 HP), 2 Druids, 4 Twig Blights | 4/8 | 4 |
| Summit L6, Kostin warned them (harder) | 6 | Tree Blight (95 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | Tree Blight (210 HP), Druid (130 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | 2/8 | 2 |
| Summit L7 | 7 | Tree Blight (165 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | Tree Blight (300 HP), Druid (55 HP), 4 Twig Blights | 3/8 | 3 |
| Summit L7, druids fled (reward) | 7 | Tree Blight (125 HP), 6 Twig Blights, 3 Vine Blights, 3 Needle Blights | Tree Blight (200 HP), 6 Twig Blights, 3 Vine Blights, 3 Needle Blights | 4/8 | 4 |
| Summit L7, struck first (reward) | 7 | Tree Blight (125 HP), Druid (55 HP), 2 Druids, Berserker, 4 Twig Blights | Tree Blight (285 HP), Druid (55 HP), 2 Druids, Berserker, 4 Twig Blights | 4/8 | 4 |
| Summit L7, Kostin warned them (harder) | 7 | Tree Blight (110 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | Tree Blight (220 HP), Druid (60 HP), Druid (44 HP), 2 Druids, 4 Twig Blights | 2/8 | 2 |
| Vine Mother L5 | 5 | The Vine Mother (101 HP), Vine Blight, 3 Needle Blights | The Vine Mother (180 HP), Vine Blight, 3 Needle Blights | 3/8 | 3 |
| Vine Mother L7 | 7 | The Vine Mother (136 HP), 4 Vine Blights, 5 Needle Blights | The Vine Mother (340 HP), 4 Vine Blights, 5 Needle Blights | 3/8 | 3 |
| Vine Mother L8 | 8 | The Vine Mother (200 HP), 5 Vine Blights, 6 Needle Blights, Tree Blight | The Vine Mother (290 HP), 5 Vine Blights, 6 Needle Blights, Tree Blight | 3/8 | 3 |
| Offalia in the bakery | 6 | Night Hag (300 HP), 5 Nightmares | Night Hag (285 HP), 5 Nightmares | 3/8 | 3 |
| Bella betrayed | 6 | Night Hag (250 HP), 3 Nightmares, 3 Dire Wolfs | Night Hag (300 HP), 6 Nightmares, 2 Dire Wolfs | 3/8 | 3 |
| Bella on the road | 6 | Night Hag (300 HP), 3 Nightmares | Night Hag (610 HP), 5 Nightmares | 2/8 | 2 |
| Offalia on the road | 6 | Night Hag (300 HP), 4 Nightmares | Night Hag (300 HP), 6 Nightmares | 3/8 | 3 |
| Morgantha alone | 6 | Night Hag (300 HP), 3 Swarm of Rats, 4 Nightmares | Night Hag (300 HP), 3 Swarm of Rats, 6 Nightmares | 3/8 | 3 |
| Lysaga at Marina's grave | 9 | Baba Lysaga (180 HP), 2 Swarm of Insects, 4 Scarecrows | Baba Lysaga (460 HP), 2 Swarm of Insects, 10 Scarecrows | 3/8 | 3 |
| Lysaga in her kitchen | 9 | Baba Lysaga (400 HP), 8 Swarm of Insects, 4 Scarecrows | Baba Lysaga (510 HP), 8 Swarm of Insects, 12 Scarecrows | 3/8 | 3 |
| The roc and its mate | 9 | Roc (190 HP), Roc (85 HP) | Roc (285 HP), Roc (85 HP) | 3/8 | 3 |
| Exethanter | 10 | Exethanter, 6 Flameskulls | Exethanter (130 HP), 6 Flameskulls, 8 Wraiths (85 HP) | 3/8 | 3 |
| Vosk unmasked | 10 | Arcanaloth (135 HP), 2 Flameskulls | Arcanaloth (320 HP), 2 Flameskulls | 3/8 | 3 |
| Vosk named and weakened (reward) | 10 | Arcanaloth (80 HP) | Arcanaloth (330 HP), 2 Flameskulls | 4/8 | 4 |
| Sarkhaza, the keepers' three tricks | 11 | Sarkhaza (165 HP), 6 Wights | Sarkhaza (507 HP), chained, grave-salted, surprised, no lair | 0/8 | 0 (not retuned) |
| Strahd woken by day (Sunsword) | 10 | Strahd von Zarovich (350 HP), 2 Swarm of Bats, Vampire Spawn | Strahd von Zarovich (270 HP), 2 Swarm of Bats, 7 Vampire Spawns | 3/8 | 3 |
| Strahd's dinner (Sunsword) | 10 | Strahd von Zarovich (375 HP), 3 Swarm of Bats, 2 Strahd's Animated Armors | Strahd von Zarovich (605 HP), 3 Swarm of Bats, 2 Strahd's Animated Armors, 3 Vampire Spawns | 3/8 | 3 |
| Strahd at the broken heart (Sunsword) | 10 | Strahd von Zarovich (350 HP), 2 Strahd's Animated Armors | Strahd von Zarovich (455 HP), 2 Strahd's Animated Armors, 5 Vampire Spawns | 3/8 | 3 |
| Final: the horseman's crypt | 10 | Strahd von Zarovich (375 HP), Nightmare, 2 Swarm of Bats, 2 Vampire Spawns | Strahd von Zarovich (355 HP), Nightmare, 2 Swarm of Bats, 5 Vampire Spawns | 3/8 | 3 |
| Final: his tomb | 10 | Strahd von Zarovich (350 HP), 2 Vampire Spawns | Strahd von Zarovich (410 HP), 5 Vampire Spawns | 3/8 | 3 |
| Final: the royal tomb | 10 | Strahd von Zarovich (400 HP), 3 Specters, 2 Vampire Spawns | Strahd von Zarovich (345 HP), 3 Specters, 8 Vampire Spawns | 3/8 | 3 |
| Final: Sergei's tomb | 10 | Strahd von Zarovich (350 HP), 3 Dire Wolfs, 2 Swarm of Bats, 3 Vampire Spawns | Strahd von Zarovich (455 HP), 3 Dire Wolfs, 2 Swarm of Bats, 7 Vampire Spawns | 3/8 | 3 |
| Final: the chapel | 10 | Strahd von Zarovich (350 HP), 6 Vampire Spawns | Strahd von Zarovich (455 HP), 10 Vampire Spawns | 3/8 | 3 |
| Final: the audience hall | 10 | Strahd von Zarovich (350 HP), 3 Dire Wolfs, 4 Vampire Spawns | Strahd von Zarovich (310 HP), 3 Dire Wolfs, 10 Vampire Spawns | 3/8 | 3 |
| Final: his study | 10 | Strahd von Zarovich (350 HP), 2 Swarm of Bats, 5 Vampire Spawns | Strahd von Zarovich (605 HP), 2 Swarm of Bats, 6 Vampire Spawns | 3/8 | 3 |
| Final: the treasury | 10 | Strahd von Zarovich (400 HP), Helmed Horror, 3 Vampire Spawns | Strahd von Zarovich (660 HP), Helmed Horror, 9 Vampire Spawns | 3/8 | 3 |
| Final: the donjon | 10 | Strahd von Zarovich (350 HP), 10 Skeletons, 4 Vampire Spawns | Strahd von Zarovich (500 HP), 10 Skeletons, 10 Vampire Spawns | 3/8 | 3 |
| Final: the overlook | 10 | Strahd von Zarovich (350 HP), 3 Swarm of Bats, Vampire Spawn | Strahd von Zarovich (765 HP), 3 Swarm of Bats, 4 Vampire Spawns | 3/8 | 3 |
| Final: the Heart of Sorrow | 10 | Strahd von Zarovich (350 HP), Helmed Horror, 2 Vampire Spawns | Strahd von Zarovich (590 HP), Helmed Horror, 8 Vampire Spawns | 3/8 | 3 |
| Strahd's test of strength L7 | 7 | Strahd von Zarovich, 2 Dire Wolfs | Strahd von Zarovich (355 HP), 2 Dire Wolfs | 3/8 | 3 |
| Strahd at the Blue Water Inn window L5 | 5 | Strahd von Zarovich (110 HP), Swarm of Bats | Strahd von Zarovich (170 HP), Swarm of Bats | 3/8 | 3 |
| Strahd at the Krezkovs' window L7 | 7 | Strahd von Zarovich (200 HP), Swarm of Bats | Strahd von Zarovich (360 HP), Swarm of Bats | 3/8 | 3 |
| Summit L5, circle broken (reward) | 5 | Tree Blight (74 HP), Druid (50 HP), 4 Twig Blights | Tree Blight (135 HP), Druid (90 HP), 4 Twig Blights | 4/8 | 4 |
| Summit L6, circle broken (reward) | 6 | Tree Blight (140 HP), Druid (60 HP), 6 Twig Blights | Tree Blight (215 HP), Druid (60 HP), 6 Twig Blights | 4/8 | 4 |
| Summit L7, circle broken (reward) | 7 | Tree Blight (100 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | Tree Blight (250 HP), Druid (55 HP), Berserker (40 HP), 4 Twig Blights | 4/8 | 4 |
| The Amber Temple's sentinel wakes | 10 | Amber Golem, 2 Gargoyles | Amber Golem (395 HP), 2 Gargoyles, 3 Wraiths | 3/8 | 3 |
| The sentinel stops a party with a dark gift | 10 | Amber Golem | Amber Golem (375 HP), 6 Wraiths | 3/8 | 3 |
| The vault guardian | 10 | Amber Golem, Wraith | Amber Golem (460 HP), 4 Wraiths | 3/8 | 3 |
| Offalia in her oven (open:hag_oven) | 6 | Night Hag (80 HP) | Night Hag (200 HP), 6 Nightmares | 3/8 | 3 |
| Rahadin at the failed footlocker | 10 | Rahadin | Rahadin (580 HP), 3 Strahd's Animated Armors (120 HP) | 3/8 | 3 |
| The iron knight (brazier room, from the brazier / from the alcove) | 10 | Iron Golem x2 (252 HP each, 2025 block): 1 to 2 wins in 8 at any Hit Points, so one wakes | Iron Golem (300 HP), the other knight empty armour | 3/8 / 3/8 | 3 |

## Where a fight is not at 3 in 8, and why

- **The festival loyalists and Izek's rampage** keep their old line-ups (6 in 8 for the full-ability test party; the tests' band is 5-7). The Phase 4
  playthrough party (Ilse, Tamsin, Hedda, Silvain) wins the loyalists 2 times in 8 and the rampage 4 times in 8 as they are, and any harder step won
  them 0 or 1 (one sergeant more in the rampage: 1 in 8), so a 3-in-8 line-up would strand the story walk-through there. Izek's duel and Izek in his
  room are at 3.
- **Strahd's final rooms** each hold two line-ups. The first, measured above, applies when the party carries the Sunsword (`item:sunsword`); the
  second, the old 5-in-8 line-up, is for the Phase 6 coffin playthrough, whose party reaches the chapel without it and cannot win the retuned room.
  Strahd's visits keep their flee-at-0-HP behaviour.
- **The harder side (2 in 8)**: Morgantha and Offalia, the two brides, all three brides, the Tinker's Wagon at level 6, Old Greytooth with Szoldar turned,
  Bella on the road. No Hit Point step or helper added landed on 3 for these; the 2 is the step below 3.
- **Khazan is the CR 23 block the owner chose** (2026-10-21, an Acerak block renamed) and kept as written on 2026-10-26: "a fight the party
  should run from". His first turn's Meteor Swarm (about 180 damage to each hero after the boss damage) kills a level 10 party in round 1, so his
  two fights expect no wins (tests: winless_ok, at most 2 in 8). His study was made deeper the same day (15 by 14 squares, was 15 by 6), his
  chair at the far end from the door.
- **Sarkhaza is the 2025 Monster Manual's ancient red dragon** (owner, 2026-10-18; CR 24, 507 HP, AC 22), fought at level 11, the game's cap. Her
  first Fire Breath (DC 24, 26d6 in a 90-ft cone) takes a level 11 party: 0 in 8 in every version (tests: at most 1 in 8). On 2026-10-18 the
  keepers' three tricks reached 3 in 8 while the hauled-in collar choked her breath and spells for a minute; on 2026-10-19 the owner had the choke
  taken out ("just get rid of the chain choking her altogether") and, by his rule, nothing retuned for a rule change, so the tricks no longer win
  it: grave-salted (slowed, one Rend, one legendary action a round), caught unready on the hauled-in chain, and the vents drowned (no lair).
- **The Eye Below** keeps the fiction of its tricks. The Eye with both wardens' ways taken needs the same 335 HP as the plain Eye (without
  its dreamed eye and its lair, and surprised), so test_side_quests_beholder now asks that it is no tougher than the plain Eye, not under 180 HP.
- **Summit L6 (Wintersplinter, default)** is held at 4 in 8 for the pregens (200 HP), the top of the 2-4 band: the weaker Phase 5 playthrough party needs a clean win within eight tries and wins 6 in 8 against 200 HP (5 against 240, 3 with 2 clean against 270; the Wizard of Wines playthrough passes on probe seeds 2, 4, 5, 6 and 7 at 200).
- **The Phase 5 playthrough** (test_phase5_exit, the Wizard of Wines) walked home from the retuned Yester Hill summit hurt and at night into a road fight it could not
  win. Its careful-player bot (`StoryBot.waits_for_long_rest`) now heals with its spells where no rest is allowed and waits for daylight before a road. Random road
  fights (data/random_encounters/, tuned for the pregens) can still beat the weaker playthrough party on other dice seeds; that is the road tables', not a boss's.
- **Rewards** a quest earns (hounds called, Corvina named, Vosk named, the summit circle broken, the Vine Mother with Adrian along, ...) are one step
  easier (4); Kostin's warning at the summit is one step harder (2).
- **Hit Points far above the book** (two to four times) are how most bosses reach 3: the full-ability party out-damages the book numbers by a lot. Where a
  boss would need more than that, helpers stand beside it instead. Encounter `text` (the voiced narrator line) still names the old counts of spawn.
- **Fight starts (2026-10-15)**: every boss fight starts spread out: no 20 ft burst catches every foe, nor more than three quarters of eight or more
  (tests/unit/test_fight_spread.gd, its PENDING list now empty). The foes were moved the fewest squares that did it; the fights were then re-measured and retuned back to their targets.
- **Boss damage (2026-10-19)**: bosses (`Difficulty.boss_entry`: narrative/combat/bosses.json and legendary-action foes) deal 25% more damage on Balanced and harder
  (`Difficulty.boss_damage`, docs/plans/difficulty.md). The line-ups and wins above were measured before it and were not re-measured (owner: the 3 in 8 tuning was a
  one-time job); a series that now leaves its band is reported by the full ci, and its expectation follows the measured value.
- **Boss to-hit and DCs (2026-10-25)**: on Balanced the same bosses also add to their attack rolls, spell attacks and the DCs of their spells and
  actions by the party's level (`Difficulty.boss_bonus`, the lowest hero's level): +1 to level 4, +2 at 5-8, +3 from 9. Tactician and Honour
  already give every foe +2. Brother Anatol's hunger (+1) comes on top. Not re-measured either.
- **Versions that never ran (2026-10-15)**: Strahd's heart-of-sorrow, horseman, darklord, Sergei and royal-tomb finals had both versions on the same condition, so the
  big one always ran; `item:sunsword` is now on the big one, like the other six finals. Two encounters have versions with different triggers (the oven Offalia, `open:hag_oven`;
  Rahadin at the failed footlocker, `check:rahadin_footlocker:failure`) and a trigger started the first version of that id whose condition held, so they never ran:
  `LocationFights.start_encounter` now takes the version the trigger matched. Both are boss fights now measured and held at 3 in 8.

