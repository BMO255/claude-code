extends BaseRoom
## The conclusion, part 2 (spec 8): the Orange Room - but the real one.
## Morning light through an actual window. The sun outside has the correct
## number of teeth (zero; it's just a sun). The pizza roll box is unopened.
## The PC is off. There's a birthday card on the desk with today's date.
## Dorko sits where he woke up, and takes the shades off. We never see his
## eyes. The afro stays. It was never the problem.

var _holds_lock := false


func _room_config() -> void:
	room_id = "orange_room_real"
	music_name = "orange"
	footstep_surface = "carpet"
	horizon_y = 195.0
	back_half = 175.0
	front_half = 345.0
	ambient_tint = Color(1.0, 0.98, 0.9)
	spawn_points = {
		"default": {"pos": Vector2(568, 292), "dir": "left"},
	}


func _room_setup() -> void:
	_build_walls()
	add_floor("checker", Color(0.55, 0.38, 0.22), Color(0.48, 0.32, 0.19), 0.9)
	_build_props()


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		GameState.unlock_input()


func _on_room_entered() -> void:
	GameState.lock_input()
	_holds_lock = true
	dorko.control_enabled = false
	await _wait(1.2)
	# pause by the desk for the card
	await _walk(Vector2(210, 280))
	dorko.face_towards(Vector2(150, 220))
	await _wait(0.8)
	var date := Time.get_date_dict_from_system()
	say("A card, on the desk. \"Happy Birthday Dorko - love, everyone.\" Dated %02d/%02d. That's today. Today's real." % [date.month, date.day])
	await DialogueManager.dialogue_finished
	await _wait(0.8)
	# then the carpet. same spot as the opening. same pose, other direction.
	await _walk(Vector2(320, 298))
	dorko.facing = "down"
	dorko._idle_anim()
	await _wait(1.2)
	# sit: swap to the from-behind sitting sprite; the camera stays back here
	dorko.visible = false
	var sitting := add_prop(AssetLib.get_or_build("real_sitting", _build_sitting_tex), Vector2(320, 276))
	sitting.z_index = 300
	await _wait(1.6)
	# the shades come off. they land facing the player. glint. beat.
	AudioBus.play_sfx("clink", 0.7, -8.0)
	sitting.texture = AssetLib.get_or_build("real_sitting_noshades", _build_sitting_tex)  # same silhouette; the change is on the floor
	var shades := add_prop(AssetLib.get_or_build("real_shades", _build_shades_tex), Vector2(320, 318))
	shades.z_index = 320
	shades.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(shades, "modulate:a", 1.0, 0.4)
	await _wait(1.8)
	say("...It was never the problem.")
	await DialogueManager.dialogue_finished
	await _wait(1.4)
	_title_card()


func _title_card() -> void:
	AudioBus.stop_music(2.0)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.size = Vector2(640, 360)
	dim.z_index = 800
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.55, 1.2)
	var letters := "DORKO"
	var lbls: Array = []
	for i in letters.length():
		var lbl := Label.new()
		lbl.text = letters[i]
		lbl.add_theme_font_size_override("font_size", 52)
		lbl.add_theme_color_override("font_color", Color(0.25, 0.8, 0.35))
		lbl.add_theme_color_override("font_shadow_color", Color(0.4, 0.1, 0.3))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		lbl.position = Vector2(196 + i * 52, 130)
		lbl.z_index = 850
		lbl.modulate.a = 0.0
		add_child(lbl)
		lbls.append(lbl)
		var lt := create_tween()
		lt.tween_property(lbl, "modulate:a", 1.0, 0.4).set_delay(0.6 + 0.18 * i)
	AudioBus.play_sfx("chime_boot", 0.8, -6.0)
	await _wait(3.2)
	# hand off to the credits; release our lock once theirs is in place
	var credits = load("res://scripts/ui/credits.gd").new()
	SceneRouter.push_overlay(credits)
	if _holds_lock:
		_holds_lock = false
		GameState.unlock_input()


func _walk(to: Vector2) -> void:
	var done := [false]
	dorko.walk_to(to, func(): done[0] = true)
	while not done[0]:
		await get_tree().process_frame
		if not is_inside_tree():
			return


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ---------------------------------------------------------------- scenery

