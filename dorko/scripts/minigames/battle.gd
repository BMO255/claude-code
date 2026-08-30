extends Node2D
## The Punch-Out-style battle (spec 7.5). Camera behind Dorko (shell + afro,
## body translucent so the opponent reads through him). The Turquoise One
## telegraphs an enormous attack with a full three-second wind-up.
## It dies in one hit. Any hit. That is the fight.
##
## Controls: A/D dodge, W block (both entirely cosmetic - the joke),
## LMB/RMB jabs (either ends it), Space = star uppercut (permanently
## unavailable; you've never had any stars).

enum State { INTRO, FIGHT, KO, COUNT, DONE }

const DORKO_HOME := Vector2(320.0, 296.0)
const OPP_HOME := Vector2(320.0, 236.0)
const NO_ATTACK_MS := 30000

var state: int = State.INTRO
var _fight_start := 0
var _rng := RandomNumberGenerator.new()

var _opp: Node2D
var _opp_sprite: Sprite2D
var _dorko_back: Sprite2D
var _jab_fist: Sprite2D
var _dim: ColorRect
var _crowd: Crowd
var _crowd_player: AudioStreamPlayer = null
var _corner_towel: Sprite2D
var _count_lbl: Label
var _big_lbl: Label
var _tooltip: Label
var _hud: CanvasLayer
var _swell_stream: AudioStreamWAV  # pre-baked wind-up riser (no mid-fight synth hitch)
var _windup_tween: Tween = null


func _ready() -> void:
	_rng.seed = 600
	_swell_stream = SfxSynth.to_wav(SfxSynth.sweep(90.0, 240.0, 3.0, "tri", 0.14, 0.1, 0.3))
	# prebuild every pose so the PNG bake captures them (incl. the 30s-path punch)
	for pose_name in ["idle", "windup", "punch", "smile_off"]:
		_opp_tex(pose_name)
	_dorko_tex("guard_down")
	_dorko_tex("guard_up")
	AudioBus.play_music("battle")
	_build_arena()
	_build_actors()
	_build_hud()
	_crowd_player = AudioBus.play_sfx("crowd_loop", 1.0, -14.0)
	_intro()


func _exit_tree() -> void:
	_stop_crowd()


func _stop_crowd() -> void:
	if _crowd_player and is_instance_valid(_crowd_player):
		_crowd_player.stop()
	_crowd_player = null


func _intro() -> void:
	AudioBus.play_sfx("ding")
	_show_big("FIGHT", Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_big_lbl.visible = false
	state = State.FIGHT
	_fight_start = Time.get_ticks_msec()
	_behavior_loop()


# ============================================================== opponent brain

func _behavior_loop() -> void:
	# Sway, wind up enormously, think better of it, repeat. He is saving the
	# real punch for the 30-second mark, out of politeness.
	while state == State.FIGHT:
		await _wait(_rng.randf_range(1.6, 2.8))
		if state != State.FIGHT:
			return
		await _windup(3.0)
		if state != State.FIGHT:
			return
		# ...and he lets it go. This wasn't the one. He'll know the one.
		_undim()
		_opp_sprite.texture = _opp_tex("idle")
		UILayer.float_text(_opp.global_position + Vector2(20, -140), "hm.", Color(0.7, 1.0, 0.95))
		await _wait(0.4)


## The full dramatic wind-up: lights dim, music swells, arm cranks back.
func _windup(dur: float) -> void:
	_opp_sprite.texture = _opp_tex("windup")
	AudioBus.play_sfx("swoosh", 0.5, -6.0)
	var tw := create_tween()
	_windup_tween = tw  # killed by _undim so a mid-wind-up KO can't re-dim
	tw.set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.38, dur * 0.8)
	tw.tween_property(_opp, "scale", Vector2(1.06, 1.06), dur)
	# a rising tone under it, because the moment demands one
	AudioBus.play_stream(_swell_stream, 3.0 / max(0.5, dur), -8.0)
	await _wait(dur)


func _undim() -> void:
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	_windup_tween = null
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.0, 0.4)
	tw.tween_property(_opp, "scale", Vector2.ONE, 0.4)


