#!/usr/bin/env python3
"""Sorts every spell and ability into an effect family (docs/art/spell_effects.md) and writes the picks that are
missing into art/vfx/effects.json; picks already there are never changed. Spells: from their data (area shape, attack
roll, tags, what they target) with a short list of spells whose look the data can't tell. Faerun and Arcana Unleashed
entries (built by their own tool) and the stopped Ravenloft: The Horrors Within content are skipped.

python3 tools/vfx/assign_families.py            report: how many keys per family, and what's missing
python3 tools/vfx/assign_families.py --write    also write the missing picks
python3 tools/vfx/assign_families.py --list     every key with the family it would get"""
import collections
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "art/vfx/effects.json")
SKIP_BOOKS = {"FRHoF", "AU", "FRAiF", "RtHW"}

# Spells whose look their data can't tell (a ray that's a saving throw, a strike from above, a drain...).
SPELL_LOOKS = {
    # missiles
    "magic_missile": {"family": "bolt", "count": 3, "size": 0.6}, "chromatic_orb": "bolt", "sorcerous_burst": "bolt",
    "ice_knife": "bolt", "melfs_acid_arrow": "bolt", "poison_spray": "bolt", "starry_wisp": "bolt@moon",
    "guiding_bolt": "bolt", "hellish_rebuke": "strike@fire", "produce_flame": "bolt",
    # rays and beams
    "ray_of_frost": "ray", "ray_of_sickness": "ray", "scorching_ray": "ray", "ray_of_enfeeblement": "ray@necrotic",
    "disintegrate": "ray", "eldritch_blast": "beam", "witch_bolt": "beam", "chain_lightning": {"family": "beam", "chain": True},
    "finger_of_death": "ray@necrotic", "blight": "drain@necrotic", "harm": "drain@necrotic", "vampiric_touch": "drain",
    "enervation": "drain",
    # from above
    "sacred_flame": "strike", "flame_strike": "strike", "moonbeam": "strike", "call_lightning": "strike",
    "ice_storm": "strike", "meteor_swarm": "strike", "storm_of_vengeance": "strike", "jallarzis_storm_of_radiance": "strike",
    "conjure_celestial": "strike", "sunburst": "burst", "fire_storm": "burst", "toll_the_dead": "psychic@necrotic",
    "power_word_kill": "psychic@necrotic", "circle_of_death": "burst",
    # out from the caster
    "thunderwave": "nova", "thunderclap": "nova", "word_of_radiance": "nova", "arms_of_hadar": "nova",
    "destructive_wave": "nova", "shatter": "burst", "lightning_arrow": "smite@lightning", "hail_of_thorns": "smite@nature",
    "ensnaring_strike": "smite@nature", "conjure_barrage": "cone@steel", "color_spray": "cone",
    "prismatic_spray": "cone", "fear": "cone", "gust_of_wind": "line", "sunbeam": "line", "lightning_bolt": "line",
    # lingering clouds and growth
    "fog_cloud": "cloud@thunder", "stinking_cloud": "cloud", "cloudkill": "cloud", "darkness": "cloud@shadow",
    "hunger_of_hadar": "cloud@shadow", "incendiary_cloud": "cloud", "sleet_storm": "cloud", "insect_plague": "cloud@nature",
    "cloud_of_daggers": "cloud@steel", "silence": "cloud@illusion", "confusion": "psychic", "hypnotic_pattern": "cloud@illusion",
    "faerie_fire": "cloud@illusion", "web": "ground@ward", "entangle": "ground", "grease": "ground", "spike_growth": "ground",
    "plant_growth": "ground", "evards_black_tentacles": "ground", "earthquake": "ground", "cordon_of_arrows": "ground@steel",
    "reverse_gravity": "ground@force", "control_water": "ground@water", "tsunami": "wall@water",
    # auras round the caster
    "spirit_guardians": "aura", "aura_of_life": "aura", "aura_of_purity": "aura", "aura_of_vitality": "aura",
    "crusaders_mantle": "aura", "holy_aura": "aura", "circle_of_power": "aura", "antilife_shell": "ward",
    "antimagic_field": "ward", "globe_of_invulnerability": "ward", "yolandes_regal_presence": "aura",
    "pass_without_trace": "aura@nature", "conjure_minor_elementals": "aura", "conjure_woodland_beings": "aura",
    "fire_shield": "ward@fire", "armor_of_agathys": "ward@cold", "fount_of_moonlight": "aura@moon",
    # weapons and touch
    "shocking_grasp": "touch", "chill_touch": "touch", "inflict_wounds": "touch", "contagion": "touch@poison",
    "bestow_curse": "debuff", "thorn_whip": "touch", "grasping_vine": "touch", "steel_wind_strike": "teleport@force",
    "true_strike": "smite@moon", "shillelagh": "buff@nature", "flame_blade": "buff@fire", "elemental_weapon": "buff",
    "magic_weapon": "buff", "divine_favor": "buff", "swift_quiver": "buff", "dragons_breath": "buff@fire",
    "spiritual_weapon": "summon@force", "flaming_sphere": "summon@fire", "bigbys_hand": "summon@force",
    "mordenkainens_sword": "summon@force", "animate_objects": "summon@force", "guardian_of_faith": "summon",
    "mordenkainens_faithful_hound": "summon", "conjure_animals": "summon", "conjure_elemental": "summon",
    "conjure_fey": "summon", "heat_metal": "debuff@fire",
    # shape and form
    "polymorph": "transform", "true_polymorph": "transform", "shapechange": "transform", "alter_self": "transform",
    "animal_shapes": "transform", "enlarge_reduce": "transform", "gaseous_form": "transform", "flesh_to_stone": "transform@earth",
    "etherealness": "teleport@illusion", "blink": "teleport", "otilukes_resilient_sphere": "ward@force",
    "forcecage": "wall@force", "maze": "teleport", "banishment": "teleport@ward", "imprisonment": "teleport@ward",
    # going places
    "misty_step": "teleport", "dimension_door": "teleport", "teleport": "teleport", "plane_shift": "teleport",
    "word_of_recall": "teleport", "tree_stride": "teleport@nature", "transport_via_plants": "teleport@nature",
    "arcane_gate": "summon", "gate": "summon", "teleportation_circle": "summon", "wind_walk": "transform@thunder",
    # defence
    "shield": "ward", "sanctuary": "ward", "mage_armor": "ward", "blade_ward": "ward", "resistance": "ward",
    "protection_from_evil_and_good": "ward", "protection_from_energy": "ward", "protection_from_poison": "ward",
    "death_ward": "ward", "stoneskin": "ward", "barkskin": "ward@nature", "warding_bond": "ward", "mind_blank": "ward",
    "mirror_image": "transform@illusion", "blur": "transform@illusion", "invisibility": "transform@illusion",
    "greater_invisibility": "transform@illusion", "counterspell": "ward", "dispel_magic": "ward",
    "magic_circle": "ward", "leomunds_tiny_hut": "ward", "false_life": "ward@necrotic",
    # small helps
    "spare_the_dying": "heal", "arcane_vigor": "heal", "hunters_mark": "debuff@nature", "expeditious_retreat": "buff",
    "jump": "buff", "feather_fall": "buff", "longstrider": "buff", "water_walk": "buff@water",
    "water_breathing": "buff@water", "see_invisibility": "buff@illusion", "darkvision": "buff@moon",
    "time_stop": "nova@arcane", "wish": "nova@arcane", "dancing_lights": "summon@illusion", "light": "buff",
    "continual_flame": "buff@fire", "minor_illusion": "summon@illusion", "mage_hand": "summon@force",
    "unseen_servant": "summon", "tensers_floating_disk": "summon@force",
}

