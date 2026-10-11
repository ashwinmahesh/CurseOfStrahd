#!/usr/bin/env python3
"""Can a playthrough reach it? (Storyline QA, 2026-10-08.) A static walk of the whole story from a new game, for
make validate: every quest stage, dialogue node, flag, item, location, travel place, door, NPC, prop and container,
reached the way the game reaches them (exits and the travel map, NPC and prop conversations, road events, Strahd's
visits, the schedule, camp talks, banter, captives, the watch, the endings).

It is optimistic: anything that could be true is taken as true (a flag once some reachable line sets it, `not` always,
the time of day, a party member of any class), and it runs to a fixpoint. So whatever is still out of reach can't happen
in any playthrough. Run again with random road encounters left out, it finds quest content only luck can reach: a map
that only a random encounter opens (the Fourth Sister's lane and the Ravens' Ransom's trail were, until 2026-10-08).

findings(root) -> [error strings], for validate_data.py; python3 tools/data/story_reach.py [--facts] prints them (and
every reachable fact).
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ID = r"[a-z][a-z0-9_]*"
SOCIAL = {"persuasion", "intimidation", "deception", "performance", "insight"}

RE_NODE = re.compile(r"^~\s+(\S+)$")
RE_OPTION = re.compile(r"^\*\s+(.*?)\s*->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?\s*$")
RE_TAG = re.compile(r"^\[([^\]]+)\]\s*")
RE_JUMP = re.compile(r"^->\s*([A-Za-z0-9_:/]+|END)$")
RE_SET = re.compile(rf"^set\s+({ID})(?:\s*(=|\+=|-=)\s*(.+))?$")
RE_QUEST = re.compile(rf"^quest\s+({ID})\s+({ID})$")
RE_GIVE = re.compile(rf"^give\s+({ID})")
RE_CHECK = re.compile(r"^check\s+.*?->\s*([A-Za-z0-9_:/]+|END)(?:\s*\|\s*([A-Za-z0-9_:/]+|END))?$")
RE_COMBAT = re.compile(rf"^combat\s+({ID})$")
RE_IF = re.compile(r"^(if|elif)\s+(.+)$")
RE_JOIN = re.compile(rf"^join\s+({ID})$")
RE_ATT = re.compile(rf"^attitude\s+({ID})\s+(hostile|indifferent|friendly)$")
RE_GIFT = re.compile(rf"^dark_gift\s+({ID})$")


def _table(root, name):
    out = {}
    for f in sorted((root / "data" / name).glob("*.json")):
        try:
            out[f.stem] = json.loads(f.read_text())
        except json.JSONDecodeError:
            pass
    return out


def _value(raw):
    raw = raw.strip()
    if raw.startswith('"'):
        return raw.strip('"')
    if raw in ("true", "false"):
        return raw == "true"
    try:
        return int(raw)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return raw


def parse_dialogue(path):
    """{node: [statement]}, each statement with the `if` guards over it in its node."""
    nodes, cur, stack = {}, None, []
    for n, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        m = RE_NODE.match(line)
        if m:
            cur, stack = m.group(1), []
            nodes[cur] = []
            continue
        if cur is None:
            continue
        m = RE_IF.match(line)
        if m:
            if m.group(1) == "if":
                stack.append(m.group(2))
            elif stack:
                stack[-1] = m.group(2)
            continue
        if line == "else":
            if stack:
                stack[-1] = "true"
            continue
        if line == "endif":
            if stack:
                stack.pop()
            continue
        st = {"line": n, "guards": list(stack)}
        if (m := RE_OPTION.match(line)):
            label, conds, gates, check = m.group(1), [], [], None
            while (t := RE_TAG.match(label)):
                tag = t.group(1).strip()
                label = label[t.end():]
                if re.match(r"^[A-Za-z][A-Za-z ]*?\s+DC\s+\d+$", tag):
                    check = tag.rsplit(" DC", 1)[0].strip().lower().replace(" ", "_")
                elif tag.startswith("if "):
                    conds.append(tag[3:])
                else:
                    gates.append(tag)
            st.update(t="option", to=[x for x in (m.group(2), m.group(3)) if x], conds=conds, gates=gates, check=check)
        elif (m := RE_JUMP.match(line)):
            st.update(t="jump", to=[m.group(1)])
        elif (m := RE_CHECK.match(line)):
            st.update(t="jump", to=[x for x in (m.group(1), m.group(2)) if x])
        elif (m := RE_SET.match(line)):
            val = "+" if m.group(2) in ("+=", "-=") else (True if m.group(3) is None else _value(m.group(3)))
            st.update(t="set", flag=m.group(1), value=val)
        elif (m := RE_QUEST.match(line)):
            st.update(t="quest", quest=m.group(1), stage=m.group(2))
        elif (m := RE_GIVE.match(line)):
            st.update(t="give", item=m.group(1))
        elif (m := RE_COMBAT.match(line)):
            st.update(t="combat", enc=m.group(1))
        elif (m := RE_JOIN.match(line)):
            st.update(t="join", npc=m.group(1))
        elif (m := RE_ATT.match(line)):
            st.update(t="attitude", npc=m.group(1), value=m.group(2))
        elif (m := RE_GIFT.match(line)):
            st.update(t="gift", gift=m.group(1))
        else:
            continue
        nodes[cur].append(st)
    return nodes


class Story:
    def __init__(self, root=ROOT, chance_maps=True):
        self.root = Path(root)
        self.chance_maps = chance_maps
        t = lambda n: _table(self.root, n)  # noqa: E731
        self.locs, self.npcs, self.quests = t("locations"), t("npcs"), t("quests")
        self.random, self.schedule, self.strahd = t("random_encounters"), t("schedule"), t("strahd")
        self.endings, self.monsters = t("endings"), t("monsters")
        self.places, self.roads = [], []
        for k, v in sorted(t("travel").items()):
            self.places += v.get("places", [])
            self.roads += v.get("roads", [])
        self.magic = set(t("magic_items"))
        self.dlg = {}
        for f in sorted((self.root / "narrative").rglob("*.dialogue")):
            self.dlg[str(f.relative_to(self.root / "narrative").with_suffix(""))] = parse_dialogue(f)
        gr = (self.root / "world" / "game_root.gd").read_text()
        self.first = re.search(r'FIRST_LOCATION\s*:=\s*"([a-z0-9_]+)"', gr).group(1)
        crime = (self.root / "story" / "crime.gd").read_text()
        self.watch_regions = set(re.findall(r'"([a-z_]+)":\s*"[a-z_]+"', re.search(r"const WATCH := \{([^}]*)\}", crime).group(1)))
        self.facts = set()
        self.why = {}
        self.flags = {}    # flag -> values it can hold
        self.stages = {}   # quest -> stages it can reach

    # --- facts and conditions -------------------------------------------------------------------------------------

    def add(self, fact, why):
        if fact in self.facts:
            return False
        self.facts.add(fact)
        self.why[fact] = why
        if fact[0] == "flag":
            self.flags.setdefault(fact[1], []).append(fact[2])
        elif fact[0] == "quest":
            self.stages.setdefault(fact[1], []).append(fact[2])
        return True

    def stage_index(self, q, s):
        for i, st in enumerate(self.quests.get(q, {}).get("stages", [])):
            if st["id"] == s:
                return i
        return -1

    def flag_values(self, f):
        return self.flags.get(f, [])

    def possible(self, expr):
        expr = (expr or "").strip()
        return True if expr == "" else _Cond(self, expr).run()

    # --- the walk -------------------------------------------------------------------------------------------------

    def walk(self, fk, node, why):
        key = ("node", fk, node)
        if key in self._walked:
            return
        self._walked.add(key)
        self.changed |= self.add(key, why)
        for s in self.dlg.get(fk, {}).get(node, []):
            if not all(self.possible(g) for g in s["guards"]):
                continue
            here = f"narrative/{fk}.dialogue:{s['line']}"
            t = s["t"]
            if t == "set":
                self.changed |= self.add(("flag", s["flag"], s["value"]), here)
            elif t == "quest":
                self.changed |= self.add(("quest", s["quest"], s["stage"]), here)
            elif t == "give":
                self.changed |= self.add(("item", s["item"]), here)
            elif t == "join":
                self.changed |= self.add(("guest", s["npc"]), here)
            elif t == "attitude":
                self.changed |= self.add(("attitude", s["npc"], s["value"]), here)
            elif t == "combat":
                self.changed |= self.add(("combat", s["enc"]), here)
            elif t == "gift":
                self.changed |= self.add(("gift", s["gift"]), here)
            elif t == "option" and not all(self.possible(c) for c in s["conds"]):
                continue
            for to in s.get("to", []):
                if to == "END":
                    continue
                if "/" in to and ":" in to:
                    self.walk(*to.rsplit(":", 1), here)
                else:
                    self.walk(fk, to, here)

    def walk_ref(self, ref, why):
        if ref:
            self.walk(*ref.rsplit(":", 1), why)

    def door_open(self, door):
        if not self.possible(door.get("when", "")):
            return False
        if not door.get("locked") and int(door.get("lock_dc", 0)) <= 0:
            return True
        return int(door.get("lock_dc", 0)) > 0 or (door.get("key") and ("item", door["key"]) in self.facts)

    def cells(self, loc, starts):
        """The squares the party can walk to from `starts`: open floor and doors that open, a step at a time, and a
        diagonal step only where it doesn't cut the corner of a wall, low obstacle or void (CombatGrid's 2024 rule;
        a horse pen's fence with a gap only between two posts is closed)."""
        rows = loc["map"]["rows"]
        doors = {tuple(d["cell"]): d for d in loc.get("doors", [])}

        def open_(c):
            x, z = c
            if z < 0 or z >= len(rows) or x < 0 or x >= len(rows[z]):
                return False
            return self.door_open(doors[c]) if c in doors else rows[z][x] in ".~1234"

        seen, todo = set(), [tuple(c) for c in starts if open_(tuple(c))]
        while todo:
            c = todo.pop()
            if c in seen:
                continue
            seen.add(c)
            x, z = c
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    n = (x + dx, z + dz)
                    if not (dx or dz) or n in seen or not open_(n):
                        continue
                    if dx and dz and not (open_((x + dx, z)) and open_((x, z + dz))):
                        continue   # the diagonal would cut a corner
                    todo.append(n)
        return seen

    @staticmethod
    def beside(cells, cell):
        x, z = cell
        return any((x + dx, z + dz) in cells for dx in (-1, 0, 1) for dz in (-1, 0, 1))

    def run(self):
        self.add(("loc", self.first), "the game starts here")
        for item in self.magic:   # random treasure can place any magic item (story/treasure.gd)
            self.add(("item", item), "random treasure")
        for name in ("pregens", "classes", "backgrounds"):
            for k, d in _table(self.root, name).items():
                for m in re.findall(r'"(?:id|item)"\s*:\s*"([a-z0-9_]+)"', json.dumps(d)):
                    self.add(("item", m), f"data/{name}/{k}.json")
        for _ in range(100):
            self.changed = False
            self._walked = set()
            self._locations()
            self._travel()
            self._events()
            if not self.changed:
                return self
        return self

    def run_tutorial(self):
        """Walk the menu-launched practice dialogue with its own flags, never campaign facts."""
        script = self.root / "world" / "tutorial" / "tutorial_session.gd"
        if not script.exists():
            return self
        entry = re.search(r'CONVERSATION_REF\s*:=\s*"([^"]+)"', script.read_text())
        if not entry:
            return self
        for _ in range(100):
            self.changed = False
            self._walked = set()
            self.walk_ref(entry.group(1), "the optional tutorial from New Game or Learn to play")
            if not self.changed:
                break
        return self

    def _locations(self):
        for lid, loc in self.locs.items():
            if ("loc", lid) not in self.facts:
                continue
            w = f"data/locations/{lid}.json"
            starts = [c for sp, c in loc.get("spawns", {}).items() if sp == "default" or ("spawn", lid, sp) in self.facts]
            cells = self.cells(loc, starts)
            for a in loc.get("areas", []):
                (x0, z0), (x1, z1) = a["cells"][0], a["cells"][-1]
                if any(x0 <= x <= x1 and z0 <= z <= z1 for x, z in cells):
                    self.changed |= self.add(("area", lid, a["id"]), w)
                    self.changed |= self.add(("visited", a["id"]), w)
            for ex in loc.get("exits", []):
                if self.beside(cells, ex["cell"]) and self.possible(ex.get("when", "")):
                    if ex["to"] == "travel":
                        self.changed |= self.add(("road_out", lid), w)
                    else:
                        self.changed |= self.add(("loc", ex["to"]), f"{w} exit {ex['id']}")
                        self.changed |= self.add(("spawn", ex["to"], ex.get("spawn", "default")), w)
            for d in loc.get("doors", []):
                if self.beside(cells, d["cell"]) and self.door_open(d):
                    self.changed |= self.add(("door", lid, d["id"]), w)
                    if d.get("flag"):
                        self.changed |= self.add(("flag", d["flag"], True), f"{w} door {d['id']}")
            for n in loc.get("npcs", []):
                if self.beside(cells, n["cell"]) and self.possible(n.get("when", "")):
                    self.changed |= self.add(("npc", lid, n["npc"], n.get("dialogue", "")), w)
                    self.changed |= self.add(("met", n["npc"]), w)
                    self.walk_ref(n.get("dialogue"), f"{w} npc {n['npc']}")
            for p in loc.get("props", []):
                if self.beside(cells, p["cell"]) and self.possible(p.get("when", "")):
                    self.changed |= self.add(("prop", lid, p["id"]), w)
                    if p.get("item"):
                        self.changed |= self.add(("item", p["item"]), f"{w} prop {p['id']}")
                    for f in (p.get("flag"), (p.get("hangs") or {}).get("flag")):
                        if f:
                            self.changed |= self.add(("flag", f, True), f"{w} prop {p['id']}")
                    self.walk_ref(p.get("dialogue"), f"{w} prop {p['id']}")
            for c in loc.get("containers", []):
                if not self.beside(cells, c["cell"]) or not self.possible(c.get("when", "")):
                    continue
                if c.get("key") and int(c.get("lock_dc", 0)) <= 0 and ("item", c["key"]) not in self.facts:
                    continue
                self.changed |= self.add(("container", lid, c["id"]), w)
                for i in c.get("items", []):
                    self.changed |= self.add(("item", i["id"]), f"{w} container {c['id']}")
                if c.get("flag"):
                    self.changed |= self.add(("flag", c["flag"], True), f"{w} container {c['id']}")
            for tr in loc.get("traps", []):
                if tr.get("flag") and any(tuple(c) in cells for c in tr["cells"]) and self.possible(tr.get("when", "")):
                    self.changed |= self.add(("flag", tr["flag"], True), f"{w} trap {tr['id']}")
            for en in loc.get("encounters", []):
                if self._encounter_on(lid, en):
                    self._won(lid, en, f"{w} encounter {en['id']}")
            if self.watch_regions & {loc.get("region")} or loc.get("watch"):
                region = loc["region"]
                self.changed |= self.add(("flag", f"crime_{region}", "+"), "story/crime.gd")
                nodes = self.dlg.get(f"watch/{region}", {})
                targets = {to for ss in nodes.values() for s in ss for to in s.get("to", [])}
                for node in nodes:
                    if node not in targets:
                        self.walk(f"watch/{region}", node, "story/crime.gd (a crime the watch sees)")

    def _encounter_on(self, lid, en):
        if not self.possible(en.get("when", "")):
            return False
        if en.get("final_battle") and not self.possible("quest.strahds_lair >= foretold"):
            return False
        trig = en["trigger"]
        kind, _, arg = trig.partition(":")
        if kind == "enter_area":
            return ("area", lid, arg) in self.facts
        if kind == "flag":
            return self.possible("flag." + arg)
        if kind == "open":
            return ("door", lid, arg) in self.facts or ("container", lid, arg) in self.facts
        if kind == "examine":
            return ("prop", lid, arg) in self.facts
        return trig == "enter" or ("combat", en["id"]) in self.facts

    def _won(self, lid, en, w):
        self.changed |= self.add(("won", lid, en["id"]), w)
        if en.get("flag"):
            self.changed |= self.add(("flag", en["flag"], True), w)
        if en.get("quest"):
            self.changed |= self.add(("quest", en["quest"]["id"], en["quest"]["stage"]), w)
        if (en.get("withdraw") or {}).get("flag"):
            self.changed |= self.add(("flag", en["withdraw"]["flag"], True), w)
        if en.get("final_battle"):
            self.changed |= self.add(("quest", "strahds_lair", "confronted"), "world/exploration/location_fights.gd")
            self.walk("strahd/final", "parley", "the final battle's parley")
        for m in en.get("monsters", []):
            md = json.dumps(self.monsters.get(m["monster"], {}))
            for f in re.findall(r'"flag"\s*:\s*"([a-z0-9_]+)"', md):
                self.changed |= self.add(("flag", f, True), f"data/monsters/{m['monster']}.json")
            for q, s in re.findall(r'"quest"\s*:\s*\{\s*"id"\s*:\s*"([a-z0-9_]+)"\s*,\s*"stage"\s*:\s*"([a-z0-9_]+)"', md):
                self.changed |= self.add(("quest", q, s), f"data/monsters/{m['monster']}.json")
        for cap in self.dlg:
            if cap.startswith("captives/"):
                self.walk(cap, "start", "captives after a fight (story/captives.gd)")

    def _travel(self):
        been = {p["id"] for p in self.places if ("loc", p["location"].split(":")[0]) in self.facts}
        open_roads = [r for r in self.roads if self.possible(r.get("when", ""))]
        near = {b for r in open_roads for a, b in ((r["from"], r["to"]), (r["to"], r["from"])) if a in been}
        known = {p["id"] for p in self.places if p["id"] in been or (p.get("when", "") == "" and p["id"] in near)
                 or (p.get("when", "") != "" and self.possible(p["when"]))}
        reached = {p["id"] for p in self.places if ("road_out", p["location"].split(":")[0]) in self.facts}
        todo = list(reached)
        while todo:
            here = todo.pop()
            for r in open_roads:
                for a, b in ((r["from"], r["to"]), (r["to"], r["from"])):
                    if a == here and b in known and b not in reached:
                        reached.add(b)
                        todo.append(b)
        for p in self.places:
            if p["id"] in reached:
                lid = p["location"].split(":")[0]
                self.changed |= self.add(("loc", lid), f"the travel map ({p['id']})")
                self.changed |= self.add(("spawn", lid, p.get("spawn", "default")), "the travel map")
        for r in open_roads:
            if r["from"] in reached and r["to"] in reached and r.get("table"):
                self.changed |= self.add(("table", r["table"]), f"the road {r['id']}")
        for tid, tb in self.random.items():
            if ("table", tid) not in self.facts:
                continue
            if tb.get("map") and self.chance_maps:
                self.changed |= self.add(("loc", tb["map"]), f"a random encounter on a {tid} road")
            for e in tb.get("entries", []):
                if e.get("dialogue") and self.possible(e.get("when", "")):
                    self.walk_ref(e["dialogue"], f"a random encounter on a {tid} road")

    def _events(self):
        for sid, sc in self.schedule.items():
            for e in sc.get("events", []):
                if ("loc", e.get("location", "")) in self.facts and self.possible(e.get("when", "")):
                    for f, v in (e.get("set") or {}).items():
                        self.changed |= self.add(("flag", f, v), f"data/schedule/{sid}.json {e['id']}")
                    self.walk_ref(e.get("dialogue"), f"data/schedule/{sid}.json {e['id']}")
        for v in self.strahd.get("visits", {}).get("visits", []):
            if not self.possible(v.get("when", "")):
                continue
            for step in [v] + list(v.get("then", [])):
                if step is not v and not self.possible(step.get("when", "")):
                    continue
                enc = step.get("encounter") if isinstance(step.get("encounter"), dict) else {}
                for ref in (step.get("dialogue"), step.get("after"), enc.get("after")):
                    self.walk_ref(ref, f"Strahd's visit {v['id']}")
                for f in (enc.get("flag"), (enc.get("withdraw") or {}).get("flag")):
                    if f:
                        self.changed |= self.add(("flag", f, True), f"Strahd's visit {v['id']}")
                for f, val in (step.get("set") or {}).items():
                    self.changed |= self.add(("flag", f, val), f"Strahd's visit {v['id']}")
        for fk, nodes in self.dlg.items():
            top = fk.split("/")[0]
            for node, stmts in nodes.items():
                if top == "camp" and stmts and stmts[0]["guards"] and self.possible(stmts[0]["guards"][0]):
                    self.walk(fk, node, "a camp talk (story/camp_talk.gd)")
                elif top == "banter":
                    self.walk(fk, node, "banter (story/banter.gd)")
        for eid, e in self.endings.items():
            if self.possible(e.get("when", "")):
                self.walk(f"endings/{eid}", "start", "the ending screen")
        for nid, n in self.npcs.items():
            if ("met", nid) not in self.facts:
                continue
            for w in (n.get("shop") or {}).get("sells", []):
                self.changed |= self.add(("item", w["id"]), f"{nid}'s shop")
                if w.get("sets"):
                    self.changed |= self.add(("flag", w["sets"], True), f"{nid}'s shop")
                if w.get("counts"):
                    self.changed |= self.add(("flag", w["counts"], "+"), f"{nid}'s shop")