func _process(_delta: float) -> void:
	if state == State.FIGHT:
		# cosmetic defense: sway with A/D, guard with W. None of it matters.
		var off := 0.0
		if Input.is_action_pressed("move_left"):
			off = -44.0
		elif Input.is_action_pressed("move_right"):
			off = 44.0
		_dorko_back.position.x = lerpf(_dorko_back.position.x, DORKO_HOME.x + off, 0.2)
		var blocking := Input.is_action_pressed("move_up")
		_dorko_back.texture = _dorko_tex("guard_up" if blocking else "guard_down")
		# the 30-second mercy rule
		if Time.get_ticks_msec() - _fight_start > NO_ATTACK_MS:
			_cant_sequence()
	# idle sway for the opponent
	if state == State.FIGHT or state == State.INTRO:
		_opp.position.x = OPP_HOME.x + sin(Time.get_ticks_msec() / 700.0) * 6.0


func _unhandled_input(event: InputEvent) -> void:
	if state != State.FIGHT:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_jab(-1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# consumed here so the verb cursor doesn't cycle mid-fight
			get_viewport().set_input_as_handled()
			_jab(1)
	elif event.is_action_pressed("battle_uppercut"):
		get_viewport().set_input_as_handled()
		_star_tooltip()


func _star_tooltip() -> void:
	_tooltip.text = "You don't have any stars. You've never had any stars."
	_tooltip.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_tooltip, "modulate:a", 0.0, 0.5)


# ============================================================== the one hit

func _jab(side: int) -> void:
	if state != State.FIGHT:
		return
	state = State.KO
	# the fist crosses the frame
	_jab_fist.visible = true
	_jab_fist.position = DORKO_HOME + Vector2(56.0 * side, -30.0)
	_jab_fist.scale = Vector2.ONE * (1.0 if side > 0 else -1.0)
	_jab_fist.scale.y = 1.0
	var tw := create_tween()
	tw.tween_property(_jab_fist, "position", OPP_HOME + Vector2(10.0 * side, -46.0), 0.09)
	await tw.finished
	if not is_inside_tree():
		return
	AudioBus.play_sfx("punch")
	_ko_sequence()


func _ko_sequence() -> void:
	# Time freeze + zoom + one modest "thwip".
	_undim()
	AudioBus.stop_music(0.3)
	AudioBus.play_sfx("thwip")
	var focus := OPP_HOME + Vector2(0, -50)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.18)
	tw.tween_property(self, "position", focus * (1.0 - 1.35), 0.18)
	await _wait(0.55)
	_jab_fist.visible = false
	# the smile flickers. twice. like a sign in a diner window.
	for i in 2:
		_opp_sprite.texture = _opp_tex("smile_off")
		await _wait(0.12)
		_opp_sprite.texture = _opp_tex("idle")
		await _wait(0.12)
	UILayer.bubble(_opp, "...oh.", 1.02, 1.6)
	await _wait(1.4)
	# un-zoom, then the plank falls
	var tz := create_tween()
	tz.set_parallel(true)
	tz.tween_property(self, "scale", Vector2.ONE, 0.25)
	tz.tween_property(self, "position", Vector2.ZERO, 0.25)
	await _wait(0.35)
	await _plank_fall()
	_count_sequence()


