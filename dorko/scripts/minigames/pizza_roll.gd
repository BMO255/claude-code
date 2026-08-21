extends Control
## Pizza Roll rhythm minigame (spec 7.1b). Full-screen view into the family
## microwave: the plate turns, the box rides it, and a pink ring contracts
## onto a gold ring every 600 ms. Click when they meet. Ten hits in a row and
## the rolls come out CORRECT; three misses and the box stops being a box.
##
## Pushed by the orange room via SceneRouter.push_overlay(
##   load("res://scripts/minigames/pizza_roll.gd").new()); it pops itself.
## Self-contained: autoloads + core classes only; texture keys "pizza_mg_*".
## All timing derives from Time.get_ticks_msec() against one anchor (_t0) —
## never frame deltas — so the visuals and the judgment share one clock.

# ---- rhythm constants --------------------------------------------------------
const BEAT_MS := 600          # one beat every 600 ms
const HIT_WINDOW_MS := 100    # |now - nearest beat| <= 100 ms is a hit...
const PERFECT_MS := 40        # ...and <= 40 ms of those are PERFECT
const WIN_COMBO := 10         # consecutive hits to win
const MAX_MISSES := 3         # total misses to detonate
const COUNTIN_BEATS := 3      # the 3-2-1
const COUNTIN_LEAD_MS := 450  # a breath before the first count beat

# ---- layout ------------------------------------------------------------------
const RING_CENTER := Vector2(320.0, 172.0)
const PLATE_CENTER := Vector2(320.0, 274.0)
const PLATE_SQUASH := 0.42    # the plate's circle, seen nearly edge-on
const ORBIT_R := 58.0         # how far off plate-center the box rides
const SPIN_RATE := 0.0007     # plate radians per millisecond (~9 s per lap)
const BOX_PHASE := 2.1        # the box's fixed angle in plate space

enum Phase { IDLE, COUNTIN, PLAY, DONE }

# ---- state -------------------------------------------------------------------
var _phase := Phase.IDLE
var _t0 := 0                  # ms tick of beat 0; count beats are k = -3..-1
var _next_unjudged := 0       # lowest beat index not yet resolved (hit or miss)
var _ticked_beat := -100      # last beat index whose metronome tick played
var _combo := 0
var _misses := 0
var _outcome := ""            # "" | "win" | "explode" | "quit" (tests read this)
var _swell_kick_ms := -100000
var _plate_stopped := false

var _plate_spin: Node2D
var _plate: Sprite2D
var _box: Sprite2D
var _rings: RingLayer
var _hud: Control
var _fx_root: Control
var _splat_root: Node2D
var _combo_lbl: Label
var _count_lbl: Label
var _strike_icons: Array = []
var _count_tween: Tween = null
var _hum: AudioStreamPlayer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scene()
	_build_hud()
	# the appliance's voice: a low mains hum that never quite resolves
	_hum = AudioBus.play_stream(_hum_stream(), 1.0, -16.0)
	if GameState.get_flag("pizza_exploded"):
		_respawn_intro()
	else:
		_begin_countin()


func _exit_tree() -> void:
	# a room transition can force-pop us mid-round; take the hum along
	_stop_hum()


func _respawn_intro() -> void:
	await get_tree().create_timer(0.4).timeout
	DialogueManager.dorko("There's always another box. That's the problem.")
	await DialogueManager.dialogue_finished
	if _phase == Phase.IDLE:   # unless Esc already ended the visit
		_begin_countin()


func _begin_countin() -> void:
	# t0 is the moment beat 0 fires. The 3-2-1 count beats are simply beats
	# -3, -2, -1 of the same clock (t0 + k*600), so ticks, count labels and
	# ring contraction all read one anchor and can never drift apart.
	_t0 = Time.get_ticks_msec() + COUNTIN_BEATS * BEAT_MS + COUNTIN_LEAD_MS
	_ticked_beat = -(COUNTIN_BEATS + 1)
	_phase = Phase.COUNTIN


# ============================================================== timing core

