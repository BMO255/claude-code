extends BaseRoom
## The Orange Room — where Dorko wakes up. Three shades of orange that almost
## match, a bulb on a cord, a door that wants a number, and a window that is
## a painting of a window. Spec 7.1.

var _door_hs: Hotspot = null
var _door_sprite: Sprite2D = null
var _poster_sprite: Sprite2D = null
var _basket_sprite: Sprite2D = null
var _basket_hs: Hotspot = null
var _fridge_hs: Hotspot = null
var _stain_added := false


func _room_config() -> void:
	room_id = "orange_room"
	music_name = "orange"
	footstep_surface = "carpet"
	horizon_y = 195.0
	back_half = 175.0
	front_half = 345.0
	spawn_points = {
		"default": {"pos": Vector2(320, 290), "dir": "down"},
		"from_living": {"pos": Vector2(575, 296), "dir": "left"},
	}


func _room_setup() -> void:
	_build_walls()
	add_floor("checker", Color(0.45, 0.29, 0.17), Color(0.38, 0.24, 0.14), 0.9)
	_build_bulb()
	_build_props_and_hotspots()
	GameState.flag_changed.connect(_on_flag_changed)
	if GameState.get_flag("pizza_exploded"):
		_add_pizza_stain()


func _on_room_entered() -> void:
	if GameState.get_flag("intro_done"):
		return
	# Opening beat: Dorko is on the carpet. Rotating the whole node about his
	# feet reads as "lying down"; the shadow goes sideways with him, so hide it.
	GameState.lock_input()
	dorko.rotation = -PI / 2.0
	dorko.shadow.visible = false
	await get_tree().create_timer(1.0).timeout
	# Sit up: small overshoot past vertical, then settle. Total ~0.45s, so the
	# whole locked stretch stays under 1.5s; the line after it is advanceable.
	var tw := create_tween()
	tw.tween_property(dorko, "rotation", 0.09, 0.32).set_ease(Tween.EASE_OUT)
	tw.tween_property(dorko, "rotation", 0.0, 0.13)
	await tw.finished
	dorko.shadow.visible = true
	GameState.unlock_input()
	say("...I was supposed to be somewhere.")
	GameState.set_flag("intro_done")


# ---------------------------------------------------------------- construction

func _build_walls() -> void:
	# Back wall (three painted panels) parallaxes; poster + window ride on it.
	var wallc := Node2D.new()
	wallc.name = "BackWall"
	bg.add_child(wallc)
	add_parallax(wallc, 1.0)
	var wall := Sprite2D.new()
	wall.texture = AssetLib.get_or_build("orange_wall", _build_wall_tex)
	wall.centered = false
	wallc.add_child(wall)
	_poster_sprite = Sprite2D.new()
	_poster_sprite.texture = AssetLib.get_or_build("orange_poster", _build_poster_tex)
	_poster_sprite.position = Vector2(250, 110)
	wallc.add_child(_poster_sprite)
	var window := Sprite2D.new()
	window.name = "Window"
	window.texture = AssetLib.get_or_build("orange_window", _build_window_tex)
	window.position = Vector2(390, 102)
	wallc.add_child(window)
	# Side walls: static triangles below the horizon flanking the floor. The
	# floor sprite (z -500 inside bg) draws over their inner overlap, so they
	# can be generous. Darker shades sell the turn of the corner.
	add_poly(PackedVector2Array([
		Vector2(0, 195), Vector2(148, 195), Vector2(0, 340),
	]), Color(0.55, 0.24, 0.08), -700)
	add_poly(PackedVector2Array([
		Vector2(492, 195), Vector2(640, 195), Vector2(640, 340),
	]), Color(0.78, 0.5, 0.3), -700)
	# The keypad door lives on the right wall; perspective is baked into the
	# texture (both door edges converge on the corner at (495,195)).
	_door_sprite = Sprite2D.new()
	_door_sprite.centered = false
	_door_sprite.position = Vector2(548, 116)
	bg.add_child(_door_sprite)
	_update_door()


