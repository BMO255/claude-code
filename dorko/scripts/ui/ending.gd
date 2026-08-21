extends Node2D
## The conclusion, part 1 (spec 8): the Turquoise Room's chair is gone, a door
## stands open where it was, and stairs go up. Dorko climbs — WASD disabled,
## this scene walks for him — passing three vignette windows: the Blue Bomb
## waving from a real blue window, the Couch Guy standing and laughing with a
## sandwich, and the PC playing voicemail_4.wav. At the top: the keypad door,
## minus the keypad. He opens it.

var _dorko_sprite: AnimatedSprite2D
var _vignette: Control
var _holds_lock := false


func _ready() -> void:
	GameState.lock_input()
	_holds_lock = true
	AudioBus.play_music("orange", 2.0)
	_build_scene()
	_run()


func _exit_tree() -> void:
	# if the scene dies mid-sequence, never leak the global input lock
	if _holds_lock:
		_holds_lock = false
		GameState.unlock_input()


func _build_scene() -> void:
	# warm dark stairwell
	var bgr := Polygon2D.new()
	bgr.polygon = PackedVector2Array([Vector2(0, 0), Vector2(640, 0), Vector2(640, 360), Vector2(0, 360)])
	bgr.color = Color(0.12, 0.07, 0.05)
	bgr.z_index = -900
	add_child(bgr)
	# orange light spilling from the top of the stairs
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(430, 0), Vector2(640, 0), Vector2(640, 200), Vector2(520, 130)])
	glow.color = Color(0.9, 0.5, 0.15, 0.2)
	glow.z_index = -850
	add_child(glow)
	# the staircase: broad steps rising left-to-right
	var steps := Sprite2D.new()
	steps.texture = AssetLib.get_or_build("ending_stairs", _build_stairs_tex)
	steps.centered = false
	steps.position = Vector2(0, 60)
	steps.z_index = -800
	add_child(steps)
	# the door at the top: same teal door, and no keypad. nothing to prove.
	var door := Sprite2D.new()
	door.texture = AssetLib.get_or_build("ending_door", _build_door_tex)
	door.position = Vector2(566, 74)
	door.z_index = -700
	add_child(door)
	# Dorko, climbing
	_dorko_sprite = AnimatedSprite2D.new()
	_dorko_sprite.sprite_frames = DorkoSprites.build()
	_dorko_sprite.position = Vector2(40, 330)
	_dorko_sprite.z_index = 100
	add_child(_dorko_sprite)
	_vignette = Control.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.z_index = 500
	add_child(_vignette)


func _run() -> void:
	await _wait(1.0)
	_dorko_sprite.play("walk_right")
	# three legs of the climb, one vignette per landing
	await _climb_to(Vector2(200, 262), 3.2)
	await _show_vignette("bomb")
	await _climb_to(Vector2(360, 194), 3.2)
	await _show_vignette("couch")
	await _climb_to(Vector2(500, 128), 3.0)
	await _show_vignette("pc")
	await _climb_to(Vector2(556, 104), 1.4)
	if not is_inside_tree():
		return
	_dorko_sprite.play("idle_up")
	await _wait(1.2)
	AudioBus.play_sfx("door_open")
	await _wait(0.9)
	if _holds_lock:
		_holds_lock = false
		GameState.unlock_input()
	SceneRouter.goto_room("orange_room_real")


func _climb_to(target: Vector2, dur: float) -> void:
	if not is_inside_tree():
		return
	_dorko_sprite.play("walk_right")
	var tw := create_tween()
	tw.tween_property(_dorko_sprite, "position", target, dur)
	# footsteps on the climb
	var steps_n := int(dur / 0.42)
	for i in steps_n:
		await _wait(0.42)
		if not is_inside_tree():
			return
		AudioBus.footstep("concrete")
	await tw.finished


