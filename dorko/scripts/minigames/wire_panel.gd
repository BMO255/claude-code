extends Control
## Blue Bomb's chest panel (spec 7.4, step 3). Five wires; the VHS shelf's
## labels give the order: RED first, then "the one that isn't there" (there is
## no orange wire — you skip straight on), YELLOW, BLUE last. GREEN is a
## decoy: cutting it triggers a five-second fake countdown that ends in a
## party horn. Any other wrong cut gets a sad bwomp and a reset.
##
## The room sets `on_success` before pushing the overlay.

const COLORS := ["red", "green", "yellow", "blue", "purple"]
const ORDER := ["red", "yellow", "blue"]
const WIRE_COLS := {
	"red": Color(0.9, 0.2, 0.15),
	"green": Color(0.25, 0.75, 0.3),
	"yellow": Color(0.95, 0.85, 0.2),
	"blue": Color(0.25, 0.45, 0.95),
	"purple": Color(0.6, 0.3, 0.85),
}

var on_success := Callable()

var _cut: Array = []        # correct cuts so far, in order
var _snipped: Dictionary = {}  # color -> bool (visual state)
var _busy := false
var _wires: Dictionary = {}
var _status: Label
var _count_lbl: Label


## Pure rule check (unit-tested headlessly): given the correct cuts so far,
## what does cutting `color` do? -> "ok" | "done" | "green_trick" | "wrong"
static func judge(cut_so_far: Array, color: String) -> String:
	if color == "green":
		return "green_trick"
	var idx := cut_so_far.size()
	if idx < ORDER.size() and color == ORDER[idx]:
		return "done" if idx == ORDER.size() - 1 else "ok"
	return "wrong"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var chest := TextureRect.new()
	chest.texture = AssetLib.get_or_build("wire_chest", _build_chest_tex)
	chest.position = Vector2(176, 42)
	chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chest)
	for i in COLORS.size():
		var color: String = COLORS[i]
		var btn := TextureButton.new()
		btn.position = Vector2(216 + i * 44, 108)
		btn.texture_normal = _wire_tex(color, false)
		btn.texture_hover = _wire_tex(color, false, true)
		btn.pressed.connect(_cut_wire.bind(color))
		add_child(btn)
		_wires[color] = btn
	_status = Label.new()
	_status.position = Vector2(0, 268)
	_status.size = Vector2(640, 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_status.text = "( he is thinking about the ocean )"
	add_child(_status)
	_count_lbl = Label.new()
	_count_lbl.position = Vector2(0, 140)
	_count_lbl.size = Vector2(640, 80)
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_size_override("font_size", 56)
	_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_count_lbl.visible = false
	add_child(_count_lbl)
	var hint := Label.new()
	hint.text = "( Esc to step back )"
	hint.position = Vector2(0, 336)
	hint.size = Vector2(640, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	add_child(hint)
	AudioBus.play_sfx("click", 0.85)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _busy:
		accept_event()
		SceneRouter.pop_overlay()


func _cut_wire(color: String) -> void:
	if _busy or _snipped.get(color, false):
		return
	match judge(_cut, color):
		"ok":
			_do_snip(color)
			_status.text = "( something inside him relaxed )"
		"done":
			_do_snip(color)
			_finish()
		"green_trick":
			_do_snip(color)
			_green_countdown()
		"wrong":
			_do_snip(color)
			_fail_reset()


func _do_snip(color: String) -> void:
	AudioBus.play_sfx("thwip", randf_range(0.95, 1.1))
	_snipped[color] = true
	_wires[color].texture_normal = _wire_tex(color, true)
	_wires[color].texture_hover = _wire_tex(color, true)
	if judge(_cut, color) in ["ok", "done"]:
		_cut.append(color)


func _green_countdown() -> void:
	# The decoy. Five seconds of pure theater.
	_busy = true
	_count_lbl.visible = true
	for n in [5, 4, 3, 2, 1]:
		_count_lbl.text = str(n)
		_count_lbl.scale = Vector2(1.3, 1.3)
		var tw := create_tween()
		tw.tween_property(_count_lbl, "scale", Vector2.ONE, 0.2)
		AudioBus.play_sfx("heartbeat", 1.0, -2.0)
		Fx.shake(0.15, 2.0 + (5 - n))
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
	_count_lbl.text = "!!"
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return
	AudioBus.play_sfx("party_horn")
	_confetti()
	_count_lbl.text = ""
	_count_lbl.visible = false
	_status.text = "( the green wire was a joke. his joke. he's been waiting thirty years )"
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return
	_reset_wires()
	_busy = false


func _fail_reset() -> void:
	_busy = true
	AudioBus.play_sfx("bwomp")
	_status.text = "( bwomp. the panel un-decides your choices )"
	Fx.shake(0.2, 3.0)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_reset_wires()
	_busy = false


func _reset_wires() -> void:
	_cut = []
	_snipped = {}
	for color in _wires:
		_wires[color].texture_normal = _wire_tex(color, false)
		_wires[color].texture_hover = _wire_tex(color, false, true)


func _finish() -> void:
	_busy = true
	AudioBus.play_sfx("puff")
	_status.text = "( the fuse lets go of the idea )"
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree():
		return
	SceneRouter.pop_overlay()
	if on_success.is_valid():
		on_success.call()


func _confetti() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	for i in 26:
		var bit := ColorRect.new()
		bit.color = Color.from_hsv(rng.randf(), 0.8, 1.0)
		bit.size = Vector2(4, 4)
		bit.position = Vector2(rng.randf_range(240, 400), rng.randf_range(80, 140))
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bit)
		var tw := bit.create_tween()
		tw.set_parallel(true)
		tw.tween_property(bit, "position:y", bit.position.y + rng.randf_range(80, 160), rng.randf_range(0.8, 1.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(bit, "position:x", bit.position.x + rng.randf_range(-40, 40), 1.2)
		tw.tween_property(bit, "modulate:a", 0.0, 1.3)
		tw.chain().tween_callback(bit.queue_free)


# ---------------------------------------------------------------- textures

func _build_chest_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(144, 92, 2)
	var navy := Color(0.14, 0.19, 0.42)
	var navy_dk := Color(0.08, 0.11, 0.28)
	# a very close view of a very round chest
	p.ellipse(72, 46, 70, 44, navy_dk)
	p.ellipse(72, 45, 67, 41, navy)
	p.ellipse(46, 26, 16, 9, Color(0.24, 0.32, 0.6, 0.7))
	# the open panel: hinged plate + dark cavity where the wires live
	p.rect(16, 24, 112, 44, Color(0.05, 0.06, 0.16))
	p.rect_outline(16, 24, 112, 44, Color(0.5, 0.55, 0.7))
	p.rect_outline(15, 23, 114, 46, navy_dk)
	p.poly(PackedVector2Array([
		Vector2(16, 24), Vector2(128, 24), Vector2(120, 10), Vector2(24, 10),
	]), Color(0.18, 0.24, 0.5))
	p.hline(24, 10, 96, Color(0.3, 0.38, 0.66))
	p.dot(20, 26, Color(0.7, 0.75, 0.85))
	p.dot(124, 26, Color(0.7, 0.75, 0.85))
	# a tiny maintenance sticker, long expired
	p.rect(100, 70, 22, 10, Color(0.85, 0.82, 0.7))
	p.hline(102, 73, 18, Color(0.4, 0.4, 0.45))
	p.hline(102, 76, 12, Color(0.4, 0.4, 0.45))
	return p.tex()


func _wire_tex(color: String, cut: bool, hover := false) -> Texture2D:
	var key := "wire_%s_%s%s" % [color, "cut" if cut else "whole", "_h" if hover else ""]
	return AssetLib.get_or_build(key, func():
		var p: Painter = AssetLib.painter(16, 40, 2)
		var c: Color = WIRE_COLS[color]
		if hover:
			c = c.lightened(0.25)
		# connector lugs top and bottom
		p.rect(5, 0, 6, 4, Color(0.6, 0.62, 0.7))
		p.rect(5, 36, 6, 4, Color(0.6, 0.62, 0.7))
		if cut:
			# two frayed halves, honest about what happened
			p.line(8, 4, 7, 14, c)
			p.line(7, 14, 9, 17, c)
			p.dot(8, 18, c.darkened(0.2))
			p.dot(7, 19, Color(0.9, 0.9, 0.95))
			p.line(8, 36, 9, 26, c)
			p.line(9, 26, 7, 23, c)
			p.dot(8, 22, Color(0.9, 0.9, 0.95))
		else:
			# a lazy S-curve; wires in fiction are never straight
			p.line(8, 4, 6, 12, c)
			p.line(6, 12, 10, 22, c)
			p.line(10, 22, 7, 30, c)
			p.line(7, 30, 8, 36, c)
			p.line(9, 4, 7, 12, c.darkened(0.25))
		return p.tex())