class _Cond:
    """Optimistic: True if `expr` could hold given what the walk has reached."""

    def __init__(self, story, expr):
        self.s = story
        self.toks = re.findall(r'"[^"]*"|==|!=|>=|<=|[=><()]|[^\s=!<>()]+', expr)
        self.i = 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else ""

    def take(self):
        self.i += 1
        return self.toks[self.i - 1] if self.i <= len(self.toks) else ""

    def run(self):
        return self.or_()

    def or_(self):
        v = self.and_()
        while self.peek() == "or":
            self.take()
            v = self.and_() or v
        return v

    def and_(self):
        v = self.not_()
        while self.peek() == "and":
            self.take()
            v = self.not_() and v
        return v

    def not_(self):
        if self.peek() == "not":
            self.take()
            self.not_()
            return True   # anything can still be untrue
        if self.peek() == "(":
            self.take()
            v = self.or_()
            if self.peek() == ")":
                self.take()
            return v
        return self.term()

    def term(self):
        t, op, rhs = self.take(), "", ""
        if self.peek() in ("==", "!=", ">=", "<=", ">", "<", "="):
            op = "==" if self.take() == "=" else self.toks[self.i - 1]
            rhs = self.take().strip('"')
        s = self.s
        if t.startswith("flag."):
            vals = s.flag_values(t[5:])
            if op == "":
                return any(v == "+" or (v not in (False, 0, "") and v is not None) for v in vals)
            if op in ("!=", "<", "<=") or (op == "==" and rhs in ("false", "0", "")):
                return True
            if op == "==":
                return any(v == "+" or str(v).lower() == rhs.lower() or (v is True and rhs == "true") for v in vals)
            n = float(rhs) if re.match(r"^-?\d+(\.\d+)?$", rhs) else 0.0
            return any(v == "+" or (v is True and n < 1 + (op == ">=")) or (isinstance(v, (int, float)) and not isinstance(v, bool)
                       and (v >= n if op == ">=" else v > n)) for v in vals)
        if t.startswith("quest."):
            q = t[6:]
            got = s.stages.get(q, [])
            if op == "":
                return bool(got)
            if op == "!=":
                return True
            if op == "==":
                return rhs in got
            want = s.stage_index(q, rhs)
            return any(op in ("<", "<=") or (s.stage_index(q, g) >= want if op == ">=" else s.stage_index(q, g) > want)
                       for g in got)
        if t.startswith("item:"):
            return ("item", t[5:]) in s.facts
        if t.startswith("visited:"):
            return ("loc", t[8:]) in s.facts or ("visited", t[8:]) in s.facts
        if t.startswith("at:"):
            return ("loc", t[3:]) in s.facts
        if t.startswith("guest:"):
            return ("guest", t[6:]) in s.facts
        if t.startswith("gift:"):
            return ("gift", t[5:]) in s.facts
        if t.startswith("attitude.") and op == "==" and rhs in ("friendly", "hostile"):
            npc = t[9:]
            return s.npcs.get(npc, {}).get("attitude") == rhs or ("attitude", npc, rhs) in s.facts
        return t != "false"