func _build_bulb() -> void:
	# One bare bulb on a cord. SwingBulb (inner class) drives a slow pendulum
	# from two incommensurate sines so it never quite repeats.
	var pend := SwingBulb.new()
	pend.name = "Bulb"
	pend.position = Vector2(328, -6)  # pivot just above the screen top
	pend.z_index = -40                # over floor/wall, behind props and Dorko
	add_child(pend)
	var cone := Polygon2D.new()
	cone.polygon = PackedVector2Array([
		Vector2(0, 118), Vector2(66, 244), Vector2(-66, 244),
	])
	cone.color = Color(1.0, 0.96, 0.72, 0.05)
	pend.add_child(cone)
	var cone2 := Polygon2D.new()
	cone2.polygon = PackedVector2Array([
		Vector2(0, 118), Vector2(40, 244), Vector2(-40, 244),
	])
	cone2.color = Color(1.0, 0.97, 0.78, 0.04)
	pend.add_child(cone2)
	var cord := Polygon2D.new()
	cord.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0), Vector2(1, 94), Vector2(-1, 94),
	])
	cord.color = Color(0.24, 0.19, 0.14)
	pend.add_child(cord)
	var glow := Sprite2D.new()
	glow.texture = AssetLib.get_or_build("orange_bulb_glow", _build_glow_tex)
	glow.position = Vector2(0, 112)
	pend.add_child(glow)
	var bulb := Sprite2D.new()
	bulb.texture = AssetLib.get_or_build("orange_bulb", _build_bulb_tex)
	bulb.position = Vector2(0, 112)
	pend.add_child(bulb)


func _build_props_and_hotspots() -> void:
	# --- desk + beige CRT PC (back-left)
	var desk := add_prop(AssetLib.get_or_build("orange_desk_pc", _build_desk_tex), Vector2(150, 175))
	add_hotspot({
		"name": "PC",
		"pos": Vector2(150, 180),
		"size": Vector2(150, 110),
		"look": "All that noise is the fan. The computer part of the computer is mostly a rumor.",
		"touch": _touch_pc,
		"visual": desk,
		"interact": Vector2(150, 244),
	})

	# --- mini-fridge (back-right of center) with pizza rolls on top
	var fridge := add_prop(AssetLib.get_or_build("orange_fridge", _build_fridge_tex), Vector2(468, 186))
	_fridge_hs = add_hotspot({
		"name": "Mini-Fridge",
		"pos": Vector2(468, 192),
		"size": Vector2(72, 92),
		"look": "It hums a note that isn't on a piano.",
		"touch": _touch_fridge,
		"visual": fridge,
		"interact": Vector2(468, 250),
	})
	var box := add_prop(AssetLib.get_or_build("orange_pizza_box", _build_pizza_box_tex), Vector2(462, 128))
	add_hotspot({
		"name": "Pizza Rolls",
		"pos": Vector2(462, 128),
		"size": Vector2(44, 28),
		"look": "FUN IN EVERY BITE, says the box. That reads like a legal document.",
		"touch": _touch_pizza_box,
		"visual": box,
		"interact": Vector2(468, 250),
	})

	# --- poster of the smiling sun
	add_hotspot({
		"name": "Sun Poster",
		"pos": Vector2(250, 110),
		"size": Vector2(84, 108),
		"look": [
			"That sun has thirty-two teeth. A full adult set. On a sun.",
			"It's smiling at everyone in the room. It's just me. It's smiling at me.",
		],
		"touch": _touch_poster,
		"visual": _poster_sprite,
		"interact": Vector2(250, 216),
	})

	# --- painted-on window
	add_hotspot({
		"name": "Window",
		"pos": Vector2(390, 102),
		"size": Vector2(76, 70),
		"look": "It's painted on. Someone painted a better day on it.",
		"touch": _touch_window,
		"interact": Vector2(390, 216),
	})

	# --- wastebasket
	_basket_sprite = add_prop(AssetLib.get_or_build("orange_basket_full", _build_basket_full_tex), Vector2(218, 246))
	_basket_hs = add_hotspot({
		"name": "Wastebasket",
		"pos": Vector2(218, 248),
		"size": Vector2(46, 52),
		"on_look": _look_basket,
		"touch": _touch_basket,
		"visual": _basket_sprite,
		"interact": Vector2(218, 282),
	})

	# --- the keypad door (right wall). Same hotspot becomes the exit once open.
	_door_hs = add_hotspot({
		"name": "Keypad Door",
		"pos": Vector2(592, 220),
		"size": Vector2(92, 204),
		"on_look": _look_door,
		"touch": _touch_door,
		"visual": _door_sprite,
		"interact": Vector2(578, 302),
	})
	_update_door()


