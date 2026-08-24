extends Control
## Credits (spec 8.5). They roll over the pizza-roll pulse indicator, ticking
## at 600 ms. The credits are clickable: land 10 on-beat clicks (same +-100 ms
## window as the microwave) and the post-credits line plays. Esc skips.
## Ends by setting game_completed and returning to the main menu.

const BEAT_MS := 600
const HIT_WINDOW_MS := 150  # matches the microwave's forgiving window
const UNLOCK_HITS := 10
const SCROLL_SPEED := 22.0  # px/s

const LINES := [
	"D O R K O",
	"",
	"a house, in order of appearance",
	"",
	"DORKO - himself",
	"THE COUCH GUY - the couch's",
	"WINDERS XD - as itself, unfortunately",
	"THE PIZZA ROLLS - 600ms apart, forever",
	"THE BLUE BOMB - retired",
	"GALAXY NIBBLER - load-bearing cabinet",
	"THE TURQUOISE ONE - down for the count",
	"",
	"sandwich continuity - the kitchen",
	"600ms compliance officer - the microwave",
	"wire order archivist - the VHS shelf",
	"crowd noise - pitched disappointment",
	"marble wrangling - the ramune bottle",
	"afro structural engineering - the afro",
	"window authenticity consultant - the kitchen window",
	"laugh track - laughed alone, at night",
	"",
	"all art, music and noise were grown",
	"inside this cartridge from raw math",
	"",
	"no pizza rolls reached the correct",
	"temperature during production",
	"",
	"except one",
	"",
	"thank you for coming downstairs",
	"you were supposed to be here",
]

var _t0 := 0
var _last_tick := -1
var _hits := 0
var _done := false
var _rolling := true

var _scroll: VBoxContainer
var _ring: PulseRing
var _hits_lbl: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bgr := ColorRect.new()
	bgr.color = Color(0.02, 0.01, 0.03, 0.96)
	bgr.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bgr)
	_ring = PulseRing.new()
	_ring.position = Vector2(320, 188)
	add_child(_ring)
	_scroll = VBoxContainer.new()
	_scroll.position = Vector2(0, 372)
	_scroll.size = Vector2(640, 0)
	_scroll.add_theme_constant_override("separation", 6)
	add_child(_scroll)
	for line in LINES:
		var lbl := Label.new()
		lbl.text = line
		lbl.custom_minimum_size = Vector2(640, 0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12 if line == "D O R K O" else 10)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.1, 0.25))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		_scroll.add_child(lbl)
	_hits_lbl = Label.new()
	_hits_lbl.position = Vector2(560, 336)
	_hits_lbl.add_theme_font_size_override("font_size", 9)
	_hits_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 0.8))
	add_child(_hits_lbl)
	_t0 = Time.get_ticks_msec() + 800
	AudioBus.stop_music(1.5)


func _process(delta: float) -> void:
	if _done:
		return
	var now := Time.get_ticks_msec()
	# metronome: same clock the click judgment reads
	var cur := int(floor(float(now - _t0) / float(BEAT_MS)))
	if cur > _last_tick and cur >= 0:
		_last_tick = cur
		_ring.beat_ms = now
		AudioBus.play_sfx("beat", 1.0, -8.0)
	_ring.now_ms = now
	_ring.t0_ms = _t0
	_ring.queue_redraw()
	if _rolling:
		_scroll.position.y -= SCROLL_SPEED * delta
		# credits end once the last line clears the top
		if _scroll.position.y < -(_scroll.size.y + 40.0):
			_finish()


func _gui_input(event: InputEvent) -> void:
	if _done or event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var now := Time.get_ticks_msec()
	var rel := now - _t0
	if rel < -HIT_WINDOW_MS:
		return
	var k := maxi(0, int(round(float(rel) / float(BEAT_MS))))
	if absi(rel - k * BEAT_MS) <= HIT_WINDOW_MS:
		_hits += 1
		AudioBus.play_sfx("perfect", 1.0, -6.0)
		_ring.flash()
		_hits_lbl.text = "%d/%d" % [mini(_hits, UNLOCK_HITS), UNLOCK_HITS]
	else:
		AudioBus.play_sfx("tick", 0.8, -12.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _done:
		accept_event()
		_finish()  # skipping forfeits the post-credits line; fair trade


func _finish() -> void:
	if _done:
		return
	_done = true
	_rolling = false
	if _hits >= UNLOCK_HITS:
		await _post_credits()
	GameState.set_flag("game_completed")
	GameState.save_game()
	SceneRouter.pop_overlay()
	SceneRouter.goto_main_menu()


func _post_credits() -> void:
	_scroll.visible = false
	_ring.visible = false
	_hits_lbl.visible = false
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = "...Could you make me another sandwich."
	lbl.position = Vector2(0, 168)
	lbl.size = Vector2(640, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68))
	add_child(lbl)
	# his voice, from somewhere upstairs
	for i in 5:
		AudioBus.blip(0.5, -8.0)
		await get_tree().create_timer(0.14).timeout
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree():
		return
	lbl.visible = false
	await get_tree().create_timer(0.8).timeout


class PulseRing extends Node2D:
	## The pizza-roll pulse, reprised: contracting ring, 600 ms period.
	var now_ms := 0
	var t0_ms := 0
	var beat_ms := -100000
	var _flash_ms := -100000

	func flash() -> void:
		_flash_ms = now_ms

	func _draw() -> void:
		var hit_glow := maxf(0.0, 1.0 - float(now_ms - _flash_ms) / 250.0)
		var beat_glow := maxf(0.0, 1.0 - float(now_ms - beat_ms) / 150.0)
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 40,
			Color(1.0, 0.9, 0.25, 0.5 + 0.5 * beat_glow + 0.3 * hit_glow), 2.5)
		var k := int(ceil(float(now_ms - t0_ms) / 600.0))
		var bt := t0_ms + k * 600
		var pr := 1.0 - float(bt - now_ms) / 600.0
		var r := lerpf(120.0, 36.0, clampf(pr, 0.0, 1.0))
		if r > 36.5:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.95, 0.3, 0.75, 0.25 + 0.5 * pr), 2.0)
		if hit_glow > 0.0:
			draw_arc(Vector2.ZERO, 36.0 + (1.0 - hit_glow) * 30.0, 0.0, TAU, 40,
				Color(1.0, 0.95, 0.5, hit_glow), 2.0)
