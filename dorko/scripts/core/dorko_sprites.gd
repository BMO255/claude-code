class_name DorkoSprites
extends RefCounted
## Generates Dorko's entire spritesheet in code: 4-direction walk (4 frames,
## 8 FPS) + idle (2 frames), drawn on a 24x36 virtual-pixel grid at 2x scale.
## Design: short green turtle guy, huge round green afro, orange shell with a
## pale rim, one wide triangular orange visor (eyes never visible), white
## tank top, small brown shoes.

const GRID_W := 24
const GRID_H := 36
const PX := 2

const SKIN := Color(0.45, 0.75, 0.35)
const SKIN_DARK := Color(0.12, 0.32, 0.12)
const FRO := Color(0.16, 0.5, 0.2)
const FRO_DARK := Color(0.06, 0.24, 0.08)
const SHELL := Color(0.95, 0.55, 0.12)
const SHELL_RIM := Color(0.99, 0.9, 0.72)
const SHELL_DARK := Color(0.55, 0.28, 0.04)
const VISOR := Color(1.0, 0.55, 0.1)
const VISOR_DARK := Color(0.62, 0.26, 0.0)
const VISOR_GLINT := Color(1.0, 0.85, 0.55)
const TANK := Color(0.95, 0.94, 0.9)
const TANK_DARK := Color(0.6, 0.58, 0.55)
const SHOE := Color(0.45, 0.3, 0.15)
const SHOE_DARK := Color(0.25, 0.15, 0.06)

static var _cached: SpriteFrames = null


static func build() -> SpriteFrames:
	if _cached:
		return _cached
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir in ["down", "up", "left", "right"]:
		frames.add_animation("walk_" + dir)
		frames.set_animation_speed("walk_" + dir, 8.0)
		frames.set_animation_loop("walk_" + dir, true)
		for f in 4:
			frames.add_frame("walk_" + dir, _frame(dir, f, true))
		frames.add_animation("idle_" + dir)
		frames.set_animation_speed("idle_" + dir, 2.0)
		frames.set_animation_loop("idle_" + dir, true)
		for f in 2:
			frames.add_frame("idle_" + dir, _frame(dir, f * 2, false))
	_cached = frames
	return frames


static func _frame(dir: String, frame: int, walking: bool) -> Texture2D:
	var p := Painter.new(GRID_W, GRID_H, PX)
	# The afro bobs on step frames (1 and 3); idle breathes on its second frame.
	var bob: int = 1 if (walking and (frame == 1 or frame == 3)) else (1 if (not walking and frame == 2) else 0)
	# Leg cycle: 0 = left forward, 1 = passing, 2 = right forward, 3 = passing.
	var step: int = [1, 0, -1, 0][frame] if walking else 0
	var draw_dir := dir
	if dir == "right":
		draw_dir = "left"  # drawn as left, mirrored below
	match draw_dir:
		"down":
			_body_front(p, bob, step, true)
		"up":
			_body_front(p, bob, step, false)
		"left":
			_body_side(p, bob, step)
	_afro(p, 12 if draw_dir != "left" else 11, 8 + bob)
	if draw_dir == "down":
		_visor_front(p, bob)
	elif draw_dir == "left":
		_visor_side(p, bob)
	var img := p.img
	if dir == "right":
		img.flip_x()
	return ImageTexture.create_from_image(img)


static func _afro(p: Painter, cx: int, cy: int) -> void:
	# outline first, then the cluster of circles that makes it look picked-out
	p.circle(cx, cy, 8.6, FRO_DARK)
	p.circle(cx - 6, cy + 1, 4.4, FRO_DARK)
	p.circle(cx + 6, cy + 1, 4.4, FRO_DARK)
	p.circle(cx, cy - 4, 5.2, FRO_DARK)
	p.circle(cx, cy, 7.6, FRO)
	p.circle(cx - 5.5, cy + 1, 3.6, FRO)
	p.circle(cx + 5.5, cy + 1, 3.6, FRO)
	p.circle(cx, cy - 4, 4.2, FRO)
	# a few darker pores so it reads as hair, not a ball
	p.dot(cx - 3, cy - 2, FRO_DARK)
	p.dot(cx + 2, cy - 5, FRO_DARK)
	p.dot(cx + 4, cy + 2, FRO_DARK)
	p.dot(cx - 1, cy + 4, FRO_DARK)


