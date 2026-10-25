#!/usr/bin/env python3
"""XP mode level simulator for the Curse of Strahd game (plan validation only).

Reads the game's real fight data (data/locations encounters with their level variants, data/monsters XP,
data/random_encounters, data/camp/night_visitors.json) and walks a party through the campaign stage by stage,
for five player types (minimal, average, thorough, fighter, explorer), comparing the XP-mode level with the milestone level the
fights are tuned for at each story gate.

Usage: python3 tools/balance/xp_sim.py <repo> [--runs N] [--route six|all|alt] [--rules plan|build|literal|plain|noguard|nofloor]
                                          [--grind N] [--set monster_mult=0.45 ...]
       python3 tools/balance/xp_sim.py <repo> --tables [--rules build]   (the validation tables, under a minute; `make xp-sim`)
Rules: `plan` is the plan's model as validated (docs/plans/xp_mode.md §5); `build` is what story/xp.gd does, the milestone's
High award paid at every beat with a climax quest's ending not paid twice (the plan's Build notes); `literal` pays both.
"""
import json, glob, re, random, sys, statistics, collections, argparse, os

# ---------------------------------------------------------------- 2024 rules
# 2024 PHB (Free Rules, Character Advancement): XP to reach each level.
THRESH = [0, 0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000, 85000, 100000, 120000]
# 2024 DMG XP Budget per Character (Low, Moderate, High) by level.
BUDGET = {1: (50, 75, 100), 2: (100, 150, 200), 3: (150, 225, 400), 4: (250, 375, 500), 5: (500, 750, 1100),
          6: (600, 1000, 1400), 7: (750, 1300, 1700), 8: (1000, 1700, 2100), 9: (1300, 2000, 2600),
          10: (1600, 2300, 3100), 11: (1900, 2900, 4100), 12: (2200, 3700, 4700)}
CAP = 11
PARTY = 4


def level_for(xp):
    lv = 1
    for L in range(2, CAP + 1):
        if xp >= THRESH[L]:
            lv = L
    return lv


def frac_level(xp):
    lv = level_for(xp)
    if lv >= CAP:
        return float(CAP)
    return lv + (xp - THRESH[lv]) / (THRESH[lv + 1] - THRESH[lv])


# ---------------------------------------------------------------- data
class Data:
    def __init__(self, repo):
        self.ms = {}
        for f in glob.glob(os.path.join(repo, 'data/monsters/*.json')) + glob.glob(os.path.join(repo, 'addons/dnd_core/data/monsters/*.json')):
            d = json.load(open(f))
            self.ms[d['id']] = d
        self.groups = collections.defaultdict(list)   # encounter id -> [(when, xp)] in data order
        for f in sorted(glob.glob(os.path.join(repo, 'data/locations/*.json'))):
            l = json.load(open(f))
            for e in l.get('encounters', []):
                xp = sum(self.ms[m['monster']]['xp'] for m in e['monsters'] if m.get('side', 'enemy') == 'enemy')
                self.groups[e['id']].append((e.get('when', ''), xp))
        self.tables = {}
        for f in glob.glob(os.path.join(repo, 'data/random_encounters/*.json')):
            d = json.load(open(f))
            self.tables[d['id']] = d
        nv = json.load(open(os.path.join(repo, 'data/camp/night_visitors.json')))
        self.visitors = nv['groups']

    def mxp(self, mons):
        tot = 0
        for m in mons:
            mid = m['monster'] if isinstance(m, dict) else m
            tot += self.ms[mid]['xp']
        return tot


def cond(when, level, night=False, flags=None, items=('sunsword',)):
    """Evaluates an encounter `when` for a modelled party: level and day/night real, flags as given (default unset)."""
    if not when.strip():
        return True
    flags = flags or {}
    s = when
    s = re.sub(r'\(([^()]*?)\)', lambda m: '(' + m.group(1) + ')', s)
    def flag_cmp(m):
        name, op, val = m.group(1), m.group(2), m.group(3)
        return repr(flags.get(name, '')) + ' ' + op + ' ' + val
    s = re.sub(r'flag\.([a-z_0-9]+)\s*(==|!=)\s*("[^"]*")', flag_cmp, s)
    s = re.sub(r'flag\.([a-z_0-9]+)\s*(>=|<=|>|<)\s*(\d+)', lambda m: repr(flags.get(m.group(1), 0) or 0) + m.group(2) + m.group(3), s)
    s = re.sub(r'flag\.([a-z_0-9]+)', lambda m: repr(bool(flags.get(m.group(1), False))), s)
    s = re.sub(r'quest\.[a-z_0-9]+\s*(>=|<=|==|!=)\s*[a-z_0-9]+', 'False', s)
    s = re.sub(r'item:([a-z_0-9]+)', lambda m: repr(m.group(1) in items), s)
    s = re.sub(r'(guest|name|final_room|visited):[a-z_0-9]+', 'False', s)
    s = re.sub(r'attention\s*>=\s*[a-z]+', 'False', s)
    s = re.sub(r'\blevel\b', str(level), s)
    s = re.sub(r'\bnight\b', repr(night), s)
    s = re.sub(r'\bday\b', repr(not night), s)
    return bool(eval(s, {'__builtins__': {}}, {}))


