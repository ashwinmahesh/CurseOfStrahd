#!/usr/bin/env python3
"""Builds the game wiki (full of spoilers) from the game's data: Obsidian pages in the vault's Wiki/ folder (`make wiki`).

Every page is generated from data/, narrative/ and a few docs, so it can be rebuilt whenever the game changes. What a
person writes on a page is kept: the generator owns only the blocks between `%% auto:<name> %%` and `%% /auto:<name>
%%`, and rewrites those in place. Anything outside them (a walkthrough, notes) survives every rebuild. Each page names
what it's about in its front matter (`wiki: quest/black_roses`), so a renamed quest or place moves its page, prose and
all. A page whose subject left the game goes to Wiki/_Removed/ if someone wrote on it, else it's deleted.

Images go to Wiki/images/: portraits and cutscene stills scaled down with macOS `sips`, location maps drawn as SVG,
and screenshots copied from a capture folder (tools/wiki/wiki_shots.gd writes them; --shots <dir>).

    python3 tools/wiki/build_wiki.py [--out <dir>] [--shots <dir>] [--no-images] [--dry-run]

Stdlib only. Nothing here reads or writes the game's saves or settings.
"""
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VAULT = Path.home() / "Documents" / "Obsidian Vault" / "CurseOfStrahd"
WIKI = "Wiki"                     # the folder in the vault; links are written vault-relative ("Wiki/Quests/...")
DEFAULT_OUT = VAULT / WIKI

# --- Names the data doesn't hold ----------------------------------------------------------------------------------

REGION_NAMES = {
    "into_the_mists": "Into the Mists", "death_house": "Death House", "village_of_barovia": "The Village of Barovia",
    "svalich_road": "The Old Svalich Road", "vallaki": "Vallaki", "old_bonegrinder": "Old Bonegrinder",
    "wizard_of_wines": "The Wizard of Wines", "yester_hill": "Yester Hill", "krezk": "Krezk",
    "abbey_of_st_markovia": "The Abbey of St. Markovia", "argynvostholt": "Argynvostholt",
    "van_richtens_tower": "Van Richten's Tower", "werewolf_den": "The Werewolf Den", "lake_zarovich": "Lake Zarovich",
    "berez": "Berez", "mount_baratok": "Mount Baratok", "tsolenka_pass": "The Tsolenka Pass",
    "mount_ghakis": "Mount Ghakis", "amber_temple": "The Amber Temple", "castle_ravenloft": "Castle Ravenloft",
}
# The story's spine in the order it's played (quests marked "main" in data/quests that aren't listed go last).
MAIN_ORDER = ["into_the_mists", "death_house", "bury_the_burgomaster", "escort_ireena", "madam_evas_reading",
              "find_the_tome", "find_the_holy_symbol", "find_the_sunsword", "find_the_ally", "strahds_lair",
              "sanctuary_for_ireena", "festival_of_the_blazing_sun", "dinner_at_castle_ravenloft"]
SKILL_NAMES = {"sleight_of_hand": "Sleight of Hand", "animal_handling": "Animal Handling"}
RARITIES = ["common", "uncommon", "rare", "very_rare", "legendary", "artifact"]
ABILITIES = ["str", "dex", "con", "int", "wis", "cha"]
SCHOOLS = ["abjuration", "conjuration", "divination", "enchantment", "evocation", "illusion", "necromancy",
           "transmutation"]
TAROKKA_TREASURES = {"tome_of_strahd": "tome", "holy_symbol_of_ravenkind": "symbol", "sunsword": "sword"}
REST_WORDS = {"safe": "Safe: a Long Rest here isn't interrupted.",
              "risky": "Risky: a rest here can be interrupted.",
              "none": "No resting here.", "unsafe": "Unsafe: resting here is asking for trouble."}
AUTO_RE = re.compile(r"%% auto:([a-z0-9_]+) %%\n(.*?)%% /auto:\1 %%\n?", re.S)
TODAY = datetime.date.today().isoformat()


# --- Small helpers ------------------------------------------------------------------------------------------------

def load_json(p):
    return json.loads(Path(p).read_text())


def title_id(s):
    return " ".join(w if w in ("of", "the", "and") and i else w.capitalize()
                    for i, w in enumerate(str(s).replace("-", "_").split("_")))


def safe_file(name):
    name = re.sub(r'[\\/:*?"<>|#^\[\]]', "", str(name)).strip().rstrip(".")
    return re.sub(r"\s+", " ", name) or "Untitled"


def esc(text):
    """Text for a table cell."""
    return str(text).replace("|", "\\|").replace("\n", " ")


def plural(n, word, many=None):
    return f"{n} {word if n == 1 else (many or word + 's')}"


def skill_name(s):
    s = str(s).lower().replace(" ", "_")
    return SKILL_NAMES.get(s, s.replace("_", " ").title())


def human_cond(expr):
    """A `when` condition in plainer words (story/story_conditions.gd's syntax)."""
    e = str(expr or "").strip()
    if not e:
        return ""
    e = re.sub(r"\bflag\.([a-z0-9_]+)\s*==\s*\"([^\"]*)\"", lambda m: f"{m[1]} is “{m[2]}”", e)
    e = re.sub(r"\bflag\.([a-z0-9_]+)\s*!=\s*\"([^\"]*)\"", lambda m: f"{m[1]} isn't “{m[2]}”", e)
    e = re.sub(r"\bquest\.([a-z0-9_]+)\s*(==|>=)\s*([a-z0-9_]+)",
               lambda m: f"quest {m[1]} {'at' if m[2] == '==' else 'at or past'} {m[3]}", e)
    e = re.sub(r"\bflag\.", "", e)
    e = re.sub(r"\bvisited:([a-z0-9_]+)", r"visited \1", e)
    e = re.sub(r"\bguest:([a-z0-9_]+)", r"\1 with the party", e)
    e = re.sub(r"\bitem:([a-z0-9_]+)", r"carrying \1", e)
    e = re.sub(r"\bgift:([a-z0-9_]+)", r"has the dark gift \1", e)
    e = re.sub(r"\b(class|species|background|tag|name):([a-z0-9_]+)", r"\1 \2", e)
    e = e.replace(">=", "≥").replace("<=", "≤").replace("==", "is").replace("!=", "isn't")
    e = e.replace("_", " ")
    return e


def lower_article(label):
    return re.sub(r"^(A|An|The) ", lambda m: m[1].lower() + " ", str(label))


def md_list(items):
    return "\n".join(f"- {x}" for x in items)


def plain(text, limit=0):
    t = re.sub(r"\s+", " ", str(text or "")).strip()
    if limit and len(t) > limit:
        t = t[:limit].rsplit(" ", 1)[0] + "…"
    return t


# --- Dialogue files -----------------------------------------------------------------------------------------------

RE_NODE = re.compile(r"^~\s+(\S+)\s*$")
RE_LINE = re.compile(r"^([A-Za-z][A-Za-z_ ]*?)(?:\s*\[([a-z:]+(?:\s*,\s*[a-z:]+)*)\])?:\s+(.+)$")
RE_OPTION = re.compile(r"^\*\s+(.*?)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?\s*$")
RE_TAG = re.compile(r"^\[([^\]]+)\]\s*")
RE_CHECK_TAG = re.compile(r"^([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)$")
RE_CHECK = re.compile(r"^check\s+([A-Za-z][A-Za-z ]*?)\s+DC\s+(\d+)\s*->\s*(\S+)(?:\s*\|\s*(\S+))?$")
RE_INTERJECT = re.compile(r"^interject\s+([a-z]+:[a-z0-9_]+):\s+(.+)$")


class Dialogue:
    """One narrative/**/*.dialogue file, parsed just enough for the wiki: per node, its statements and where it can
    go next. Grammar: docs/contracts/dialogue.md (tools/data/dialogue_lint.py is the full parser)."""

    def __init__(self, key, path):
        self.key = key
        self.path = path
        self.header = []          # the file's opening comment: what it's for, in the writers' words
        self.nodes = OrderedDict()
        node = None
        for n, raw in enumerate(path.read_text().split("\n"), 1):
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#"):
                if node is None:
                    self.header.append(line.lstrip("# ").strip())
                continue
            m = RE_NODE.match(line)
            if m:
                node = m[1]
                self.nodes[node] = []
                continue
            if node is None:
                continue
            st = self._statement(line)
            if st:
                st["line"] = n
                st["node"] = node
                self.nodes[node].append(st)

    @staticmethod
    def _statement(line):
        if line.startswith("*"):
            m = RE_OPTION.match(line)
            if not m:
                return None
            text, tags = m[1], []
            while True:
                t = RE_TAG.match(text)
                if not t:
                    break
                tags.append(t[1])
                text = text[t.end():]
            st = {"t": "option", "text": text, "tags": tags, "ok": m[2], "fail": m[3] or ""}
            for tag in tags:
                c = RE_CHECK_TAG.match(tag)
                if c:
                    st["check"] = (skill_name(c[1]), int(c[2]))
            return st
        if line.startswith("->"):
            return {"t": "jump", "to": line[2:].strip()}
        if line.startswith("|"):
            return {"t": "variant", "text": line[1:].strip()}
        word, _, rest = line.partition(" ")
        rest = rest.strip()
        if word in ("if", "elif"):
            return {"t": word, "cond": rest}
        if word in ("else", "endif", "once"):
            return {"t": word}
        if word == "set":
            return {"t": "set", "expr": rest, "flag": re.split(r"[\s=+-]", rest)[0]}
        if word == "quest":
            parts = rest.split()
            return {"t": "quest", "id": parts[0], "stage": parts[1] if len(parts) > 1 else ""}
        if word in ("give", "take"):
            m = re.match(r"^([a-z][a-z0-9_]*)(?:\s+(\d+))?(?:\s+to\s+(\S+))?$", rest)
            if m:
                return {"t": word, "item": m[1], "qty": int(m[2] or 1), "to": m[3] or ""}
            return None
        if word == "gold":
            try:
                return {"t": "gold", "amount": int(rest)}
            except ValueError:
                return None
        if word == "combat":
            return {"t": "combat", "id": rest}
        if word == "check":
            m = RE_CHECK.match(line)
            if m:
                return {"t": "check", "check": (skill_name(m[1]), int(m[2])), "ok": m[3], "fail": m[4] or ""}
            return None
        if word in ("cast", "reveal", "cutscene", "dark_gift", "join", "leave", "shop", "appear", "narrate", "xp",
                    "time", "attitude", "tarokka", "cooldown", "inspire", "end_game", "sacrifice"):
            return {"t": word, "arg": rest}
        if word == "approve":
            head, _, why = rest.partition(":")
            pairs = re.findall(r"([a-z_]+)\s+([+-]\d+)", head)
            return {"t": "approve", "changes": [(a, int(b)) for a, b in pairs], "why": why.strip()}
        if word == "interject":
            m = RE_INTERJECT.match(line)
            return {"t": "interject", "who": m[1], "text": m[2]} if m else None
        m = RE_LINE.match(line)
        if m:
            return {"t": "line", "speaker": m[1].strip(), "mood": m[2] or "", "text": m[3]}
        return None

    def ref(self, target):
        """(file key, node) a jump target in this file names, or None for END."""
        if not target or target == "END":
            return None
        if "/" in target and ":" in target:
            i = target.rfind(":")
            return (target[:i], target[i + 1:])
        return (self.key, target)

    def edges(self, node):
        out = []
        for st in self.nodes.get(node, []):
            for k in ("to", "ok", "fail"):
                if st.get(k) and st["t"] in ("jump", "option", "check"):
                    r = self.ref(st[k])
                    if r:
                        out.append(r)
        # Falling off the end of a node runs on into the next one only through an explicit jump, so no edge here.
        return out


# --- The game's data ----------------------------------------------------------------------------------------------

class Game:
    def __init__(self, root):
        self.root = root
        d = root / "data"

        def folder(name):
            out = OrderedDict()
            for f in sorted((d / name).glob("*.json")):
                j = load_json(f)
                out[str(j.get("id", f.stem))] = j
            return out

        self.quests = folder("quests")
        self.locations = folder("locations")
        self.npcs = folder("npcs")
        self.monsters = folder("monsters")
        self.items = folder("items")
        self.magic = folder("magic_items")
        self.spells = folder("spells")
        self.classes = folder("classes")
        self.subclasses = folder("subclasses")
        self.species = folder("species")
        self.backgrounds = folder("backgrounds")
        self.feats = folder("feats")
        self.conditions = folder("conditions")
        self.dark_gifts = folder("dark_gifts")
        self.endings = folder("endings")
        self.pregens = folder("pregens")
        self.cutscenes = folder("cutscenes")
        self.travel = folder("travel")
        self.random_encounters = folder("random_encounters")
        self.tarokka_cards = load_json(d / "tarokka" / "cards.json")
        self.tarokka = load_json(d / "tarokka" / "outcomes.json")
        self.visits = load_json(d / "strahd" / "visits.json")
        self.treasure = load_json(d / "treasure" / "levels.json")
        self.weather = load_json(d / "weather" / "barovia.json")
        self.glossary = load_json(d / "glossary" / "terms.json")
        self.loading = load_json(d / "loading" / "cards.json")
        self.schedules = folder("schedule")
        self.all_items = OrderedDict(list(self.items.items()) + list(self.magic.items()))
        self.dialogues = OrderedDict()
        for p in sorted((root / "narrative").rglob("*.dialogue")):
            key = str(p.relative_to(root / "narrative"))[:-len(".dialogue")]
            self.dialogues[key] = Dialogue(key, p)
        self.speaker_npc = self._speakers()
        self.entries = self._entries()
        self.reach = self._reach()

    # Names --------------------------------------------------------------------------------------------------------

    def item_name(self, iid):
        iid = str(iid)
        if iid in self.all_items:
            return self.all_items[iid].get("name", title_id(iid))
        if "__" in iid:
            tid, base = iid.split("__", 1)
            t = self.all_items.get(tid, {})
            tmpl = (t.get("template") or {}).get("name", "")
            if t.get("template", {}).get("on") == "spell":
                bname = self.spells.get(base, {}).get("name", title_id(base))
            else:
                bname = self.all_items.get(base, {}).get("name", title_id(base))
            if tmpl and "{base}" in tmpl:
                return tmpl.replace("{base}", bname)
            return f"{t.get('name', title_id(tid))} ({bname})"
        return title_id(iid)

    def item_data(self, iid):
        iid = str(iid)
        if iid in self.all_items:
            return self.all_items[iid]
        if "__" in iid:
            tid, base = iid.split("__", 1)
            t = dict(self.all_items.get(tid, {}))
            b = self.all_items.get(base, {})
            if t and b and not t.get("cost_gp"):
                t["cost_gp"] = b.get("cost_gp", 0)
            return t
        return {}

    def item_cost(self, iid):
        d = self.item_data(iid)
        cost = float(d.get("cost_gp", 0) or 0)
        if "__" in str(iid) and str(iid).split("__")[0] in self.magic:
            base = self.all_items.get(str(iid).split("__", 1)[1], {})
            cost += float(base.get("cost_gp", 0) or 0)
        return cost

    def location_name(self, lid):
        return self.locations.get(lid, {}).get("name", title_id(lid))

    def npc_name(self, nid):
        return self.npcs.get(nid, {}).get("name", title_id(nid))

    def monster_name(self, mid):
        return self.monsters.get(mid, {}).get("name", title_id(mid))

    def region_name(self, rid):
        return REGION_NAMES.get(rid, title_id(rid))

    def region_level(self, rid):
        return self.treasure.get("region_levels", {}).get(rid)

    def area_name(self, lid, cell):
        if not cell:
            return ""
        x, y = int(cell[0]), int(cell[1])
        for a in self.locations.get(lid, {}).get("areas", []):
            (x0, y0), (x1, y1) = a["cells"][0], a["cells"][1]
            if min(x0, x1) <= x <= max(x0, x1) and min(y0, y1) <= y <= max(y0, y1):
                return a.get("name", "")
        return ""

    # Who speaks in which file -------------------------------------------------------------------------------------

    def _speakers(self):
        """Speaker display name -> npc id, from the NPC data and the conversations locations open."""
        out = {}
        for nid, n in self.npcs.items():
            out.setdefault(n.get("name", ""), nid)
        return out

    def _entries(self):
        """(file key, node) -> [where it's opened from]: an NPC or prop in a location, a road event, a camp talk..."""
        out = defaultdict(list)
        ref_re = re.compile(r"^([a-z0-9_]+(?:/[a-z0-9_]+)+):([A-Za-z0-9_:]+)$")

        def add(ref, where):
            m = ref_re.match(str(ref))
            if m:
                out[(m[1], m[2])].append(where)

        for lid, loc in self.locations.items():
            for n in loc.get("npcs", []):
                if n.get("dialogue"):
                    add(n["dialogue"], {"kind": "npc", "npc": n.get("npc", ""), "location": lid, "cell": n.get("cell"),
                                        "when": n.get("when", ""), "ref": n["dialogue"]})
            for p in loc.get("props", []):
                if p.get("dialogue"):
                    add(p["dialogue"], {"kind": "prop", "prop": p.get("label", p.get("id")), "location": lid,
                                        "cell": p.get("cell"), "when": p.get("when", "")})
            narr = loc.get("narration", {})
            for k, v in narr.items() if isinstance(narr, dict) else []:
                if isinstance(v, str):
                    add(v if "/" in v else "narrator/" + v, {"kind": "arrive", "location": lid})

        def scan(obj, src):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if isinstance(v, str) and k in ("dialogue", "talk", "conversation"):
                        add(v, {"kind": "event", "source": src, "when": obj.get("when", "")})
                    else:
                        scan(v, src)
            elif isinstance(obj, list):
                for v in obj:
                    scan(v, src)

        d = self.root / "data"
        for f in sorted(d.rglob("*.json")):
            if "locations" in f.parts or "schemas" in f.parts:
                continue
            try:
                scan(load_json(f), str(f.relative_to(d))[:-5])
            except (json.JSONDecodeError, UnicodeDecodeError):
                pass
        # Cross-file jumps count as ways in too (the target's place is the caller's).
        return out

    def _reach(self):
        """(file key, node) -> set of entry (file key, node) it can be reached from, following jumps and options."""
        graph = defaultdict(set)
        for key, dlg in self.dialogues.items():
            for node in dlg.nodes:
                for r in dlg.edges(node):
                    graph[(key, node)].add(r)
        reach = defaultdict(set)
        for entry in list(self.entries):
            seen, stack = set(), [entry]
            while stack:
                cur = stack.pop()
                if cur in seen:
                    continue
                seen.add(cur)
                reach[cur].add(entry)
                stack.extend(graph.get(cur, ()))
        return reach

    def places_for(self, key, node):
        """Where a node can be reached from: [(entry dict)] through every entry that leads to it."""
        out = []
        for e in sorted(self.reach.get((key, node), ())):   # sorted: a set's order changes from run to run
            out.extend(self.entries.get(e, []))
        return out

    def statements(self, kinds):
        for key, dlg in self.dialogues.items():
            for node, sts in dlg.nodes.items():
                for st in sts:
                    if st["t"] in kinds:
                        yield key, node, st


