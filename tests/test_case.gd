class_name TestCase
extends Node
## Base class for tests. Methods named test_* are run by tests/test_runner.gd (ADR 0001).

var current_test := ""
var failures: Array[String] = []


func before_each() -> void:
	pass


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected %s, got %s" % [msg, var_to_str(expected), var_to_str(actual)])


func assert_ne(actual: Variant, other: Variant, msg: String = "") -> void:
	if typeof(actual) == typeof(other) and actual == other:
		fail("%s expected anything but %s" % [msg, var_to_str(other)])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		fail("%s expected %s..%s, got %s" % [msg, lo, hi, actual])