def fight_xp(data, gid, level, night=False, flags=None):
    vs = data.groups[gid]
    for w, xp in vs:
        if cond(w, level, night, flags):
            return xp
    return vs[-1][1]


# ---------------------------------------------------------------- the campaign model
# p = (minimal, average, thorough): the chance the profile meets that fight or does that thing.
# Stage content is listed in the order a party meets it, so a level-up mid-stage changes later fights' variants.

def F(gid, p, night=False, flags=None, note=''):
    return ('fight', gid, p, night, flags or {}, note)

def Q(kind, n, note=''):          # quests completed: n = (min, avg, full)
    return ('quest', kind, n, note)

def X(kind, n):                   # exploration counts: place, area, find, check, trap, lore
    return ('explore', kind, n)

def R(table, legs, night_share):  # road legs travelled: legs = (min, avg, full)
    return ('road', table, legs, night_share)

def N(land, n):                   # interrupted camp nights
    return ('camp', land, n)

def S(kind, note=''):             # Strahd's harassment fights (not CR XP: a High award)
    return ('strahd', kind, note)

def M(note):
    return ('milestone', note)

ALL = (1, 1, 1)
CRIT = (1, 1, 1)
SIDE = (0, .5, 1)      # a side quest's fights: half the average players do it
OPT = (0, .6, 1)       # an optional room or fight on the way
CHOICE = (.5, .5, .5)  # a fight that comes from a choice either way

STAGES = {}

STAGES['mists'] = dict(name='Into the Mists (L1)', items=[
    X('place', (1, 1, 1)), X('location', (1, 1, 1)),
    F('mists_wolves', (.5, .5, 1), note='failed check or draw steel'),
    F('ilarion_wolves', SIDE, note='The Last Traveller'), Q('side', (0, .5, 1)),
    X('find', (0, 3, 5)), X('check', (1, 3, 4)), X('trap', (0, 1, 1)),
])

STAGES['dh_up'] = dict(name='Death House, above ground (L1)', items=[
    X('place', (1, 1, 1)), X('location', (4, 4, 4)), X('find', (2, 5, 7)), X('lore', (1, 3, 5)),
    X('check', (2, 5, 8)), X('trap', (0, 1, 2)),
    F('armor_guardian', CRIT), F('storage_broom', OPT), F('nursery_specter', (0, .5, 1), note='avoidable'),
    M('Death House: the hidden stair (L2)'),
])

STAGES['dh_down'] = dict(name='Death House, the dungeon (L2)', items=[
    X('location', (2, 2, 2)), X('find', (2, 4, 7)), X('check', (2, 5, 8)), X('trap', (1, 1, 1)),
    F('passage_ghouls', (0, .7, 1)), F('shrine_shadows', (0, .5, 1)), F('crypt_insects', (0, .5, 1)),
    F('larder_grick', (0, .5, 1)), F('den_mimic', (0, .5, 1)), F('durst_reunion', (0, .6, 1)),
    F('lorghoth_rises', (0, .15, 1), note='only by choice'),
    F('shades_harry', (.2, .2, .2), note='failed run'),
    Q('mmain', (1, 1, 1), 'Death House'), Q('side', (0, .5, 1), 'Rose and Thorn'),
    M('Death House: altar or escape (L3)'),
])

STAGES['village'] = dict(name='Village of Barovia (L3)', items=[
    X('place', (1, 2, 3)), X('location', (4, 7, 8)), X('find', (3, 7, 11)), X('lore', (2, 4, 7)),
    X('check', (4, 10, 17)),
    F('night_streets_dead', (.3, .5, 1), night=True, flags={'ismark_met': True}), F('doru_undercroft', (.4, .6, 1)),
    F('mansion_siege', (0, .5, 1), night=True),
    F('pasture_wolves', SIDE), F('hound_tenant', SIDE), F('oat_hunters', SIDE), F('teodor_errand', SIDE),
    F('woodpile_wakes', SIDE), F('well_bride', SIDE), F('nursemaid_keepers', SIDE),
    Q('side', (0, 4, 8), 'eight village side quests'),
    F('churchyard_dead', (.5, .5, 1)),
    Q('mmain', (1, 1, 1), 'Bury the Burgomaster'), Q('main', (0, .5, 1), 'Escort Ireena'), N('village_of_barovia', (0, .3, .5)),
    M('the burial (L4)'),
])

STAGES['road'] = dict(name='Old Svalich Road and Tser Pool (L4)', items=[
    X('place', (2, 4, 5)), X('location', (4, 9, 15)), X('find', (4, 12, 21)), X('check', (4, 10, 17)),
    R('svalich_road', (2, 4, 6), .25), R('svalich_woods', (1, 3, 5), .25),
    F('road_hunters', (0, .3, 1), note='a road meeting; talkable'),
    F('road_dead_procession', (0, .2, 1), night=True, note='a road meeting; hide or turn'),
    F('tser_pool_brawl', (0, .2, .2)),
    F('falls_werewolf', (0, .3, 1), night=True),
    F('carriage_escort', SIDE), F('falls_wisps', SIDE), F('den_blights', SIDE), F('gully_spiders', SIDE),
    F('roadhouse_cellar', SIDE),
    Q('main', (1, 1, 1), "Madam Eva's reading"), Q('side', (0, 2.5, 5), 'five road side quests'),
    N('svalich_road', (0, .3, .5)),
])

