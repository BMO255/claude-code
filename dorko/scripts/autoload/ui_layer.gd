extends CanvasLayer
## In-game UI: the slide-out inventory bar, speech bubbles, floating feedback
## text, the item-pickup fly animation, and the pause menu.

const BAR_SHOWN_Y := 318.0
const BAR_HIDDEN_Y := 358.0

var _bar: PanelContainer
var _slots_box: HBoxContainer
var _bar_pinned := false
var _pause_panel: CenterContainer
var _paused := false


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bar()
	_build_pause_menu()
	Inventory.changed.connect(_refresh_slots)
	Inventory.selection_feedback.connect(func(text): toast(text))


# ------------------------------------------------------------------ inventory bar

func _build_bar() -> void:
	_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.11, 0.92)
	style.border_color = Color(0.55, 0.45, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	_bar.add_theme_stylebox_override("panel", style)
	_bar.position = Vector2(112, BAR_HIDDEN_Y)
	add_child(_bar)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 2)
	_bar.add_child(_slots_box)
	for i in Inventory.MAX_SLOTS:
		_slots_box.add_child(InvSlot.new(i))
	_refresh_slots()


func _refresh_slots() -> void:
	for i in _slots_box.get_child_count():
		var slot: InvSlot = _slots_box.get_child(i)
		slot.set_item(Inventory.items[i] if i < Inventory.items.size() else "")
	# keep centered whatever the container computes
	_bar.reset_size()
	_bar.position.x = (640.0 - _bar.size.x) / 2.0


func _process(_delta: float) -> void:
	if _paused:
		return
	var mouse := get_viewport().get_mouse_position()
	var want_shown := (_bar_pinned or mouse.y > 348.0 or (_bar.position.y < BAR_HIDDEN_Y - 2.0 and mouse.y > 300.0)) \
		and not DialogueManager.active
	var target := BAR_SHOWN_Y if want_shown else BAR_HIDDEN_Y
	_bar.position.y = lerp(_bar.position.y, target, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not DialogueManager.active and not _paused:
		_bar_pinned = not _bar_pinned
	if event.is_action_pressed("pause"):
		# One Esc, several meanings — priority order matters here.
		if CursorManager.verb == CursorManager.VERB_ITEM:
			CursorManager.clear_item()
		elif _paused:
			toggle_pause()
		elif DialogueManager.active or SceneRouter.has_overlay() or SceneRouter.transitioning:
			pass  # dialogue/overlays own Esc themselves
		elif GameState.current_room != "":
			toggle_pause()


## One inventory cell. Click = select/look, drag onto another = combine.
class InvSlot:
	extends Control
	var index: int
	var item_id := ""
	var _icon: TextureRect

	func _init(i: int) -> void:
		index = i
		custom_minimum_size = Vector2(38, 38)
		var bg := TextureRect.new()
		bg.texture = AssetLib.tex("slot_bg")
		bg.position = Vector2(1, 1)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)
		_icon = TextureRect.new()
		_icon.position = Vector2(3, 3)
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func set_item(id: String) -> void:
		item_id = id
		_icon.texture = AssetLib.item_icon(id) if id != "" else null

	func _on_enter() -> void:
		if item_id != "":
			CursorManager.set_hover_text(Inventory.display_name(item_id))

	func _on_exit() -> void:
		CursorManager.set_hover_text("")

	func _gui_input(event: InputEvent) -> void:
		if item_id == "":
			return
		if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if CursorManager.verb == CursorManager.VERB_EYE:
				DialogueManager.dorko(Inventory.look_text(item_id))
			else:
				CursorManager.set_item(item_id)
			accept_event()

	func _get_drag_data(_at: Vector2):
		if item_id == "":
			return null
		var preview := TextureRect.new()
		preview.texture = AssetLib.item_icon(item_id)
		set_drag_preview(preview)
		return {"item": item_id}

	func _can_drop_data(_at: Vector2, data) -> bool:
		return item_id != "" and typeof(data) == TYPE_DICTIONARY and data.has("item") and data.item != item_id

	func _drop_data(_at: Vector2, data) -> void:
		var result := Inventory.combine(data.item, item_id)
		if result == "":
			DialogueManager.combine_fail()


# ------------------------------------------------------------------ feedback

## Small rising text at a canvas position ("PERFECT", "+ Bread", …).
func float_text(pos: Vector2, text: String, color := Color.WHITE) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.z_index = 10
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 22.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


## Quiet corner notification (inventory full, autosave, etc.)
func toast(text: String) -> void:
	float_text(Vector2(16, 300), text, Color(1.0, 0.9, 0.6))


## Speech bubble that follows a world node (Couch Guy barks). Rooms are
## unscrolled, so world position == canvas position.
func bubble(target: Node2D, text: String, pitch := 1.0, duration := 2.6) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.95, 0.9, 0.95)
	style.border_color = Color(0.15, 0.1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(min(150.0, text.length() * 5.5 + 20.0), 0)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.15))
	lbl.add_theme_font_size_override("font_size", 10)
	panel.add_child(lbl)
	add_child(panel)
	panel.reset_size()
	var follow := func():
		if is_instance_valid(target):
			panel.position = target.global_position + Vector2(-panel.size.x / 2.0, -80.0 - panel.size.y)
			panel.position.x = clamp(panel.position.x, 4.0, 636.0 - panel.size.x)
			panel.position.y = max(panel.position.y, 4.0)
	follow.call()
	var timer := Timer.new()
	timer.wait_time = 1.0 / 30.0
	timer.timeout.connect(follow)
	panel.add_child(timer)
	timer.start()
	AudioBus.blip(pitch)
	var tw := create_tween()
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(panel.queue_free)


## Item icon flies from a canvas position into the inventory bar.
func fly_item(id: String, from_pos: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = AssetLib.item_icon(id)
	icon.position = from_pos - Vector2(16, 16)
	add_child(icon)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(icon, "position", Vector2(304, 330), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.45)
	tw.chain().tween_callback(icon.queue_free)
	_bar.position.y = BAR_SHOWN_Y  # peek the bar so the item visibly lands


# ------------------------------------------------------------------ pause menu

func _build_pause_menu() -> void:
	_pause_panel = CenterContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.11, 0.97)
	style.border_color = Color(1.0, 0.55, 0.1)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	_pause_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "— PAUSED —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for entry in [["Resume", _on_resume], ["Save", _on_save], ["Options", _on_options], ["Main Menu", _on_main_menu]]:
		var btn := Button.new()
		btn.text = entry[0]
		btn.pressed.connect(entry[1])
		vbox.add_child(btn)


func toggle_pause() -> void:
	_paused = not _paused
	_pause_panel.visible = _paused
	get_tree().paused = _paused
	AudioBus.play_sfx("click", 0.9 if _paused else 1.1)


func _on_resume() -> void:
	toggle_pause()


func _on_save() -> void:
	GameState.save_game()
	toast("Saved. The house remembers.")


func _on_options() -> void:
	# Options panel arrives with the main menu milestone; shared scene.
	toast("Options live in the main menu for now.")


func _on_main_menu() -> void:
	toggle_pause()
	SceneRouter.goto_main_menu()