# Monster and feature looks are added when their events reach the view (rollout).


def spell_family(s):
    """The family a spell's data points to (SpellFx.derive_family, more fully)."""
    tags = s.get("tags", [])
    area = s.get("area", {})
    shape = area.get("shape", "")
    rng = s.get("range", {}).get("kind", "")
    targets = s.get("targets", {}).get("kind", "")
    dur = s.get("duration", {}).get("kind", "")
    damage = bool(s.get("damage"))
    if s.get("on_hit_spell"):
        return "smite"
    if "healing" in tags and (s.get("heal") or "regain" in s.get("summary", "").lower() or "restor" in s.get("summary", "").lower()):
        return "heal"
    if "restoration" in tags:
        return "heal"
    if "summon" in tags:
        return "summon"
    if shape == "cone":
        return "cone"
    if shape == "line":
        return "line"
    if shape == "wall":
        return "wall"
    if shape == "emanation":
        return "nova" if dur == "instantaneous" else "aura"
    if shape in ("sphere", "cube", "cylinder"):
        if rng == "self":
            return "nova"
        if damage and dur == "instantaneous":
            return "burst"
        if "zone" in s:
            return "cloud"
        if damage:
            return "burst"
        return "psychic" if "control" in tags else "cloud"
    if s.get("attack") == "ranged":
        return "bolt"
    if s.get("attack") == "melee":
        return "touch"
    if damage and targets in ("creature", "creature_or_object", "enemy"):
        return "debuff" if s.get("save") in ("con", "str") else "psychic" if s.get("save") in ("wis", "int", "cha") else "strike"
    if "movement" in tags and "teleport" in s.get("text", "").lower():
        return "teleport"
    if "debuff" in tags or ("control" in tags and targets in ("creature", "creature_or_object")):
        # Charms, commands and holds work on the mind: ripples round the head rather than a curse sinking in.
        return "psychic" if s.get("save") in ("wis", "int", "cha") and s.get("_flavour") == "mind" else "debuff"
    if "defense" in tags:
        return "ward"
    if "buff" in tags:
        return "buff"
    return "glimmer"