# ---------------------------------------------------------------- interactions

func _touch_pc() -> void:
	var path := "res://scripts/minigames/pc_desktop.gd"
	if ResourceLoader.exists(path):
		SceneRouter.push_overlay(load(path).new())
	else:
		say("It's booting. It's been booting. We respect the process.")


func _touch_pizza_box() -> void:
	if GameState.get_flag("pizza_win"):
		say("No. I made the perfect one already. You don't chase a feeling like that twice.")
		return
	var path := "res://scripts/minigames/pizza_roll.gd"
	if ResourceLoader.exists(path):
		SceneRouter.push_overlay(load(path).new())
	else:
		say("The box wants an oven. Everything in this house is a journey.")


func _touch_fridge() -> void:
	if GameState.get_flag("orange_fridge_taken"):
		say([
			"Empty. It hums anyway. Professional.",
			"Just the little light in there now. It comes on for nobody.",
		])
		return
	AudioBus.play_sfx("clink")
	if Inventory.add_item("cold_cheese_slice"):
		UILayer.fly_item("cold_cheese_slice", _fridge_hs.global_position)
		# Flag only on a successful add, so a full inventory doesn't burn the
		# one cheese this room will ever give.
		GameState.set_flag("orange_fridge_taken")
		say("One slice of cheese, colder than the fridge around it. It's showing off.")


func _touch_poster() -> void:
	if not GameState.get_flag("saw_note"):
		AudioBus.play_sfx("thwip")
		_poster_sprite.texture = AssetLib.get_or_build("orange_poster_peeled", _build_poster_peeled_tex)
		var tw := create_tween()
		tw.tween_property(_poster_sprite, "rotation", 0.05, 0.1)
		tw.tween_property(_poster_sprite, "rotation", -0.02, 0.12)
		tw.tween_property(_poster_sprite, "rotation", 0.0, 0.1)
		GameState.set_flag("saw_note")
	SceneRouter.push_overlay(NoteCloseup.new())


func _touch_window() -> void:
	say("I checked for a latch. The latch is also paint. Thorough.")


func _look_basket() -> void:
	if GameState.get_flag("orange_card_taken"):
		say("A wastebasket. Retired. It gave everything it had, which was one thing.")
	else:
		say("A wastebasket. The only honest container in this house. Something pink in there.")


func _touch_basket() -> void:
	if GameState.get_flag("orange_card_taken"):
		say("Nothing else in there. Even the garbage moved on.")
		return
	if Inventory.add_item("crumpled_card"):
		UILayer.fly_item("crumpled_card", _basket_hs.global_position)
		GameState.set_flag("orange_card_taken")
		_basket_sprite.texture = AssetLib.get_or_build("orange_basket_empty", _build_basket_empty_tex)
		say("A birthday card. Crumpled with intent. I'm un-crumpling the intent.")


func _look_door() -> void:
	if GameState.get_flag("room1_door_open"):
		say("Open. The living room's through there, acting like it was there the whole time.")
	else:
		say("Locked, with a keypad. The door thinks we should get to know each other first.")


func _touch_door() -> void:
	if GameState.get_flag("room1_door_open"):
		AudioBus.play_sfx("door_open")
		SceneRouter.goto_room("living_room", "from_orange")
	else:
		SceneRouter.push_overlay(load("res://scripts/minigames/keypad.gd").new())


func _on_flag_changed(flag_name: String, value: bool) -> void:
	if not value:
		return
	if flag_name == "room1_door_open":
		_update_door()
	elif flag_name == "pizza_exploded":
		_add_pizza_stain()


func _update_door() -> void:
	var open := GameState.get_flag("room1_door_open")
	if _door_sprite != null:
		if open:
			_door_sprite.texture = AssetLib.get_or_build("orange_door_open", _build_door_open_tex)
		else:
			_door_sprite.texture = AssetLib.get_or_build("orange_door_locked", _build_door_locked_tex)
	if _door_hs != null:
		_door_hs.hotspot_name = "Open Door" if open else "Keypad Door"