func _cant_sequence() -> void:
	if state != State.FIGHT:
		return
	state = State.KO
	# The real one. Finally. Lights all the way down.
	await _windup(1.6)
	if not is_inside_tree():
		return
	_opp_sprite.texture = _opp_tex("punch")
	AudioBus.play_sfx("swoosh", 1.4)
	var tw := create_tween()
	tw.tween_property(_opp, "position", DORKO_HOME + Vector2(0, -66), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_inside_tree():
		return
	# ...and it stops. An inch from the visor. The room holds its breath.
	AudioBus.stop_music(0.4)
	await _wait(2.0)
	_undim()
	UILayer.bubble(_opp, "I can't.", 1.02, 1.8)
	await _wait(1.9)
	var back := create_tween()
	back.tween_property(_opp, "position", OPP_HOME, 0.5)
	await back.finished
	if not is_inside_tree():
		return
	_opp_sprite.texture = _opp_tex("idle")
	await _wait(0.4)
	await _plank_fall()
	_count_sequence()


func _plank_fall() -> void:
	# Straight backwards, like a plank. No knees involved. Knees are for people
	# with doubts.
	AudioBus.play_sfx("swoosh", 0.8, -6.0)
	var tw := create_tween()
	tw.tween_property(_opp, "rotation", -PI / 2.0, 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_opp, "position:y", OPP_HOME.y + 8.0, 0.62)
	await tw.finished
	if not is_inside_tree():
		return
	AudioBus.play_sfx("thud_concrete_1", 0.7, 2.0)
	AudioBus.play_sfx("poof", 1.0, -6.0)
	Fx.shake(0.3, 5.0)
	await _wait(0.5)


# ============================================================== the count

func _count_sequence() -> void:
	state = State.COUNT
	var glove := Sprite2D.new()
	glove.texture = AssetLib.get_or_build("battle_ref_glove", _build_glove_tex)
	glove.position = Vector2(430, 170)
	glove.z_index = 650
	add_child(glove)
	var bob := create_tween().set_loops()
	bob.tween_property(glove, "position:y", 162.0, 0.5).set_trans(Tween.TRANS_SINE)
	bob.tween_property(glove, "position:y", 170.0, 0.5).set_trans(Tween.TRANS_SINE)
	_count_lbl.visible = true
	# 1..10, brisk and official
	for n in range(1, 11):
		_count_lbl.text = str(n)
		_count_lbl.scale = Vector2(1.25, 1.25)
		var tw := create_tween()
		tw.tween_property(_count_lbl, "scale", Vector2.ONE, 0.12)
		AudioBus.blip(1.3, -4.0)
		await _wait(0.34)
		if not is_inside_tree():
			return
	# ...11. 12. 13. The crowd noise cuts out. The glove is committed now.
	_stop_crowd()
	_crowd.frozen = true
	var n := 10
	var step := 1
	while n < 600:
		n = mini(600, n + step)
		_count_lbl.text = str(n)
		# ghost trails so the blur reads as speed, not a broken label
		if step > 2 and n % 7 == 0:
			var ghost := _count_lbl.duplicate()
			ghost.modulate.a = 0.35
			ghost.scale = Vector2.ONE * _rng.randf_range(0.9, 1.15)
			add_child(ghost)
			var gt := create_tween()
			gt.tween_property(ghost, "modulate:a", 0.0, 0.3)
			gt.tween_callback(ghost.queue_free)
		if n % 3 == 0:
			AudioBus.blip(1.5 + float(n) / 600.0, -14.0)
		step = mini(19, step + (1 if n > 20 else 0))
		await get_tree().process_frame
		if not is_inside_tree():
			return
	_count_lbl.text = "600"
	await _wait(0.5)
	AudioBus.play_sfx("ding")
	bob.kill()
	await _wait(0.8)
	_count_lbl.visible = false
	_winner_sequence()


func _winner_sequence() -> void:
	state = State.DONE
	_show_big("WINER", Color(1.0, 0.9, 0.2))
	await _wait(1.4)
	if not is_inside_tree():
		return
	# it corrects itself. quietly. hoping nobody saw.
	AudioBus.play_sfx("tick", 0.8)
	_show_big("WINNER", Color(1.0, 0.9, 0.2))
	await _wait(1.6)
	# Point the save at the conclusion room BEFORE saving: goto_scene never
	# updates current_room, so without this a post-win save would Continue
	# into the exit-less turquoise room and soft-lock the run.
	GameState.current_room = "orange_room_real"
	GameState.current_spawn = "default"
	GameState.set_flag("battle_won")
	GameState.save_game()
	if ResourceLoader.exists("res://scenes/ui/ending.tscn"):
		SceneRouter.goto_scene("res://scenes/ui/ending.tscn")
	else:
		push_warning("battle: ending scene not built yet")
		SceneRouter.goto_main_menu()


func _show_big(text: String, color: Color) -> void:
	_big_lbl.text = text
	_big_lbl.visible = true
	_big_lbl.add_theme_color_override("font_color", color)
	_big_lbl.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(_big_lbl, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ============================================================== construction

func _build_arena() -> void:
	# hall darkness, ring floor, ropes, crowd
	var bgr := Polygon2D.new()
	bgr.polygon = PackedVector2Array([Vector2(0, 0), Vector2(640, 0), Vector2(640, 360), Vector2(0, 360)])
	bgr.color = Color(0.06, 0.05, 0.1)
	bgr.z_index = -900
	add_child(bgr)
	_crowd = Crowd.new()
	_crowd.z_index = -850
	add_child(_crowd)
	# ring floor: perspective-lit canvas
	var mat := Sprite2D.new()
	mat.texture = AssetLib.floor_tex("battle_ring", {
		"w": 640, "h": 200, "back_half": 260.0, "front_half": 420.0,
		"pattern": "stripes_x", "col_a": Color(0.75, 0.72, 0.85), "col_b": Color(0.68, 0.64, 0.78),
		"cell": 2.2, "shade_back": 0.35,
	})
	mat.centered = false
	mat.position = Vector2(0, 160)
	mat.z_index = -800
	add_child(mat)
	# ropes: three strands with corner posts
	for i in 3:
		var y := 150.0 - i * 22.0
		var rope := Polygon2D.new()
		rope.polygon = PackedVector2Array([
			Vector2(30, y), Vector2(610, y), Vector2(610, y + 3), Vector2(30, y + 3),
		])
		rope.color = [Color(0.9, 0.25, 0.3), Color(0.95, 0.95, 0.95), Color(0.25, 0.4, 0.9)][i]
		rope.z_index = -700
		add_child(rope)
	for x in [30.0, 610.0]:
		var post := Polygon2D.new()
		post.polygon = PackedVector2Array([
			Vector2(x - 5, 90), Vector2(x + 5, 90), Vector2(x + 5, 165), Vector2(x - 5, 165),
		])
		post.color = Color(0.35, 0.35, 0.42)
		post.z_index = -690
		add_child(post)
	# corner-man: a familiar silhouette with a towel and no advice
	var corner := Sprite2D.new()
	corner.texture = AssetLib.get_or_build("battle_corner", _build_corner_tex)
	corner.position = Vector2(52, 320)
	corner.z_index = 500
	add_child(corner)
	_corner_towel = corner
	var towel_timer := Timer.new()
	towel_timer.wait_time = 6.0
	towel_timer.timeout.connect(func():
		var tw := create_tween()
		tw.tween_property(_corner_towel, "rotation", -0.12, 0.4)
		tw.tween_property(_corner_towel, "rotation", 0.0, 0.6))
	add_child(towel_timer)
	towel_timer.start()
	# dim layer for the wind-up (under HUD, over actors)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0.02, 0.0)
	_dim.size = Vector2(640, 360)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.z_index = 600
	add_child(_dim)


func _build_actors() -> void:
	_opp = Node2D.new()
	_opp.position = OPP_HOME
	_opp.z_index = 100
	add_child(_opp)
	_opp_sprite = Sprite2D.new()
	_opp_sprite.texture = _opp_tex("idle")
	_opp_sprite.position = Vector2(0, -72)
	_opp.add_child(_opp_sprite)
	_dorko_back = Sprite2D.new()
	_dorko_back.texture = _dorko_tex("guard_down")
	_dorko_back.position = DORKO_HOME
	_dorko_back.modulate.a = 0.62  # translucent so the opponent stays visible
	_dorko_back.z_index = 400
	add_child(_dorko_back)
	_jab_fist = Sprite2D.new()
	_jab_fist.texture = AssetLib.get_or_build("battle_fist", _build_fist_tex)
	_jab_fist.visible = false
	_jab_fist.z_index = 450
	add_child(_jab_fist)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 45
	add_child(_hud)
	# name plates + health bars. His bar leaves the screen. Yours does not.
	_bar(Vector2(16, 14), 90.0, Color(0.4, 0.9, 0.4), "DORKO")
	_bar(Vector2(170, 14), 500.0, Color(0.2, 0.85, 0.8), "THE TURQUOISE ONE")
	_count_lbl = Label.new()
	_count_lbl.position = Vector2(0, 96)
	_count_lbl.size = Vector2(640, 70)
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.pivot_offset = Vector2(320, 35)
	_count_lbl.add_theme_font_size_override("font_size", 46)
	_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_count_lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.05, 0.1))
	_count_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_count_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_count_lbl.visible = false
	_hud.add_child(_count_lbl)
	_big_lbl = Label.new()
	_big_lbl.position = Vector2(0, 130)
	_big_lbl.size = Vector2(640, 90)
	_big_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_lbl.pivot_offset = Vector2(320, 45)
	_big_lbl.add_theme_font_size_override("font_size", 60)
	_big_lbl.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.15))
	_big_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_big_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_big_lbl.visible = false
	_hud.add_child(_big_lbl)
	_tooltip = Label.new()
	_tooltip.position = Vector2(0, 254)
	_tooltip.size = Vector2(640, 16)
	_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	_tooltip.modulate.a = 0.0
	_hud.add_child(_tooltip)
	var controls := Label.new()
	controls.text = "A/D dodge   W block   click jab   Space ---"
	controls.position = Vector2(0, 344)
	controls.size = Vector2(640, 14)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 8)
	controls.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 0.6))
	_hud.add_child(controls)


