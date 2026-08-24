class_name BaseRoom
extends Node2D
## Every room extends this. Provides: the pseudo-3D floor (perspective-mapped
## texture + matching NavigationRegion2D walk area), depth sorting (characters
## scale 0.55 at the back wall to 1.1 at the front edge), wall parallax,
## hotspot creation + centralized mouse picking, spawn points, and Dorko.
##
## Subclasses override _room_config() (set fields), _room_setup() (build the
## scenery + hotspots) and _on_room_entered() (opening beats). Never _ready().

# ---- configuration (set in _room_config) ------------------------------------
var room_id := "room"
var music_name := ""
var footstep_surface := "carpet"   # carpet | tile | concrete
var ambient_tint := Color(1, 1, 1)

var horizon_y := 195.0             # screen y of the wall/floor seam
var back_half := 175.0             # half-width of the floor at the back
var front_half := 345.0            # half-width at the screen's bottom edge
var floor_center_x := 320.0
var scale_back := 0.55
var scale_front := 1.1
var parallax_max := 3.0            # px of wall shift at the room's edge
var spawn_dorko_enabled := true

var walk_poly := PackedVector2Array()   # computed from floor if left empty
var spawn_points: Dictionary = {}       # id -> {"pos": Vector2, "dir": "down"}

# ---- runtime ----------------------------------------------------------------
var dorko: Dorko = null
var bg: Node2D
var props: Node2D
var hotspots_node: Node2D
var actors: Node2D

var _depth_nodes: Array = []       # [node, base_scale]
var _parallax_layers: Array = []   # [node, factor, base_x]
var _clicks: Array = []
var _hover: Hotspot = null


func _ready() -> void:
	_room_config()
	_build_base()
	_room_setup()
	if spawn_dorko_enabled:
		_spawn_dorko()
	if music_name != "":
		AudioBus.play_music(music_name)
	_on_room_entered()


# ---- subclass hooks ---------------------------------------------------------

func _room_config() -> void:
	pass


func _room_setup() -> void:
	pass


func _on_room_entered() -> void:
	pass


# ---- construction helpers ---------------------------------------------------

func _build_base() -> void:
	bg = Node2D.new()
	bg.name = "BG"
	bg.z_index = -800
	add_child(bg)
	props = Node2D.new()
	props.name = "Props"
	add_child(props)
	hotspots_node = Node2D.new()
	hotspots_node.name = "Hotspots"
	add_child(hotspots_node)
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	if walk_poly.is_empty():
		walk_poly = default_walk_poly()
	_build_nav_region()
	if ambient_tint != Color(1, 1, 1):
		var cm := CanvasModulate.new()
		cm.color = ambient_tint
		add_child(cm)


func default_walk_poly(inset := 8.0) -> PackedVector2Array:
	var bottom := 356.0
	return PackedVector2Array([
		Vector2(floor_center_x - back_half + inset, horizon_y + inset),
		Vector2(floor_center_x + back_half - inset, horizon_y + inset),
		Vector2(floor_center_x + front_half - inset, bottom),
		Vector2(floor_center_x - front_half + inset, bottom),
	])


func _build_nav_region() -> void:
	var region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	# Triangulate the walk polygon directly - deterministic, no baking pass.
	nav_poly.vertices = walk_poly
	var indices := Geometry2D.triangulate_polygon(walk_poly)
	for i in range(0, indices.size() - 2, 3):
		nav_poly.add_polygon(PackedInt32Array([indices[i], indices[i + 1], indices[i + 2]]))
	region.navigation_polygon = nav_poly
	add_child(region)


## Standard pseudo-3D floor: perspective-projected pattern from AssetLib.
func add_floor(pattern: String, col_a: Color, col_b: Color, cell := 1.0, z_far := 3.0) -> Sprite2D:
	var h := int(362.0 - horizon_y)
	var t := AssetLib.floor_tex(room_id + "_" + pattern, {
		"w": 640, "h": h, "back_half": back_half, "front_half": front_half,
		"center_x": floor_center_x, "pattern": pattern, "col_a": col_a,
		"col_b": col_b, "cell": cell, "z_far": z_far,
	})
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = Vector2(0, horizon_y)
	s.z_index = -500
	bg.add_child(s)
	return s


