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

	# --- visit every room that exists
	print("SMOKE: touring rooms")
	for room_id in SceneRouter.ROOMS:
		if not ResourceLoader.exists(SceneRouter.ROOMS[room_id]):
			print("SMOKE: skip unbuilt room " + room_id)
			continue
		print("SMOKE: room " + room_id)
		GameState.new_game()
		await SceneRouter.goto_room(room_id)
		await get_tree().create_timer(1.2).timeout
		await drain_dialogue()  # rooms may open with scripted lines

	if ok:
		print("SMOKE OK")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED")
		get_tree().quit(1)