def load(folder):
    out = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", folder, "*.json"))):
        j = json.load(open(f))
        if isinstance(j, dict) and j.get("source", {}).get("book") not in SKIP_BOOKS:
            out.append(j)
    return out


def proposals():
    icons = json.load(open(os.path.join(ROOT, "art/icons.json")))["spells"]
    picks = {}
    for s in load("spells"):
        icon = icons.get(s.get("icon", s["id"]), "")
        s["_flavour"] = icon.split("@")[1] if "@" in icon else ""
        picks[s["id"]] = SPELL_LOOKS.get(s["id"], spell_family(s))
    return {"spells": picks}


def family_of(pick):
    return pick["family"] if isinstance(pick, dict) else pick.split("@")[0]


def main():
    data = json.load(open(DATA))
    props = proposals()
    if "--list" in sys.argv:
        for kind, picks in props.items():
            for k, v in sorted(picks.items(), key=lambda kv: (family_of(kv[1]), kv[0])):
                print(f"{kind}\t{family_of(v)}\t{k}\t{v if not isinstance(v, str) or '@' in v else ''}")
        return
    for kind, picks in props.items():
        have = data.setdefault(kind, {})
        missing = {k: v for k, v in picks.items() if k not in have}
        counts = collections.Counter(family_of(v) for v in {**picks, **have}.values())
        print(f"{kind}: {len(picks)} in scope, {len(have)} picked, {len(missing)} missing")
        print("  " + ", ".join(f"{f} {n}" for f, n in counts.most_common()))
        if "--write" in sys.argv:
            have.update(missing)
            data[kind] = dict(sorted(have.items()))
    if "--write" in sys.argv:
        text = json.dumps(data, indent=2, ensure_ascii=False)
        open(DATA, "w").write(text + "\n")
        print("wrote", DATA)


if __name__ == "__main__":
    main()
