extends BaseRoom
## The Kitchen (spec 7.3). Pale green tile, a checkerboard floor doing its
## best pseudo-3D, a fridge with editorial magnets, and - through the window -
## an actual night. The only real weather in the house.

var _fridge_sprite: Sprite2D
var _magnet_sprite: Sprite2D
var _toaster_sprite: Sprite2D
var _cabinet_sprite: Sprite2D
var _toasting := false


func _room_config() -> void:
	room_id = "kitchen"
	music_name = "kitchen"
	footstep_surface = "tile"
	horizon_y = 195.0
	spawn_points = {
		"default": {"pos": Vector2(88, 288), "dir": "right"},
		"from_living": {"pos": Vector2(88, 288), "dir": "right"},
	}


func _room_setup() -> void:
	_build_walls()
	add_floor("checker", Color(0.78, 0.85, 0.76), Color(0.92, 0.94, 0.9), 1.0)
	_build_fridge()
	_build_counter()
	_build_cabinet()


# ---------------------------------------------------------------- construction

func _build_walls() -> void:
	var wallc := Node2D.new()
	bg.add_child(wallc)
	add_parallax(wallc, 1.0)
	var wall := Sprite2D.new()
	wall.texture = AssetLib.get_or_build("kitchen_wall", _build_wall_tex)
	wall.centered = false
	wallc.add_child(wall)
	var window := Sprite2D.new()
	window.texture = AssetLib.get_or_build("kitchen_window", _build_window_tex)
	window.position = Vector2(340, 96)
	wallc.add_child(window)
	add_hotspot({
		"name": "Window",
		"pos": Vector2(340, 96),
		"size": Vector2(84, 76),
		"look": "That one's real. Real night, real stars. The most suspicious thing in this house.",
		"touch": func(): say("Cold glass. Actual cold. I stood there a second longer than I needed to."),
		"interact": Vector2(340, 220),
	})
	add_exit({
		"name": "Doorway (Living Room)",
		"pos": Vector2(38, 240),
		"size": Vector2(64, 190),
		"target": "living_room",
		"spawn": "from_kitchen",
		"look": "Back to the mustard and the laugh track.",
		"interact": Vector2(80, 300),
	})


func _build_fridge() -> void:
	_fridge_sprite = add_prop(AssetLib.get_or_build("kitchen_fridge", _build_fridge_tex), Vector2(148, 168))
	_magnet_sprite = Sprite2D.new()
	# The magnets spell EAT until the food is actually gone; the moment the
	# last of it leaves the fridge, they spell ATE. Nobody moved them.
	_magnet_sprite.texture = _magnets_tex(_fridge_emptied())
	_magnet_sprite.position = Vector2(148, 150)
	_magnet_sprite.z_index = _fridge_sprite.z_index + 1
	props.add_child(_magnet_sprite)
	add_hotspot({
		"name": "Fridge",
		"pos": Vector2(148, 172),
		"size": Vector2(78, 130),
		"on_look": _look_fridge,
		"touch": _touch_fridge,
		"visual": _fridge_sprite,
		"interact": Vector2(148, 250),
	})


func _build_counter() -> void:
	add_prop(AssetLib.get_or_build("kitchen_counter", _build_counter_tex), Vector2(400, 208), 214)
	# toaster
	_toaster_sprite = add_prop(AssetLib.get_or_build("kitchen_toaster", _build_toaster_tex), Vector2(268, 172), 215)
	add_hotspot({
		"name": "Toaster",
		"pos": Vector2(268, 172),
		"size": Vector2(48, 36),
		"look": "Two slots. Chrome. It reflects the room back slightly happier than it is.",
		"touch": func(): say("I pressed the lever on nothing. The toaster did nothing, correctly."),
		"use_item": _use_on_toaster,
		"visual": _toaster_sprite,
		"interact": Vector2(268, 246),
	})
	# cutting board + knife block
	var board := add_prop(AssetLib.get_or_build("kitchen_board", _build_board_tex), Vector2(430, 174), 215)
	add_hotspot({
		"name": "Cutting Board",
		"pos": Vector2(430, 176),
		"size": Vector2(66, 32),
		"look": "A cutting board, and a knife block with four slots and three knives. Don't think about the fourth.",
		"touch": func(): say("I'm not touching the knives recreationally."),
		"use_item": _use_on_board,
		"visual": board,
		"interact": Vector2(430, 246),
	})
	# bread box
	var breadbox := add_prop(AssetLib.get_or_build("kitchen_breadbox", _build_breadbox_tex), Vector2(534, 170), 215)
	add_hotspot({
		"name": "Bread Box",
		"pos": Vector2(534, 172),
		"size": Vector2(52, 34),
		"look": "A little garage for bread. The bread's home when the light's on. The light is never on.",
		"touch": _touch_breadbox,
		"visual": breadbox,
		"interact": Vector2(534, 246),
	})