def findings(root=ROOT):
    """The errors: what no playthrough reaches, and quest content only a random road encounter reaches."""
    s = Story(root).run()
    lucky = Story(root, chance_maps=False).run()
    tutorial = Story(root).run_tutorial()
    out = []
    for qid, q in sorted(s.quests.items()):
        for st in q["stages"]:
            f = ("quest", qid, st["id"])
            if f not in s.facts:
                out.append(f"data/quests/{qid}.json: no playthrough reaches stage '{st['id']}'")
            elif f not in lucky.facts:
                out.append(f"data/quests/{qid}.json: stage '{st['id']}' is only reached on a map that a random road "
                           f"encounter happens to open; give that place a way in (an exit or a travel place)")
    for fk, nodes in sorted(s.dlg.items()):
        if fk.startswith("narrator/"):
            continue
        source = tutorial if fk.startswith("tutorial/") else s
        for node in nodes:
            if ("node", fk, node) not in source.facts:
                out.append(f"narrative/{fk}.dialogue: nothing reaches node '{node}' (no entry, jump or option leads there "
                           f"in a playthrough)")
    for lid, loc in sorted(s.locs.items()):
        if ("loc", lid) not in s.facts:
            out.append(f"data/locations/{lid}.json: no playthrough reaches this location")
            continue
        # Only what has to be touched: a prop to take, read, pull or talk at, a container, a person to talk to. A prop that
        # is only looked at is examined from where the party stands (LocationInteraction._seen_from_afar).
        for kind, key in (("props", "prop"), ("containers", "container"), ("npcs", "npc")):
            for e in loc.get(kind, []):
                if kind == "props" and not (e.get("item") or e.get("dialogue") or e.get("flag")):
                    continue
                if kind == "npcs" and not e.get("dialogue"):
                    continue
                got = ("npc", lid, e["npc"], e["dialogue"]) if kind == "npcs" else (key, lid, e["id"])
                if got not in s.facts and s.possible(e.get("when", "")):
                    out.append(f"data/locations/{lid}.json: {key} {e.get('id', e.get('npc'))} at {e['cell']} can't be "
                               f"reached (no square beside it can be walked to; diagonal steps can't cut a wall's corner)")
    for fid, places in sorted(_reads(s).items()):
        for where in places:
            source = tutorial if where.startswith("narrative/tutorial/") else s
            if not source.possible(f"flag.{fid}"):
                out.append(f"{where}: flag '{fid}' is read, but nothing a playthrough reaches sets it")
                break
    return out


def _reads(s):
    reads = {}

    def scan(expr, where):
        for f in re.findall(r"(?<!not )\bflag\.([a-z][a-z0-9_]*)\b(?!\s*(?:==|!=|<|>|<=|>=))", expr or ""):
            reads.setdefault(f, []).append(where)

    for fk, nodes in s.dlg.items():
        for node, stmts in nodes.items():
            for st in stmts:
                for c in st["guards"] + st.get("conds", []):
                    scan(c, f"narrative/{fk}.dialogue:{st['line']}")
    for lid, loc in s.locs.items():
        for sec in ("exits", "doors", "props", "containers", "npcs", "encounters"):
            for e in loc.get(sec, []):
                scan(e.get("when", ""), f"data/locations/{lid}.json")
    for p in s.places:
        scan(p.get("when", ""), "data/travel")
    return reads


if __name__ == "__main__":
    errs = findings(ROOT)
    for e in errs:
        print("  FAIL ", e)
    if "--facts" in sys.argv:
        for f in sorted(Story(ROOT).run().facts, key=repr):
            print("  ", f)
    print(f"story reach: {len(errs)} errors")
    sys.exit(1 if errs else 0)