# --- Pages: paths, links and the auto blocks ----------------------------------------------------------------------

class Site:
    """Which page each thing has, and how to link to it."""

    def __init__(self, game):
        self.g = game
        self.paths = {}         # "quest/black_roses" -> "Quests/Black Roses"
        self.titles = {}
        self.anchors = {}       # things that live as a heading on a shared page: key -> (path, heading)

    def register(self, key, folder, title, disambig=""):
        name = safe_file(title)
        path = f"{folder}/{name}" if folder else name
        taken = {v.lower() for v in self.paths.values()}
        if path.lower() in taken:
            path = f"{folder}/{safe_file(title + ' (' + (disambig or key.split('/')[-1]) + ')')}"
        n = 2
        while path.lower() in taken:
            path = f"{folder}/{safe_file(title)} {n}"
            n += 1
        self.paths[key] = path
        self.titles[key] = title
        return path

    def anchor(self, key, path, heading):
        self.anchors[key] = (path, heading)

    def link(self, key, text=None):
        if key in self.paths:
            label = text or self.titles[key]
            return f"[[{WIKI}/{self.paths[key]}|{label}]]"
        if key in self.anchors:
            path, heading = self.anchors[key]
            label = text or heading
            return f"[[{WIKI}/{path}#{heading}|{label}]]"
        return text or key.split("/", 1)[-1]

    def page(self, path, text=None):
        return f"[[{WIKI}/{path}|{text or path.split('/')[-1]}]]"

    # Shorthands
    def quest(self, qid, text=None):
        return self.link(f"quest/{qid}", text or self.g.quests.get(qid, {}).get("name"))

    def npc(self, nid, text=None):
        return self.link(f"npc/{nid}", text or self.g.npc_name(nid))

    def loc(self, lid, text=None):
        return self.link(f"location/{lid}", text or self.g.location_name(lid))

    def mon(self, mid, text=None):
        return self.link(f"monster/{mid}", text or self.g.monster_name(mid))

    def region(self, rid, text=None):
        return self.link(f"region/{rid}", text or self.g.region_name(rid))

    def item(self, iid, text=None):
        return self.link(f"item/{iid}", text or self.g.item_name(iid))

    def spell(self, sid, text=None):
        return self.link(f"spell/{sid}", text or self.g.spells.get(sid, {}).get("name", title_id(sid)))


RE_LINK_PIPE = re.compile(r"(\[\[[^\]|]*?)(?<!\\)\|([^\]]*?\]\])")


def table_safe(body):
    """A link or embed's own `|` inside a table row ends the cell in Obsidian unless it's written `\\|`."""
    out = []
    for ln in body.split("\n"):
        if ln.startswith("|") and "[[" in ln:
            ln = RE_LINK_PIPE.sub(r"\1\\|\2", ln)
        out.append(ln)
    return "\n".join(out)


def auto(name, body):
    return f"%% auto:{name} %%\n{table_safe(body.rstrip())}\n%% /auto:{name} %%\n"


class Writer:
    """Writes pages, keeping whatever a person wrote outside the auto blocks."""

    def __init__(self, out, dry=False):
        self.out = out
        self.dry = dry
        self.written = set()
        self.stats = defaultdict(int)
        self.existing = {}          # wiki key -> path of an existing page
        if out.exists():
            for p in out.rglob("*.md"):
                if "images" in p.parts:
                    continue
                m = re.match(r"^---\n(.*?)\n---\n", p.read_text(), re.S)
                if m:
                    k = re.search(r"^wiki:\s*(\S+)\s*$", m[1], re.M)
                    if k:
                        self.existing[k[1]] = p

    def write(self, key, rel_path, title, parts, tags=()):
        """parts: a list of strings, each either an auto() block or a person's default text for a new page."""
        path = self.out / (rel_path + ".md")
        front = f"---\nwiki: {key}\n" + (f"tags: [{', '.join(tags)}]\n" if tags else "") + "---\n"
        new_body = f"# {title}\n\n" + "\n".join(p.rstrip() + "\n" for p in parts)
        old_path = self.existing.get(key)
        if old_path and old_path.exists():
            old = old_path.read_text()
            body = self._merge(old, new_body)
            om = re.match(r"^---\n(.*?)\n---\n", old, re.S)
            if om:
                keep = [ln for ln in om[1].split("\n") if not re.match(r"^(wiki|tags):", ln)]
                if keep:
                    front = front[:-4] + "\n".join(keep) + "\n---\n"
            text = front + body
            if old_path != path:
                self.stats["moved"] += 1
                if not self.dry:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    old_path.rename(path)
            if text != old:
                self.stats["changed"] += 1
        else:
            text = front + new_body
            self.stats["new"] += 1
        self.written.add(path.resolve())
        if not self.dry:
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists() or path.read_text() != text:
                path.write_text(text)

    @staticmethod
    def _merge(old, new_body):
        """The old page with its auto blocks replaced by the new ones; new blocks go after the block before them."""
        new_blocks = OrderedDict((m[1], m[0]) for m in AUTO_RE.finditer(new_body))
        old_body = re.sub(r"^---\n.*?\n---\n", "", old, count=1, flags=re.S)
        old_names = [m[1] for m in AUTO_RE.finditer(old_body)]
        # Title line: the generator's.
        old_body = re.sub(r"^# .*\n", new_body.split("\n", 1)[0] + "\n", old_body, count=1)

        def repl(m):
            blk = new_blocks.get(m[1])
            return blk if blk is not None else ""
        body = AUTO_RE.sub(repl, old_body)
        names = list(new_blocks)
        for i, name in enumerate(names):
            if name in old_names:
                continue
            before = next((n for n in reversed(names[:i]) if n in old_names or f"%% auto:{n} %%" in body), None)
            if before:
                end = body.find(f"%% /auto:{before} %%")
                end = body.find("\n", end) + 1
                body = body[:end] + "\n" + new_blocks[name] + body[end:]
            else:
                body = body.rstrip() + "\n\n" + new_blocks[name]
        return body

    def sweep(self, removed_dir):
        """Pages that weren't written this run: deleted, or moved aside if a person wrote on them."""
        for key, p in self.existing.items():
            if not p.exists() or p.resolve() in self.written:
                continue
            body = re.sub(r"^---\n.*?\n---\n", "", p.read_text(), count=1, flags=re.S)
            rest = AUTO_RE.sub("", body)
            rest = re.sub(r"^# .*\n", "", rest)
            rest = re.sub(r"(?m)^%% default %%.*$|^\*No walkthrough written yet\.\*$|^## (Walkthrough|Notes)\s*$", "",
                          rest)
            self.stats["removed"] += 1
            if self.dry:
                continue
            if rest.strip():
                dest = removed_dir / p.name
                dest.parent.mkdir(parents=True, exist_ok=True)
                p.rename(dest)
            else:
                p.unlink()


# --- Images -------------------------------------------------------------------------------------------------------

class Images:
    def __init__(self, game, out, enabled):
        self.g = game
        self.dir = out / "images"
        self.enabled = enabled and shutil.which("sips") is not None
        self.made = 0

    def _scaled(self, src, dest, size, fmt=None):
        if not src.exists():
            return False
        if dest.exists() and dest.stat().st_mtime >= src.stat().st_mtime:
            return True
        if not self.enabled:
            return dest.exists()
        dest.parent.mkdir(parents=True, exist_ok=True)
        cmd = ["sips", "-Z", str(size)]
        if fmt:
            cmd += ["-s", "format", fmt, "-s", "formatOptions", "78"]
        cmd += [str(src), "--out", str(dest)]
        r = subprocess.run(cmd, capture_output=True)
        if r.returncode == 0:
            self.made += 1
        return r.returncode == 0

    def portrait(self, art_id):
        """Wiki-relative embed path for a portrait, or ""."""
        if not art_id:
            return ""
        src = self.g.root / "art" / "portraits" / f"{art_id}.png"
        dest = self.dir / "portraits" / f"{art_id}.png"
        return f"images/portraits/{art_id}.png" if self._scaled(src, dest, 256) else ""

    def still(self, image):
        for ext in (".jpg", ".png", ".webp"):
            src = self.g.root / "art" / "cutscenes" / f"{image}{ext}"
            if src.exists():
                dest = self.dir / "cutscenes" / f"{image}.jpg"
                return f"images/cutscenes/{image}.jpg" if self._scaled(src, dest, 1200, "jpeg") else ""
        return ""

    def file(self, rel):
        return (self.dir.parent / rel).exists()


def embed(rel, width=None):
    if not rel:
        return ""
    return f"![[{WIKI}/{rel}{'|' + str(width) if width else ''}]]"


# --- Location maps (SVG) ------------------------------------------------------------------------------------------

MAP_COLOURS = {"#": "#2b2326", ".": "#6f6658", "=": "#8a6d3b", "~": "#3d5a6b", "w": "#2f4b5c", "^": "#4a5a3a",
               "_": "#4f4436", "1": "#7d7465", "2": "#857a69", "3": "#8c826f"}


def map_svg(game, lid, markers):
    """A plan of a location from its map rows, with numbered markers: [(n, cell, kind)]."""
    loc = game.locations[lid]
    rows = loc.get("map", {}).get("rows", [])
    if not rows:
        return ""
    s = 16
    w = max(len(r) for r in rows)
    h = len(rows)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w * s} {h * s}" width="{w * s}" height="{h * s}" '
           f'font-family="Georgia, serif">', f'<rect width="{w * s}" height="{h * s}" fill="#1a1416"/>']
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):
            ch = row[x]
            run = 1
            while x + run < len(row) and row[x + run] == ch:
                run += 1
            col = MAP_COLOURS.get(ch, "#6f6658" if ch not in "# " else "#2b2326")
            if ch != " ":
                out.append(f'<rect x="{x * s}" y="{y * s}" width="{run * s}" height="{s}" fill="{col}"/>')
            x += run
    for a in loc.get("areas", []):
        (x0, y0), (x1, y1) = a["cells"][0], a["cells"][1]
        cx, cy = (min(x0, x1) + max(x0, x1) + 1) / 2 * s, (min(y0, y1) + max(y0, y1) + 1) / 2 * s
        name = str(a.get("name", "")).replace("&", "&amp;").replace("<", "&lt;")
        out.append(f'<text x="{cx}" y="{cy}" font-size="10" text-anchor="middle" fill="#f0e2c0" fill-opacity="0.75" '
                   f'stroke="#120709" stroke-width="2.5" paint-order="stroke" font-style="italic">{name}</text>')
    kinds = {"npc": "#d9b45a", "container": "#c0574a", "hidden": "#a06cc0", "check": "#4fa3a3", "exit": "#e8e0c8",
             "fight": "#e0402e", "trap": "#ff8c1a", "door": "#9a8a6a"}
    for n, cell, kind in markers:
        cx, cy = (int(cell[0]) + 0.5) * s, (int(cell[1]) + 0.5) * s
        col = kinds.get(kind, "#ffffff")
        out.append(f'<circle cx="{cx}" cy="{cy}" r="{s * 0.62}" fill="{col}" stroke="#120709" stroke-width="2"/>')
        out.append(f'<text x="{cx}" y="{cy + 4}" font-size="{11 if n < 100 else 9}" text-anchor="middle" '
                   f'fill="#120709" font-weight="bold">{n}</text>')
    out.append("</svg>")
    return "\n".join(out)


# --- The wiki -----------------------------------------------------------------------------------------------------