func _show_vignette(which: String) -> void:
	if not is_inside_tree():
		return
	_dorko_sprite.play("idle_up")
	var panel := TextureRect.new()
	panel.texture = AssetLib.get_or_build("ending_vig_" + which, func(): return _build_vignette_tex(which))
	panel.position = Vector2(660, 40)
	panel.z_index = 600
	_vignette.add_child(panel)
	var tw := create_tween()
	tw.tween_property(panel, "position:x", 396.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	match which:
		"bomb":
			AudioBus.blip(1.45)
			_caption(panel, "( he waves with his whole body )")
		"couch":
			AudioBus.blip(0.5)
			_caption(panel, "\"Ha. Haha.\"  — warm, this time")
		"pc":
			AudioBus.play_sfx("blip", 1.2, -10.0)
			await _type_caption(panel, "voicemail_4.wav:  \"You did it. Come home.\"")
	await _wait(2.6)
	if not is_inside_tree():
		return
	var out := create_tween()
	out.tween_property(panel, "position:x", 660.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_callback(panel.queue_free)
	await out.finished


func _caption(panel: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2(-40, 132)
	lbl.size = Vector2(300, 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(lbl)


func _type_caption(panel: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.visible_characters = 0
	lbl.position = Vector2(-70, 132)
	lbl.size = Vector2(360, 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(lbl)
	for i in text.length():
		lbl.visible_characters = i + 1
		if i % 3 == 0:
			AudioBus.blip(1.2, -14.0)
		await _wait(0.04)
		if not is_inside_tree():
			return


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ---------------------------------------------------------------- textures

func _build_stairs_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 150, 2)
	var step_top := Color(0.5, 0.32, 0.2)
	var step_face := Color(0.35, 0.2, 0.12)
	# a broad diagonal staircase; each step is a quad climbing rightward
	for i in 9:
		var x := 8 + i * 34
		var y := 132 - i * 15
		p.poly(PackedVector2Array([
			Vector2(x, y), Vector2(x + 46, y), Vector2(x + 46, y + 5), Vector2(x, y + 5),
		]), step_top)
		p.poly(PackedVector2Array([
			Vector2(x + 12, y + 5), Vector2(x + 46, y + 5), Vector2(x + 46, y + 15), Vector2(x + 12, y + 15),
		]), step_face)
		p.hline(x, y, 46, Color(0.65, 0.44, 0.28))
	# banister line
	p.line(4, 118, 300, -12, Color(0.55, 0.35, 0.2))
	p.line(4, 117, 300, -13, Color(0.3, 0.18, 0.1))
	return p.tex()


func _build_door_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(40, 62, 2)
	p.rect(2, 2, 36, 58, Color(0.05, 0.28, 0.26))
	p.rect(5, 5, 30, 52, Color(0.14, 0.55, 0.5))
	p.rect_outline(5, 5, 30, 52, Color(0.2, 0.68, 0.62))
	p.rect_outline(9, 10, 22, 18, Color(0.1, 0.46, 0.42))
	p.rect_outline(9, 33, 22, 18, Color(0.1, 0.46, 0.42))
	p.circle(8, 31, 1.8, Color(0.95, 0.78, 0.3))
	# where the keypad used to be: four clean screw holes and nothing else
	p.dot(24, 24, Color(0.08, 0.4, 0.36))
	p.dot(30, 24, Color(0.08, 0.4, 0.36))
	p.dot(24, 30, Color(0.08, 0.4, 0.36))
	p.dot(30, 30, Color(0.08, 0.4, 0.36))
	# warm light leaking around the frame
	p.vline(1, 4, 56, Color(1.0, 0.7, 0.3, 0.5))
	p.hline(2, 1, 36, Color(1.0, 0.7, 0.3, 0.5))
	return p.tex()


func _build_vignette_tex(which: String) -> Texture2D:
	var p: Painter = AssetLib.painter(110, 66, 2)
	# shared frame
	p.rect(0, 0, 110, 66, Color(0.35, 0.22, 0.12))
	p.rect(3, 3, 104, 60, Color(0.1, 0.08, 0.1))
	match which:
		"bomb":
			# a REAL window, painted blue, with the Blue Bomb waving through it
			p.rect(6, 6, 98, 54, Color(0.35, 0.55, 0.85))
			p.rect(10, 10, 90, 46, Color(0.55, 0.75, 0.95))
			p.rect(52, 10, 3, 46, Color(0.35, 0.55, 0.85))
			p.rect(10, 31, 90, 3, Color(0.35, 0.55, 0.85))
			p.circle(30, 40, 11, Color(0.14, 0.19, 0.42))
			p.circle(26, 37, 3, Color.WHITE)
			p.circle(34, 37, 3, Color.WHITE)
			p.hline(25, 38, 3, Color(0.1, 0.1, 0.15))
			p.hline(33, 38, 3, Color(0.1, 0.1, 0.15))
			p.hline(27, 44, 6, Color(0.06, 0.08, 0.22))
			p.line(40, 34, 46, 26, Color(0.14, 0.19, 0.42))  # the waving arm
			p.circle(47, 25, 2.5, Color(0.14, 0.19, 0.42))
			p.dot(30, 28, Color(1, 1, 0.8))  # no fuse spark. just sky.
		"couch":
			# Couch Guy STANDING. TV off. Sandwich in hand. Laughing.
			p.rect(6, 6, 98, 54, Color(0.6, 0.48, 0.14))
			p.rect(10, 40, 40, 16, Color(0.4, 0.27, 0.16))  # the couch, vacant
			p.ellipse(30, 44, 14, 5, Color(0.3, 0.19, 0.1))
			p.rect(66, 26, 20, 16, Color(0.25, 0.2, 0.16))  # tv stand, screen dark
			p.rect(68, 28, 16, 10, Color(0.04, 0.04, 0.05))
			p.circle(52, 26, 7, Color(0.9, 0.75, 0.6))       # him! vertical!
			p.ellipse(52, 22, 8, 4, Color(0.58, 0.58, 0.62))
			p.ellipse(52, 40, 10, 9, Color(0.72, 0.5, 0.35))
			p.rect(48, 49, 3, 8, Color(0.55, 0.36, 0.24))
			p.rect(54, 49, 3, 8, Color(0.55, 0.36, 0.24))
			p.hline(50, 27, 4, Color(0.4, 0.25, 0.15))       # open laughing mouth
			p.dot(50, 26, Color(0.2, 0.12, 0.08))
			p.rect(60, 36, 7, 3, Color(0.94, 0.85, 0.65))    # the sandwich
			p.hline(60, 37, 7, Color(0.92, 0.6, 0.65))
		"pc":
			# the orange room PC, screen on, playing its last voicemail
			p.rect(6, 6, 98, 54, Color(0.5, 0.25, 0.1))
			p.rect(30, 16, 50, 36, Color(0.86, 0.81, 0.68))
			p.rect(36, 21, 38, 24, Color(0.05, 0.1, 0.08))
			p.hline(38, 26, 34, Color(0.3, 0.9, 0.4))
			p.hline(38, 32, 22, Color(0.3, 0.9, 0.4))
			p.hline(38, 38, 28, Color(0.2, 0.6, 0.3))
			p.dot(76, 48, Color(0.3, 0.9, 0.4))
			# little speaker waves
			p.ellipse_outline(20, 34, 5, 8, Color(0.9, 0.8, 0.5, 0.5))
			p.ellipse_outline(20, 34, 9, 13, Color(0.9, 0.8, 0.5, 0.3))
	p.rect_outline(0, 0, 110, 66, Color(0.6, 0.4, 0.2))
	return p.tex()