func _build_cabinet() -> void:
	_cabinet_sprite = Sprite2D.new()
	_cabinet_sprite.texture = _cabinet_tex()
	_cabinet_sprite.position = Vector2(480, 92)
	_cabinet_sprite.z_index = -390
	bg.add_child(_cabinet_sprite)
	add_hotspot({
		"name": "High Cabinet",
		"pos": Vector2(480, 92),
		"size": Vector2(72, 56),
		"on_look": _look_cabinet,
		"touch": _touch_cabinet,
		"use_item": _use_on_cabinet,
		"visual": _cabinet_sprite,
		"interact": Vector2(480, 230),
	})


# ---------------------------------------------------------------- fridge

func _fridge_emptied() -> bool:
	return GameState.get_flag("kitchen_meat_taken") and GameState.get_flag("kitchen_lettuce_taken")


func _magnets_tex(ate: bool) -> Texture2D:
	if ate:
		return AssetLib.get_or_build("kitchen_magnets_ate", func(): return _build_magnets_tex(true))
	return AssetLib.get_or_build("kitchen_magnets_eat", func(): return _build_magnets_tex(false))


func _look_fridge() -> void:
	if _fridge_emptied():
		say("The magnets say ATE now. I didn't move them. I want that on the record.")
	else:
		say("The magnets spell EAT. Direct. I respect a fridge with a thesis.")


func _touch_fridge() -> void:
	AudioBus.play_sfx("door_open", 1.3, -6.0)
	if not GameState.get_flag("fridge_opened"):
		GameState.set_flag("fridge_opened")
	var gave := false
	if not GameState.get_flag("kitchen_meat_taken") and Inventory.add_item("mystery_meat"):
		UILayer.fly_item("mystery_meat", Vector2(148, 180))
		GameState.set_flag("kitchen_meat_taken")
		gave = true
	if not GameState.get_flag("kitchen_lettuce_taken") and Inventory.add_item("lettuce"):
		UILayer.fly_item("lettuce", Vector2(148, 200))
		GameState.set_flag("kitchen_lettuce_taken")
		gave = true
	if gave:
		if _fridge_emptied():
			# the fridge updates its editorial position immediately
			_magnet_sprite.texture = _magnets_tex(true)
		var line := "\"Meat\", in quotes, and lettuce. The lettuce vouches for nothing."
		if Inventory.has_item("cold_cheese_slice"):
			line += " The cheese from the other fridge glares at them. Cheese counts, cheese. You count."
		say(line)
	else:
		say([
			"The fridge has entered its minimalist era.",
			"Just the light in there. It comes on for nobody.",
		])


# ---------------------------------------------------------------- counter

func _touch_breadbox() -> void:
	if GameState.get_flag("kitchen_bread_taken"):
		say("Empty. The bread box is between tenants.")
		return
	if Inventory.add_item("bread"):
		UILayer.fly_item("bread", Vector2(534, 168))
		GameState.set_flag("kitchen_bread_taken")
		AudioBus.play_sfx("door_open", 1.6, -10.0)
		say("Two slices. They travel as one item. They've agreed to this.")


## Sync entry point: handlers reached via Callable.call() must never be
## coroutines (Godot errors out on "async function without await" and the
## body never runs - this was the reported toaster freeze). The wrapper
## validates synchronously, then fires the async cycle as a direct call.
func _use_on_toaster(item_id: String) -> bool:
	if item_id != "bread":
		if item_id == "toast":
			say("Again? No. There's a line, and it's drawn in carbon.")
			return true
		return false
	if _toasting:
		say("It's busy. Toast is a process, not an event.")
		return true
	_toast_cycle()
	return true


func _toast_cycle() -> void:
	_toasting = true
	# Consume the bread only when the toast pops: if the player wanders off to
	# another room mid-cycle this timer dies with the room and the bread lives.
	AudioBus.play_sfx("click", 0.8)
	_toaster_sprite.modulate = Color(1.25, 1.05, 0.9)
	var timer := get_tree().create_timer(3.0)
	var tick := Timer.new()
	tick.wait_time = 0.75
	tick.timeout.connect(func(): AudioBus.play_sfx("tick", 0.7, -12.0))
	add_child(tick)
	tick.start()
	await timer.timeout
	if not is_instance_valid(tick):
		return
	tick.queue_free()
	if not is_inside_tree():
		return
	_toasting = false
	_toaster_sprite.modulate = Color.WHITE
	# The bread might have been combined away during the 3s cycle - no bread,
	# no toast, no duplication exploit.
	if not Inventory.has_item("bread"):
		AudioBus.play_sfx("pop", 0.7)
		say("The toaster popped on nothing. It felt that. We both felt that.")
		return
	Inventory.remove_item("bread")
	Inventory.add_item("toast")
	UILayer.fly_item("toast", Vector2(268, 160))
	AudioBus.play_sfx("pop", 1.3)
	say("Toast. The bread came back with a past.")
	return


