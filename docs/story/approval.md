# Companion approval, romances and Heroic Inspiration for playing in character

Owner picks (2026-10-07, Improvement Ideas F3 and F15): "Each companion likes or dislikes your choices and says so;
approval opens or closes the best ending of their personal quest, extra camp scenes and romances" (romances: yes),
and "a companion who acts true to their background or nature earns Heroic Inspiration, as the 2024 rules let a DM
award it and Baldur's Gate 3 does".

## Approval (`story/approval.gd`)

Each of the six roster companions has a score from -100 to +100, starting at 0, saved in `StoryState.approval` with
the last eight moments they remember. Seven tiers:

| Tier | From | What it means |
|---|---|---|
| Devoted | 50 | Would follow you into the castle and back out again |
| Close | 25 | Trusts you with the things that matter most to them |
| Warm | 10 | Glad to be travelling with you |
| Neutral | -9 | Still making up their mind (everyone starts here) |
| Doubtful | -24 | Has doubts about the way you do things |
| Strained | -49 | Won't follow you into what matters most to them until it's mended |
| Estranged | -100 | Still walks with you, for now |

- **Who sees it.** Only companions travelling in the party see a choice and react. Those at camp don't, and a custom
  hero never has approval, even one who took a companion's name.
- **Saying so.** A change shows as a notice ("Godrick approves · Kip disapproves", "greatly" for 5 or more, and the
  new tier when one is crossed). The bigger moments also carry a spoken line.
- **Once each.** Every `approve` statement counts once a playthrough, however often its node runs.
- **Sizes used.** 1 a manner or small kindness; 2 to 3 a clear value choice; 4 to 6 a big moral choice or a moment in
  their own story; 8 to 10 the climax of their quest or a betrayal (the Death House sacrifice, leaving children
  caged, offering Ireena to Strahd).
- **The party screen** (`ui/screens/approval_panel.gd`): a card per companion in the company with their tier, a bar,
  any romance and the last three moments (the rest on hover); each party card wears the tier as a pill.

What each of them cares about, as tagged across the campaign:

- **Godrick:** protecting the weak, keeping his word, honesty, courtesy, the Order. Hates cruelty, abandoning people,
  oath-breaking and deals with fiends.
- **Liriel:** mercy, rest for the dead, faith, St. Andral's bones, the Abbot's redemption. Hates desecration, the Dark
  Gifts, cruelty and the wedding.
- **Thistle:** freeing anything caged, children and animals, saying it straight, burning what's rotten. Hates cages,
  cruelty to the small, bowing to tyrants and leaving the little ones behind.
- **Ratatoille:** cleverness and study, hospitality and food, being taken seriously. Hates waste, bullying cooks,
  Morgantha's pastries and being made to keep quiet.
- **Wren:** wit, mercy over vengeance, freeing people, the overlooked. Hates cold-blooded killing, bullying and
  hatred, which is the wrong lesson.
- **Kip:** fair dealing, paying what's owed, children and families, reading the small print. Hates fiendish bargains
  above everything (the Dark Gifts, Bella's pact, Vladimir's oath of hate), theft and cheating.

## What approval opens and closes

**Camp talks** (`narrative/camp/<who>.dialogue`): each file offers its first talk that holds, so they come in this
order. Strained (`talk_strained`) and Doubtful (`talk_doubt`): the companion says what's wrong, naming the worst thing
done where there is one; answering well mends it (up to +10), answering coldly makes it worse. Then the personal
quest's talks. Then Warm (`talk_warm`, level 3), Close (`talk_close`, level 5) and Devoted (`talk_devoted`, level 8).

**Personal quest endings** (`narrative/companions/`, `narrative/camp/`). Strained or worse holds the best ending back
until approval recovers; nothing is lost for good, unless the campaign ends first. Close or better adds to it:

| Companion | Strained or worse | Close or better |
|---|---|---|
| Godrick | Won't kneel for the knighting | Names the party his fellowship; Sir Aldric's sword is +2 instead of +1; the party gains Heroic Inspiration |
| Liriel | Can't sing the dawn in the chapel | Leaves her novice's sunburst (Amulet of the Devout +1) that kept the dawn; the party gains Heroic Inspiration |
| Thistle | Won't let the party's magic near Fen | Fen gives her his trapper's cloak (Cloak of Elvenkind) |
| Ratatoille | Lays no table | The supper is a feast: the party gains Heroic Inspiration |
| Wren | Won't take the party's way at Rahadin (no pity option) | Says the last lesson out loud and gains Heroic Inspiration |
| Kip | Won't settle with Quillon with the party watching | Carves the first pit off a free tree into a charm that works (Stone of Good Luck) |

## Romances (`narrative/camp/romance_<pair>.dialogue`)

Between the six, steered by the party (the owner's yes to romances, 2026-10-07; between-the-six is the default the
thread picked while asking whether he'd rather romance a custom hero). Three pairs, each with three camp talks:

| Pair | Spark (both Warm, level 3) | Courting (both Warm, level 5) | Together (both Close, level 7) |
|---|---|---|---|
| Thistle and Wren | The rematch footrace | Wren asks how to tell her | The race in the rain |
| Godrick and Thistle | The eating contest | Godrick asks how to court her | Thistle asks him |
| Liriel and Ratatoille | Grace over his stew | Rat asks what she'd want with a cook | The honey cakes |

The party can nudge, stay quiet, or steer them apart at the spark and the courting; steering them apart ends it
(flag value `over`). Thistle walks one road at a time: either spark waits until the other is unset or over. Kip, a
family man, has no romance. Banter in `narrative/banter/party_six.dialogue` notices the spark and follows the couple.

## Heroic Inspiration for playing in character (`story/in_character.gd`, F15)

`inspire <selector>: reason` gives Heroic Inspiration to the party member the moment fits: `name:` for a companion
true to their own nature (Thistle turning down Kiril, Ratatoille refusing Strahd's tower, Kip getting a receipt
signed, a companion paying Madam Eva in truth), and `class:`, `background:` or the like when the option was a class or
background option, so a custom hero earns it too (a Cleric's prayer, a Wizard's reading of a circle, a Sage knowing
Van Richten's monographs). `inspire party` inspires everyone (a feast, a fellowship). Under the 2024 rules a character
who already has it passes it on; here it goes to the first party member in marching order who lacks it
(docs/rules/deviations.md).

## Dialogue (docs/contracts/dialogue.md)

```
approve godrick_pendlebrook +3 kip_smudgewick -2: You refused to give the house one of your own
inspire name:thistle: turned down Kiril's pack to his face
inspire party: ate Ratatoille's supper at his own table
give cloak_of_elvenkind to name:thistle
if approval.thistle >= close        (a tier, compared by rank: `<= strained` is Strained or worse; or a number)
```

The reason reads as the companion's memory of what the party did ("You ..."). The validator checks the ids, the
sizes (-20 to +20, never 0), tiers and selectors.

## Lines to voice

Every new party line in `narrative/camp/*.dialogue`, `narrative/companions/*.dialogue` and the romance banter, in each
companion's own voice, plus the new Narrator lines. Notices and the memories on the party screen aren't spoken.
