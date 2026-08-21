class_name Painter
extends RefCounted
## Tiny procedural pixel-art canvas. All coordinates are in "virtual pixels";
## each virtual pixel is rendered as a px-by-px block so art stays chunky at
## any size. Every generated texture in DORKO goes through this.

var img: Image
var vw: int
var vh: int
var px: int = 1

# Seeded so generated art is identical every run (and between save loads).
var rng := RandomNumberGenerator.new()


func _init(width: int, height: int, pixel_size: int = 1, bg: Color = Color(0, 0, 0, 0)) -> void:
	vw = width
	vh = height
	px = pixel_size
	rng.seed = 0xD02C0  # constant seed; art must be deterministic
	img = Image.create(width * px, height * px, false, Image.FORMAT_RGBA8)
	if bg.a > 0.0:
		img.fill(bg)


func dot(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= vw or y >= vh:
		return
	img.fill_rect(Rect2i(x * px, y * px, px, px), c)


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	var r := Rect2i(x * px, y * px, w * px, h * px).intersection(Rect2i(0, 0, vw * px, vh * px))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


func rect_outline(x: int, y: int, w: int, h: int, c: Color) -> void:
	rect(x, y, w, 1, c)
	rect(x, y + h - 1, w, 1, c)
	rect(x, y, 1, h, c)
	rect(x + w - 1, y, 1, h, c)


func hline(x: int, y: int, w: int, c: Color) -> void:
	rect(x, y, w, 1, c)


func vline(x: int, y: int, h: int, c: Color) -> void:
	rect(x, y, 1, h, c)


func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	# Bresenham on virtual pixels.
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy
	while true:
		dot(x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				dot(x, y, c)


func ellipse_outline(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	# Cheap outline: sample the perimeter densely.
	var steps: int = int(max(12.0, (rx + ry) * 4.0))
	for i in steps:
		var a := TAU * float(i) / float(steps)
		dot(int(round(cx + cos(a) * rx - 0.5)), int(round(cy + sin(a) * ry - 0.5)), c)


func circle(cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(cx, cy, r, r, c)


func poly(points: PackedVector2Array, c: Color) -> void:
	# Filled polygon via scanline test on virtual pixels (small canvases only).
	var min_y := 99999.0
	var max_y := -99999.0
	for p in points:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	for y in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		for x in vw:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				dot(x, y, c)


func speckle(x: int, y: int, w: int, h: int, c: Color, density: float, seed_val: int = 1) -> void:
	# Random single-pixel noise inside a rect; used for texture/grime.
	rng.seed = seed_val
	for i in int(w * h * density):
		dot(x + rng.randi_range(0, w - 1), y + rng.randi_range(0, h - 1), c)


func checker(x: int, y: int, w: int, h: int, cell: int, a: Color, b: Color) -> void:
	for yy in range(0, h):
		for xx in range(0, w):
			var even := ((xx / cell) + (yy / cell)) % 2 == 0
			dot(x + xx, y + yy, a if even else b)


func tex() -> ImageTexture:
	return ImageTexture.create_from_image(img)
