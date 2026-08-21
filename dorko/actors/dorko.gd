class_name Dorko
extends Node2D
## The player. WASD movement clamped to the room's walk polygon (speed scales
## with depth), click-to-walk via NavigationAgent2D with an on-arrival action,
## 4-direction generated sprite animation, afro bob, shadow, footsteps.

const BASE_SPEED := 110.0

var room: BaseRoom = null
var facing := "down"
var control_enabled := true    # cutscenes flip this off

var sprite: AnimatedSprite2D
var shadow: Sprite2D
var agent: NavigationAgent2D

var _nav_active := false
var _nav_target := Vector2.ZERO
var _straight_mode := false    # fallback when the nav map has no path
var _on_arrive := Callable()


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.texture = AssetLib.tex("shadow")
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = DorkoSprites.build()
	sprite.position = Vector2(0, -35)
	add_child(sprite)
	sprite.frame_changed.connect(_on_frame_changed)
	agent = NavigationAgent2D.new()
	agent.path_desired_distance = 4.0
	agent.target_desired_distance = 5.0
	add_child(agent)
	sprite.play("idle_" + facing)


func _physics_process(delta: float) -> void:
	if room == null:
		return
	var locked := not control_enabled or GameState.is_input_locked() \
		or DialogueManager.active or SceneRouter.transitioning or SceneRouter.has_overlay()
	var input_dir := Vector2.ZERO
	if not locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() > 0.2:
		stop()  # WASD overrides any pending click-walk
		_step(input_dir.normalized(), delta)
		_walk_anim(input_dir)
	elif _nav_active:
		_follow_nav(delta)
	else:
		_idle_anim()


func _step(dir: Vector2, delta: float) -> void:
	# Depth-scaled speed: smaller (farther) Dorko moves slower on screen.
	var speed := BASE_SPEED * scale.x
	var motion := dir * speed * delta
	var target := position + motion
	if room.point_walkable(target):
		position = target
	elif room.point_walkable(position + Vector2(motion.x, 0)):
		position += Vector2(motion.x, 0)
	elif room.point_walkable(position + Vector2(0, motion.y)):
		position += Vector2(0, motion.y)


func _follow_nav(delta: float) -> void:
	var next: Vector2
	if _straight_mode:
		next = _nav_target
	else:
		if agent.is_navigation_finished():
			# Either we're there, or the nav map had no path (empty first-frame
			# map, unbaked region…). If we're still far away, walk straight.
			if position.distance_to(_nav_target) > 12.0 and not _straight_mode:
				_straight_mode = true
				return
			_arrive()
			return
		next = agent.get_next_path_position()
	var to := next - position
	var speed := BASE_SPEED * scale.x
	if _straight_mode and to.length() < 4.0:
		_arrive()
		return
	var dir := to.normalized()
	var motion := dir * minf(speed * delta, to.length())
	var stepped := position + motion
	if room.point_walkable(stepped):
		position = stepped
	elif room.point_walkable(position + Vector2(motion.x, 0)):
		position += Vector2(motion.x, 0)
	elif room.point_walkable(position + Vector2(0, motion.y)):
		position += Vector2(0, motion.y)
	else:
		_arrive()  # wedged against the walk-area edge; close enough
		return
	_walk_anim(dir)


func walk_to(target: Vector2, on_arrive := Callable()) -> void:
	_on_arrive = on_arrive
	_nav_target = target
	_straight_mode = false
	_nav_active = true
	agent.target_position = target


func stop() -> void:
	_nav_active = false
	_straight_mode = false
	_on_arrive = Callable()


func _arrive() -> void:
	_nav_active = false
	_straight_mode = false
	var cb := _on_arrive
	_on_arrive = Callable()
	_idle_anim()
	if cb.is_valid():
		cb.call()


func teleport(pos: Vector2, face := "") -> void:
	stop()
	position = pos
	if face != "":
		facing = face
	_idle_anim()


func face_towards(point: Vector2) -> void:
	var d := point - position
	if abs(d.x) > abs(d.y):
		facing = "left" if d.x < 0 else "right"
	else:
		facing = "up" if d.y < 0 else "down"
	_idle_anim()


func _walk_anim(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		facing = "left" if dir.x < 0 else "right"
	else:
		facing = "up" if dir.y < 0 else "down"
	if sprite.animation != "walk_" + facing:
		sprite.play("walk_" + facing)


func _idle_anim() -> void:
	if sprite.animation != "idle_" + facing or not sprite.is_playing():
		sprite.play("idle_" + facing)


func _on_frame_changed() -> void:
	# A footstep lands on the two "contact" frames of each walk cycle.
	if String(sprite.animation).begins_with("walk_") and (sprite.frame == 1 or sprite.frame == 3):
		if room:
			AudioBus.footstep(room.footstep_surface)
