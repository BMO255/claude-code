extends Node
## Procedural asset factory + cache. Every texture and sound in DORKO is
## generated at runtime from code - there are no binary assets in the repo.
## Rooms build their own art with painter()/get_or_build(); shared art
## (cursors, item icons, portraits, floors, SFX, music) lives here.

var _tex_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}


func painter(w: int, h: int, pixel_size := 1, bg := Color(0, 0, 0, 0)) -> Painter:
	return Painter.new(w, h, pixel_size, bg)


## Cache-or-create for room-local art. builder receives no args and returns Texture2D.
func get_or_build(key: String, builder: Callable) -> Texture2D:
	if not _tex_cache.has(key):
		_tex_cache[key] = builder.call()
	return _tex_cache[key]


func solid(w: int, h: int, color: Color) -> Texture2D:
	return get_or_build("solid_%d_%d_%s" % [w, h, color.to_html()], func():
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(color)
		return ImageTexture.create_from_image(img))


# ---------------------------------------------------------------- core textures

func tex(name: String) -> Texture2D:
	return get_or_build("core_" + name, func(): return _build_tex(name))


func _build_tex(name: String) -> Texture2D:
	var p: Painter
	match name:
		"pixel":
			p = painter(1, 1)
			p.dot(0, 0, Color.WHITE)
		"cursor_eye":
			p = painter(12, 12, 2)
			p.ellipse(6, 6, 5.5, 3.5, Color(0.95, 0.93, 0.85))
			p.ellipse_outline(6, 6, 5.5, 3.5, Color(0.1, 0.1, 0.12))
			p.circle(6, 6, 2.5, Color(0.2, 0.55, 0.3))
			p.circle(6, 6, 1.2, Color(0.05, 0.05, 0.05))
			p.dot(5, 5, Color(1, 1, 1))
		"cursor_hand":
			p = painter(12, 12, 2)
			var skin := Color(0.96, 0.82, 0.3)
			var dark := Color(0.55, 0.42, 0.08)
			p.rect(3, 5, 6, 6, skin)          # palm
			p.rect(3, 2, 1, 4, skin)           # fingers
			p.rect(5, 1, 1, 5, skin)
			p.rect(7, 2, 1, 4, skin)
			p.rect(9, 4, 2, 3, skin)           # thumb
			p.rect_outline(3, 5, 6, 6, dark)
			p.vline(2, 5, 5, dark)
		"cursor_mouth":
			p = painter(12, 12, 2)
			var lip := Color(0.85, 0.3, 0.35)
			var dark2 := Color(0.25, 0.05, 0.08)
			p.ellipse(6, 6, 5.0, 3.5, lip)
			p.ellipse_outline(6, 6, 5.0, 3.5, dark2)
			p.ellipse(6, 6, 3.5, 1.5, Color(0.2, 0.02, 0.05))
			p.rect(4, 5, 2, 1, Color.WHITE)    # teeth glint
			p.rect(7, 5, 2, 1, Color.WHITE)
		"shadow":
			p = painter(24, 8, 2)
			p.ellipse(12, 4, 11, 3.5, Color(0, 0, 0, 0.35))
			p.ellipse(12, 4, 8, 2.5, Color(0, 0, 0, 0.2))
		"slot_bg":
			p = painter(18, 18, 2)
			p.rect(0, 0, 18, 18, Color(0.13, 0.1, 0.16, 0.9))
			p.rect_outline(0, 0, 18, 18, Color(0.55, 0.45, 0.65))
			p.rect_outline(1, 1, 16, 16, Color(0.05, 0.03, 0.08))
		_:
			p = painter(8, 8, 2)
			p.checker(0, 0, 8, 8, 2, Color.MAGENTA, Color.BLACK)  # missing-texture look
	return p.tex()


# ---------------------------------------------------------------- item icons

func item_icon(id: String) -> Texture2D:
	return get_or_build("item_" + id, func(): return _build_item_icon(id))


