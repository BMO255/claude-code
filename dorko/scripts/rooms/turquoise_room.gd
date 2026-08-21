extends BaseRoom
## The Turquoise Room (spec 7.5). Small, perfectly clean, the opposite of
## everything above it. One chair. One figure. One very long speech, and then
## the shortest boxing match in recorded history.

var _figure: TurquoiseOne


func _room_config() -> void:
	room_id = "turquoise_room"
	music_name = "turquoise"
	footstep_surface = "tile"
	horizon_y = 190.0
	back_half = 200.0
	front_half = 330.0
	ambient_tint = Color(0.92, 1.02, 1.0)
	spawn_points = {
		"default": {"pos": Vector2(320, 320), "dir": "up"},
	}


func _room_setup() -> void:
	# flat, bright, flawless
	var wall := add_rect(Rect2(0, 0, 640, horizon_y), Color(0.2, 0.72, 0.68))
	add_parallax(wall, 0.4)  # barely any parallax; this room doesn't play along
	add_rect(Rect2(0, horizon_y - 4, 640, 4), Color(0.32, 0.85, 0.8), -750)
	add_floor("grid", Color(0.26, 0.78, 0.73), Color(0.16, 0.6, 0.56), 1.2)
	# the white chair (soon: where the door will be)
	var chair := add_prop(AssetLib.get_or_build("tq_chair", _build_chair_tex), Vector2(320, 210))
	add_hotspot({
		"name": "White Chair",
		"pos": Vector2(320, 208),
		"size": Vector2(40, 48),
		"look": "A white chair. Immaculate. Nobody has ever sat in it, and it has made peace with that.",
		"touch": func(): say("I'm not sitting. Sitting is how this house gets you."),
		"visual": chair,
		"interact": Vector2(320, 250),
	})
	_figure = TurquoiseOne.new()
	_figure.position = Vector2(320, 186)
	_figure.z_index = 200
	add_child(_figure)
	add_hotspot({
		"name": "The Turquoise One",
		"pos": Vector2(320, 150),
		"size": Vector2(60, 130),
		"look": "Tall. Smooth. Wearing my shades. Mine are mine. I checked — mine are still on my face. So whose are those.",
		"touch": func(): say("My hand said no before I did."),
		"on_talk": func(): say("It talks when it's ready. It's been getting ready for a long time."),
		"walk_required": false,
	})


func _on_room_entered() -> void:
	if GameState.get_flag("battle_won"):
		# A save landed here after the fight: the figure is gone, and the room
		# has no exits — carry the player forward into the conclusion.
		_figure.visible = false
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree():
			SceneRouter.goto_scene("res://scenes/ui/ending.tscn")
		return
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	# If the player got a look-line open in the first moment, wait it out —
	# giving up here would strand them in a room with no exits.
	while DialogueManager.active:
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
	if GameState.get_flag("monologue_done"):
		_to_battle()
		return
	DialogueManager.dialogue_finished.connect(_on_dialogue_done)
	DialogueManager.start("turquoise_monologue")


func _on_dialogue_done(id: String) -> void:
	if id != "turquoise_monologue":
		return
	DialogueManager.dialogue_finished.disconnect(_on_dialogue_done)
	GameState.set_flag("monologue_done")
	_to_battle()


func _to_battle() -> void:
	GameState.lock_input()
	Fx.flash(Color(1, 1, 1), 0.25)
	AudioBus.play_sfx("bell")
	var round_lbl := Label.new()
	round_lbl.text = "ROUND 1"
	round_lbl.position = Vector2(0, 140)
	round_lbl.size = Vector2(640, 80)
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_lbl.add_theme_font_size_override("font_size", 52)
	round_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	round_lbl.add_theme_color_override("font_shadow_color", Color(0.4, 0.05, 0.15))
	round_lbl.add_theme_constant_override("shadow_offset_x", 3)
	round_lbl.add_theme_constant_override("shadow_offset_y", 3)
	round_lbl.z_index = 900
	add_child(round_lbl)
	await get_tree().create_timer(1.3).timeout
	GameState.unlock_input()
	SceneRouter.goto_scene("res://scenes/minigames/battle.tscn")


func _build_chair_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(22, 26, 2)
	var white := Color(0.96, 0.97, 0.96)
	var shade := Color(0.78, 0.84, 0.82)
	p.rect(4, 2, 3, 14, white)     # back
	p.vline(4, 2, 14, shade)
	p.rect(4, 14, 14, 3, white)    # seat
	p.hline(4, 16, 14, shade)
	p.vline(5, 17, 8, white)       # legs
	p.vline(16, 17, 8, white)
	p.vline(16, 17, 8, shade)
	return p.tex()
