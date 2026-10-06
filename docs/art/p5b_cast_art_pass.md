# P5b cast art pass: the Phase 5 regions' named NPCs (planned, blocked by Gemini's daily quota)

Date: 2026-10-06 · Status: **no images made yet.** The first two calls (Ezmerelda's and Sir Godfrey's turnarounds)
came back `429 ... generate_requests_per_model_per_day, limit: 1000, model: gemini-3.1-flash-image`: the shared key's
daily request quota was already spent (art/generation_log.jsonl logs 766 images on 2026-10-06; refusals and errors also
count but aren't logged). Google resets per-day quotas at midnight Pacific time (03:00 EDT). Nothing was registered in
art/manifest.json or art/anim/animations.json, because nothing exists to register. The method is P5's
(docs/art/p5_cast_art_pass.md): 5-view turnaround → `make sprite` → manifest entry with `sprite_flags` → animations.json
entry → `make anims ONLY=<id> GENERATE=1`; base portrait from the turnaround (`--ref`), mood from the base portrait,
`make portrait ... BG=ash_violet`.

Done without Gemini: `tools/art/check_npc_art.py` now asks for a walk sheet only from NPCs that can stand on a map (they
name a `sprite`, a location's `npcs` places them, or they can join as a guest). The 16 `vestige_*` NPCs have none of
these, so they need only the shared `vestige_amber` portrait and print as "portrait only"; their data needs no change
(the schema doesn't require `sprite`, and their sarcophagi are `coffin` props).

## The plan: 38 sheets, 79 portraits, about 330 calls

Moods are the tag each one's dialogue uses most (counted over narrative/**/*.dialogue); "none" means no tags, so the
mood fits the voice bible. Heights are suggestions for `CombatToken.HEIGHTS` (world/, the lead's file).

| sheet id | portraits | look | flags | attack | height |
|---|---|---|---|---|---|
| ezmerelda | base, `angry` (4 vs 3 smile) | Vistani hunter: midnight-blue greatcoat, crimson waistcoat, silver stakes, rapier, hand crossbow, oak-and-steel brace below the right knee | | rapier lunge | 1.25 |
| sir_godfrey_gwilym | base, `sad` (6) | big grey revenant, bareheaded, dented silver-grey plate, faded royal-blue surcoat with the silver dragon | | longsword chop | 1.42 |
| vladimir_horngaard | base, `angry` (none) | gaunt grey revenant, black dragon-scale plate, silver dragon-winged open helm, tattered crimson cloak, greatsword | | greatsword chop | 1.4 |
| davian_martikov | base, `angry` (2) | white-bearded vintner, raven-black eyes, wine-stained plum coat, raven clasp, black feather mantle, vine stick | | shortsword slash | 1.24 |
| emil_toranescu | base, `angry` (2) | big grey-bearded werewolf in human form, yellow eyes, black silver-burn rings on both wrists, broken shackle, barefoot | | clawed swipe | 1.38 |
| mordenkainen | `mad_mage` + `mad_mage_sly` (1/1 tie), `mordenkainen` + `mordenkainen_angry` (none) | one sheet for both: gaunt old archwizard, tangled beard with twigs, ruined royal-purple robe with tarnished gold stars, black staff. Mad: wild-haired, lost; restored: beard combed, piercing | | lightning spell (`casts`) | 1.25 |
| baba_lysaga | base, `angry` (12) | tiny ancient witch, walnut face, black headscarf, blood-red shawl, bone necklace, bird-skull staff | | green curse (`casts`) | 0.95 |
| exethanter | base, `sad` (3) | tall stooped lich, parchment-grey skull face, frost-blue eye-lights, tea-tan robe pinned with notes, plum stole | | frost spell (`casts`) | 1.28 |
| vosk | base, `smile` (11) | slim bespectacled scholar: crimson high-collared robe, skullcap, quill, black ledger | | violet fire (`casts`) | 1.24 |
| abbot | base, `smile` (4) | serene golden-haired young monk: cream habit (not white), gold sunburst, crimson rope belt, stained surgeon's apron | | golden light (`casts`) | 1.3 |
| vasilka | base (wedding dress, the look she speaks in), `vasilka_shroud` (asleep in her shroud; not a mood) | stitched bride: lace-fine seams, odd eyes, auburn hair, veil, cream wedding dress with crimson folk embroidery | | two-fisted blow | 1.22 |
| kiril_stoyanovich | base, `smile` (8) | huge bare-chested werewolf in human form, wolf-pelt cloak with the head, teeth necklace, red waist cloth | | clawed rake | 1.45 |
| zuleika_toranescu | base, `angry` (1) | lean werewolf woman, patched walnut coat with rust and moss patches, plum headscarf, herbs and wolfsbane, herb knife | | knife slash | 1.25 |
| ilinca_vrana | base, `weary` (1/1/1 tie) | small old midwife, black feather-edged shawl, moonlit-blue dress, bone apron, satchel | | knife slash | 1.1 |
| bella_sunbane | base, `smile` (7) | lovely miller's daughter: honey-blonde, big red ribbon, deep blue bodice and skirt, floury hands | | clawing rake | 1.2 |
| offalia_wormwiggle | base, `smile` (6) | round rosy baker's wife: orange kerchief, mustard and orange striped dress, floury apron, tray of pastries | | tray smash | 1.15 |
| ruxandra | base, `smile` (none) | kindly old archdruid: moss-green sacking robe, grey braids with twigs and red berries, earth to the elbows, black staff | | green light (`casts`) | 1.1 |
| adrian_martikov | base, `sad` (2) | lean black-eyed vintner: cream shirt, black waistcoat, raven pin, crimson neckerchief, cooper's apron | | shortsword slash | 1.3 |
| stefania_martikov | base, `angry` (none) | sturdy practical woman: crimson kerchief, plum bodice, brown skirt, apron, ladle (no child on her hip: the rig can't carry one) | | shortsword slash | 1.2 |
| kostin | base, `angry` (2) | gaunt young druid: moss-green sacking robe, thorn-twig wreath, red berry necklace, quarterstaff | | staff swing | 1.25 |
| dmitri_krezkov | base, `angry` (5) | broad grey-bearded burgomaster: fur hat, sheepskin coat, blood-red tunic, iron chain of office, longsword | | longsword slash | 1.32 |
| anna_krezkova | base, `smile` (3) | small tired mother: deep red headscarf, moonlit-blue dress, embroidered apron, brown shawl, wooden sunburst | | candlestick swing | 1.1 |
| ilya_krezkov | base, `smile` (none) | skinny eight-year-old: flushed cheeks, too-big brown jacket over a nightshirt, red scarf | | stick swing | 0.8 |
| kasha_varo | base, `angry` (2) | tiny old widow in three shawls (blue, crimson, mustard), twig broom | | broom swat | 0.95 |
| krezk_guard | base, `afraid` (1) | lanky mountain farmer: tall black sheepskin hat, sheepskin coat, red shirt, spear | | spear thrust | 1.3 |
| clovin_belview | base, `sad` (2) | stooped mongrelfolk in a patched brown habit: hound's ear, goat eye, feathered left hand, a hoof, wineskin | | club swing | 1.1 |
| belview | base, `sly` (none) | hunched mongrelfolk in sacking: goat eyes, a ram's horn, a hound's ear, fur patches, stubby wing, bird's-foot hand | | claw swipe | 1.15 |
| mirela | base, `angry` (none) | fierce ten-year-old: split lip, two braids, a man's too-big brown coat, ragged red dress, bandaged arm | | thrown stone | 0.85 |
| ilka_sarnov | base, `sad` (2/2 tie with afraid) | thin ten-year-old: short choppy hair, ragged moonlit-blue dress, grey shawl | | splinter jab | 0.82 |
| toma_sarnov | base, `weary` (none: he sleeps) | sleepy six-year-old: light-brown mop, too-big mustard shirt, half-eaten pastry | | thrown pastry | 0.65 |
| order_knight | base, `weary` (none) | generic revenant knight: grey face, open helm, battered plate, ragged royal-blue surcoat | | longsword slash | 1.32 |
| phantom_warden | base, `angry` (none) | ghost man-at-arms, all frost-blue: kettle helm, mail, dragon-badge surcoat, kite shield, spear | | spear thrust | 1.3 |
| tsolenka_sergeant | base, `angry` (1) | ghost watch sergeant, all grey-blue: conical nasal helm, mail, tabard and sash, horn, halberd | | halberd chop | 1.3 |
| tsolenka_watchman | base, `weary` (none) | ghost watchman, all grey-blue: kettle helm, mail, plain tabard, round shield, spear | | spear thrust | 1.28 |
| patrina_velikovna | base, `angry` (5) | banshee dusk elf scholar, all frost-blue and lilac, drifting hair, stone scars, gown ending in a wisp | `BODY=float` | wailing touch | 1.25 |
| amber_sentinel | base, `angry` (none: the hood's glow flares) | Large hooded colossus of glowing amber, two golden eye-points, statue robe, pillar legs, black stone bands | | fist slam | 2.3 |
| argynvost_echo | `argynvost` + `argynvost_sad` (2) | ghost of a silver dragon: horned head, long neck and folded wings fading into a frost-mist wisp, all frost-blue and silver | `BODY=float` | frost breath | 1.7 |
| sergei_von_zarovich | base, `smile` (none) | spirit of Strahd's brother in old wedding clothes (doublet, sash, short cape), all moonlit-blue; portrait with faint water ripples | | sword cut | 1.3 |
| (vestiges) | `vestige_amber` | a face glimpsed in glowing amber; no reference image | portrait only | | |

Sergei is placed on no map today; he gets a sheet last because his data names one. Colour lessons from P4/P5 are in the
prompts: saturated purples and reds (not dusty), "clear moss green" (low-chroma greens snap to grey), cream rather than
white (the cutter removes white), ghosts "no warm colours, no pure white", revenant skin a flat grey (grey-lilac snaps
to lilac in portraits).

## Later (not this pass)

Combat forms, which are monster art: the night hags' true forms (Bella, Offalia and Morgantha), Vosk's jackal face
(arcanaloth; the region doc also asks for an unmasked portrait), the Abbot's deva form with wings of light, `flesh_golem`
drawn as Vasilka, the Martikovs' and Ilinca's raven forms, and werewolf hybrids for Kiril, Emil and Zuleika (there is no
`werewolf` sheet in art/sprites yet).