class Wiki:
    def __init__(self, game, out, images=True, shots=None, dry=False):
        self.g = game
        self.out = out
        self.site = Site(game)
        self.w = Writer(out, dry)
        self.img = Images(game, out, images and not dry)
        self.shots = shots
        self.dry = dry
        self.head = self._git_head()
        self._index()

    def _git_head(self):
        try:
            return subprocess.run(["git", "-C", str(self.g.root), "rev-parse", "--short", "HEAD"],
                                  capture_output=True, text=True).stdout.strip()
        except OSError:
            return ""

    # Facts gathered once ------------------------------------------------------------------------------------------

    def _index(self):
        g, s = self.g, self.site
        for qid, q in g.quests.items():
            s.register(f"quest/{qid}", "Quests", q["name"], g.region_name(q.get("region", "")))
        for lid, l in g.locations.items():
            s.register(f"location/{lid}", "Locations", l["name"], g.region_name(l.get("region", "")))
        regions = OrderedDict()
        for rid in g.treasure.get("region_levels", {}):
            regions[rid] = True
        for l in g.locations.values():
            regions.setdefault(l.get("region", ""), True)
        self.regions = [r for r in regions if r]
        for rid in self.regions:
            s.register(f"region/{rid}", "Regions", g.region_name(rid))
        for nid, n in g.npcs.items():
            s.register(f"npc/{nid}", "People", n["name"], n.get("title", "") or g.region_name(n.get("region", "")))
        for mid, m in g.monsters.items():
            s.register(f"monster/{mid}", "Bestiary", m["name"])
        for cid, c in g.classes.items():
            s.register(f"class/{cid}", "Characters/Classes", c["name"])
        for sid, sp in g.spells.items():
            s.anchor(f"spell/{sid}", f"Spells/Level {sp.get('level', 0)} Spells" if sp.get("level") else
                     "Spells/Cantrips", sp["name"])
        self.item_sources = self._item_sources()
        for iid in self.item_sources:
            s.anchor(f"item/{iid}", "Items/Where to Find Items", g.item_name(iid))
        self.quest_files = self._quest_files()
        self.npc_places = self._npc_places()
        self.fights = self._fights()

    def _quest_files(self):
        """quest id -> {file key: set of nodes that move it}."""
        out = defaultdict(lambda: defaultdict(set))
        for key, node, st in self.g.statements({"quest"}):
            out[st["id"]][key].add(node)
        return out

    def _npc_places(self):
        """npc id -> [(location, cell, when, hours, dialogue)]"""
        out = defaultdict(list)
        for lid, loc in self.g.locations.items():
            for n in loc.get("npcs", []):
                out[n.get("npc", "")].append({"location": lid, "cell": n.get("cell"), "when": n.get("when", ""),
                                              "hours": n.get("hours"), "dialogue": n.get("dialogue", ""),
                                              "path": n.get("path")})
        return out

    def _fights(self):
        """encounter id -> [(location, encounter)] for every fight placed in a location."""
        out = defaultdict(list)
        for lid, loc in self.g.locations.items():
            for e in loc.get("encounters", []):
                out[e["id"]].append((lid, e))
        return out

    def where(self, entry, short=False):
        """Words for one way into a conversation."""
        g, s = self.g, self.site
        k = entry.get("kind")
        if k == "npc":
            area = g.area_name(entry["location"], entry.get("cell"))
            place = s.loc(entry["location"]) + (f" ({area})" if area and not short else "")
            return f"{s.npc(entry['npc'])} in {place}"
        if k == "prop":
            area = g.area_name(entry["location"], entry.get("cell"))
            return f"{entry['prop']} in {s.loc(entry['location'])}" + (f" ({area})" if area and not short else "")
        if k == "arrive":
            return f"arriving at {s.loc(entry['location'])}"
        src = entry.get("source", "")
        nice = {"strahd/visits": "one of Strahd's visits", "schedule/vallaki": "Vallaki's daily schedule"}
        if src.startswith("random_encounters/"):
            return "a random encounter on the road"
        if src.startswith("travel/"):
            return "the travel map"
        return nice.get(src, src.replace("_", " ").replace("/", ": "))

    def where_node(self, key, node, limit=4, short=False):
        seen, out = set(), []
        for e in self.g.places_for(key, node):
            w = self.where(e, short)
            if w not in seen:
                seen.add(w)
                out.append(w)
        if len(out) > limit:
            out = out[:limit] + [f"{len(out) - limit} more"]
        return out

    def _item_sources(self):
        """item id -> [source dicts]: where every item can be had, fixed placements first."""
        g = self.g
        out = defaultdict(list)
        for lid, loc in g.locations.items():
            spots = loc.get("treasure_spots") or {}
            spot_containers = {v.get("container") for v in spots.values()} if isinstance(spots, dict) else set()
            for c in loc.get("containers", []):
                for it in c.get("items", []):
                    out[it["id"]].append({"kind": "container", "location": lid, "label": c.get("label", c["id"]),
                                          "cell": c.get("cell"), "qty": it.get("qty", 1),
                                          "lock": c.get("lock_dc"), "owner": c.get("owner", ""),
                                          "when": c.get("when", ""), "key": c.get("key", "")})
            for p in loc.get("props", []):
                if p.get("item"):
                    out[p["item"]].append({"kind": "hidden", "location": lid, "label": p.get("label", p["id"]),
                                           "cell": p.get("cell"), "dc": p.get("search_dc"),
                                           "skill": p.get("skill", "perception"), "when": p.get("when", ""),
                                           "prop": p["id"]})
                for c in p.get("checks", []):
                    for it in (c.get("success") or {}).get("items", []):
                        out[it["id"]].append({"kind": "check", "location": lid, "label": p.get("label", p["id"]),
                                              "cell": p.get("cell"), "check": (skill_name(c["skill"]), c["dc"]),
                                              "qty": it.get("qty", 1)})
            for e in loc.get("encounters", []):
                for it in (e.get("loot") or {}).get("items", []):
                    out[it["id"]].append({"kind": "loot", "location": lid, "fight": e["id"], "qty": it.get("qty", 1),
                                          "quest": (e.get("quest") or {}).get("id", "")})
        for key, node, st in g.statements({"give"}):
            if st.get("to", "").startswith("npc"):
                continue
            quests = self._give_quests(key, node, st)
            out[st["item"]].append({"kind": "gift", "file": key, "node": node, "qty": st["qty"], "quests": quests})
        for nid, n in g.npcs.items():
            shop = n.get("shop") or {}
            for it in shop.get("sells", []):
                out[it["id"]].append({"kind": "shop", "npc": nid, "qty": it.get("qty", -1), "if": it.get("if", "")})
            for grp in (shop.get("rotating") or {}).get("groups", []):
                for iid in grp.get("pool", []):
                    out[iid].append({"kind": "shop", "npc": nid, "rotating": True})
        for iid, slot in TAROKKA_TREASURES.items():
            out[iid] = [x for x in out.get(iid, []) if x["kind"] != "gift"]
            out[iid].insert(0, {"kind": "tarokka", "slot": slot})
        return OrderedDict(sorted(out.items(), key=lambda kv: g.item_name(kv[0]).lower()))

    def _give_quests(self, key, node, give):
        """The quest a `give` pays out for: a `quest` line right after it in the same branch, else the node's."""
        sts = self.g.dialogues[key].nodes.get(node, [])
        i = sts.index(give)
        for st in sts[i + 1:]:
            if st["t"] in ("if", "elif", "else", "endif", "jump", "option"):
                break
            if st["t"] == "quest":
                return [st["id"]]
        for st in reversed(sts[:i]):
            if st["t"] in ("if", "elif", "else", "endif", "option"):
                break
            if st["t"] == "quest":
                return [st["id"]]
        return self._node_quests(key, node)

    def _node_quests(self, key, node):
        dlg = self.g.dialogues[key]
        qs = [st["id"] for st in dlg.nodes.get(node, []) if st["t"] == "quest"]
        if qs:
            return sorted(set(qs))
        allq = {st["id"] for sts in dlg.nodes.values() for st in sts if st["t"] == "quest"}
        if len(allq) == 1:
            return sorted(allq)
        base = key.split("/")[-1]
        return [base] if base in self.g.quests else []

    def source_words(self, src):
        g, s = self.g, self.site
        k = src["kind"]
        qty = f"{src['qty']} × " if src.get("qty", 1) not in (1, -1, None) else ""
        if k == "container":
            area = g.area_name(src["location"], src.get("cell"))
            extra = []
            if src.get("lock"):
                extra.append(f"locked, DC {src['lock']}")
            if src.get("key"):
                extra.append(f"key: {g.item_name(src['key'])}")
            if src.get("owner"):
                extra.append(f"belongs to {g.npc_name(src['owner'])}: taking it is theft")
            if src.get("when"):
                extra.append(f"only when {human_cond(src['when'])}")
            return (f"{qty}In {lower_article(src['label'])}, {s.loc(src['location'])}" + (f" ({area})" if area else "") +
                    (f" ({'; '.join(extra)})" if extra else ""))
        if k == "hidden":
            area = g.area_name(src["location"], src.get("cell"))
            dc = f"{skill_name(src.get('skill') or 'perception')} DC {src['dc']}" if src.get("dc") else "search"
            return (f"Hidden: {lower_article(src['label'])}, {s.loc(src['location'])}" + (f" ({area})" if area else "") +
                    f" (found with Search, {dc}" + (f"; only when {human_cond(src['when'])}" if src.get("when") else "")
                    + ")")
        if k == "check":
            return f"{qty}A {src['check'][0]} check (DC {src['check'][1]}) at {src['label']}, {s.loc(src['location'])}"
        if k == "loot":
            q = f", {s.quest(src['quest'])}" if src.get("quest") else ""
            return f"{qty}Loot from the fight in {s.loc(src['location'])}{q}"
        if k == "gift":
            who = self.where_node(src["file"], src["node"], limit=2, short=True)
            q = ", ".join(s.quest(x) for x in src.get("quests", []) if x in g.quests)
            text = f"{qty}Given" + (f" by {' or '.join(who)}" if who else "")
            return text + (f" ({q})" if q else "")
        if k == "tarokka":
            n = len(g.tarokka.get(src["slot"]) or {})
            return (f"Wherever Madam Eva's reading puts it: any of {n} places, one per card "
                    f"({s.link('page/tarokka', 'The Tarokka Reading')})")
        if k == "shop":
            if src.get("rotating"):
                return f"Sometimes in {s.npc(src['npc'])}'s changing stock ({s.link('page/merchants', 'Merchants')})"
            cond = f", only when {human_cond(src['if'])}" if src.get("if") else ""
            return f"Sold by {s.npc(src['npc'])}{cond}"
        return k

    # Shared bits ----------------------------------------------------------------------------------------------------

    def monsters_line(self, monsters):
        """'3 × Wolf, Dire Wolf (Old Greytooth)' for an encounter's monster list."""
        g, s = self.g, self.site
        groups = OrderedDict()
        for m in monsters:
            mid = m.get("monster", "")
            key = (mid, m.get("name", ""))
            groups[key] = groups.get(key, 0) + 1
        parts = []
        for (mid, name), n in groups.items():
            link = s.mon(mid)
            if name and name != g.monster_name(mid):
                link = f"{name} ({link})"
            parts.append(f"{n} × {link}" if n > 1 else link)
        return ", ".join(parts)

    def fight_label(self, e, quest=True):
        """A fight in words: its quest and its opening line, since its id is only for the game."""
        q = (e.get("quest") or {}).get("id", "")
        text = plain(e.get("text", ""), 110)
        bits = []
        if quest and q in self.g.quests:
            bits.append(self.site.quest(q))
        if text:
            bits.append(f"*{text}*")
        return " · ".join(bits) or title_id(e.get("id", "a fight"))

    def xp_of(self, monsters):
        return sum(int(self.g.monsters.get(m.get("monster", ""), {}).get("xp", 0) or 0) for m in monsters)

    def fight_block(self, eid, placements):
        """A fight's variants (level-scaled copies share an id) as markdown lines."""
        lines = []
        for lid, e in placements:
            cond = human_cond(e.get("when", ""))
            head = f"**{self.site.loc(lid)}**" + (f", when {cond}" if cond else "")
            extra = []
            if e.get("lair"):
                extra.append("lair")
            if e.get("surprise"):
                extra.append(f"surprise: {e['surprise']}")
            if e.get("loot"):
                lt = e["loot"]
                bits = [f"{lt['gold']} gp"] if lt.get("gold") else []
                bits += [self.site.item(i["id"]) + (f" ×{i['qty']}" if i.get("qty", 1) > 1 else "")
                         for i in lt.get("items", [])]
                extra.append("loot: " + ", ".join(bits))
            lines.append(f"- {head}: {self.monsters_line(e.get('monsters', []))} ({self.xp_of(e.get('monsters', []))} XP"
                         + (f"; {'; '.join(extra)}" if extra else "") + ")")
        return lines

    def shot(self, name):
        """A screenshot from the capture folder, copied into images/shots/; its embed path or ""."""
        dest = self.out / "images" / "shots" / (Path(name).stem + ".jpg")
        if self.shots:
            src = Path(self.shots) / name
            if src.exists() and not self.dry:
                if not dest.exists() or dest.stat().st_mtime < src.stat().st_mtime:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    if shutil.which("sips"):
                        subprocess.run(["sips", "-Z", "1280", "-s", "format", "jpeg", "-s", "formatOptions", "80",
                                        str(src), "--out", str(dest)], capture_output=True)
                    else:
                        shutil.copy2(src, dest)
        return f"images/shots/{dest.name}" if dest.exists() else ""

    def cutscene_stills(self, cid, width=480):
        c = self.g.cutscenes.get(cid)
        if not c:
            return []
        out = []
        for im in c.get("images", []):
            p = self.img.still(im.get("image", ""))
            if p:
                cond = human_cond(im.get("when", ""))
                out.append((p, cond))
        return out

    # Quests -------------------------------------------------------------------------------------------------------

    def quest_scope(self, qid):
        """{file key: nodes or None (the whole file)} for the conversations that belong to a quest."""
        g = self.g
        scope = {}
        for key, nodes in self.quest_files.get(qid, {}).items():
            dlg = g.dialogues[key]
            all_q = [st["id"] for sts in dlg.nodes.values() for st in sts if st["t"] == "quest"]
            mine = sum(1 for x in all_q if x == qid)
            if key.split("/")[-1] == qid or mine * 2 >= len(all_q):
                scope[key] = None
            else:
                # A shared file: the nodes that move this quest, and those a plain jump joins to them either way
                # (the speech before a quest line often sits in the node that jumps into it).
                jumps = {n: {st["to"] for st in sts if st["t"] == "jump" and st["to"] in dlg.nodes}
                         for n, sts in dlg.nodes.items()}
                near = set(nodes)
                for n in nodes:
                    near.update(jumps.get(n, ()))
                frontier = set(nodes)
                for _ in range(2):   # two plain jumps back
                    frontier = {n for n, js in jumps.items() if js & frontier} - near
                    near |= frontier
                scope[key] = near
        for key in g.dialogues:
            if key.split("/")[-1] == qid:
                scope[key] = None
        return scope

    def scoped_statements(self, scope):
        for key, nodes in scope.items():
            dlg = self.g.dialogues[key]
            for node, sts in dlg.nodes.items():
                if nodes is not None and node not in nodes:
                    continue
                for st in sts:
                    yield key, node, st

    def quest_pages(self):
        g, s = self.g, self.site
        self.quest_locations = defaultdict(set)
        self.npc_quests = defaultdict(set)
        for qid, q in g.quests.items():
            scope = self.quest_scope(qid)
            region = q.get("region", "")
            lvl = g.region_level(region)
            kind = "Main quest" if q.get("kind") == "main" else "Side quest"
            facts = [f"> [!info] {kind}", f"> {q.get('summary', '')}", ">"]
            facts.append(f"> **Region:** {s.region(region)}" + (f" (party level about {lvl})" if lvl else ""))
            if q.get("giver"):
                facts.append(f"> **Given by:** {s.npc(q['giver'])}")
                self.npc_quests[q["giver"]].add(qid)
            # Where it starts: the conversations that set its first stages.
            stage_ids = [st["id"] for st in q.get("stages", [])]
            set_at = defaultdict(list)
            for key, node, st in g.statements({"quest"}):
                if st["id"] == qid:
                    set_at[st["stage"]].append((key, node))
            starts, gates = [], []
            for sid in stage_ids:
                for key, node in set_at.get(sid, []):
                    for w in self.where_node(key, node, limit=3):
                        if w not in starts:
                            starts.append(w)
                    for e in g.places_for(key, node):
                        m = re.findall(r"level\s*>=\s*(\d+)", str(e.get("when", "")))
                        gates.append(max(int(x) for x in m) if m else 0)
                if starts:
                    break
            if starts:
                facts.append(f"> **Starts:** {'; '.join(starts[:4])}")
            if gates and min(gates) > 0:
                facts.append(f"> **Only from party level {min(gates)}:** whoever starts it isn't there before then.")
            # Fights, checks, rewards, people, places.
            fights = OrderedDict()
            checks, gifts, golds, approvals, cuts, people, places, gifts_dark = [], [], [], defaultdict(list), [], [], [], []
            xp_milestones = 0
            for key, node, st in self.scoped_statements(scope):
                t = st["t"]
                if t == "combat":
                    fights.setdefault(st["id"], None)
                elif t in ("option", "check") and st.get("check"):
                    sk, dc = st["check"]
                    txt = plain(st.get("text", ""), 90) if t == "option" else "(rolled in the scene)"
                    checks.append(f"{sk} DC {dc}: {txt}")
                elif t in ("give", "gold", "xp") and qid not in (self._give_quests(key, node, st) or [qid]):
                    pass   # paid out for another quest the same conversation moves
                elif t == "give":
                    gifts.append((st["item"], st["qty"]))
                elif t == "gold" and st["amount"] > 0:
                    golds.append(st["amount"])
                elif t == "approve":
                    for who, d in st["changes"]:
                        approvals[who].append((d, st.get("why", "")))
                elif t == "cutscene":
                    if st["arg"] not in cuts:
                        cuts.append(st["arg"])
                elif t == "xp" and "milestone" in st.get("arg", ""):
                    xp_milestones += 1
                elif t == "dark_gift":
                    gifts_dark.append(st["arg"])
                elif t == "line":
                    nid = g.speaker_npc.get(st["speaker"])
                    if nid and nid not in people:
                        people.append(nid)
                for e in g.places_for(key, node):
                    if e.get("kind") == "npc" and e["npc"] not in people:
                        people.append(e["npc"])
                    if e.get("location") and e["location"] not in places:
                        places.append(e["location"])
            for eid, plist in self.fights.items():
                for lid, e in plist:
                    if (e.get("quest") or {}).get("id") == qid:
                        fights.setdefault(eid, None)
            for lid in places:
                self.quest_locations[lid].add(qid)
            for nid in people:
                self.npc_quests[nid].add(qid)
            reward_bits = []
            if gifts:
                counts = OrderedDict()   # the most one ending gives: endings are usually either-or
                for iid, n in gifts:
                    counts[iid] = max(counts.get(iid, 0), n)
                reward_bits += [s.item(i) + (f" ×{n}" if n > 1 else "") for i, n in counts.items()]
            if golds:
                amounts = sorted(set(golds))
                reward_bits.append(f"{amounts[0]} gp" if len(amounts) == 1 else
                                   " or ".join(f"{a} gp" for a in amounts) + ", depending on how it goes")
            if xp_milestones:
                reward_bits.append("a level (milestone)")
            if reward_bits:
                facts.append(f"> **Rewards:** {', '.join(reward_bits)}")
            pic = self.shot(f"quest_{qid}.png")
            if pic:
                facts += ["", embed(pic, 900)]
            parts = [auto("facts", "\n".join(facts))]
            parts.append("## Walkthrough\n\n*No walkthrough written yet.*\n")
            # Journal stages.
            st_lines = ["## Journal stages", ""]
            for st in q.get("stages", []):
                end = {"success": " (ends: success)", "failure": " (ends: failure)"}.get(st.get("ends", ""), "")
                st_lines.append(f"### {title_id(st['id'])}{end}")
                st_lines.append(f"> {st.get('journal', '')}")
                for o in st.get("objectives", []):
                    st_lines.append(f"- [ ] {o}")
                if st.get("hint"):
                    st_lines.append(f"\n**Hint:** {st['hint']}")
                wh = []
                for key, node in set_at.get(st["id"], []):
                    for w in self.where_node(key, node, limit=2, short=True):
                        if w not in wh:
                            wh.append(w)
                if wh:
                    st_lines.append(f"\n*Reached through:* {'; '.join(wh[:4])}")
                st_lines.append("")
            parts.append(auto("stages", "\n".join(st_lines)))
            det = []
            if fights:
                det += ["## Fights", ""]
                for eid in fights:
                    pl = self.fights.get(eid, [])
                    if pl:
                        det.append(f"**{self.fight_label(pl[0][1], quest=False)}**" + (" (the first line your party fits is the fight you get)"
                                                              if len(pl) > 1 else ""))
                        det += self.fight_block(eid, pl)
                        det.append("")
            if checks:
                det += ["## Skill checks in conversation", ""]
                seen = []
                for c in checks:
                    if c not in seen:
                        seen.append(c)
                det += [f"- {c}" for c in seen[:40]] + [""]
            if approvals:
                det += ["## Companion approval", ""]
                for who, ch in approvals.items():
                    name = g.pregens.get(who, {}).get("name", g.npc_name(who))
                    bits = "; ".join(f"{'+' if d > 0 else ''}{d}: {why}" for d, why in ch[:6])
                    det.append(f"- **{name}:** {bits}")
                det.append("")
            if gifts_dark:
                det += ["## Dark gifts offered", ""] + [f"- {s.link('page/dark_gifts', g.dark_gifts.get(x, {}).get('name', title_id(x)))}" for x in gifts_dark] + [""]
            if people:
                det += ["## People", "", ", ".join(s.npc(n) for n in people if n in g.npcs), ""]
            if places:
                det += ["## Places", "", ", ".join(s.loc(lid) for lid in places), ""]
            if cuts:
                det += ["## Cutscenes", ""]
                for cid in cuts:
                    c = g.cutscenes.get(cid, {})
                    stills = self.cutscene_stills(cid)
                    det.append(f"**{c.get('title', title_id(cid))}**: {c.get('summary', '')}")
                    for p, cond in stills[:2]:
                        det.append(embed(p, 480) + (f"\n*({cond})*" if cond else ""))
                    det.append("")
            if det:
                parts.append(auto("details", "\n".join(det)))
            self.w.write(f"quest/{qid}", s.paths[f"quest/{qid}"], q["name"], parts,
                         tags=["wiki", "quest", "main-quest" if q.get("kind") == "main" else "side-quest"])
        self._quest_indexes()

    def _quest_indexes(self):
        g, s = self.g, self.site
        main = [q for q in MAIN_ORDER if q in g.quests and g.quests[q].get("kind") == "main"]
        main += [q for q, d in g.quests.items() if d.get("kind") == "main" and q not in main]
        lines = ["The story's spine, in the order it's usually played. Several run side by side: after Madam Eva's "
                 "reading the four treasures and the ally can be found in any order.", ""]
        for i, qid in enumerate(main, 1):
            q = g.quests[qid]
            lines.append(f"{i}. {s.quest(qid)} ({s.region(q.get('region', ''))}): {q.get('summary', '')}")
        s.paths["page/main_story"] = "Quests/Main Story"
        s.titles["page/main_story"] = "Main Story"
        self.w.write("page/main_story", "Quests/Main Story", "Main Story",
                     ["%% default %%\n", auto("list", "\n".join(lines))], tags=["wiki", "index"])
        by_region = defaultdict(list)
        for qid, q in g.quests.items():
            if q.get("kind") != "main":
                by_region[q.get("region", "")].append(qid)
        order = sorted(by_region, key=lambda r: (g.region_level(r) or 99, g.region_name(r)))
        lines = [f"{plural(sum(len(v) for v in by_region.values()), 'side quest')}, by region and the party level "
                 "they're built for. Most start from a rumour: ask the townsfolk *Heard anything interesting?*", ""]
        for rid in order:
            lvl = g.region_level(rid)
            lines += [f"## {g.region_name(rid)}" + (f" (level {lvl})" if lvl else ""), "",
                      "| Quest | Given by | What it's about |", "|---|---|---|"]
            for qid in sorted(by_region[rid], key=lambda x: g.quests[x]["name"]):
                q = g.quests[qid]
                giver = s.npc(q["giver"]) if q.get("giver") in g.npcs else ""
                lines.append(f"| {s.quest(qid)} | {giver} | {esc(q.get('summary', ''))} |")
            lines.append("")
        s.paths["page/side_quests"] = "Quests/Side Quests"
        s.titles["page/side_quests"] = "Side Quests"
        self.w.write("page/side_quests", "Quests/Side Quests", "Side Quests", [auto("list", "\n".join(lines))],
                     tags=["wiki", "index"])

    # Locations and regions --------------------------------------------------------------------------------------

    def location_pages(self):
        g, s = self.g, self.site
        for lid, loc in g.locations.items():
            region = loc.get("region", "")
            lvl = loc.get("treasure_level") or g.region_level(region)
            facts = [f"> [!info] {s.region(region)}" + (f" · party level about {lvl}" if lvl else ""),
                     f"> {loc.get('summary', '')}"]
            if loc.get("rest"):
                facts += [">", f"> **Resting:** {REST_WORDS.get(loc['rest'], loc['rest'])}" +
                          (f" {loc['rest_text']}" if loc.get("rest_text") else "")]
            if loc.get("map", {}).get("light"):
                facts.append(f"> **Light:** {loc['map']['light']}" + (", outdoors" if loc["map"].get("outdoors") else ""))
            body = facts[:]
            if loc.get("text"):
                body += ["", loc["text"]]
            shots = [self.shot(f"loc_{lid}_overview.png")] + [self.shot(f"loc_{lid}_{i}.png") for i in (1, 2, 3)]
            shots = [x for x in shots if x]
            if shots:
                body += ["", embed(shots[0], 900)]
            parts = [auto("about", "\n".join(body))]
            # Numbered map markers and the tables that explain them.
            markers, at_cell = [], {}

            def mark(cell, kind):
                """One number per square, so people and things sharing a square share a dot."""
                key = (int(cell[0]), int(cell[1]))
                if key not in at_cell:
                    at_cell[key] = len(at_cell) + 1
                    markers.append((at_cell[key], cell, kind))
                return at_cell[key]
            people, chests, hidden, checks, exits, traps, doors, reads = [], [], [], [], [], [], [], []
            for e in loc.get("exits", []):
                n = mark(e["cell"], "exit")
                to = "the travel map" if e.get("to") == "travel" else s.loc(e["to"])
                cond = human_cond(e.get("when", ""))
                exits.append(f"| {n} | {esc(e.get('label', ''))} | {to} | {esc(cond)} |")
            for p in loc.get("npcs", []):
                n = mark(p["cell"], "npc")
                hrs = p.get("hours")
                when = human_cond(p.get("when", ""))
                bits = []
                if hrs:
                    bits.append(f"{hrs[0]:02d}:00–{hrs[1]:02d}:00")
                if when:
                    bits.append(f"when {when}")
                if p.get("asleep"):
                    bits.append("asleep")
                people.append(f"| {n} | {s.npc(p['npc'])} | {esc(g.area_name(lid, p['cell']))} | {esc('; '.join(bits))} |")
            for c in loc.get("containers", []):
                n = mark(c["cell"], "container")
                inside = [s.item(i["id"]) + (f" ×{i['qty']}" if i.get("qty", 1) > 1 else "") for i in c.get("items", [])]
                if c.get("gold"):
                    inside.append(f"{c['gold']} gp")
                notes = []
                if c.get("lock_dc"):
                    notes.append(f"lock DC {c['lock_dc']}")
                if c.get("key"):
                    notes.append(f"key: {s.item(c['key'])}")
                if c.get("owner"):
                    notes.append(f"{g.npc_name(c['owner'])}'s (theft)")
                if c.get("when"):
                    notes.append(f"when {human_cond(c['when'])}")
                chests.append(f"| {n} | {esc(c.get('label', c['id']))} | {esc(', '.join(inside) or 'empty')} | "
                              f"{esc('; '.join(notes))} |")
            for p in loc.get("props", []):
                if p.get("item"):
                    n = mark(p["cell"], "hidden")
                    dc = f"{skill_name(p.get('skill', 'perception'))} DC {p['search_dc']}" if p.get("search_dc") else ""
                    hidden.append(f"| {n} | {esc(p.get('label', p['id']))} | {s.item(p['item'])} | {dc} |")
                if p.get("checks"):
                    n = mark(p["cell"], "check")
                    for c in p["checks"]:
                        checks.append(f"| {n} | {esc(p.get('label', p['id']))} | {skill_name(c['skill'])} {c['dc']} | "
                                      f"{esc(c.get('label', ''))} | {esc(self.check_result(lid, c))} |")
                if p.get("kind") == "book" or p.get("codex"):
                    if p.get("text"):
                        reads.append((p.get("label", p["id"]), p["text"], human_cond(p.get("when", ""))))
            for t in loc.get("traps", []):
                n = mark(t["cells"][0], "trap")
                sv = t.get("save") or {}
                traps.append(f"| {n} | {esc(t.get('label', t['id']))} | {t.get('detect_dc', '')} | "
                             f"{t.get('disarm_dc', '—')} | {sv.get('ability', '').upper()} {sv.get('dc', '')} | "
                             f"{t.get('damage', '')} {t.get('damage_type', '')} |")
            for d in loc.get("doors", []):
                if d.get("lock_dc") or d.get("secret_dc") or d.get("key") or d.get("locked"):
                    bits = []
                    if d.get("lock_dc"):
                        bits.append(f"lock DC {d['lock_dc']}")
                    if d.get("secret_dc"):
                        bits.append(f"secret, found at DC {d['secret_dc']}")
                    if d.get("key"):
                        bits.append(f"opens with {s.item(d['key'])}")
                    if d.get("locked") and not d.get("lock_dc"):
                        bits.append("barred")
                    if d.get("unlocked_when"):
                        bits.append(f"opens when {human_cond(d['unlocked_when'])}")
                    doors.append(f"- {d.get('label', d['id'])}: {', '.join(bits)}")
            svg = map_svg(g, lid, markers)
            mp = []
            if svg and not self.dry:
                p = self.out / "images" / "maps" / f"{lid}.svg"
                p.parent.mkdir(parents=True, exist_ok=True)
                if not p.exists() or p.read_text() != svg:
                    p.write_text(svg)
            if svg:
                mp += ["## Map", "", embed(f"images/maps/{lid}.svg"), "",
                       "Gold dots are people, red containers, purple hidden finds, teal skill checks, white exits, "
                       "orange traps. The numbers match the tables below.", ""]
            if len(shots) > 1:
                mp += ["", " ".join(embed(x, 300) for x in shots[1:]), ""]
            if exits:
                mp += ["## Ways out", "", "| # | Exit | Leads to | Only when |", "|---|---|---|---|"] + exits + [""]
            if people:
                mp += ["## People here", "", "| # | Who | Where | When |", "|---|---|---|---|"] + people + [""]
            if chests:
                mp += ["## Containers", "", "| # | Container | Inside | Notes |", "|---|---|---|---|"] + chests + [""]
            spots = loc.get("treasure_spots") or {}
            if isinstance(spots, dict) and spots:
                mp += ["**Tarokka treasure spots.** If the reading hid one of the treasures here, it's in: " +
                       "; ".join(f"{title_id(k)} ({v.get('container', '')})" for k, v in spots.items()), ""]
            mp += [f"Containers can also hold random magic items, rolled for a party of level {lvl or 5} the first "
                   f"time you come here ({s.link('page/random_treasure', 'Random Treasure')}).", ""]
            if hidden:
                mp += ["## Hidden finds", "", "Press Search (F) near the spot; the best Perception in the party "
                       "rolls against the DC.", "", "| # | Where | What | DC |", "|---|---|---|---|"] + hidden + [""]
            if checks:
                mp += ["## Skill checks", "", "| # | Where | Check | Try | What it does |", "|---|---|---|---|---|"] \
                      + checks + [""]
            if traps:
                mp += ["## Traps", "", "| # | Trap | Find DC | Disarm DC | Save | Damage |", "|---|---|---|---|---|---|"] \
                      + traps + [""]
            if doors:
                mp += ["## Locked and secret doors", ""] + doors + [""]
            parts.append(auto("map", "\n".join(mp)))
            fl = []
            encs = OrderedDict()
            for e in loc.get("encounters", []):
                encs.setdefault(e["id"], []).append((lid, e))
            if encs:
                fl += ["## Fights", ""]
                for eid, pl in encs.items():
                    e0 = pl[0][1]
                    q = e0.get("quest") or {}
                    head = f"**{self.fight_label(e0, quest=False)}**" + \
                        (f" ({s.quest(q['id'])})" if q.get("id") in g.quests else "")
                    fl.append(head)
                    if len(pl) > 1:
                        fl.append("*The first line your party fits is the fight you get.*")
                    for lid2, e in pl:
                        cond = human_cond(e.get("when", ""))
                        fl.append(f"- {self.monsters_line(e.get('monsters', []))} ({self.xp_of(e.get('monsters', []))} XP)"
                                  + (f", when {cond}" if cond else ""))
                    fl.append("")
            qs = sorted(self.quest_locations.get(lid, ()), key=lambda x: g.quests[x]["name"])
            if qs:
                fl += ["## Quests here", "", ", ".join(s.quest(x) for x in qs), ""]
            if reads:
                fl += ["## Things to read", ""]
                for label, text, cond in reads:
                    fl.append(f"> [!quote]- {label}" + (f" (when {cond})" if cond else ""))
                    for para in str(text).split("\n"):
                        fl.append(f"> {para}")
                    fl.append("")
            if fl:
                parts.append(auto("more", "\n".join(fl)))
            self.w.write(f"location/{lid}", s.paths[f"location/{lid}"], loc["name"], parts,
                         tags=["wiki", "location"])
        self._region_pages()

    def check_result(self, lid, c):
        g, s = self.g, self.site
        out = []
        succ = c.get("success") or {}
        loc = g.locations.get(lid, {})
        props = {p["id"]: p for p in loc.get("props", [])}
        for pid in succ.get("reveal", []):
            p = props.get(pid, {})
            if p.get("item"):
                out.append(f"finds {g.item_name(p['item'])}")
            else:
                out.append(f"reveals {p.get('label', pid)}")
        if succ.get("gold"):
            out.append(f"{succ['gold']} gp")
        for it in succ.get("items", []):
            out.append(g.item_name(it["id"]) + (f" ×{it['qty']}" if it.get("qty", 1) > 1 else ""))
        if succ.get("codex"):
            out.append(f"lore: {succ['codex'].get('title', '')}")
        if succ.get("inspiration"):
            out.append("Heroic Inspiration")
        if succ.get("heal"):
            out.append(f"heals {succ['heal']}")
        if succ.get("temp_hp"):
            out.append(f"{succ['temp_hp']} temporary HP")
        if succ.get("unlock"):
            out.append("unlocks " + ", ".join(succ["unlock"]).replace("_", " "))
        if succ.get("disarm"):
            out.append("disarms " + ", ".join(succ["disarm"]).replace("_", " "))
        if succ.get("flag"):
            out.append(succ["flag"].replace("_", " "))
        fail = c.get("failure") or {}
        if fail.get("damage"):
            out.append(f"on a failure: {fail['damage']} {fail.get('damage_type', '')} damage")
        elif fail:
            out.append("on a failure: " + ", ".join(f"{k} {v}" for k, v in fail.items() if not isinstance(v, (dict, list))))
        return "; ".join(out)

    def _region_pages(self):
        g, s = self.g, self.site
        card = (g.loading.get("regions") or {})
        for rid in self.regions:
            lvl = g.region_level(rid)
            lines = []
            img = card.get(rid)
            if img:
                p = self.img.still(img)
                if p:
                    lines += [embed(p, 900), ""]
            if lvl:
                lines.append(f"Built for a party of about level {lvl}: random treasure here is rolled for that level.")
                lines.append("")
            locs = [lid for lid, l in g.locations.items() if l.get("region") == rid]
            if locs:
                lines += ["## Places", ""] + [f"- {s.loc(x)}: {g.locations[x].get('summary', '')}" for x in locs] + [""]
            qs = [q for q, d in g.quests.items() if d.get("region") == rid]
            if qs:
                lines += ["## Quests", ""] + [f"- {s.quest(q)}" + (" (main)" if g.quests[q].get("kind") == "main" else "")
                                             for q in sorted(qs, key=lambda x: g.quests[x]["name"])] + [""]
            ppl = [n for n, d in g.npcs.items() if d.get("region") == rid]
            if ppl:
                lines += ["## People", "", ", ".join(s.npc(n) for n in sorted(ppl, key=g.npc_name)), ""]
            shops = [n for n in ppl if g.npcs[n].get("shop")]
            if shops:
                lines += ["## Merchants", "", ", ".join(s.link("page/merchants", g.npc_name(n)) for n in shops), ""]
            roads = [r for r, d in g.random_encounters.items() if r.startswith(rid) or rid in d.get("summary", "").lower()]
            self.w.write(f"region/{rid}", s.paths[f"region/{rid}"], g.region_name(rid),
                         ["%% default %%\n", auto("region", "\n".join(lines))], tags=["wiki", "region"])
        lines = []
        for rid in sorted(self.regions, key=lambda r: (g.region_level(r) or 99)):
            lvl = g.region_level(rid)
            lines.append(f"## {s.region(rid)}" + (f" (level {lvl})" if lvl else ""))
            lines.append("")
            for lid, l in g.locations.items():
                if l.get("region") == rid:
                    lines.append(f"- {s.loc(lid)}: {l.get('summary', '')}")
            lines.append("")
        travel = self.shot("travel_map.png")
        head = []
        if travel:
            head = [embed(travel, 1000), ""]
        head += ["Barovia is crossed on the travel map (M): pick a place you know of and the party walks there, "
                 "with the time it takes and a chance of meeting something on the road "
                 f"({s.link('page/random_encounters', 'Random Encounters')}). New places join the map as you hear of them.", ""]
        self.w.write("page/locations", "Locations/All Locations", "All Locations", [auto("list", "\n".join(head + lines))],
                     tags=["wiki", "index"])

    # People -----------------------------------------------------------------------------------------------------

    def npc_pages(self):
        g, s = self.g, self.site
        for nid, n in g.npcs.items():
            pic = self.img.portrait(n.get("portrait", nid))
            facts = []
            if pic:
                facts.append(embed(pic, 200))
                facts.append("")
            facts.append(f"> [!info] {n.get('title', '')}" if n.get("title") else "> [!info]")
            facts.append(f"> {n.get('summary', '')}")
            facts.append(">")
            if n.get("region"):
                facts.append(f"> **Region:** {s.region(n['region'])}")
            if n.get("attitude"):
                facts.append(f"> **Starting attitude:** {n['attitude']}")
            if n.get("pronouns"):
                facts.append(f"> **Pronouns:** {n['pronouns']}")
            if n.get("monster") and n["monster"] in g.monsters:
                facts.append(f"> **In a fight:** {s.mon(n['monster'])}")
            if n.get("guest"):
                facts.append("> **Can travel with the party** as a guest.")
            parts = [auto("about", "\n".join(facts))]
            lines = []
            places = self.npc_places.get(nid, [])
            if places:
                lines += ["## Where to find them", ""]
                for p in places:
                    area = g.area_name(p["location"], p.get("cell"))
                    bits = []
                    if p.get("hours"):
                        bits.append(f"{p['hours'][0]:02d}:00–{p['hours'][1]:02d}:00")
                    if p.get("when"):
                        bits.append(f"when {human_cond(p['when'])}")
                    if p.get("path"):
                        bits.append("walks a round")
                    lines.append(f"- {s.loc(p['location'])}" + (f", {area}" if area else "") +
                                 (f" ({'; '.join(bits)})" if bits else ""))
                lines.append("")
            if n.get("shop"):
                lines += ["## Merchant", "", f"Sells and buys goods: see {s.link('page/merchants', 'Merchants')} "
                          f"(#{n['name']}).", ""]
            if n.get("services"):
                lines += ["## Services", ""]
                for sv in n["services"]:
                    lines.append(f"- {self.service_name(sv['id'])}" + (f" (when {human_cond(sv['if'])})" if sv.get("if") else ""))
                lines.append("")
            qs = sorted(self.npc_quests.get(nid, ()), key=lambda x: g.quests[x]["name"])
            if qs:
                lines += ["## Quests", ""] + [f"- {s.quest(q)}" + (" (gives it)" if g.quests[q].get("giver") == nid else "")
                                             for q in qs] + [""]
            if lines:
                parts.append(auto("where", "\n".join(lines)))
            self.w.write(f"npc/{nid}", s.paths[f"npc/{nid}"], n["name"], parts, tags=["wiki", "person"])
        by_region = defaultdict(list)
        for nid, n in g.npcs.items():
            by_region[n.get("region", "")].append(nid)
        lines = [f"{plural(len(g.npcs), 'person', 'people')} you can meet in Barovia, by region.", ""]
        for rid in sorted(by_region, key=lambda r: (g.region_level(r) or 99, g.region_name(r))):
            lines += [f"## {g.region_name(rid) if rid else 'Elsewhere'}", "", "| | Who | Title |", "|---|---|---|"]
            for nid in sorted(by_region[rid], key=g.npc_name):
                n = g.npcs[nid]
                pic = self.img.portrait(n.get("portrait", nid))
                lines.append(f"| {embed(pic, 48).replace('|', chr(92) + '|') if pic else ''} | {s.npc(nid)} | {esc(n.get('title', ''))} |")
            lines.append("")
        self.w.write("page/people", "People/All People", "All People", [auto("list", "\n".join(lines))],
                     tags=["wiki", "index"])

    # Bestiary ---------------------------------------------------------------------------------------------------

    def monster_pages(self):
        g, s = self.g, self.site
        met = defaultdict(list)
        for lid, loc in g.locations.items():
            for e in loc.get("encounters", []):
                for m in e.get("monsters", []):
                    if (lid, e["id"]) not in [(a, b) for a, b, _ in met[m.get("monster")]]:
                        met[m.get("monster")].append((lid, e["id"], e))
        roads = defaultdict(list)
        for rid, r in g.random_encounters.items():
            for e in r.get("entries", []):
                for m in e.get("monsters", []):
                    if rid not in roads[m.get("monster")]:
                        roads[m.get("monster")].append(rid)
        for mid, m in g.monsters.items():
            pic = self.img.portrait(m.get("art", mid))
            ab = m.get("abilities", {})
            hp = m.get("hp", {})
            speed = ", ".join(f"{k} {v} ft" if k != "walk" else f"{v} ft" for k, v in (m.get("speed") or {}).items()
                              if not isinstance(v, bool))
            lines = []
            if pic:
                lines += [embed(pic, 220), ""]
            lines.append(f"*{m.get('size', '').title()} {m.get('type', '')}, {m.get('alignment', '')}*")
            lines.append("")
            if m.get("summary"):
                lines += [m["summary"], ""]
            lines += ["| AC | HP | Speed | CR | XP |", "|---|---|---|---|---|",
                      f"| {m.get('ac', '')} | {hp.get('average', '')} ({hp.get('dice', '')}) | {speed} | "
                      f"{self.cr(m.get('cr'))} | {m.get('xp', '')} |", "",
                      "| STR | DEX | CON | INT | WIS | CHA |", "|---|---|---|---|---|---|",
                      "| " + " | ".join(f"{ab.get(a, 10)} ({(ab.get(a, 10) - 10) // 2:+d})" for a in ABILITIES) + " |", ""]
            facts = []
            if m.get("saves"):
                facts.append("**Saving throws:** " + ", ".join(f"{k.upper()} {v:+d}" for k, v in m["saves"].items()))
            if m.get("skills"):
                facts.append("**Skills:** " + ", ".join(f"{skill_name(k)} {v:+d}" for k, v in m["skills"].items()))
            for k, label in (("vulnerabilities", "Vulnerable"), ("resistances", "Resistant"), ("immunities", "Immune"),
                             ("damage_immunities", "Immune"), ("condition_immunities", "Condition immunities")):
                if m.get(k):
                    facts.append(f"**{label}:** " + ", ".join(str(x).replace("_", " ") for x in m[k]))
            if m.get("senses"):
                sn = m["senses"]
                facts.append("**Senses:** " + (", ".join(f"{k} {v} ft" for k, v in sn.items()) if isinstance(sn, dict)
                                               else str(sn)) + f"; passive Perception {m.get('passive_perception', '')}")
            if m.get("languages"):
                facts.append("**Languages:** " + ", ".join(m["languages"]))
            lines += [f"- {f}" for f in facts] + [""]
            for k, label in (("traits", "Traits"), ("actions", "Actions"), ("bonus_actions", "Bonus actions"),
                             ("reactions", "Reactions"), ("legendary_actions", "Legendary actions"),
                             ("lair_actions", "Lair actions")):
                acts = m.get(k) or []
                if isinstance(acts, dict):
                    acts = acts.get("actions", [])
                if acts:
                    lines += [f"### {label}", ""]
                    for a in acts:
                        lines.append(f"- **{a.get('name', title_id(a.get('id', '')))}.** {a.get('text') or a.get('summary', '')}")
                    lines.append("")
            parts = [auto("stats", "\n".join(lines))]
            wl = []
            if met.get(mid):
                wl += ["## Where you meet it", ""]
                seen = []
                for lid, eid, e in met[mid]:
                    t = f"- {s.loc(lid)}: {self.fight_label(e)}"
                    if t not in seen:
                        seen.append(t)
                wl += seen[:30] + [""]
            if roads.get(mid):
                wl += ["On the road: " + ", ".join(s.link("page/random_encounters", title_id(r)) for r in roads[mid]), ""]
            if wl:
                parts.append(auto("where", "\n".join(wl)))
            self.w.write(f"monster/{mid}", s.paths[f"monster/{mid}"], m["name"], parts, tags=["wiki", "monster"])
        lines = [f"Every creature the party can fight: {len(g.monsters)} of them. The journal's Bestiary tab fills in "
                 "as you meet, fell and Study them.", "", "| | Creature | Type | CR | XP | AC | HP |",
                 "|---|---|---|---|---|---|---|"]
        for mid, m in sorted(g.monsters.items(), key=lambda kv: (float(kv[1].get("cr", 0) or 0), kv[1]["name"])):
            pic = self.img.portrait(m.get("art", mid))
            lines.append(f"| {embed(pic, 48).replace('|', chr(92) + '|') if pic else ''} | {s.mon(mid)} | "
                         f"{m.get('type', '')} | {self.cr(m.get('cr'))} | {m.get('xp', '')} | {m.get('ac', '')} | "
                         f"{(m.get('hp') or {}).get('average', '')} |")
        self.w.write("page/bestiary", "Bestiary/All Creatures", "Bestiary", [auto("list", "\n".join(lines))],
                     tags=["wiki", "index"])

    @staticmethod
    def cr(v):
        return {0.125: "1/8", 0.25: "1/4", 0.5: "1/2"}.get(v, str(int(v)) if isinstance(v, (int, float)) and v == int(v)
                                                           else str(v))

    # Items ------------------------------------------------------------------------------------------------------

    def item_pages(self):
        g, s = self.g, self.site
        groups = OrderedDict([("Magic items", []), ("Story items, keys and letters", []), ("Equipment and supplies", [])])
        for iid in self.item_sources:
            d = g.item_data(iid)
            if d.get("magic") or iid.split("__")[0] in g.magic:
                groups["Magic items"].append(iid)
            elif d.get("category") in ("quest",) or not d:
                groups["Story items, keys and letters"].append(iid)
            else:
                groups["Equipment and supplies"].append(iid)
        lines = ["Every item placed in the world, given by someone or sold, and where to get it. Containers and "
                 "hidden finds are numbered on each place's map. Random magic items rolled into containers are on top "
                 f"of these ({s.link('page/random_treasure', 'Random Treasure')}); merchants' prices are on "
                 f"{s.link('page/merchants', 'Merchants')}.", ""]
        for gname, ids in groups.items():
            lines += [f"## {gname}", ""]
            for iid in ids:
                d = g.item_data(iid)
                lines.append(f"### {g.item_name(iid)}")
                meta = []
                if d.get("magic"):
                    meta.append(str(d["magic"].get("rarity", "")).replace("_", " "))
                    if d["magic"].get("attunement"):
                        meta.append("attunement")
                if d.get("category"):
                    meta.append(d["category"])
                if meta or d.get("summary"):
                    lines.append(f"*{', '.join(meta)}*" + (f". {d.get('summary', '')}" if d.get("summary") else ""))
                srcs = self.item_sources[iid]
                shops = [x for x in srcs if x["kind"] == "shop"]
                others = [x for x in srcs if x["kind"] != "shop"]
                for x in others[:25]:
                    lines.append(f"- {self.source_words(x)}")
                if len(others) > 25:
                    lines.append(f"- …and {len(others) - 25} more places")
                if shops:
                    fixed = sorted({g.npc_name(x["npc"]) for x in shops if not x.get("rotating")})
                    rot = sorted({g.npc_name(x["npc"]) for x in shops if x.get("rotating")})
                    if fixed:
                        lines.append(f"- Sold by: {', '.join(s.npc(next(k for k, v in g.npcs.items() if v['name'] == f), f) for f in fixed)}")
                    if rot:
                        lines.append(f"- Sometimes in the changing stock of: {', '.join(rot)}")
                lines.append("")
        self.w.write("page/item_sources", "Items/Where to Find Items", "Where to Find Items",
                     [auto("list", "\n".join(lines))], tags=["wiki", "items"])
        # The magic item catalogue, by rarity.
        lines = [f"All {len(g.magic)} magic items in the game, by rarity. Most turn up as random treasure "
                 f"({s.link('page/random_treasure', 'Random Treasure')}); those with a fixed home link to it.", ""]
        by_r = defaultdict(list)
        for iid, d in g.magic.items():
            if d.get("playable", True):
                by_r[(d.get("magic") or {}).get("rarity", "common")].append(iid)
        for r in RARITIES:
            if not by_r.get(r):
                continue
            lines += [f"## {r.replace('_', ' ').title()} ({len(by_r[r])})", "",
                      "| Item | Type | Attune | What it does | Placed |", "|---|---|---|---|---|"]
            for iid in sorted(by_r[r], key=lambda x: g.magic[x]["name"]):
                d = g.magic[iid]
                placed = [k for k in self.item_sources if k == iid or k.startswith(iid + "__")]
                where = " ".join(s.item(k, "where") for k in placed[:1]) if placed else ""
                lines.append(f"| {esc(d['name'])} | {d.get('category', '')} | "
                             f"{'yes' if (d.get('magic') or {}).get('attunement') else ''} | "
                             f"{esc(d.get('summary', ''))} | {where} |")
            lines.append("")
        self.w.write("page/magic_items", "Items/Magic Items", "Magic Items", [auto("list", "\n".join(lines))],
                     tags=["wiki", "items"])
        # Mundane equipment.
        lines = ["The everyday gear of the 2024 Player's Handbook as this game prices it. Merchants charge their own "
                 f"markup on these ({s.link('page/merchants', 'Merchants')}).", ""]
        weapons = [d for d in g.items.values() if d.get("category") == "weapon"]
        if weapons:
            lines += ["## Weapons", "", "| Weapon | Kind | Damage | Properties | Mastery | Cost | Weight |",
                      "|---|---|---|---|---|---|---|"]
            for d in sorted(weapons, key=lambda d: (d.get("weapon", {}).get("kind", ""), d["name"])):
                w = d.get("weapon", {})
                props = ", ".join(str(p).replace("_", " ") for p in w.get("properties", []))
                if w.get("versatile"):
                    props += f" ({w['versatile']})"
                if w.get("range"):
                    rg = w["range"]
                    props += f" (range {rg[0]}/{rg[1]})" if isinstance(rg, list) else f" (range {rg})"
                lines.append(f"| {d['name']} | {w.get('kind', '').replace('_', ' ')} | {w.get('damage', '')} "
                             f"{w.get('damage_type', '')} | {props} | {w.get('mastery', '')} | {self.gp(d.get('cost_gp'))} | "
                             f"{d.get('weight_lb', '')} lb |")
            lines.append("")
        armor = [d for d in g.items.values() if d.get("category") in ("armor", "shield")]
        if armor:
            lines += ["## Armor", "", "| Armor | Kind | AC | Strength | Stealth | Cost | Weight |",
                      "|---|---|---|---|---|---|---|"]
            for d in sorted(armor, key=lambda d: (d.get("armor", {}).get("kind", ""), d.get("cost_gp", 0))):
                a = d.get("armor", {})
                ac = f"{a.get('base_ac', '')}"
                if a.get("kind") == "shield":
                    ac = f"+{a.get('base_ac', 2)}"
                elif a.get("dex_cap") is None:
                    ac += " + Dex"
                elif a.get("dex_cap"):
                    ac += f" + Dex (max {a['dex_cap']})"
                lines.append(f"| {d['name']} | {a.get('kind', '')} | {ac} | {a.get('strength', '') or ''} | "
                             f"{'Disadvantage' if a.get('stealth_disadvantage') else ''} | {self.gp(d.get('cost_gp'))} | "
                             f"{d.get('weight_lb', '')} lb |")
            lines.append("")
        rest = [d for d in g.items.values() if d.get("category") not in ("weapon", "armor", "shield", "quest")]
        cats = defaultdict(list)
        for d in rest:
            cats[d.get("category", "gear")].append(d)
        for c in sorted(cats):
            lines += [f"## {c.replace('_', ' ').title()}", "", "| Item | What it does | Cost | Weight |", "|---|---|---|---|"]
            for d in sorted(cats[c], key=lambda d: d["name"]):
                lines.append(f"| {d['name']} | {esc(d.get('summary', ''))} | {self.gp(d.get('cost_gp'))} | "
                             f"{d.get('weight_lb', '')} lb |")
            lines.append("")
        self.w.write("page/equipment", "Items/Equipment", "Equipment", [auto("list", "\n".join(lines))],
                     tags=["wiki", "items"])
        # Random treasure.
        t = g.treasure
        lines = [plain(t.get("_note", "")), "", "## Party level by region", "", "| Region | Level |", "|---|---|"]
        for rid, lvl in sorted(t.get("region_levels", {}).items(), key=lambda kv: kv[1]):
            lines.append(f"| {s.region(rid)} | {lvl} |")
        lines.append("")
        for k, v in t.items():
            if k in ("_note", "region_levels") or not isinstance(v, (dict, list)):
                continue
            lines += [f"## {title_id(k)}", "", "```json", json.dumps(v, indent=1)[:3000], "```", ""]
        self.w.write("page/random_treasure", "Items/Random Treasure", "Random Treasure", [auto("list", "\n".join(lines))],
                     tags=["wiki", "items"])

    @staticmethod
    def gp(v):
        if v in (None, ""):
            return ""
        v = float(v)
        if v >= 1:
            return f"{v:g} gp"
        if v * 10 >= 1:
            return f"{v * 10:g} sp"
        return f"{v * 100:g} cp"

    # Merchants and services -------------------------------------------------------------------------------------

    def _services(self):
        src = (self.g.root / "story" / "services.gd").read_text()
        out = OrderedDict()
        for m in re.finditer(r'^\t"([a-z_]+)": \{(.*?)\},?\n(?=\t"|\})', src, re.S | re.M):
            body = m[2]
            get = lambda k: (re.search(rf'"{k}":\s*("([^"]*)"|[\d.]+)', body) or [None, None, None])
            name = get("name")[2]
            price = get("price")[1]
            each = get("each")[1]
            text = get("text")[2]
            out[m[1]] = {"name": name or title_id(m[1]), "price": price, "each": each, "text": text or ""}
        return out

    def service_name(self, sid):
        return self._services().get(sid, {}).get("name", title_id(sid))

    def merchant_page(self):
        g, s = self.g, self.site
        trade = (g.root / "story" / "trade.gd").read_text()
        dc = re.search(r"const HAGGLE_DC := (\d+)", trade)
        lines = ["## How prices work", "",
                 "- Each merchant marks up the book price of what they sell (their markup below) and pays a share of "
                 "it for what they buy (their rate). Every price is rounded up to a whole gold piece.",
                 "- A merchant's attitude to the party changes both: friendly takes 10% off and pays 10% more; "
                 "hostile charges 25% more and pays 25% less.",
                 f"- **Haggling:** one Persuasion check by the hero at the counter, DC {dc[1] if dc else 15} unless "
                 "the shop says otherwise. Win and that merchant gives you a further 10% both ways for good; lose and "
                 "they never haggle with you again.",
                 "- Some merchants close at night or until something happens; some stock only appears after a quest.",
                 ""]
        services = self._services()
        for nid, n in g.npcs.items():
            shop = n.get("shop")
            if not shop:
                continue
            pic = self.img.portrait(n.get("portrait", nid))
            lines.append(f"## {n['name']}")
            if pic:
                lines.append(embed(pic, 96))
            places = self.npc_places.get(nid, [])
            where = sorted({s.loc(p["location"]) for p in places})
            lines.append(f"{s.npc(nid)}, {n.get('title', '')}" + (f", in {', '.join(where)}" if where else ""))
            lines.append("")
            mk = float(shop.get("markup", 1.0))
            bits = [f"markup ×{mk:g}", f"pays {int(float(shop.get('sell_rate', 0.5)) * 100)}% of value"]
            if shop.get("buys"):
                bits.append("buys " + ", ".join(shop["buys"]))
            if shop.get("closed"):
                bits.append(f"closed when {human_cond(shop['closed'])}")
            if shop.get("haggle"):
                h = shop["haggle"]
                if isinstance(h, dict) and h.get("dc"):
                    bits.append(f"haggle DC {h['dc']}")
            lines += [f"*{'; '.join(bits)}*", "", "| Item | Price | Stock | Only when |", "|---|---|---|---|"]
            for it in shop.get("sells", []):
                if "price" in it:
                    price = float(it["price"])
                else:
                    price = g.item_cost(it["id"]) * float(it.get("markup", mk))
                price = 0 if price <= 0 else int(-(-price // 1))
                qty = "∞" if it.get("qty", -1) == -1 else str(it.get("qty"))
                lines.append(f"| {s.item(it['id'])} | {'free' if price == 0 else str(price) + ' gp'} | {qty} | "
                             f"{esc(human_cond(it.get('if', '')))} |")
            lines.append("")
            rot = shop.get("rotating")
            if rot:
                lines.append(f"**Changing stock:** every {rot.get('days', 1)} days the stock is redrawn:")
                for grp in rot.get("groups", []):
                    lines.append(f"- {grp.get('count', 1)} of: " + ", ".join(g.item_name(x) for x in grp.get("pool", [])))
                lines.append("")
        lines += ["# Services", "", "Temples sell spells cast for the party, and inns sell a night's room.", "",
                  "| Service | Base price | What it does |", "|---|---|---|"]
        for sid, sv in services.items():
            price = f"{float(sv['price']):g} gp" if sv.get("price") else (f"{float(sv['each']):g} gp each" if sv.get("each") else "")
            lines.append(f"| {sv['name']} | {price} | {esc(sv['text'])} |")
        lines += ["", "| Who | Offers |", "|---|---|"]
        for nid, n in g.npcs.items():
            if n.get("services"):
                lines.append(f"| {s.npc(nid)} | " + ", ".join(services.get(x["id"], {}).get("name", x["id"]) +
                                                             (f" (when {human_cond(x['if'])})" if x.get("if") else "")
                                                             for x in n["services"]) + " |")
        self.w.write("page/merchants", "Items/Merchants", "Merchants and Services", [auto("list", "\n".join(lines))],
                     tags=["wiki", "items"])

    # World skill checks and talking creatures -------------------------------------------------------------------

    def checks_page(self):
        g, s = self.g, self.site
        lines = ["Skill checks you can try out in the world, by place. Walk up to the thing and pick the check from "
                 "its menu; the hero you have selected rolls. Most can be tried once: a failed check is final.", ""]
        total = 0
        for rid in sorted(self.regions, key=lambda r: (g.region_level(r) or 99)):
            rows = []
            for lid, loc in g.locations.items():
                if loc.get("region") != rid:
                    continue
                for p in loc.get("props", []):
                    for c in p.get("checks", []):
                        rows.append(f"| {s.loc(lid)} | {esc(p.get('label', p['id']))} | {skill_name(c['skill'])} "
                                    f"{c['dc']} | {esc(c.get('label', ''))} | {esc(self.check_result(lid, c))} |")
            if rows:
                total += len(rows)
                lines += [f"## {g.region_name(rid)}", "", "| Place | Thing | Check | Try | What it does |",
                          "|---|---|---|---|---|"] + rows + [""]
        lines.insert(1, f"{total} checks in all.")
        self.w.write("page/checks", "World/Skill Checks", "World Skill Checks", [auto("list", "\n".join(lines))],
                     tags=["wiki", "world"])
        # Talking creatures: conversations that cast Speak with Animals or Speak with Dead.
        rows = defaultdict(list)
        for key, dlg in g.dialogues.items():
            for node, sts in dlg.nodes.items():
                spells = set()
                for st in sts:
                    if st["t"] == "cast" and st["arg"] in ("speak_with_animals", "speak_with_dead"):
                        spells.add(st["arg"])
                    if st["t"] == "option":
                        for tag in st.get("tags", []):
                            m = re.search(r"(?:knows|spell):(speak_with_(?:animals|dead))", tag)
                            if m:
                                spells.add(m[1])
                if not spells:
                    continue
                told = self.what_follows(key, node)
                for sp in spells:
                    for w in self.where_node(key, node, limit=3):
                        rows[sp].append((w, told))
        lines = ["Animals and the dead who'll talk if you cast the right spell. With **Speak with Animals** (a Ritual: "
                 "ten minutes, no slot) a Beast talks; with **Speak with Dead** a corpse answers once. The spell's "
                 "option shows in the conversation when a hero knows it.", ""]
        for sp, label in (("speak_with_animals", "Speak with Animals"), ("speak_with_dead", "Speak with Dead")):
            if not rows.get(sp):
                continue
            lines += [f"## {label}", "", "| Who and where | What they say and what it leads to |", "|---|---|"]
            seen = set()
            for w, told in rows[sp]:
                if w in seen:
                    continue
                seen.add(w)
                lines.append(f"| {w} | {esc('; '.join(told))} |")
            lines.append("")
        self.w.write("page/talking", "World/Talking Creatures", "Talking Creatures", [auto("list", "\n".join(lines))],
                     tags=["wiki", "world"])

    def what_follows(self, key, node, depth=6):
        """What a conversation leads to from `node` on, within its file: hidden finds it shows, quests it moves,
        items it gives, and the first thing said."""
        g, s = self.g, self.site
        props = {}
        for lid, loc in g.locations.items():
            for p in loc.get("props", []):
                props.setdefault(p["id"], (lid, p))
        dlg = g.dialogues[key]
        seen, frontier, out, said = {node}, [node], [], ""
        for _ in range(depth):
            nxt = []
            for n in frontier:
                after_cast = False
                for st in dlg.nodes.get(n, []):
                    if st["t"] == "cast":
                        after_cast = True
                    elif st["t"] == "reveal":
                        lid, p = props.get(st["arg"], ("", {}))
                        out.append(f"shows where {g.item_name(p['item'])} is hidden" if p.get("item") else
                                   f"shows {p.get('label', st['arg'])}")
                    elif st["t"] == "quest" and st["id"] in g.quests:
                        out.append(f"moves {s.quest(st['id'])}")
                    elif st["t"] == "give":
                        out.append(f"gives {s.item(st['item'])}")
                    elif st["t"] == "line" and not said and (after_cast or n != node) and st["speaker"] != "Narrator":
                        said = plain(st["text"], 140)
                for r in dlg.edges(n):
                    if r[0] == key and r[1] not in seen:
                        seen.add(r[1])
                        nxt.append(r[1])
            frontier = nxt
        if said:
            out.insert(0, f"“{said}”")
        return list(dict.fromkeys(out))

    # Characters -------------------------------------------------------------------------------------------------

    def character_pages(self):
        g, s = self.g, self.site
        lines = ["The ready-made heroes you can start with or recruit. Each has a story of their own and opinions about "
                 f"what the party does ({s.link('page/approval', 'Companion Approval')}).", ""]
        for pid, p in g.pregens.items():
            b = p.get("build", {})
            cls = ", ".join(g.classes.get(l.get("class"), {}).get("name", "") for l in b.get("levels", [])[:1])
            pic = self.img.portrait(pid)
            lines.append(f"## {p['name']}")
            if pic:
                lines.append(embed(pic, 160))
            lines.append(f"*{p.get('summary', '')}*")
            lines.append("")
            if p.get("hook"):
                lines += [p["hook"], ""]
            bits = []
            if b.get("species"):
                bits.append(f"**Species:** {g.species.get(b['species'], {}).get('name', title_id(b['species']))}")
            if cls:
                bits.append(f"**Class:** {s.link('class/' + b['levels'][0]['class'], cls)}")
            if b.get("background"):
                bits.append(f"**Background:** {g.backgrounds.get(b['background'], {}).get('name', title_id(b['background']))}")
            if b.get("base_scores"):
                bits.append("**Scores:** " + ", ".join(f"{k.upper()} {v}" for k, v in b["base_scores"].items()))
            if p.get("pronouns"):
                bits.append(f"**Pronouns:** {p['pronouns']}")
            lines += [" · ".join(bits), ""]
        self.w.write("page/heroes", "Characters/Heroes", "Heroes", ["%% default %%\n", auto("list", "\n".join(lines))],
                     tags=["wiki", "characters"])
        for cid, c in g.classes.items():
            lines = [f"*{c.get('summary', '')}*", "",
                     f"- **Hit die:** d{c.get('hit_die', '')}",
                     f"- **Primary ability:** {', '.join(a.upper() for a in c.get('primary_abilities', []))}",
                     f"- **Saving throws:** {', '.join(a.upper() for a in c.get('saving_throws', []))}"]
            sk = c.get("skill_choices", {})
            if sk:
                lines.append(f"- **Skills:** choose {sk.get('count', 2)} from " + ", ".join(skill_name(x) for x in sk.get("from", [])))
            pr = c.get("proficiencies", {})
            for k in ("armor", "weapons", "tools"):
                if pr.get(k):
                    lines.append(f"- **{k.title()}:** " + ", ".join(str(x).replace("_", " ") for x in pr[k]))
            sc = c.get("spellcasting")
            if sc:
                lines.append(f"- **Spellcasting:** {sc.get('ability', '').upper()}, {sc.get('progression', '')} caster "
                             f"({s.link('page/spells_by_class', 'spell list')})")
            lines += ["", "## Features by level", ""]
            for lv in c.get("levels", []):
                for f in lv.get("features", []):
                    lines.append(f"- **{lv['level']}: {f['name']}.** {f.get('summary', '')}")
            subs = [x for x in g.subclasses.values() if x.get("class") == cid]
            if subs:
                lines += ["", f"## Subclasses (from level {c.get('subclass_level', 3)})", ""]
                for sb in subs:
                    lines += [f"### {sb['name']}", f"*{sb.get('summary', '')}*", ""]
                    for f in sb.get("features", []):
                        ft = f.get("feature", f)
                        lines.append(f"- **{f.get('level', '')}: {ft.get('name', '')}.** {ft.get('summary', '')}")
                    lines.append("")
            self.w.write(f"class/{cid}", s.paths[f"class/{cid}"], c["name"], [auto("class", "\n".join(lines))],
                         tags=["wiki", "class"])
        lines = []
        for sid, sp in g.species.items():
            lines += [f"## {sp['name']}", f"*{sp.get('summary', '')}*", "",
                      f"Size {', '.join(sp.get('sizes', []))}, speed {sp.get('speed', 30)} ft.", ""]
            for t in sp.get("traits", []):
                lines.append(f"- **{t['name']}.** {t.get('summary', '')}")
            lines.append("")
        self.w.write("page/species", "Characters/Species", "Species", [auto("list", "\n".join(lines))],
                     tags=["wiki", "characters"])
        lines = ["| Background | Abilities | Feat | Skills | What it is |", "|---|---|---|---|---|"]
        for bid, b in g.backgrounds.items():
            lines.append(f"| {b['name']} | {', '.join(a.upper() for a in b.get('ability_scores', []))} | "
                         f"{g.feats.get(b.get('feat', ''), {}).get('name', title_id(b.get('feat', '')))} | "
                         f"{', '.join(skill_name(x) for x in b.get('skills', []))} | {esc(b.get('summary', ''))} |")
        self.w.write("page/backgrounds", "Characters/Backgrounds", "Backgrounds", [auto("list", "\n".join(lines))],
                     tags=["wiki", "characters"])
        by_cat = defaultdict(list)
        for fid, f in g.feats.items():
            by_cat[f.get("category", "general")].append(f)
        lines = []
        for cat in sorted(by_cat):
            lines += [f"## {cat.replace('_', ' ').title()} feats", "", "| Feat | What it does |", "|---|---|"]
            for f in sorted(by_cat[cat], key=lambda f: f["name"]):
                lines.append(f"| {f['name']}{' (repeatable)' if f.get('repeatable') else ''} | {esc(f.get('summary', ''))} |")
            lines.append("")
        self.w.write("page/feats", "Characters/Feats", "Feats", [auto("list", "\n".join(lines))], tags=["wiki", "characters"])

    # Spells -----------------------------------------------------------------------------------------------------

    def spell_pages(self):
        g, s = self.g, self.site
        field = (g.root / "story" / "field_casting.gd").read_text()
        exploring = set(re.findall(r'"([a-z_]+)"', re.search(r"EXPLORING_TOO[^\[]*\[(.*?)\]", field, re.S)[1])) \
            if re.search(r"EXPLORING_TOO", field) else set()
        by_level = defaultdict(list)
        for sid, sp in g.spells.items():
            by_level[int(sp.get("level", 0))].append(sid)
        for lv in sorted(by_level):
            title = "Cantrips" if lv == 0 else f"Level {lv} Spells"
            lines = []
            for sid in sorted(by_level[lv], key=lambda x: g.spells[x]["name"]):
                sp = g.spells[sid]
                ct = sp.get("casting_time", {})
                rng = sp.get("range", {})
                comp = sp.get("components", {})
                dur = sp.get("duration", {})
                ctxt = (f"{ct.get('amount', 1)} {ct.get('unit', '')}" if ct.get("unit") in ("minute", "hour")
                        else ct.get("unit", "").replace("_", " "))
                rtxt = f"{rng.get('feet')} ft" if rng.get("feet") else rng.get("kind", "").replace("_", " ")
                ctags = "".join(x.upper() for x in ("v", "s") if comp.get(x)) + (" M" if comp.get("m") else "")
                dtxt = dur.get("kind", "").replace("_", " ") + (f" {dur.get('amount')}" if dur.get("amount") else "")
                lines.append(f"## {sp['name']}")
                lines.append(f"*{'Cantrip' if lv == 0 else 'Level ' + str(lv)} {sp.get('school', '')}"
                             f"{' (ritual)' if sp.get('ritual') else ''}* · {ctxt} · {rtxt} · {ctags} · {dtxt}"
                             + (f" · {', '.join(c.title() for c in sp.get('classes', []))}" if sp.get("classes") else ""))
                lines.append("")
                lines.append(sp.get("text") or sp.get("summary", ""))
                notes = []
                if not sp.get("playable", True):
                    notes.append("Not castable in this game yet.")
                if sid in exploring or sp.get("field_utility"):
                    notes.append("Can also be cast while exploring, from the character sheet.")
                if notes:
                    lines += ["", "> [!note] In this game", "> " + " ".join(notes)]
                lines.append("")
            path = f"Spells/{title}"
            self.w.write(f"page/spells_{lv}", path, title, [auto("list", "\n".join(lines))], tags=["wiki", "spells"])
        lines = ["Which class can learn which spell. Each name links to its full entry.", ""]
        for cid, c in g.classes.items():
            if not c.get("spellcasting"):
                continue
            lines += [f"## {c['name']}", ""]
            for lv in range(10):
                ids = sorted((x for x in by_level.get(lv, []) if cid in g.spells[x].get("classes", [])),
                             key=lambda x: g.spells[x]["name"])
                if ids:
                    lines.append(f"- **{'Cantrips' if lv == 0 else 'Level ' + str(lv)}:** " + ", ".join(s.spell(x) for x in ids))
            lines.append("")
        self.w.write("page/spells_by_class", "Spells/Spells by Class", "Spells by Class", [auto("list", "\n".join(lines))],
                     tags=["wiki", "spells"])

    # Rules ------------------------------------------------------------------------------------------------------

    def rules_pages(self):
        g, s = self.g, self.site
        dev = (g.root / "docs" / "rules" / "deviations.md").read_text()
        lines = ["Where this game plays differently from the 2024 rulebooks, and why. Most are calls the books leave "
                 "to the Dungeon Master; a few are the owner's own house rules, many borrowed from Baldur's Gate 3.", ""]
        section = ""
        for ln in dev.split("\n"):
            if ln.startswith("## "):
                section = ln[3:].strip()
                lines += [f"## {section}", ""]
                continue
            if not ln.startswith("| ") or ln.startswith("| Rule ") or ln.startswith("|---"):
                continue
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", ln)[1:-1]]
            if len(cells) < 3:
                continue
            rule, does, why = cells[0], cells[1], cells[2]
            rule = re.sub(r"\s*\((owner|Owner)[^)]*\)", "", rule)
            lines.append(f"### {rule}")
            lines.append(does)
            lines.append(f"\n*Why:* {why}\n")
        self.w.write("page/house_rules", "Rules/House Rules", "House Rules", ["%% default %%\n", auto("list", "\n".join(lines))],
                     tags=["wiki", "rules"])
        lines = []
        for cid, c in g.conditions.items():
            lines += [f"## {c['name']}", c.get("text") or c.get("summary", ""), ""]
        self.w.write("page/conditions", "Rules/Conditions", "Conditions", [auto("list", "\n".join(lines))], tags=["wiki", "rules"])
        lines = ["The rules words the game underlines; hover one in the game to read it. *In this game* notes are "
                 "where it plays differently.", ""]
        for t in sorted(g.glossary.get("terms", []), key=lambda t: t.get("name", "")):
            text = t.get("text") or t.get("summary", "")
            if not text and t.get("from"):
                kind, _, tid = t["from"].partition(":")
                if kind == "condition":
                    text = g.conditions.get(tid, {}).get("text", "")
            lines.append(f"## {t.get('name', '')}")
            if t.get("kind"):
                lines.append(f"*{t['kind']}*")
            lines.append(text)
            if t.get("here"):
                lines.append(f"\n> [!note] In this game\n> {t['here']}")
            lines.append("")
        self.w.write("page/glossary", "Rules/Glossary", "Glossary", [auto("list", "\n".join(lines))], tags=["wiki", "rules"])
        self.controls_page()

    def controls_page(self):
        g = self.g
        src = (g.root / "core" / "input_actions.gd").read_text()
        keys = {}
        m = re.search(r"const BINDINGS := \{(.*?)\n\}", src, re.S)
        for a, k in re.findall(r'&"([a-z_0-9]+)":\s*\[([^\]]*)\]', m[1] if m else ""):
            keys[a] = [x.strip().replace("KEY_", "").replace("KP_", "Keypad ").title() for x in k.split(",") if x.strip()]
        pads = {}
        for a, k in re.findall(r'&"([a-z_0-9]+)":\s*\[(JOY_[^\]]*)\]', src):
            pads.setdefault(a, [x.strip().replace("JOY_BUTTON_", "").replace("_", " ").title() for x in k.split(",")])
        cmds = re.findall(r'\[&"([a-z_0-9]+)", "([^"]+)", "([a-z]+)"\]', src)
        lists = dict(re.findall(r'"([a-z]+)": "([^"]+)"', re.search(r"const LISTS := \{(.*?)\}", src, re.S)[1]))
        lines = ["The default keys. Every one can be changed in Settings, Keys, except **Esc** (menus, back, cancel) "
                 "and **F1** (the controls card), so there's always a way back. A controller works everywhere too.", ""]
        for lst, label in lists.items():
            lines += [f"## {label}", "", "| Does | Key | Controller |", "|---|---|---|"]
            for a, what, l in cmds:
                if l != lst:
                    continue
                pk = ", ".join(pads.get(a, []))
                lines.append(f"| {what} | {', '.join(keys.get(a, []))} | {pk} |")
            lines.append("")
        lines += ["## Mouse", "", "- Left-click the ground to walk there; left-click a person, door or thing to use it.",
                  "- Right-click for a menu of everything you can do with what's under the cursor.",
                  "- In a fight, click a square to move (a far click walks as far as it can) or a foe to attack.", ""]
        tips = g.loading.get("tips", [])
        if tips:
            lines += ["## Tips from the loading screens", ""] + [f"- {t}" for t in tips] + [""]
        self.w.write("page/controls", "Rules/Controls", "Controls", ["%% default %%\n", auto("list", "\n".join(lines))],
                     tags=["wiki", "rules"])

    # Story systems ----------------------------------------------------------------------------------------------

    def story_pages(self):
        g, s = self.g, self.site
        cards = {c["id"]: c for c in g.tarokka_cards.get("cards", [])}
        lines = ["Madam Eva's reading at Tser Pool decides where three treasures lie, who your destined ally is and "
                 "where Strahd waits at the end. Each card drawn sets one of them. The reading is random per "
                 f"playthrough; the journal keeps her verses ({s.quest('madam_evas_reading')}).", ""]
        for kind, label in (("tome", "The Tome of Strahd"), ("symbol", "The Holy Symbol of Ravenkind"),
                            ("sword", "The Sunsword")):
            lines += [f"## {label}", "", "| Card | Where it is | Her verse |", "|---|---|---|"]
            for cid, o in (g.tarokka.get(kind) or {}).items():
                cn = cards.get(cid, {}).get("name", title_id(cid))
                where = o.get("hint", "") or title_id(o.get("place", ""))
                lines.append(f"| {cn} | {esc(where)} | *{esc(o.get('verse', ''))}* |")
            lines.append("")
        lines += ["## The destined ally", "", "| Card | Ally | Where | Her verse |", "|---|---|---|---|"]
        for cid, o in (g.tarokka.get("ally") or {}).items():
            lines.append(f"| {cards.get(cid, {}).get('name', title_id(cid))} | {s.npc(o.get('npc', ''))} | "
                         f"{esc(o.get('where', ''))} | *{esc(o.get('verse', ''))}* |")
        lines += ["", "## Where Strahd waits", "", "| Card | Room | Her verse |", "|---|---|---|"]
        for cid, o in (g.tarokka.get("enemy") or {}).items():
            lines.append(f"| {cards.get(cid, {}).get('name', title_id(cid))} | {esc(o.get('hint', '') or title_id(o.get('room', '')))} | "
                         f"*{esc(o.get('verse', ''))}* |")
        lines += ["", "## The cards", "", "| Card | Deck | Meaning |", "|---|---|---|"]
        for c in g.tarokka_cards.get("cards", []):
            lines.append(f"| {c['name']} | {c.get('deck', '')} | {esc(c.get('summary', ''))} |")
        self.w.write("page/tarokka", "Story/Tarokka Reading", "The Tarokka Reading", [auto("list", "\n".join(lines))],
                     tags=["wiki", "story"])
        lines = ["How the game can end. The first ending whose conditions hold (highest priority first) is the one you "
                 "get.", ""]
        for eid, e in sorted(g.endings.items(), key=lambda kv: -int(kv[1].get("priority", 0))):
            lines += [f"## {e.get('title', title_id(eid))}", f"*{e.get('summary', '')}*", "",
                      f"**When:** {human_cond(e.get('when', ''))}", ""]
            for ep in e.get("epilogue", []):
                lines.append(f"- **{ep.get('title', '')}**" + (f" (when {human_cond(ep['when'])})" if ep.get("when") else "")
                             + f": {ep.get('text', '')}")
            lines.append("")
        self.w.write("page/endings", "Story/Endings", "Endings", [auto("list", "\n".join(lines))], tags=["wiki", "story"])
        lines = ["The vestiges sealed in the Amber Temple's vault each offer a gift for a price. Accepting one is "
                 f"permanent. Take the hollow one and Strahd's end may not be yours ({s.link('page/endings', 'Endings')}).", ""]
        for did, d in g.dark_gifts.items():
            lines += [f"## {d.get('name', title_id(did))}", f"*{d.get('vestige', '')}*", "", d.get("summary", ""), ""]
        self.w.write("page/dark_gifts", "Story/Dark Gifts", "Dark Gifts", [auto("list", "\n".join(lines))], tags=["wiki", "story"])
        v = g.visits
        lines = [plain(v.get("summary", "")), "", f"At least {v.get('gap_hours', 12)} hours pass between visits. He "
                 "never comes in " + ", ".join(g.region_name(r) for r in v.get("quiet_regions", [])) + ", nor to "
                 + ", ".join(g.location_name(x) for x in v.get("quiet_at", [])) + ".", ""]
        for vis in v.get("visits", []):
            lines.append(f"## {title_id(vis['id'])}")
            lines.append(vis.get("summary", ""))
            if vis.get("when"):
                lines.append(f"\n*When:* {human_cond(vis['when'])}" + (" (once)" if vis.get("once") else ""))
            lines.append("")
        self.w.write("page/strahd", "Story/Strahd's Visits", "Strahd's Visits", [auto("list", "\n".join(lines))],
                     tags=["wiki", "story"])
        lines = ["Travelling between places on the map can be interrupted. Each road has a chance by day and by night, "
                 "and a weighted table of what comes.", ""]
        for rid, r in g.random_encounters.items():
            lines += [f"## {title_id(rid)}", r.get("summary", ""), "",
                      f"Chance per journey: {int(float(r.get('chance_day', 0)) * 100)}% by day, "
                      f"{int(float(r.get('chance_night', 0)) * 100)}% by night.", "",
                      "| Weight | When | What | XP |", "|---|---|---|---|"]
            for e in r.get("entries", []):
                lines.append(f"| {e.get('weight', 1)} | {esc(human_cond(e.get('when', '')))} | "
                             f"{self.monsters_line(e.get('monsters', []))} | {self.xp_of(e.get('monsters', []))} |")
            lines.append("")
        self.w.write("page/random_encounters", "World/Random Encounters", "Random Encounters",
                     [auto("list", "\n".join(lines))], tags=["wiki", "world"])
        w = g.weather
        lines = [plain(w.get("summary", "")), "", "| Weather | Travel speed | Road danger (day/night) | Hides things |",
                 "|---|---|---|---|"]
        for k, d in w.get("kinds", {}).items():
            lines.append(f"| {d.get('label', k)} | ×{d.get('travel', 1)} | +{d.get('road_day', 0)} / +{d.get('road_night', 0)} | "
                         f"{'yes' if d.get('obscures') else ''} |")
        self.w.write("page/weather", "World/Weather", "Weather", [auto("list", "\n".join(lines))], tags=["wiki", "world"])
        src = (g.root / "core" / "achievements.gd").read_text()
        ach = re.findall(r'"([a-z_0-9]+)": \["([^"]+)", "([^"]+)"\]', src)
        lines = ["| Achievement | How |", "|---|---|"] + [f"| {n} | {t} |" for _, n, t in ach]
        lines += ["", "Reaching each ending is an achievement too."]
        self.w.write("page/achievements", "World/Achievements", "Achievements", [auto("list", "\n".join(lines))],
                     tags=["wiki", "world"])
        lines = ["Every full-screen picture the story can show, with where it comes from. Spoilers, all of them.", ""]
        users = defaultdict(list)
        for key, node, st in g.statements({"cutscene"}):
            users[st["arg"]].append((key, node))
        for cid, c in g.cutscenes.items():
            stills = self.cutscene_stills(cid)
            if not stills:
                continue
            lines.append(f"## {c.get('title', title_id(cid))}")
            lines.append(c.get("summary", ""))
            qs = set()
            for key, node in users.get(cid, []):
                qs.update(q for q in self._node_quests(key, node) if q in g.quests)
            if qs:
                lines.append("From " + ", ".join(s.quest(q) for q in sorted(qs)))
            lines.append("")
            for p, cond in stills:
                lines.append(embed(p, 420) + (f" *({cond})*" if cond else ""))
            lines.append("")
        self.w.write("page/cutscenes", "Story/Cutscene Gallery", "Cutscene Gallery", [auto("list", "\n".join(lines))],
                     tags=["wiki", "story"])
        self.w.write("page/approval", "Characters/Companion Approval", "Companion Approval",
                     ["%% default %%\n", auto("list", self.approval_lines())], tags=["wiki", "characters"])
        self.w.write("page/difficulty", "Rules/Difficulty", "Difficulty", ["%% default %%\n", auto("modes", self.difficulty_lines())],
                     tags=["wiki", "rules"])
        # Pages people write by hand: the generator only makes sure they exist and keeps them linked.
        for key in ("page/magic", "page/stealth", "page/resting"):
            self.w.write(key, s.paths[key], s.titles[key], ["%% default %%\n"], tags=["wiki", "rules"])

    def difficulty_lines(self):
        """The four modes, from combat/difficulty.gd's MODES table (its describe() in words)."""
        src = (self.g.root / "combat" / "difficulty.gd").read_text()
        lines = []
        for mid, body in re.findall(r'^\t"([a-z]+)": \{(.*?)\},?$', src, re.S | re.M):
            def val(k):
                m = re.search(rf'"{k}":\s*("([^"]*)"|[\d.]+|true|false)', body)
                return None if not m else (m[2] if m[2] is not None else m[1])
            hp = float(val("hp") or 1)
            out = []
            out.append("Enemy Hit Points: their stat block's." if abs(hp - 1) < 1e-6 else
                       f"Enemy Hit Points: {abs(round((hp - 1) * 100))}% {'fewer' if hp < 1 else 'more'}, within what "
                       "their Hit Dice could roll.")
            if int(float(val("party_bonus") or 0)):
                out.append(f"+{int(float(val('party_bonus')))} to your attack rolls and saving throws.")
            if int(float(val("enemy_bonus") or 0)):
                out.append(f"+{int(float(val('enemy_bonus')))} to enemies' attack rolls and the DCs of their spells "
                           "and abilities.")
            t = val("tactics")
            if t == "kind":
                out.append("Enemies spread their attacks around and don't chase the killing blow.")
            elif t == "standard":
                out.append("Enemies fight as the book has them.")
            else:
                out.append("Enemies gang up on the hurt and go for your healers and spellcasters first; their "
                           "spellcasters cast from their whole spell list.")
            if t == "ruthless":
                out.append("Cruel foes strike a hero who has fallen to 0 Hit Points.")
            if val("kit") == "true":
                out.append("Armed foes carry a Potion of Healing and drink it when Bloodied; casters carry a spell "
                           "scroll. You loot what they don't use.")
            if val("morale") == "true":
                out.append("When their side breaks, foes flee the fight, except mindless things and bosses.")
            if val("full_bosses") == "true":
                out.append("Bosses fight at full strength even against a low-level party.")
            if val("spared") == "true":
                out.append("Nobody dies for good: a hero who would die is left Unconscious and Stable.")
            if val("safe_rests") == "true":
                out.append("A Long Rest is never interrupted, even in a risky place.")
            if val("one_save") == "true":
                out.append("One save for the whole playthrough.")
            if val("switchable") == "false":
                out.append("Picked only at a new game; leaving it is for good.")
            lines += [f"## {val('name')}: *{val('tagline')}*", "", val("summary") or "", ""] + [f"- {x}" for x in out] + [""]
        return "\n".join(lines)

    def approval_lines(self):
        g, s = self.g, self.site
        tally = defaultdict(lambda: defaultdict(list))
        for key, node, st in g.statements({"approve"}):
            for who, d in st["changes"]:
                tally[who]["+" if d > 0 else "-"].append((d, st.get("why", ""), key))
        lines = ["What each companion likes and dislikes, from every reaction in the story. Big swings first.", ""]
        for who in sorted(tally, key=lambda w: g.pregens.get(w, {}).get("name", w)):
            name = g.pregens.get(who, {}).get("name", title_id(who))
            lines += [f"## {name}", ""]
            for sign, label in (("+", "Approves"), ("-", "Disapproves")):
                items = sorted(tally[who][sign], key=lambda x: -abs(x[0]))
                if not items:
                    continue
                lines.append(f"**{label}** ({len(items)}):")
                seen = []
                for d, why, key in items:
                    if why and why not in seen:
                        seen.append(why)
                        if len(seen) <= 15:
                            lines.append(f"- {'+' if d > 0 else ''}{d}: {why}")
                if len(seen) > 15:
                    lines.append(f"- …and {len(seen) - 15} more")
                lines.append("")
        return "\n".join(lines)

    # The front page ---------------------------------------------------------------------------------------------

    def home(self):
        g, s = self.g, self.site
        n_side = sum(1 for q in g.quests.values() if q.get("kind") != "main")
        n_main = len(g.quests) - n_side
        sec = [
            ("Walkthroughs", [s.link("page/main_story", "Main Story") + f" ({n_main} quests)",
                              s.link("page/side_quests", "Side Quests") + f" ({n_side} quests)",
                              s.link("page/tarokka", "The Tarokka Reading"), s.link("page/endings", "Endings")]),
            ("The world", [s.link("page/locations", "All Locations") + f" ({len(g.locations)} places, with maps)",
                           s.link("page/regions", "Regions"),
                           s.link("page/people", "People") + f" ({len(g.npcs)})",
                           s.link("page/bestiary", "Bestiary") + f" ({len(g.monsters)} creatures)",
                           s.link("page/checks", "World Skill Checks"), s.link("page/talking", "Talking Creatures"),
                           s.link("page/random_encounters", "Random Encounters"), s.link("page/weather", "Weather"),
                           s.link("page/strahd", "Strahd's Visits")]),
            ("Items and money", [s.link("page/item_sources", "Where to Find Items"),
                                 s.link("page/merchants", "Merchants and Services"),
                                 s.link("page/magic_items", "Magic Items") + f" ({len(g.magic)})",
                                 s.link("page/equipment", "Equipment"), s.link("page/random_treasure", "Random Treasure"),
                                 "[[Cheat Codes]] (every item's code)"]),
            ("Heroes and magic", [s.link("page/heroes", "Heroes"), s.link("page/approval", "Companion Approval"),
                                  "Classes: " + ", ".join(s.link(f"class/{c}") for c in g.classes),
                                  s.link("page/species", "Species"), s.link("page/backgrounds", "Backgrounds"),
                                  s.link("page/feats", "Feats"), s.link("page/spells_by_class", "Spells by Class"),
                                  "Spells: " + ", ".join(s.link(f"page/spells_{i}", "Cantrips" if i == 0 else f"Level {i}")
                                                         for i in range(10) if f"page/spells_{i}" in s.paths),
                                  s.link("page/dark_gifts", "Dark Gifts")]),
            ("Rules and play", [s.link("page/house_rules", "House Rules"), s.link("page/difficulty", "Difficulty"),
                                s.link("page/magic", "How Magic Works"), s.link("page/stealth"), s.link("page/resting"),
                                s.link("page/controls", "Controls"), s.link("page/conditions", "Conditions"),
                                s.link("page/glossary", "Glossary"), s.link("page/achievements", "Achievements"),
                                s.link("page/cutscenes", "Cutscene Gallery")]),
        ]
        lines = []
        for title, links in sec:
            lines += [f"## {title}", ""] + [f"- {x}" for x in links] + [""]
        lines.append(f"*Built from the game's data at `{self.head}` on {TODAY} by `make wiki` "
                     "(tools/wiki/build_wiki.py). Generated sections are rewritten each time; anything written outside "
                     "them stays.*")
        intro = ("> [!warning] Spoilers\n> This wiki covers the whole game: every quest, twist, ending and secret.\n\n"
                 "A guide to the Curse of Strahd game: walkthroughs for every quest, where every item is, who sells "
                 "what, every place and person in Barovia, the creatures you'll fight, and how the rules work here.\n")
        self.w.write("page/home", "Home", "Curse of Strahd Wiki", [intro, auto("contents", "\n".join(lines))],
                     tags=["wiki"])

    def quest_start(self, qid):
        """(file key, node, entry) of the conversation that starts a quest: its earliest stage set where a person
        stands, or None."""
        q = self.g.quests[qid]
        order = [st["id"] for st in q.get("stages", [])]
        best = None
        for key, node, st in self.g.statements({"quest"}):
            if st["id"] != qid or st["stage"] not in order:
                continue
            for e in self.g.places_for(key, node):
                if e.get("kind") != "npc":
                    continue
                rank = (0 if e["npc"] == q.get("giver") else 1, order.index(st["stage"]))
                if best is None or rank < best[0]:
                    best = (rank, key, node, e)
        return best[1:] if best else None

    def shot_list(self):
        """What tools/wiki/wiki_shots.gd should shoot, grouped by place so each is entered once."""
        g = self.g
        by_loc = OrderedDict((lid, []) for lid in g.locations)
        for qid in g.quests:
            start = self.quest_start(qid)
            if not start:
                continue
            key, node, e = start
            hours = None
            for p in self.npc_places.get(e["npc"], []):
                if p["location"] == e["location"] and p.get("hours"):
                    hours = p["hours"]
            when = str(e.get("when", ""))
            hour = 22 if re.search(r"\bnight\b", when) else (int((hours[0] + hours[1]) / 2) if hours else 11)
            by_loc[e["location"]].append({"name": f"quest_{qid}", "kind": "dialogue", "location": e["location"],
                                          "hour": hour, "dialogue": f"{key}:{node}", "npc": e["npc"],
                                          "fallback": e.get("ref", "")})
        out = [{"name": "travel_map", "kind": "map", "location": "vallaki", "hour": 11}]
        for lid, quests in by_loc.items():
            out.append({"name": f"loc_{lid}_1", "kind": "explore", "location": lid, "hour": 11})
            out += sorted(quests, key=lambda x: x["hour"])
            out.append({"name": f"loc_{lid}_overview", "kind": "overview", "location": lid, "hour": 11})
        return out

    def build(self):
        s = self.site
        for key, path, title in [("page/main_story", "Quests/Main Story", "Main Story"),
                                 ("page/side_quests", "Quests/Side Quests", "Side Quests"),
                                 ("page/locations", "Locations/All Locations", "All Locations"),
                                 ("page/regions", "Locations/All Locations", "Regions"),
                                 ("page/people", "People/All People", "All People"),
                                 ("page/bestiary", "Bestiary/All Creatures", "Bestiary"),
                                 ("page/item_sources", "Items/Where to Find Items", "Where to Find Items"),
                                 ("page/magic_items", "Items/Magic Items", "Magic Items"),
                                 ("page/equipment", "Items/Equipment", "Equipment"),
                                 ("page/random_treasure", "Items/Random Treasure", "Random Treasure"),
                                 ("page/merchants", "Items/Merchants", "Merchants and Services"),
                                 ("page/checks", "World/Skill Checks", "World Skill Checks"),
                                 ("page/talking", "World/Talking Creatures", "Talking Creatures"),
                                 ("page/random_encounters", "World/Random Encounters", "Random Encounters"),
                                 ("page/weather", "World/Weather", "Weather"),
                                 ("page/achievements", "World/Achievements", "Achievements"),
                                 ("page/heroes", "Characters/Heroes", "Heroes"),
                                 ("page/approval", "Characters/Companion Approval", "Companion Approval"),
                                 ("page/species", "Characters/Species", "Species"),
                                 ("page/backgrounds", "Characters/Backgrounds", "Backgrounds"),
                                 ("page/feats", "Characters/Feats", "Feats"),
                                 ("page/spells_by_class", "Spells/Spells by Class", "Spells by Class"),
                                 ("page/house_rules", "Rules/House Rules", "House Rules"),
                                 ("page/difficulty", "Rules/Difficulty", "Difficulty"),
                                ("page/magic", "Rules/How Magic Works", "How Magic Works"),
                                ("page/stealth", "Rules/Sneaking, Stealing and the Watch", "Sneaking, Stealing and the Watch"),
                                ("page/resting", "Rules/Resting and Saving", "Resting and Saving"),
                                 ("page/controls", "Rules/Controls", "Controls"),
                                 ("page/conditions", "Rules/Conditions", "Conditions"),
                                 ("page/glossary", "Rules/Glossary", "Glossary"),
                                 ("page/tarokka", "Story/Tarokka Reading", "The Tarokka Reading"),
                                 ("page/endings", "Story/Endings", "Endings"),
                                 ("page/dark_gifts", "Story/Dark Gifts", "Dark Gifts"),
                                 ("page/strahd", "Story/Strahd's Visits", "Strahd's Visits"),
                                 ("page/cutscenes", "Story/Cutscene Gallery", "Cutscene Gallery"),
                                 ("page/home", "Home", "Curse of Strahd Wiki")]:
            s.paths[key] = path
            s.titles[key] = title
        for lv in range(10):
            s.paths[f"page/spells_{lv}"] = "Spells/Cantrips" if lv == 0 else f"Spells/Level {lv} Spells"
            s.titles[f"page/spells_{lv}"] = "Cantrips" if lv == 0 else f"Level {lv} Spells"
        self.quest_pages()
        self.location_pages()
        self.npc_pages()
        self.monster_pages()
        self.item_pages()
        self.merchant_page()
        self.checks_page()
        self.character_pages()
        self.spell_pages()
        self.rules_pages()
        self.story_pages()
        self.home()
        self.w.sweep(self.out / "_Removed")
        self.relink()
        self.broken = self.check_links()
        return self.w.stats

    def check_links(self):
        """Links and embeds on any page (hand-written ones included) that point at no page, heading or image."""
        if self.dry or not self.out.exists():
            return []
        heads = {}
        bad = []
        link_re = re.compile(r"(!?)\[\[(" + re.escape(WIKI) + r"/[^\]|#\\]+)(?:#([^\]|\\]+))?(?:\\?\|[^\]]*)?\]\]")
        for p in sorted(self.out.rglob("*.md")):
            for m in link_re.finditer(p.read_text()):
                target = self.out / m[2][len(WIKI) + 1:]
                if m[1]:
                    ok = target.exists()
                else:
                    page = target.with_name(target.name + ".md")
                    ok = page.exists()
                    if ok and m[3]:
                        if page not in heads:
                            heads[page] = {h.strip() for h in re.findall(r"^#+ (.+)$", page.read_text(), re.M)}
                        ok = m[3].strip() in heads[page]
                if not ok:
                    bad.append(f"{p.relative_to(self.out)}: {m[0]}")
        return bad

    def relink(self):
        """Links people wrote to a page or heading that has since been renamed (a quest, place or item whose name
        changed) follow it: the last build's links are kept in .wiki-links.json, and every page's old link becomes the
        new one."""
        s = self.site
        manifest = self.out / ".wiki-links.json"
        new = {k: s.link(k) for k in list(s.paths) + list(s.anchors)}
        old = {}
        if manifest.exists():
            try:
                old = json.loads(manifest.read_text())
            except json.JSONDecodeError:
                old = {}
        swaps = []
        for k, was in old.items():
            now = new.get(k)
            if not now or now == was:
                continue
            ot, _, ol = was[2:-2].partition("|")
            nt, _, nl = now[2:-2].partition("|")
            if ot == nt:
                continue
            swaps += [(was, now), (was.replace("|", "\\|"), now.replace("|", "\\|")),
                      (f"[[{ot}|", f"[[{nt}|"), (f"[[{ot}\\|", f"[[{nt}\\|"), (f"[[{ot}]]", f"[[{nt}]]")]
            if "#" not in ot:
                swaps.append((f"[[{ot}#", f"[[{nt}#"))
        if swaps and not self.dry:
            for p in self.out.rglob("*.md"):
                text = p.read_text()
                fixed = text
                for a, b in swaps:
                    fixed = fixed.replace(a, b)
                if fixed != text:
                    p.write_text(fixed)
                    self.w.stats["relinked"] += 1
        if not self.dry:
            manifest.write_text(json.dumps(new, indent=0, ensure_ascii=False, sort_keys=True))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="the wiki folder (default: the vault's Wiki/)")
    ap.add_argument("--root", type=Path, default=ROOT, help="the game checkout to read")
    ap.add_argument("--shots", type=Path, default=None, help="a folder of screenshots from tools/wiki/wiki_shots.gd")
    ap.add_argument("--no-images", action="store_true", help="skip scaling portraits and stills")
    ap.add_argument("--dry-run", action="store_true", help="say what would change, write nothing")
    ap.add_argument("--shot-list", type=Path, default=None,
                    help="write the screenshot list for tools/wiki/wiki_shots.gd to this file and stop")
    a = ap.parse_args()
    if a.shot_list:
        wiki = Wiki(Game(a.root), a.out, images=False, dry=True)
        for key, path, title in []:
            pass
        shots = wiki.shot_list()
        a.shot_list.write_text(json.dumps(shots, indent=1))
        print(f"wiki: {len(shots)} shots listed in {a.shot_list}")
        return 0
    if not a.dry_run and not a.out.parent.exists():
        print(f"wiki: {a.out.parent} doesn't exist (no vault on this machine?); nothing written")
        return 0
    game = Game(a.root)
    wiki = Wiki(game, a.out, images=not a.no_images, shots=a.shots, dry=a.dry_run)
    stats = wiki.build()
    print(f"wiki: {len(wiki.w.written)} pages ({stats['new']} new, {stats['changed']} changed, {stats['moved']} moved, "
          f"{stats['removed']} removed, {stats['relinked']} relinked), {wiki.img.made} images made, in {a.out}")
    broken = getattr(wiki, "broken", [])
    if broken:
        print(f"wiki: {len(broken)} broken links or images (a page or heading renamed by hand, or a missing shot):")
        for b in broken[:40]:
            print("  " + b)
    return 0


if __name__ == "__main__":
    sys.exit(main())
