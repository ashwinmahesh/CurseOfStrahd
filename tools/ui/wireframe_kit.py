"""Tiny SVG kit for the docs/ui wireframes (plan §5.6). Low-fidelity on purpose: layout, hierarchy, states
and focus, in the project palette, readable in Obsidian. Screens live in tools/ui/wireframes.py."""
from html import escape

P = {  # art/palette/palette.json
    "void": "#0d0a12", "ink": "#1a1220", "grave": "#271c2e", "ash": "#3a2a44", "blood": "#6e1023",
    "crimson": "#a3192d", "red": "#d6283a", "rose": "#e8606a", "bruise": "#4a2160", "plum": "#6d3486",
    "orchid": "#9a5bb0", "lilac": "#c495cf", "night": "#1c2e4c", "mist": "#5379a3", "moonlight": "#8fb2cf",
    "frost": "#c9dfe8", "bone_dark": "#5b4c3e", "bone": "#8e7a62", "parchment": "#c7b18a", "vellum": "#e6d6b0",
    "ivory": "#f4ecd6", "moss": "#3e6a3a", "sickly": "#6f9a3e", "bile": "#a9c450", "ember": "#8a3a12",
    "candle": "#d9731e", "flame": "#f2a93b", "wick": "#fbe08a", "stone": "#3b3b45", "slate": "#5c5c69",
    "pewter": "#8a8a96", "silver": "#bdbdc6", "umber": "#4d382a", "walnut": "#664a35",
}
SANS = "Inter, 'Helvetica Neue', Arial, sans-serif"
SERIF = "Georgia, 'Times New Roman', serif"
W, H = 1600, 900