func _build_item_icon(id: String) -> Texture2D:
	var p := painter(16, 16, 2)
	var outline := Color(0.1, 0.08, 0.1)
	match id:
		"cold_cheese_slice":
			var ch := Color(1.0, 0.85, 0.3)
			p.poly(PackedVector2Array([Vector2(1, 13), Vector2(14, 13), Vector2(14, 3)]), ch)
			p.line(1, 13, 14, 3, outline)
			p.line(1, 13, 14, 13, outline)
			p.vline(14, 3, 11, outline)
			p.circle(10, 9, 1.4, Color(0.85, 0.68, 0.15))
			p.circle(12, 11, 1.0, Color(0.85, 0.68, 0.15))
			p.dot(8, 12, Color(0.6, 0.8, 1.0))  # a glint of cold
		"crumpled_card":
			var pink := Color(0.95, 0.7, 0.8)
			p.poly(PackedVector2Array([Vector2(3, 4), Vector2(8, 2), Vector2(13, 5), Vector2(12, 12), Vector2(6, 13), Vector2(2, 10)]), pink)
			p.line(3, 4, 12, 12, Color(0.7, 0.45, 0.55))
			p.line(8, 2, 6, 13, Color(0.7, 0.45, 0.55))
			p.line(13, 5, 2, 10, Color(0.8, 0.55, 0.65))
			p.dot(7, 7, Color(0.4, 0.2, 0.3))
		"perfect_pizza_roll":
			p.ellipse(8, 9, 6, 4, Color(0.9, 0.68, 0.3))
			p.ellipse_outline(8, 9, 6, 4, Color(0.55, 0.35, 0.1))
			p.ellipse(8, 8, 4.5, 2.5, Color(0.98, 0.8, 0.45))
			p.dot(6, 8, Color(0.75, 0.2, 0.1))
			p.dot(10, 9, Color(0.75, 0.2, 0.1))
			# it glows faintly, because it is correct
			p.dot(3, 3, Color(1, 1, 0.7)); p.dot(13, 4, Color(1, 1, 0.7)); p.dot(12, 14, Color(1, 1, 0.7))
		"bread":
			p.ellipse(8, 5, 6, 3.5, Color(0.94, 0.85, 0.65))
			p.ellipse_outline(8, 5, 6, 3.5, Color(0.65, 0.5, 0.3))
			p.ellipse(8, 10, 6, 3.5, Color(0.94, 0.85, 0.65))
			p.ellipse_outline(8, 10, 6, 3.5, Color(0.65, 0.5, 0.3))
		"toast":
			p.ellipse(8, 5, 6, 3.5, Color(0.8, 0.6, 0.35))
			p.ellipse_outline(8, 5, 6, 3.5, Color(0.5, 0.32, 0.15))
			p.ellipse(8, 10, 6, 3.5, Color(0.8, 0.6, 0.35))
			p.ellipse_outline(8, 10, 6, 3.5, Color(0.5, 0.32, 0.15))
			p.speckle(3, 3, 10, 10, Color(0.45, 0.28, 0.12), 0.12, 5)
		"mystery_meat":
			p.rect(3, 5, 10, 7, Color(0.9, 0.55, 0.6))
			p.rect_outline(3, 5, 10, 7, outline)
			p.speckle(4, 6, 8, 5, Color(0.75, 0.4, 0.45), 0.2, 9)
			p.dot(6, 8, Color(1, 1, 1)); p.dot(9, 8, Color(1, 1, 1))  # the quotes
		"sliced_meat":
			for i in 3:
				p.ellipse(6 + i * 2, 6 + i * 2, 5, 2.5, Color(0.92, 0.6, 0.65))
				p.ellipse_outline(6 + i * 2, 6 + i * 2, 5, 2.5, Color(0.6, 0.3, 0.35))
		"lettuce":
			p.ellipse(8, 8, 6, 5, Color(0.5, 0.85, 0.4))
			p.ellipse_outline(8, 8, 6, 5, Color(0.2, 0.5, 0.15))
			p.line(4, 10, 8, 5, Color(0.3, 0.65, 0.25))
			p.line(8, 5, 12, 10, Color(0.3, 0.65, 0.25))
		"sandwich", "good_sandwich", "great_sandwich":
			p.ellipse(8, 4, 6, 2.5, Color(0.94, 0.85, 0.65))   # top bread
			p.rect(2, 6, 12, 2, Color(0.92, 0.6, 0.65))         # meat
			var row := 8
			if id != "sandwich":
				p.rect(2, row, 12, 1, Color(1.0, 0.85, 0.3))    # cheese
				row += 1
			if id == "great_sandwich":
				p.rect(2, row, 12, 1, Color(0.5, 0.85, 0.4))    # lettuce
				row += 1
			p.ellipse(8, row + 2, 6, 2.5, Color(0.9, 0.78, 0.55))  # bottom bread
			p.ellipse_outline(8, 4, 6, 2.5, Color(0.65, 0.5, 0.3))
		"ramune_bottle":
			var glass := Color(0.45, 0.7, 0.95, 0.9)
			p.rect(6, 6, 4, 8, glass)
			p.ellipse(8, 6, 2, 1.5, glass)
			p.rect(7, 2, 2, 3, Color(0.6, 0.82, 1.0))
			p.rect_outline(6, 6, 4, 8, Color(0.2, 0.35, 0.6))
			p.circle(8, 8, 1.2, Color(0.85, 0.95, 1.0))  # the marble
		"cassette_tape":
			p.rect(2, 5, 12, 7, Color(0.15, 0.15, 0.18))
			p.rect_outline(2, 5, 12, 7, Color(0.5, 0.5, 0.55))
			p.circle(6, 8, 1.4, Color(0.85, 0.85, 0.9))
			p.circle(10, 8, 1.4, Color(0.85, 0.85, 0.9))
			p.rect(4, 6, 8, 1, Color(0.8, 0.6, 0.2))  # label strip
		"plastic_trophy":
			var gold := Color(0.95, 0.8, 0.25)
			p.ellipse(8, 5, 4, 3, gold)
			p.rect(7, 7, 2, 3, gold)
			p.rect(5, 11, 6, 2, Color(0.55, 0.35, 0.15))
			p.ellipse_outline(8, 5, 4, 3, Color(0.6, 0.45, 0.1))
			p.dot(6, 4, Color(1, 1, 0.85))
		"wet_rag":
			p.poly(PackedVector2Array([Vector2(3, 4), Vector2(12, 3), Vector2(13, 10), Vector2(5, 12)]), Color(0.55, 0.62, 0.7))
			p.line(3, 4, 13, 10, Color(0.4, 0.47, 0.55))
			p.dot(6, 13, Color(0.5, 0.7, 1.0))
			p.dot(10, 14, Color(0.5, 0.7, 1.0))
		"wind_up_key":
			var grey := Color(0.75, 0.75, 0.8)
			p.ellipse_outline(5, 5, 3, 3, grey)
			p.ellipse_outline(11, 5, 3, 3, grey)
			p.rect(7, 4, 2, 2, grey)
			p.rect(7, 6, 2, 8, grey)
			p.rect(6, 13, 4, 1, grey)
		_:
			p.circle(8, 8, 6, Color(0.6, 0.6, 0.6))
			p.dot(8, 8, Color.BLACK)
	return p.tex()