## Pure hit-test (unit-tested headlessly). Beats fire at t0 + k*600, k >= 0.
## Returns "PERFECT" (|delta| <= 40), "OK" (<= 100), "MISS" (outside every
## window), or "" for clicks before beat 0's window even opens (count-in
## enthusiasm — free, this once). Beats are 600 ms apart, so the distance to
## the NEAREST beat is at most 300 ms; anything past 100 is a miss.
static func classify(now_ms: int, t0_ms: int) -> String:
	var rel := now_ms - t0_ms
	if rel < -HIT_WINDOW_MS:
		return ""
	# nearest beat index: round the signed beat-fraction, floored at 0
	var k := maxi(0, int(round(float(rel) / float(BEAT_MS))))
	var delta := absi(rel - k * BEAT_MS)
	if delta <= PERFECT_MS:
		return "PERFECT"
	if delta <= HIT_WINDOW_MS:
		return "OK"
	return "MISS"


static func nearest_beat(now_ms: int, t0_ms: int) -> int:
	return maxi(0, int(round(float(now_ms - t0_ms) / float(BEAT_MS))))


## Beat k's window closes at t0 + k*600 + 100. Any unresolved beat whose
## window has closed is a MISS; this drains every beat the player let pass.
func _judge_expired(now: int) -> void:
	while _phase == Phase.PLAY and now > _t0 + _next_unjudged * BEAT_MS + HIT_WINDOW_MS:
		_next_unjudged += 1
		_register_miss(RING_CENTER)


func _handle_click(now: int, pos: Vector2) -> void:
	if _phase != Phase.PLAY and _phase != Phase.COUNTIN:
		return
	# resolve older beats first so a late click can't be credited backwards
	_judge_expired(now)
	if _phase == Phase.DONE:
		return  # those expiries may have just ended the round
	var verdict := classify(now, _t0)
	if verdict == "":
		return
	var k := nearest_beat(now, _t0)
	if verdict == "MISS" or k < _next_unjudged:
		# outside every window, or inside one that's already been spent
		# (double-click). Enthusiasm is not accuracy.
		_register_miss(pos)
		return
	_next_unjudged = k + 1
	_register_hit(verdict)


func _register_hit(verdict: String) -> void:
	_combo += 1
	_fx_hit(verdict)
	if _combo >= WIN_COMBO:
		_phase = Phase.DONE
		_outcome = "win"
		if is_inside_tree():
			_win_sequence()


func _register_miss(pos: Vector2) -> void:
	if _phase == Phase.DONE:
		return
	_combo = 0
	_misses += 1
	_fx_miss(pos)
	if _misses >= MAX_MISSES:
		_phase = Phase.DONE
		_outcome = "explode"
		if is_inside_tree():
			_explode_sequence()


# ============================================================== per-frame

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	_animate_scene(now)
	if _phase == Phase.COUNTIN or _phase == Phase.PLAY:
		_tick_beats(now)
	if _phase == Phase.PLAY:
		_judge_expired(now)


func _tick_beats(now: int) -> void:
	# highest beat index whose fire time has passed; floor() keeps the
	# count-in beats (k < 0) on the same signed clock
	var cur := int(floor(float(now - _t0) / float(BEAT_MS)))
	if cur <= _ticked_beat:
		return
	_ticked_beat = cur   # a hiccuped frame ticks once, not twice
	_rings.last_beat_ms = now
	if cur < 0:
		AudioBus.play_sfx("beat", 0.9)
		_show_count(str(-cur))
	elif _phase == Phase.COUNTIN:
		# reaching (or skipping past) beat 0 starts play either way
		_phase = Phase.PLAY
		AudioBus.play_sfx("beat", 1.1)
		_show_count("GO.")
	else:
		AudioBus.play_sfx("beat")


