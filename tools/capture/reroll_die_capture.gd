extends Node
## make capture SCENE=res://tools/capture/reroll_die_capture.tscn NAME=reroll_die FRAMES=10
## The big d20's words for a d20 rolled again and for what was added after the roll (Ashwin, 2026-10-26): Heroic Inspiration
## after a low throw, the same under Advantage (one die rolled again), and Dark One's Own Luck and Bardic Inspiration on a save.
## The die itself is at rest on its last throw (a still capture has no motion; the sets-aside first throw shows in play).

const ROLLS: Array[Dictionary] = [
	{"name": "1_inspiration", "kind": "check", "natural": 17, "rolls": [17], "total": 21, "target": 14, "success": true, "who": "Ilse Varga",
		"label": "Intimidation", "modifier": 4, "parts": [{"label": "Str modifier", "value": 2}, {"label": "Proficiency", "value": 2}],
		"extra": 0, "extra_label": "", "rerolls": [{"source": "Heroic Inspiration", "before": [4], "before_kept": 4, "after": [17], "after_kept": 17}],
		"added": []},
	{"name": "2_inspiration_advantage", "kind": "check", "natural": 15, "rolls": [15, 9], "total": 19, "target": 18, "success": true,
		"who": "Hedda Ironvow", "label": "Athletics", "modifier": 4, "advantage": true,
		"parts": [{"label": "Str modifier", "value": 2}, {"label": "Proficiency", "value": 2}], "extra": 0, "extra_label": "",
		"rerolls": [{"source": "Heroic Inspiration", "before": [3, 9], "before_kept": 9, "after": [15, 9], "after_kept": 15}], "added": []},
	{"name": "3_own_luck", "kind": "save", "natural": 6, "rolls": [6], "total": 18, "target": 15, "success": true, "who": "Kip Smudgewick",
		"label": "Wisdom saving throw", "modifier": 3, "parts": [{"label": "Wis modifier", "value": 1}, {"label": "Proficiency", "value": 2}],
		"extra": 9, "extra_label": "+ Bardic Inspiration 3 + Dark One's Own Luck 6", "rerolls": [],
		"added": [{"source": "Bardic Inspiration", "amount": 3, "total": 12, "success": false},
			{"source": "Dark One's Own Luck", "amount": 6, "total": 18, "success": true}]},
]


func capture_shots(tool: Node, out: String) -> void:
	for r: Dictionary in ROLLS:
		var panel := DiceRoll.new()
		add_child(panel)
		panel.place_for_screen()
		panel.roll(r)
		await tool.call("wait_frames", 12)
		tool.call("_shot", "%s_%s.png" % [out, str(r["name"])])
		panel.queue_free()
		await tool.call("wait_frames", 2)