STAGES['vallaki'] = dict(name='Vallaki (L4 to 5)', items=[
    X('place', (1, 1, 1)), X('location', (4, 8, 10)), X('find', (4, 9, 15)), X('lore', (3, 7, 12)),
    X('check', (6, 15, 30)), X('trap', (0, 0, 1)),
    F('storeroom_spawn', (.5, .5, .5), note='the bones by day'), F('church_siege', (.5, .5, .5), night=True, note='or the vigil'),
    Q('climax', (1, 1, 1), 'St. Andral\'s bones'),
    M('Vallaki: the bones or the festival (L5)'),
    F('stella_shadow', SIDE), F('roses_street', SIDE), F('roses_graves', SIDE),
    F('ribbons_street', SIDE), F('ribbons_gate', SIDE), F('izek_duel', (0, .3, 1)),
    F('wachter_cellar_cult', (0, .4, 1), night=True), F('lantern_girl', SIDE), F('reed_isle_boatmen', SIDE),
    F('crossroads_hanged_dead', SIDE, night=True), F('tinkers_wagon', SIDE),
    R('zarovich_shore', (0, 2, 4), .25), R('svalich_road', (0, 2, 4), .25), R('svalich_woods', (0, 2, 4), .25),
    Q('side', (0, 5, 11), 'Vallaki and crossroads side quests at level 5'),
    F('festival_coup', (.34, .34, .34)), F('festival_loyalists', (.33, .33, .33)), F('festival_izek_rampage', (.33, .33, .33)),
    Q('main', (1, 1, 1), 'the Festival'), Q('main', (0, .5, 1), 'Sanctuary for Ireena'),
    N('town', (0, .3, .5)),
])

STAGES['ob'] = dict(name='Old Bonegrinder (L5 to 6)', items=[
    X('place', (1, 2, 2)), X('location', (3, 4, 4)), X('find', (4, 8, 12)), X('check', (2, 4, 6)), X('trap', (0, 1, 1)),
    R('svalich_road', (2, 2, 2), .25), R('svalich_woods', (2, 2, 2), .25), R('bonegrinder_lane', (2, 2, 4), .25),
    F('bakery_offalia', (.5, .8, 1)), F('coven_last_stand', (.5, .7, 1)),
    Q('climax', (1, 1, 1), 'the children freed'), Q('side', (0, .3, .6), 'a companion quest completed'),
    M('Old Bonegrinder (+1)'),
    F('granny_ash', SIDE), F('greytooth_hunt', SIDE), F('raven_trap', SIDE),
    Q('side', (0, 1.5, 3), 'Fourth Sister, Hunters at the Inn, Ravens\' Ransom'),
    N('old_bonegrinder', (0, .3, .5)),
])

STAGES['wow'] = dict(name='Wizard of Wines and Yester Hill (L6 to 7)', items=[
    X('place', (2, 2, 2)), X('location', (4, 5, 6)), X('find', (5, 10, 13)), X('lore', (1, 2, 3)), X('check', (3, 5, 7)),
    R('vineyard_road', (4, 4, 6), .25),
    F('vineyard_ambush', CRIT), F('winery_occupation', CRIT), F('cellar_dig', (.5, .8, 1)), F('press_house_mash', CRIT),
    F('vine_mother', SIDE), F('wardens_camp_fight', (0, .5, 1)),
    F('summit_ritual', CRIT),
    Q('climax', (1, 1, 1), 'the winery reclaimed and Yester Hill broken'),
    Q('main', (1, 1, 1), 'a Tarokka treasure'), Q('side', (0, .3, .6), 'a companion quest completed'),
    M('Wizard of Wines (+1)'),
    F('hill_watch', SIDE), F('bone_marshal', SIDE),
    Q('side', (0, 2.5, 5), 'Black Row, Elvir, Third Stone, Barrow, Last Muster'),
    N('wizard_of_wines', (0, .3, .5)),
])

STAGES['krezk'] = dict(name='Krezk and the Abbey (L7 to 8)', items=[
    X('place', (2, 3, 4)), X('location', (4, 7, 8)), X('find', (5, 12, 17)), X('lore', (0, 1, 2)), X('check', (5, 12, 20)),
    R('krezk_road', (2, 2, 4), .25),
    F('gate_wolves', (0, .3, 1), night=True), F('garden_sentry', (0, .6, 1)), F('wards_cells', (0, .3, 1)),
    F('sorin_pursuers', SIDE), F('waystone_wolves', SIDE), F('grandsire', SIDE), F('ash_effigy', SIDE),
    F('bride_defends', (.5, .5, 1)), F('abbot_wrath', (0, .15, .15)),
    Q('climax', (1, 1, 1), "the Abbot's bride"),
    Q('main', (1, 1, 1), 'a Tarokka treasure'), Q('side', (0, .3, .6), 'a companion quest completed'),
    Q('side', (0, 4, 9), 'eight Krezk side quests, the druid who came back'),
    M('Krezk (+1)'),
    N('abbey_of_st_markovia', (0, .3, .5)),
])

