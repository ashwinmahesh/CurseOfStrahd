extends TestCase
## Rebinding keys (Improvement Ideas U5, core/input_actions.gd): a new key lands in the InputMap and the settings
## file, a clash inside a list swaps the two commands' keys, the lists don't clash with each other but the walking
## keys clash with both, Escape and F1 can't be taken, and code matching keys by their defaults follows the player's.


func before_each() -> void:
	InputActions.ensure()
	InputActions.reset()


func after_each() -> void:
	InputActions.reset()


func _key(k: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.pressed = true
	return ev


func test_a_new_key_works_and_is_kept() -> void:
	assert_eq(InputActions.bind(&"open_journal", 0, KEY_K), "", "K was free")
	assert_true(_key(KEY_K).is_action_pressed(&"open_journal"), "K opens the journal")
	assert_false(_key(KEY_J).is_action_pressed(&"open_journal"), "J no longer does")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(GameSettings.path), OK)
	var saved := cfg.get_value(GameSettings.SECTION, "keys", {}) as Dictionary
	assert_eq(saved.get("open_journal", []), [KEY_K, KEY_NONE], "kept in the settings file")
	assert_eq(saved.size(), 1, "only what differs from the defaults")
	assert_ne(GameSettings.path, "user://settings.cfg", "tests never touch the player's own settings")
	InputActions.reset()
	assert_true(_key(KEY_J).is_action_pressed(&"open_journal"), "reset brings J back")
	assert_false(InputActions.changed())


func test_a_clash_in_one_list_swaps_the_keys() -> void:
	var note := InputActions.bind(&"open_journal", 0, KEY_C)
	assert_eq(InputActions.keys(&"open_journal")[0], KEY_C)
	assert_eq(InputActions.keys(&"open_sheet")[0], KEY_J, "the Character sheet takes J in exchange")
	assert_true(note.contains("Character") and note.contains("J"), "the note says what moved: %s" % note)


func test_the_lists_only_clash_where_they_meet() -> void:
	# Space ends a turn in fights; exploring, it's free for the journal.
	assert_eq(InputActions.bind(&"open_journal", 0, KEY_SPACE), "")
	assert_eq(InputActions.keys(&"combat_end_turn")[0], KEY_SPACE, "the fight keeps Space")
	# Q turns the camera in both modes, so a fight key on Q takes it from the camera.
	InputActions.bind(&"combat_toggle_log", 0, KEY_Q)
	assert_eq(InputActions.keys(&"camera_rotate_left")[0], KEY_L, "the camera takes the log's old key")


func test_escape_and_f1_keep_their_jobs() -> void:
	assert_ne(InputActions.bind(&"open_map", 0, KEY_ESCAPE), "", "refused with a note")
	assert_ne(InputActions.bind(&"open_map", 0, KEY_F1), "")
	assert_eq(InputActions.keys(&"open_map")[0], KEY_M)


func test_alternates_and_clearing() -> void:
	assert_eq(InputActions.keys(&"move_forward"), [KEY_W, KEY_UP])
	InputActions.bind(&"move_forward", 1, KEY_I)
	assert_eq(InputActions.keys(&"move_forward")[1], KEY_I)
	assert_eq(InputActions.keys(&"open_inventory")[0], KEY_UP, "the inventory takes the arrow in exchange")
	InputActions.clear(&"move_forward", 0)
	assert_eq(InputActions.keys(&"move_forward"), [KEY_I, KEY_NONE], "a lone alternate becomes the key")
	# Its own alternate as its key: the two trade places.
	InputActions.reset()
	InputActions.bind(&"move_forward", 0, KEY_UP)
	assert_eq(InputActions.keys(&"move_forward"), [KEY_UP, KEY_W])


func test_code_matching_default_keys_follows_the_player() -> void:
	assert_eq(InputActions.as_default(_key(KEY_J)), KEY_J, "untouched, a key is itself")
	InputActions.bind(&"open_journal", 0, KEY_K)
	assert_eq(InputActions.as_default(_key(KEY_K)), KEY_J, "K now stands for the journal's J")
	assert_eq(InputActions.as_default(_key(KEY_J)), KEY_NONE, "J does nothing now")
	assert_eq(InputActions.as_default(_key(KEY_ESCAPE)), KEY_ESCAPE, "Escape is always itself")
	assert_eq(InputActions.as_default(_key(KEY_T)), KEY_T, "a key no exploring command uses passes through")


func test_texts_name_the_players_keys() -> void:
	assert_eq(InputActions.fill("{open_journal} journal · {walk} walk"), "J journal · W A S D or the arrows walk")
	InputActions.bind(&"open_journal", 0, KEY_BRACKETLEFT)
	assert_eq(InputActions.fill("{open_journal} journal"), "[ journal")
	assert_eq(InputActions.key_text(&"combat_confirm", 1), "Num Enter")
	for c: Array in InputActions.COMMANDS:
		assert_true(InputActions.BINDINGS.has(c[0]), "%s has default keys" % c[0])
		assert_true(InputActions.LISTS.has(str(c[2])), "%s is in a list" % c[0])