func _build_walls() -> void:
	var wallc := Node2D.new()
	bg.add_child(wallc)
	add_parallax(wallc, 1.0)
	var wall := Sprite2D.new()
	wall.texture = AssetLib.get_or_build("real_wall", _build_wall_tex)
	wall.centered = false
	wallc.add_child(wall)
	# the real window, where the painted one was: morning, and a toothless sun
	var window := Sprite2D.new()
	window.texture = AssetLib.get_or_build("real_window", _build_window_tex)
	window.position = Vector2(390, 102)
	wallc.add_child(window)
	# sunbeam across the floor
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(340, 140), Vector2(445, 140), Vector2(560, 356), Vector2(260, 356),
	])
	beam.color = Color(1.0, 0.9, 0.6, 0.10)
	beam.z_index = -300
	add_child(beam)
	# the poster wall spot: a clean rectangle where it used to hang
	add_rect(Rect2(212, 58, 78, 102), Color(0.97, 0.6, 0.2), -740)


func _build_props() -> void:
	# desk with the PC off, and the birthday card standing open on it
	add_prop(AssetLib.get_or_build("real_desk", _build_desk_tex), Vector2(150, 175))
	# mini-fridge with the unopened box
	add_prop(AssetLib.get_or_build("real_fridge", _build_fridge_tex), Vector2(468, 186))
	# door we came through, ajar, morning light behind it
	var door := Sprite2D.new()
	door.texture = AssetLib.get_or_build("real_door_open", func():
		var q: Painter = AssetLib.painter(44, 104, 2)
		q.poly(PackedVector2Array([Vector2(0, 24), Vector2(43, 0), Vector2(43, 103), Vector2(0, 69)]), Color(0.05, 0.28, 0.26))
		q.poly(PackedVector2Array([Vector2(3, 26), Vector2(40, 4), Vector2(40, 99), Vector2(3, 66)]), Color(0.14, 0.55, 0.5))
		return q.tex())
	door.centered = false
	door.position = Vector2(548, 116)
	bg.add_child(door)


# ---------------------------------------------------------------- textures

func _build_wall_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 98, 2)
	# same three-panel wall, but lit by morning: everything half a shade kinder
	var sections := [
		[0, 72, Color(0.82, 0.45, 0.2), 0.85],
		[72, 102, Color(0.82, 0.45, 0.2), 1.0],
		[102, 215, Color(0.97, 0.6, 0.2), 1.0],
		[215, 248, Color(0.99, 0.75, 0.52), 1.0],
		[248, 320, Color(0.99, 0.75, 0.52), 0.85],
	]
	for y in 98:
		var row := lerpf(1.06, 0.95, float(y) / 97.0)
		for s in sections:
			var c: Color = s[2]
			var f: float = s[3] * row
			p.hline(s[0], y, s[1] - s[0], Color(minf(1.0, c.r * f), minf(1.0, c.g * f), minf(1.0, c.b * f)))
	p.vline(102, 0, 98, Color(0.55, 0.28, 0.1))
	p.vline(215, 0, 98, Color(0.6, 0.34, 0.14))  # the seam is straight in this one
	p.rect(0, 92, 320, 6, Color(0.42, 0.22, 0.1))
	p.hline(0, 92, 320, Color(0.65, 0.38, 0.18))
	return p.tex()


func _build_window_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(36, 34, 2)
	var frame := Color(0.62, 0.4, 0.2)
	# morning sky, real
	for y in range(3, 27):
		var t := float(y - 3) / 23.0
		p.hline(3, y, 30, Color(0.55, 0.78, 0.95).lerp(Color(0.95, 0.85, 0.6), t))
	# the sun: zero teeth. it's just a sun.
	p.circle(12, 10, 4.5, Color(1.0, 0.92, 0.55))
	p.circle(12, 10, 3, Color(1.0, 0.98, 0.8))
	p.ellipse(24, 8, 5, 2, Color(1, 1, 1, 0.85))
	p.ellipse(20, 14, 4, 1.5, Color(1, 1, 1, 0.7))
	p.ellipse(18, 27, 16, 5, Color(0.5, 0.8, 0.45))
	p.rect(17, 3, 2, 24, frame)
	p.rect(3, 14, 30, 2, frame)
	p.rect(0, 0, 36, 3, frame)
	p.rect(0, 27, 36, 3, frame)
	p.rect(0, 0, 3, 30, frame)
	p.rect(33, 0, 3, 30, frame)
	p.rect_outline(0, 0, 36, 30, Color(0.45, 0.28, 0.12))
	p.hline(2, 30, 32, Color(0.7, 0.48, 0.25))  # a sill, holding actual light
	return p.tex()