STAGES['den'] = dict(name="Van Richten's Tower, the Werewolf Den, Lake Zarovich (L8 to 9)", items=[
    X('place', (3, 5, 6)), X('location', (4, 8, 10)), X('find', (6, 14, 18)), X('lore', (2, 4, 5)), X('check', (4, 10, 18)),
    X('trap', (0, 1, 2)),
    R('zarovich_shore', (1, 2, 3), .25), R('zarovich_hills', (2, 3, 5), .25),
    F('tower_night_visitors', (0, .5, 1), night=True, flags={'van_richten_notes_read': True}), F('den_guards', (.5, .6, 1)),
    F('ward_wolves', (0, .3, 1), note='the tower door touched before its riddle (V1)'),
    F('pack_challenge', (.5, .7, 1)), F('den_reckoning', (0, .2, .2)),
    Q('climax', (1, 1, 1), 'the pack settled'),
    Q('main', (1, 1, 1), 'a Tarokka treasure'), Q('side', (0, .3, .6), 'a companion quest completed'),
    M('Werewolf Den (+1)'),
    F('drowned_landing', SIDE), F('the_index', SIDE), F('remembered', (0, .3, 1)), F('khazan_named', (0, .3, 1)),
    F('the_hunt', SIDE, night=True),
    Q('side', (0, 3, 6), 'tower, library, name over the door, bell, huntsman, stolen children'),
    N('van_richtens_tower', (0, .3, .5)),
])

STAGES['argyn'] = dict(name='Argynvostholt (L8 to 9)', items=[
    X('place', (1, 1, 1)), X('location', (3, 5, 6)), X('find', (4, 7, 9)), X('lore', (2, 4, 5)), X('check', (4, 8, 13)),
    R('argynvostholt_road', (2, 2, 4), .3),
    F('courtyard_phantoms', (0, .4, 1), night=True, flags={'godfrey_met': True}), F('lamp_dark', CRIT), F('bone_watch', (0, .3, 1)),
    F('ballroom_colony', OPT), F('chapel_revenants', (0, .3, .6), night=True),
    F('vladimir_duel', (0, .3, 1)), F('beacon_stand', (.2, .2, .2)),
    Q('climax', (1, 1, 1), 'the beacon lit'), Q('side', (0, .3, .6), 'a companion quest completed'),
    M('Argynvostholt (+1)'),
    F('squires_vigil', SIDE), F('gilded_knight', SIDE),
    Q('side', (0, 1.5, 3), 'Order, Silver Hoard, Squire'),
    N('argynvostholt', (0, .3, .5)),
])

STAGES['berez'] = dict(name='Berez, Mount Baratok, the Tsolenka Pass (L9 to 10)', items=[
    X('place', (3, 5, 7)), X('location', (6, 11, 16)), X('find', (8, 15, 20)), X('lore', (1, 2, 3)), X('check', (6, 15, 25)),
    R('berez_marsh', (2, 2, 4), .3), R('baratok_slopes', (2, 3, 5), .3),
    F('berez_scarecrows', (.5, .7, 1)), F('berez_drowned_lights', (0, .3, 1), night=True),
    F('lysaga_in_hut', CRIT),
    Q('climax', (1, 1, 1), 'the witch of Berez'),
    Q('main', (1, 1, 1), 'the Tarokka ally'), Q('side', (0, .3, .6), 'a companion quest completed'),
    M('Berez (+1)'),
    F('tsolenka_watch', CRIT), F('roc_of_ghakis', (.3, .5, 1)), F('the_penitent', (0, .3, 1)),
    F('rag_queen', SIDE), F('forgotten_storm', SIDE), F('last_egg', SIDE),
    F('ghakis_keepers', (0, .25, 1)), F('sarkhaza', (0, .25, 1)), F('grandfather_stone', (0, .25, 1)),
    F('counts_likeness', SIDE),
    Q('side', (0, 4, 9), 'Billy, Storm, Mad Mage, Pages, Pilgrims, Egg, Gate, Ghakis x2, Portraitist'),
    N('berez', (0, .3, .5)),
])

STAGES['amber'] = dict(name='The Amber Temple (L10 to 11)', items=[
    X('place', (2, 2, 2)), X('location', (5, 6, 7)), X('find', (5, 8, 10)), X('lore', (1, 2, 3)), X('check', (8, 18, 30)),
    X('trap', (1, 3, 6)),
    R('amber_temple_road', (2, 2, 3), .3),
    F('amber_guide', (0, .2, .2)), F('sentinel_wakes', (.2, .3, 1)), F('frozen_watch', (0, .6, 1)),
    F('hollow_eyed', (.3, .7, 1)), F('library_wardens', (0, .5, 1)), F('vault_guardian', (0, .4, 1)),
    F('patrina_wails', SIDE), F('dreamed_eyes', (0, .3, 1)), F('the_eye_below', (0, .3, 1)),
    F('vosk_unmasked', (.5, .6, 1)),
    Q('climax', (1, 1, 1), 'the revelation'), Q('side', (0, .3, .6), 'a companion quest completed'),
    Q('side', (0, 2, 4), 'Patrina, Lid, Amber Debt, Guide'),
    M('Amber Temple (+1, the cap)'),
])

