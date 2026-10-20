You are drafting lines for a single-player gothic horror RPG based on Curse of Strahd (Barovia, Castle Ravenloft, Strahd von Zarovich). Write in our own words; never quote the published book. Reply with plain text only: one line per slot, in the form `SLOT_ID: text`, in the order given, nothing else. Finish without sending messages to anyone else.

## The voice: the Narrator

An old gothic storyteller who speaks for the world. Second person, present tense ("You step inside."). One or two sentences; the second is often the turn (irony, dread, a dry joke). Ominous, dryly funny, never cruel. Concrete senses (a smell, a sound, a temperature) over adjectives. No game terms (no "HP", "roll", "check", "level"). Never states things the characters could not perceive. Castle Ravenloft is grand, cold and beautiful, and the menace is in its manners. When someone else speaks through the Narrator (a ghost, a statue), the Narrator describes the voice and quotes the words in double quotes, as in: The little lid buzzes, and a small dry voice comes up through the stone. "I fell down the tower stair."

## Background you can use

Strahd von Zarovich killed his brother Sergei on Sergei's wedding day four hundred years ago, out of love for the bride, Tatyana, who then threw herself from the castle walls. The castle's upper floor, the Rooms of Weeping, is where Strahd lives. Pidlwick was the castle's jester; a toymaker built a clockwork copy of him, Pidlwick II, to amuse the children, but the children still loved the real one, and one night the clockwork copy pushed the real Pidlwick down the high tower's stair. Pidlwick II still wanders the high tower, lonely, holding grudges. Strahd sleeps by day in a coffin in a tomb deep under the castle, at the foot of a black stair in the catacombs. A great crystal heart at the top of the high tower takes his wounds before he does. His treasury lies behind the study's hearth. His parents, King Barov and Queen Ravenovia, and his brother Sergei lie in the old tombs below the catacombs. Long ago he slaughtered the castle's own guards in the kingsmen's hall when they turned on him.

## New rooms (a wing off the Rooms of Weeping)

- **The guardians' passage (the book's "guardian vermin")**: two alcoves flank a steel door engraved with a king on horseback among mountains and wolves. In each alcove stands what looks like a guard, but it is a mass of rats packed into the shape of a man; as the party nears the door they come apart into swarms and attack.
- **The count's dining hall**: a wedding feast laid four hundred years ago and never cleared: fine plates and silver under thick dust, a tall wedding cake slumped and green with age, a bride figurine still on top, the groom figurine lying on the floor where someone threw it. An iron chandelier. A lute on a chair. A harp in the corner. If someone plays the harp well, the ghost of Pidlwick the jester appears and talks. If the party takes the groom figurine out of the room and later comes back, the cake has burst open from inside and something has gone out through the window (we never say what).
- **A closet**: iron hooks with black capes (twenty-eight of them) and formal clothes.
- **The Hall of Heroes**: a long corridor whose ceiling has fallen in, open to the storm. Ten statues of armoured heroes line it, faces blank, until lightning flashes and every face is frozen in horror. The ancestors' spirits live in the statues; each statue will answer one question, but not every answer is true.
- **The parapets**: rain-slick walkways outside the castle walls, patrolled by Strahd's empty suits of animated armour, which attack those who linger.
- **The maid's hall (Helga's room)**: eight canopied beds hung with yellowed lace, all neatly made, dusted every day by the vampire maid Helga, who pretends to be a frightened servant. One small mirror stands turned to the wall (Helga wants nothing more than a looking-glass that keeps an image; vampires have no reflection).
- **The servants' upper rooms**: a dirty attic of broken bedframes. A wardrobe roughly shaped like a coffin, its black doors painted with fey creatures; open it and an old yellowed dress flies out and dances round the room, and it dances until someone touches it. Behind a mirror, a narrow ladder goes down into the dark of the high tower's stair.

## Slots