func _add_pizza_stain() -> void:
	# Added exactly once per room instance; the flag re-firing can't stack them.
	if _stain_added:
		return
	_stain_added = true
	var s := add_prop(AssetLib.get_or_build("orange_stain", _build_stain_tex), Vector2(330, 300), -450)
	add_hotspot({
		"name": "Pizza Stain",
		"pos": Vector2(330, 300),
		"size": Vector2(88, 46),
		"look": "A commemorative grease shadow. The carpet will tell this story forever, quietly.",
		"touch": func(): say("That was the last of them."),
		"visual": s,
		"interact": Vector2(330, 322),
	})


# ---------------------------------------------------------------- textures

func _build_wall_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 98, 2)
	var burnt := Color(0.72, 0.33, 0.10)
	var tang := Color(0.93, 0.52, 0.10)
	var peach := Color(0.97, 0.68, 0.45)
	# Columns: the regions beyond vp 72 / 248 are the side walls turning away,
	# so they run darker. Between them, three paint panels that don't match.
	var sections := [
		[0, 72, burnt, 0.8],
		[72, 102, burnt, 1.0],
		[102, 215, tang, 1.0],
		[215, 248, peach, 1.0],
		[248, 320, peach, 0.8],
	]
	for y in 98:
		var row_shade := lerpf(1.04, 0.9, float(y) / 97.0)
		for s in sections:
			var c: Color = s[2]
			var f: float = s[3] * row_shade
			p.hline(s[0], y, s[1] - s[0], Color(c.r * f, c.g * f, c.b * f))
	# corner shading
	p.vline(72, 0, 98, Color(0.45, 0.2, 0.07))
	p.vline(248, 0, 98, Color(0.52, 0.26, 0.12))
	# painted panel seams; the right seam shifts one pixel partway down.
	# Nobody notices consciously. That's the point.
	var seam := Color(0.38, 0.16, 0.05)
	p.vline(102, 0, 98, seam)
	p.vline(103, 0, 98, Color(1.0, 0.66, 0.28))
	p.vline(215, 0, 64, seam)
	p.vline(216, 64, 34, seam)
	# seam screws
	p.dot(102, 6, Color(0.55, 0.3, 0.12))
	p.dot(102, 88, Color(0.55, 0.3, 0.12))
	p.dot(215, 6, Color(0.6, 0.36, 0.18))
	p.dot(216, 88, Color(0.6, 0.36, 0.18))
	# baseboard
	p.rect(0, 92, 320, 6, Color(0.33, 0.15, 0.07))
	p.hline(0, 92, 320, Color(0.55, 0.28, 0.12))
	p.hline(0, 91, 320, Color(0.42, 0.19, 0.07))
	# grime
	p.speckle(0, 0, 320, 91, Color(0.5, 0.25, 0.1), 0.012, 7)
	p.speckle(0, 0, 320, 91, Color(1.0, 0.75, 0.4), 0.006, 8)
	return p.tex()


func _build_poster_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(40, 52, 2)
	_paint_poster_base(p)
	# unpeeled: just a shy little curl at the bottom-right corner
	p.poly(PackedVector2Array([
		Vector2(36, 51), Vector2(39, 51), Vector2(39, 48),
	]), Color(0.75, 0.85, 0.98))
	return p.tex()


func _build_poster_peeled_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(40, 52, 2)
	_paint_poster_base(p)
	# corner peeled up-left: bare wall, the sticky note, and the paper-back flap
	p.poly(PackedVector2Array([
		Vector2(24, 51), Vector2(39, 51), Vector2(39, 35),
	]), Color(0.97, 0.68, 0.45))
	p.rect(29, 40, 8, 8, Color(0.99, 0.9, 0.4))
	p.rect_outline(29, 40, 8, 8, Color(0.8, 0.65, 0.2))
	p.hline(30, 43, 5, Color(0.3, 0.3, 0.5))
	p.hline(30, 45, 6, Color(0.3, 0.3, 0.5))
	p.poly(PackedVector2Array([
		Vector2(24, 51), Vector2(39, 35), Vector2(26, 38),
	]), Color(0.82, 0.86, 0.92))
	p.line(24, 51, 39, 35, Color(0.5, 0.55, 0.65))
	return p.tex()