STAGES['castle'] = dict(name='Castle Ravenloft (no milestone; tuned for 10)', items=[
    X('place', (1, 1, 1)), X('location', (6, 12, 17)), X('find', (5, 10, 15)), X('check', (8, 20, 32)), X('trap', (1, 4, 9)),
    R('svalich_woods', (1, 1, 1), .3),
    F('crg_dinner_affront', (0, .3, .3)), F('larders_guardroom', (0, .5, 1)), F('court_rahadin_fight', (0, .5, 1)),
    F('court_brides_fight', (0, .5, 1)), F('heart_guardians', (0, .5, 1)), F('corvina', (0, .3, 1)),
    Q('side', (0, 3, 6), 'castle side quests'), Q('side', (1, 2, 3), 'companion quests completed'),
    F('crg_overlook_final_battle', CRIT),
    Q('main', (1, 1, 1), "Strahd's end"),
])

ROUTES = {
    # every region, in the order the region docs' arrival levels imply
    'all': ['mists', 'dh_up', 'dh_down', 'village', 'road', 'vallaki', 'ob', 'wow', 'krezk', 'den', 'argyn', 'berez', 'amber', 'castle'],
    # the docs' intended pace: one of the knights' or the wolves' regions skipped
    'six': ['mists', 'dh_up', 'dh_down', 'village', 'road', 'vallaki', 'ob', 'wow', 'krezk', 'den', 'berez', 'amber', 'castle'],
    # a different order: the wolves and the knights before Krezk and the winery
    'alt': ['mists', 'dh_up', 'dh_down', 'village', 'road', 'vallaki', 'den', 'ob', 'argyn', 'wow', 'krezk', 'berez', 'amber', 'castle'],
}


# ---------------------------------------------------------------- awards
class Rules:
    """How much each source gives, per hero (XP is one shared pool: each hero's share of a party of four).

    monster_ref: 'actual' = the stat blocks of the version the party met; 'story' = the version the milestone level
    would meet (no reward for running ahead); 'budget' = actual, scaled by High(story)/High(party).
    quest: kind -> (DMG budget column at the party's level, multiple).
    explore: kind -> multiple of the Low budget at the party's level.
    floor: a story milestone lifts XP to at least the milestone level's threshold.
    ceiling: XP can't reach two levels past the milestone level; one-time XP over it is banked for the next
    milestone, repeatable XP (road, camp, Strahd's hunts) over it is lost.
    """
    PRESETS = {
        'plain': dict(monster_mult=1.0, monster_ref='actual', floor=False, ceiling=False,
                      quest={'climax': ('high', 1.0), 'main': ('high', 1.0), 'mmain': ('high', 1.0), 'side': ('low', 1.0)},
                      explore={'place': 1.0, 'location': 0, 'find': 0, 'check': 0, 'trap': 0, 'lore': 0}),
        'plan': dict(monster_mult=0.4, quest={'climax': ('high', 1.0), 'main': ('mod', 1.0), 'mmain': ('mod', 1.0), 'side': ('low', 0.5)}),
        # The plan's text taken literally: High at every beat AND the climax quest's own award on top. Drifts +0.3 levels
        # ahead of the milestones by mid-game (see docs/plans/xp_mode.md, Build notes).
        'literal': dict(monster_mult=0.4, milestone_high=True, quest={'climax': ('low', 0.5), 'main': ('mod', 1.0), 'mmain': ('mod', 1.0), 'side': ('low', 0.5)}),
        # What story/xp.gd does (data/progression/xp.json): every region milestone beat pays High, and the climax quest whose
        # ending it is ('climax', and the main quests 'mmain' that end at one: Death House, the burial) is paid by the
        # milestone, not twice. Re-run with --tables --rules build.
        'build': dict(monster_mult=0.4, milestone_high=True, quest={'climax': ('low', 0.0), 'main': ('mod', 1.0), 'mmain': ('mod', 0.0), 'side': ('low', 0.5)}),
        'nofloor': dict(monster_mult=0.4, floor=False, quest={'climax': ('high', 1.0), 'main': ('mod', 1.0), 'mmain': ('mod', 1.0), 'side': ('low', 0.5)}),
        'noguard': dict(monster_mult=0.4, floor=False, ceiling=False, quest={'climax': ('high', 1.0), 'main': ('mod', 1.0), 'mmain': ('mod', 1.0), 'side': ('low', 0.5)}),
    }

    def __init__(self, name, **kw):
        self.name = name
        self.monster_mult = 1.0
        self.monster_ref = 'actual'
        self.quest = {'climax': ('high', 1.0), 'main': ('high', 1.0), 'mmain': ('high', 1.0), 'side': ('low', 1.0)}
        self.explore = {'place': .5, 'location': .1, 'find': .05, 'check': .05, 'trap': .1, 'lore': .025}
        self.floor = True
        self.ceiling = True
        self.milestone_high = False
        self.__dict__.update(self.PRESETS.get(name, {}))
        self.__dict__.update(kw)


def budget(level, col):
    lo, mo, hi = BUDGET[min(level, 12)]
    return {'low': lo, 'mod': mo, 'high': hi}[col]


