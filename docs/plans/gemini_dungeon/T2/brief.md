You are drafting lines for a single-player gothic horror RPG based on Curse of Strahd (Barovia, Strahd von Zarovich). Write in our own words; never quote the published book. Reply with plain text only: one line per slot, in the form `SLOT_ID: text`, in the order given, nothing else. Finish without sending messages to anyone else.

## The setting: the Amber Temple's vestiges

High in the mountains, the Amber Temple holds sarcophagi of amber, each sealing a vestige: the last ember of a dead god or an older thing. They cannot move or make anything; they can only offer, and every offer comes from what they were. Each one offers a "dark gift" (real power with a real, permanent price). They are honest about the gift and nearly honest about the price: each one names its cost if asked, in its own framing. Wardens long ago carved a blunt warning on each lid. Rules: each voice is one idea taken to its end, never a generic tempter; lines short, let the Narrator describe; no winks, no modern words, no game terms (no "HP", "roll", "check", "level", "save", "spell slot"). No dashes of any kind; use full stops, commas and semicolons.

Two existing vestiges, for the style:
- Seriach, master of the burning hounds (the hunt, a huntsman's growl, proud of its dogs). First words: "Hear them? They've had your scent since the stair. Good noses, my dogs. They never lose a quarry. Want one of them to run with you?" Its offer: "Fire in the blood. Your blows will burn like my hounds' teeth, and flame will slide off you like rain off a dog's back." Its price: "My hounds will follow you. Always. Every beast you meet will smell them and bolt, or bite. And fire hates the cold, hunter. Look where you're standing." Its lid: "Seriach, master of the burning hounds. Its hunts did not end when the quarry died." After a hero accepts, the Narrator: "{name}'s breath smokes, though the air is no colder than before. Far off, inside the mountain, something howls." Refused: "Then run as you are. Slowly. My dogs will find that funny."
- Zantras (adoration, a theatrical monarch). Its call, spoken once as the party first comes near: "Do not walk past the stage, my darlings, when the whole hall was built for your entrance. Step into the light and let me see your faces."

**The Narrator**: an old gothic storyteller. Second person, present tense. One or two sentences; concrete senses over adjectives. `{name}` stands for the hero who accepted.

## The new vault and its three vestiges

A side vault off the stair down to the hall of vestiges. The wardens bricked its doorway up; long ago someone broke through the bricks from outside, and the rubble lies inside. Three sarcophagi stand there. One of them is hard to find: it stands in a niche behind a hidden panel, and even when found, the figure inside never seems to be quite where you looked.

- **Zrin-Hala, the howling storm** (idea: fury, the storm that wrecks for the joy of it). In the amber, a shape like a thundercloud with a howling mouth, lightning frozen in the middle of a strike. Voice: loud, gusting, impatient, laughs like thunder; wants everything broken open. Gift: once a day, a bolt of lightning from your hand; lightning and thunder hurt you less. Price: the air around you crackles and smells of storm so you can never move quietly again, and its temper gets into you: you can't steady your own mind against anything that tries to bend it.
- **Delban, the star of ice and hate** (idea: cold hatred of every warm living thing). In the amber, a single pale blue-white point of light, frost spreading through the amber from it in needles. Voice: quiet, precise, contemptuous, every word cold and clipped; despises warmth, breath, heartbeats. Gift: once a day, a cone of killing cold from your hands; cold hurts you less. Price: fire finds you easier than anyone (it hurts you more), and the cold never leaves your voice, so nobody warms to anything you ask of them.
- **Vaund, the evasive** (idea: escape, never being where the blow lands). The amber seems empty at first; a slight figure in a hooded cloak is always just at the edge of where you look, never at the middle. Voice: light, amused, slippery, answers questions with questions, says "over here" and "not quite"; it got away from everything except the amber. Gift: a few times a day, step from one place to another in a blink, and you dodge what comes at you better than before. Price: part of you is always somewhere else, so you are a little less hardy than you were, and you can never again quite believe anyone is who they seem.

## Slots

The vault (Narrator, 1 or 2 sentences each):
- T2_ENTER_VAULT: entering the breached vault for the first time (the broken bricks, the three amber shapes).
- T2_EXAMINE_BREACH: looking at the broken bricked-up doorway (the bricks were broken in from outside).
- T2_FIND_NICHE: finding the hidden panel to Vaund's niche (one sentence).

For each vestige, with NAME being ZRIN, DELBAN and VAUND (so 15 slots each, ZRIN_CALL, ZRIN_FIRST_NARR and so on):
- NAME_CALL: the vestige's call as the party first comes near, before anyone touches it (the vestige speaking, 1 or 2 short sentences, at most 25 words, a lure with no pitch; must not use the words gift, offer, price, level, save or check).
- NAME_FIRST_NARR: Narrator, what you see in the amber when you first speak to it (1 or 2 sentences).
- NAME_FIRST: the vestige's first words to the party (2 to 4 short sentences, ending with an invitation).
- NAME_BACK: the vestige when the party comes back to it after the first time (one short sentence).
- NAME_GIFTED_NARR: Narrator, what the amber does when someone who carries its gift comes near (one sentence).
- NAME_GIFTED: the vestige to the one who carries its gift (one short sentence).
- NAME_WANT: its answer to "What do you want with us?" (1 or 2 short sentences).
- NAME_OFFER: its answer to "What are you offering?" (the gift above, in its own framing, 1 or 2 sentences).
- NAME_PRICE: its answer to "And the price?" (the price above, in its own framing, 2 or 3 short sentences, honest).
- NAME_LID: the wardens' inscription on its lid, read in plain words (Narrator: The inscription, in plain words: "..."; the quoted part one blunt sentence or two).
- NAME_LID_FAIL: Narrator, the inscription can't be made out (one sentence, specific to this vestige).
- NAME_ACCEPT_NARR: Narrator, what happens to {name} as the gift takes (one or two sentences).
- NAME_ACCEPT: the vestige's words right after (one short sentence).
- NAME_NOONE: the vestige when in the end nobody accepts (one short sentence).
- NAME_REFUSE: the vestige when the party says no (one short sentence).