func _paint_poster_base(p: Painter) -> void:
	p.rect(0, 0, 40, 52, Color(0.5, 0.72, 0.95))
	p.rect_outline(0, 0, 40, 52, Color(0.95, 0.95, 0.9))
	p.rect_outline(1, 1, 38, 50, Color(0.35, 0.55, 0.78))
	# the sun
	p.circle(20, 19, 11, Color(1.0, 0.84, 0.12))
	p.ellipse_outline(20, 19, 11, 11, Color(0.85, 0.6, 0.05))
	for i in 8:
		var a := TAU * float(i) / 8.0
		p.line(int(20 + cos(a) * 12.5), int(19 + sin(a) * 12.5),
			int(20 + cos(a) * 16.0), int(19 + sin(a) * 16.0), Color(1.0, 0.84, 0.12))
	p.dot(16, 15, Color(0.25, 0.12, 0.02))
	p.dot(24, 15, Color(0.25, 0.12, 0.02))
	# the mouth: two full rows of teeth, plus two that don't fit inside it
	p.ellipse(20, 24, 7.5, 4, Color(0.4, 0.15, 0.05))
	for i in 7:
		p.rect(14 + i * 2, 22, 1, 2, Color(0.98, 0.98, 0.95))
		p.rect(14 + i * 2, 26, 1, 2, Color(0.98, 0.98, 0.95))
	p.dot(12, 24, Color(0.98, 0.98, 0.95))
	p.dot(28, 24, Color(0.98, 0.98, 0.95))
	# grass and flowers having a normal day underneath
	p.rect(2, 44, 36, 6, Color(0.3, 0.75, 0.25))
	p.dot(7, 45, Color(0.95, 0.5, 0.7))
	p.dot(15, 46, Color(0.98, 0.98, 0.95))
	p.dot(25, 45, Color(0.95, 0.5, 0.7))
	p.dot(33, 46, Color(0.98, 0.98, 0.95))


func _build_window_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(36, 34, 2)
	var frame := Color(0.52, 0.3, 0.14)
	# the better day
	p.rect(3, 3, 30, 24, Color(0.3, 0.65, 0.95))
	p.hline(6, 12, 8, Color(0.55, 0.8, 1.0))    # brushstroke streaks in the sky
	p.hline(20, 6, 7, Color(0.55, 0.8, 1.0))
	p.ellipse(18, 27, 16, 6, Color(0.35, 0.75, 0.3))
	p.circle(12, 9, 3, Color(1, 1, 1))
	p.circle(16, 8, 4, Color(1, 1, 1))
	p.circle(20, 9, 3, Color(1, 1, 1))
	p.line(24, 12, 26, 14, Color(0.2, 0.2, 0.3))
	p.line(26, 14, 28, 12, Color(0.2, 0.2, 0.3))
	p.line(8, 16, 9, 17, Color(0.2, 0.2, 0.3))
	p.line(9, 17, 10, 16, Color(0.2, 0.2, 0.3))
	# crossbars + frame painted flat over the scene
	p.rect(17, 3, 2, 24, frame)
	p.rect(3, 14, 30, 2, frame)
	p.rect(0, 0, 36, 3, frame)
	p.rect(0, 27, 36, 3, frame)
	p.rect(0, 0, 3, 30, frame)
	p.rect(33, 0, 3, 30, frame)
	p.rect_outline(0, 0, 36, 30, Color(0.38, 0.2, 0.08))
	# drips: whoever painted the frame stopped caring near the end.
	p.vline(8, 30, 3, frame)
	p.vline(9, 30, 2, frame)
	p.vline(19, 30, 4, frame)
	p.vline(27, 30, 2, frame)
	p.vline(24, 30, 3, Color(0.3, 0.65, 0.95))  # one drip of sky
	return p.tex()


