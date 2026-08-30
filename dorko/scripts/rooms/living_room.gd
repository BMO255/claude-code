extends BaseRoom
## The Living Room (spec 7.2). Mustard walls, a floral couch with a permanent
## resident, a TV that only gets one channel and that channel is wrong, a
## console with a breathing cartridge slot, a rug over a secret, and a lever
## nobody is reaching over him to pull.

const BARKS := [
	"Could you make me a sandwich.",
	"Could you make me a sandwich.",
	"Could you make me a sandwich.",
	"Will. Will. W- Will.",
	"I'm not gonna sit here and- sit here.",
	"Hahaha. Ha.",
	"In West- in- in West-",
	"That's my- that's m- sandwich.",
	"Uncle. Uncle. Uncle.",
]

const SUBTITLES := [
	"NOW THIS IS A STORY ALL ABOUT HOW",
	"my life got flipped",
	"flipped",
	"flipped",
	"turned upside d-",
	"CAROLINE",
	"will",
	"WILL",
	"WILLLL",
	"we were on a BREAK a BREAK a BR-",
	"[audience knows something]",
	"the uncle returns tonight",
	"he's BACK and he's [static]",
	"laugh. laugh now.",
	"sandwich sandwich sandwich sandwich",
	"D-D-D-DINNER TIME",
	"who ate the- WHO ATE THE-",
	"[applause reversed]",
]

var _cg: CouchGuy
var _tv: TvScreen
var _tv_sub: Label
var _fan: CeilingFan
var _rug_sprite: Sprite2D
var _rug_hs: Hotspot
var _lever_sprite: Sprite2D
var _bark_timer: Timer
var _tv_fx_timer: Timer
var _cutscene := false


func _room_config() -> void:
	room_id = "living_room"
	music_name = "living"
	footstep_surface = "carpet"
	horizon_y = 195.0
	spawn_points = {
		"default": {"pos": Vector2(95, 285), "dir": "right"},
		"from_orange": {"pos": Vector2(95, 285), "dir": "right"},
		"from_kitchen": {"pos": Vector2(548, 285), "dir": "left"},
	}


func _room_setup() -> void:
	_build_walls()
	add_floor("solid", Color(0.5, 0.36, 0.2), Color(0.44, 0.31, 0.17))
	AssetLib.get_or_build("living_rug_open", _build_rug_open_tex)  # for the PNG bake
	_build_rug()
	_build_tv()
	_build_couch()
	_build_furniture()
	_build_fan()
	_build_timers()


func _on_room_entered() -> void:
	if GameState.get_flag("couch_fed") and _rug_hs != null:
		_open_trapdoor_visual()


# ---------------------------------------------------------------- construction

func _build_walls() -> void:
	var wallc := Node2D.new()
	bg.add_child(wallc)
	add_parallax(wallc, 1.0)
	var wall := Sprite2D.new()
	wall.texture = AssetLib.get_or_build("living_wall", _build_wall_tex)
	wall.centered = false
	wallc.add_child(wall)
	# doorways: left back to the orange room, right to the kitchen
	add_exit({
		"name": "Doorway (Orange Room)",
		"pos": Vector2(38, 240),
		"size": Vector2(64, 190),
		"target": "orange_room",
		"spawn": "from_living",
		"look": "Back the way I came. The orange is audible from here.",
		"interact": Vector2(78, 300),
	})
	add_exit({
		"name": "Doorway (Kitchen)",
		"pos": Vector2(602, 240),
		"size": Vector2(64, 190),
		"target": "kitchen",
		"spawn": "from_living",
		"look": "Cold light and tile in there. A room that means business.",
		"interact": Vector2(562, 300),
	})


