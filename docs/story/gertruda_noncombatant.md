# Gertruda keeps out of fights (Resume packages, Allies item 2)

Owner's ask (2026-10-24): "Gertruda should be a non-combatant when she's with the party." She travels with the party as a guest
from the castle's yellow guest room to her mother's house in the village of Barovia (`find_gertruda`, `data/npcs/gertruda.json`).
Until now she fought as a commoner with 4 Hit Points, which a fight would have ended in a round.

The rule is the one built for Ireena (allies plan E3; `docs/contracts/campaign.md`, `docs/rules/deviations.md`): her NPC says
`guest_fights: false`, so she is never in the encounter. She takes no turn, nobody can target her or catch her in an area, she
can't fall, and her figure stays on the board as a bystander who steps aside if the fight starts on a square someone will
stand on. Her party card says "Keeps back". Nothing else about her changes: `guest_stays` still keeps her with the party until her
mother has her, and her own lines (`narrative/banter/guest_gertruda.dialogue`) already had her stay very quiet in a fight.

## The Narrator

`narrative/narrator/keeps_back.dialogue` has her nodes beside Ireena's: `combat:keeps_back:gertruda:first` is said once, as the
first fight with her along begins, and `combat:keeps_back:gertruda` (nine lines, a cooldown of 20) now and then in the ones after.
Unlike Ireena's, they do not hint at why nothing turns on her: she only stands very still. Nine unvoiced lines for the voice thread
(speaker: the Narrator), drafted by Gemini through the bridge (`docs/plans/gemini_allies/gertruda/`).

## Tests

`tests/unit/test_gertruda_noncombatant.gd` is Ireena's test (`test_noncombatant_guest.gd`) for Gertruda: the rule, the card,
a fight without her, no area catching her, stepping aside, the Narrator's lines, a save; and a check of the lines' length.
