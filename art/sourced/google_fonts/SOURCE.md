# Fonts (Google Fonts, SIL Open Font License 1.1)

Downloaded 2026-10-08 from the google/fonts repository (https://github.com/google/fonts/tree/main/ofl), untouched,
each with its licence (OFL.txt in its folder). The game draws its type with these on every platform, so a Mac and a
Windows PC look the same (owner, 2026-10-08: before, the faces were macOS system fonts and Windows fell back to
Georgia). Each stands in for the Mac face it replaced, chosen for the nearest look and width:

| Folder | File | SHA-1 | Replaces | Used for |
|---|---|---|---|---|
| medievalsharp/ | MedievalSharp.ttf | 60cb477d78d89c5fbc4008055639aa082ec4c478 | Luminari | Titles, headers and buttons (UiKit.display_font) |
| cinzel/ | Cinzel[wght].ttf | 060d1bc090cb2b06eaddaf89e4b55759ec99ac3c | Copperplate | Engraved captions: HIT POINTS, STRENGTH (UiParts.caps_font) |
| ebgaramond/ | EBGaramond[wght].ttf | 00c7d1e9e74bde586154a1303d562392023136ac | Hoefler Text | The big numbers (UiParts.figure_font) |