func _bar(pos: Vector2, width: float, color: Color, label_text: String) -> void:
	var back := ColorRect.new()
	back.position = pos
	back.size = Vector2(width, 10)
	back.color = Color(0.1, 0.1, 0.14, 0.9)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(back)
	var fill := ColorRect.new()
	fill.position = pos + Vector2(1, 1)
	fill.size = Vector2(width - 2.0, 8)
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(fill)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = pos + Vector2(0, 10)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	_hud.add_child(lbl)


# ============================================================== textures

func _opp_tex(pose: String) -> Texture2D:
	return AssetLib.get_or_build("battle_opp_" + pose, func(): return _draw_opp(pose))


func _draw_opp(pose: String) -> Texture2D:
	var p: Painter = AssetLib.painter(52, 72, 2)
	var tq := Color(0.22, 0.82, 0.76)
	var tq_dk := Color(0.1, 0.55, 0.5)
	var tq_hi := Color(0.45, 0.95, 0.88)
	var cx := 26
	# head
	p.ellipse(cx, 9, 7, 8, tq)
	p.dot(cx - 4, 4, tq_hi)
	# visor
	p.poly(PackedVector2Array([Vector2(cx - 6, 7), Vector2(cx + 6, 7), Vector2(cx, 11)]), Color(1.0, 0.55, 0.1))
	p.line(cx - 6, 7, cx + 6, 7, Color(0.62, 0.26, 0.0))
	# smile (or its absence, mid-flicker)
	if pose != "smile_off":
		p.line(cx - 3, 14, cx, 15, Color(0.04, 0.3, 0.27))
		p.line(cx, 15, cx + 3, 14, Color(0.04, 0.3, 0.27))
	else:
		p.hline(cx - 3, 14, 7, Color(0.04, 0.3, 0.27))
	# torso taper
	p.poly(PackedVector2Array([
		Vector2(cx - 7, 16), Vector2(cx + 7, 16), Vector2(cx + 4, 52), Vector2(cx - 4, 52),
	]), tq)
	p.vline(cx - 4, 18, 30, tq_hi)
	# legs
	p.poly(PackedVector2Array([
		Vector2(cx - 4, 52), Vector2(cx + 4, 52), Vector2(cx + 3, 70), Vector2(cx - 3, 70),
	]), tq_dk)
	match pose:
		"windup":
			# the arm goes back further than arms go
			p.line(cx + 6, 20, cx + 20, 30, tq_dk)
			p.line(cx + 20, 30, cx + 23, 46, tq_dk)
			p.circle(cx + 23, 50, 5, tq)          # a fist the size of a promise
			p.circle(cx + 23, 50, 3, tq_hi)
			p.line(cx - 6, 20, cx - 12, 34, tq_dk)  # other arm braced
		"punch":
			# fully extended toward the camera: fist enormous, foreshortened
			p.circle(cx, 44, 12, tq_dk)
			p.circle(cx, 43, 10, tq)
			p.circle(cx - 3, 40, 3, tq_hi)
			p.line(cx - 6, 20, cx - 14, 30, tq_dk)
		_:
			# boxing-adjacent idle: both thin arms loosely up
			p.line(cx - 6, 20, cx - 13, 30, tq_dk)
			p.circle(cx - 13, 32, 3, tq)
			p.line(cx + 6, 20, cx + 13, 30, tq_dk)
			p.circle(cx + 13, 32, 3, tq)
	return p.tex()


