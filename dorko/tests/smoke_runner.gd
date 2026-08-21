extends Node
## Headless CI smoke pass. Lives directly under root (not in the current
## scene), so it survives room transitions. Prints "SMOKE OK" + exits 0 on
## success; prints "SMOKE FAIL: …" lines + exits 1 otherwise. Script errors
## surface on stderr and are grepped by the harness.

var ok := true


func fail(msg: String) -> void:
	print("SMOKE FAIL: " + msg)
	ok = false


## Clicks through any open (and queued) dialogue until the box is closed.
func drain_dialogue() -> void:
	for i in 40:
		if not DialogueManager.active:
			return
		DialogueManager._advance()
		await get_tree().create_timer(0.1).timeout


func run() -> void:
	print("SMOKE: core checks")
	GameState.new_game()
	GameState.settings.text_speed = 5000.0

	# --- inventory + combos
	Inventory.add_item("bread", true)
	Inventory.add_item("sliced_meat", true)
	if Inventory.combine("bread", "sliced_meat") != "sandwich":
		fail("combine bread+sliced_meat")
	Inventory.add_item("cold_cheese_slice", true)
	if Inventory.combine("cold_cheese_slice", "sandwich") != "good_sandwich":
		fail("combine cheese+sandwich")
	await drain_dialogue()  # combine lines open the dialogue box by design

	# --- flags + save/load
	GameState.set_flag("smoke_flag")
	if not GameState.get_flag("smoke_flag"):
		fail("flags")
	GameState.current_room = "dev_room"
	GameState.save_game()
	GameState.current_room = ""
	if GameState.load_game() != "dev_room":
		fail("save/load")
	GameState.new_game()

	# --- dialogue open/advance/close
	DialogueManager.say("Dorko", "Smoke test line one.")
	await get_tree().create_timer(0.4).timeout
	if not DialogueManager.active:
		fail("dialogue did not open")
	DialogueManager._advance()
	await get_tree().create_timer(0.3).timeout
	if DialogueManager.active:
		DialogueManager._advance()
		await get_tree().create_timer(0.3).timeout
	if DialogueManager.active:
		fail("dialogue did not close (typing=%s node=%s choices=%d)" % [
			DialogueManager._typing, str(DialogueManager._node),
			DialogueManager._choices_box.get_child_count()])
		# force it shut so the room tour can proceed
		DialogueManager._close()

	# --- M2: pizza-roll timing math (pure function; the exact spec windows)
	var pizza = load("res://scripts/minigames/pizza_roll.gd")
	if pizza:
		var t0 := 100000
		if pizza.classify(t0 + 600, t0) != "PERFECT":
			fail("pizza classify: exact beat should be PERFECT")
		if pizza.classify(t0 + 600 + 99, t0) != "OK":
			fail("pizza classify: +99ms should be OK")
		if pizza.classify(t0 + 600 - 99, t0) != "OK":
			fail("pizza classify: -99ms should be OK")
		if pizza.classify(t0 + 600 + 101, t0) != "MISS":
			fail("pizza classify: +101ms should be MISS")
		if pizza.classify(t0 + 600 - 101, t0) != "MISS":
			fail("pizza classify: -101ms should be MISS")
		if pizza.classify(t0 - 200, t0) != "":
			fail("pizza classify: pre-window click should be free")

	# --- M2: keypad knows the birthday backwards
	var keypad = load("res://scripts/minigames/keypad.gd")
	if keypad and keypad.CODE != "4170":
		fail("keypad code is not 4170")

	# --- M4: wire panel rules (red -> yellow -> blue; green = the joke)
	var wires = load("res://scripts/minigames/wire_panel.gd")
	if wires:
		if wires.judge([], "red") != "ok":
			fail("wires: red first should be ok")
		if wires.judge(["red"], "yellow") != "ok":
			fail("wires: yellow second should be ok")
		if wires.judge(["red", "yellow"], "blue") != "done":
			fail("wires: blue third should finish")
		if wires.judge([], "green") != "green_trick":
			fail("wires: green should be the trick")
		if wires.judge(["red", "yellow"], "green") != "green_trick":
			fail("wires: green is the trick at any point")
		if wires.judge([], "yellow") != "wrong":
			fail("wires: yellow first should be wrong")
		if wires.judge(["red"], "purple") != "wrong":
			fail("wires: purple should always be wrong")

	# --- visit every room that exists
	print("SMOKE: touring rooms")
	for room_id in SceneRouter.ROOMS:
		if not ResourceLoader.exists(SceneRouter.ROOMS[room_id]):
			print("SMOKE: skip unbuilt room " + room_id)
			continue
		if room_id == "turquoise_room":
			continue  # covered by the dedicated battle-flow pass below
		print("SMOKE: room " + room_id)
		GameState.new_game()
		await SceneRouter.goto_room(room_id)
		await get_tree().create_timer(1.2).timeout
		await drain_dialogue()  # rooms may open with scripted lines
		if room_id == "orange_room":
			await _exercise_overlays()

	# --- M5: monologue -> ROUND 1 -> battle scene -> one-hit KO -> the count
	if ResourceLoader.exists("res://scenes/rooms/turquoise_room.tscn") \
		and ResourceLoader.exists("res://scenes/minigames/battle.tscn"):
		print("SMOKE: battle flow")
		GameState.new_game()
		await SceneRouter.goto_room("turquoise_room")
		await get_tree().create_timer(2.2).timeout  # monologue auto-starts at 1.5s
		if not DialogueManager.active:
			fail("turquoise monologue did not start")
		await drain_dialogue()
		await get_tree().create_timer(3.2).timeout  # ROUND 1 beat + scene change
		var battle = get_tree().current_scene
		if battle == null or not battle.scene_file_path.ends_with("battle.tscn"):
			fail("battle scene did not load after monologue")
		else:
			await get_tree().create_timer(1.5).timeout  # intro -> FIGHT
			battle._jab(-1)
			for i in 30:
				await get_tree().create_timer(1.0).timeout
				if GameState.get_flag("battle_won"):
					break
			if not GameState.get_flag("battle_won"):
				fail("battle did not reach battle_won after a jab")

	# --- M6: stairs -> real orange room -> credits -> game_completed -> menu
	if GameState.get_flag("battle_won") and ResourceLoader.exists("res://scenes/ui/ending.tscn"):
		print("SMOKE: ending flow")
		var deadline := Time.get_ticks_msec() + 150000
		var skipped_credits := false
		while Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(1.0).timeout
			if DialogueManager.active:
				await drain_dialogue()  # the cutscene lines need advancing
			var top = SceneRouter.top_overlay()
			if top != null and not skipped_credits and top.has_method("_finish"):
				await get_tree().create_timer(2.5).timeout  # let the pulse tick a bit
				top._finish()
				skipped_credits = true
			if GameState.get_flag("game_completed"):
				break
		if not GameState.get_flag("game_completed"):
			fail("ending flow did not reach game_completed")
		else:
			await get_tree().create_timer(2.0).timeout  # menu reloads

	if ok:
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED")
		get_tree().quit(1)


## Push each orange-room overlay for a moment so their _ready/_process run
## headlessly, then pop. Any script error surfaces on stderr.
func _exercise_overlays() -> void:
	for path in ["res://scripts/minigames/keypad.gd",
			"res://scripts/minigames/pc_desktop.gd",
			"res://scripts/minigames/pizza_roll.gd"]:
		if not ResourceLoader.exists(path):
			continue
		print("SMOKE: overlay " + path.get_file())
		SceneRouter.push_overlay(load(path).new())
		await get_tree().create_timer(1.4).timeout
		if SceneRouter.has_overlay():
			SceneRouter.pop_overlay()
		await get_tree().create_timer(0.3).timeout
		await drain_dialogue()
