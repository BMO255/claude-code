extends Control
## Keypad overlay for the orange room's door. The code is 4170 — Dorko's
## birthday (07/14) backwards, per the sticky note behind the poster and the
## crumpled card in the wastebasket. Wrong answers get laughed at.
##
## Push with: SceneRouter.push_overlay(load("res://scripts/minigames/keypad.gd").new())
## Handles its own Esc (overlays must). Digits also type from the keyboard.

const CODE := "4170"
const MAX_DIGITS := 4
const SUCCESS_LINE := "My own birthday, backwards. This door knew me before I did."
const TAUNTS := ["HA HA HA", "NO.", "COLDER", "NOT IT", "HA. NO."]

# 3x5 pixel glyphs for the chunky button faces (and the scratched-in "HA").
const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "001", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
	"C": ["111", "100", "100", "100", "111"],
	"O": ["111", "101", "101", "101", "111"],
	"K": ["101", "110", "100", "110", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"H": ["101", "101", "111", "101", "101"],
	"A": ["010", "101", "111", "101", "101"],
}

const COL_ENTRY := Color(0.35, 1.0, 0.5)
const COL_TAUNT := Color(1.0, 0.35, 0.3)
const COL_OPEN := Color(0.6, 1.0, 0.6)

var _entry := ""
var _busy := false      # taunt or open sequence in progress; buttons ignored
var _opening := false   # success sequence; even Esc waits for the door
var _panel: Control
var _display: Label
var _taunt_timer: Timer
var _open_timer: Timer


func _ready() -> void:
	name = "Keypad"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = Control.new()
	_panel.position = Vector2(232, 56)
	_panel.size = Vector2(176, 248)
	add_child(_panel)

	var plate := TextureRect.new()
	plate.texture = AssetLib.get_or_build("keypad_plate", _build_plate_tex)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(plate)

	_display = Label.new()
	_display.position = Vector2(16, 28)
	_display.size = Vector2(144, 36)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display.add_theme_font_size_override("font_size", 20)
	_display.add_theme_color_override("font_color", COL_ENTRY)
	_panel.add_child(_display)

	# button grid: 1-9, then CLEAR / 0 / ENTER on the bottom row
	var rows := [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["C", "0", "OK"]]
	for r in rows.size():
		for c in 3:
			var label: String = rows[r][c]
			var btn := _make_button(label, Vector2(16 + c * 50, 76 + r * 42))
			if label == "C":
				btn.pressed.connect(_press_clear)
			elif label == "OK":
				btn.pressed.connect(_press_enter)
			else:
				btn.pressed.connect(_press_digit.bind(int(label)))

	# close X, top-right of the plate
	var x_btn := TextureButton.new()
	x_btn.position = Vector2(144, 6)
	x_btn.texture_normal = _x_tex("normal")
	x_btn.texture_hover = _x_tex("hover")
	x_btn.texture_pressed = _x_tex("pressed")
	x_btn.pressed.connect(_close)
	_panel.add_child(x_btn)

	# child Timers instead of awaits: they die with this node, so a mid-taunt
	# close can never resume a coroutine on a freed overlay.
	_taunt_timer = Timer.new()
	_taunt_timer.one_shot = true
	_taunt_timer.timeout.connect(_end_taunt)
	add_child(_taunt_timer)
	_open_timer = Timer.new()
	_open_timer.one_shot = true
	_open_timer.timeout.connect(_finish_open)
	add_child(_open_timer)

	_refresh_display()
	AudioBus.play_sfx("click", 0.9, -4.0)
	_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)


func _make_button(label: String, pos: Vector2) -> TextureButton:
	var btn := TextureButton.new()
	btn.position = pos
	btn.texture_normal = _btn_tex(label, "normal")
	btn.texture_hover = _btn_tex(label, "hover")
	btn.texture_pressed = _btn_tex(label, "pressed")
	_panel.add_child(btn)
	return btn


# ---------------------------------------------------------------- behavior

func _press_digit(d: int) -> void:
	if _busy:
		return
	if _entry.length() >= MAX_DIGITS:
		AudioBus.play_sfx("tick")  # the keypad is full and unimpressed
		return
	_entry += str(d)
	# each digit beeps a shade higher, like it's getting its hopes up
	AudioBus.play_sfx("keypad_beep", 0.95 + 0.04 * float(d))
	_refresh_display()


func _press_clear() -> void:
	if _busy:
		return
	_entry = ""
	AudioBus.play_sfx("click")
	_refresh_display()


func _backspace() -> void:
	if _busy or _entry.is_empty():
		return
	_entry = _entry.substr(0, _entry.length() - 1)
	AudioBus.play_sfx("tick")
	_refresh_display()


func _press_enter() -> void:
	if _busy:
		return
	if _entry == CODE:
		_busy = true
		_opening = true
		AudioBus.play_sfx("door_unlock")
		# Flag first: even if something interrupts the little OPEN beat, the
		# door stays open. The save system remembers so we don't have to.
		GameState.set_flag("room1_door_open")
		_display.add_theme_color_override("font_color", COL_OPEN)
		_display.text = "O P E N"
		_open_timer.start(0.55)
	else:
		_busy = true
		AudioBus.play_sfx("keypad_laugh")
		_display.add_theme_color_override("font_color", COL_TAUNT)
		_display.text = TAUNTS.pick_random()
		_taunt_timer.start(0.95)


func _end_taunt() -> void:
	_busy = false
	_entry = ""
	_display.add_theme_color_override("font_color", COL_ENTRY)
	_refresh_display()