func _use_on_board(item_id: String) -> bool:
	if item_id != "mystery_meat":
		if item_id == "sliced_meat":
			say("Slicing slices gets philosophical fast. No.")
			return true
		if item_id in ["bread", "toast", "lettuce", "cold_cheese_slice"]:
			say("It doesn't need cutting. It needs assembling. Different verb, same me.")
			return true
		return false
	_chop_meat()  # async body fired via direct call (never through Callable.call)
	return true


func _chop_meat() -> void:
	GameState.lock_input()
	for i in 3:
		AudioBus.play_sfx("thud_tile_1", 1.8, -4.0)
		await get_tree().create_timer(0.22).timeout
	GameState.unlock_input()
	if not is_inside_tree():
		return
	Inventory.remove_item("mystery_meat")
	Inventory.add_item("sliced_meat")
	UILayer.fly_item("sliced_meat", Vector2(430, 164))
	say("Sliced. The quotes survived the knife.")


# ---------------------------------------------------------------- cabinet

func _look_cabinet() -> void:
	if GameState.get_flag("cabinet_open"):
		say("The latch is a small plastic puddle now. The cabinet is at peace.")
	else:
		say("A high cabinet with a childproof latch. Proofed against children, turtles, most adults.")


func _touch_cabinet() -> void:
	if GameState.get_flag("cabinet_open"):
		if not GameState.get_flag("kitchen_ramune_taken"):
			if Inventory.add_item("ramune_bottle"):
				UILayer.fly_item("ramune_bottle", Vector2(480, 100))
				GameState.set_flag("kitchen_ramune_taken")
				_cabinet_sprite.texture = _cabinet_tex()  # bottle leaves the shelf
				say("A full ramune. The marble's still sealed in. Somebody's been saving a celebration.")
		else:
			say("Empty now, and proud of the scorch mark.")
		return
	AudioBus.play_sfx("click", 1.4, -6.0)
	say([
		"The latch won. Round one to the latch.",
		"You squeeze, then lift, then pivot, then accept defeat.",
		"I have thumbs for this and it still beat me.",
	])


func _use_on_cabinet(item_id: String) -> bool:
	if item_id != "perfect_pizza_roll":
		if item_id == "plastic_trophy":
			say("Prying it open feels like cheating a baby. The latch, I mean.")
			return true
		return false
	if GameState.get_flag("cabinet_open"):
		say("Already open. The roll and I both remember.")
		return true
	_melt_latch()  # async body fired via direct call
	return true


func _melt_latch() -> void:
	# The roll's impossible heat vs. childproof plastic. One-sided.
	AudioBus.play_sfx("puff")
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	AudioBus.play_sfx("poof", 0.8)
	GameState.set_flag("cabinet_open")
	_cabinet_sprite.texture = _cabinet_tex()
	say("The latch melted. The roll is unharmed. Still perfect. Of course it is.")


func _cabinet_tex() -> Texture2D:
	# The open texture bakes in whether the bottle is still on the shelf, so
	# the cache key has to encode that state too.
	if GameState.get_flag("cabinet_open"):
		var key := "kitchen_cabinet_open_empty" if GameState.get_flag("kitchen_ramune_taken") else "kitchen_cabinet_open_full"
		return AssetLib.get_or_build(key, func(): return _build_cabinet_tex(true))
	return AssetLib.get_or_build("kitchen_cabinet_shut", func(): return _build_cabinet_tex(false))


# ---------------------------------------------------------------- textures

