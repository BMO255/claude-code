class_name Hotspot
extends Area2D
## An interactive region. Rooms create these through BaseRoom.add_hotspot().
## Behavior is wired with Callables: on_look / on_touch / on_use_item, plus a
## dialogue id for the Mouth verb. Undefined behaviors fall back to Dorko's
## generic dry lines.

var hotspot_name := ""
var look = ""                       # String or Array of variants
var talk_dialogue_id := ""
var interact_point := Vector2.ZERO  # where Dorko walks to before acting
var walk_required := true
var enabled := true: set = set_enabled
var on_look := Callable()
var on_touch := Callable()
var on_use_item := Callable()       # func(item_id: String) -> bool
var visual: CanvasItem = null       # optional sprite to pulse on hover
var outline_size := Vector2.ZERO    # hover outline half-extents source

var hovered := false
var _phase := 0.0


func _ready() -> void:
	z_index = 900  # outline draws above room art


func _process(delta: float) -> void:
	if hovered:
		_phase += delta
		queue_redraw()


func _draw() -> void:
	if not hovered or outline_size == Vector2.ZERO:
		return
	# Faint animated outline: a rectangle that gently breathes.
	var grow := 2.0 + sin(_phase * 5.0) * 1.5
	var a := 0.35 + 0.15 * sin(_phase * 5.0)
	var r := Rect2(-outline_size / 2.0 - Vector2(grow, grow), outline_size + Vector2(grow, grow) * 2.0)
	draw_rect(r, Color(1.0, 0.95, 0.6, a), false, 1.0)


func set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		set_hovered(false)


func set_hovered(h: bool) -> void:
	if hovered == h:
		return
	hovered = h
	_phase = 0.0
	queue_redraw()
	if visual and is_instance_valid(visual):
		visual.modulate = Color(1.12, 1.12, 1.08) if h else Color.WHITE


func get_interact_point() -> Vector2:
	return interact_point if interact_point != Vector2.ZERO else global_position


func do_look() -> void:
	if on_look.is_valid():
		on_look.call()
	elif (look is String and look != "") or (look is Array and not look.is_empty()):
		DialogueManager.dorko(look)
	else:
		DialogueManager.dorko("It's %s. Looking at it changes nothing." % (hotspot_name.to_lower() if hotspot_name != "" else "something"))


func do_touch() -> void:
	if on_touch.is_valid():
		on_touch.call()
	else:
		DialogueManager.touch_default()


func do_talk() -> void:
	if talk_dialogue_id != "":
		DialogueManager.start(talk_dialogue_id)
	else:
		DialogueManager.talk_fail()


func do_use(item_id: String) -> void:
	var handled := false
	if on_use_item.is_valid():
		handled = bool(on_use_item.call(item_id))
	if not handled:
		DialogueManager.use_fail()


## Pickup helper: fly-to-bar animation + pop, in one call.
func give_item(id: String) -> void:
	if Inventory.add_item(id):
		UILayer.fly_item(id, global_position)