func _build_desk_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(75, 48, 2)
	# legs + desktop
	p.rect(4, 30, 3, 17, Color(0.4, 0.22, 0.1))
	p.rect(68, 30, 3, 17, Color(0.4, 0.22, 0.1))
	p.rect(0, 26, 75, 4, Color(0.6, 0.36, 0.18))
	p.hline(0, 26, 75, Color(0.72, 0.46, 0.24))
	p.rect(0, 30, 75, 2, Color(0.45, 0.26, 0.12))
	# tower under the desk
	p.rect(48, 33, 14, 14, Color(0.85, 0.8, 0.68))
	p.rect_outline(48, 33, 14, 14, Color(0.4, 0.36, 0.3))
	p.hline(50, 36, 10, Color(0.5, 0.48, 0.42))
	p.hline(50, 38, 10, Color(0.5, 0.48, 0.42))
	p.dot(52, 44, Color(0.3, 0.9, 0.4))
	# beige CRT
	p.rect(10, 4, 26, 22, Color(0.86, 0.81, 0.68))
	p.rect_outline(10, 4, 26, 22, Color(0.45, 0.4, 0.32))
	p.rect(13, 7, 18, 14, Color(0.06, 0.09, 0.08))
	p.hline(13, 10, 18, Color(0.1, 0.14, 0.12))
	p.hline(13, 14, 18, Color(0.1, 0.14, 0.12))
	p.line(14, 8, 17, 11, Color(0.16, 0.22, 0.2))
	p.dot(15, 18, Color(0.3, 0.9, 0.4))          # a cursor, blinking for no one
	p.rect(31, 5, 3, 3, Color(0.99, 0.9, 0.4))   # sticky note on the bezel
	# keyboard, mouse, mug
	p.rect(42, 22, 22, 4, Color(0.8, 0.76, 0.64))
	for i in 9:
		p.dot(43 + i * 2, 23, Color(0.5, 0.47, 0.4))
	p.ellipse(68, 24, 1.5, 2, Color(0.85, 0.8, 0.68))
	p.line(66, 24, 64, 23, Color(0.4, 0.38, 0.32))
	p.rect(3, 21, 5, 5, Color(0.15, 0.6, 0.55))
	p.dot(8, 23, Color(0.15, 0.6, 0.55))
	p.hline(4, 21, 3, Color(0.35, 0.2, 0.1))     # coffee, room temperature since spring
	return p.tex()


func _build_fridge_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(34, 46, 2)
	p.rect(2, 4, 30, 40, Color(0.72, 0.9, 0.83))
	p.rect_outline(2, 4, 30, 40, Color(0.3, 0.45, 0.4))
	p.hline(2, 4, 30, Color(0.85, 0.97, 0.92))
	p.hline(3, 20, 28, Color(0.4, 0.55, 0.5))
	p.rect(27, 10, 2, 6, Color(0.45, 0.5, 0.5))
	p.rect(27, 24, 2, 8, Color(0.45, 0.5, 0.5))
	p.rect(5, 44, 4, 2, Color(0.2, 0.25, 0.25))
	p.rect(25, 44, 4, 2, Color(0.2, 0.25, 0.25))
	# a drawing held up by magnets; nobody remembers drawing it
	p.rect(7, 25, 7, 8, Color(0.95, 0.95, 0.9))
	p.line(8, 28, 12, 30, Color(0.9, 0.5, 0.1))
	p.line(8, 31, 11, 27, Color(0.3, 0.6, 0.9))
	p.dot(9, 25, Color(0.9, 0.25, 0.2))
	p.dot(13, 33, Color(0.25, 0.4, 0.9))
	p.hline(4, 42, 8, Color(0.45, 0.6, 0.55))
	return p.tex()


func _build_pizza_box_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(20, 12, 2)
	p.rect(1, 3, 18, 8, Color(0.87, 0.2, 0.16))
	p.rect_outline(1, 3, 18, 8, Color(0.5, 0.08, 0.06))
	p.hline(2, 5, 16, Color(0.97, 0.82, 0.25))
	p.hline(1, 3, 18, Color(1.0, 0.5, 0.4))
	p.ellipse(7, 8, 3, 2, Color(0.98, 0.95, 0.9))
	p.dot(7, 8, Color(0.85, 0.6, 0.3))
	p.dot(14, 6, Color(1, 0.95, 0.4))
	p.dot(16, 8, Color(1, 0.95, 0.4))
	p.dot(14, 9, Color(1, 0.95, 0.4))
	return p.tex()


func _build_basket_full_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(20, 22, 2)
	_paint_basket(p)
	# the pink one is the card. the white one is a decoy.
	p.circle(8, 4, 2.2, Color(0.95, 0.68, 0.8))
	p.line(7, 3, 9, 5, Color(0.75, 0.45, 0.55))
	p.circle(13, 4, 1.7, Color(0.93, 0.93, 0.88))
	p.dot(13, 4, Color(0.7, 0.7, 0.65))
	return p.tex()


func _build_basket_empty_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(20, 22, 2)
	_paint_basket(p)
	p.ellipse(10, 5.5, 6, 1.6, Color(0.16, 0.18, 0.24))
	return p.tex()