func _dorko_tex(pose: String) -> Texture2D:
	return AssetLib.get_or_build("battle_dorko_" + pose, func(): return _draw_dorko_back(pose))


func _draw_dorko_back(pose: String) -> Texture2D:
	var p: Painter = AssetLib.painter(40, 44, 2)
	var fro := Color(0.16, 0.5, 0.2)
	var fro_dk := Color(0.06, 0.24, 0.08)
	var skin := Color(0.96, 0.82, 0.3)
	var up := pose == "guard_up"
	# afro from behind - the star of this camera angle
	p.circle(20, 11, 11, fro_dk)
	p.circle(20, 11, 10, fro)
	p.circle(12, 13, 5, fro)
	p.circle(28, 13, 5, fro)
	p.dot(16, 8, fro_dk)
	p.dot(24, 13, fro_dk)
	# shell on the back
	p.ellipse(20, 29, 10, 7, Color(0.55, 0.28, 0.04))
	p.ellipse(20, 28, 9, 6, Color(0.95, 0.55, 0.12))
	p.ellipse_outline(20, 28, 9, 6, Color(0.99, 0.9, 0.72))
	# guard fists at the frame's edge
	var fy := 22 if up else 30
	p.circle(6, fy, 4, skin)
	p.circle(34, fy, 4, skin)
	p.circle(6, fy, 2, Color(1.0, 0.92, 0.55))
	p.circle(34, fy, 2, Color(1.0, 0.92, 0.55))
	# stubby legs
	p.rect(14, 38, 4, 5, skin)
	p.rect(22, 38, 4, 5, skin)
	return p.tex()