# ---------------------------------------------------------------- the walk
def road_fights(data, tid, legs, night_share, rng, level):
    """Fights met on `legs` legs of a road table (its chance per leg, then a weighted pick)."""
    t = data.tables[tid]
    out = []
    n = int(legs) + (1 if rng.random() < legs - int(legs) else 0)
    for i in range(n):
        night = rng.random() < night_share
        ch = t['chance_night'] if night else t['chance_day']
        if rng.random() > ch:
            continue
        pool = []
        for e in t['entries']:
            w = e.get('when', '')
            ok = True
            if w:
                try:
                    ok = cond(w, level, night)
                except Exception:
                    ok = True
            if ok:
                pool.append(e)
        tot = sum(e['weight'] for e in pool)
        r = rng.random() * tot
        for e in pool:
            r -= e['weight']
            if r <= 0:
                if 'monsters' in e:
                    out.append(data.mxp(e['monsters']))
                break
    return out


def visitor_xp(data, land, level):
    want = 'town' if land in ('town', 'village_of_barovia') else ('marsh' if land in ('berez',) else 'forest')
    for g in data.visitors:
        if g.get('land') == want and g['levels'][0] <= level <= g['levels'][1]:
            return data.mxp(g['monsters'])
    return 0


PROFILES = {
    'min': dict(fight=0, quest=0, explore=0, road=0, camp=0),
    'avg': dict(fight=1, quest=1, explore=1, road=1, camp=1),
    'full': dict(fight=2, quest=2, explore=2, road=2, camp=2),
    # play styles around the average: all the fights but few quests and little looking about, or the reverse
    'fighter': dict(fight=2, quest=0, explore=0, road=2, camp=2),
    'explorer': dict(fight=0, quest=2, explore=2, road=1, camp=1),
}


def walk(data, route, profile, rules, rng, grind=0):
    P = PROFILES[profile]
    xp = 0.0
    bank = 0.0
    story = 1
    gates = []
    fights = []      # (stage, gid, xp-mode level (int), story level, crit)
    src = collections.Counter()
    stage_end = []

    def ceiling_xp():
        return THRESH[story + 2] - 1 if story + 2 <= CAP else THRESH[CAP]

    def add(amount, kind, repeatable=False):
        nonlocal xp, bank
        if amount <= 0:
            return
        if not rules.ceiling:
            xp += amount
            src[kind] += amount
            return
        room = max(0.0, ceiling_xp() - xp)
        take = min(room, amount)
        xp += take
        src[kind] += take
        if not repeatable:
            bank += amount - take
        else:
            src['lost'] += amount - take

    def mon(raw_at, lv, kind, repeatable=False):
        if rules.monster_ref == 'story':
            amount = raw_at(story)
        elif rules.monster_ref == 'budget':
            amount = raw_at(lv) * budget(story, 'high') / budget(lv, 'high')
        else:
            amount = raw_at(lv)
        add(amount * rules.monster_mult / PARTY, kind, repeatable)

    for sid in route:
        st = STAGES[sid]
        for it in st['items']:
            lv = level_for(xp)
            kind = it[0]
            if kind == 'fight':
                _, gid, p, night, flags, note = it
                if rng.random() < p[P['fight']]:
                    fights.append((sid, gid, lv, story, p[0] >= 1))
                    mon(lambda L: fight_xp(data, gid, L, night, flags), lv, 'monsters')
            elif kind == 'quest':
                _, qk, n, note = it
                k = n[P['quest']]
                cnt = int(k) + (1 if rng.random() < k - int(k) else 0)
                col, mult = rules.quest[qk]
                for _ in range(cnt):
                    add(budget(level_for(xp), col) * mult, 'quests:' + qk)
            elif kind == 'explore':
                _, ek, n = it
                add(rules.explore[ek] * budget(lv, 'low') * n[P['explore']], 'explore')
            elif kind == 'road':
                _, tid, legs, ns = it
                extra = grind if profile == 'avg' else 0
                # the table's foes are fixed: the XP is theirs whatever the party's level
                for fx in road_fights(data, tid, legs[P['road']] + extra, ns, rng, lv):
                    fights.append((sid, 'road:' + tid, lv, story, False))
                    add(fx * rules.monster_mult / PARTY, 'road', repeatable=True)
            elif kind == 'camp':
                _, land, n = it
                if rng.random() < n[P['camp']]:
                    mon(lambda L: visitor_xp(data, land, L), lv, 'camp', repeatable=True)
            elif kind == 'milestone':
                before = frac_level(xp)
                if rules.milestone_high:
                    add(budget(level_for(xp), 'high'), 'milestone')
                story = min(CAP, story + 1)
                topped = 0.0
                if rules.floor and xp < THRESH[story]:
                    topped = THRESH[story] - xp
                    xp = THRESH[story]
                    src['floor'] += topped
                if rules.ceiling and bank > 0:
                    room = max(0.0, ceiling_xp() - xp)
                    take = min(room, bank)
                    xp += take
                    bank -= take
                    src['bank paid'] += take
                gates.append((sid, it[1], story, before, frac_level(xp), topped))
        stage_end.append((sid, frac_level(xp), story))
    src['bank left'] = bank
    return dict(gates=gates, fights=fights, src=src, xp=xp, stage_end=stage_end)


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def run(data, route, profile, rules, runs, seed=1, grind=0):
    outs = [walk(data, route, profile, rules, random.Random(seed * 100003 + r), grind) for r in range(runs)]
    return outs