func _paint_basket(p: Painter) -> void:
	p.rect(2, 4, 16, 3, Color(0.35, 0.4, 0.5))
	p.poly(PackedVector2Array([
		Vector2(3, 7), Vector2(17, 7), Vector2(15, 21), Vector2(5, 21),
	]), Color(0.47, 0.52, 0.62))
	p.vline(6, 8, 12, Color(0.4, 0.45, 0.55))
	p.vline(9, 8, 13, Color(0.4, 0.45, 0.55))
	p.vline(12, 8, 13, Color(0.4, 0.45, 0.55))
	p.vline(15, 8, 12, Color(0.4, 0.45, 0.55))
	p.hline(5, 20, 10, Color(0.3, 0.34, 0.42))


func _build_door_locked_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(44, 104, 2)
	_paint_door(p, false)
	return p.tex()


func _build_door_open_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(44, 104, 2)
	_paint_door(p, true)
	return p.tex()


func _paint_door(p: Painter, open: bool) -> void:
	# Perspective baked in: both door edges converge on the room's back-right
	# corner. Far (left) edge is short, near (right) edge tall. A saturated
	# teal door on an orange wall — they argue, quietly, forever.
	p.poly(PackedVector2Array([
		Vector2(0, 24), Vector2(43, 0), Vector2(43, 103), Vector2(0, 69),
	]), Color(0.05, 0.28, 0.26))
	p.poly(PackedVector2Array([
		Vector2(3, 26), Vector2(40, 4), Vector2(40, 99), Vector2(3, 66),
	]), Color(0.14, 0.55, 0.5))
	p.line(3, 26, 40, 4, Color(0.2, 0.68, 0.62))
	p.line(3, 26, 3, 66, Color(0.2, 0.68, 0.62))
	if open:
		# ajar: a slab of dark along the hinge-side gap
		p.poly(PackedVector2Array([
			Vector2(3, 25), Vector2(9, 22), Vector2(9, 67), Vector2(3, 66),
		]), Color(0.02, 0.05, 0.06))
	# inset panels, corners lerped along the converging edges (see math above)
	p.poly(PackedVector2Array([
		Vector2(9, 29), Vector2(34, 18), Vector2(34, 47), Vector2(9, 44),
	]), Color(0.1, 0.46, 0.42))
	p.line(9, 29, 34, 18, Color(0.07, 0.36, 0.33))
	p.line(9, 44, 34, 47, Color(0.2, 0.68, 0.62))
	p.poly(PackedVector2Array([
		Vector2(9, 49), Vector2(34, 55), Vector2(34, 84), Vector2(9, 65),
	]), Color(0.1, 0.46, 0.42))
	p.line(9, 49, 34, 55, Color(0.07, 0.36, 0.33))
	p.line(9, 65, 34, 84, Color(0.2, 0.68, 0.62))
	# knob (shifts inward when the door hangs ajar)
	var knob_x := 11.0 if open else 6.5
	p.circle(knob_x, 46, 1.8, Color(0.95, 0.78, 0.3))
	p.dot(int(knob_x) - 1, 45, Color(1, 0.95, 0.7))
	# keypad plate mounted mid-door
	p.poly(PackedVector2Array([
		Vector2(20, 39), Vector2(31, 38), Vector2(31, 50), Vector2(20, 49),
	]), Color(0.62, 0.63, 0.68))
	p.line(20, 39, 31, 38, Color(0.8, 0.8, 0.85))
	p.line(20, 49, 31, 50, Color(0.35, 0.35, 0.4))
	for r in 3:
		for c2 in 3:
			p.dot(22 + c2 * 3, 41 + r * 3, Color(0.2, 0.2, 0.25))
	if open:
		p.dot(29, 40, Color(0.2, 0.95, 0.4))
	else:
		p.dot(29, 40, Color(0.95, 0.2, 0.15))


func _build_stain_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(44, 22, 2)
	var dark := Color(0.4, 0.17, 0.09)
	p.ellipse(22, 11, 17, 7, dark)
	p.ellipse(10, 14, 6, 3.5, dark)
	p.ellipse(35, 8, 5, 3, dark)
	p.ellipse_outline(22, 11, 17, 7, Color(0.3, 0.12, 0.06))
	p.ellipse(22, 11, 10, 4, Color(0.33, 0.13, 0.07))
	p.dot(18, 8, Color(0.9, 0.55, 0.18))
	p.dot(27, 14, Color(0.9, 0.55, 0.18))
	p.dot(24, 6, Color(0.8, 0.4, 0.12))
	p.dot(20, 12, Color(0.55, 0.25, 0.12))
	return p.tex()


