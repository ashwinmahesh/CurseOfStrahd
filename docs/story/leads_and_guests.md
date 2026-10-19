# NPCs that lead you, and guests you can talk to

Owner's todos (2026-10-17): "When interacting with certain NPCs, if the NPC is supposed to take the characters somewhere,
the gameplay should represent that. Have the player sprites follow the NPC sprites to that location. If it's in a
different map area, give a confirmation to follow now or come back later." And: "Pidlwick is in my party, and I now have
the key. How do I give it to him? We should make NPCs interactable if they're with the party."

## The lead step (`lead <npc> to <where>`)

One dialogue statement (docs/contracts/dialogue.md). The conversation hides, the NPC's figure walks to the spot, and the
party's figures follow in marching order two squares behind (`LocationLead`, `world/exploration/location_lead.gd`), at
the same smooth pace as the rest of exploring. Nothing is set off on the way (traps, areas, watchers); a click, Enter,
Space, Esc or the pad's A skips the walk and puts everyone where it was going. The conversation then carries on where
the party stands, with the NPC beside them.

- **This map** (a door, prop, container, exit or area id, or `x,y`): no prompt. After the conversation the person keeps
  the square they walked to for as long as the party stays (the rebuild keeps people where they stand); the data's
  `when` entries decide where they stand on the next visit.
- **Another place** (a location id, `location_id` or `location_id:spawn`): `LeadPrompt` asks "Follow now" or "Come back
  later". Following walks to this map's way out (if it has one to there), changes place (5 minutes pass) and brings the
  NPC beside the party for the rest of the conversation. Coming back later leaves everything where it was and sets
  `check.last` false, so the conversation goes on without the walk and the NPC can be asked again.
- Fights: a walk stops if a fight starts. A lead into a place that fights on arrival needs the story's flags set first.
- Arriving: the NPC stands beside the party for the rest of the conversation, unless the place already has them standing
  (Zuleika at her shrine), and steps out when it ends, like anyone `appear` brought. A lead that is the conversation's last
  line therefore ends it on arrival (Parriwimple, up in the hollow).
- Bots and tools that play conversations without a screen (`DialogueRunner.offer_leads` off) count every lead as followed.

### Who leads (found 2026-10-17 by reading every dialogue and quest hint)

| NPC | Where they say it | Leads to |
|---|---|---|
| Adrian Martikov | `wizard_of_wines/adrian:to_father` ("This way, round by the trees") | his father's camp, this map (10,27) |
| Lupu | `village_of_barovia/the_burgomasters_hound:follow` (quest hint: "follow him") | the mansion's side wall under the study window, this map (12,3) |
| Parriwimple | `village_of_barovia/the_oat_thief:path_told` ("Come up. Up the path, past the last house") | the Charcoal-Burners' Hollow |
| Zuleika | `werewolf_den/zuleika:pact` ("Walk behind me") | her shrine in the den's caves (spawn `shrine`; the pact's flags are set first, so the guards at the mouth stand aside) |
| Bluto | `lake_zarovich/landing:to_vistani` (he "walks ahead of you along the shore") | the Vistani camp outside Vallaki |

Left as they are, on purpose: Escher (he goes ahead alone and waits, and the roof is at night before dawn), Davian ("come
and do the same", an invitation to act), Vosk (goes ahead alone, and it is a trap), Ismark (only says he will go ahead),
Baba Lysaga and Morgantha (invitations), Anna Krezkova ("come and see him", she sits at the bed already), Mad Mary (the
quest hint says she shows Gertruda's room; the conversation never walks anywhere), Ilarion (the party leads him).

## Guests (story allies travelling with the party)

A guest is a figure in the world and a card on the HUD and the Party screen, and all three answer to the same three
things (`GuestTalk`, `LocationGuests`; the game root's `talk_to_guest`, `give_to_guest`, `guest_menu`):

- **Talk**: the guest's `guest_talk` conversation (data/npcs), else one of their road lines (narrative/banter/guest_<id>),
  else a word that they have nothing more to say.
- **Give...**: `GiftPicker` lists what the party can hand them now, from the npc's `gifts` (each with a story condition
  `when`, the `item` that names and pictures it, and the conversation `ref` that hands it over). Potions and healing
  still go from the Inventory (`FieldItems.give_potion`).
- **Send home**: as on the Party screen.

In the world: hover reads "Talk to Pidlwick II", a click walks up and talks, a right-click opens the menu (Talk, Give...,
Send home, Look), the pad marks guests like anyone else. On the HUD: click the guest's card. On the Party screen: Talk and
Give... beside Send home.

### Allies the cards can name, who cannot be sent home (Ashwin, 2026-10-19)

Madam Eva's ally stays for good (`StoryState.guest_stays`), so whatever the story asks of them in conversation has to be
reachable on the road. The Mage's Lost Pages was the gap that showed it: Mordenkainen joined as the cards' ally with the
three letters in the pack, his hut was empty, and nothing handed them over. Now Mordenkainen (`mordenkainen:companion`, the
gift "The three lost letters", and a hand-over the moment he joins already holding them), Sir Godfrey Gwilym
(`godfrey:companion`: Godrick's knighting) and Rictavio (`rictavio:companion`: Silvain's Aurel Mirescu question and his wares)
have a `guest_talk`, with an exit each; Davian's news goes through Stefania (`stefania:news`). The rest of the cards'
allies (Emil, Victor, Ismark, Kolyan, Parriwimple, Arabelle) hold only banter or business done before they travel.
tests/integration/test_mage_pages_orders.gd lists every ally on a card and fails when a new one has no note.

### Pidlwick and his key

The brass key is now a quest item (`pidlwicks_key`, given by the roost's nest, taken when handed over). With Pidlwick II
in the party: click him (his `companion` conversation offers "We found your key"), or Give... > "The brass wind-up key"
(starts `castle_ravenloft/spires_pidlwick:key_back` directly). A save made after finding the key but before this change has
the flag but not the item: the gift is offered from the flag, so it still works.
