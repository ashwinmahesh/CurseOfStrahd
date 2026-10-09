extends SceneTree
## Times the enemy AI's turns in a fight (Functional QA's FN-14: a big fight's enemy turn froze the screen). Plays the
## fight with the pregens on autopilot and, before each AI turn, times its parts on their own: the reachable squares,
## the Opportunity Attack threats, the whole plan (plan_turn), then the turn itself in the combat view's steps: its plan
## (think, on the view's worker thread) and the rest (begin and finish, on the main thread).
##
##   godot --headless --script res://tools/balance/ai_profile.gd -- --location=<id> --fight=<id> [--level=n] [--seed=n]

const Sim := preload("res://tools/balance/balance_sim.gd")


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var errors: Array[String] = []
	var party: Array[String] = ["ilse_varga", "hedda_ironvow", "silvain_aster", "tamsin_tealeaf"]
	var e := Sim.location_fight(str(args.get("location", "")), str(args.get("fight", "")), int(args.get("level", "6")),
		party, DiceRoller.new(int(args.get("seed", "1"))), errors)
	if e == null:
		printerr(errors)
		quit(1)
		return
	Difficulty.named(str(args.get("mode", "balanced"))).prepare(e)
	e.default_player_reaction = "auto"
	e.start()
	var pilot := PartyAutopilot.new(e)
	var rows: Array[Dictionary] = []
	var guard := 0
	while e.state == Encounter.State.ACTIVE and e.round_no <= 12 and guard < 400:
		guard += 1
		var c := e.current()
		if c.is_player_controlled():
			pilot.play(c)
			while e.pending != null:
				e.answer_reaction(true)
			if e.state == Encounter.State.ACTIVE and e.current() == c:
				e.end_turn()
			continue
		var t0 := Time.get_ticks_usec()
		var reach := e.reachable_for(c)
		var t1 := Time.get_ticks_usec()
		var t2 := t1
		var t3 := t1
		if args.has("parts"):
			e.ai._threats(c)
			t2 = Time.get_ticks_usec()
			Creature.begin_read()
			e.ai.plan_turn(c)
			Creature.end_read()
			t3 = Time.get_ticks_usec()
		# The turn in its three steps: what the combat view runs on the main thread (begin, finish) and on the worker
		# thread (think).
		var r := e.begin_ai_turn()
		var tb := Time.get_ticks_usec()
		var tt := tb
		if r == null:
			var thought := e.ai.think(c)
			tt = Time.get_ticks_usec()
			e.finish_ai_turn(thought)
		while e.pending != null:
			e.answer_reaction(true)
		var t4 := Time.get_ticks_usec()
		rows.append({"who": c.name(), "round": e.round_no, "cells": reach.size(), "reach_ms": (t1 - t0) / 1000.0,
			"threats_ms": (t2 - t1) / 1000.0, "plan_ms": (t3 - t2) / 1000.0, "turn_ms": (t4 - t3) / 1000.0,
			"think_ms": (tt - tb) / 1000.0, "main_ms": (t4 - t3 - (tt - tb)) / 1000.0,
			"kind": str(e.ai.last_plan.get("kind", ""))})
	# The fight's whole log, hashed: the same seed must give the same fight after a change that only makes planning
	# cheaper (what the AI decides can't move).
	var total := 0.0
	for r0: Dictionary in rows:
		total += float(r0["turn_ms"])
	print("log %s · %d lines · AI turns %.0f ms in all, %.1f ms on average" % [e.log.dump().sha1_text().substr(0, 12),
		e.log.entries.size(), total, total / maxf(1.0, float(rows.size()))])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["turn_ms"]) > float(b["turn_ms"]))
	print("%s: %d AI turns, outcome %s" % [e.title, rows.size(), e.outcome])
	var main := 0.0
	for r1: Dictionary in rows:
		main = maxf(main, float(r1["main_ms"]))
	print("the main thread's part of a turn (all but the plan): %.1f ms at most" % main)
	print("%-22s %5s %6s %8s %8s %8s %8s %8s %8s  %s" % ["who", "round", "cells", "reach", "threats", "plan", "turn", "think",
		"main", "kind"])
	for r: Dictionary in rows.slice(0, 12):
		print("%-22s %5d %6d %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f  %s" % [r["who"], r["round"], r["cells"], r["reach_ms"],
			r["threats_ms"], r["plan_ms"], r["turn_ms"], r["think_ms"], r["main_ms"], r["kind"]])
	quit(0)