func _finish_open() -> void:
	# pop first (frees us at frame end), then the line — both synchronous,
	# so nothing here ever awaits on a freed node.
	SceneRouter.pop_overlay()
	DialogueManager.dorko(SUCCESS_LINE)


func _close() -> void:
	if _opening:
		return  # the door is mid-open; let it have its half second
	AudioBus.play_sfx("click", 0.8)
	SceneRouter.pop_overlay()


func _refresh_display() -> void:
	var shown := ""
	for i in MAX_DIGITS:
		shown += _entry[i] if i < _entry.length() else "-"
		if i < MAX_DIGITS - 1:
			shown += " "
	_display.text = shown


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var code: int = event.keycode
	if code == KEY_NONE:
		code = event.physical_keycode
	if code == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		accept_event()
		_close()
	elif code >= KEY_0 and code <= KEY_9:
		accept_event()
		_press_digit(code - KEY_0)
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		accept_event()
		_press_digit(code - KEY_KP_0)
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		accept_event()
		_press_enter()
	elif code == KEY_BACKSPACE:
		accept_event()
		_backspace()


# ---------------------------------------------------------------- textures

func _build_plate_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(88, 124, 2)
	p.rect(1, 1, 86, 122, Color(0.58, 0.58, 0.63))
	p.rect_outline(0, 0, 88, 124, Color(0.12, 0.12, 0.16))
	p.hline(1, 1, 86, Color(0.75, 0.75, 0.8))
	p.vline(1, 1, 122, Color(0.75, 0.75, 0.8))
	p.hline(1, 122, 86, Color(0.35, 0.35, 0.4))
	p.vline(86, 1, 122, Color(0.35, 0.35, 0.4))
	# display recess
	p.rect(7, 13, 74, 20, Color(0.04, 0.09, 0.05))
	p.rect_outline(6, 12, 76, 22, Color(0.02, 0.04, 0.02))
	p.hline(8, 14, 72, Color(0.0, 0.03, 0.0))
	p.hline(8, 18, 72, Color(0.06, 0.12, 0.07))
	p.hline(8, 24, 72, Color(0.06, 0.12, 0.07))
	p.hline(8, 30, 72, Color(0.06, 0.12, 0.07))
	# corner screws
	for s in [Vector2i(3, 3), Vector2i(84, 3), Vector2i(3, 120), Vector2i(84, 120)]:
		p.dot(s.x, s.y, Color(0.3, 0.3, 0.35))
		p.dot(s.x, s.y - 1, Color(0.7, 0.7, 0.75))
	# speaker slots — this is where the laugh comes from
	p.hline(58, 34, 22, Color(0.3, 0.3, 0.34))
	p.hline(58, 36, 22, Color(0.3, 0.3, 0.34))
	# something scratched "HA" next to the speaker, some time ago
	_draw_text(p, "HA", 8, 33, Color(0.46, 0.46, 0.51))
	return p.tex()


func _btn_tex(label: String, state: String) -> Texture2D:
	var key := "keypad_btn_%s_%s" % [label, state]
	return AssetLib.get_or_build(key, func():
		var p: Painter = AssetLib.painter(22, 17, 2)
		var base := Color(0.93, 0.89, 0.76)
		var ink := Color(0.2, 0.16, 0.12)
		if label == "C":
			base = Color(0.85, 0.32, 0.2)
			ink = Color(1.0, 0.93, 0.88)
		elif label == "OK":
			base = Color(0.28, 0.66, 0.34)
			ink = Color(0.95, 1.0, 0.92)
		if state == "hover":
			base = base.lightened(0.12)
		elif state == "pressed":
			base = base.darkened(0.22)
		p.rect(1, 1, 20, 15, base)
		p.rect_outline(0, 0, 22, 17, Color(0.1, 0.1, 0.14))
		if state == "pressed":
			p.hline(1, 1, 20, base.darkened(0.25))
			p.vline(1, 1, 15, base.darkened(0.25))
		else:
			p.hline(1, 1, 20, base.lightened(0.25))
			p.vline(1, 1, 15, base.lightened(0.2))
			p.hline(1, 15, 20, base.darkened(0.3))
			p.vline(20, 1, 15, base.darkened(0.25))
		# glyph drops one pixel when pressed, like it means it
		var ty := 7 if state == "pressed" else 6
		var w := label.length() * 4 - 1
		_draw_text(p, label, int((22 - w) / 2.0), ty, ink)
		return p.tex())


func _x_tex(state: String) -> Texture2D:
	var key := "keypad_x_%s" % state
	return AssetLib.get_or_build(key, func():
		var p: Painter = AssetLib.painter(12, 10, 2)
		var base := Color(0.55, 0.22, 0.2)
		if state == "hover":
			base = base.lightened(0.15)
		elif state == "pressed":
			base = base.darkened(0.2)
		p.rect(1, 1, 10, 8, base)
		p.rect_outline(0, 0, 12, 10, Color(0.1, 0.1, 0.14))
		_draw_text(p, "X", 4, 2, Color(1.0, 0.9, 0.85))
		return p.tex())


func _draw_text(p: Painter, s: String, x: int, y: int, c: Color) -> void:
	# 3x5 glyphs with a 1px gap. Only the characters the keypad needs exist;
	# the keypad does not believe in the rest of the alphabet.
	var cx := x
	for i in s.length():
		var rows: Array = GLYPHS.get(s[i], [])
		for r in rows.size():
			var row: String = rows[r]
			for col in row.length():
				if row[col] == "1":
					p.dot(cx + col, y + r, c)
		cx += 4