func _build_rug() -> void:
	# shifted right of center so the foreground TV doesn't sit on the secret
	_rug_sprite = Sprite2D.new()
	_rug_sprite.texture = AssetLib.get_or_build("living_rug", _build_rug_tex)
	_rug_sprite.position = Vector2(365, 306)
	_rug_sprite.z_index = -450
	bg.add_child(_rug_sprite)
	_rug_hs = add_hotspot({
		"name": "Rug",
		"pos": Vector2(365, 306),
		"size": Vector2(120, 42),
		"look": "There's a draft coming up through it. Rugs shouldn't breathe.",
		"touch": _touch_rug,
		"visual": _rug_sprite,
		"interact": Vector2(365, 332),
	})


func _build_tv() -> void:
	# The TV sits in the FOREGROUND, planted right in front of the couch guy,
	# screen toward the camera (he watches it; we watch it over its shoulder).
	# Its ground line (y=356) keeps it drawn in front of him (his z is ~272).
	var stand := add_prop(AssetLib.get_or_build("living_tv_stand", _build_stand_tex), Vector2(230, 312))
	_tv = TvScreen.new()
	# stand sprite is 112x88 centered at (230,312): top-left (174,268); the
	# CRT's inner screen rect starts 6px in from that and is exactly 88x40.
	_tv.position = Vector2(180, 274)
	_tv.z_index = 357  # one over the stand's ground-line z
	add_child(_tv)
	_tv_sub = Label.new()
	_tv_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # before size, so it wraps
	_tv_sub.position = Vector2(130, 318)
	_tv_sub.size = Vector2(200, 26)
	_tv_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv_sub.add_theme_font_size_override("font_size", 8)
	_tv_sub.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	_tv_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_tv_sub.add_theme_constant_override("shadow_offset_x", 1)
	_tv_sub.add_theme_constant_override("shadow_offset_y", 1)
	_tv_sub.z_index = 800
	add_child(_tv_sub)
	add_hotspot({
		"name": "TV",
		"pos": Vector2(230, 296),
		"size": Vector2(104, 84),
		"look": [
			"Wood-paneled. The wood is a sticker. The panel is also, somehow, a sticker.",
			"It only gets one channel, and the channel is wrong.",
		],
		"touch": _touch_tv,
		"visual": stand,
		"interact": Vector2(304, 334),
	})
	# Ultra Cube 64 on the stand's shelf
	add_hotspot({
		"name": "Ultra Cube 64",
		"pos": Vector2(230, 340),
		"size": Vector2(56, 26),
		"look": "The cartridge slot is breathing.",
		"touch": func(): say("I pressed the power button. The button and I both understood nothing would happen."),
		"use_item": _use_on_cube,
		"interact": Vector2(304, 334),
	})


func _build_couch() -> void:
	var couch := add_prop(AssetLib.get_or_build("living_couch", _build_couch_tex), Vector2(330, 240))
	_cg = CouchGuy.new()
	_cg.position = Vector2(328, 268)
	_cg.z_index = 272  # in front of the couch back, behind the front lip line
	add_child(_cg)
	add_hotspot({
		"name": "Couch Guy",
		"pos": Vector2(328, 232),
		"size": Vector2(84, 84),
		"look": "He's been sitting here long enough that the couch has started sitting on him.",
		"touch": func(): say("Don't. He's load-bearing."),
		"on_talk": func(): DialogueManager.start("couch_guy", "fed_start" if GameState.get_flag("couch_fed") else "start"),
		"use_item": _use_on_couch_guy,
		"visual": couch,
		"interact": Vector2(300, 300),
	})
	# The lever, on the wall behind the couch. Barely visible. That's the point.
	_lever_sprite = Sprite2D.new()
	_lever_sprite.texture = AssetLib.get_or_build("living_lever", _build_lever_tex)
	_lever_sprite.position = Vector2(404, 172)
	_lever_sprite.z_index = -400
	bg.add_child(_lever_sprite)
	add_hotspot({
		"name": "Lever",
		"pos": Vector2(404, 172),
		"size": Vector2(26, 34),
		"look": "A lever on the wall behind him. Levers are never decorative.",
		"touch": _touch_lever,
		"visual": _lever_sprite,
		"interact": Vector2(390, 288),
	})


