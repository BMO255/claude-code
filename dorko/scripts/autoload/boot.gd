extends Node
## First autoload. Registers input actions in code (kept out of project.godot so
## the whole input surface is documented in one place) and reads CLI args used
## by the headless test harness (--room <id>, --smoke).

# Set from user CLI args ("godot --path dorko -- --room kitchen").
var launch_room: String = ""
var smoke_test: bool = false
var dump_assets: bool = false  # bake generated textures to assets/images/*.png


func _enter_tree() -> void:
	_setup_input()
	_parse_args()


func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("move_up", [KEY_W, KEY_UP])
	_action("move_down", [KEY_S, KEY_DOWN])
	_action("inventory", [KEY_I, KEY_TAB])
	_action("advance", [KEY_SPACE, KEY_ENTER])
	_action("pause", [KEY_ESCAPE])
	_action("choice_1", [KEY_1])
	_action("choice_2", [KEY_2])
	_action("choice_3", [KEY_3])
	_action("choice_4", [KEY_4])
	_action("battle_uppercut", [KEY_SPACE])


func _action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action_name, ev)


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--room":
				if i + 1 < args.size():
					launch_room = args[i + 1]
					i += 1
			"--smoke":
				smoke_test = true
			"--dump-assets":
				dump_assets = true
		i += 1
