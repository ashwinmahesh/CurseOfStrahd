# The Tome of Strahd in his own voice (2026-10-20)

Ashwin: "For the Tome of Strahd cutscene, I want it to be a mix of Strahd's voice and the narrator. Mostly strahd's with the
narrator filling in information that he didnt write", "I like everything that is said, but also just highlight part of his
jealousy for his brother comes from the fact that he is now older and had to work for everything while his younger brother
is getting the love he always wanted", "I should be able to re-trigger that cutscene every time I read the tome of strahd".

The reading is now the conversation `strahd/tome:read` (`narrative/strahd/tome.dialogue`) over the same six pictures. The
first script's 24 Narrator captions were all voiced already, so none was edited. Ten of them, the ones that tell what Strahd
did not write (what lies between his lines), stay in word for word; the 14 that only repeated what he wrote were replaced by
his own first-person words (new lines, unvoiced), and the older-brother point is a new line of its own (`S3b`). One new
closing Narrator line follows his last sentence. That makes 15 Strahd lines and 11 Narrator lines.

Kept Narrator lines (keys in `narrative/narrator/treasures.dialogue`, still there): `read:tome_of_strahd`,
`scene:tome_conqueror_4`, `scene:tome_brothers_3`, `scene:tome_refused_3`, `scene:tome_wedding_2`, `scene:tome_wedding_4`,
`scene:tome_wall_2`, `scene:tome_again`, `scene:tome_again_3`, `scene:tome_again_4`.
No longer played (voiced, kept so each clip keeps its line): `scene:tome_conqueror_2` and `_3`, `scene:tome_brothers`, `_2` and
`_4`, `scene:tome_refused`, `_2` and `_4`, `scene:tome_wedding` and `_3`, `scene:tome_wall` and `_3`, `scene:tome_again_2` and
`_5`.