func _build_furniture() -> void:
	# side table + HIS empty ramune bottle
	var table := add_prop(AssetLib.get_or_build("living_table", _build_table_tex), Vector2(448, 258))
	add_hotspot({
		"name": "Empty Ramune Bottle",
		"pos": Vector2(448, 240),
		"size": Vector2(30, 34),
		"look": "Empty. The marble rattles around in there like a memory with no story attached.",
		"touch": func(): say("It's his. The bottle and I agreed I should put it down."),
		"visual": table,
		"interact": Vector2(448, 290),
	})
	# lamp, right side
	var lamp := add_prop(AssetLib.get_or_build("living_lamp", _build_lamp_tex), Vector2(508, 236))
	add_hotspot({
		"name": "Lamp",
		"pos": Vector2(508, 226),
		"size": Vector2(34, 70),
		"look": "It's on. The TV is brighter. The lamp knows.",
		"touch": func(): say("I'm not turning it off. It's the only thing in here still trying."),
		"visual": lamp,
		"interact": Vector2(508, 288),
	})


func _build_fan() -> void:
	_fan = CeilingFan.new()
	_fan.position = Vector2(320, 52)
	_fan.z_index = -350
	add_child(_fan)
	add_hotspot({
		"name": "Ceiling Fan",
		"pos": Vector2(320, 52),
		"size": Vector2(110, 40),
		"look": "It's set to a speed that isn't on the switch. The room's one athlete.",
		"touch": func(): say("No. My arm stays down here with the rest of me."),
		"walk_required": false,
	})


func _build_timers() -> void:
	_bark_timer = Timer.new()
	_bark_timer.one_shot = true
	_bark_timer.timeout.connect(_do_bark)
	add_child(_bark_timer)
	_bark_timer.start(randf_range(4.0, 8.0))
	_tv_fx_timer = Timer.new()
	_tv_fx_timer.one_shot = true
	_tv_fx_timer.timeout.connect(_do_tv_fx)
	add_child(_tv_fx_timer)
	_tv_fx_timer.start(2.0)


# ---------------------------------------------------------------- TV

func _touch_tv() -> void:
	AudioBus.play_sfx("static_burst", randf_range(0.8, 1.3), -8.0)
	if _tv.mode == "static":
		_tv.set_mode("show")
		say("Channel F. The only channel. F for- it doesn't say.")
	else:
		_tv.reroll_moment()
	_set_subtitle(SUBTITLES.pick_random())


func _set_subtitle(text: String) -> void:
	_tv_sub.text = text
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(func():
		if _tv_sub.text == text:
			_tv_sub.text = "")


func _do_tv_fx() -> void:
	# The show's audio personality: laugh bursts, garble, the occasional
	# reversed-feeling sweep. Only while channel F is on and nothing blocks it.
	if _tv.mode == "show" and not DialogueManager.active and not SceneRouter.has_overlay() and not _cutscene:
		var roll := randf()
		if roll < 0.35:
			AudioBus.play_sfx("laugh_track", randf_range(0.85, 1.15), -10.0)
		elif roll < 0.7:
			AudioBus.play_sfx("static_burst", randf_range(0.6, 1.6), -14.0)
			_set_subtitle(SUBTITLES.pick_random())
		else:
			AudioBus.play_sfx("blip", randf_range(0.4, 0.7), -12.0)  # audio, reversed-ish
		_tv.reroll_moment()
	_tv_fx_timer.start(randf_range(2.0, 5.0))


# ---------------------------------------------------------------- Couch Guy

func _do_bark() -> void:
	if _tv.mode == "show" and not DialogueManager.active \
		and not SceneRouter.has_overlay() and not _cutscene \
		and not GameState.get_flag("couch_fed"):
		UILayer.bubble(_cg, BARKS.pick_random(), 0.5)
	_bark_timer.start(randf_range(8.0, 15.0))