Narration (Narrator, 1 or 2 sentences each unless said):
- C6_ENTER_PASSAGE: entering the guardians' passage (the two "guards" in their alcoves, the steel door).
- C6_EXAMINE_DOOR: looking at the steel door's engraving.
- C6_FIGHT_VERMIN: shown as the fight begins: the guards come apart into rats (one sentence, under 20 words).
- C6_ENTER_DINING: entering the count's dining hall.
- C6_ENTER_DINING_BURST: entering the dining hall again after the groom figurine was taken away: the cake has burst open from inside and the window is broken outward.
- C6_EXAMINE_CAKE: looking at the wedding cake and the bride on top.
- C6_EXAMINE_GROOM: looking at the groom figurine on the floor.
- C6_TAKE_GROOM: picking up the groom figurine (one sentence).
- C6_EXAMINE_LUTE: looking at the lute on the chair (one sentence).
- C6_HARP_INTRO: the harp, before anyone plays (one sentence).
- C6_HARP_FAIL: the harp played badly (one sentence): nothing answers but the strings.
- C6_HARP_GHOST: the harp played well: the ghost of Pidlwick the jester appears beside it (2 sentences): a small man in motley, see-through, with a jester's timing.
- C6_GHOST_1 to C6_GHOST_6: six short things the ghost says (Narrator describes and quotes him, one or two sentences each, his words witty, sad, with a professional fool's timing): 1) who he was and that he played for this very feast; 2) what happened at the feast (the bride, the groom, the count watching); 3) how he died (fell down the tower stair, the polite word for it), without naming his killer outright; 4) when asked about his clockwork double: it was made to be him and wanted to be loved instead of him; 5) a warning: the clockwork one never forgets a slight, so never laugh at it; 6) his goodbye as he fades (he takes a bow).
- C6_ENTER_CLOSET: entering the closet of capes (one sentence, a dry joke allowed).
- C6_ENTER_HEROES: entering the Hall of Heroes in the storm.
- C6_HEROES_LIGHTNING: lightning shows every face frozen in horror (one sentence).
- C6_HEROES_ASK: the moment the party asks a statue a question: a voice comes out of the stone (one sentence, no quote).
- C6_HEROES_DONE: all the statues that will answer have answered; the hall is only stone and rain (one sentence).
- For each question below, a TRUE answer and a FALSE answer, each quoted from a statue (one or two sentences, old-fashioned, grieving that their bloodline is ending, quoted in double quotes after a short description such as "The statue's lips do not move."). The false answer must sound just as sure as the true one.
  - Q1 Where does the count sleep by day? TRUE: deep under the castle, in a tomb at the foot of a black stair in the catacombs. FALSE: in the chapel, beneath the altar.
  - Q2 What is the heart in the high tower? TRUE: a heart of crystal at the tower's top that takes his wounds before they reach him; break it and he bleeds like other men. FALSE: a gift from the dark powers that kills any who touch it.
  - Q3 Who is the woman in the portrait in the study? TRUE: Tatyana, his brother's bride, whom he loved, and who died on her wedding day. FALSE: his mother, Queen Ravenovia.
  - Q4 Where is his treasure? TRUE: behind the hearth in his study, in a vault inside a vault. FALSE: in the ravens' roost under the roofs.
  - Q5 Who lies in the old tombs? TRUE: King Barov, Queen Ravenovia, and Sergei, the brother he killed. FALSE: the knights who served him, all of them loyal to the end.
  - Q6 What happened to the castle's guards? TRUE: they turned on him the night of the wedding, and he killed them in their own hall. FALSE: they still guard the gate, alive, under a spell of sleep.
  - Q7 Can he be destroyed? TRUE: only in his coffin, by a stake through the heart, or by the light of the sun. FALSE: no; he is the land, and the land cannot die.
  (Name the slots C6_Q1_TRUE, C6_Q1_FALSE, and so on to C6_Q7_FALSE.)
- C6_ENTER_PARAPETS: stepping out onto the rain-slick parapets.
- C6_FIGHT_PARAPETS: shown as the armour on patrol turns on the party (one sentence, under 20 words).
- C6_ENTER_MAIDS: entering Helga's hall of eight canopied beds.
- C6_EXAMINE_MIRROR: looking at the small mirror turned to the wall (turning it round shows the room, and only the room).
- C6_ENTER_SERVANTS: entering the servants' upper rooms.
- C6_EXAMINE_WARDROBE: looking at the coffin-shaped wardrobe painted with fey creatures.
- C6_DRESS_OUT: opening the wardrobe: the dress flies out and begins to dance (2 sentences).
- C6_DRESS_TOUCH: someone touches the dancing dress and it drops, empty and still (one sentence).
- C6_DRESS_LEAVE: leaving the dress dancing (one sentence: it will dance forever, and it seems to prefer it).
- C6_EXAMINE_LADDER_MIRROR: finding the narrow ladder behind the mirror, going down into the dark of the high tower (one sentence).