# ---------------------------------------------------------------- portraits

func portrait(id: String) -> Texture2D:
	return get_or_build("portrait_" + id, func(): return _build_portrait(id))


func _build_portrait(id: String) -> Texture2D:
	var p := painter(24, 24, 2)
	p.rect(0, 0, 24, 24, Color(0.08, 0.06, 0.1))
	p.rect_outline(0, 0, 24, 24, Color(0.5, 0.4, 0.6))
	match id:
		"dorko":
			var fro := Color(0.16, 0.5, 0.2)
			var fro_dark := Color(0.08, 0.3, 0.1)
			var skin := Color(0.96, 0.82, 0.3)
			# afro: cluster of circles
			p.circle(12, 8, 8, fro_dark)
			p.circle(7, 8, 4.5, fro); p.circle(17, 8, 4.5, fro)
			p.circle(12, 5, 5, fro); p.circle(12, 9, 6.5, fro)
			p.rect(7, 14, 10, 8, skin)          # face
			p.ellipse(12, 21, 6, 3, skin)
			# the visor: one wide orange triangle, eyes never visible
			p.poly(PackedVector2Array([Vector2(5, 15), Vector2(19, 15), Vector2(12, 20)]), Color(1.0, 0.55, 0.1))
			p.line(5, 15, 19, 15, Color(0.6, 0.25, 0.0))
			p.line(5, 15, 12, 20, Color(0.6, 0.25, 0.0))
			p.line(19, 15, 12, 20, Color(0.6, 0.25, 0.0))
			p.dot(9, 16, Color(1.0, 0.8, 0.5))  # glint
			p.hline(10, 22, 4, Color(0.5, 0.36, 0.06))  # deadpan mouth
		"couch_guy":
			var face := Color(0.9, 0.75, 0.6)
			var hat := Color(0.55, 0.55, 0.58)
			p.circle(12, 14, 9, face)
			p.ellipse(12, 7, 10, 5, hat)                 # ushanka dome
			p.rect(2, 8, 4, 10, hat); p.rect(18, 8, 4, 10, hat)  # ear flaps down
			p.speckle(3, 3, 18, 6, Color(0.68, 0.68, 0.7), 0.25, 3)
			# the red star on the front of the hat
			var star := Color(0.85, 0.15, 0.12)
			p.dot(12, 6, star)
			p.dot(11, 7, star); p.dot(12, 7, star); p.dot(13, 7, star)
			p.dot(10, 8, star); p.dot(14, 8, star)
			p.hline(8, 13, 3, Color(0.2, 0.15, 0.1))     # half-lidded eyes, locked right
			p.hline(14, 13, 3, Color(0.2, 0.15, 0.1))
			p.dot(10, 14, Color(0.1, 0.08, 0.05)); p.dot(16, 14, Color(0.1, 0.08, 0.05))
			p.hline(11, 19, 3, Color(0.5, 0.35, 0.25))   # a mouth that has said "sandwich"
		"blue_bomb":
			var navy := Color(0.15, 0.2, 0.45)
			p.circle(12, 14, 9, navy)
			p.circle(9, 12, 3, Color.WHITE); p.circle(15, 12, 3, Color.WHITE)
			p.circle(9, 13, 1.2, Color.BLACK); p.circle(15, 13, 1.2, Color.BLACK)
			p.rect(11, 2, 2, 4, Color(0.6, 0.5, 0.3))    # fuse
			p.dot(12, 1, Color(1, 0.8, 0.2)); p.dot(11, 0, Color(1, 0.4, 0.1))
			p.ellipse(12, 19, 3, 1.5, Color(0.1, 0.13, 0.3))  # worried mouth
			p.dot(19, 10, Color(0.6, 0.8, 1.0))          # sweat
		"sun_bmp":
			# the sun from the file, eyes open, all teeth accounted for
			p.rect(1, 1, 22, 22, Color(0.5, 0.72, 0.95))
			p.circle(12, 12, 8, Color(1.0, 0.84, 0.12))
			p.ellipse_outline(12, 12, 8, 8, Color(0.85, 0.6, 0.05))
			for i in 8:
				var a := TAU * float(i) / 8.0
				p.line(int(12 + cos(a) * 9.0), int(12 + sin(a) * 9.0),
					int(12 + cos(a) * 11.5), int(12 + sin(a) * 11.5), Color(1.0, 0.84, 0.12))
			p.circle(9, 10, 1.6, Color.WHITE)
			p.circle(15, 10, 1.6, Color.WHITE)
			p.dot(9, 10, Color(0.15, 0.1, 0.05))
			p.dot(15, 10, Color(0.15, 0.1, 0.05))
			p.ellipse(12, 15, 5, 2.5, Color(0.4, 0.15, 0.05))
			for i in 5:
				p.dot(8 + i * 2, 14, Color(0.98, 0.98, 0.95))
				p.dot(8 + i * 2, 16, Color(0.98, 0.98, 0.95))
		"turquoise_one":
			var tq := Color(0.2, 0.8, 0.75)
			p.ellipse(12, 12, 6, 10, tq)
			p.poly(PackedVector2Array([Vector2(7, 10), Vector2(17, 10), Vector2(12, 14)]), Color(1.0, 0.55, 0.1))
			p.line(7, 10, 17, 10, Color(0.6, 0.25, 0.0))
			# the smile: gentle, fixed, load-bearing
			p.line(9, 18, 12, 20, Color(0.05, 0.3, 0.28))
			p.line(12, 20, 15, 18, Color(0.05, 0.3, 0.28))
		_:
			p.ellipse(12, 13, 6, 8, Color(0.3, 0.3, 0.33))
			p.rect(11, 9, 2, 5, Color(0.6, 0.6, 0.65))
			p.dot(11, 16, Color(0.6, 0.6, 0.65))
	return p.tex()