func _use_on_couch_guy(item_id: String) -> bool:
	match item_id:
		"sandwich", "good_sandwich", "great_sandwich":
			_deliver_sandwich(item_id)
			return true
		"cold_cheese_slice":
			say("He wants the full arc, not a cameo.")
			return true
		"bread", "toast":
			say("That's an ingredient. He ordered a story.")
			return true
		"mystery_meat", "sliced_meat":
			say("Alone? No. It needs a bread alibi.")
			return true
	return false


func _deliver_sandwich(item_id: String) -> void:
	_cutscene = true
	GameState.lock_input()
	Inventory.remove_item(item_id)
	dorko.face_towards(_cg.global_position)
	_cg.drinking_enabled = false
	await get_tree().create_timer(0.5).timeout
	# He turns his head. First time. The room notices.
	_cg.set_pose("turned")
	AudioBus.play_sfx("swoosh", 0.7, -10.0)
	await get_tree().create_timer(1.6).timeout
	_cg.set_pose("bite")
	AudioBus.play_sfx("puff", 0.75)
	await get_tree().create_timer(0.9).timeout
	var lines := []
	var toasted := GameState.get_flag("sandwich_toasted")
	match item_id:
		"great_sandwich":
			lines.append(["Couch Guy", "...Thank you, Will. That was the whole episode."])
		"good_sandwich":
			lines.append(["Couch Guy", "...Thank you, Will. There's cheese in it. There's- thank you."])
		_:
			lines.append(["Couch Guy", "...Thank you, Will."])
	if toasted:
		lines.append(["Couch Guy", "It crunched. Hahaha. Ha."])
	DialogueManager.say_seq(lines)
	await DialogueManager.dialogue_finished
	# Without looking, he reaches behind the couch and cranks the lever.
	_cg.set_pose("idle")
	await get_tree().create_timer(0.6).timeout
	AudioBus.play_sfx("click", 0.6)
	var tw := create_tween()
	tw.tween_property(_lever_sprite, "rotation", 0.9, 0.25).set_trans(Tween.TRANS_BACK)
	await tw.finished
	GameState.set_flag("couch_fed")
	_open_trapdoor_visual()
	AudioBus.play_sfx("trapdoor")
	Fx.shake(0.3, 5.0)
	# Dorko's "!" - then the floor files its paperwork.
	UILayer.float_text(dorko.global_position + Vector2(-6, -84), "!", Color(1.0, 0.9, 0.2))
	await get_tree().create_timer(1.0).timeout
	await _fall_through()


func _touch_lever() -> void:
	if GameState.get_flag("couch_fed"):
		say("It did its one thing. Respect.")
	else:
		say("It's behind him. I'd have to reach over. I'm not reaching over.")


func _touch_rug() -> void:
	if GameState.get_flag("couch_fed"):
		_jump_down()
	else:
		say("It's fastened down at the corners. Someone really wanted this rug to stay a rug.")


func _open_trapdoor_visual() -> void:
	_rug_sprite.texture = AssetLib.get_or_build("living_rug_open", _build_rug_open_tex)
	_rug_hs.hotspot_name = "Open Trapdoor"
	_rug_hs.look = "The rug was a lid. The draft has opinions about my hair."


func _jump_down() -> void:
	_cutscene = true
	GameState.lock_input()
	await get_tree().create_timer(0.2).timeout
	await _fall_through()


## Shared falling beat: Dorko tumbles into the rug hole, afro first.
func _fall_through() -> void:
	dorko.control_enabled = false
	AudioBus.play_sfx("fall_whistle")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dorko, "position", Vector2(365, 306), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(dorko, "rotation", TAU * 1.5, 0.9)
	tw.tween_property(dorko, "scale", Vector2(0.1, 0.1), 0.9).set_ease(Tween.EASE_IN)
	await tw.finished
	AudioBus.play_sfx("poof")
	dorko.visible = false
	await get_tree().create_timer(0.4).timeout
	GameState.unlock_input()
	_cutscene = false
	SceneRouter.goto_room("basement")