func _animate_scene(now: int) -> void:
	var t := float(now)
	if not _plate_stopped:
		_plate.rotation = t * SPIN_RATE
	# The box rides the turntable: a circle in plate space becomes an ellipse
	# on screen because we see the plate nearly edge-on (y squashed by 0.42).
	var a := _plate.rotation + BOX_PHASE
	var orbit := Vector2(cos(a) * ORBIT_R, sin(a) * ORBIT_R * PLATE_SQUASH)
	var depth := lerpf(0.86, 1.06, (sin(a) + 1.0) * 0.5)   # nearer edge = bigger
	var swell := 1.0 + 0.12 * float(mini(_misses, 3))
	# each miss also lands a 250 ms scale kick so the swell reads as an event
	var kick := 1.0 + 0.22 * maxf(0.0, 1.0 - float(now - _swell_kick_ms) / 250.0)
	var shiver := 0.0
	if _box.visible and _misses > 0:
		shiver = sin(t * 0.02) * 0.012 * float(_misses)
	if _box.visible and _outcome == "explode":
		shiver = sin(t * 0.09) * 0.09   # the box's closing argument
	_box.position = PLATE_CENTER + orbit + Vector2(0.0, -30.0 * depth * swell)
	_box.scale = Vector2.ONE * (depth * swell * kick)
	_box.rotation = sin(t * 0.0023) * 0.05 + shiver
	_rings.now_ms = now
	_rings.t0_ms = _t0
	_rings.pulsing = _phase == Phase.COUNTIN or _phase == Phase.PLAY
	_rings.queue_redraw()


# ============================================================== input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_handle_click(Time.get_ticks_msec(), event.position)


func _unhandled_input(event: InputEvent) -> void:
	# overlays own their Esc (UILayer deliberately ignores it while we're up)
	if event.is_action_pressed("pause"):
		accept_event()
		if _phase == Phase.DONE:
			return   # win/boom sequences see themselves out
		_quit_politely()


func _quit_politely() -> void:
	# Esc = "not right now, microwave." No penalty, no flags, no judgment.
	_phase = Phase.DONE
	_outcome = "quit"
	AudioBus.play_sfx("pop", 0.8)
	SceneRouter.pop_overlay()


# ============================================================== outcomes

func _win_sequence() -> void:
	_stop_hum()
	_plate_stopped = true          # the microwave considers this dish finished
	AudioBus.play_sfx("ding")
	_show_count("CORRECT.")
	await get_tree().create_timer(0.35).timeout
	AudioBus.play_sfx("bell")
	Fx.flash(Color(1.0, 0.98, 0.82), 0.2)
	await get_tree().create_timer(0.55).timeout
	Inventory.add_item("perfect_pizza_roll")
	UILayer.fly_item("perfect_pizza_roll", Vector2(320.0, 180.0))
	GameState.set_flag("pizza_win")
	await get_tree().create_timer(0.75).timeout
	DialogueManager.dorko("It's the correct pizza roll. I didn't know they made those.")
	SceneRouter.pop_overlay()


func _explode_sequence() -> void:
	_set_box_stage(3)
	# one last strained wobble while the cardboard weighs its options
	await get_tree().create_timer(0.42).timeout
	_stop_hum()
	_plate_stopped = true
	_box.visible = false
	AudioBus.play_sfx("explosion")
	Fx.flash(Color(1.0, 0.85, 0.55), 0.3)
	Fx.shake(0.55, 11.0)
	_add_scorch()
	_splatter()
	GameState.set_flag("pizza_exploded")
	await get_tree().create_timer(1.1).timeout
	DialogueManager.dorko("That was the last of them.")
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(0.45).timeout   # a short beat for the fallen
	SceneRouter.pop_overlay()


# ============================================================== feedback fx
# Everything below early-returns when the node isn't in the tree, so the
# state machine above can be driven headlessly for tests.

func _fx_hit(verdict: String) -> void:
	if not is_inside_tree():
		return
	if verdict == "PERFECT":
		AudioBus.play_sfx("perfect")
		_spawn_feedback("PERFECT", Color(1.0, 0.92, 0.2), RING_CENTER + Vector2(0, -66), 15)
		_rings.add_hit_fx(Color(1.0, 0.92, 0.2))
	else:
		AudioBus.play_sfx("click", 1.2)
		_spawn_feedback("OK", Color(0.75, 0.9, 1.0), RING_CENTER + Vector2(0, -60), 13)
		_rings.add_hit_fx(Color(0.75, 0.9, 1.0))
	_bump_combo_label()


func _fx_miss(pos: Vector2) -> void:
	if not is_inside_tree():
		return
	_swell_kick_ms = Time.get_ticks_msec()
	AudioBus.play_sfx("miss_buzz")
	AudioBus.play_sfx("bwomp", 1.4, -10.0)
	_spawn_feedback("MISS", Color(1.0, 0.28, 0.2), pos + Vector2(0, -30), 14)
	_set_box_stage(_misses)
	_update_strikes()
	_bump_combo_label()
	Fx.shake(0.16, 3.0)