# ---------------------------------------------------------------- floors & walls

## Perspective-projected floor texture. Draws a trapezoid whose checker/stripe
## pattern converges toward a vanishing point, with rows perspective-spaced.
## opts: w, h, back_half, front_half, center_x, pattern ("checker"|"stripes_z"|
## "stripes_x"|"grid"|"solid"), col_a, col_b, cell (world units; 1.0 ≈ 37px at
## the front edge), z_far (how much deeper the back is; default 3.0),
## shade_back (0..1 darkening at the back).
func floor_tex(key: String, opts: Dictionary = {}) -> Texture2D:
	return get_or_build("floor_" + key, func(): return _build_floor(opts))


func _build_floor(opts: Dictionary) -> Texture2D:
	var w: int = opts.get("w", 640)
	var h: int = opts.get("h", 150)
	var back_half: float = opts.get("back_half", 190.0)
	var front_half: float = opts.get("front_half", 330.0)
	var cx: float = opts.get("center_x", w / 2.0)
	var pattern: String = opts.get("pattern", "checker")
	var col_a: Color = opts.get("col_a", Color(0.55, 0.35, 0.2))
	var col_b: Color = opts.get("col_b", Color(0.45, 0.28, 0.16))
	var cell: float = opts.get("cell", 1.0)
	var z_far: float = opts.get("z_far", 3.0)
	var shade_back: float = opts.get("shade_back", 0.3)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(max(1, h - 1))
		# Perspective-correct depth: interpolate 1/z linearly in screen space.
		var inv_z: float = lerp(1.0 / z_far, 1.0, t)
		var z := 1.0 / inv_z
		var half: float = lerp(back_half, front_half, t)
		var shade: float = lerp(1.0 - shade_back, 1.0, t)
		var x0: int = int(floor(cx - half))
		var x1: int = int(ceil(cx + half))
		var world_z := z * 4.0 / cell
		for x in range(max(0, x0), min(w, x1 + 1)):
			var u := (float(x) - cx) / half   # -1 .. 1 across the floor
			var world_x := u * z * 8.0 / cell
			var col: Color
			match pattern:
				"checker":
					var even := (int(floor(world_x)) + int(floor(world_z))) % 2 == 0
					col = col_a if even else col_b
				"stripes_z":
					col = col_a if int(floor(world_z)) % 2 == 0 else col_b
				"stripes_x":
					col = col_a if int(floor(world_x)) % 2 == 0 else col_b
				"grid":
					var fx := absf(world_x - round(world_x))
					var fz := absf(world_z - round(world_z))
					var lw := 0.06 * z  # keep the line roughly screen-constant
					col = col_b if (fx < lw or fz < lw / 2.0) else col_a
				_:
					col = col_a
			col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Simple speckled vertical-gradient wall panel.