def report(data, route_name, rules, runs, grind=0, profiles=('min', 'avg', 'full'), out=sys.stdout):
    route = ROUTES[route_name]
    res = {}
    for profile in profiles:
        outs = run(data, route, profile, rules, runs, grind=grind)
        res[profile] = outs
        print(f"\n=== {profile}  route={route_name}  rules={rules.name}  grind={grind}", file=out)
        print(f"{'gate':42s} {'mile':>4s} {'arrive p10 p50 p90':>20s} {'after p50':>9s} {'= mile':>7s} {'floor':>6s}", file=out)
        ng = len(outs[0]['gates'])
        for gi in range(ng):
            sid, note, story = outs[0]['gates'][gi][:3]
            b = [o['gates'][gi][3] for o in outs]
            a = [o['gates'][gi][4] for o in outs]
            same = sum(1 for x in a if int(x) == story) / len(a)
            fl = sum(1 for o in outs if o['gates'][gi][5] > 0) / len(outs)
            print(f"{note[:42]:42s} {story:4d} {pct(b,.1):6.2f} {pct(b,.5):6.2f} {pct(b,.9):6.2f}  {pct(a,.5):9.2f} {same*100:6.0f}% {fl*100:5.0f}%", file=out)
        print('fights by stage: share met at the milestone level / one above / two above (critical-path fights in brackets)', file=out)
        for sid in route:
            d = collections.Counter(); dc = collections.Counter()
            for o in outs:
                for f in o['fights']:
                    if f[0] == sid:
                        d[f[2] - f[3]] += 1
                        if f[4]:
                            dc[f[2] - f[3]] += 1
            n = sum(d.values()); nc = sum(dc.values())
            if n:
                row = ' '.join(f"{k:+d}:{d[k]/n*100:3.0f}%" for k in sorted(d))
                rowc = ' '.join(f"{k:+d}:{dc[k]/nc*100:3.0f}%" for k in sorted(dc)) if nc else ''
                print(f"   {sid:9s} {row:34s} [{rowc}]", file=out)
        srcs = collections.Counter()
        for o in outs:
            srcs.update(o['src'])
        earned = sum(v for k, v in srcs.items() if k not in ('lost', 'bank left', 'bank paid', 'floor'))
        print('XP earned by source: ' + ', '.join(f"{k} {v/earned*100:.0f}%" for k, v in sorted(srcs.items(), key=lambda kv: -kv[1]) if k not in ('lost', 'bank left', 'bank paid', 'floor')), file=out)
        print(f"   floor top-ups {srcs['floor']/earned*100:.1f}% of earned; repeatable XP lost over the ceiling {srcs['lost']/earned*100:.1f}%; banked and paid later {srcs['bank paid']/earned*100:.1f}%; still banked at the end {srcs['bank left']/runs:.0f} per hero", file=out)
    return res