func _build_wall_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 98, 2)
	var tile_a := Color(0.72, 0.82, 0.72)
	var tile_b := Color(0.66, 0.78, 0.68)
	var grout := Color(0.55, 0.66, 0.58)
	for ty in range(0, 98, 12):
		for tx in range(0, 320, 16):
			var off := 8 if (ty / 12) % 2 == 1 else 0
			var c := tile_a if ((tx + off) / 16 + ty / 12) % 2 == 0 else tile_b
			p.rect(tx - off, ty, 16, 12, c)
			p.hline(tx - off, ty, 16, grout)
			p.vline(tx - off, ty, 12, grout)
	# one tile, slightly wrong shade. installed on a different day. by someone else.
	p.rect(193, 36, 15, 11, Color(0.74, 0.79, 0.83))
	# baseboard
	p.rect(0, 92, 320, 6, Color(0.45, 0.55, 0.48))
	p.hline(0, 92, 320, Color(0.6, 0.72, 0.62))
	# doorway to the living room, left
	p.rect(3, 24, 34, 74, Color(0.2, 0.14, 0.07))
	p.rect(5, 26, 30, 72, Color(0.45, 0.34, 0.14))
	p.rect_outline(2, 23, 36, 75, Color(0.5, 0.6, 0.52))
	return p.tex()