func add_poly(points: PackedVector2Array, color: Color, z := -700) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.z_index = z
	bg.add_child(p)
	return p


func add_rect(r: Rect2, color: Color, z := -700) -> Polygon2D:
	return add_poly(PackedVector2Array([
		r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y),
	]), color, z)


## Sprite prop. z defaults to its ground line so depth layering works.
func add_prop(texture: Texture2D, pos: Vector2, z := -99999, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.centered = centered
	s.position = pos
	var ground_y := pos.y + (texture.get_height() / 2.0 if centered else float(texture.get_height()))
	s.z_index = int(ground_y) if z == -99999 else z
	props.add_child(s)
	return s


## Register a wall/background node for parallax (walls shift opposite Dorko).
func add_parallax(node: Node2D, factor := 1.0) -> void:
	_parallax_layers.append([node, factor, node.position.x])


## Register any Node2D for per-frame depth scale + z from its y position.
func register_depth(node: Node2D, base_scale := 1.0) -> void:
	_depth_nodes.append([node, base_scale])
	_apply_depth(node, base_scale)


func depth_scale(y: float) -> float:
	var bottom := 356.0
	var t: float = clamp((y - horizon_y) / max(1.0, bottom - horizon_y), 0.0, 1.0)
	return lerpf(scale_back, scale_front, t)


func _apply_depth(node: Node2D, base_scale: float) -> void:
	var s := depth_scale(node.position.y) * base_scale
	node.scale = Vector2(s, s)
	node.z_index = int(node.position.y)


## cfg: name, pos, size, [look, touch, use_item, talk, interact, walk_required,
##      visual, offset_z]. Returns the Hotspot.
func add_hotspot(cfg: Dictionary) -> Hotspot:
	var h := Hotspot.new()
	h.hotspot_name = cfg.get("name", "")
	h.position = cfg.get("pos", Vector2.ZERO)
	var size: Vector2 = cfg.get("size", Vector2(32, 32))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	h.add_child(shape)
	h.outline_size = size
	h.look = cfg.get("look", "")
	if cfg.has("touch"):
		h.on_touch = cfg.touch
	if cfg.has("use_item"):
		h.on_use_item = cfg.use_item
	if cfg.has("on_look"):
		h.on_look = cfg.on_look
	if cfg.has("on_talk"):
		h.on_talk = cfg.on_talk
	h.talk_dialogue_id = cfg.get("talk", "")
	h.interact_point = cfg.get("interact", Vector2(h.position.x, clamp(h.position.y, horizon_y + 12.0, 352.0)))
	h.walk_required = cfg.get("walk_required", true)
	h.visual = cfg.get("visual", null)
	hotspots_node.add_child(h)
	return h


## Doorway helper. cfg: name, pos, size, target, spawn, [look, condition
## (Callable -> bool), locked_line, on_exit (Callable, extra beat before go)].
func add_exit(cfg: Dictionary) -> Hotspot:
	var target: String = cfg.get("target", "")
	var spawn: String = cfg.get("spawn", "default")
	var condition: Callable = cfg.get("condition", Callable())
	var locked_line = cfg.get("locked_line", "It's not letting me through. Rude.")
	var go := func():
		if condition.is_valid() and not condition.call():
			DialogueManager.dorko(locked_line)
			return
		if cfg.has("on_exit"):
			cfg.on_exit.call()
		else:
			AudioBus.play_sfx("door_open")
			SceneRouter.goto_room(target, spawn)
	var merged := cfg.duplicate()
	merged["touch"] = go
	merged["look"] = cfg.get("look", "A way out. Or in. Depends which way you're facing.")
	return add_hotspot(merged)


func _spawn_dorko() -> void:
	dorko = Dorko.new()
	var sp: Dictionary = spawn_points.get(GameState.current_spawn, spawn_points.get("default", {}))
	dorko.position = sp.get("pos", Vector2(floor_center_x, horizon_y + 90.0))
	dorko.facing = sp.get("dir", "down")
	actors.add_child(dorko)
	dorko.room = self
	register_depth(dorko)


## Dorko-flavored one-liner (rooms use this constantly).
func say(text) -> void:
	DialogueManager.dorko(text)


# ---- per-frame work ---------------------------------------------------------

func _process(_delta: float) -> void:
	for entry in _depth_nodes:
		if is_instance_valid(entry[0]):
			_apply_depth(entry[0], entry[1])
	if dorko and not _parallax_layers.is_empty():
		var off: float = -(dorko.position.x - floor_center_x) / max(1.0, front_half) * parallax_max
		for layer_entry in _parallax_layers:
			if is_instance_valid(layer_entry[0]):
				layer_entry[0].position.x = layer_entry[2] + off * layer_entry[1]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_clicks.append(get_global_mouse_position())


func _physics_process(_delta: float) -> void:
	var blocked := GameState.is_input_locked() or DialogueManager.active \
		or SceneRouter.transitioning or SceneRouter.has_overlay()
	if blocked:
		_clicks.clear()
		_set_hover(null)
		return
	_set_hover(_hotspot_at(get_global_mouse_position()))
	while not _clicks.is_empty():
		var pos: Vector2 = _clicks.pop_front()
		var h := _hotspot_at(pos)
		if h:
			_interact(h)
		elif dorko:
			dorko.walk_to(clamp_to_walk(pos))


func _hotspot_at(pos: Vector2) -> Hotspot:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var best: Hotspot = null
	for hit in space.intersect_point(params, 16):
		var collider = hit.get("collider")
		if collider is Hotspot and collider.enabled:
			# Later-added hotspots win ties (they're "on top" visually).
			if best == null or collider.get_index() >= best.get_index():
				best = collider
	return best


func _set_hover(h: Hotspot) -> void:
	if _hover == h:
		return
	if _hover and is_instance_valid(_hover):
		_hover.set_hovered(false)
	_hover = h
	if _hover:
		_hover.set_hovered(true)
		CursorManager.set_hover_text(_hover.hotspot_name)
	else:
		CursorManager.set_hover_text("")


func _interact(h: Hotspot) -> void:
	var verb := CursorManager.verb
	if verb == CursorManager.VERB_EYE:
		h.do_look()  # looking works from any distance
		return
	if dorko == null or not h.walk_required \
		or dorko.position.distance_to(h.get_interact_point()) < 30.0:
		_perform(h, verb, CursorManager.item_id)
	else:
		var item := CursorManager.item_id
		dorko.walk_to(clamp_to_walk(h.get_interact_point()), func(): _perform(h, verb, item))


func _perform(h: Hotspot, verb: int, item: String) -> void:
	if not is_instance_valid(h) or not h.enabled:
		return
	if dorko:
		dorko.face_towards(h.global_position)
	match verb:
		CursorManager.VERB_HAND:
			h.do_touch()
		CursorManager.VERB_MOUTH:
			h.do_talk()
		CursorManager.VERB_ITEM:
			CursorManager.clear_item()
			h.do_use(item)


# ---- walkable-area math -----------------------------------------------------

func point_walkable(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, walk_poly)


## Nearest point inside the walk polygon (projection onto the closest edge).
func clamp_to_walk(p: Vector2) -> Vector2:
	if point_walkable(p):
		return p
	var best := p
	var best_d := INF
	for i in walk_poly.size():
		var a := walk_poly[i]
		var b := walk_poly[(i + 1) % walk_poly.size()]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	# nudge inward so float error doesn't leave us on the fence
	return best + (Vector2(floor_center_x, (horizon_y + 356.0) / 2.0) - best).normalized() * 1.5
