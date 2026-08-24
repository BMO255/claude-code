class_name TurquoiseOne
extends Node2D
## The Turquoise One: tall, thin, smooth, featureless except for a gentle
## fixed smile and the same triangular orange visor Dorko wears. It stands
## very still. The stillness is the point; the animation budget is spent on
## a barely-perceptible breath and one too-slow head tilt.

var _sprite: Sprite2D
var _t := 0.0
var _tilt_phase := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = AssetLib.get_or_build("tq_one_stand", _build_tex)
	_sprite.position = Vector2(0, -62)
	add_child(_sprite)


func _process(delta: float) -> void:
	_t += delta
	# breathing measured in furniture time
	_sprite.scale.y = 1.0 + sin(_t * 0.8) * 0.006
	# every ~9 seconds the head considers a tilt, does one, regrets nothing
	_tilt_phase = fmod(_t, 9.0)
	if _tilt_phase < 2.0:
		_sprite.rotation = sin(_tilt_phase * PI / 2.0) * 0.02
	else:
		_sprite.rotation = 0.0


func _build_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(24, 62, 2)
	var tq := Color(0.22, 0.82, 0.76)
	var tq_dk := Color(0.1, 0.55, 0.5)
	var tq_hi := Color(0.45, 0.95, 0.88)
	# one long smooth form; no clothes, no seams, no doubts
	p.ellipse(12, 8, 6, 7, tq)                     # head
	p.poly(PackedVector2Array([
		Vector2(7, 12), Vector2(17, 12), Vector2(15, 44), Vector2(9, 44),
	]), tq)                                         # torso taper
	p.poly(PackedVector2Array([
		Vector2(9, 44), Vector2(15, 44), Vector2(14, 58), Vector2(10, 58),
	]), tq_dk)                                      # legs as a suggestion
	p.ellipse(12, 59, 4, 2, tq_dk)
	# arms: thin, held perfectly at the sides
	p.vline(6, 14, 22, tq_dk)
	p.vline(17, 14, 22, tq_dk)
	# sheen down one side
	p.vline(9, 14, 26, tq_hi)
	p.dot(9, 5, tq_hi)
	# the visor - Dorko's visor. that's the reveal.
	p.poly(PackedVector2Array([Vector2(6, 6), Vector2(18, 6), Vector2(12, 10)]), Color(1.0, 0.55, 0.1))
	p.line(6, 6, 18, 6, Color(0.62, 0.26, 0.0))
	p.line(6, 6, 12, 10, Color(0.62, 0.26, 0.0))
	p.line(18, 6, 12, 10, Color(0.62, 0.26, 0.0))
	p.dot(9, 7, Color(1.0, 0.85, 0.55))
	# the smile: gentle, fixed, immortal
	p.line(9, 12, 12, 13, Color(0.04, 0.3, 0.27))
	p.line(12, 13, 15, 12, Color(0.04, 0.3, 0.27))
	return p.tex()