func _use_on_cube(item_id: String) -> bool:
	if item_id == "perfect_pizza_roll":
		say("No. I respect it too much.")
		return true
	return false


# ---------------------------------------------------------------- textures

func _build_wall_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 98, 2)
	var mustard := Color(0.78, 0.62, 0.18)
	for y in 98:
		var f := lerpf(1.05, 0.88, float(y) / 97.0)
		p.hline(0, y, 320, Color(mustard.r * f, mustard.g * f, mustard.b * f))
	# wainscoting line + hanging frames of nothing in particular
	p.hline(0, 62, 320, Color(0.55, 0.42, 0.1))
	p.hline(0, 63, 320, Color(0.9, 0.76, 0.3))
	p.rect_outline(96, 22, 18, 14, Color(0.45, 0.28, 0.12))
	p.rect(98, 24, 14, 10, Color(0.62, 0.72, 0.6))
	p.ellipse(105, 29, 4, 2.5, Color(0.4, 0.5, 0.42))  # a painting of a lake, or a smudge
	p.rect_outline(226, 18, 12, 16, Color(0.45, 0.28, 0.12))
	p.rect(228, 20, 8, 12, Color(0.85, 0.8, 0.7))
	p.vline(232, 22, 8, Color(0.5, 0.45, 0.4))         # a portrait of a line
	# doorway openings (dark), left and right
	p.rect(3, 24, 34, 74, Color(0.16, 0.1, 0.05))
	p.rect(5, 26, 30, 72, Color(0.24, 0.15, 0.08))
	p.rect_outline(2, 23, 36, 75, Color(0.5, 0.36, 0.14))
	p.rect(283, 24, 34, 74, Color(0.14, 0.16, 0.12))
	p.rect(285, 26, 30, 72, Color(0.5, 0.62, 0.5))     # kitchen light spills out
	p.rect_outline(282, 23, 36, 75, Color(0.5, 0.36, 0.14))
	# baseboard
	p.rect(0, 92, 320, 6, Color(0.5, 0.36, 0.14))
	p.hline(0, 92, 320, Color(0.68, 0.52, 0.22))
	p.speckle(0, 0, 320, 92, Color(0.62, 0.48, 0.12), 0.012, 17)
	return p.tex()


func _build_rug_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(64, 24, 2)
	# slightly wrong color for this room; the rug is new here and lying about it
	p.ellipse(32, 12, 30, 10, Color(0.62, 0.3, 0.24))
	p.ellipse_outline(32, 12, 30, 10, Color(0.4, 0.18, 0.14))
	p.ellipse_outline(32, 12, 24, 7.5, Color(0.78, 0.5, 0.3))
	p.ellipse_outline(32, 12, 17, 5, Color(0.4, 0.18, 0.14))
	p.dot(20, 10, Color(0.85, 0.7, 0.4))
	p.dot(44, 14, Color(0.85, 0.7, 0.4))
	p.dot(32, 8, Color(0.85, 0.7, 0.4))
	return p.tex()


func _build_rug_open_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(64, 24, 2)
	# trapdoor thrown open: black hole + the rug-lid flipped up behind it
	p.ellipse(32, 13, 28, 9, Color(0.03, 0.02, 0.04))
	p.ellipse_outline(32, 13, 28, 9, Color(0.25, 0.12, 0.08))
	p.ellipse(32, 15, 20, 5, Color(0.0, 0.0, 0.0))
	p.poly(PackedVector2Array([
		Vector2(6, 12), Vector2(58, 12), Vector2(50, 2), Vector2(14, 2),
	]), Color(0.5, 0.24, 0.2))
	p.hline(14, 2, 36, Color(0.7, 0.44, 0.28))
	p.dot(30, 6, Color(0.85, 0.7, 0.4))
	return p.tex()