class Svg:
    def __init__(self, title, w=W, h=H):
        self.w, self.h = w, h
        self.parts = []
        self.title = title
        self.rect(0, 0, w, h, P["ink"])

    # primitives
    def rect(self, x, y, w, h, fill="none", stroke=None, sw=1, rx=6, dash=None, opacity=None):
        a = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}"'
        if dash:
            a += f' stroke-dasharray="{dash}"'
        if opacity is not None:
            a += f' opacity="{opacity}"'
        self.parts.append(a + "/>")

    def line(self, x1, y1, x2, y2, stroke=None, sw=1, dash=None):
        a = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke or P["ash"]}" stroke-width="{sw}"'
        if dash:
            a += f' stroke-dasharray="{dash}"'
        self.parts.append(a + "/>")

    def circle(self, cx, cy, r, fill, stroke=None, sw=1):
        a = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}" stroke-width="{sw}"'
        self.parts.append(a + "/>")

    def text(self, x, y, s, size=15, fill=None, weight="normal", anchor="start", family=SANS, italic=False):
        style = ' font-style="italic"' if italic else ""
        self.parts.append(f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" fill="{fill or P["vellum"]}" '
                          f'font-weight="{weight}" text-anchor="{anchor}"{style}>{escape(str(s))}</text>')

    def lines(self, x, y, rows, size=14, fill=None, gap=None, **kw):
        gap = gap or int(size * 1.45)
        for i, r in enumerate(rows):
            self.text(x, y + i * gap, r, size, fill, **kw)
        return y + len(rows) * gap

    # components
    def frame(self, step_title, crumbs=None, party=None, hint="", back=True, next_label="Next ▸", next_focus=False,
              next_disabled=False):
        """Outer chrome shared by the creator and level-up screens."""
        self.rect(0, 0, self.w, 64, P["void"], rx=0)
        self.text(28, 41, self.title, 22, P["wick"], "bold", family=SERIF)
        if crumbs:
            self.text(self.w - 28, 40, crumbs, 14, P["silver"], anchor="end")
        if party:
            x = max(360, 28 + int(len(self.title) * 11.5) + 24)
            for i, (name, state) in enumerate(party):
                active = state == "active"
                self.rect(x, 14, 168, 36, P["grave"] if not active else P["bruise"], P["candle"] if active else P["ash"], 2 if active else 1)
                self.text(x + 12, 37, f"{i + 1}  {name}", 14, P["ivory"] if active else P["silver"], "bold" if active else "normal")
                if state == "done":
                    self.text(x + 150, 37, "✓", 15, P["bile"], anchor="end")
                x += 178
        self.rect(0, self.h - 60, self.w, 60, P["void"], rx=0)
        if back:
            self.button(24, self.h - 48, 130, 36, "◂ Back")
        if hint:
            self.text(self.w / 2, self.h - 24, hint, 14, P["silver"], anchor="middle")
        if next_label:
            self.button(self.w - 184, self.h - 48, 160, 36, next_label, primary=not next_disabled, focus=next_focus,
                        disabled=next_disabled)
        if step_title:
            self.text(28, 100, step_title, 26, P["ivory"], "bold", family=SERIF)

    def button(self, x, y, w, h, label, primary=False, focus=False, disabled=False):
        fill = P["candle"] if primary else P["grave"]
        if disabled:
            fill = P["stone"]
        self.rect(x, y, w, h, fill, P["wick"] if focus else P["ash"], 4 if focus else 1, rx=5)
        col = P["ink"] if primary and not disabled else (P["pewter"] if disabled else P["vellum"])
        self.text(x + w / 2, y + h / 2 + 5, label, 15, col, "bold" if primary else "normal", anchor="middle")
        if focus:
            self.text(x - 14, y + h / 2 + 6, "▸", 18, P["wick"], "bold")

    def panel(self, x, y, w, h, title=None, fill=None):
        self.rect(x, y, w, h, fill or P["grave"], P["ash"], 1, rx=8)
        if title:
            self.text(x + 16, y + 28, title, 15, P["lilac"], "bold")
            self.line(x + 12, y + 40, x + w - 12, y + 40, P["ash"])

    def parchment(self, x, y, w, h, title=None):
        self.rect(x, y, w, h, P["vellum"], P["bone"], 2, rx=6)
        if title:
            self.text(x + 18, y + 32, title, 20, P["ink"], "bold", family=SERIF)

    def card(self, x, y, w, h, title, rows=(), selected=False, disabled=False, focus=False, reason=None, badge=None, tags=()):
        fill = P["bruise"] if selected else P["grave"]
        if disabled:
            fill = P["stone"]
        stroke = P["wick"] if focus else (P["candle"] if selected else P["ash"])
        self.rect(x, y, w, h, fill, stroke, 4 if focus else (2 if selected else 1), rx=6)
        tc = P["pewter"] if disabled else P["ivory"]
        self.text(x + 14, y + 26, title, 16, tc, "bold")
        if badge:
            self.text(x + w - 12, y + 26, badge, 13, P["flame"], anchor="end")
        yy = y + 48
        for r in rows:
            self.text(x + 14, yy, r, 13, P["silver"] if not disabled else P["pewter"])
            yy += 19
        if tags:
            tx = x + 14
            for t in tags:
                tw = 10 + 7 * len(t)
                self.rect(tx, y + h - 30, tw, 20, P["ash"], rx=10)
                self.text(tx + tw / 2, y + h - 15, t, 11, P["lilac"], anchor="middle")
                tx += tw + 6
        if reason:
            self.text(x + 14, y + h - 12, "⊘ " + reason, 12, P["rose"])
        if focus:
            self.text(x - 16, y + 28, "▸", 18, P["wick"], "bold")

    def chip(self, x, y, label, color=None, fill=None):
        w = 14 + 7.2 * len(label)
        self.rect(x, y, w, 24, fill or P["ash"], rx=12)
        self.text(x + w / 2, y + 17, label, 12, color or P["vellum"], anchor="middle")
        return x + w + 8

    def status(self, x, y, kind, text, size=13):
        icon, col = {"error": ("!", P["red"]), "warn": ("~", P["flame"]), "ok": ("✓", P["bile"]),
                     "info": ("i", P["moonlight"])}[kind]
        self.circle(x + 9, y - 5, 9, col)
        self.text(x + 9, y, icon, 13, P["ink"], "bold", anchor="middle")
        self.text(x + 26, y, text, size, col if kind != "info" else P["frost"])

    def callout(self, n, x, y):
        self.circle(x, y, 13, P["wick"], P["ink"], 2)
        self.text(x, y + 5, str(n), 14, P["ink"], "bold", anchor="middle")

    def tooltip(self, x, y, w, title, rows, pinned=False):
        h = 46 + 21 * len(rows)
        self.rect(x + 4, y + 4, w, h, P["void"], rx=6, opacity=0.6)
        self.rect(x, y, w, h, P["ivory"], P["candle"] if pinned else P["bone"], 2, rx=6)
        self.text(x + 14, y + 26, title, 15, P["ink"], "bold")
        if pinned:
            self.text(x + w - 12, y + 24, "📌 pinned", 12, P["ember"], anchor="end")
        yy = y + 50
        for r in rows:
            self.text(x + 14, yy, r, 13, P["umber"])
            yy += 21
        return y + h

    def live_sheet(self, x, y, w, h, name, sub, rows, changed=()):
        """The live character sheet sidebar used on every creator step."""
        self.panel(x, y, w, h, "LIVE SHEET")
        self.text(x + 16, y + 66, name, 18, P["ivory"], "bold", family=SERIF)
        self.text(x + 16, y + 86, sub, 13, P["silver"])
        yy = y + 116
        for label, value in rows:
            hl = label in changed
            if hl:
                self.rect(x + 8, yy - 16, w - 16, 22, P["bruise"], P["candle"], 1, rx=3)
            self.text(x + 16, yy, label, 13, P["silver"])
            self.text(x + w - 16, yy, value + (" ▲" if hl else ""), 13, P["wick"] if hl else P["ivory"], "bold", anchor="end")
            yy += 24

    def steps(self, x, y, items, current):
        """Left rail of steps: (name, state) with state ok / error / warn / todo."""
        self.panel(x, y, 220, 600, "STEPS")
        yy = y + 74
        for i, (name, state) in enumerate(items):
            cur = i == current
            if cur:
                self.rect(x + 8, yy - 22, 204, 32, P["bruise"], P["candle"], 2, rx=4)
            icon = {"ok": ("✓", P["bile"]), "error": ("!", P["red"]), "warn": ("~", P["flame"]), "todo": ("·", P["pewter"])}[state]
            self.text(x + 22, yy, icon[0], 16, icon[1], "bold")
            self.text(x + 44, yy, name, 15, P["ivory"] if cur else P["silver"], "bold" if cur else "normal")
            yy += 46

    def save(self, path):
        body = "\n".join(self.parts)
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" width="{self.w}" height="{self.h}">'
               f'<title>{escape(self.title)}</title>\n{body}\n</svg>\n')
        with open(path, "w") as f:
            f.write(svg)
