extends Node
## Global game state: story flags, current room, input locking, settings,
## and save/load to user://save.json.

signal flag_changed(flag_name: String, value: bool)

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"

var flags: Dictionary = {}
var current_room: String = ""
var current_spawn: String = "default"

# Counting lock so dialogue + overlay + cutscene can each hold it independently.
var _input_locks: int = 0

var settings: Dictionary = {
	"master_vol": 1.0,
	"music_vol": 0.8,
	"sfx_vol": 0.9,
	"vhs_filter": true,
	"text_speed": 40.0,   # typewriter chars per second
	"fullscreen": false,
}


func _ready() -> void:
	load_settings()
	# Apply after every autoload exists (AudioBus, Fx come later in the list).
	call_deferred("apply_settings")


# ------------------------------------------------------------------ flags

func set_flag(flag_name: String, value: bool = true) -> void:
	var changed: bool = not flags.has(flag_name) or flags[flag_name] != value
	flags[flag_name] = value
	if changed:
		flag_changed.emit(flag_name, value)
	# Autosave on story progress, but never while in menus.
	if current_room != "" and not flag_name.begins_with("_"):
		save_game()


func get_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func clear_flag(flag_name: String) -> void:
	set_flag(flag_name, false)


# ------------------------------------------------------------------ input lock

func lock_input() -> void:
	_input_locks += 1


func unlock_input() -> void:
	_input_locks = max(0, _input_locks - 1)


func is_input_locked() -> bool:
	return _input_locks > 0


# ------------------------------------------------------------------ save / load

func new_game() -> void:
	flags = {}
	current_room = ""
	current_spawn = "default"
	_input_locks = 0
	Inventory.reset()
	# a held cursor item from a previous run/save-peek must not survive
	CursorManager.clear_item()


func save_game() -> void:
	var data := {
		"flags": flags,
		"items": Inventory.items,
		"room": current_room,
		"spawn": current_spawn,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Restores state and returns the saved room id ("" if no/invalid save).
## Caller (main menu) is responsible for routing to the room.
func load_game() -> String:
	if not has_save():
		return ""
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	new_game()
	flags = data.get("flags", {})
	current_spawn = data.get("spawn", "default")
	for id in data.get("items", []):
		Inventory.add_item(id, true)
	return data.get("room", "")


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


# ------------------------------------------------------------------ settings

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			settings[k] = data[k]


func apply_settings() -> void:
	AudioBus.set_volume("Master", settings.master_vol)
	AudioBus.set_volume("Music", settings.music_vol)
	AudioBus.set_volume("SFX", settings.sfx_vol)
	Fx.set_vhs_enabled(settings.vhs_filter)
	if not DisplayServer.get_name() == "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
