class_name BlueBomb
extends Node2D
## The Blue Bomb: a spherical navy fellow with a wind-up key in his back, big
## anxious eyes, and a fuse that has been "about to go" since '94. Original
## design, bob-omb-adjacent the way a nervous grape is balloon-adjacent.
##
## States (driven by flags): key turns until key_jammed; the fuse sparks until
## fuse_wet (then smolders); after bomb_defused he stands and does a relieved
## little bounce.

var _body: Sprite2D
var _key: Sprite2D
var _spark: Node2D
var _key_angle := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 94
	_body = Sprite2D.new()
	_body.position = Vector2(0, -30)
	add_child(_body)
	_key = Sprite2D.new()
	_key.texture = _key_tex()
	_key.position = Vector2(-24, -34)
	add_child(_key)
	_spark = Node2D.new()
	_spark.position = Vector2(4, -64)
	var glow := Sprite2D.new()
	glow.texture = AssetLib.get_or_build("bomb_spark", _build_spark_tex)
	_spark.add_child(glow)
	add_child(_spark)
	refresh()


## Re-reads flags and swaps pose/parts. The room calls this after each step.
func refresh() -> void:
	var defused := GameState.get_flag("bomb_defused")
	_body.texture = _body_tex("stand" if defused else "sit")
	_key.visible = not defused
	_spark.visible = not GameState.get_flag("fuse_wet") and not defused
	if defused:
		_key_angle = 0.0


func _process(delta: float) -> void:
	_t += delta
	var defused := GameState.get_flag("bomb_defused")
	if defused:
		# the relieved bounce of a former explosive
		_body.position.y = -30.0 - absf(sin(_t * 2.4)) * 3.0
	else:
		# anxious micro-jitter
		_body.position.y = -30.0 + sin(_t * 9.0) * 0.4
		if not GameState.get_flag("key_jammed"):
			_key_angle += delta * 0.9  # winding him, always winding him
		_key.rotation = _key_angle
		if _spark.visible:
			_spark.position.x = 4.0 + sin(_t * 13.0) * 1.5
			_spark.scale = Vector2.ONE * (0.85 + 0.3 * absf(sin(_t * 11.0)))


func _body_tex(pose: String) -> Texture2D:
	return AssetLib.get_or_build("bomb_body_" + pose, func(): return _draw_body(pose))


func _draw_body(pose: String) -> Texture2D:
	var p: Painter = AssetLib.painter(36, 36, 2)
	var navy := Color(0.14, 0.19, 0.42)
	var navy_hi := Color(0.24, 0.32, 0.6)
	var navy_dk := Color(0.08, 0.11, 0.28)
	var standing := pose == "stand"
	var cy := 18 if not standing else 16
	# body sphere
	p.circle(18, cy, 13, navy_dk)
	p.circle(18, cy - 1, 12, navy)
	p.ellipse(14, cy - 6, 5, 3.5, navy_hi)   # sheen
	# fuse port + fuse
	p.rect(19, cy - 15, 4, 3, Color(0.5, 0.42, 0.3))
	p.line(21, cy - 15, 20, cy - 18, Color(0.72, 0.6, 0.4))
	# eyes: large, white, deeply concerned (relieved crescents when standing)
	if standing:
		p.circle(13, cy - 1, 3.5, Color.WHITE)
		p.circle(23, cy - 1, 3.5, Color.WHITE)
		p.hline(11, cy, 5, Color(0.1, 0.1, 0.15))
		p.hline(21, cy, 5, Color(0.1, 0.1, 0.15))
		# a small, unpracticed smile
		p.hline(16, cy + 6, 5, Color(0.05, 0.07, 0.2))
		p.dot(15, cy + 5, Color(0.05, 0.07, 0.2))
		p.dot(21, cy + 5, Color(0.05, 0.07, 0.2))
	else:
		p.circle(13, cy - 2, 4, Color.WHITE)
		p.circle(23, cy - 2, 4, Color.WHITE)
		p.circle(14, cy - 1, 1.3, Color(0.1, 0.1, 0.15))
		p.circle(22, cy - 1, 1.3, Color(0.1, 0.1, 0.15))
		p.hline(10, cy - 6, 3, navy_dk)          # worried brows
		p.hline(23, cy - 6, 3, navy_dk)
		p.ellipse(18, cy + 6, 2.5, 1.5, Color(0.06, 0.08, 0.22))  # small o mouth
		p.dot(28, cy - 5, Color(0.6, 0.8, 1.0))  # sweat
		p.dot(29, cy - 3, Color(0.6, 0.8, 1.0, 0.7))
	# feet
	if standing:
		p.ellipse(12, 33, 4, 2.5, navy_dk)
		p.ellipse(24, 33, 4, 2.5, navy_dk)
	else:
		p.ellipse(10, cy + 11, 4, 2.5, navy_dk)
		p.ellipse(26, cy + 11, 4, 2.5, navy_dk)
	return p.tex()


func _key_tex() -> Texture2D:
	return AssetLib.get_or_build("bomb_key", func():
		var p: Painter = AssetLib.painter(16, 16, 2)
		var grey := Color(0.72, 0.72, 0.78)
		p.ellipse_outline(5, 8, 3, 3, grey)
		p.ellipse_outline(11, 8, 3, 3, grey)
		p.rect(7, 7, 2, 2, grey)
		p.rect(7, 9, 2, 5, grey)
		return p.tex())


func _build_spark_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(10, 10, 2)
	p.dot(5, 5, Color(1.0, 0.9, 0.4))
	p.dot(4, 5, Color(1.0, 0.6, 0.15))
	p.dot(6, 5, Color(1.0, 0.6, 0.15))
	p.dot(5, 4, Color(1.0, 0.6, 0.15))
	p.dot(5, 6, Color(1.0, 0.6, 0.15))
	p.dot(3, 3, Color(1.0, 0.85, 0.35, 0.8))
	p.dot(7, 7, Color(1.0, 0.85, 0.35, 0.8))
	p.dot(7, 3, Color(1.0, 0.85, 0.35, 0.6))
	return p.tex()