func _build_stand_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(56, 44, 2)
	# wood stand
	p.rect(2, 26, 52, 16, Color(0.42, 0.26, 0.12))
	p.rect_outline(2, 26, 52, 16, Color(0.25, 0.14, 0.06))
	p.hline(2, 26, 52, Color(0.58, 0.38, 0.18))
	for i in 5:
		p.vline(6 + i * 11, 28, 12, Color(0.35, 0.2, 0.09))
	# Ultra Cube 64 on the shelf: grey trapezoid, four ports, a slot that breathes
	p.poly(PackedVector2Array([
		Vector2(14, 40), Vector2(42, 40), Vector2(38, 32), Vector2(18, 32),
	]), Color(0.55, 0.55, 0.6))
	p.hline(18, 32, 20, Color(0.7, 0.7, 0.75))
	p.hline(21, 34, 14, Color(0.3, 0.3, 0.35))  # the slot
	p.dot(20, 38, Color(0.9, 0.2, 0.2))
	p.dot(25, 38, Color(0.95, 0.85, 0.2))
	p.dot(30, 38, Color(0.2, 0.7, 0.3))
	p.dot(35, 38, Color(0.25, 0.4, 0.9))
	# CRT above (the screen itself is the TvScreen node)
	p.rect(0, 0, 56, 26, Color(0.4, 0.26, 0.13))
	p.rect_outline(0, 0, 56, 26, Color(0.22, 0.13, 0.06))
	p.rect(3, 3, 44, 20, Color(0.05, 0.05, 0.07))
	p.rect(48, 4, 6, 18, Color(0.3, 0.2, 0.1))
	p.dot(51, 7, Color(0.9, 0.3, 0.2))
	p.dot(51, 11, Color(0.5, 0.5, 0.55))
	p.dot(51, 15, Color(0.5, 0.5, 0.55))
	return p.tex()


func _build_couch_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(88, 44, 2)
	var base := Color(0.5, 0.34, 0.2)
	var dark := Color(0.36, 0.23, 0.13)
	var bloom := Color(0.72, 0.5, 0.3)
	# back + arms + seat
	p.rect(4, 4, 80, 22, base)
	p.ellipse(8, 22, 7, 14, base)
	p.ellipse(80, 22, 7, 14, base)
	p.rect(6, 24, 76, 14, dark)
	p.hline(6, 24, 76, base)
	p.rect(2, 36, 84, 6, dark)
	# floral pattern: little blooms that used to be a print
	for f in [[14, 10], [30, 14], [48, 9], [64, 13], [76, 8], [22, 20], [56, 19], [70, 21]]:
		p.dot(f[0], f[1], bloom)
		p.dot(f[0] - 1, f[1], Color(0.62, 0.42, 0.24))
		p.dot(f[0] + 1, f[1], Color(0.62, 0.42, 0.24))
		p.dot(f[0], f[1] - 1, Color(0.62, 0.42, 0.24))
	# the permanent depression where he sits
	p.ellipse(44, 24, 17, 6, Color(0.3, 0.19, 0.1))
	return p.tex()


func _build_lever_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(13, 17, 2)
	p.rect(4, 12, 5, 4, Color(0.4, 0.4, 0.45))
	p.rect_outline(4, 12, 5, 4, Color(0.2, 0.2, 0.25))
	p.line(6, 12, 10, 3, Color(0.55, 0.55, 0.6))
	p.circle(10, 3, 1.8, Color(0.85, 0.25, 0.2))
	p.dot(9, 2, Color(1.0, 0.55, 0.5))
	return p.tex()


func _build_table_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 34, 2)
	p.ellipse(15, 12, 13, 4, Color(0.5, 0.32, 0.16))
	p.ellipse_outline(15, 12, 13, 4, Color(0.32, 0.19, 0.09))
	p.rect(13, 15, 4, 17, Color(0.42, 0.26, 0.12))
	p.ellipse(15, 32, 7, 2, Color(0.35, 0.21, 0.1))
	# the empty ramune bottle on top
	p.rect(12, 2, 4, 8, Color(0.55, 0.75, 0.95, 0.85))
	p.rect(13, 0, 2, 2, Color(0.7, 0.85, 1.0))
	p.dot(13, 7, Color(0.9, 0.95, 1.0))
	return p.tex()