Drafted by Gemini through the ai-bridge (the packaged service, target `gemini`, no model or effort chosen; the bridge did not
report which model answered). `brief.txt` is the brief as sent, `reply_raw.json` the raw reply record. Edits, slot by slot, in
the table below: "same" means the draft went in untouched. The common edits: no Oxford commas (the game's style), "arrived" cut
from Sergei's line (the book has no arrival), "Queen Ravenovia" dropped from the castle line (the opening Narrator line names her),
the sixth slot made to start with the uniform instead of "That night" (slot 8 starts that way), her pity named in the eighth,
"compact" made "bargain", the grey mist's lock image cut, and the closing line's added sentence ("The ink has torn the page ...")
cut because the Narrator's line before it says the hand breaks there while the last line stays steady.

| Slot | Gemini's draft | In the game |
|---|---|---|
| S1 | I have set down my victories, my medals, and the honours the court heaped upon my name. A prince is measured by what he holds. Far below, my soldiers cheered among the smoking fields, and I did not turn to look at them. | I have set down my victories, my medals and the honours the court heaped upon my name. A prince is measured by what he holds. Far below, my soldiers cheered among the smoking fields, and I did not turn to look at them. |
| S2 | I made the castle that bears my mother Queen Ravenovia's name my seat, and then the quiet came. Peace left nothing to conquer. A kingdom won is merely a house to keep, and I was not bred for keeping house. | I made the castle that bears my mother's name my seat, and then the quiet came. Peace left nothing to conquer. A kingdom won is merely a house to keep, and I was not bred for keeping house. |
| S3 | When my younger brother Sergei arrived, the halls warmed to his step before he had done a single day of service. My brother wore the sun as easily as linen. Every heart yielded to him without effort or demand. | My younger brother Sergei had the gift of being loved without trying. The halls warmed to his step before he had done a single day of service. My brother wore the sun as easily as linen. |
| S3b | As the elder son, I paid for my rank, my army, and every acre of this stone in years and blood. Sergei had never kept a winter watch or held a line, yet he was given freely the only grace I ever desired. | As the elder son I paid for my rank, my army and every acre of this stone in years and blood. Sergei never kept a winter watch or held a line, yet he was given, for nothing, the love I had wanted all my life. |
| S4 | Tatyana came to the castle in white gowns, a young woman with auburn hair, and the light in the hall belonged to her. I had taken an entire country by force, yet before her quiet grace I found something that could not be commanded. | Tatyana came to the castle in white gowns, a young woman with auburn hair, and the light in the hall belonged to her. I had taken a country by force, yet before her quiet grace I found something that could not be commanded. |
| S5 | I recorded my vigilance as the proper concern of an elder brother and the master of the house. Yet I asked the page why a boy who had never bled for a single field should win so easily what a proven commander is denied. | I told myself it was the proper concern of an elder brother and the master of the house. Yet I asked the page why a boy who had never bled for a single field should win so easily what a proven commander is denied. |
| S6 | That night I put on my dress uniform, heavy with ribbons and campaign medals, and offered Tatyana my hand and my house. I laid ten years of hard-won glory before her, judging that a heart, like any fortress, must yield to proven honours. | I put on my dress uniform, heavy with ribbons and campaign medals, and went to Tatyana. I offered her my hand and my house, and laid ten years of hard-won glory before her, judging that a heart, like any fortress, must yield to honours. |
| S7 | She heard my offer to the end, and then she declined it with a small, apologetic smile that cut deeper than any cruelty. She looked upon me with pity. I wrote the fact down in a single line and closed the ledger. | She heard my offer to the end, and then she declined it with a small, apologetic smile that cut deeper than any cruelty. She looked upon me with pity. I wrote it down in one flat line and closed the book. |
| S8 | Before dawn I had resolved the matter in my own mind. I had endured the winter marches and the iron of my enemies, but I would not endure her gentleness at my expense. What is mine by merit shall not be lost to softness. | That night I resolved the matter. I had endured the winter marches and the iron of my enemies, but I would not endure her pity. What is mine by merit shall not be lost to softness. |
| S9 | I made the long freezing climb into the high mountains, where a courteous old warden led me before a hollow sarcophagus of amber. In that dark, a voice understood me at last. It asked only what I wanted, and I answered without ornament. | I made the long freezing climb into the high mountains, where a courteous old warden led me before a hollow sarcophagus of amber. In that dark a voice understood me at last. It asked only what I wanted, and I answered without ornament. |
| S10 | All that week I showed Tatyana every kindness while she walked the halls and chose her white flowers for the feast. The price of my compact fell due on the very day I was to claim my happiness: a necessary debt, best settled swiftly. | All that week I showed Tatyana every kindness while she chose her white flowers for the feast. The price of my bargain fell due on the very day I was to claim my happiness: a necessary debt, best settled swiftly. |
| S11 | Tatyana ran along the high castle walls as the white mist rose from the stones. When I reached for her, she looked once into my face and stepped into the fog. She mistook my reach for ruin, and the precipice took what was mine. | Tatyana ran along the high castle walls as the white mist rose from the stones. When I reached for her she looked once into my face and stepped into the fog. She mistook my reach for ruin, and the precipice took what was mine. |
| S12 | The grey mist closed round the mountains and sealed the passes shut, binding ruler and border into a single lock. The valley and I are one thing now. I keep the accounts of these stones, and I still call my hunger a kingdom. | The grey mist closed round the mountains and sealed the valley shut. The valley and I are one thing now. I keep the accounts of these stones, and I still call my hunger a kingdom. |
| S13 | In each new life I seek her out with patience, letters, gifts, and rescues, hoping she will choose me at last. I was gentle with her at the first. When gentleness fails me, I lay courtesy aside and return to the old ways. | In each new life I seek her out with patience, letters, gifts and rescues, hoping she will choose me at last. I was gentle with her at the first. When gentleness fails me, I lay courtesy aside and return to the old ways. |
| S14 | The ink has torn the page, yet the account is complete and nothing is owed. I chose every step of it, and I would choose it again. | I chose every step of it, and I would choose it again. |
| N_END | The hand never shakes on that last line, which is how you know. | same |
