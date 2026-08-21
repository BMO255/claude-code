extends Control
## Main menu: wobbly hand-drawn title, New Game / Continue / Options / Quit.
## Also the entry point for the headless test harness (--room / --smoke).

const START_ROOM := "orange_room"

var _title_letters: Array = []
var _time := 0.0
var _menu_box: VBoxContainer
var _options_panel: PanelContainer


func _ready() -> void:
	_build_background()
	_build_title()
	_build_menu()
	_build_options()
	AudioBus.play_music("orange")
	if Boot.launch_room != "":
		var target := Boot.launch_room
		Boot.launch_room = ""
		GameState.new_game()
		call_deferred("_launch", target)
	elif Boot.smoke_test:
		Boot.smoke_test = false
		# The runner sits under root so it survives room transitions.
		var runner := Node.new()
		runner.set_script(load("res://tests/smoke_runner.gd"))
		get_tree().root.add_child.call_deferred(runner)
		runner.ready.connect(func(): runner.run())


func _launch(room: String) -> void:
	SceneRouter.goto_room(room)


func _build_background() -> void:
	# Orange-room-flavored gradient with a big sleeping silhouette.
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.75, 0.4, 0.12)
	add_child(bg)
	var floor_rect := ColorRect.new()
	floor_rect.position = Vector2(0, 230)
	floor_rect.size = Vector2(640, 130)
	floor_rect.color = Color(0.45, 0.28, 0.16)
	add_child(floor_rect)
	var glow := ColorRect.new()
	glow.position = Vector2(0, 200)
	glow.size = Vector2(640, 30)
	glow.color = Color(0.85, 0.5, 0.18)
	add_child(glow)
	# sleeping Dorko: shell + afro seen from the side, on the floor
	var doze := AssetLib.get_or_build("menu_doze", func():
		var p: Painter = AssetLib.painter(60, 30, 2)
		p.ellipse(38, 20, 14, 8, Color(0.55, 0.28, 0.04))
		p.ellipse(38, 19, 12, 7, Color(0.95, 0.55, 0.12))
		p.ellipse_outline(38, 19, 12, 7, Color(0.99, 0.9, 0.72))
		p.circle(14, 18, 9, Color(0.06, 0.24, 0.08))
		p.circle(14, 18, 8, Color(0.16, 0.5, 0.2))
		p.circle(8, 20, 4, Color(0.16, 0.5, 0.2))
		p.circle(20, 21, 4, Color(0.16, 0.5, 0.2))
		return p.tex())
	var doze_rect := TextureRect.new()
	doze_rect.texture = doze
	doze_rect.position = Vector2(430, 250)
	add_child(doze_rect)
	var z := Label.new()
	z.text = "z  z  z"
	z.position = Vector2(500, 226)
	z.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 0.8))
	add_child(z)


func _build_title() -> void:
	var letters := "DORKO"
	for i in letters.length():
		var lbl := Label.new()
		lbl.text = letters[i]
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 0.3))
		lbl.add_theme_color_override("font_shadow_color", Color(0.4, 0.1, 0.3))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		lbl.position = Vector2(200 + i * 48, 50)
		lbl.pivot_offset = Vector2(16, 28)
		add_child(lbl)
		_title_letters.append(lbl)
	var sub := Label.new()
	sub.text = "you were supposed to be somewhere"
	sub.position = Vector2(228, 120)
	sub.add_theme_color_override("font_color", Color(1, 0.85, 0.55, 0.7))
	add_child(sub)


func _process(delta: float) -> void:
	_time += delta
	# hand-drawn wobble: each letter drifts and tilts on its own beat
	for i in _title_letters.size():
		var lbl: Label = _title_letters[i]
		lbl.position.y = 50.0 + sin(_time * 2.2 + i * 1.4) * 3.0
		lbl.rotation = sin(_time * 1.7 + i * 2.1) * 0.06


func _build_menu() -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.position = Vector2(250, 160)
	_menu_box.custom_minimum_size = Vector2(140, 0)
	_menu_box.add_theme_constant_override("separation", 6)
	add_child(_menu_box)
	var completed := GameState.get_flag("game_completed")
	_add_button("New Game" if not completed else "Play Again", _on_new_game)
	if GameState.has_save() and not completed:
		_add_button("Continue", _on_continue)
	_add_button("Options", _on_options)
	_add_button("Quit", _on_quit)


func _add_button(text: String, handler: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.07, 0.16, 0.9)
	style.border_color = Color(1.0, 0.55, 0.1)
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(0.3, 0.15, 0.35, 0.95)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.mouse_entered.connect(func(): AudioBus.play_sfx("tick", 1.2, -10.0))
	btn.pressed.connect(handler)
	_menu_box.add_child(btn)


func _on_new_game() -> void:
	AudioBus.play_sfx("click")
	GameState.new_game()
	GameState.delete_save()
	SceneRouter.goto_room(START_ROOM if ResourceLoader.exists(SceneRouter.ROOMS[START_ROOM]) else "dev_room")


func _on_continue() -> void:
	AudioBus.play_sfx("click")
	var room := GameState.load_game()
	if room != "" and SceneRouter.ROOMS.has(room):
		SceneRouter.goto_room(room, GameState.current_spawn)
	else:
		_on_new_game()


func _on_options() -> void:
	AudioBus.play_sfx("click")
	_options_panel.visible = not _options_panel.visible


func _on_quit() -> void:
	get_tree().quit()


# ------------------------------------------------------------------ options

func _build_options() -> void:
	_options_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.05, 0.11, 0.97)
	style.border_color = Color(0.5, 0.9, 0.4)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	_options_panel.add_theme_stylebox_override("panel", style)
	_options_panel.position = Vector2(420, 150)
	_options_panel.visible = false
	add_child(_options_panel)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(180, 0)
	_options_panel.add_child(vbox)

	_add_slider(vbox, "Master", "master_vol", 0.0, 1.0)
	_add_slider(vbox, "Music", "music_vol", 0.0, 1.0)
	_add_slider(vbox, "SFX", "sfx_vol", 0.0, 1.0)
	_add_slider(vbox, "Text Speed", "text_speed", 15.0, 90.0)
	_add_check(vbox, "VHS Filter", "vhs_filter")
	_add_check(vbox, "Fullscreen", "fullscreen")
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func():
		GameState.save_settings()
		_options_panel.visible = false)
	vbox.add_child(back)


func _add_slider(parent: Node, label_text: String, key: String, lo: float, hi: float) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	parent.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = (hi - lo) / 100.0
	slider.value = GameState.settings.get(key, hi)
	slider.value_changed.connect(func(v):
		GameState.settings[key] = v
		GameState.apply_settings())
	parent.add_child(slider)


func _add_check(parent: Node, label_text: String, key: String) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = GameState.settings.get(key, true)
	check.toggled.connect(func(v):
		GameState.settings[key] = v
		GameState.apply_settings())
	parent.add_child(check)