func _build_lamp_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(24, 42, 2)
	p.poly(PackedVector2Array([
		Vector2(4, 2), Vector2(20, 2), Vector2(17, 12), Vector2(7, 12),
	]), Color(0.92, 0.8, 0.5))
	p.hline(7, 12, 10, Color(0.7, 0.58, 0.3))
	p.rect(11, 12, 2, 24, Color(0.35, 0.3, 0.28))
	p.ellipse(12, 38, 7, 2.5, Color(0.3, 0.26, 0.24))
	p.ellipse(12, 8, 10, 6, Color(1.0, 0.95, 0.7, 0.12))
	return p.tex()


# ---------------------------------------------------------------- inner classes

class TvScreen extends Node2D:
	## The screen of the CRT. Static by default; "channel F" is a procedurally
	## glitched sitcom that never resolves into an actual show. The root draws
	## the screen rectangle and CLIPS a child canvas to it, so zoomed glitch
	## moments can never spill outside the CRT's bounds.
	const W := 44.0 * 2.0
	const H := 20.0 * 2.0

	var mode := "static"
	var _frame := 0
	var _timer := 0.0
	var _hold := 0.1
	# per-moment show state (read by the child canvas)
	var _zoom := 1.0
	var _zoom_at := Vector2(44, 20)
	var _invert := false
	var _pose := 0
	var _rng := RandomNumberGenerator.new()
	var _canvas: Node2D

	func _ready() -> void:
		_rng.seed = 929
		clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_canvas = TvCanvas.new()
		_canvas.screen = self
		add_child(_canvas)

	func set_mode(m: String) -> void:
		mode = m
		reroll_moment()

	func reroll_moment() -> void:
		_zoom = [1.0, 1.0, 1.6, 2.4, 3.4][_rng.randi_range(0, 4)]
		_zoom_at = Vector2(_rng.randf_range(20, 68), _rng.randf_range(8, 26))
		_invert = _rng.randf() < 0.18
		_pose = _rng.randi_range(0, 3)
		if _canvas:
			_canvas.queue_redraw()

	func _process(delta: float) -> void:
		_timer += delta
		if _timer >= _hold:
			_timer = 0.0
			_frame += 1
			if mode == "static":
				_hold = 0.08
			else:
				# stutter: some frames hold, some jump-cut instantly
				_hold = [0.1, 0.14, 0.05, 0.3, 0.5][_rng.randi_range(0, 4)]
				if _rng.randf() < 0.4:
					reroll_moment()
			if _canvas:
				_canvas.queue_redraw()

	func _draw() -> void:
		# this rect IS the clip region for everything the canvas draws
		draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.03))