static func _visor_front(p: Painter, bob: int) -> void:
	var y := 17 + bob
	p.poly(PackedVector2Array([Vector2(5, y), Vector2(19, y), Vector2(12, y + 5)]), VISOR)
	p.line(5, y, 19, y, VISOR_DARK)
	p.line(5, y, 12, y + 5, VISOR_DARK)
	p.line(19, y, 12, y + 5, VISOR_DARK)
	p.dot(9, y + 1, VISOR_GLINT)
	p.dot(10, y + 1, VISOR_GLINT)


static func _visor_side(p: Painter, bob: int) -> void:
	var y := 17 + bob
	# one pointed lens jutting past the profile
	p.poly(PackedVector2Array([Vector2(14, y), Vector2(14, y + 4), Vector2(3, y + 2)]), VISOR)
	p.line(14, y, 3, y + 2, VISOR_DARK)
	p.line(14, y + 4, 3, y + 2, VISOR_DARK)
	p.dot(10, y + 1, VISOR_GLINT)


## Shared front/back body. front=true shows face+tank; false shows the shell.
static func _body_front(p: Painter, bob: int, step: int, front: bool) -> void:
	var hy := 16 + bob
	# head
	p.rect(8, hy, 8, 7, SKIN)
	p.ellipse(12, hy + 6.5, 4.5, 2.0, SKIN)
	p.vline(7, hy + 1, 5, SKIN_DARK)
	p.vline(16, hy + 1, 5, SKIN_DARK)
	if front:
		p.hline(11, hy + 8, 2, SKIN_DARK)  # deadpan mouth
	# torso
	var ty := 24
	if front:
		p.rect(8, ty, 8, 6, TANK)
		p.vline(8, ty, 6, TANK_DARK)
		p.vline(15, ty, 6, TANK_DARK)
		# shell rim peeking around the sides
		p.vline(6, ty + 1, 4, SHELL)
		p.vline(17, ty + 1, 4, SHELL)
		p.dot(6, ty, SHELL_RIM)
		p.dot(17, ty, SHELL_RIM)
	else:
		# the shell owns the back view
		p.ellipse(12, ty + 3, 7.2, 4.8, SHELL_DARK)
		p.ellipse(12, ty + 3, 6.4, 4.0, SHELL)
		p.ellipse_outline(12, ty + 3, 6.4, 4.0, SHELL_RIM)
		p.ellipse_outline(12, ty + 3, 3.6, 2.2, SHELL_DARK)
	# arms swing opposite the legs
	var arm_l := ty + 1 + (1 if step > 0 else 0)
	var arm_r := ty + 1 + (1 if step < 0 else 0)
	p.vline(6 if front else 5, arm_l, 4, SKIN)
	p.vline(17 if front else 18, arm_r, 4, SKIN)
	# legs + shoes: a lifted foot rises one pixel
	var lift_l: int = 1 if step > 0 else 0
	var lift_r: int = 1 if step < 0 else 0
	p.rect(9, 30 - lift_l, 2, 3 + lift_l, SKIN)
	p.rect(13, 30 - lift_r, 2, 3 + lift_r, SKIN)
	p.rect(8, 33 - lift_l, 4, 2, SHOE)
	p.rect(12, 33 - lift_r, 4, 2, SHOE)
	p.hline(8, 34 - lift_l, 4, SHOE_DARK)
	p.hline(12, 34 - lift_r, 4, SHOE_DARK)


static func _body_side(p: Painter, bob: int, step: int) -> void:
	var hy := 16 + bob
	# head profile (facing left)
	p.rect(7, hy, 8, 7, SKIN)
	p.ellipse(11, hy + 6.5, 4.0, 2.0, SKIN)
	p.dot(6, hy + 3, SKIN)  # snout bump
	# shell hump on the back
	var ty := 24
	p.ellipse(16, ty + 2.5, 4.6, 5.0, SHELL_DARK)
	p.ellipse(16, ty + 2.5, 3.8, 4.2, SHELL)
	p.ellipse_outline(16, ty + 2.5, 3.8, 4.2, SHELL_RIM)
	# torso in front of the shell
	p.rect(8, ty, 6, 6, TANK)
	p.vline(8, ty, 6, TANK_DARK)
	# one visible arm, swinging with the far leg
	p.vline(10 + step, ty + 1, 4, SKIN)
	# legs scissor horizontally in profile
	var near_x := 11 + step * 2
	var far_x := 11 - step * 2
	p.rect(far_x, 30, 2, 3, SKIN.darkened(0.25))
	p.rect(far_x - 1, 33, 4, 2, SHOE.darkened(0.25))
	p.rect(near_x, 30, 2, 3, SKIN)
	p.rect(near_x - 1, 33, 4, 2, SHOE)
	p.hline(near_x - 1, 34, 4, SHOE_DARK)