func wall_tex(key: String, w: int, h: int, top: Color, bottom: Color, grime := 0.0) -> Texture2D:
	return get_or_build("wall_" + key, func():
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			var c := top.lerp(bottom, float(y) / float(max(1, h - 1)))
			for x in w:
				img.set_pixel(x, y, c)
		if grime > 0.0:
			var rng := RandomNumberGenerator.new()
			rng.seed = key.hash()
			for i in int(w * h * grime * 0.02):
				var gx := rng.randi_range(0, w - 1)
				var gy := rng.randi_range(0, h - 1)
				var gc := img.get_pixel(gx, gy).darkened(rng.randf_range(0.05, 0.2))
				img.set_pixel(gx, gy, gc)
		return ImageTexture.create_from_image(img))


# ---------------------------------------------------------------- audio

func sfx(name: String) -> AudioStreamWAV:
	if not _sfx_cache.has(name):
		_sfx_cache[name] = _build_sfx(name)
	return _sfx_cache[name]


func music(name: String) -> AudioStreamWAV:
	if not _music_cache.has(name):
		_music_cache[name] = MusicGen.song(name)
	return _music_cache[name]


func _build_sfx(name: String) -> AudioStreamWAV:
	var S := SfxSynth
	var samples: PackedFloat32Array
	var loop := false
	match name:
		"tick":
			samples = S.tone(1200.0, 0.03, "square", 0.25, 0.001, 0.01)
		"pop":
			samples = S.sweep(300.0, 900.0, 0.07, "sine", 0.5, 0.002, 0.02)
		"click":
			samples = S.noise(0.025, 0.5, 0.6, 0.001, 0.015)
		"blip":
			samples = S.tone(600.0, 0.055, "square", 0.18, 0.002, 0.02)
		"chime_boot":
			samples = S.mix([
				S.tone(392.0, 0.5, "sine", 0.25, 0.01, 0.3),
				S.tone(523.25, 0.6, "sine", 0.25, 0.01, 0.35),
				S.tone(659.25, 0.8, "sine", 0.22, 0.01, 0.5),
				S.tone(783.99, 1.0, "sine", 0.18, 0.01, 0.7),
			], [0.0, 0.12, 0.24, 0.36])
		"error_dlg":
			samples = S.seq([S.tone(330.0, 0.12, "square", 0.3, 0.002, 0.02), S.tone(262.0, 0.2, "square", 0.3, 0.002, 0.08)])
		"keypad_beep":
			samples = S.tone(880.0, 0.06, "square", 0.25, 0.002, 0.02)
		"keypad_laugh":
			# a soft, wrong little laugh
			samples = S.seq([
				S.tone(520.0, 0.09, "tri", 0.3, 0.005, 0.04, 0.08, 9.0), S.silence(0.05),
				S.tone(470.0, 0.09, "tri", 0.28, 0.005, 0.04, 0.08, 9.0), S.silence(0.05),
				S.tone(400.0, 0.14, "tri", 0.26, 0.005, 0.08, 0.08, 9.0),
			])
		"door_unlock":
			samples = S.seq([S.tone(140.0, 0.07, "square", 0.4, 0.002, 0.03), S.silence(0.05), S.noise(0.04, 0.5, 0.7, 0.001, 0.02, 3)])
		"door_open":
			samples = S.mix([S.noise(0.3, 0.25, 0.3, 0.02, 0.2, 4), S.sweep(180.0, 90.0, 0.35, "tri", 0.2, 0.01, 0.2)])
		"thud_carpet_1":
			samples = S.sweep(85.0, 55.0, 0.07, "sine", 0.35, 0.002, 0.05)
		"thud_carpet_2":
			samples = S.sweep(75.0, 50.0, 0.06, "sine", 0.3, 0.002, 0.045)
		"thud_tile_1":
			samples = S.mix([S.sweep(150.0, 90.0, 0.05, "sine", 0.3, 0.001, 0.035), S.noise(0.02, 0.2, 0.8, 0.001, 0.015, 5)])
		"thud_tile_2":
			samples = S.mix([S.sweep(130.0, 80.0, 0.05, "sine", 0.28, 0.001, 0.035), S.noise(0.02, 0.18, 0.8, 0.001, 0.015, 6)])
		"thud_concrete_1":
			samples = S.mix([S.sweep(110.0, 65.0, 0.06, "sine", 0.32, 0.001, 0.04), S.noise(0.03, 0.15, 0.4, 0.001, 0.025, 7)])
		"thud_concrete_2":
			samples = S.mix([S.sweep(100.0, 60.0, 0.06, "sine", 0.3, 0.001, 0.04), S.noise(0.03, 0.13, 0.4, 0.001, 0.025, 8)])
		"clink":
			samples = S.mix([S.tone(1800.0, 0.06, "sine", 0.3, 0.001, 0.05), S.tone(2400.0, 0.04, "sine", 0.2, 0.001, 0.035)])
		"static_burst":
			samples = S.noise(0.15, 0.35, 1.0, 0.005, 0.05, 21)
		"laugh_track":
			# pitched noise bursts pretending to be an audience
			var bursts: Array = []
			var offs: Array = []
			for i in 14:
				bursts.append(S.noise(0.25, 0.12, 0.25 + 0.03 * (i % 5), 0.02, 0.18, 100 + i))
				offs.append(0.06 * i)
			samples = S.mix(bursts, offs)
		"trapdoor":
			samples = S.mix([S.sweep(220.0, 70.0, 0.25, "square", 0.35, 0.002, 0.1), S.noise(0.3, 0.3, 0.5, 0.01, 0.2, 31)])
		"fall_whistle":
			samples = S.sweep(1400.0, 300.0, 0.9, "sine", 0.25, 0.02, 0.2)
		"poof":
			samples = S.noise(0.25, 0.3, 0.2, 0.005, 0.2, 41)
		"bwomp":
			samples = S.sweep(300.0, 140.0, 0.35, "square", 0.3, 0.005, 0.15)
		"party_horn":
			samples = S.seq([S.tone(392.0, 0.18, "saw", 0.35, 0.01, 0.02, 0.15, 12.0), S.sweep(392.0, 587.0, 0.3, "saw", 0.35, 0.005, 0.1)])
		"puff":
			samples = S.noise(0.12, 0.25, 0.35, 0.003, 0.1, 43)
		"ding":
			samples = S.mix([S.tone(1320.0, 0.5, "sine", 0.3, 0.001, 0.45), S.tone(2640.0, 0.3, "sine", 0.1, 0.001, 0.28)])
		"bell":
			samples = S.mix([S.tone(880.0, 0.7, "sine", 0.35, 0.001, 0.6), S.tone(1760.0, 0.5, "sine", 0.15, 0.001, 0.45), S.tone(587.0, 0.7, "sine", 0.12, 0.001, 0.6)])
		"punch":
			samples = S.mix([S.noise(0.06, 0.5, 0.5, 0.001, 0.045, 51), S.sweep(200.0, 80.0, 0.09, "sine", 0.4, 0.001, 0.06)])
		"thwip":
			samples = S.sweep(2000.0, 400.0, 0.06, "sine", 0.4, 0.001, 0.02)
		"explosion":
			samples = S.mix([S.noise(0.7, 0.55, 0.25, 0.002, 0.55, 61), S.sweep(160.0, 40.0, 0.6, "sine", 0.5, 0.002, 0.5)])
		"splat":
			samples = S.mix([S.noise(0.12, 0.4, 0.45, 0.002, 0.09, 71), S.sweep(400.0, 150.0, 0.1, "sine", 0.25, 0.002, 0.08)])
		"beat":
			samples = S.sweep(150.0, 60.0, 0.08, "sine", 0.45, 0.001, 0.05)
		"perfect":
			samples = S.seq([S.tone(880.0, 0.06, "square", 0.22, 0.002, 0.02), S.tone(1174.66, 0.1, "square", 0.22, 0.002, 0.05)])
		"miss_buzz":
			samples = S.tone(130.0, 0.16, "square", 0.3, 0.002, 0.06, 0.1, 25.0)
		"swoosh":
			samples = S.noise(0.2, 0.3, 0.15, 0.05, 0.12, 81)
		"crowd_loop":
			samples = S.mix([S.noise(2.0, 0.1, 0.12, 0.3, 0.3, 91), S.noise(2.0, 0.06, 0.3, 0.5, 0.5, 92)])
			loop = true
		"heartbeat":
			samples = S.seq([S.sweep(120.0, 60.0, 0.1, "sine", 0.4, 0.002, 0.07), S.silence(0.12), S.sweep(110.0, 55.0, 0.09, "sine", 0.3, 0.002, 0.06), S.silence(0.4)])
		"whip_pan":
			samples = S.sweep(300.0, 1200.0, 0.25, "saw", 0.15, 0.02, 0.15)
		_:
			samples = S.tone(440.0, 0.1, "sine", 0.2)
	return S.to_wav(samples, loop)