def tables(repo, rules_name='plan'):
    """The plan's validation tables (docs/plans/xp_mode.md §5), as markdown. `rules_name` 'plan' reproduces them exactly;
    'build' runs what story/xp.gd does."""
    global data
    data = Data(repo)
    RUNS = 600
    plan = Rules(rules_name)

    def gates(route, profile, rules=plan, runs=RUNS, grind=0):
        outs = run(data, ROUTES[route], profile, rules, runs, grind=grind)
        rows = []
        for gi in range(len(outs[0]['gates'])):
            sid, note, story = outs[0]['gates'][gi][:3]
            b = [o['gates'][gi][3] for o in outs]; a = [o['gates'][gi][4] for o in outs]
            fl = sum(1 for o in outs if o['gates'][gi][5] > 0) / len(outs)
            top = statistics.mean(o['gates'][gi][5] for o in outs)
            same = sum(1 for x in a if int(x) == story) / len(a)
            rows.append(dict(sid=sid, note=note, story=story, p10=pct(b, .1), p50=pct(b, .5), p90=pct(b, .9), after=pct(a, .5), floor=fl, top=top, same=same))
        return rows, outs

    print('## T1 gates, route six')
    R = {}
    for prof in ('min', 'avg', 'full', 'fighter', 'explorer'):
        R[prof], _ = gates('six', prof)
    print('| Gate | Milestone level | Average p10 / p50 / p90 | Minimal | Thorough | Fighter | Explorer | Average topped up |')
    print('|---|---|---|---|---|---|---|---|')
    for i, g in enumerate(R['avg']):
        print(f"| {g['note']} | {g['story']} | {g['p10']:.2f} / {g['p50']:.2f} / {g['p90']:.2f} | {R['min'][i]['p50']:.2f} | {R['full'][i]['p50']:.2f} | {R['fighter'][i]['p50']:.2f} | {R['explorer'][i]['p50']:.2f} | {g['floor']*100:.0f}% |")

    print('\n## T2 per stage, average player, route six: XP per hero by source (median of runs) and level')
    outs = run(data, ROUTES['six'], 'avg', plan, RUNS)
    # re-walk with per-stage accounting
    def stage_breakdown(route, profile):
        acc = collections.defaultdict(lambda: collections.defaultdict(list))
        lv = collections.defaultdict(list)
        for r in range(RUNS):
            rng = random.Random(100003 + r)
            # instrumented walk: copy of walk logic with stage tags
            P = PROFILES[profile]; xp = 0.0; bank = 0.0; story = 1
            def ceiling_xp():
                return THRESH[story + 2] - 1 if story + 2 <= CAP else THRESH[CAP]
            for sid in ROUTES[route]:
                got = collections.Counter(); start = frac_level(xp)
                def add(amount, kind, repeatable=False):
                    nonlocal xp, bank
                    room = max(0.0, ceiling_xp() - xp); take = min(room, amount); xp += take; got[kind] += take
                    if not repeatable: bank += amount - take
                for it in STAGES[sid]['items']:
                    L = level_for(xp); k = it[0]
                    if k == 'fight':
                        _, gid, p, night, flags, note = it
                        if rng.random() < p[P['fight']]:
                            add(fight_xp(data, gid, L, night, flags) * plan.monster_mult / 4, 'fights')
                    elif k == 'quest':
                        _, qk, n, note = it; kk = n[P['quest']]; cnt = int(kk) + (1 if rng.random() < kk - int(kk) else 0)
                        col, mult = plan.quest[qk]
                        for _ in range(cnt): add(budget(level_for(xp), col) * mult, 'quests')
                    elif k == 'explore':
                        _, ek, n = it; add(plan.explore[ek] * budget(L, 'low') * n[P['explore']], 'explore')
                    elif k == 'road':
                        _, tid, legs, ns = it
                        for fx in road_fights(data, tid, legs[P['road']], ns, rng, L): add(fx * plan.monster_mult / 4, 'road', True)
                    elif k == 'camp':
                        _, land, n = it
                        if rng.random() < n[P['camp']]: add(visitor_xp(data, land, L) * plan.monster_mult / 4, 'road', True)
                    elif k == 'milestone':
                        if plan.milestone_high: add(budget(level_for(xp), 'high'), 'quests')
                        story = min(CAP, story + 1)
                        if xp < THRESH[story]: got['top-up'] += THRESH[story] - xp; xp = THRESH[story]
                        if bank > 0:
                            room = max(0.0, ceiling_xp() - xp); take = min(room, bank); xp += take; bank -= take; got['bank'] += take
                for kk in ('fights', 'road', 'quests', 'explore', 'top-up', 'bank'):
                    acc[sid][kk].append(got[kk])
                lv[sid].append((start, frac_level(xp)))
        return acc, lv
    acc, lv = stage_breakdown('six', 'avg')
    print('| Stage | Level in, out | Fights | Road and camp | Quests | Exploring | Milestone top-up | Total |')
    print('|---|---|---|---|---|---|---|---|')
    for sid in ROUTES['six']:
        a = acc[sid]; m = {k: statistics.mean(v) for k, v in a.items()}
        tot = sum(m.values())
        li = statistics.median(x[0] for x in lv[sid]); lo = statistics.median(x[1] for x in lv[sid])
        print(f"| {STAGES[sid]['name']} | {li:.2f}, {lo:.2f} | {m['fights']:,.0f} | {m['road']:,.0f} | {m['quests']:,.0f} | {m['explore']:,.0f} | {m['top-up']:,.0f} | {tot:,.0f} |")

    print('\n## T3 routes (average p50 on arrival at each gate; minus the milestone level)')
    for route in ('six', 'all', 'alt'):
        rows, _ = gates(route, 'avg')
        print(route, ' '.join(f"{g['story']}:{g['p50']-g['story']:+.2f}" for g in rows))

    print('\n## T4 fights met at the milestone level / one above (all non-road fights; critical-path fights)')
    for route in ('six', 'all', 'alt'):
        for prof in ('min', 'avg', 'full', 'fighter', 'explorer'):
            o = run(data, ROUTES[route], prof, plan, 300)
            d = collections.Counter(); dc = collections.Counter()
            for x in o:
                for f in x['fights']:
                    if not f[1].startswith('road'):
                        d[f[2]-f[3]] += 1
                        if f[4]: dc[f[2]-f[3]] += 1
            n = sum(d.values()); nc = sum(dc.values())
            print(route, prof, ' '.join(f"{k:+d}:{d[k]/n*100:.0f}%" for k in sorted(d)), '| crit', ' '.join(f"{k:+d}:{dc[k]/nc*100:.0f}%" for k in sorted(dc)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('repo')
    ap.add_argument('--runs', type=int, default=400)
    ap.add_argument('--route', default='all')
    ap.add_argument('--rules', default='plan')
    ap.add_argument('--grind', type=float, default=0)
    ap.add_argument('--set', action='append', default=[], help='rule override, e.g. monster_ref=story')
    ap.add_argument('--tables', action='store_true', help="print the plan's validation tables")
    args = ap.parse_args()
    if args.tables:
        tables(args.repo, args.rules)
        return
    kw = {}
    for s in args.set:
        k, v = s.split('=', 1)
        kw[k] = eval(v, {}, {}) if v[:1] in '0123456789[{(.TF' else v
    data = Data(args.repo)
    report(data, args.route, Rules(args.rules, **kw), args.runs, args.grind)


if __name__ == '__main__':
    main()