func _build_desk_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(75, 48, 2)
	p.rect(4, 30, 3, 17, Color(0.45, 0.26, 0.12))
	p.rect(68, 30, 3, 17, Color(0.45, 0.26, 0.12))
	p.rect(0, 26, 75, 4, Color(0.66, 0.42, 0.22))
	p.hline(0, 26, 75, Color(0.8, 0.54, 0.3))
	# the CRT: off. resting. it earned it.
	p.rect(10, 4, 26, 22, Color(0.88, 0.83, 0.7))
	p.rect_outline(10, 4, 26, 22, Color(0.5, 0.45, 0.36))
	p.rect(13, 7, 18, 14, Color(0.12, 0.13, 0.14))
	p.line(15, 9, 19, 13, Color(0.2, 0.22, 0.24))
	# the birthday card, standing open like a tiny roof
	p.poly(PackedVector2Array([Vector2(46, 26), Vector2(52, 14), Vector2(58, 26)]), Color(0.98, 0.9, 0.6))
	p.line(46, 26, 52, 14, Color(0.85, 0.7, 0.3))
	p.line(52, 14, 58, 26, Color(0.95, 0.85, 0.5))
	p.dot(54, 20, Color(0.9, 0.4, 0.4))
	p.dot(55, 22, Color(0.4, 0.5, 0.9))
	return p.tex()


func _build_fridge_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(34, 46, 2)
	p.rect(2, 4, 30, 40, Color(0.78, 0.94, 0.88))
	p.rect_outline(2, 4, 30, 40, Color(0.35, 0.5, 0.45))
	p.hline(2, 4, 30, Color(0.9, 1.0, 0.96))
	p.hline(3, 20, 28, Color(0.45, 0.6, 0.55))
	p.rect(27, 10, 2, 6, Color(0.5, 0.55, 0.55))
	# the pizza roll box on top: unopened. sealed. full of potential.
	p.rect(6, 0, 18, 7, Color(0.87, 0.2, 0.16))
	p.rect_outline(6, 0, 18, 7, Color(0.5, 0.08, 0.06))
	p.hline(7, 2, 16, Color(0.97, 0.82, 0.25))
	p.hline(6, 0, 18, Color(1.0, 0.5, 0.4))
	return p.tex()


func _build_sitting_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 26, 2)
	# Dorko from behind, sitting on the carpet: afro, shell, small and still
	p.circle(15, 8, 9, Color(0.06, 0.24, 0.08))
	p.circle(15, 8, 8, Color(0.16, 0.5, 0.2))
	p.circle(9, 10, 4, Color(0.16, 0.5, 0.2))
	p.circle(21, 10, 4, Color(0.16, 0.5, 0.2))
	p.ellipse(15, 19, 8, 6, Color(0.55, 0.28, 0.04))
	p.ellipse(15, 18, 7, 5, Color(0.95, 0.55, 0.12))
	p.ellipse_outline(15, 18, 7, 5, Color(0.99, 0.9, 0.72))
	p.ellipse(8, 23, 3, 2, Color(0.96, 0.82, 0.3))   # folded legs peeking out
	p.ellipse(22, 23, 3, 2, Color(0.96, 0.82, 0.3))
	return p.tex()


func _build_shades_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(18, 10, 2)
	# the visor on the carpet, facing the player. glinting once, gently.
	p.poly(PackedVector2Array([Vector2(1, 2), Vector2(16, 2), Vector2(9, 8)]), Color(1.0, 0.55, 0.1))
	p.line(1, 2, 16, 2, Color(0.62, 0.26, 0.0))
	p.line(1, 2, 9, 8, Color(0.62, 0.26, 0.0))
	p.line(16, 2, 9, 8, Color(0.62, 0.26, 0.0))
	p.dot(5, 3, Color(1.0, 0.9, 0.6))
	p.dot(6, 3, Color(1.0, 0.95, 0.8))
	return p.tex()
