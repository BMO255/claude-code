extends Node
## Room transitions with fade-to-black + VHS tracking-line sweep, spawn point
## routing, full-screen overlays (PC desktop, minigames), and autosave.

signal room_changed(room_id: String)

const ROOMS := {
	"dev_room": "res://scenes/rooms/dev_room.tscn",
	"orange_room": "res://scenes/rooms/orange_room.tscn",
	"living_room": "res://scenes/rooms/living_room.tscn",
	"kitchen": "res://scenes/rooms/kitchen.tscn",
	"basement": "res://scenes/rooms/basement.tscn",
	"turquoise_room": "res://scenes/rooms/turquoise_room.tscn",
	"orange_room_real": "res://scenes/rooms/orange_room_real.tscn",
}
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const FADE_TIME := 0.4

var transitioning := false

var _overlay_layer: CanvasLayer
var _overlays: Array = []
var _fade_rect: ColorRect
var _track_line: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 110
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	fade_layer.add_child(_fade_rect)
	_track_line = ColorRect.new()
	_track_line.color = Color(1, 1, 1, 0.0)
	_track_line.size = Vector2(640, 3)
	_track_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_track_line)


# ------------------------------------------------------------------ rooms

func goto_room(room_id: String, spawn := "default") -> void:
	if transitioning:
		return
	if not ROOMS.has(room_id):
		push_error("SceneRouter: unknown room " + room_id)
		return
	var path: String = ROOMS[room_id]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: room not built yet: " + room_id)
		return
	transitioning = true
	GameState.lock_input()
	await _fade_out()
	GameState.current_room = room_id
	GameState.current_spawn = spawn
	_swap_scene(load(path).instantiate())
	GameState.save_game()  # autosave on every room transition
	room_changed.emit(room_id)
	await _fade_in()
	GameState.unlock_input()
	transitioning = false


## Non-room full scenes (battle, ending, menu) with the same fade.
func goto_scene(path: String) -> void:
	if transitioning:
		return
	transitioning = true
	GameState.lock_input()
	await _fade_out()
	_swap_scene(load(path).instantiate())
	await _fade_in()
	GameState.unlock_input()
	transitioning = false


func goto_main_menu() -> void:
	AudioBus.stop_music()
	GameState.current_room = ""
	goto_scene(MAIN_MENU)


func _swap_scene(scene: Node) -> void:
	# Overlays never survive a scene change.
	while not _overlays.is_empty():
		pop_overlay()
	var old := get_tree().current_scene
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	if old:
		old.queue_free()


# ------------------------------------------------------------------ overlays

func push_overlay(node: Node) -> void:
	_overlays.append(node)
	_overlay_layer.add_child(node)
	GameState.lock_input()


func pop_overlay() -> void:
	if _overlays.is_empty():
		return
	var node = _overlays.pop_back()
	if is_instance_valid(node):
		_overlay_layer.remove_child(node)
		node.queue_free()
	GameState.unlock_input()


func has_overlay() -> bool:
	return not _overlays.is_empty()


func top_overlay() -> Node:
	return null if _overlays.is_empty() else _overlays.back()


# ------------------------------------------------------------------ fade

func _fade_out() -> void:
	await _fade(0.0, 1.0)


func _fade_in() -> void:
	await _fade(1.0, 0.0)


func _fade(from_a: float, to_a: float) -> void:
	_fade_rect.modulate.a = from_a
	_track_line.color.a = 0.3
	_track_line.position.y = -3.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_fade_rect, "modulate:a", to_a, FADE_TIME)
	tw.tween_property(_track_line, "position:y", 362.0, FADE_TIME)
	await tw.finished
	_track_line.color.a = 0.0
