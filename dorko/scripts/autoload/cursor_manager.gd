extends CanvasLayer
## The verb cursor. Scroll wheel / right-click cycles Eye → Hand → Mouth.
## Selecting an inventory item swaps the cursor to that item's icon.
## Draws on the topmost layer; the OS cursor is hidden.

signal cursor_changed(verb: int, item_id: String)

enum { VERB_EYE, VERB_HAND, VERB_MOUTH, VERB_ITEM }

var verb: int = VERB_EYE
var item_id: String = ""

var _cursor: TextureRect
var _label: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_cursor = TextureRect.new()
	_cursor.texture = AssetLib.tex("cursor_eye")
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.pivot_offset = Vector2(12, 12)
	add_child(_cursor)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)


func _process(_delta: float) -> void:
	var m := get_viewport().get_mouse_position()
	_cursor.position = m - _cursor.pivot_offset
	_label.position = m + Vector2(14, 10)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cycle(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				cycle(1)
			MOUSE_BUTTON_RIGHT:
				# Accessibility fallback: right-click also cycles; with an item
				# held it just puts the item away.
				if verb == VERB_ITEM:
					clear_item()
				else:
					cycle(1)


func cycle(dir: int) -> void:
	if verb == VERB_ITEM:
		_set_verb(VERB_EYE)
	else:
		_set_verb(posmod(verb + dir, 3))
	AudioBus.play_sfx("tick", randf_range(0.95, 1.05), -8.0)
	_bounce()


func _set_verb(v: int) -> void:
	verb = v
	item_id = ""
	match v:
		VERB_EYE:
			_cursor.texture = AssetLib.tex("cursor_eye")
		VERB_HAND:
			_cursor.texture = AssetLib.tex("cursor_hand")
		VERB_MOUTH:
			_cursor.texture = AssetLib.tex("cursor_mouth")
	_cursor.pivot_offset = Vector2(12, 12)
	cursor_changed.emit(verb, item_id)


func set_item(id: String) -> void:
	verb = VERB_ITEM
	item_id = id
	_cursor.texture = AssetLib.item_icon(id)
	_cursor.pivot_offset = Vector2(16, 16)
	cursor_changed.emit(verb, item_id)
	_bounce()


func clear_item() -> void:
	if verb == VERB_ITEM:
		_set_verb(VERB_EYE)


## The 100ms bounce when the verb changes.
func _bounce() -> void:
	_cursor.scale = Vector2(1.45, 1.45)
	var tw := create_tween()
	tw.tween_property(_cursor, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hotspot name (or any hint) shown beside the cursor. "" clears it.
func set_hover_text(text: String) -> void:
	_label.text = text
