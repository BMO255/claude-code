extends CanvasLayer
## Dialogue trees + the dialogue box UI. Trees load from res://data/dialogue/
## (*.json); rooms can also register trees built at runtime (register_tree).
##
## Node format (see docs/CONTRACT.md):
##   { "speaker": "Couch Guy", "text": "..." | ["pool", ...],
##     "portrait": "couch_guy",            (optional, defaults from speaker)
##     "set_flag": "x", "gives_item": "y", (optional, applied when shown)
##     "next": "node_id",                  (optional; absent/null = end)
##     "choices": [ { "text", "next", "requires_flag", "requires_not_flag",
##                    "requires_item", "once", "set_flag", "gives_item" } ] }

signal dialogue_started(id: String)
signal dialogue_finished(id: String)

const DIALOGUE_DIR := "res://data/dialogue"

const PITCH := {
	"Dorko": 0.78,
	"Couch Guy": 0.5,
	"Blue Bomb": 1.45,
	"The Turquoise One": 1.02,
	"Winders XD": 1.25,
	"???": 1.15,
	"Ref": 1.3,
}

const NAME_COLORS := {
	"Dorko": Color(0.55, 0.9, 0.45),
	"Couch Guy": Color(0.75, 0.72, 0.68),
	"Blue Bomb": Color(0.55, 0.65, 1.0),
	"The Turquoise One": Color(0.3, 0.95, 0.85),
}

const USE_FAIL_LINES := [
	"That doesn't do anything.",
	"Nothing. Which is something, I guess.",
	"Those two have no chemistry.",
	"I tried. The universe declined.",
]
const TALK_FAIL_LINES := [
	"It doesn't want to talk. Or can't. Hard to say.",
	"We stood in silence for a while. It was fine.",
	"No response. Story of my life.",
]
const TOUCH_DEFAULT_LINES := [
	"I touched it. We're both the same as before.",
	"It's exactly as solid as it looks.",
	"I'll leave it be.",
]
const COMBINE_FAIL_LINES := [
	"They don't want to be together.",
	"That's not a recipe. That's a cry for help.",
	"Physically possible. Morally no.",
]

var trees: Dictionary = {}
var active: bool = false

var _tree_id: String = ""
var _node_key: String = ""
var _node: Dictionary = {}
var _pitch: float = 1.0
var _typing: bool = false
var _char_accum: float = 0.0
var _blip_count: int = 0
var _queue: Array = []          # [ [tree_id, node_key], ... ] queued dialogues
var _say_counter: int = 0

var _catcher: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _name_label: Label
var _text_label: Label
var _advance_arrow: Label
var _choices_box: VBoxContainer


func _ready() -> void:
	layer = 60
	_load_trees()
	_build_ui()
	visible = false


func _load_trees() -> void:
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var f := FileAccess.open(DIALOGUE_DIR + "/" + fname, FileAccess.READ)
			if f:
				var data = JSON.parse_string(f.get_as_text())
				if typeof(data) == TYPE_DICTIONARY and data.has("id"):
					trees[data.id] = data
				else:
					push_error("DialogueManager: bad dialogue file " + fname)
		fname = dir.get_next()


func register_tree(tree: Dictionary) -> void:
	trees[tree.id] = tree


func _build_ui() -> void:
	_catcher = Control.new()
	_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.05, 0.13, 0.96)
	style.border_color = Color(1.0, 0.55, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(10, 266)
	_panel.size = Vector2(620, 88)
	_catcher.add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	var portrait_holder := VBoxContainer.new()
	hbox.add_child(portrait_holder)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	portrait_holder.add_child(_portrait)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_col)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 10)
	text_col.add_child(_name_label)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("font_size", 11)
	text_col.add_child(_text_label)

	_advance_arrow = Label.new()
	_advance_arrow.text = "v"
	_advance_arrow.position = Vector2(600, 66)
	_advance_arrow.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	_panel.add_child(_advance_arrow)

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 2)
	_choices_box.position = Vector2(240, 120)
	_choices_box.size = Vector2(380, 140)
	_choices_box.alignment = BoxContainer.ALIGNMENT_END
	_catcher.add_child(_choices_box)


# ------------------------------------------------------------------ public API

func start(id: String, node_key := "start") -> void:
	if not trees.has(id):
		push_error("DialogueManager: unknown tree " + id)
		return
	if active:
		_queue.append([id, node_key])
		return
	active = true
	visible = true
	GameState.lock_input()
	_tree_id = id
	dialogue_started.emit(id)
	_show_node(node_key)


## One-off line. text may be a String or an Array (random pick).
func say(speaker: String, text) -> void:
	_say_counter += 1
	var id := "_say_%d" % _say_counter
	register_tree({"id": id, "nodes": {"start": {"speaker": speaker, "text": text}}})
	start(id)


func dorko(text) -> void:
	say("Dorko", text)


## Scripted back-and-forth: lines = [[speaker, text], ...]
func say_seq(lines: Array) -> void:
	_say_counter += 1
	var id := "_seq_%d" % _say_counter
	var nodes := {}
	for i in lines.size():
		var node := {"speaker": lines[i][0], "text": lines[i][1]}
		if i < lines.size() - 1:
			node["next"] = "n%d" % (i + 1)
		nodes["start" if i == 0 else "n%d" % i] = node
	register_tree({"id": id, "nodes": nodes})
	start(id)


func use_fail() -> void:
	dorko(USE_FAIL_LINES.pick_random())


func talk_fail() -> void:
	dorko(TALK_FAIL_LINES.pick_random())


func touch_default() -> void:
	dorko(TOUCH_DEFAULT_LINES.pick_random())


