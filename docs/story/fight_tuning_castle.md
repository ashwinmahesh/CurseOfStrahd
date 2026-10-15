# Castle Ravenloft's rooms and watches, and one road after Yester Hill

(Owner, 2026-10-13: the book's fights were written for weaker characters. Over seeds 1-8 the four pregens on the sharp
autopilot win five in eight on Balanced, give or take one, each fight played from where walking in or touching something
sets it off, its foes starting spread out. The bosses are the boss lane's, in `docs/story/boss_fights.md`.)

## The road home from Yester Hill

`vineyard_road:hedgerow_blights` now also needs `not flag.yester_hill_resolved` (2026-10-15). Both Yester Hill locations
allow no rest, so a party that has just won the summit walks home with its healers' slots spent on Cure Wounds and the
rest of its slots gone; the same four playthrough heroes who win that fight eight times in eight rested lost all eight
tries in `test_phase5_exit` at seed 11. Until the tree burns, the blights still ambush the road on the way up; the first
ambush after the hill is broken is skipped. (The `druids_return` revenge table still fires after a spared hill; see the
hand-off note.)