func _build_bulb_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(12, 18, 2)
	p.rect(4, 0, 4, 4, Color(0.35, 0.35, 0.38))
	p.hline(4, 1, 4, Color(0.5, 0.5, 0.55))
	p.circle(6, 10, 5, Color(1.0, 0.9, 0.55))
	p.circle(6, 10, 3, Color(1.0, 0.97, 0.75))
	p.line(5, 12, 7, 11, Color(0.95, 0.7, 0.3))
	p.dot(4, 8, Color(1, 1, 0.95))
	return p.tex()


func _build_glow_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(40, 40, 2)
	p.circle(20, 20, 18, Color(1.0, 0.95, 0.7, 0.05))
	p.circle(20, 20, 12, Color(1.0, 0.95, 0.7, 0.06))
	p.circle(20, 20, 7, Color(1.0, 0.95, 0.75, 0.08))
	return p.tex()


# ---------------------------------------------------------------- inner classes

class SwingBulb extends Node2D:
	## Pendulum for the ceiling bulb. Two incommensurate sines so the swing
	## drifts instead of ticking like a metronome. Subtle on purpose.
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		rotation = sin(_t * 1.35) * 0.05 + sin(_t * 0.41) * 0.018


class NoteCloseup extends Control:
	## Brief close-up of the sticky note behind the poster corner:
	## "your birthday backwards", plus a cake with too many candles.
	## Click anywhere or Esc to put the poster back.

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		var note := TextureRect.new()
		note.texture = AssetLib.get_or_build("orange_note_closeup", _build_note_tex)
		note.position = Vector2(224, 72)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(note)
		var scrawl := Label.new()
		scrawl.text = "your birthday\nbackwards"
		scrawl.position = Vector2(252, 104)
		scrawl.size = Vector2(140, 48)
		scrawl.rotation = -0.05
		scrawl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scrawl.add_theme_font_size_override("font_size", 13)
		scrawl.add_theme_color_override("font_color", Color(0.22, 0.2, 0.38))
		add_child(scrawl)
		var hint := Label.new()
		hint.text = "( click to look away )"
		hint.position = Vector2(0, 332)
		hint.size = Vector2(640, 16)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 9)
		hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.7))
		add_child(hint)
		gui_input.connect(_on_gui)
		AudioBus.play_sfx("pop", 0.8, -6.0)

	func _on_gui(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			SceneRouter.pop_overlay()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
			accept_event()
			SceneRouter.pop_overlay()

	func _build_note_tex() -> Texture2D:
		var p: Painter = AssetLib.painter(64, 64, 3)
		p.rect(7, 8, 54, 54, Color(0, 0, 0, 0.4))
		p.rect(4, 4, 54, 54, Color(0.99, 0.89, 0.38))
		p.rect(4, 4, 54, 8, Color(0.93, 0.81, 0.3))
		p.rect_outline(4, 4, 54, 54, Color(0.75, 0.6, 0.15))
		# the cake: nine candles on a cake drawn for maybe three
		p.rect(22, 40, 20, 9, Color(0.52, 0.31, 0.15))
		p.rect(22, 38, 20, 3, Color(0.95, 0.55, 0.7))
		p.dot(25, 41, Color(0.95, 0.55, 0.7))
		p.dot(33, 41, Color(0.95, 0.55, 0.7))
		p.dot(39, 41, Color(0.95, 0.55, 0.7))
		for i in 9:
			var cx := 23 + i * 2
			var cc := Color(0.4, 0.6, 0.9) if i % 2 == 0 else Color(0.9, 0.4, 0.35)
			p.vline(cx, 32, 6, cc)
			p.dot(cx, 31, Color(1.0, 0.75, 0.2))
		p.hline(20, 49, 24, Color(0.7, 0.55, 0.2))
		# corner curl
		p.poly(PackedVector2Array([
			Vector2(53, 57), Vector2(57, 57), Vector2(57, 53),
		]), Color(0.85, 0.72, 0.25))
		return p.tex()