func combine_fail() -> void:
	dorko(COMBINE_FAIL_LINES.pick_random())


func speaker_pitch(speaker: String) -> float:
	var tree: Dictionary = trees.get(_tree_id, {})
	var speakers: Dictionary = tree.get("speakers", {})
	if speakers.has(speaker) and speakers[speaker].has("pitch"):
		return speakers[speaker].pitch
	return PITCH.get(speaker, 1.1)


# ------------------------------------------------------------------ internals

func _show_node(key: String) -> void:
	var nodes: Dictionary = trees[_tree_id].get("nodes", {})
	if not nodes.has(key):
		push_error("DialogueManager: %s has no node '%s'" % [_tree_id, key])
		_close()
		return
	_node_key = key
	_node = nodes[key]
	_clear_choices()

	if _node.has("set_flag") and _node.set_flag:
		GameState.set_flag(_node.set_flag)
	if _node.has("gives_item") and _node.gives_item:
		Inventory.add_item(_node.gives_item)

	var speaker: String = _node.get("speaker", "Dorko")
	_pitch = speaker_pitch(speaker)
	_name_label.text = speaker
	_name_label.add_theme_color_override("font_color", _name_color(speaker))
	_portrait.texture = AssetLib.portrait(_node.get("portrait", _portrait_id(speaker)))

	var text = _node.get("text", "...")
	if typeof(text) == TYPE_ARRAY:  # random_pool
		text = text.pick_random()
	_text_label.text = str(text)
	_text_label.visible_characters = 0
	_char_accum = 0.0
	_blip_count = 0
	_typing = true
	_advance_arrow.visible = false


func _portrait_id(speaker: String) -> String:
	match speaker:
		"The Turquoise One":
			return "turquoise_one"
		_:
			return speaker.to_snake_case()


func _name_color(speaker: String) -> Color:
	if NAME_COLORS.has(speaker):
		return NAME_COLORS[speaker]
	return Color.from_hsv(fmod(abs(float(speaker.hash())) / 1000.0, 1.0), 0.5, 1.0)


func _process(delta: float) -> void:
	if not active:
		return
	if _typing:
		var speed: float = GameState.settings.get("text_speed", 40.0)
		_char_accum += speed * delta
		var total := _text_label.text.length()
		var target: int = min(total, int(_char_accum))
		while _text_label.visible_characters < target:
			_text_label.visible_characters += 1
			var ch := _text_label.text[_text_label.visible_characters - 1]
			if ch != " " and ch != ".":
				_blip_count += 1
				if _blip_count % 2 == 0:
					AudioBus.blip(_pitch)
		if _text_label.visible_characters >= total:
			_finish_typing()
	else:
		_advance_arrow.visible = _choices_box.get_child_count() == 0 and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_populate_choices()


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("advance"):
		_advance()
	for i in 4:
		if event.is_action_pressed("choice_%d" % (i + 1)):
			if not _typing and i < _choices_box.get_child_count():
				_choices_box.get_child(i).pressed.emit()


func _advance() -> void:
	if _typing:
		# First click skips the typewriter…
		_char_accum = 99999.0
		return
	if _choices_box.get_child_count() > 0:
		return  # …but with choices up, the player has to pick one.
	var next = _node.get("next", null)
	if next is String and next != "":
		_show_node(next)
	else:
		_close()


func _populate_choices() -> void:
	var choices: Array = _node.get("choices", [])
	var shown := 0
	for i in choices.size():
		var c: Dictionary = choices[i]
		if not _choice_available(c, i):
			continue
		shown += 1
		var btn := Button.new()
		btn.text = "%d. %s" % [shown, c.get("text", "...")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 10)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.13, 0.08, 0.2, 0.95)
		style.border_color = Color(0.5, 0.9, 0.4)
		style.set_border_width_all(1)
		style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = Color(0.25, 0.14, 0.35, 0.95)
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		btn.pressed.connect(_on_choice.bind(c, i))
		_choices_box.add_child(btn)


func _choice_available(c: Dictionary, idx: int) -> bool:
	if c.get("once", false) and GameState.get_flag(_once_key(idx)):
		return false
	var req = c.get("requires_flag", null)
	if req is String and req != "" and not GameState.get_flag(req):
		return false
	var req_not = c.get("requires_not_flag", null)
	if req_not is String and req_not != "" and GameState.get_flag(req_not):
		return false
	var req_item = c.get("requires_item", null)
	if req_item is String and req_item != "" and not Inventory.has_item(req_item):
		return false
	return true


func _once_key(idx: int) -> String:
	return "_used::%s::%s::%d" % [_tree_id, _node_key, idx]


func _on_choice(c: Dictionary, idx: int) -> void:
	AudioBus.play_sfx("click", 1.1, -6.0)
	if c.get("once", false):
		GameState.set_flag(_once_key(idx))
	if c.has("set_flag") and c.set_flag:
		GameState.set_flag(c.set_flag)
	if c.has("gives_item") and c.gives_item:
		Inventory.add_item(c.gives_item)
	_clear_choices()
	var next = c.get("next", null)
	if next is String and next != "":
		_show_node(next)
	else:
		_close()


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
		_choices_box.remove_child(child)


func _close() -> void:
	active = false
	visible = false
	GameState.unlock_input()
	var finished_id := _tree_id
	_tree_id = ""
	dialogue_finished.emit(finished_id)
	if not _queue.is_empty():
		var nxt: Array = _queue.pop_front()
		# Deferred so back-to-back dialogues don't recurse inside _close.
		call_deferred("start", nxt[0], nxt[1])
