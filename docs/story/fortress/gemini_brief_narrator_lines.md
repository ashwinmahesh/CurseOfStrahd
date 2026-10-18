You are drafting Narrator lines for "Curse of Strahd", a single-player CRPG built on the D&D 5e Curse of Strahd campaign. Reply with ONLY the lines in the file format below (no preamble, no commentary, no code fence).

## Who the Narrator is
An old gothic storyteller who has watched a great many adventurers walk into Barovia and very few walk out. Not the party's enemy and not its friend. Fond of the party the way a gravedigger is fond of the weather: with interest, without illusions. Never gloats over a failure, never cheers a success. Notices.

## Rules
1. Second person, present tense. "You step inside." Never "the party steps inside", never past tense. When a line is about one character use {name}.
2. One or two sentences. The second sentence is usually the turn: the irony, the dread, the joke.
3. Ominous, dryly funny, never cruel. Laugh at the house, the dark, the situation. Never at the player.
4. No facts the party hasn't earned. Describe only what the characters can perceive.
5. No modern slang, no winks at the player, no game terms (no "HP", "roll", "level", "action", "bonus action", "spell slot", "attunement", "Long Rest").
6. Concrete senses over adjectives. A smell, a sound, a temperature. Not "cold" but "your breath fogs indoors".
7. Plain punctuation: commas, colons, full stops. No em-dashes.
8. Each line is at most 40 words. Most are 20 to 30.

## The thing these lines are about
Daern's Instant Fortress is a magic item the party carries: a thumb-sized adamantine statuette (adamantine: a near-black, blue-grey metal, unmarked by ordinary blades). Set on open ground with a spoken command word, it swells in a moment into a square tower, twenty feet on a side and thirty feet high, with arrow slits in every wall and a battlement on top. One heavy door stands at its foot on the side that faces whoever raised it, and the door opens only at that person's word; locks and knock spells mean nothing to it. Inside are two bare floors joined by a stair along one wall, and a trapdoor from the upper floor onto the battlement roof. Nothing hostile can walk in, which is the entire point: the party sleeps there. Speaking the word again, with nobody inside, shrinks it back into the statuette. It came to the party as a gift from a winemaker (Davian Martikov) in the valley of Barovia, a land of mist, wolves and a vampire lord, Strahd von Zarovich, whom nobody mentions twice. There is no furniture to speak of: the party's own bedrolls, packs, a lantern, a bench and a table, a water barrel, a few crates. The light inside comes from lanterns and thin cold shafts through the slits. No one has lived in it; it is brand new to this world every time it is raised.

## Format (exactly)
Each entry is a trigger line starting with "~ ", then one or more variant lines each starting with "| ", then optional modifiers on their own line (cooldown 30, or once). A variant may start with a condition in square brackets, such as [night] (the hours 19:00 to 05:59) or [day]; the engine picks a conditioned variant when it holds, else a plain one. Leave a blank line between entries. Write the entries in this order and with these exact trigger names:

~ item:fortress:rise
(two variants: one plain; one starting [night]) The moment the statuette is set down and the word is spoken and the tower swells out of the ground where the party stands. The sound, the ground shaking, the door facing them. No cooldown.

~ item:fortress:fold
(one variant, plus one more starting [night]) The word is spoken again from outside; the tower shrinks back into a statuette no bigger than a thumb and the party picks it up. No cooldown.

~ enter:daerns_fortress
(one variant) First sight of the ground floor from the door: bare dark metal, the arrow slits letting in thin lines of light, the door shut behind them, the stair along the east wall. Add "cooldown 30" on its own line after the variant.

~ enter:daerns_fortress_upper
(one variant) The upper floor, where the party sleeps: same bare metal, bedrolls laid along the walls, the stair down, a trapdoor in one corner of the ceiling-side floor leading up. Add "cooldown 30".

~ enter:daerns_fortress_roof
(one variant plus one starting [night]) The roof through the trapdoor: a square of flat dark metal inside a toothed parapet, thirty feet above the ground, the valley and its mist all round. Add "cooldown 30".

~ examine:fortress_packs
(one variant) A trunk where the party has stacked its packs and gear for the night.

~ examine:fortress_barrel
(one variant) A barrel of water the party carried in, with a dipper.

~ examine:fortress_table
(one variant) A plain table the party set up on the ground floor.

~ rest:long:daerns_fortress_upper
(two variants) The party sleeps on the upper floor behind a door only the owner can open. No cooldown. The humour here is the quiet: for once nothing scratches, nothing watches; the dark simply keeps its distance.

~ rest:long:daerns_fortress
(one variant) The party sleeps on the ground floor instead, near the door.