class TvCanvas extends Node2D:
	## All actual TV imagery. Clipped by the parent TvScreen's rect.
	var screen  # TvScreen

	func _draw() -> void:
		var w: float = TvScreen.W
		var h: float = TvScreen.H
		if screen.mode == "static":
			_draw_static(w, h)
		else:
			_draw_show(w, h)
		# scanlines + glass sheen over everything
		for y in range(0, int(h), 4):
			draw_rect(Rect2(0, y, w, 1), Color(0, 0, 0, 0.18))
		draw_rect(Rect2(4, 2, 14, 6), Color(1, 1, 1, 0.06))

	func _draw_static(w: float, h: float) -> void:
		var r := RandomNumberGenerator.new()
		r.seed = screen._frame  # new noise every frame, deterministic per frame
		for i in 260:
			var v := r.randf()
			draw_rect(Rect2(r.randf_range(0, w - 3), r.randf_range(0, h - 2), 3, 2), Color(v, v, v, 0.9))
		if r.randf() < 0.12:  # occasional color bars
			var bars := [Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.2), Color(0.2, 0.9, 0.9),
				Color(0.2, 0.9, 0.2), Color(0.9, 0.2, 0.9), Color(0.9, 0.2, 0.2), Color(0.2, 0.2, 0.9)]
			for b in bars.size():
				draw_rect(Rect2(b * w / 7.0, 0, w / 7.0, h), bars[b])

	func _draw_show(w: float, h: float) -> void:
		# zoomed drawing: place the focus point at screen center, scaled;
		# overspill is clipped by the parent, so any zoom stays in the tube
		draw_set_transform(Vector2(w / 2, h / 2) - screen._zoom_at * screen._zoom, 0.0, Vector2(screen._zoom, screen._zoom))
		var wall := Color(0.75, 0.6, 0.45)
		var floor_c := Color(0.5, 0.35, 0.22)
		if screen._invert:
			wall = wall.inverted()
			floor_c = floor_c.inverted()
		draw_rect(Rect2(0, 0, 88, 26), wall)
		draw_rect(Rect2(0, 26, 88, 14), floor_c)
		# their window (a show about people who also have a window)
		draw_rect(Rect2(8, 5, 14, 12), Color(0.55, 0.75, 0.95) if not screen._invert else Color(0.45, 0.25, 0.05))
		draw_rect(Rect2(8, 5, 14, 2), Color(0.4, 0.28, 0.16))
		# their couch (a show about people who also have a couch)
		draw_rect(Rect2(30, 18, 30, 10), Color(0.35, 0.45, 0.65) if not screen._invert else Color(0.65, 0.55, 0.35))
		# two silhouette actors, poses jump around per moment
		var actor := Color(0.1, 0.08, 0.1)
		match screen._pose:
			0:
				_actor(Vector2(38, 12), actor)
				_actor(Vector2(52, 12), actor)
			1:
				_actor(Vector2(36, 10), actor)
				_actor(Vector2(37, 10), actor)  # standing inside each other. sitcom physics.
			2:
				_actor(Vector2(48, 6), actor)
				_actor(Vector2(70, 16), actor)
			_:
				_actor(Vector2(24, 12), actor)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if screen._invert:
			draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.06))

	func _actor(at: Vector2, c: Color) -> void:
		draw_circle(at, 3.0, c)
		draw_rect(Rect2(at.x - 2.5, at.y + 2, 5, 9), c)


class CeilingFan extends Node2D:
	## Spins at a speed the switch does not offer.
	var _blades: Node2D

	func _ready() -> void:
		var mount := Polygon2D.new()
		mount.polygon = PackedVector2Array([Vector2(-2, -20), Vector2(2, -20), Vector2(2, 0), Vector2(-2, 0)])
		mount.color = Color(0.3, 0.22, 0.1)
		add_child(mount)
		_blades = Node2D.new()
		add_child(_blades)
		for i in 4:
			var blade := Polygon2D.new()
			blade.polygon = PackedVector2Array([
				Vector2(4, -2), Vector2(46, -5), Vector2(46, 5), Vector2(4, 2),
			])
			blade.color = Color(0.55, 0.4, 0.2)
			blade.rotation = TAU * float(i) / 4.0
			_blades.add_child(blade)
		var hub := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 10:
			var a := TAU * float(i) / 10.0
			pts.append(Vector2(cos(a), sin(a)) * 5.0)
		hub.polygon = pts
		hub.color = Color(0.4, 0.3, 0.14)
		add_child(hub)
		# motion smear so the speed reads even in a still frame
		var smear := Polygon2D.new()
		var spts := PackedVector2Array()
		for i in 20:
			var a := TAU * float(i) / 20.0
			spts.append(Vector2(cos(a) * 47.0, sin(a) * 12.0))
		smear.polygon = spts
		smear.color = Color(0.55, 0.42, 0.22, 0.16)
		add_child(smear)
		move_child(smear, 1)

	func _process(delta: float) -> void:
		_blades.rotation += 19.0 * delta  # three switch settings past "high"
		_blades.scale.y = 0.32            # seen from below-ish, squashed
