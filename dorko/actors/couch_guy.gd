class_name CouchGuy
extends Node2D
## The Couch Guy: a big round soft man in a grey fur ushanka, welded to the
## couch by time. He watches the TV. He raises a ramune bottle every 6–12
## seconds. He does not look at you. (Until the sandwich.)
##
## Poses: idle, drink1 (bottle rising), drink2 (head back, marble clink),
## turned (facing the room, the first time in years), bite (turned + sandwich).

var pose := "idle"
var drinking_enabled := true

var _sprite: Sprite2D
var _drink_timer: Timer


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = _tex("idle")
	# feet-line origin: the texture bottom sits on this node's position
	_sprite.position = Vector2(0, -44)
	add_child(_sprite)
	_drink_timer = Timer.new()
	_drink_timer.one_shot = true
	_drink_timer.timeout.connect(_do_drink)
	add_child(_drink_timer)
	_schedule_drink()


func set_pose(p: String) -> void:
	pose = p
	_sprite.texture = _tex(p)


func _schedule_drink() -> void:
	_drink_timer.start(randf_range(6.0, 12.0))


func _do_drink() -> void:
	# Never interrupt a cutscene pose; just try again later.
	if not drinking_enabled or pose != "idle":
		_schedule_drink()
		return
	set_pose("drink1")
	await get_tree().create_timer(0.45).timeout
	if pose != "drink1":
		return
	set_pose("drink2")
	AudioBus.play_sfx("clink", randf_range(0.95, 1.08), -4.0)
	await get_tree().create_timer(0.9).timeout
	if pose != "drink2":
		return
	set_pose("drink1")
	await get_tree().create_timer(0.3).timeout
	if pose != "drink1":
		return
	set_pose("idle")
	_schedule_drink()


# ---------------------------------------------------------------- drawing

func _tex(which: String) -> Texture2D:
	return AssetLib.get_or_build("couch_guy_" + which, func(): return _draw_pose(which))


func _draw_pose(which: String) -> Texture2D:
	var p: Painter = AssetLib.painter(44, 44, 2)
	var body := Color(0.72, 0.5, 0.35)      # a soft brown sweater situation
	var body_dark := Color(0.55, 0.36, 0.24)
	var skin := Color(0.9, 0.75, 0.6)
	var hat := Color(0.58, 0.58, 0.62)
	var hat_dark := Color(0.42, 0.42, 0.46)
	var facing_room := which == "turned" or which == "bite"
	var head_tilt: int = -2 if which == "drink2" else 0

	# body: a big round mass that has accepted the couch's terms
	p.ellipse(22, 32, 16, 11, body_dark)
	p.ellipse(22, 31, 15, 10, body)
	p.hline(10, 36, 24, body_dark)
	# legs barely exist; two soft shapes at the front
	p.ellipse(14, 41, 5, 2.5, body_dark)
	p.ellipse(30, 41, 5, 2.5, body_dark)

	# head
	var hx := 22
	var hy := 14 + head_tilt
	p.circle(hx, hy, 9, skin)
	# ushanka: dome + ear flaps down
	p.ellipse(hx, hy - 5, 10, 5.5, hat)
	p.ellipse(hx, hy - 7, 8, 3.5, hat_dark)
	p.rect(hx - 11, hy - 4, 4, 11, hat)
	p.rect(hx + 7, hy - 4, 4, 11, hat)
	p.speckle(hx - 10, hy - 9, 20, 6, Color(0.7, 0.7, 0.74), 0.3, 5)
	p.speckle(hx - 11, hy - 3, 4, 9, Color(0.7, 0.7, 0.74), 0.25, 6)
	p.speckle(hx + 7, hy - 3, 4, 9, Color(0.7, 0.7, 0.74), 0.25, 7)
	# the red star, front and center on the ushanka
	var star := Color(0.85, 0.15, 0.12)
	p.dot(hx, hy - 7, star)
	p.dot(hx - 1, hy - 6, star)
	p.dot(hx, hy - 6, star)
	p.dot(hx + 1, hy - 6, star)
	p.dot(hx - 1, hy - 5, star)
	p.dot(hx + 1, hy - 5, star)
	p.dot(hx, hy - 5, Color(1.0, 0.4, 0.35))  # glint at the heart of the star

	if facing_room:
		# the turn: full face, eyes open wider than you'd like
		p.circle(hx - 3, hy, 2.2, Color.WHITE)
		p.circle(hx + 3, hy, 2.2, Color.WHITE)
		p.circle(hx - 3, hy + 1, 1.0, Color(0.15, 0.1, 0.08))
		p.circle(hx + 3, hy + 1, 1.0, Color(0.15, 0.1, 0.08))
		if which == "bite":
			# sandwich, mid-commitment
			p.rect(hx - 4, hy + 4, 8, 3, Color(0.94, 0.85, 0.65))
			p.hline(hx - 4, hy + 5, 8, Color(0.92, 0.6, 0.65))
			p.hline(hx - 2, hy + 4, 4, Color(1.0, 0.85, 0.3))
		else:
			p.hline(hx - 1, hy + 5, 3, Color(0.5, 0.35, 0.25))
	else:
		# profile-ish toward the TV (screen-left): lidded eye, flat mouth
		p.hline(hx - 6, hy - 1, 4, Color(0.45, 0.3, 0.2))
		p.dot(hx - 5, hy, Color(0.15, 0.1, 0.08))
		p.hline(hx - 6, hy + 5, 3, Color(0.5, 0.35, 0.25))
		p.dot(hx + 6, hy + 2, Color(0.8, 0.62, 0.48))  # far ear hint

	# arms + the ramune bottle
	var bottle := Color(0.45, 0.7, 0.95)
	var bottle_hi := Color(0.7, 0.88, 1.0)
	match which:
		"idle":
			p.ellipse(9, 30, 3.5, 6, body)          # left arm resting
			p.ellipse(34, 31, 3.5, 6, body)         # right arm holds bottle on knee
			p.rect(33, 24, 3, 7, bottle)
			p.dot(34, 26, Color(0.9, 0.97, 1.0))    # the marble, watching
			p.dot(34, 23, bottle_hi)
		"drink1":
			p.ellipse(9, 30, 3.5, 6, body)
			p.ellipse(32, 25, 3.5, 6, body)         # arm rising
			p.rect(30, 15, 3, 8, bottle)
			p.dot(31, 17, Color(0.9, 0.97, 1.0))
		"drink2":
			p.ellipse(9, 30, 3.5, 6, body)
			p.ellipse(30, 20, 3.5, 6, body)         # arm up, head back
			p.rect(27, 8 + head_tilt, 3, 9, bottle)
			p.dot(28, 10 + head_tilt, Color(0.9, 0.97, 1.0))
			p.dot(28, 7 + head_tilt, bottle_hi)
		"turned", "bite":
			p.ellipse(9, 30, 3.5, 6, body)
			p.ellipse(35, 30, 3.5, 6, body)
	return p.tex()