func _spawn_feedback(text: String, color: Color, pos: Vector2, font_size := 14) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(randf_range(-24.0, 24.0), 0.0)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_root.add_child(lbl)
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


func _bump_combo_label() -> void:
	_combo_lbl.text = "STREAK %d/%d" % [_combo, WIN_COMBO]
	_combo_lbl.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(_combo_lbl, "scale", Vector2.ONE, 0.12)


func _update_strikes() -> void:
	for i in _strike_icons.size():
		var icon: TextureRect = _strike_icons[i]
		# the supply depletes right-to-left; a spent box goes grey and quiet
		var spent: bool = i >= MAX_MISSES - _misses
		icon.modulate = Color(0.35, 0.35, 0.38, 0.7) if spent else Color(1, 1, 1, 1)


func _show_count(text: String) -> void:
	_count_lbl.text = text
	_count_lbl.visible = true
	_count_lbl.modulate.a = 1.0
	_count_lbl.scale = Vector2(1.35, 1.35)
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_property(_count_lbl, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_tween.tween_interval(0.28)
	_count_tween.tween_property(_count_lbl, "modulate:a", 0.0, 0.2)


func _set_box_stage(stage: int) -> void:
	_box.texture = _box_tex(clampi(stage, 0, 3))


func _add_scorch() -> void:
	# the box's plate-local angle never changed (BOX_PHASE), so the burn mark
	# lands exactly where the box was, riding the now-motionless plate
	var s := Sprite2D.new()
	s.texture = _scorch_tex()
	s.position = Vector2(cos(BOX_PHASE), sin(BOX_PHASE)) * ORBIT_R
	_plate.add_child(s)


func _splatter() -> void:
	AudioBus.play_sfx("splat")
	AudioBus.play_sfx("splat", 0.78, -4.0)
	# placement varies per detonation; only the textures are deterministic
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	for i in rng.randi_range(4, 6):
		var blob := Sprite2D.new()
		blob.texture = _splat_tex(i % 3)
		blob.position = Vector2(rng.randf_range(120.0, 520.0), rng.randf_range(60.0, 240.0))
		blob.rotation = rng.randf_range(-0.4, 0.4)
		var s := rng.randf_range(0.9, 1.8)
		blob.scale = Vector2(s * 1.5, s * 1.5)
		blob.modulate.a = 0.0
		_splat_root.add_child(blob)
		var d0 := rng.randf_range(0.0, 0.14)
		var tw := blob.create_tween()
		tw.set_parallel(true)
		tw.tween_property(blob, "modulate:a", 1.0, 0.05).set_delay(d0)
		tw.tween_property(blob, "scale", Vector2(s, s), 0.16).set_delay(d0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# then the sauce remembers gravity: a brief drip down the glass
		tw.chain().tween_property(blob, "position:y", blob.position.y + rng.randf_range(26.0, 60.0), rng.randf_range(0.9, 1.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(blob, "scale:y", s * 1.3, 1.2)


func _stop_hum() -> void:
	if _hum != null and is_instance_valid(_hum):
		_hum.stop()
	_hum = null


# ============================================================== construction

func _build_scene() -> void:
	var bg := TextureRect.new()
	bg.texture = _bg_tex()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_plate_spin = Node2D.new()
	_plate_spin.position = PLATE_CENTER
	_plate_spin.scale = Vector2(1.0, PLATE_SQUASH)
	add_child(_plate_spin)
	_plate = Sprite2D.new()
	_plate.texture = _plate_tex()
	_plate_spin.add_child(_plate)
	_box = Sprite2D.new()
	_box.texture = _box_tex(0)
	add_child(_box)
	var glass := TextureRect.new()
	glass.texture = _glass_tex()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)
	_rings = RingLayer.new()
	_rings.position = RING_CENTER
	add_child(_rings)
	# pre-bake the swell stages and sauce so a miss never hitches
	for i in 4:
		_box_tex(i)
	for i in 3:
		_splat_tex(i)
	_scorch_tex()


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	_combo_lbl = _make_label("STREAK 0/%d" % WIN_COMBO, Vector2(0, 26), Vector2(640, 18), 13, Color(1.0, 0.9, 0.3))
	_combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_lbl.pivot_offset = Vector2(320, 9)
	_hud.add_child(_combo_lbl)
	var supply := _make_label("BOX SUPPLY", Vector2(508, 12), Vector2(104, 10), 7, Color(0.65, 0.85, 0.85, 0.85))
	supply.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(supply)
	for i in MAX_MISSES:
		var icon := TextureRect.new()
		icon.texture = _strike_tex()
		icon.position = Vector2(514.0 + 34.0 * float(i), 24.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(icon)
		_strike_icons.append(icon)
	var brand := _make_label("WAVE BOY 600", Vector2(24, 342), Vector2(140, 12), 9, Color(0.42, 0.68, 0.66, 0.9))
	_hud.add_child(brand)
	var hint := _make_label("Click when the pink ring lands on the gold one.", Vector2(0, 341), Vector2(640, 12), 8, Color(0.9, 0.9, 0.85, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(hint)
	_count_lbl = _make_label("", Vector2(0, 108), Vector2(640, 64), 42, Color(1.0, 0.95, 0.55))
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.pivot_offset = Vector2(320, 32)
	_count_lbl.visible = false
	_hud.add_child(_count_lbl)
	_fx_root = Control.new()
	_fx_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_root)
	_splat_root = Node2D.new()
	add_child(_splat_root)


func _make_label(text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================================================== textures

func _bg_tex() -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_bg", func():
		var p: Painter = AssetLib.painter(320, 180, 2)
		var frame := Color(0.09, 0.21, 0.23)
		var frame_hi := Color(0.16, 0.34, 0.36)
		var frame_dk := Color(0.04, 0.10, 0.11)
		var wall_side := Color(0.18, 0.12, 0.10)
		var wall_back := Color(0.24, 0.16, 0.13)
		var ceilc := Color(0.13, 0.09, 0.08)
		var floorc := Color(0.21, 0.145, 0.12)
		p.rect(0, 0, 320, 180, frame)
		p.rect_outline(0, 0, 320, 180, frame_dk)
		p.rect_outline(1, 1, 318, 178, frame_hi)
		p.rect_outline(25, 19, 270, 138, frame_dk)
		p.rect_outline(24, 18, 272, 140, frame_hi)
		# the cavity: four perspective walls around the lit back panel
		p.poly(PackedVector2Array([Vector2(26, 20), Vector2(294, 20), Vector2(242, 44), Vector2(78, 44)]), ceilc)
		p.poly(PackedVector2Array([Vector2(26, 20), Vector2(78, 44), Vector2(78, 128), Vector2(26, 156)]), wall_side)
		p.poly(PackedVector2Array([Vector2(294, 20), Vector2(242, 44), Vector2(242, 128), Vector2(294, 156)]), wall_side)
		p.poly(PackedVector2Array([Vector2(26, 156), Vector2(78, 128), Vector2(242, 128), Vector2(294, 156)]), floorc)
		p.rect(78, 44, 164, 84, wall_back)
		p.speckle(78, 44, 164, 84, Color(0.18, 0.12, 0.10), 0.05, 11)
		p.speckle(30, 130, 260, 24, Color(0.14, 0.10, 0.08), 0.06, 12)
		# the bulb: warm, tired, doing its best in the top corner
		p.ellipse(226, 32, 16, 7, Color(1.0, 0.8, 0.4, 0.25))
		p.ellipse(226, 32, 10, 4.5, Color(1.0, 0.87, 0.5, 0.5))
		p.ellipse(226, 32, 5, 2.5, Color(1.0, 0.96, 0.75))
		p.ellipse(210, 70, 46, 26, Color(1.0, 0.85, 0.5, 0.07))
		p.ellipse(180, 140, 80, 14, Color(1.0, 0.85, 0.5, 0.06))
		# vent slits along the bottom frame
		for i in 8:
			p.hline(36 + i * 10, 168, 6, frame_dk)
			p.hline(36 + i * 10, 167, 6, frame_hi)
		# door latch, right frame
		p.rect(304, 78, 8, 26, frame_dk)
		p.rect(305, 79, 6, 24, Color(0.13, 0.28, 0.30))
		p.vline(306, 82, 18, frame_hi)
		# the timer display reads NOW. It has read NOW since it was plugged in.
		p.rect(126, 164, 40, 11, Color(0.02, 0.05, 0.04))
		p.rect_outline(126, 164, 40, 11, frame_dk)
		var seg := Color(0.3, 0.95, 0.5)
		p.vline(131, 166, 7, seg)
		p.line(131, 166, 135, 172, seg)
		p.vline(135, 166, 7, seg)
		p.rect_outline(139, 166, 6, 7, seg)
		p.vline(148, 166, 6, seg)
		p.vline(156, 166, 6, seg)
		p.line(148, 172, 152, 169, seg)
		p.line(156, 172, 152, 169, seg)
		return p.tex())


func _glass_tex() -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_glass", func():
		var p: Painter = AssetLib.painter(320, 180, 2)
		# the door mesh: a polite polka-dot grid between you and the food
		var mesh := Color(0.0, 0.0, 0.0, 0.16)
		for gy in range(24, 156, 7):
			for gx in range(30, 292, 7):
				var off := 3 if (gy / 7) % 2 == 0 else 0
				p.dot(gx + off, gy, mesh)
		# two lazy diagonal sheens
		for i in 14:
			p.line(96 + i, 18, 30 + i, 96, Color(1, 1, 1, 0.05))
		for i in 8:
			p.line(232 + i, 18, 178 + i, 84, Color(1, 1, 1, 0.04))
		# grease archaeology
		p.speckle(40, 30, 240, 120, Color(0.9, 0.75, 0.3, 0.10), 0.01, 21)
		p.ellipse(96, 120, 10, 5, Color(0.85, 0.7, 0.3, 0.06))
		return p.tex())


func _plate_tex() -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_plate", func():
		var p: Painter = AssetLib.painter(116, 116, 2)
		var glass_lo := Color(0.60, 0.66, 0.72)
		var glass_mid := Color(0.72, 0.78, 0.83)
		var glass_hi := Color(0.80, 0.86, 0.90)
		p.circle(58, 58, 56, glass_lo)
		p.circle(58, 58, 52, glass_mid)
		p.circle(58, 58, 40, glass_hi)
		p.ellipse_outline(58, 58, 56, 56, Color(0.42, 0.48, 0.55))
		p.ellipse_outline(58, 58, 46, 46, Color(0.62, 0.68, 0.74))
		p.circle(58, 58, 7, glass_mid)
		p.ellipse_outline(58, 58, 7, 7, Color(0.55, 0.61, 0.68))
		# spokes so the spin reads on screen
		for i in 8:
			var a := TAU * float(i) / 8.0
			p.line(int(round(58.0 + cos(a) * 12.0)), int(round(58.0 + sin(a) * 12.0)),
				int(round(58.0 + cos(a) * 38.0)), int(round(58.0 + sin(a) * 38.0)), Color(0.60, 0.67, 0.73))
		p.speckle(20, 20, 76, 76, Color(0.55, 0.62, 0.68), 0.03, 31)
		return p.tex())


func _box_tex(stage: int) -> Texture2D:
	var s := clampi(stage, 0, 3)
	return AssetLib.get_or_build("pizza_mg_box_%d" % s, func():
		var p: Painter = AssetLib.painter(56, 40, 2)
		var bulge: int = [0, 2, 4, 7][s]
		var teal := Color(0.05, 0.58, 0.62)
		var teal_hi := Color(0.18, 0.74, 0.76)
		var teal_dk := Color(0.02, 0.33, 0.37)
		var orange := Color(1.0, 0.52, 0.06)
		var magenta := Color(0.92, 0.12, 0.52)
		# body + per-stage bulges (the filling negotiating with the cardboard)
		p.rect(11, 10, 34, 24, teal)
		p.ellipse(11, 22, 2.0 + bulge, 12.0, teal)
		p.ellipse(45, 22, 2.0 + bulge, 12.0, teal)
		p.ellipse(28, 11, 17.0, 2.0 + bulge * 0.7, teal)
		p.ellipse(28, 33, 17.0, 1.5 + bulge * 0.5, teal)
		p.rect(11, 10, 34, 2, teal_hi)
		p.rect(11, 32, 34, 2, teal_dk)
		if s < 3:
			# lid flap, still on speaking terms with the box
			p.rect(11, 5, 34, 5, teal_dk)
			p.hline(11, 5, 34, teal)
		else:
			# lid blown ajar; the light from inside is not oven light
			p.poly(PackedVector2Array([Vector2(12, 10), Vector2(17, 3), Vector2(22, 10)]), teal_dk)
			p.poly(PackedVector2Array([Vector2(30, 10), Vector2(36, 4), Vector2(41, 10)]), teal_dk)
			p.hline(13, 9, 30, Color(1.0, 0.7, 0.2))
		# label blob + confident unreadable copy
		p.ellipse(27, 21, 12, 8, orange)
		p.ellipse_outline(27, 21, 12, 8, Color(0.72, 0.3, 0.0))
		p.hline(19, 18, 8, Color.WHITE)
		p.hline(29, 18, 5, Color.WHITE)
		p.hline(20, 21, 12, Color(1.0, 0.95, 0.8))
		p.hline(21, 24, 8, Color.WHITE)
		# corner burst: 40% MORE (of something)
		p.circle(42, 13, 4, magenta)
		p.hline(40, 12, 4, Color.WHITE)
		p.hline(41, 14, 3, Color.WHITE)
		# glamour shot of one roll
		p.ellipse(39, 28, 5, 3, Color(0.9, 0.66, 0.3))
		p.ellipse_outline(39, 28, 5, 3, Color(0.6, 0.4, 0.12))
		p.dot(38, 27, Color(0.8, 0.2, 0.1))
		p.dot(41, 29, Color(0.8, 0.2, 0.1))
		# freezer frost, not long for this world
		p.dot(13, 12, Color(0.75, 0.95, 1.0))
		p.dot(15, 30, Color(0.75, 0.95, 1.0, 0.8))
		p.dot(43, 31, Color(0.75, 0.95, 1.0, 0.8))
		if s >= 1:
			# seams starting to state their objection
			p.vline(9 - bulge, 18, 4, Color(1, 1, 1, 0.75))
			p.vline(47 + bulge, 20, 4, Color(1, 1, 1, 0.75))
		if s >= 2:
			p.dot(50, 7, Color(0.6, 0.9, 1.0))        # box sweat
			p.dot(51, 9, Color(0.6, 0.9, 1.0, 0.8))
			p.vline(28, 32, 4, Color(1.0, 0.8, 0.3))  # bottom seam glowing
		if s >= 3:
			p.ellipse_outline(20, 3, 2.0, 2.5, Color(0.92, 0.92, 0.92, 0.7))
			p.ellipse_outline(38, 2, 1.5, 2.0, Color(0.92, 0.92, 0.92, 0.6))
			p.speckle(12, 12, 32, 20, Color(0.9, 0.5, 0.1, 0.5), 0.05, 51)
		return p.tex())


func _strike_tex() -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_strike", func():
		var p: Painter = AssetLib.painter(16, 12, 2)
		p.rect(1, 1, 14, 3, Color(0.02, 0.33, 0.37))
		p.rect(1, 3, 14, 8, Color(0.05, 0.58, 0.62))
		p.ellipse(8, 7, 4, 2.5, Color(1.0, 0.52, 0.06))
		p.rect_outline(1, 1, 14, 10, Color(0.02, 0.2, 0.24))
		return p.tex())


func _splat_tex(variant: int) -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_splat_%d" % variant, func():
		var p: Painter = AssetLib.painter(26, 26, 2)
		var sauce := Color(0.72, 0.10, 0.05, 0.94)
		var dark := Color(0.5, 0.05, 0.03, 0.95)
		p.circle(13, 12, 7, sauce)
		p.circle(13, 12, 3.5, dark)
		match variant:
			0:
				p.circle(6, 8, 3, sauce)
				p.circle(20, 15, 2.5, sauce)
				p.circle(16, 4, 1.5, sauce)
				p.circle(9, 20, 2, sauce)
			1:
				p.circle(21, 8, 3, sauce)
				p.circle(4, 14, 2, sauce)
				p.circle(12, 22, 2.5, sauce)
			_:
				p.circle(7, 18, 3, sauce)
				p.circle(19, 20, 2, sauce)
				p.circle(22, 11, 1.5, sauce)
				p.circle(5, 5, 1.5, sauce)
		p.dot(11, 9, Color(0.95, 0.45, 0.35, 0.8))   # glisten
		return p.tex())


func _scorch_tex() -> Texture2D:
	return AssetLib.get_or_build("pizza_mg_scorch", func():
		var p: Painter = AssetLib.painter(30, 22, 2)
		p.ellipse(15, 11, 13, 8, Color(0.07, 0.05, 0.05, 0.9))
		p.ellipse(15, 11, 8, 5, Color(0.03, 0.02, 0.02))
		p.speckle(3, 3, 24, 16, Color(0.15, 0.10, 0.08, 0.8), 0.08, 41)
		p.dot(10, 9, Color(0.95, 0.45, 0.1, 0.9))    # embers, briefly proud
		p.dot(19, 13, Color(0.9, 0.3, 0.08, 0.9))
		return p.tex())


# ============================================================== synth audio

## 1 s seamless mains hum: 120 Hz fundamental + 240 Hz overtone, both integer
## cycle counts over the loop so the seam is inaudible; zero attack/release
## so the envelope doesn't dip at the join. A whisper of lowpassed noise on
## top so it sounds like an appliance, not a sine.
func _hum_stream() -> AudioStreamWAV:
	var s := SfxSynth.mix([
		SfxSynth.tone(120.0, 1.0, "sine", 0.10, 0.0, 0.0),
		SfxSynth.tone(240.0, 1.0, "sine", 0.035, 0.0, 0.0),
		SfxSynth.noise(1.0, 0.02, 0.08, 0.0, 0.0, 977),
	])
	return SfxSynth.to_wav(s, true)


# ============================================================== inner classes

## The telegraph: a fixed gold target ring plus pink rings that contract onto
## it. All radii derive from (now - t0) — the same clock the judgment uses —
## so what you see and what gets scored can never disagree.
class RingLayer:
	extends Node2D

	const BEAT := 600
	const TARGET_R := 46.0
	const START_R := 168.0
	const RING_COL := Color(0.95, 0.3, 0.75)    # clashes with everything. correct.
	const TARGET_COL := Color(1.0, 0.9, 0.25)

	var now_ms := 0
	var t0_ms := 0
	var pulsing := false
	var last_beat_ms := -100000
	var _hit_fx: Array = []                      # [start_ms, Color]

	func add_hit_fx(col: Color) -> void:
		_hit_fx.append([now_ms, col])

	func _draw() -> void:
		# target ring, brightening briefly each time a beat lands on it
		var flash := maxf(0.0, 1.0 - float(now_ms - last_beat_ms) / 130.0)
		draw_arc(Vector2.ZERO, TARGET_R + 4.0, 0.0, TAU, 48,
			Color(TARGET_COL.r, TARGET_COL.g, TARGET_COL.b, 0.10 + 0.25 * flash), 7.0)
		draw_arc(Vector2.ZERO, TARGET_R, 0.0, TAU, 48, Color(TARGET_COL, 0.85), 3.0)
		if pulsing:
			# k_up is the next beat index (negative during the count-in — same
			# clock). A ring for beat k spawns one beat early at START_R and
			# contracts linearly, arriving at TARGET_R exactly at t0 + k*600.
			# Two are drawn so the beat after next is already faintly inbound.
			var k_up := int(ceil(float(now_ms - t0_ms) / float(BEAT)))
			for j in 2:
				var bt := t0_ms + (k_up + j) * BEAT
				var pr := 1.0 - float(bt - now_ms) / float(BEAT)  # 1 at the beat
				var r := lerpf(START_R, TARGET_R, pr)
				if r < TARGET_R:
					continue
				var a := clampf(0.12 + 0.88 * pr, 0.0, 1.0)
				var col := RING_COL.lerp(TARGET_COL, clampf(pr, 0.0, 1.0) * 0.7)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(col.r, col.g, col.b, a), 4.0)
		# hit bursts: a quick ring expanding off the target
		var keep: Array = []
		for fx in _hit_fx:
			var age := float(now_ms - fx[0])
			if age < 240.0:
				keep.append(fx)
				var c: Color = fx[1]
				draw_arc(Vector2.ZERO, TARGET_R + age * 0.22, 0.0, TAU, 48,
					Color(c.r, c.g, c.b, 1.0 - age / 240.0), 3.0)
		_hit_fx = keep
