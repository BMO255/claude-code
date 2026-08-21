extends CanvasLayer
## Full-screen effects: the togglable VHS filter, screen flash, screen shake.

var _vhs_rect: ColorRect
var _flash_rect: ColorRect

var _shake_time := 0.0
var _shake_strength := 0.0
var _shake_target: Node = null
var _shake_origin := Vector2.ZERO


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vhs_rect = ColorRect.new()
	_vhs_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/vhs.gdshader")
	_vhs_rect.material = mat
	add_child(_vhs_rect)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.modulate.a = 0.0
	add_child(_flash_rect)


func set_vhs_enabled(enabled: bool) -> void:
	_vhs_rect.visible = enabled


func flash(color := Color.WHITE, duration := 0.18) -> void:
	_flash_rect.color = color
	_flash_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash_rect, "modulate:a", 0.0, duration)


## Shakes the current scene (or the top overlay if one is open).
func shake(duration := 0.35, strength := 6.0) -> void:
	_end_shake()
	_shake_target = SceneRouter.top_overlay()
	if _shake_target == null:
		_shake_target = get_tree().current_scene
	if _shake_target == null or not ("position" in _shake_target):
		_shake_target = null
		return
	_shake_origin = _shake_target.position
	_shake_time = duration
	_shake_strength = strength


func _process(delta: float) -> void:
	if _shake_target == null:
		return
	if not is_instance_valid(_shake_target):
		_shake_target = null
		return
	_shake_time -= delta
	if _shake_time <= 0.0:
		_end_shake()
		return
	var s := _shake_strength * minf(1.0, _shake_time / 0.15)  # ease out at the tail
	_shake_target.position = _shake_origin + Vector2(randf_range(-s, s), randf_range(-s, s))


func _end_shake() -> void:
	if _shake_target and is_instance_valid(_shake_target):
		_shake_target.position = _shake_origin
	_shake_target = null
