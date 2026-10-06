#!/usr/bin/env python3
"""Generates the docs/ui wireframes (SVG) for the four core flows of plan §5.6.
Run: python3 tools/ui/wireframes.py   (writes docs/ui/wireframes/*.svg)
The specs that explain them: docs/ui/character_creation.md, level_up.md, inventory.md, party_management.md."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from wireframe_kit import P, SERIF, Svg  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "docs" / "ui" / "wireframes"
OUT.mkdir(parents=True, exist_ok=True)
PARTY_NEW = [("Ilse", "active"), ("empty", ""), ("empty", ""), ("empty", "")]
PARTY_START = [("new", "active"), ("empty", ""), ("empty", ""), ("empty", "")]
STEPS = ["Start", "Class", "Origin", "Ability Scores", "Class Choices", "Equipment", "Appearance", "Identity", "Review"]
SHEET_FIGHTER = [("Str", "17 (+3)"), ("Dex", "14 (+2)"), ("Con", "14 (+2)"), ("Int", "8 (−1)"), ("Wis", "10 (+0)"),
                 ("Cha", "12 (+1)"), ("AC", "17"), ("Hit Points", "14"), ("Speed", "30 ft"), ("Initiative", "+2"),
                 ("Prof. Bonus", "+2"), ("Saves", "Str +5, Con +4"), ("Greatsword", "+5, 2d6+3"), ("Passive Perc.", "12")]


def steps_state(current, errors=(), warns=()):
    out = []
    for i, s in enumerate(STEPS):
        if i in errors:
            out.append((s, "error"))
        elif i in warns:
            out.append((s, "warn"))
        elif i < current:
            out.append((s, "ok"))
        else:
            out.append((s, "todo"))
    return out


# ------------------------------------------------------------------------------------------------ creation
def cc01_start():
    s = Svg("Character Creation · Start")
    s.frame("Start: who is walking into the mists?", "Party 0 of 4 built", PARTY_START,
            "Choose how to make your party. You can change any character later.", back=False, next_label=None)
    cards = [
        ("Pregenerated party", ["Four level 1 characters made for Barovia,", "each with a hook into the story.",
                                 "Use them as they are, or edit any step.", "", "Fastest way into the game."], False, True),
        ("Build from scratch", ["Nine steps per character: Class, Origin,", "Ability Scores, Class Choices, Equipment,",
                                "Appearance, Identity, Review.", "", "Any finished step can be revisited."], True, False),
        ("Copy from a save", ["Bring a character from another", "playthrough, then edit freely.", "", "",
                              "Levels and gear come along."], False, False),
    ]
    x = 60
    for i, (t, rows, focus, selected) in enumerate(cards):
        disabled = i == 2
        s.card(x, 150, 470, 230, t, rows, selected=selected, focus=focus, disabled=disabled,
               reason="No other saves yet" if disabled else None)
        x += 500
    s.callout(1, 520, 166)
    s.callout(2, 1040, 166)
    # pregen preview strip
    s.panel(60, 410, 1480, 400, "PREGENERATED PARTY (preview)")
    pregens = [("Ilse Varga", "Human Fighter (Champion), Soldier", "Her company vanished on a fog-bound road."),
               ("Tamsin Tealeaf", "Halfling Rogue (Thief), Criminal", "A stolen locket shows a woman he's never met."),
               ("Hedda Ironvow", "Dwarf Cleric (Life Domain), Acolyte", "Dreams of a silver raven and a dying sun."),
               ("Silvain Aster", "High Elf Wizard (Evoker), Sage", "Hunts a book written in a vampire's hand.")]
    x = 80
    for name, line, hook in pregens:
        s.rect(x, 530, 340, 255, P["ink"], P["ash"], 1)
        s.rect(x + 16, 546, 92, 120, P["ash"], P["slate"], 1, rx=4)
        s.text(x + 62, 612, "portrait", 12, P["pewter"], anchor="middle")
        s.text(x + 122, 570, name, 17, P["ivory"], "bold", family=SERIF)
        s.lines(x + 122, 594, line.split(", "), 12, P["silver"])
        s.lines(x + 16, 700, [hook], 13, P["lilac"], italic=True)
        s.button(x + 16, 730, 140, 34, "Edit")
        s.button(x + 184, 730, 140, 34, "Use as is", primary=True)
        x += 360
    s.callout(3, 1480, 428)
    s.save(OUT / "cc_01_start.svg")


def cc02_class():
    s = Svg("Character Creation · Class")
    s.frame("Class", "Ilse · step 2 of 9", PARTY_NEW, "Pick a class. Hover any rule term for its explanation.")
    s.steps(24, 130, steps_state(1), 1)
    classes = [("Fighter", "Front line · Weapons", "●○○", True), ("Rogue", "Skills · Striker", "●●○", False),
               ("Cleric", "Healer · Divine", "●●○", False), ("Wizard", "Arcane · Control", "●●●", False)]
    x = 268
    for name, roles, cx, sel in classes:
        s.card(x, 130, 200, 96, name, [roles, "Complexity " + cx], selected=sel, focus=sel)
        x += 212
    s.callout(1, 268, 124)
    s.parchment(268, 244, 836, 566, "Fighter")
    rows = ["Primary ability: Strength or Dexterity     Hit Point Die: d10", "Saving throws: Strength, Constitution",
            "Armor training: Light, Medium, Heavy, Shields     Weapons: Simple and Martial",
            "Skills: choose 2 of Acrobatics, Animal Handling, Athletics, History, Insight, …"]
    s.lines(290, 306, rows, 14, P["umber"])
    s.text(290, 412, "Levels 1 to 5", 16, P["ink"], "bold")
    feats = ["1  Fighting Style · Second Wind · Weapon Mastery", "2  Action Surge · Tactical Mind",
             "3  Fighter Subclass", "4  Ability Score Improvement", "5  Extra Attack · Tactical Shift"]
    s.lines(290, 440, feats, 14, P["umber"])
    s.text(290, 572, "Subclasses (chosen at level 3)", 16, P["ink"], "bold")
    subs = [("Battle Master", "Superiority Dice fuel trips, parries, rallies."), ("Champion", "Crits on 19-20, athletic, hard to kill."),
            ("Eldritch Knight", "Wizard spells and a bonded weapon."), ("Psi Warrior", "Psionic shields and Force strikes.")]
    y = 600
    for n, d in subs:
        s.rect(290, y - 18, 790, 40, P["ivory"], P["bone"], 1, rx=4)
        s.text(304, y + 6, n, 14, P["ink"], "bold")
        s.text(460, y + 6, d, 13, P["umber"])
        s.text(1066, y + 6, "features to 20 ▸", 12, P["ember"], anchor="end")
        y += 48
    s.callout(2, 1094, 572)
    s.live_sheet(1124, 130, 452, 680, "Ilse", "Human Fighter 1 · Soldier", SHEET_FIGHTER)
    s.callout(3, 1556, 150)
    s.save(OUT / "cc_02_class.svg")


def cc03_origin():
    s = Svg("Character Creation · Origin")
    s.frame("Origin: background, species, languages", "Ilse · step 3 of 9", PARTY_NEW,
            "Your background decides which three abilities can rise.")
    s.steps(24, 130, steps_state(2, errors=(2,)), 2)
    s.panel(268, 130, 400, 680, "BACKGROUND")
    bgs = ["Acolyte", "Artisan", "Charlatan", "Criminal", "Entertainer", "Farmer", "Guard", "Guide", "Hermit",
           "Merchant", "Noble", "Sage", "Sailor", "Scribe", "Soldier", "Wayfarer"]
    y = 194
    for b in bgs:
        sel = b == "Soldier"
        if sel:
            s.rect(276, y - 19, 384, 28, P["bruise"], P["candle"], 2, rx=4)
        s.text(292, y, b, 14, P["ivory"] if sel else P["silver"], "bold" if sel else "normal")
        y += 30
    s.panel(680, 130, 430, 330, "SOLDIER")
    s.lines(700, 196, ["Abilities: Strength, Dexterity, Constitution", "Origin feat: Savage Attacker",
                       "Skills: Athletics, Intimidation", "Tool: one Gaming Set"], 13, P["silver"])
    s.text(700, 300, "Gaming Set", 13, P["lilac"])
    s.rect(800, 284, 200, 26, P["ink"], P["ash"], rx=4)
    s.text(812, 302, "Dice Set ▾", 13, P["ivory"])
    s.text(700, 350, "Ability increases", 14, P["lilac"], "bold")
    s.chip(700, 362, "+2 / +1", P["ink"], P["candle"])
    s.chip(790, 362, "+1 / +1 / +1")
    for i, (ab, v) in enumerate([("Str", "+2"), ("Dex", ""), ("Con", "+1")]):
        s.button(700 + i * 130, 400, 116, 40, f"{ab} {v}".strip(), primary=bool(v), focus=(i == 0))
    s.callout(1, 1090, 350)
    s.panel(680, 474, 430, 336, "SPECIES: HUMAN")
    s.lines(700, 540, ["Size: Medium or Small (choose)", "Speed 30 ft"], 13, P["silver"])
    s.chip(700, 576, "Medium", P["ink"], P["candle"])
    s.chip(784, 576, "Small")
    s.text(700, 632, "Skillful: one skill", 13, P["lilac"])
    s.status(700, 658, "ok", "Perception")
    s.text(700, 700, "Versatile: one Origin feat", 13, P["lilac"])
    s.status(700, 726, "error", "Not chosen yet: pick an Origin feat")
    s.text(700, 778, "Languages: Common + 2 standard", 13, P["lilac"])
    s.status(930, 778, "warn", "1 of 2")
    s.callout(2, 1090, 700)
    rows = [(k, "12" if k == "Hit Points" else v) for k, v in SHEET_FIGHTER]
    s.live_sheet(1124, 130, 452, 680, "Ilse", "Human Fighter 1 · Soldier", rows, changed=("Str", "Con", "Hit Points", "Saves"))
    s.callout(3, 1556, 150)
    s.save(OUT / "cc_03_origin.svg")


def cc04_abilities():
    s = Svg("Character Creation · Ability Scores")
    s.frame("Ability Scores", "Ilse · step 4 of 9", PARTY_NEW, "Drag a score onto an ability, or pick one and press A on an ability.")
    s.steps(24, 130, steps_state(3), 3)
    s.panel(268, 130, 840, 680)
    tabs = [("Standard Array", True), ("Point Cost", False), ("Random (4d6)", False)]
    x = 288
    for t, on in tabs:
        s.rect(x, 146, 200, 40, P["bruise"] if on else P["ink"], P["candle"] if on else P["ash"], 2 if on else 1, rx=4)
        s.text(x + 100, 172, t, 14, P["ivory"], "bold" if on else "normal", anchor="middle")
        x += 212
    s.button(940, 146, 150, 40, "Recommended")
    s.callout(1, 1100, 166)
    s.text(288, 226, "Unused:", 14, P["silver"])
    x = 360
    for v in ["12"]:
        s.rect(x, 206, 52, 34, P["candle"], P["wick"], 2, rx=6)
        s.text(x + 26, 229, v, 16, P["ink"], "bold", anchor="middle")
    for label, hx in [("Ability", 304), ("Base", 436), ("Background", 540), ("Total", 690), ("Modifier", 790)]:
        s.text(hx, 280, label, 14, P["lilac"], "bold")
    rows = [("Strength", "15", "+2", "17", "+3", True), ("Dexterity", "14", "", "14", "+2", False),
            ("Constitution", "13", "+1", "14", "+2", False), ("Intelligence", "—", "", "—", "", False),
            ("Wisdom", "10", "", "10", "+0", False), ("Charisma", "8", "", "8", "−1", False)]
    y = 320
    for name, base, bg, tot, mod, focus in rows:
        s.rect(288, y - 24, 800, 48, P["ink"], P["wick"] if focus else P["ash"], 3 if focus else 1, rx=4)
        s.text(304, y + 6, name, 15, P["ivory"], "bold")
        if base == "—":
            s.rect(436, y - 16, 52, 32, P["ink"], P["slate"], 1, rx=6, dash="4 3")
            s.status(700, y + 6, "error", "Empty: place the 12 here")
        else:
            s.rect(436, y - 16, 52, 32, P["candle"], rx=6)
            s.text(462, y + 6, base, 15, P["ink"], "bold", anchor="middle")
            s.text(560, y + 6, bg, 15, P["bile"], "bold")
            s.text(690, y + 6, tot, 16, P["ivory"], "bold")
            s.text(800, y + 6, mod, 16, P["wick"], "bold")
        y += 58
    s.callout(2, 1080, 418)
    s.panel(288, 680, 380, 116, "POINT COST (other tab)")
    s.lines(304, 744, ["Points left: 3 of 27", "8–15 only · 14 costs 7 · 15 costs 9"], 13, P["silver"])
    s.panel(688, 680, 400, 116, "RANDOM (other tab)")
    s.lines(704, 744, ["Rolled with the game's dice, shown:", "⚀⚄⚅⚂ → drop 1 → 14   ·   Re-roll only by restarting"], 13, P["silver"])
    s.callout(3, 1080, 700)
    s.tooltip(1124, 130, 452, "Strength 17 (+3)", ["Base (Standard Array) 15", "Background: Soldier +2",
                                                  "Modifier = (17 − 10) ÷ 2, rounded down = +3",
                                                  "Used for: Athletics, Strength saves, melee", "weapon attacks and damage (Greatsword)"])
    s.live_sheet(1124, 330, 452, 480, "Ilse", "Human Fighter 1 · Soldier", SHEET_FIGHTER[:10], changed=("Str",))
    s.save(OUT / "cc_04_abilities.svg")


def cc05_choices():
    s = Svg("Character Creation · Class Choices")
    s.frame("Class Choices", "Ilse · step 5 of 9", PARTY_NEW, "Each box is one choice the rules give you. The count shows how many to pick.")
    s.steps(24, 130, steps_state(4, warns=(4,)), 4)
    s.panel(268, 130, 840, 230, "SKILLS · choose 2 of 9      2 of 2 ✓")
    skills = [("Acrobatics", "Dex", 0, None), ("Animal Handling", "Wis", 0, None), ("Athletics", "Str", 0, "Already from Soldier"),
              ("History", "Int", 0, None), ("Insight", "Wis", 1, None), ("Intimidation", "Cha", 0, "Already from Soldier"),
              ("Perception", "Wis", 0, "Already from Human"), ("Persuasion", "Cha", 0, None), ("Survival", "Wis", 1, None)]
    for i, (n, ab, on, warn) in enumerate(skills):
        x = 284 + (i % 3) * 272
        y = 190 + (i // 3) * 54
        s.rect(x, y - 22, 258, 44, P["bruise"] if on else P["ink"], P["candle"] if on else P["ash"], 2 if on else 1, rx=4)
        s.text(x + 12, y, ("☑ " if on else "☐ ") + n, 14, P["ivory"])
        s.text(x + 246, y, ab, 12, P["silver"], anchor="end")
        if warn:
            s.text(x + 30, y + 16, "~ " + warn, 11, P["flame"])
    s.callout(1, 1090, 150)
    s.panel(268, 374, 840, 200, "FIGHTING STYLE · choose 1      1 of 1 ✓")
    styles = [("Archery", "+2 to ranged attacks"), ("Defense", "+1 AC in armor"), ("Dueling", "+2 damage, one weapon"),
              ("Great Weapon Fighting", "1s and 2s count as 3"), ("Protection", "Reaction: Disadvantage"),
              ("Two-Weapon Fighting", "add mod to off-hand")]
    for i, (n, d) in enumerate(styles):
        x = 284 + (i % 3) * 272
        y = 420 + (i // 3) * 74
        s.card(x, y, 258, 64, n, [d], selected=n == "Defense", focus=n == "Defense")
    s.panel(268, 588, 840, 222, "WEAPON MASTERY · choose 3      3 of 3 ✓   (change one after any Long Rest)")
    weapons = [("Greatsword", "Graze: miss still deals Str mod", True), ("Flail", "Sap: target has Disadvantage", True),
               ("Javelin", "Slow: −10 ft Speed", True), ("Longsword", "Sap", False), ("Glaive", "Graze", False), ("Longbow", "Slow", False)]
    for i, (n, d, on) in enumerate(weapons):
        x = 284 + (i % 3) * 272
        y = 640 + (i // 3) * 74
        s.card(x, y, 258, 64, ("☑ " if on else "☐ ") + n, [d], selected=on)
    s.callout(2, 1090, 600)
    s.live_sheet(1124, 130, 452, 680, "Ilse", "Human Fighter 1 · Soldier", SHEET_FIGHTER, changed=("AC",))
    s.save(OUT / "cc_05_class_choices.svg")


def cc05b_spells():
    s = Svg("Character Creation · Spell browser (Wizard)")
    party = [("Ilse", "done"), ("Tamsin", "done"), ("Hedda", "done"), ("Silvain", "active")]
    s.frame("Class Choices: spells", "Silvain · step 5 of 9", party, "Spellbook 4 of 6 · Prepared 2 of 4. Unavailable spells show why.")
    s.steps(24, 130, steps_state(4, errors=(4,)), 4)
    s.panel(268, 130, 520, 680, "WIZARD SPELLS")
    s.chip(284, 182, "Level 1 ▾", P["ink"], P["candle"])
    x = s.chip(380, 182, "School: any ▾")
    x = s.chip(x, 182, "Concentration")
    x = s.chip(x, 182, "Ritual")
    s.chip(284, 216, "Damage: Fire ▾")
    s.rect(420, 214, 352, 28, P["ink"], P["ash"], rx=4)
    s.text(432, 233, "🔍 search", 13, P["pewter"])
    s.callout(1, 776, 196)
    rows = [("☑ Magic Missile", "Evocation", "book", True, None), ("☑ Shield", "Abjuration · Reaction", "book", True, None),
            ("☑ Burning Hands", "Evocation · 15 ft cone", "book", False, None), ("☑ Mage Armor", "Abjuration", "book", False, None),
            ("☐ Sleep", "Enchantment · C", "", False, None), ("☐ Detect Magic", "Divination · C, R", "", False, None),
            ("☐ Find Familiar", "Conjuration · R", "", False, "~ You already have it from Magic Initiate"),
            ("☐ Fireball", "Evocation · level 3", "", False, "⊘ Needs level 3 spell slots")]
    y = 280
    for name, school, inbook, prep, note in rows:
        dis = note and note.startswith("⊘")
        s.rect(284, y - 20, 488, 52 if note else 38, P["stone"] if dis else P["ink"], P["candle"] if name.startswith("☑ Magic") else P["ash"], 2 if name.startswith("☑ Magic") else 1, rx=4)
        s.text(298, y + 2, name, 14, P["pewter"] if dis else P["ivory"], "bold")
        s.text(540, y + 2, school, 12, P["silver"])
        if prep:
            s.text(760, y + 2, "★ prepared", 12, P["wick"], anchor="end")
        if note:
            s.text(320, y + 22, note, 12, P["rose"] if dis else P["flame"])
        y += 60 if note else 48
    s.callout(2, 776, 640)
    s.parchment(800, 130, 308, 680, "Magic Missile")
    s.lines(818, 186, ["Level 1 Evocation · Wizard, Sorcerer", "Action · 120 ft · V, S · Instant"], 13, P["umber"])
    s.lines(818, 246, ["Three darts of force each hit a", "creature you can see: 1d4 + 1", "Force damage each. Darts can hit",
                       "the same or different targets.", "", "Higher slot: one more dart per", "level above 1.", "",
                       "With you: 3 × (1d4+1) Force,", "always hits."], 13, P["ink"])
    s.button(818, 740, 272, 40, "Prepare ★", primary=True, focus=True)
    s.callout(3, 1090, 150)
    rows2 = [("Int", "17 (+3)"), ("Spell save DC", "13"), ("Spell attack", "+5"), ("Slots", "L1 × 2"), ("Cantrips", "3 of 3 ✓"),
             ("Spellbook", "4 of 6 !"), ("Prepared", "2 of 4 !"), ("AC", "11 (14 with Mage Armor)"), ("Hit Points", "8")]
    s.live_sheet(1124, 130, 452, 680, "Silvain", "High Elf Wizard 1 · Sage", rows2)
    s.save(OUT / "cc_05b_spells.svg")


def cc06_equipment():
    s = Svg("Character Creation · Equipment")
    s.frame("Equipment", "Ilse · step 6 of 9", PARTY_NEW, "Take a starting package or the gold. Numbers show what the gear does for you.")
    s.steps(24, 130, steps_state(5), 5)
    opts = [("Fighter A", ["Chain Mail → AC 16 (17 with Defense)", "   Heavy · needs Str 13 ✓ · Stealth Disadvantage",
                           "Greatsword  +5 · 2d6+3 Slashing · Graze ★", "Flail  +5 · 1d8+3 · Sap ★", "8 Javelins  +5 · 1d6+3 · Slow ★",
                           "Dungeoneer's Pack · 4 GP"], True),
            ("Fighter B", ["Studded Leather → AC 14 (15 with Defense)", "Scimitar · Shortsword · Longbow + 20 Arrows",
                           "Quiver · Dungeoneer's Pack · 11 GP"], False),
            ("Fighter C", ["155 GP to spend at the first merchant"], False)]
    y = 130
    for t, rows, sel in opts:
        h = 40 + 21 * len(rows) + 20
        s.card(268, y, 600, h, t, rows, selected=sel, focus=sel)
        y += h + 14
    s.callout(1, 860, 150)
    s.card(890, 130, 218, 290, "Soldier A", ["Spear · Shortbow", "20 Arrows · Quiver", "Dice Set · Healer's Kit",
                                             "Traveler's Clothes", "14 GP"], selected=True)
    s.card(890, 434, 218, 110, "Soldier B", ["50 GP"])
    s.panel(268, 640, 840, 170, "WARNINGS")
    s.status(290, 700, "warn", "Rogue B: you'd carry Studded Leather you can use; fine.")
    s.status(290, 736, "info", "★ = you can use this weapon's mastery property (Weapon Mastery choices)")
    s.status(290, 772, "info", "Total gold: 18 GP. Packs open in the inventory after creation.")
    s.callout(2, 1090, 660)
    s.live_sheet(1124, 130, 452, 680, "Ilse", "Human Fighter 1 · Soldier", SHEET_FIGHTER, changed=("AC",))
    s.save(OUT / "cc_06_equipment.svg")


def cc07_appearance():
    s = Svg("Character Creation · Appearance")
    s.frame("Appearance", "Ilse · step 7 of 9", PARTY_NEW, "Q / E or the right stick turns the preview. It uses the game's shaders.")
    s.steps(24, 130, steps_state(6), 6)
    s.panel(268, 130, 520, 680, "IN-GAME SPRITE")
    s.rect(380, 190, 300, 420, P["night"], P["ash"], rx=6)
    s.rect(470, 260, 120, 300, P["ash"], P["slate"], rx=40)
    s.text(530, 420, "sprite", 14, P["pewter"], anchor="middle")
    dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    for i, d in enumerate(dirs):
        x = 290 + i * 60
        s.rect(x, 640, 52, 64, P["ink"], P["candle"] if d == "SE" else P["ash"], 2 if d == "SE" else 1, rx=4)
        s.text(x + 26, 724, d, 12, P["silver"], anchor="middle")
    s.button(300, 750, 200, 36, "Shaders: on (palette)")
    s.callout(1, 776, 150)
    s.panel(800, 130, 308, 680, "LOOK")
    labels = [("Body type", ["A", "B", "C"]), ("Skin", ["", "", "", "", ""]), ("Hair", ["", "", "", "", ""]),
              ("Outfit main", ["", "", "", ""]), ("Outfit trim", ["", "", "", ""])]
    sw = [P["skin_light"] if False else "#e6b896", "#c48a6a", "#7a4a3c", "#5b4c3e", "#3d0a14"]
    y = 190
    for name, opts in labels:
        s.text(816, y, name, 13, P["lilac"])
        for i, _ in enumerate(opts):
            col = sw[i % len(sw)] if name != "Body type" else P["ash"]
            s.rect(816 + i * 52, y + 10, 44, 34, col, P["wick"] if i == 0 else P["ink"], 3 if i == 0 else 1, rx=4)
            if name == "Body type":
                s.text(838 + i * 52, y + 33, opts[i], 13, P["ivory"], anchor="middle")
        y += 78
    s.text(816, 600, "Portrait (generated sets)", 13, P["lilac"])
    for i in range(4):
        s.rect(816 + i * 70, 612, 62, 80, P["ash"], P["wick"] if i == 1 else P["ink"], 3 if i == 1 else 1, rx=4)
    s.callout(2, 1090, 150)
    s.live_sheet(1124, 130, 452, 680, "Ilse", "Human Fighter 1 · Soldier", SHEET_FIGHTER[:8])
    s.save(OUT / "cc_07_appearance.svg")


def cc08_identity():
    s = Svg("Character Creation · Identity")
    s.frame("Identity", "Ilse · step 8 of 9", PARTY_NEW, "Tags shape what this character says when the party talks to people.")
    s.steps(24, 130, steps_state(7), 7)
    s.panel(268, 130, 840, 680)
    s.text(290, 186, "Name", 14, P["lilac"])
    s.rect(290, 198, 500, 40, P["ink"], P["wick"], 3, rx=4)
    s.text(306, 224, "Ilse Varga", 17, P["ivory"])
    s.text(290, 280, "Pronouns", 14, P["lilac"])
    x = 290
    for p, on in [("she/her", True), ("he/him", False), ("they/them", False), ("custom…", False)]:
        x = s.chip(x, 292, p, P["ink"] if on else None, P["candle"] if on else None)
    s.text(290, 360, "Personality (pick 2 or 3)", 14, P["lilac"])
    x, y = 290, 372
    for i, t in enumerate(["blunt", "loyal", "veteran", "pious", "curious", "greedy", "kind", "proud", "sardonic", "nervous", "bookish", "brave"]):
        on = t in ("blunt", "loyal", "veteran")
        x = s.chip(x, y, t, P["ink"] if on else None, P["candle"] if on else None)
        if x > 1040:
            x, y = 290, y + 34
    s.text(290, 480, "Backstory (pick 1)", 14, P["lilac"])
    x = 290
    for t in ["deserter", "orphan", "noble-born", "exile", "survivor", "debtor"]:
        on = t == "survivor"
        x = s.chip(x, 492, t, P["ink"] if on else None, P["candle"] if on else None)
    s.text(290, 560, "Story hook", 14, P["lilac"])
    s.rect(290, 572, 800, 90, P["ink"], P["ash"], rx=4)
    s.lines(306, 600, ["Her mercenary company vanished on a fog-bound road a year ago; the only trace",
                       "was a sealed letter of invitation signed with a single ornate S."], 14, P["silver"], italic=True)
    s.status(290, 700, "info", "Example interjection unlocked by 'blunt': \"Ask him straight. If he lies, I'll know.\"")
    s.callout(1, 800, 216)
    s.callout(2, 1090, 360)
    s.live_sheet(1124, 130, 452, 680, "Ilse Varga", "Human Fighter 1 · Soldier · she/her", SHEET_FIGHTER[:8])
    s.save(OUT / "cc_08_identity.svg")


def cc09_review():
    s = Svg("Character Creation · Review")
    s.frame("Review", "Ilse · step 9 of 9", [("Ilse", "active"), ("Tamsin", "done"), ("Hedda", "done"), ("Silvain", "done")],
            "Fix the blocking items to confirm. Warnings never block.", next_label="Confirm ✓", next_disabled=True)
    s.steps(24, 130, steps_state(8, errors=(2,), warns=(4,)), 8)
    s.parchment(268, 130, 840, 520, "Ilse Varga · Human Fighter 1 · Soldier")
    cols = [["STR 17 +3", "DEX 14 +2", "CON 14 +2", "INT  8 −1", "WIS 10 +0", "CHA 12 +1"],
            ["AC 17", "HP 12", "Speed 30 ft", "Initiative +2", "Prof. Bonus +2", "Passive Perception 12"],
            ["Saves: Str +5 · Con +4", "Athletics +5 · Intimidation +3", "Insight +2 · Perception +2 · Survival +2",
             "Greatsword +5 · 2d6+3 · Graze", "Javelin +5 · 1d6+3 · Slow", "Feats: Savage Attacker, Defense"]]
    for i, col in enumerate(cols):
        s.lines(290 + i * 250, 196, col, 14, P["ink"], gap=26)
    s.text(290, 380, "Features", 15, P["ink"], "bold")
    s.lines(290, 406, ["Fighting Style (Defense) · Second Wind ×2 · Weapon Mastery (Greatsword, Flail, Javelin)",
                       "Human: Resourceful · Skillful · Versatile (—)", "Languages: Common, Dwarvish, Elvish",
                       "Gear: Chain Mail, Greatsword, Flail, 8 Javelins, Spear, Shortbow, 20 Arrows, …  18 GP"], 13, P["umber"], gap=24)
    s.panel(268, 664, 560, 146, "BLOCKING (1)")
    s.status(290, 724, "error", "Versatile (Species: Human): choose 1 Origin feat.")
    s.text(290, 754, "Go to Origin ▸", 13, P["wick"])
    s.panel(840, 664, 268, 146, "WARNINGS (1)")
    s.status(858, 724, "warn", "Athletics: already from", 12)
    s.text(884, 744, "Soldier; the Fighter pick", 12, P["flame"])
    s.text(884, 762, "adds nothing.", 12, P["flame"])
    s.callout(1, 820, 680)
    # party composition
    s.panel(1124, 130, 452, 680, "PARTY COMPOSITION")
    s.lines(1144, 196, ["Healing: Hedda", "Front line: Ilse", "Arcane: Silvain · Divine: Hedda"], 14, P["silver"], gap=26)
    s.text(1144, 290, "Skills (best in party)", 13, P["lilac"])
    sk = [("Stealth", "Tamsin +7"), ("Perception", "Silvain +4"), ("Arcana", "Silvain +5"), ("Athletics", "Ilse +5"),
          ("Persuasion", "Hedda +3"), ("Nature", "nobody ⊘")]
    y = 316
    for a, b in sk:
        s.text(1144, y, a, 13, P["silver"])
        s.text(1556, y, b, 13, P["rose"] if "nobody" in b else P["ivory"], anchor="end")
        y += 22
    s.text(1144, 470, "Gaps (advice, never enforced)", 13, P["lilac"])
    s.status(1144, 500, "warn", "Nobody is proficient in Nature, Animal", 12)
    s.text(1170, 518, "Handling or Performance.", 12, P["flame"])
    s.status(1144, 548, "warn", "2 of 4 can't see in the dark; bring light.", 12)
    s.status(1144, 584, "ok", "Radiant damage: Hedda (Sacred Flame)", 12)
    s.callout(2, 1556, 150)
    s.save(OUT / "cc_09_review.svg")


def cc10_explain():
    s = Svg("Explanations and controller focus (all screens)")
    s.frame("Every number explains itself", None, None, "Y / right-click pins a tooltip. Pinned tooltips stack until closed.",
            back=False, next_label=None)
    s.panel(40, 130, 700, 680, "HOVER OR FOCUS A NUMBER")
    s.rect(70, 190, 160, 70, P["ink"], P["wick"], 3, rx=6)
    s.text(150, 238, "AC 17", 26, P["ivory"], "bold", anchor="middle")
    s.tooltip(260, 180, 450, "Armor Class 17", ["Chain Mail 16 (heavy: no Dexterity)", "Defense +1 (Fighting Style, in armor)",
                                               "Not counted: Dexterity +2 (heavy armor)"])
    s.rect(70, 360, 160, 70, P["ink"], P["ash"], 1, rx=6)
    s.text(150, 408, "Stealth +2", 22, P["ivory"], "bold", anchor="middle")
    s.tooltip(260, 340, 450, "Stealth +2", ["Dexterity modifier +2", "Not proficient",
                                            "Disadvantage: Chain Mail", "Passive: 10 + 2 − 5 = 7"])
    s.rect(70, 560, 160, 70, P["ink"], P["ash"], 1, rx=6)
    s.text(150, 608, "HP 34", 22, P["ivory"], "bold", anchor="middle")
    s.tooltip(260, 520, 450, "Hit Points 34 (level 3)", ["Level 1: Fighter d10 maximum 10", "2 levels at the fixed value 12",
                                                       "Con modifier +2 × 3 levels 6", "Tough +6 (2 × level)"])
    s.panel(760, 130, 800, 330, "RULE TERMS OPEN NESTED, PINNABLE TOOLTIPS")
    s.text(790, 196, "Remarkable Athlete: you have", 14, P["silver"])
    s.text(985, 196, "Advantage", 14, P["wick"], "bold")
    s.line(985, 200, 1060, 200, P["wick"], 1, dash="3 2")
    s.text(1068, 196, "on Initiative and Strength (Athletics) checks.", 14, P["silver"])
    s.tooltip(800, 226, 560, "Advantage", ["Roll two d20s and use the higher.", "Advantage and Disadvantage cancel out,",
                                           "however many sources of each you have.", "Here from: Remarkable Athlete (Champion 3)"], pinned=True)
    s.panel(760, 480, 800, 330, "CONTROLLER AND KEYBOARD")
    rows = [("Move focus", "D-pad / left stick", "Arrows / Tab"), ("Choose / toggle", "A", "Enter / Space"),
            ("Back", "B", "Esc"), ("Explain (tooltip)", "Y (hold)", "F1 / hover"), ("Pin tooltip", "Y twice", "Right-click"),
            ("Previous / next step", "LB / RB", "PgUp / PgDn"), ("Previous / next character", "LT / RT", "Ctrl+Tab"),
            ("Confirm step", "Start", "Ctrl+Enter")]
    y = 546
    s.text(790, 530, "Action", 13, P["lilac"], "bold")
    s.text(1100, 530, "Controller", 13, P["lilac"], "bold")
    s.text(1330, 530, "Mouse and keyboard", 13, P["lilac"], "bold")
    for a, c, k in rows:
        s.text(790, y + 10, a, 13, P["silver"])
        s.text(1100, y + 10, c, 13, P["ivory"])
        s.text(1330, y + 10, k, 13, P["ivory"])
        y += 30
    s.status(790, 800, "info", "Focus = thick candle frame + ▸ marker, never colour alone. Text scales 100-160%.")
    s.save(OUT / "cc_10_explanations_and_controller.svg")


# ------------------------------------------------------------------------------------------------ level up
PARTY_LU = [("Ilse ⬆", "active"), ("Tamsin ⬆", ""), ("Hedda", ""), ("Silvain ⬆", "")]


def lu01_class():
    s = Svg("Level Up · Choose a class")
    s.frame("Ilse reaches level 4", "Level up · 1 of 4: Class", PARTY_LU, "Advance your class, or start a new one if you qualify.")
    opts = [("Fighter", "Level 3 → 4", ["Ability Score Improvement or a feat", "Weapon Mastery: 4 weapons"], True, None),
            ("Rogue", "New class (multiclass)", ["Gain: Light armor, Thieves' Tools,", "one Rogue skill, Sneak Attack 1d6"], False, None),
            ("Cleric", "New class (multiclass)", ["Needs Wisdom 13"], False, "Cleric needs Wisdom 13 (you have 10)"),
            ("Wizard", "New class (multiclass)", ["Needs Intelligence 13"], False, "Wizard needs Intelligence 13 (you have 8)")]
    x = 40
    for name, sub, rows, sel, reason in opts:
        s.card(x, 140, 368, 220, name, [sub, ""] + rows, selected=sel, focus=sel, disabled=bool(reason), reason=reason)
        x += 384
    s.callout(1, 400, 156)
    s.callout(2, 1168, 156)
    s.panel(40, 390, 1520, 420, "WHAT MULTICLASSING MEANS")
    s.lines(64, 456, ["• Your Proficiency Bonus follows your total level; each class's features follow that class's level.",
                      "• A new class gives only some of its starting proficiencies (shown on each card) and never level 1 Hit Points.",
                      "• Spell slots combine across classes; each class prepares its own spells as if single-classed.",
                      "• To take a new class you need 13 in its primary ability AND in the primary ability of every class you have.",
                      "• Extra Attack from two classes doesn't stack."], 15, P["silver"], gap=34)
    s.status(64, 660, "info", "Ilse: Strength 17 meets Fighter's 'Strength or Dexterity 13'. Dexterity 14 meets Rogue's 13.")
    s.callout(3, 1540, 410)
    s.save(OUT / "lu_01_class.svg")


def lu02_hp():
    s = Svg("Level Up · Hit Points")
    s.frame("Hit Points", "Level up · 2 of 4", PARTY_LU, "Take the fixed value or roll. The roll uses the game's seeded dice and is shown.")
    s.panel(40, 140, 760, 670, "FIGHTER LEVEL 4: d10")
    s.rect(300, 220, 240, 240, P["ink"], P["candle"], 3, rx=30)
    s.text(420, 365, "8", 96, P["wick"], "bold", anchor="middle", family=SERIF)
    s.text(420, 500, "rolled on a d10", 15, P["silver"], anchor="middle")
    s.button(120, 560, 260, 52, "Take 6 (fixed)")
    s.button(460, 560, 260, 52, "Roll the d10", primary=True, focus=True)
    s.lines(120, 680, ["Gain = roll (or 6) + Con modifier (+2), minimum 1.", "You can roll once; the result is final."], 15, P["silver"])
    s.callout(1, 780, 160)
    s.panel(820, 140, 740, 670, "HIT POINTS BEFORE → AFTER")
    s.text(850, 230, "34  →  44", 48, P["ivory"], "bold", family=SERIF)
    s.lines(850, 300, ["Level 1: Fighter d10 maximum 10", "Levels 2-3 at the fixed value: 12", "Level 4 rolled: 8",
                       "Con modifier +2 × 4 levels: 8", "Tough: 2 × level = 8"], 16, P["silver"], gap=32)
    s.status(850, 520, "info", "Changing Constitution later changes every level's Hit Points (retroactive).")
    s.status(850, 560, "info", "Current Hit Points rise by the same amount: 30/34 → 40/44.")
    s.callout(2, 1540, 160)
    s.save(OUT / "lu_02_hit_points.svg")


def lu03_choices():
    s = Svg("Level Up · Features and choices")
    s.frame("New features and choices", "Level up · 3 of 4", PARTY_LU, "Unavailable feats stay listed with the reason. Filter to hide them.")
    s.panel(40, 140, 420, 670, "NEW AT LEVEL 4")
    s.card(60, 196, 380, 120, "Ability Score Improvement", ["Take the Ability Score Improvement feat", "or any feat you qualify for."], selected=True)
    s.card(60, 330, 380, 104, "Weapon Mastery: 4th weapon", ["Pick one more weapon kind.", "Now: Greatsword, Flail, Javelin"], selected=False)
    s.status(60, 470, "error", "1 choice left: Weapon Mastery")
    s.callout(1, 440, 160)
    s.panel(476, 140, 620, 670, "FEATS")
    x = s.chip(496, 192, "General ▾", P["ink"], P["candle"])
    x = s.chip(x, 192, "Ability: any ▾")
    s.chip(x, 192, "☐ Only ones I qualify for")
    feats = [("Ability Score Improvement", "+2 to one or +1 to two (max 20)", None, True),
             ("Great Weapon Master", "+1 Str; heavy weapon hits add PB damage", None, False),
             ("Heavy Armor Master", "+1 Str/Con; reduce B/P/S damage by PB", None, False),
             ("Tough", "Hit Point maximum +2 per level", None, False),
             ("War Caster", "Advantage to keep Concentration …", "Requires the Spellcasting feature", False),
             ("Elemental Adept", "Spells ignore Resistance to one type", "Requires the Spellcasting feature", False),
             ("Inspiring Leader", "Temp HP to allies after a rest", "Requires Wisdom or Charisma 13", False)]
    y = 236
    for n, d, reason, sel in feats:
        h = 62 if reason else 50
        s.rect(492, y, 588, h - 6, P["stone"] if reason else (P["bruise"] if sel else P["ink"]),
               P["wick"] if sel else P["ash"], 3 if sel else 1, rx=4)
        s.text(508, y + 22, n, 14, P["pewter"] if reason else P["ivory"], "bold")
        s.text(760, y + 22, d, 12, P["silver"])
        if reason:
            s.text(508, y + 44, "⊘ " + reason, 12, P["rose"])
        y += h
    s.callout(2, 1076, 160)
    s.panel(1112, 140, 448, 670, "ABILITY SCORE IMPROVEMENT")
    s.chip(1132, 196, "+2 to one", P["ink"], P["candle"])
    s.chip(1240, 196, "+1 to two")
    abil = [("Strength", "17 → 19", True), ("Dexterity", "14", False), ("Constitution", "14", False),
            ("Intelligence", "8", False), ("Wisdom", "10", False), ("Charisma", "12", False)]
    y = 256
    for n, v, on in abil:
        s.rect(1132, y - 20, 408, 40, P["bruise"] if on else P["ink"], P["candle"] if on else P["ash"], 2 if on else 1, rx=4)
        s.text(1148, y + 6, n, 14, P["ivory"])
        s.text(1528, y + 6, v, 14, P["wick"] if on else P["silver"], "bold", anchor="end")
        y += 50
    s.lines(1132, 600, ["Strength 19: modifier +3 → +4", "Greatsword +5 → +6 to hit, damage +3 → +4",
                        "Athletics +5 → +6, Strength save +5 → +6"], 13, P["frost"], gap=24)
    s.save(OUT / "lu_03_features_and_choices.svg")


def lu03b_subclass():
    s = Svg("Level Up · Subclass browser")
    s.frame("Choose a Fighter subclass", "Level up · 3 of 4", PARTY_LU, "Compare subclasses through level 20 before you commit.")
    subs = [("Battle Master", ["3  Combat Superiority (4 d8 dice, 3 maneuvers)", "3  Student of War", "7  Know Your Enemy",
                               "10 Improved Combat Superiority (d10)", "15 Relentless", "18 Ultimate Combat Superiority (d12)"], False),
            ("Champion", ["3  Improved Critical (19-20)", "3  Remarkable Athlete", "7  Additional Fighting Style",
                          "10 Heroic Warrior", "15 Superior Critical (18-20)", "18 Survivor"], True),
            ("Eldritch Knight", ["3  Spellcasting (Wizard, Int)", "3  War Bond", "7  War Magic", "10 Eldritch Strike",
                                 "15 Arcane Charge", "18 Improved War Magic"], False),
            ("Psi Warrior", ["3  Psionic Power (4 d6 dice)", "7  Telekinetic Adept", "10 Guarded Mind",
                             "15 Bulwark of Force", "18 Telekinetic Master"], False)]
    x = 40
    for n, rows, sel in subs:
        s.card(x, 140, 368, 400, n, rows, selected=sel, focus=sel, tags=("complexity ●○○",) if n == "Champion" else ("●●○",))
        x += 384
    s.panel(40, 560, 1520, 250, "CHAMPION · WHAT CHANGES NOW")
    s.lines(64, 620, ["Critical Hits on 19 or 20 with weapons and Unarmed Strikes (from 5% to 10% of attacks).",
                      "Advantage on Initiative and Strength (Athletics) checks; move half your Speed after a Critical Hit.",
                      "Your sheet: Greatsword crit range 19-20 · Initiative +2 with Advantage · Athletics +5 with Advantage"], 15, P["silver"], gap=34)
    s.callout(1, 1540, 580)
    s.save(OUT / "lu_03b_subclass.svg")


def lu04_summary():
    s = Svg("Level Up · Summary")
    s.frame("Summary: Ilse, Fighter 3 → 4", "Level up · 4 of 4", PARTY_LU, "Nothing changes until you confirm.", next_label="Confirm ✓", next_focus=True)
    s.panel(40, 140, 900, 670, "BEFORE → AFTER (only what changed)")
    rows = [("Level", "Fighter (Champion) 3", "Fighter (Champion) 4"), ("Hit Point maximum", "34", "44"),
            ("Strength", "17", "19"), ("Strength save", "+5", "+6"), ("Athletics", "+5", "+6"),
            ("Greatsword", "+5 · 2d6+3", "+6 · 2d6+4"), ("Second Wind uses", "2", "3"), ("Weapon masteries", "3", "4 (+Spear)")]
    y = 210
    s.text(64, y - 14, "", 13)
    for label, a, b in rows:
        s.rect(56, y - 22, 868, 40, P["ink"], P["ash"], rx=4)
        s.text(72, y + 4, label, 15, P["silver"])
        s.text(560, y + 4, a, 15, P["pewter"], anchor="end")
        s.text(600, y + 4, "→", 15, P["candle"], anchor="middle")
        s.text(640, y + 4, b, 15, P["wick"], "bold")
        y += 48
    s.callout(1, 920, 160)
    s.panel(960, 140, 600, 670, "NEW FEATURES (full text)")
    s.parchment(980, 196, 560, 250, "Ability Score Improvement")
    s.lines(998, 252, ["+2 Strength (17 → 19).", "This feature returns at levels 6, 8, 12, 14 and 16."], 14, P["ink"])
    s.parchment(980, 462, 560, 200, "Weapon Mastery (4 kinds)")
    s.lines(998, 518, ["Added: Spear (Sap). Change one kind after any Long Rest."], 14, P["ink"])
    s.status(980, 720, "ok", "All choices made. Confirm applies the level.")
    s.save(OUT / "lu_04_summary.svg")


# ------------------------------------------------------------------------------------------------ inventory
def inv01_character():
    s = Svg("Inventory · Character")
    s.frame(None, "Inventory: Ilse", [("Ilse", "active"), ("Tamsin", ""), ("Hedda", ""), ("Silvain", "")],
            "Drag items onto a portrait to give them. X on a controller opens the item menu.", next_label="Done")
    s.panel(24, 80, 470, 730, "PAPER DOLL")
    slots = [("Head", 170, 120), ("Cloak", 30, 200), ("Neck", 316, 200), ("Armor: Chain Mail", 150, 270), ("Hands", 30, 360),
             ("Belt", 316, 360), ("Ring", 30, 450), ("Ring", 316, 450), ("Feet", 170, 540)]
    s.rect(180, 170, 140, 330, P["ash"], P["slate"], rx=50)
    for name, x, y in slots:
        filled = "Chain" in name
        s.rect(24 + x, y, 120 if not filled else 160, 56, P["bruise"] if filled else P["ink"], P["candle"] if filled else P["ash"], 2 if filled else 1, rx=4)
        s.text(34 + x, y + 33, name, 12, P["ivory"] if filled else P["pewter"])
    s.text(44, 640, "Weapon sets (quick swap: ↻)", 13, P["lilac"])
    s.rect(44, 652, 210, 60, P["bruise"], P["wick"], 3, rx=4)
    s.text(56, 678, "Set 1 ★ Greatsword", 13, P["ivory"], "bold")
    s.text(56, 700, "two-handed", 12, P["silver"])
    s.rect(266, 652, 210, 60, P["ink"], P["ash"], rx=4)
    s.text(278, 678, "Set 2  Javelin · —", 13, P["silver"])
    s.text(44, 750, "Ammunition: 20 Arrows · Focus: —", 12, P["silver"])
    s.callout(1, 474, 100)
    s.panel(508, 80, 600, 730, "BACKPACK")
    x = s.chip(524, 128, "All", P["ink"], P["candle"])
    for t in ["Weapons", "Armor", "Consumables", "Tools", "Quest", "Junk", "New"]:
        x = s.chip(x, 128, t)
    for label, hx in [("Item", 532), ("Qty", 760), ("Weight", 880), ("Value", 980)]:
        s.text(hx, 186, label, 13, P["lilac"], "bold")
    items = [("Longsword (found)", "1", "3 lb", "15 GP", "NEW", True), ("Potion of Healing", "2", "1 lb", "50 GP", "", False),
             ("Javelin", "8", "16 lb", "4 GP", "", False), ("Healer's Kit", "1 (10 uses)", "3 lb", "5 GP", "", False),
             ("Dungeoneer's Pack ▸", "1", "55 lb", "12 GP", "", False), ("Shortbow", "1", "2 lb", "25 GP", "", False),
             ("Arrows", "20", "1 lb", "1 GP", "", False), ("Locket (quest) 🔒", "1", "—", "—", "", False)]
    y = 214
    for n, q, w, v, tag, focus in items:
        s.rect(520, y - 18, 576, 34, P["bruise"] if focus else P["ink"], P["wick"] if focus else P["ash"], 3 if focus else 1, rx=3)
        s.text(532, y + 4, n, 13, P["ivory"])
        s.text(760, y + 4, q, 13, P["silver"])
        s.text(880, y + 4, w, 13, P["silver"])
        s.text(980, y + 4, v, 13, P["silver"])
        if tag:
            s.chip(1040, y - 12, tag, P["ink"], P["flame"])
        y += 42
    s.text(524, 600, "Carrying 112 / 255 lb  (Strength 17 × 15)", 13, P["silver"])
    s.rect(524, 612, 560, 16, P["ink"], P["ash"], rx=8)
    s.rect(524, 612, 246, 16, P["moss"], rx=8)
    s.text(524, 660, "Attunement  ◇ ◇ ◇  (0 of 3) · attune during a Short Rest", 13, P["silver"])
    s.text(524, 700, "Coins: 18 GP · 0 SP · 0 CP   [Convert ▾]", 13, P["silver"])
    s.callout(2, 1090, 100)
    s.parchment(1122, 80, 454, 730, "Longsword")
    s.lines(1140, 136, ["Martial Melee · Versatile (1d10) · 3 lb · 15 GP", "Mastery: Sap — you can't use it yet",
                        "", "With you:  +5 to hit · 1d10+3 two-handed", "Compared to Greatsword (equipped):",
                        "  average damage 8.5 vs 10.0   ▼ 1.5", "  frees a hand for a Shield? Shield: not owned",
                        "", "Not identified: no (mundane)"], 14, P["ink"])
    s.button(1140, 560, 200, 40, "Equip in Set 2")
    s.button(1356, 560, 200, 40, "Give to… ▾")
    s.button(1140, 616, 200, 40, "Mark as junk")
    s.button(1356, 616, 200, 40, "Drop")
    s.callout(3, 1556, 100)
    s.save(OUT / "inv_01_character.svg")


def inv02_loot():
    s = Svg("Inventory · Loot, stash and merchant")
    s.frame(None, "Loot: the Durst nursery chest", None, "Send items straight to whoever can carry them.", back=False, next_label="Close")
    s.panel(24, 90, 760, 720, "LOOT")
    s.button(44, 140, 170, 40, "Take all", primary=True)
    s.button(230, 140, 230, 40, "Send to who can carry")
    loot = [("Silver mirror (treasure)", "25 GP", "Tamsin"), ("Potion of Healing", "50 GP", "Hedda"),
            ("Toy wooden soldier", "—", "—"), ("Unidentified ring ✦", "?", "Silvain"), ("Rose's journal (Codex)", "—", "Codex")]
    y = 230
    for n, v, who in loot:
        s.rect(44, y - 22, 720, 44, P["ink"], P["ash"], rx=4)
        s.text(60, y + 4, n, 14, P["ivory"])
        s.text(420, y + 4, v, 13, P["silver"])
        s.text(560, y + 4, "→ " + who, 13, P["wick"])
        s.text(744, y + 4, "Take ▸", 13, P["candle"], anchor="end")
        y += 54
    s.status(44, 520, "info", "Books and letters go to the Codex, not the backpack.")
    s.status(44, 556, "warn", "Unidentified ring: Identify, or study it during a Short Rest.")
    s.status(44, 592, "info", "Overloaded characters are skipped by 'Send to who can carry'.")
    s.callout(1, 764, 110)
    s.panel(800, 90, 776, 720, "MERCHANT: BILDRATH'S MERCANTILE")
    s.text(820, 150, "Attitude: Indifferent · prices ×1.0     [Haggle: Persuasion DC 15 ▸]", 14, P["silver"])
    cols = [("BUY", [("Chain Mail", "75 GP"), ("Holy Water", "25 GP"), ("Lantern, Hooded", "5 GP"), ("Rations ×5", "2.5 GP")]),
            ("SELL", [("Toy wooden soldier", "1 SP"), ("Silver mirror", "12 GP"), ("Locket 🔒", "can't sell: quest item")])]
    x = 820
    for title, rows in cols:
        s.text(x, 200, title, 15, P["lilac"], "bold")
        y = 236
        for n, v in rows:
            locked = "can't" in v
            s.rect(x, y - 22, 360, 40, P["stone"] if locked else P["ink"], P["ash"], rx=4)
            s.text(x + 12, y + 4, n, 13, P["pewter"] if locked else P["ivory"])
            s.text(x + 348, y + 4, v, 12, P["rose"] if locked else P["silver"], anchor="end")
            y += 48
        x += 376
    s.button(820, 500, 260, 40, "Sell all junk (3)")
    s.text(820, 600, "Party stash (Blue Water Inn): available here ✓", 14, P["bile"])
    s.callout(2, 1556, 110)
    s.save(OUT / "inv_02_loot_and_merchant.svg")


# ------------------------------------------------------------------------------------------------ party
def pm01_overview():
    s = Svg("Party · Overview")
    s.frame(None, "Party overview", None, "Everyone here is yours to direct. Guests follow your orders in combat.", back=False, next_label="Close")
    chars = [("Ilse Varga", "Fighter 4", "40/44", "4/4 d10", "—", "Second Wind 3/3 · Action Surge 1/1", "—"),
             ("Tamsin Tealeaf", "Rogue 4", "18/32", "2/4 d8", "—", "Luck", "Poisoned (2 rounds)"),
             ("Hedda Ironvow", "Cleric 4", "35/35", "4/4 d8", "L1 ●●○○ L2 ●●●", "Channel Divinity 2/2", "—"),
             ("Silvain Aster", "Wizard 4", "26/26", "4/4 d6", "L1 ●●●● L2 ●●○", "Arcane Recovery 1/1", "Exhaustion 1")]
    x = 24
    for name, cls, hp, hd, slots, res, cond in chars:
        s.panel(x, 90, 300, 470)
        s.rect(x + 16, 110, 80, 100, P["ash"], P["slate"], rx=4)
        s.text(x + 108, 138, name, 16, P["ivory"], "bold", family=SERIF)
        s.text(x + 108, 160, cls, 13, P["silver"])
        cur, mx = [int(v) for v in hp.split("/")]
        s.text(x + 16, 250, "HP " + hp, 14, P["ivory"], "bold")
        s.rect(x + 16, 260, 268, 12, P["ink"], rx=6)
        s.rect(x + 16, 260, int(268 * cur / mx), 12, P["crimson"] if cur / mx <= 0.5 else P["moss"], rx=6)
        if cur / mx <= 0.5:
            s.text(x + 284, 250, "Bloodied", 12, P["rose"], anchor="end")
        s.lines(x + 16, 300, ["Hit Dice " + hd, "Slots " + slots, res, "Conditions: " + cond, "Attuned: ◇◇◇"], 13, P["silver"], gap=28)
        x += 314
    s.panel(1280, 90, 296, 470, "GUEST")
    s.rect(1296, 110, 80, 100, P["ash"], P["slate"], rx=4)
    s.text(1388, 138, "Ireena Kolyana", 15, P["ivory"], "bold", family=SERIF)
    s.lines(1296, 250, ["Directed by you in combat.", "Level and gear come from", "the story: no level-up or", "build choices."], 13, P["silver"], gap=24)
    s.callout(1, 1556, 110)
    s.panel(24, 576, 1552, 234, "PARTY SKILLS (best in each, Expertise ★)")
    sk = [("Acrobatics", "Tamsin +6"), ("Arcana", "Silvain +8 ★"), ("Athletics", "Ilse +6"), ("Deception", "Tamsin +1"),
          ("History", "Silvain +6"), ("Insight", "Hedda +6"), ("Intimidation", "Ilse +3"), ("Investigation", "Tamsin +4"),
          ("Medicine", "Hedda +6"), ("Nature", "Silvain +4"), ("Perception", "Silvain +4"), ("Persuasion", "Hedda +3"),
          ("Religion", "Hedda +2"), ("Sleight of Hand", "Tamsin +8 ★"), ("Stealth", "Tamsin +8 ★"), ("Survival", "Ilse +2")]
    for i, (a, b) in enumerate(sk):
        x = 44 + (i % 4) * 384
        y = 630 + (i // 4) * 40
        s.text(x, y, a, 14, P["silver"])
        s.text(x + 340, y, b, 14, P["ivory"], "bold", anchor="end")
    s.save(OUT / "pm_01_overview.svg")


def pm02_sheet():
    s = Svg("Party · Character sheet")
    s.frame(None, "Character sheet: Hedda Ironvow", [("Ilse", ""), ("Tamsin", ""), ("Hedda", "active"), ("Silvain", "")],
            "LB / RB switch tabs · LT / RT switch character.", back=True, next_label="Close")
    tabs = ["Overview", "Abilities & Skills", "Features & Traits", "Spells", "Inventory", "Active Effects", "Notes"]
    x = 24
    for t in tabs:
        on = t == "Active Effects"
        w = 30 + 9 * len(t)
        s.rect(x, 80, w, 40, P["bruise"] if on else P["ink"], P["candle"] if on else P["ash"], 2 if on else 1, rx=4)
        s.text(x + w / 2, 106, t, 14, P["ivory"], "bold" if on else "normal", anchor="middle")
        x += w + 8
    s.panel(24, 136, 1000, 674, "ACTIVE EFFECTS (every condition, spell and item, with its source)")
    eff = [("Bless", "Hedda (Concentration)", "+1d4 to attack rolls and saves", "8 rounds"),
           ("Shield of Faith", "—", "ended: Concentration moved to Bless", "—"),
           ("Dwarven Resilience", "Species: Dwarf", "Resistance to Poison; Advantage vs Poisoned", "always"),
           ("Exhaustion 1", "Forced march", "D20 Tests −2, Speed −5 ft", "until a Long Rest"),
           ("Strahd's charm (lingering)", "Story", "Disadvantage on saves against Strahd", "until broken")]
    y = 200
    s.text(44, y - 14 + 4, "", 12)
    for n, src, eff_text, dur in eff:
        ended = src == "—"
        s.rect(40, y - 20, 968, 64, P["stone"] if ended else P["ink"], P["ash"], rx=4)
        s.text(56, y + 4, n, 15, P["pewter"] if ended else P["ivory"], "bold")
        s.text(56, y + 28, eff_text, 13, P["silver"])
        s.text(600, y + 4, src, 13, P["lilac"])
        s.text(992, y + 4, dur, 13, P["wick"], anchor="end")
        y += 76
    s.callout(1, 1004, 156)
    s.panel(1040, 136, 536, 674, "OVERVIEW (other tab) · numbers explain on focus")
    s.lines(1060, 206, ["AC 14   HP 35/35   Speed 30 ft   Init −1", "Spell save DC 14 · Spell attack +6",
                        "Slots: L1 ●●●● · L2 ●●●", "Channel Divinity ●● (one back on a Short Rest)",
                        "Prepared 7 + domain 4 (★)"], 14, P["silver"], gap=30)
    s.tooltip(1060, 380, 496, "Spell save DC 14", ["Base 8", "Wisdom modifier +4", "Proficiency Bonus +2"])
    s.tooltip(1060, 540, 496, "Hit Points 35", ["Level 1: Cleric d8 maximum 8", "3 levels at the fixed value 15",
                                                "Con modifier +2 × 4 levels 8", "Dwarven Toughness +4"])
    s.save(OUT / "pm_02_sheet.svg")


def pm03_formation_rest():
    s = Svg("Party · Formation and rests")
    s.frame(None, "Marching order and rests", None, "Order matters for traps and surprise. The leader walks first.", back=False, next_label="Close")
    s.panel(24, 90, 560, 720, "MARCHING ORDER & FORMATION")
    order = [("1  Ilse (leader ★)", "Passive Perception 12"), ("2  Tamsin", "Passive Perception 12 · Stealth +8"),
             ("3  Hedda", "Darkvision 120 ft"), ("4  Silvain", "Darkvision 60 ft"), ("Guest  Ireena", "follows Hedda")]
    y = 160
    for n, d in order:
        s.rect(44, y - 24, 520, 56, P["bruise"] if "★" in n else P["ink"], P["candle"] if "★" in n else P["ash"], 2 if "★" in n else 1, rx=4)
        s.text(60, y, n, 15, P["ivory"], "bold")
        s.text(60, y + 22, d, 12, P["silver"])
        y += 70
    s.text(44, 540, "Formation", 14, P["lilac"])
    for i, f in enumerate(["Column", "Pairs", "Wedge", "Spread"]):
        s.button(44 + i * 132, 556, 120, 36, f, primary=i == 0)
    s.status(44, 640, "warn", "Silvain at the back has the best passive Perception (14):", 12)
    s.text(70, 660, "traps are spotted by the front rank. Swap?", 12, P["flame"])
    s.callout(1, 564, 110)
    s.panel(600, 90, 480, 720, "SHORT REST (1 hour)")
    rows = [("Ilse", "HD 4/4 d10", "40/44", "Second Wind +1, Action Surge ✓"),
            ("Tamsin", "HD 2/4 d8", "18/32", "—"),
            ("Hedda", "HD 4/4 d8", "35/35", "Channel Divinity +1"),
            ("Silvain", "HD 4/4 d6", "26/26", "Arcane Recovery: 2 slot levels")]
    y = 160
    for n, hd, hp, back in rows:
        s.rect(620, y - 24, 440, 110, P["ink"], P["ash"], rx=4)
        s.text(636, y, n + "   " + hp, 15, P["ivory"], "bold")
        s.text(636, y + 22, hd, 12, P["silver"])
        s.text(636, y + 44, "Back on finishing: " + back, 12, P["frost"])
        if n == "Tamsin":
            s.button(900, y - 10, 140, 34, "Spend d8 ⚄", primary=True, focus=True)
            s.text(900, y + 46, "rolled 5 + Con 2 = +7", 12, P["wick"])
        y += 124
    s.callout(2, 1060, 110)
    s.panel(1096, 90, 480, 720, "LONG REST (8 hours, camp)")
    s.lines(1116, 156, ["Risk of interruption tonight: High", "(Svalich Woods at night, wolves heard)", "",
                        "Watches: Ilse ▸ Tamsin ▸ Hedda ▸ Silvain", "", "On finishing:", "• All HP and Hit Point Dice back",
                        "• Spell slots and features refresh", "• Exhaustion −1 (Silvain)", "• Then: prepare spells ▸"],
            14, P["silver"], gap=28)
    s.button(1116, 720, 200, 40, "Make camp", primary=True)
    s.save(OUT / "pm_03_formation_and_rests.svg")


def pm04_prepare():
    s = Svg("Party · Spell preparation")
    s.frame(None, "Prepare spells: Hedda (after a Long Rest)", [("Ilse", ""), ("Tamsin", ""), ("Hedda", "active"), ("Silvain", "")],
            "Domain spells (★) are always prepared and don't count.", next_label="Done")
    s.panel(24, 90, 760, 720, "CLERIC SPELLS YOU CAN PREPARE · 7 of 7")
    rows = [("★ Bless", "domain"), ("★ Cure Wounds", "domain"), ("★ Aid", "domain"), ("★ Lesser Restoration", "domain"),
            ("☑ Guiding Bolt", ""), ("☑ Healing Word", ""), ("☑ Shield of Faith", ""), ("☑ Command", ""),
            ("☑ Spiritual Weapon", ""), ("☑ Hold Person", ""), ("☑ Detect Magic", "R"), ("☐ Silence", "C, R"), ("☐ Spirit Guardians", "needs level 3 slots")]
    y = 150
    for n, note in rows:
        dis = "needs" in note
        s.rect(44, y - 20, 720, 38, P["stone"] if dis else P["ink"], P["ash"], rx=3)
        s.text(60, y + 4, n, 14, P["wick"] if n.startswith("★") else (P["pewter"] if dis else P["ivory"]))
        s.text(744, y + 4, ("⊘ " if dis else "") + note, 12, P["rose"] if dis else P["silver"], anchor="end")
        y += 44
    s.callout(1, 764, 110)
    s.panel(800, 90, 776, 720, "LOADOUTS")
    for i, (n, d) in enumerate([("Exploring", "Detect Magic, Command, …"), ("Dungeon crawl", "Spiritual Weapon, Hold Person, …"),
                                ("Undead hunt", "Guiding Bolt, Spirit Guardians later, …")]):
        s.card(820, 150 + i * 110, 736, 96, n, [d], selected=i == 1)
    s.button(820, 500, 220, 40, "Save current as…")
    s.status(820, 600, "info", "Rituals marked R can also be cast without preparing? Cleric: no (prepared only).")
    s.status(820, 640, "info", "Wizards prepare from their spellbook and can cast its Rituals unprepared.")
    s.callout(2, 1556, 110)
    s.save(OUT / "pm_04_spell_preparation.svg")


ALL = [cc01_start, cc02_class, cc03_origin, cc04_abilities, cc05_choices, cc05b_spells, cc06_equipment, cc07_appearance,
       cc08_identity, cc09_review, cc10_explain, lu01_class, lu02_hp, lu03_choices, lu03b_subclass, lu04_summary,
       inv01_character, inv02_loot, pm01_overview, pm02_sheet, pm03_formation_rest, pm04_prepare]

if __name__ == "__main__":
    for f in ALL:
        f()
    print(f"{len(ALL)} wireframes written to {OUT}")