func _build_window_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(42, 38, 2)
	var frame := Color(0.85, 0.9, 0.86)
	# actual night: gradient sky, stars, a moon with no expression at all
	for y in range(3, 31):
		var t := float(y - 3) / 27.0
		var sky := Color(0.04, 0.05, 0.14).lerp(Color(0.1, 0.12, 0.28), t)
		p.hline(3, y, 36, sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7014
	for i in 14:
		var sx := rng.randi_range(4, 37)
		var sy := rng.randi_range(4, 26)
		p.dot(sx, sy, Color(0.9, 0.92, 1.0, rng.randf_range(0.4, 1.0)))
	p.circle(30, 10, 4, Color(0.92, 0.93, 0.85))
	p.circle(28, 9, 3, Color(0.04, 0.05, 0.14))  # crescent bite
	p.dot(10, 24, Color(0.7, 0.75, 0.95, 0.6))
	# frame + crossbars
	p.rect(19, 3, 2, 28, frame)
	p.rect(3, 16, 36, 2, frame)
	p.rect(0, 0, 42, 3, frame)
	p.rect(0, 31, 42, 4, frame)
	p.rect(0, 0, 3, 35, frame)
	p.rect(39, 0, 3, 35, frame)
	p.rect_outline(0, 0, 42, 35, Color(0.5, 0.6, 0.55))
	p.hline(4, 35, 34, Color(0.6, 0.7, 0.62))  # sill
	# a tiny potted plant on the sill, leaning toward the real air
	p.rect(6, 32, 4, 3, Color(0.7, 0.4, 0.25))
	p.dot(7, 31, Color(0.3, 0.7, 0.3))
	p.dot(8, 30, Color(0.3, 0.7, 0.3))
	return p.tex()


func _build_fridge_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(40, 66, 2)
	p.rect(2, 2, 36, 62, Color(0.9, 0.93, 0.9))
	p.rect_outline(2, 2, 36, 62, Color(0.55, 0.62, 0.58))
	p.hline(2, 24, 36, Color(0.6, 0.68, 0.62))
	p.rect(33, 8, 2, 12, Color(0.6, 0.66, 0.62))
	p.rect(33, 30, 2, 16, Color(0.6, 0.66, 0.62))
	p.hline(2, 2, 36, Color(1, 1, 1))
	p.rect(6, 64, 5, 2, Color(0.3, 0.33, 0.3))
	p.rect(29, 64, 5, 2, Color(0.3, 0.33, 0.3))
	# a child's drawing that came with the house
	p.rect(9, 34, 10, 12, Color(0.98, 0.98, 0.94))
	p.circle(14, 38, 2, Color(0.95, 0.75, 0.2))
	p.line(11, 43, 17, 43, Color(0.35, 0.65, 0.3))
	p.dot(12, 36, Color(0.9, 0.3, 0.3))
	return p.tex()


func _build_magnets_tex(ate: bool) -> Texture2D:
	var p: Painter = AssetLib.painter(40, 10, 2)
	var letters := "ATE" if ate else "EAT"
	var cols := [Color(0.9, 0.25, 0.2), Color(0.25, 0.5, 0.9), Color(0.95, 0.8, 0.2)]
	var glyphs := {
		"E": ["111", "100", "111", "100", "111"],
		"A": ["010", "101", "111", "101", "101"],
		"T": ["111", "010", "010", "010", "010"],
	}
	for i in letters.length():
		var rows: Array = glyphs[letters[i]]
		var ox := 10 + i * 7
		for r in rows.size():
			for c in 3:
				if rows[r][c] == "1":
					p.dot(ox + c, 2 + r, cols[i])
	# plus the loose crowd of unused letters along the bottom edge
	p.dot(4, 8, Color(0.3, 0.75, 0.4))
	p.dot(33, 8, Color(0.8, 0.4, 0.8))
	p.dot(36, 3, Color(0.3, 0.75, 0.4))
	return p.tex()


func _build_counter_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(190, 40, 2)
	# countertop slab + cabinet doors below
	p.rect(0, 0, 190, 6, Color(0.82, 0.78, 0.7))
	p.hline(0, 0, 190, Color(0.92, 0.9, 0.84))
	p.hline(0, 5, 190, Color(0.6, 0.56, 0.5))
	p.rect(2, 6, 186, 32, Color(0.5, 0.6, 0.52))
	for i in 5:
		p.rect_outline(6 + i * 37, 9, 33, 26, Color(0.4, 0.5, 0.42))
		p.dot(33 + i * 37, 22, Color(0.85, 0.88, 0.85))
	p.speckle(0, 1, 190, 4, Color(0.7, 0.66, 0.58), 0.08, 23)  # crumbs of prior sandwiches
	return p.tex()


func _build_toaster_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(26, 18, 2)
	p.ellipse(13, 10, 12, 7, Color(0.75, 0.78, 0.82))
	p.ellipse(13, 8, 11, 5.5, Color(0.85, 0.88, 0.92))
	p.hline(5, 4, 7, Color(0.3, 0.32, 0.36))
	p.hline(14, 4, 7, Color(0.3, 0.32, 0.36))
	p.rect(2, 9, 2, 4, Color(0.35, 0.38, 0.42))  # the lever
	p.dot(13, 13, Color(0.9, 0.3, 0.2))
	p.hline(8, 11, 10, Color(1, 1, 1, 0.5))      # chrome smile
	return p.tex()


func _build_board_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(34, 16, 2)
	# board
	p.ellipse(12, 10, 11, 5, Color(0.8, 0.62, 0.38))
	p.ellipse_outline(12, 10, 11, 5, Color(0.6, 0.44, 0.24))
	p.hline(6, 9, 12, Color(0.65, 0.48, 0.28))
	# knife block: four slots, three knives
	p.poly(PackedVector2Array([
		Vector2(24, 14), Vector2(33, 14), Vector2(33, 4), Vector2(27, 2),
	]), Color(0.5, 0.34, 0.18))
	for i in 3:
		p.line(26 + i * 2, 4, 27 + i * 2, 1, Color(0.8, 0.82, 0.86))
	p.vline(32, 3, 3, Color(0.3, 0.2, 0.1))  # the fourth slot. empty. fine.
	return p.tex()


func _build_breadbox_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(28, 18, 2)
	p.poly(PackedVector2Array([
		Vector2(2, 16), Vector2(26, 16), Vector2(26, 8), Vector2(20, 2), Vector2(2, 2),
	]), Color(0.72, 0.5, 0.3))
	p.line(2, 2, 20, 2, Color(0.85, 0.64, 0.4))
	p.line(20, 2, 26, 8, Color(0.85, 0.64, 0.4))
	p.rect(6, 6, 14, 9, Color(0.55, 0.36, 0.2))
	p.rect_outline(6, 6, 14, 9, Color(0.4, 0.26, 0.13))
	p.dot(13, 11, Color(0.9, 0.75, 0.5))
	return p.tex()


func _build_cabinet_tex(open: bool) -> Texture2D:
	var p: Painter = AssetLib.painter(38, 30, 2)
	p.rect(1, 1, 36, 28, Color(0.55, 0.42, 0.26))
	p.rect_outline(1, 1, 36, 28, Color(0.38, 0.28, 0.16))
	if open:
		# one door swung wide; the inside and the scorched hinge of the latch
		p.rect(4, 4, 14, 22, Color(0.25, 0.17, 0.09))
		p.rect(19, 3, 16, 25, Color(0.6, 0.47, 0.3))
		p.vline(19, 3, 25, Color(0.7, 0.56, 0.38))
		p.dot(18, 15, Color(0.2, 0.2, 0.2))
		p.dot(17, 16, Color(0.35, 0.3, 0.25))  # the puddle formerly known as latch
		if not GameState.get_flag("kitchen_ramune_taken"):
			p.rect(8, 16, 4, 9, Color(0.45, 0.7, 0.95))
			p.rect(9, 13, 2, 3, Color(0.6, 0.82, 1.0))
	else:
		p.vline(19, 2, 26, Color(0.4, 0.3, 0.18))
		p.dot(16, 15, Color(0.85, 0.88, 0.85))
		p.dot(22, 15, Color(0.85, 0.88, 0.85))
		# the childproof latch, smug
		p.rect(16, 12, 7, 3, Color(0.9, 0.9, 0.92))
		p.rect_outline(16, 12, 7, 3, Color(0.6, 0.6, 0.65))
	return p.tex()