func _build_fist_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(16, 16, 2)
	p.circle(8, 8, 6, Color(0.55, 0.42, 0.08))
	p.circle(8, 8, 5, Color(0.96, 0.82, 0.3))
	p.hline(5, 6, 6, Color(1.0, 0.92, 0.55))
	p.dot(4, 10, Color(0.72, 0.58, 0.15))
	return p.tex()


func _build_glove_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(14, 16, 2)
	p.circle(7, 7, 5, Color(0.95, 0.95, 0.98))
	p.rect(5, 10, 4, 4, Color(0.95, 0.95, 0.98))
	p.hline(5, 12, 4, Color(0.75, 0.75, 0.82))
	p.dot(4, 5, Color(1, 1, 1))
	p.ellipse_outline(7, 7, 5, 5, Color(0.7, 0.7, 0.8))
	return p.tex()


func _build_corner_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 34, 2)
	var sil := Color(0.12, 0.1, 0.16)
	# a round-afro'd silhouette. suspiciously familiar. says nothing.
	p.circle(15, 8, 7, sil)
	p.rect(9, 14, 12, 14, sil)
	p.line(21, 18, 27, 12, sil)  # arm holding the towel
	p.rect(25, 10, 4, 8, Color(0.85, 0.85, 0.9))
	return p.tex()


# ============================================================== inner classes

class Crowd extends Node2D:
	## Two rows of dark bobbing heads behind the ropes. They know something.
	var frozen := false
	var _heads: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1994
		for i in 44:
			_heads.append([
				Vector2(rng.randf_range(10, 630), rng.randf_range(34, 84)),
				rng.randf_range(0.8, 1.6),      # bob speed
				rng.randf_range(0.0, TAU),      # phase
				rng.randf_range(3.0, 5.5),      # radius
			])

	func _process(_delta: float) -> void:
		if not frozen:
			queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for h in _heads:
			var bob := 0.0 if frozen else sin(t * h[1] + h[2]) * 2.0
			draw_circle(h[0] + Vector2(0, bob), h[3], Color(0.16, 0.13, 0.22))
