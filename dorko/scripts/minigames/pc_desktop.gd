extends Control
## "Winders XD" - the family computer (spec 7.1a). A full-screen fake-OS
## overlay pushed by the orange room via SceneRouter.push_overlay(); Esc (or
## Go > Shut Down) pops it. Everything on the desk is procedural: wallpaper,
## icons, chunky bevel windows, the hold music, and one voicemail that
## somebody meant to delete.
##
## Self-contained: references only autoloads + core classes. All texture keys
## are prefixed "pcdesk_".

const VM_TEXT := "Dorko. It's- listen. Don't go in the basement. I'm serious this time."
const ERROR_TEXT := "This program has performed an illegal operation and will be escorted out."
const ERROR_TITLES := ["Error", "Error (again)", "Error (final)"]
const DIARY_TEXT := """aug 3
practiced waving in the mirror. the mirror started first. good for the mirror.

aug 9
mom says the basement is just storage. the storage hums when the heater is off. boxes settling, probably.

aug 14 (?)
I keep forgetting my own birthday. I wrote it down somewhere small.

aug 21
counted the stairs. thirteen going down, twelve coming back up. decided not to count anymore."""

## Desktop items, in icon-column order. basement_key.png is appended at runtime.
const APPS := [
	["diary", "diary.txt"],
	["me", "me.bmp"],
	["sun", "sun.bmp"],
	["hold", "hold_music.wav"],
	["voicemail", "voicemail_3.wav"],
	["donotopen", "DO NOT OPEN.exe"],
	["recycle", "Recycle Bin"],
]

const FACE := Color(0.72, 0.8, 0.74)       # window plastic
const DESK_H := 334.0                       # taskbar starts here (360 - 26)
const WAVE_W := 188.0                       # media player waveform width (px)

var _icons_root: Control
var _windows_root: Control
var _taskbar: Control
var _task_box: HBoxContainer
var _go_menu: Control
var _clock_lbl: Label
var _shutdown_screen: Control

var _icons: Array = []                      # DesktopIcon list (selection group)
var _open_windows: Dictionary = {}          # app id -> XPWindow
var _spawn_count := 0
var _shutting_down := false

# The clock is wrong on purpose. It reads 25:61 and loses a minute every few
# seconds; at 25:58 it loses its nerve and snaps back up to 61.
var _clock_min := 61
var _clock_accum := 0.0

# DO NOT OPEN.exe escort procedure
var _error_dlg: XPWindow = null
var _error_count := 0
var _has_key_icon := false

# audio kept so it can be stopped on window close AND overlay exit
var _hold_player: AudioStreamPlayer = null
var _hold_btn: Button = null
var _hold_cursor: ColorRect = null
var _hold_time: Label = null
var _vm_player: AudioStreamPlayer = null
var _vm_label: Label = null
# static: synthesized once per app session, not once per overlay visit
# (the voicemail is ~10s of samples - regenerating it every PC boot hitches)
static var _vm_stream: AudioStreamWAV = null
static var _shutdown_wav: AudioStreamWAV = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_wallpaper()
	_icons_root = Control.new()
	_icons_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icons_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icons_root)
	_build_icons()
	_windows_root = Control.new()
	_windows_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_windows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_windows_root)
	_build_taskbar()
	_build_go_menu()
	_build_shutdown_screen()
	_boot_flash()


func _exit_tree() -> void:
	# The desk can be popped mid-song (room transition force-pops overlays);
	# don't leave the hold music haunting the SFX bus, and give the room its
	# music back if we silenced it.
	for p in [_hold_player, _vm_player]:
		if p != null and is_instance_valid(p):
			p.stop()
	AudioBus.resume_ducked()


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 4.0:
		_clock_accum = 0.0
		_clock_min -= 1
		if _clock_min < 58:
			_clock_min = 61
		if _clock_lbl and is_instance_valid(_clock_lbl):
			_clock_lbl.text = "25:%02d" % _clock_min
	# media player playhead follows the (looping) hold stream
	if _hold_player != null and is_instance_valid(_hold_player) \
		and _hold_cursor != null and is_instance_valid(_hold_cursor):
		var song_len := _hold_len()
		var pos := fmod(_hold_player.get_playback_position(), song_len)
		_hold_cursor.position.x = 10.0 + (pos / song_len) * WAVE_W
		if _hold_time != null and is_instance_valid(_hold_time):
			_hold_time.text = _fmt_time(pos) + " / " + _fmt_time(song_len)


func _unhandled_input(event: InputEvent) -> void:
	# Overlays own their Esc (UILayer deliberately ignores it while we're up).
	# Not while a dialogue (the sun, say) is holding court, though.
	if event.is_action_pressed("pause") and not DialogueManager.active:
		accept_event()
		_shutdown()


func _gui_input(event: InputEvent) -> void:
	# Clicks that reach the root missed every icon/window: deselect + close Go.
	if event is InputEventMouseButton and event.pressed:
		_go_menu.visible = false
		select_icon(null)


# ============================================================== construction

func _build_wallpaper() -> void:
	var wp := TextureRect.new()
	wp.texture = _wallpaper_tex()
	wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wp)


func _build_icons() -> void:
	for i in APPS.size():
		_add_icon(APPS[i][0], APPS[i][1], Vector2(6.0, 8.0 + 46.0 * float(i)))
	if GameState.get_flag("pc_curiosity"):
		# The escort already happened on an earlier visit; the file remembers.
		_has_key_icon = true
		_add_icon("basement_key", "basement_key.png", Vector2(64, 8))


func _add_icon(id: String, label: String, pos: Vector2) -> Control:
	var ic := DesktopIcon.new(self, id, label, _icon_tex(id))
	ic.position = pos
	_icons_root.add_child(ic)
	_icons.append(ic)
	return ic


func _build_taskbar() -> void:
	_taskbar = Control.new()
	_taskbar.position = Vector2(0, DESK_H)
	_taskbar.size = Vector2(640, 26)
	_taskbar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_taskbar)
	_taskbar.add_child(_bevel_panel(Vector2(640, 26), Color(0.16, 0.45, 0.4)))
	var go := _make_button("Go", Vector2(40, 19), Color(0.2, 0.66, 0.3), 10)
	go.position = Vector2(4, 3)
	go.pressed.connect(_toggle_go)
	_taskbar.add_child(go)
	_task_box = HBoxContainer.new()
	_task_box.position = Vector2(52, 4)
	_task_box.add_theme_constant_override("separation", 3)
	_taskbar.add_child(_task_box)
	var clock_box := _bevel_panel(Vector2(52, 18), Color(0.1, 0.3, 0.28), true)
	clock_box.position = Vector2(584, 4)
	_taskbar.add_child(clock_box)
	_clock_lbl = _make_label("25:61", Vector2(0, 3), Vector2(52, 12), 9, Color(0.5, 1.0, 0.85))
	_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_box.add_child(_clock_lbl)


func _build_go_menu() -> void:
	_go_menu = Control.new()
	_go_menu.size = Vector2(116, 66)
	_go_menu.position = Vector2(4, DESK_H - 66.0)
	_go_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_go_menu.visible = false
	add_child(_go_menu)
	_go_menu.add_child(_bevel_panel(Vector2(116, 66), FACE))
	var banner := ColorRect.new()
	banner.color = Color(0.13, 0.5, 0.32)
	banner.position = Vector2(2, 2)
	banner.size = Vector2(112, 14)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_go_menu.add_child(banner)
	var t := _make_label("WINDERS XD", Vector2(6, 3), Vector2(104, 11), 8, Color(0.85, 1.0, 0.9))
	_go_menu.add_child(t)
	var stuff := _make_button("My Stuff", Vector2(108, 20), Color(0.82, 0.88, 0.82), 9)
	stuff.position = Vector2(4, 20)
	stuff.pressed.connect(open_app.bind("mystuff"))
	_go_menu.add_child(stuff)
	var off := _make_button("Shut Down", Vector2(108, 20), Color(0.82, 0.88, 0.82), 9)
	off.position = Vector2(4, 42)
	off.pressed.connect(_shutdown)
	_go_menu.add_child(off)


func _build_shutdown_screen() -> void:
	_shutdown_screen = Control.new()
	_shutdown_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shutdown_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_shutdown_screen.visible = false
	add_child(_shutdown_screen)
	var black := ColorRect.new()
	black.color = Color(0.01, 0.02, 0.02)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shutdown_screen.add_child(black)
	var t := _make_label("It is now safe to stop looking at this.", Vector2(0, 168), Vector2(640, 16), 11, Color(0.4, 0.95, 0.75))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shutdown_screen.add_child(t)


func _boot_flash() -> void:
	AudioBus.play_sfx("chime_boot")
	var f := Control.new()
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color(0.01, 0.03, 0.03)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(black)
	var t := _make_label("WINDERS XD", Vector2(0, 146), Vector2(640, 30), 18, Color(0.35, 0.95, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(t)
	var s := _make_label("finding your files. they did not go anywhere.", Vector2(0, 182), Vector2(640, 14), 8, Color(0.5, 0.75, 0.65))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(s)
	add_child(f)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(f, "modulate:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


# ============================================================== desktop logic

func _toggle_go() -> void:
	_go_menu.visible = not _go_menu.visible


func select_icon(icon) -> void:
	for ic in _icons:
		if is_instance_valid(ic):
			ic.set_selected(ic == icon)
	if icon != null:
		AudioBus.play_sfx("tick", 1.0, -12.0)


func open_app(id: String) -> void:
	_go_menu.visible = false
	if _open_windows.has(id) and is_instance_valid(_open_windows[id]):
		_open_windows[id].restore_win()
		return
	match id:
		"diary":
			_open_diary()
		"me":
			_open_me()
		"sun":
			_open_sun()
		"hold":
			_open_hold()
		"voicemail":
			_open_voicemail()
		"recycle":
			_open_recycle()
		"basement_key":
			_open_key()
		"mystuff":
			_open_my_stuff()
		"donotopen":
			_open_donotopen()


func _register_window(id: String, w: XPWindow) -> void:
	w.on_closed = func(): _on_app_closed(id)
	_open_windows[id] = w
	w.position = _next_spawn_pos()
	_windows_root.add_child(w)
	w.pop_open()


func _next_spawn_pos() -> Vector2:
	# Classic cascade: each new window a step down-right, wrapping every 6.
	var p := Vector2(150.0, 34.0) + Vector2(22.0, 16.0) * float(_spawn_count % 6)
	_spawn_count += 1
	return p


func _on_app_closed(id: String) -> void:
	match id:
		"hold":
			if _hold_player != null and is_instance_valid(_hold_player):
				_hold_player.stop()
			_hold_player = null
			_hold_btn = null
			_hold_cursor = null
			_hold_time = null
			if not _open_windows.has("voicemail"):
				AudioBus.resume_ducked()
		"voicemail":
			if _vm_player != null and is_instance_valid(_vm_player):
				_vm_player.stop()
			_vm_player = null
			_vm_label = null
			if not _open_windows.has("hold"):
				AudioBus.resume_ducked()
	_open_windows.erase(id)


func add_task_button(win) -> Button:
	var b := _make_button(String(win.win_title).substr(0, 9), Vector2(64, 18), Color(0.22, 0.55, 0.48), 8)
	b.pressed.connect(_restore_from_task.bind(win))
	_task_box.add_child(b)
	return b


func _restore_from_task(win) -> void:
	if is_instance_valid(win):
		win.restore_win()


func _stop_all_audio() -> void:
	for p in [_hold_player, _vm_player]:
		if p != null and is_instance_valid(p):
			p.stop()
	_hold_player = null
	_vm_player = null


func _shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	_go_menu.visible = false
	_stop_all_audio()
	AudioBus.play_stream(_shutdown_stream(), 1.0, -4.0)
	_shutdown_screen.visible = true
	_shutdown_screen.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_shutdown_screen, "modulate:a", 1.0, 0.3)
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	SceneRouter.pop_overlay()


# ============================================================== app windows

func _open_diary() -> void:
	var w := XPWindow.new(self, "diary.txt - Notepal", Vector2(226, 164))
	w.content.add_child(_bevel_panel(Vector2(226, 164), Color(0.98, 0.97, 0.9), true))
	w.content.add_child(_make_label(DIARY_TEXT, Vector2(8, 5), Vector2(210, 154), 8, Color(0.14, 0.12, 0.16)))
	_register_window("diary", w)


func _open_me() -> void:
	var w := XPWindow.new(self, "me.bmp - Image Peeker", Vector2(140, 122))
	w.content.add_child(_bevel_panel(Vector2(140, 122), Color(0.93, 0.93, 0.88), true))
	var img := TextureRect.new()
	img.texture = _me_tex()
	img.position = Vector2(14, 8)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(img)
	w.content.add_child(_make_label("me.bmp  112 x 92  16 colors", Vector2(10, 106), Vector2(126, 12), 7, Color(0.4, 0.4, 0.42)))
	_register_window("me", w)


func _open_sun() -> void:
	var w := XPWindow.new(self, "sun.bmp - Image Peeker", Vector2(140, 122))
	w.content.add_child(_bevel_panel(Vector2(140, 122), Color(0.93, 0.93, 0.88), true))
	var img := TextureRect.new()
	img.texture = _sun_tex(false)   # loads the way it looks on the poster
	img.position = Vector2(10, 8)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(img)
	var caption := _make_label("sun.bmp  120 x 96  16 colors", Vector2(10, 106), Vector2(126, 12), 7, Color(0.4, 0.4, 0.42))
	w.content.add_child(caption)
	_register_window("sun", w)
	# 1.4s after the file "loads", the eyes finish loading too. From then on
	# the image takes clicks: you can talk to it. It was always going to talk.
	var awake := [false]
	img.gui_input.connect(func(event):
		if awake[0] and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not DialogueManager.active:
			DialogueManager.start("sun_bmp"))
	var open_eyes := func():
		if is_instance_valid(img):
			img.texture = _sun_tex(true)
			img.mouse_filter = Control.MOUSE_FILTER_STOP
			awake[0] = true
			if is_instance_valid(caption):
				caption.text = "sun.bmp is looking at you. click to speak."
				caption.add_theme_color_override("font_color", Color(0.6, 0.45, 0.1))
			AudioBus.play_sfx("tick", 0.7, -8.0)
	var tw := w.create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(open_eyes)
	# From then on it blinks about every six seconds. Watching back.
	var blink := w.create_tween()
	blink.set_loops()
	blink.tween_interval(6.0)
	blink.tween_callback(func(): img.texture = _sun_tex(false))
	blink.tween_interval(0.12)
	blink.tween_callback(func(): img.texture = _sun_tex(true))


func _open_hold() -> void:
	var w := XPWindow.new(self, "hold_music.wav - WinderAmp", Vector2(208, 92))
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.2, 0.22)
	bg.size = Vector2(208, 92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(bg)
	var wave := TextureRect.new()
	wave.texture = _wave_tex()
	wave.position = Vector2(10, 8)
	wave.mouse_filter = Control.MOUSE_FILTER_STOP
	wave.gui_input.connect(_on_wave_input)
	w.content.add_child(wave)
	_hold_cursor = ColorRect.new()
	_hold_cursor.color = Color(1.0, 0.95, 0.4)
	_hold_cursor.position = Vector2(10, 8)
	_hold_cursor.size = Vector2(2, 34)
	_hold_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(_hold_cursor)
	_hold_btn = _make_button("Pause", Vector2(46, 16), Color(0.25, 0.6, 0.5), 8)
	_hold_btn.position = Vector2(10, 50)
	_hold_btn.pressed.connect(_hold_toggle)
	w.content.add_child(_hold_btn)
	_hold_time = _make_label("0:00 / 0:00", Vector2(64, 52), Vector2(90, 12), 8, Color(0.7, 0.95, 0.85))
	w.content.add_child(_hold_time)
	w.content.add_child(_make_label("you are caller number 1. you have always been caller number 1.", Vector2(10, 72), Vector2(190, 14), 7, Color(0.45, 0.65, 0.6)))
	# The room music yields the floor while the hold music has it.
	AudioBus.duck_music()
	_hold_player = AudioBus.play_stream(AssetLib.music("hold"), 1.0, -4.0)
	_register_window("hold", w)


func _hold_toggle() -> void:
	if _hold_player == null or not is_instance_valid(_hold_player):
		return
	_hold_player.stream_paused = not _hold_player.stream_paused
	if _hold_btn != null and is_instance_valid(_hold_btn):
		_hold_btn.text = "Play" if _hold_player.stream_paused else "Pause"


func _on_wave_input(event: InputEvent) -> void:
	if _hold_player == null or not is_instance_valid(_hold_player):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Seek: restart the stream near the clicked spot. Near is plenty.
		var ratio := clampf(event.position.x / WAVE_W, 0.0, 1.0)
		_hold_player.stream_paused = false
		_hold_player.play(ratio * _hold_len())
		if _hold_btn != null and is_instance_valid(_hold_btn):
			_hold_btn.text = "Pause"
		AudioBus.play_sfx("tick", 1.3, -10.0)


func _hold_len() -> float:
	var s: AudioStream = _hold_player.stream
	if s == null:
		return 0.01
	return maxf(0.01, s.get_length())


func _fmt_time(s: float) -> String:
	return "%d:%02d" % [int(s / 60.0), int(s) % 60]


func _open_voicemail() -> void:
	var w := XPWindow.new(self, "voicemail_3.wav - Answering Machine", Vector2(224, 92))
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.16)
	bg.size = Vector2(224, 92)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(bg)
	var hdr := _make_label("message 3 of 3 - caller unknown - 0:10", Vector2(8, 5), Vector2(208, 12), 7, Color(0.5, 0.6, 0.6))
	w.content.add_child(hdr)
	_vm_label = _make_label(VM_TEXT, Vector2(8, 22), Vector2(208, 52), 9, Color(0.75, 0.95, 0.8))
	_vm_label.visible_characters = 0
	w.content.add_child(_vm_label)
	# Silence the room music for the length of the message.
	AudioBus.duck_music()
	_vm_player = AudioBus.play_stream(_voicemail_stream(), 1.0, -2.0)
	_register_window("voicemail", w)
	# Subtitles type out across the garble; the music comes back when the
	# voicemail is over (unless the hold music is also mid-performance).
	var tw := w.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(_vm_label, "visible_characters", VM_TEXT.length(), 8.8)
	tw.tween_callback(func():
		hdr.text = "end of message. the machine has nothing further."
		if not _open_windows.has("hold"):
			AudioBus.resume_ducked())


func _open_recycle() -> void:
	var w := XPWindow.new(self, "Recycle Bin", Vector2(196, 100))
	w.content.add_child(_bevel_panel(Vector2(196, 100), Color(0.97, 0.97, 0.93), true))
	w.content.add_child(_make_label("Name                    Size", Vector2(8, 4), Vector2(180, 11), 7, Color(0.45, 0.45, 0.5)))
	var line := ColorRect.new()
	line.color = Color(0.7, 0.7, 0.72)
	line.position = Vector2(6, 16)
	line.size = Vector2(184, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(line)
	var msg := _make_label("You can't throw yourself away, but you can try.", Vector2(16, 34), Vector2(164, 40), 8, Color(0.4, 0.42, 0.46))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.content.add_child(msg)
	w.content.add_child(_make_label("0 object(s)     0 KB", Vector2(8, 86), Vector2(180, 11), 7, Color(0.45, 0.45, 0.5)))
	_register_window("recycle", w)


func _open_key() -> void:
	var w := XPWindow.new(self, "basement_key.png - Image Peeker", Vector2(140, 108))
	w.content.add_child(_bevel_panel(Vector2(140, 108), Color(0.93, 0.93, 0.88), true))
	var img := TextureRect.new()
	img.texture = _key_tex()
	img.position = Vector2(14, 8)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(img)
	var lbl := _make_label("not yet.", Vector2(14, 40), Vector2(112, 14), 10, Color(0.8, 0.8, 0.75))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.content.add_child(lbl)
	_register_window("basement_key", w)


func _open_my_stuff() -> void:
	var entries: Array = []
	for e in APPS:
		entries.append(e)
	if _has_key_icon:
		entries.append(["basement_key", "basement_key.png"])
	var ch := 10.0 + 22.0 * float(entries.size())
	var w := XPWindow.new(self, "My Stuff", Vector2(170, ch))
	w.content.add_child(_bevel_panel(Vector2(170, ch), Color(0.97, 0.97, 0.93), true))
	for i in entries.size():
		var b := _make_button("  " + String(entries[i][1]), Vector2(158, 20), Color(0.9, 0.93, 0.9), 8)
		b.position = Vector2(6.0, 5.0 + 22.0 * float(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = _icon_tex(String(entries[i][0]))
		b.add_theme_constant_override("icon_max_width", 16)
		b.pressed.connect(open_app.bind(String(entries[i][0])))
		w.content.add_child(b)
	_register_window("mystuff", w)


func _open_donotopen() -> void:
	# The program runs instantly and is instantly in trouble.
	if _error_dlg != null and is_instance_valid(_error_dlg):
		_error_dlg.restore_win()
		return
	_error_count = 0
	_spawn_error_dialog()


func _spawn_error_dialog() -> void:
	AudioBus.play_sfx("error_dlg")
	var w := XPWindow.new(self, ERROR_TITLES[mini(_error_count, 2)], Vector2(224, 62))
	w.on_closed = _on_error_dismissed
	# Each respawn lands a little down-right of the last, like it's sidling
	# toward the door it claims to be escorted out of.
	w.position = Vector2(180.0, 86.0) + Vector2(26.0, 20.0) * float(_error_count)
	var ic := TextureRect.new()
	ic.texture = _err_tex()
	ic.position = Vector2(10, 14)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.content.add_child(ic)
	w.content.add_child(_make_label(ERROR_TEXT, Vector2(42, 4), Vector2(176, 38), 8, Color(0.12, 0.1, 0.12)))
	var ok := _make_button("OK", Vector2(56, 16), Color(0.62, 0.7, 0.66), 8)
	ok.position = Vector2(84, 44)
	ok.pressed.connect(w.close_win)
	w.content.add_child(ok)
	_error_dlg = w
	_windows_root.add_child(w)
	w.pop_open()


func _on_error_dismissed() -> void:
	_error_dlg = null
	_error_count += 1
	if _error_count < 3:
		_spawn_error_dialog()
	else:
		_reveal_basement_key()


func _reveal_basement_key() -> void:
	GameState.set_flag("pc_curiosity")
	if _has_key_icon:
		return
	_has_key_icon = true
	AudioBus.play_sfx("ding", 0.75, -4.0)
	var ic := _add_icon("basement_key", "basement_key.png", Vector2(64, 8))
	ic.pivot_offset = Vector2(26, 23)
	ic.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(ic, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UILayer.toast("1 new file. it was always going to arrive.")


# ============================================================== UI helpers

## Chunky 3D panel: light top/left, shadow bottom/right - plastic that has
## seen things. sunken=true swaps the bevel for inset areas (documents, clock).
func _bevel_panel(sz: Vector2, face: Color, sunken := false) -> Control:
	var root := Control.new()
	root.size = sz
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mk := func(pos: Vector2, s: Vector2, col: Color):
		var r := ColorRect.new()
		r.position = pos
		r.size = s
		r.color = col
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(r)
	var light := face.lightened(0.38)
	var dark := face.darkened(0.35)
	if sunken:
		var tmp := light
		light = dark
		dark = tmp
	mk.call(Vector2.ZERO, sz, face)
	mk.call(Vector2.ZERO, Vector2(sz.x, 2), light)
	mk.call(Vector2.ZERO, Vector2(2, sz.y), light)
	mk.call(Vector2(0, sz.y - 2.0), Vector2(sz.x, 2), dark)
	mk.call(Vector2(sz.x - 2.0, 0), Vector2(2, sz.y), dark)
	return root


func _make_button(text: String, sz: Vector2, bg: Color, font_size := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = sz
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var fg := Color(0.06, 0.1, 0.08) if bg.get_luminance() > 0.45 else Color(0.93, 0.98, 0.94)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = bg.darkened(0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = bg.darkened(0.15)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(func(): AudioBus.play_sfx("click", 1.15, -8.0))
	return b


func _make_label(text: String, pos: Vector2, sz: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================================================== textures

func _wallpaper_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_wallpaper", func():
		var p: Painter = AssetLib.painter(160, 90, 4)
		# rolling-hill default wallpaper: sky gradient + two hill ellipses
		var sky_top := Color(0.3, 0.72, 0.9)
		var sky_bot := Color(0.78, 0.95, 0.78)
		for y in 56:
			p.hline(0, y, 160, sky_top.lerp(sky_bot, float(y) / 55.0))
		p.ellipse(38, 14, 11, 3.5, Color(1, 1, 1, 0.9))
		p.ellipse(46, 12, 7, 2.5, Color(1, 1, 1, 0.85))
		p.ellipse(118, 22, 9, 2.5, Color(1, 1, 1, 0.8))
		p.rect(0, 54, 160, 36, Color(0.26, 0.68, 0.27))
		p.ellipse(112, 96, 85, 46, Color(0.2, 0.58, 0.24))    # far hill
		p.ellipse(36, 102, 78, 52, Color(0.3, 0.79, 0.3))     # near hill
		p.speckle(0, 60, 160, 30, Color(0.24, 0.6, 0.24), 0.04, 12)
		# a small door in the far hill; the wallpaper shipped like this
		p.rect(126, 58, 3, 6, Color(0.06, 0.1, 0.07))
		p.dot(128, 61, Color(0.8, 0.75, 0.3))
		return p.tex())


func _titlebar_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_titlebar", func():
		var p: Painter = AssetLib.painter(64, 8, 1)
		for x in 64:
			p.vline(x, 0, 8, Color(0.03, 0.3, 0.25).lerp(Color(0.2, 0.7, 0.45), float(x) / 63.0))
		p.hline(0, 0, 64, Color(0.35, 0.85, 0.6, 0.7))
		return p.tex())


func _icon_tex(id: String) -> Texture2D:
	return AssetLib.get_or_build("pcdesk_icon_" + id, func(): return _build_icon(id))


func _build_icon(id: String) -> Texture2D:
	var p := AssetLib.painter(12, 12, 2)
	var outline := Color(0.1, 0.12, 0.14)
	match id:
		"diary":
			p.rect(2, 1, 8, 10, Color(0.97, 0.96, 0.9))
			p.rect_outline(2, 1, 8, 10, Color(0.55, 0.55, 0.6))
			p.rect(8, 1, 2, 2, Color(0.8, 0.8, 0.75))
			p.vline(3, 2, 8, Color(0.95, 0.6, 0.6))
			p.hline(5, 4, 4, Color(0.4, 0.55, 0.85))
			p.hline(5, 6, 4, Color(0.4, 0.55, 0.85))
			p.hline(5, 8, 3, Color(0.4, 0.55, 0.85))
		"me":
			p.rect(1, 2, 10, 9, Color(0.95, 0.95, 0.9))
			p.rect_outline(1, 2, 10, 9, Color(0.5, 0.5, 0.55))
			p.rect(2, 3, 8, 5, Color(0.55, 0.8, 0.95))
			p.rect(2, 8, 8, 2, Color(0.35, 0.7, 0.3))
			p.circle(6, 5, 1.8, Color(0.14, 0.42, 0.18))
			p.rect(5, 6, 2, 2, Color(0.96, 0.82, 0.3))
		"sun":
			p.circle(6, 6, 3.5, Color(0.98, 0.85, 0.2))
			for d in [Vector2(6, 1), Vector2(6, 11), Vector2(1, 6), Vector2(11, 6), Vector2(2, 2), Vector2(10, 2), Vector2(2, 10), Vector2(10, 10)]:
				p.dot(int(d.x), int(d.y), Color(0.95, 0.6, 0.1))
			p.hline(4, 5, 2, outline)   # eyes shut. on the icon, anyway.
			p.hline(7, 5, 2, outline)
			p.hline(5, 8, 3, outline)
		"hold":
			p.circle(4, 9, 1.7, Color(0.12, 0.18, 0.4))
			p.vline(5, 3, 6, Color(0.12, 0.18, 0.4))
			p.hline(5, 3, 4, Color(0.12, 0.18, 0.4))
			p.dot(8, 4, Color(0.12, 0.18, 0.4))
			p.dot(10, 6, Color(0.2, 0.8, 0.7))
			p.dot(11, 5, Color(0.2, 0.8, 0.7))
		"voicemail":
			p.rect(2, 4, 8, 5, Color(0.35, 0.35, 0.4))
			p.rect_outline(2, 4, 8, 5, outline)
			p.dot(4, 6, Color(0.8, 0.8, 0.85))
			p.dot(8, 6, Color(0.8, 0.8, 0.85))
			p.dot(10, 3, Color(1.0, 0.25, 0.2))   # one message. always one.
		"donotopen":
			p.rect(1, 2, 10, 8, Color(0.8, 0.8, 0.85))
			p.rect_outline(1, 2, 10, 8, outline)
			p.hline(1, 2, 10, Color(0.25, 0.4, 0.7))
			p.circle(6, 6, 2.2, Color(0.85, 0.2, 0.2))
			p.line(5, 5, 7, 7, Color.WHITE)
			p.line(7, 5, 5, 7, Color.WHITE)
		"recycle":
			p.poly(PackedVector2Array([Vector2(3, 4), Vector2(9, 4), Vector2(8, 11), Vector2(4, 11)]), Color(0.55, 0.62, 0.68))
			p.hline(2, 3, 8, Color(0.45, 0.5, 0.56))
			p.dot(5, 7, Color(0.25, 0.65, 0.3))
			p.dot(7, 7, Color(0.25, 0.65, 0.3))
			p.dot(6, 9, Color(0.25, 0.65, 0.3))
		"basement_key":
			p.rect(1, 1, 10, 10, Color(0.05, 0.05, 0.06))
			p.speckle(1, 1, 10, 10, Color(0.1, 0.1, 0.13), 0.2, 5)
			p.ellipse_outline(4, 4, 1.5, 1.5, Color(0.22, 0.22, 0.27))
			p.line(5, 5, 8, 8, Color(0.22, 0.22, 0.27))
			p.dot(8, 7, Color(0.22, 0.22, 0.27))
		_:
			p.checker(0, 0, 12, 12, 2, Color.MAGENTA, Color.BLACK)
	return p.tex()


func _err_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_icon_err", func():
		var p: Painter = AssetLib.painter(12, 12, 2)
		p.circle(6, 6, 5, Color(0.85, 0.2, 0.2))
		p.ellipse_outline(6, 6, 5, 5, Color(0.45, 0.08, 0.08))
		p.line(4, 4, 8, 8, Color.WHITE)
		p.line(8, 4, 4, 8, Color.WHITE)
		return p.tex())


func _me_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_me_photo", func():
		var p: Painter = AssetLib.painter(56, 46, 2)
		# a polaroid-ish print: white border, wide bottom margin
		p.rect(0, 0, 56, 46, Color(0.96, 0.96, 0.9))
		p.rect(4, 4, 48, 34, Color(0.5, 0.78, 0.95))
		p.rect(4, 28, 48, 10, Color(0.35, 0.7, 0.3))
		# child Dorko: smaller afro, smaller shades, identical deadpan
		var fro := Color(0.16, 0.5, 0.2)
		var fro_dark := Color(0.08, 0.3, 0.1)
		p.circle(28, 14, 6, fro_dark)
		p.circle(24, 14, 3.5, fro)
		p.circle(32, 14, 3.5, fro)
		p.circle(28, 11, 4, fro)
		p.circle(28, 15, 4.5, fro)
		p.rect(24, 18, 9, 7, Color(0.96, 0.82, 0.3))
		p.poly(PackedVector2Array([Vector2(24, 19), Vector2(33, 19), Vector2(28, 22)]), Color(1.0, 0.55, 0.1))
		p.hline(27, 23, 3, Color(0.1, 0.25, 0.08))
		# the shirt clashes on purpose (it was a gift)
		p.rect(24, 25, 9, 6, Color(0.55, 0.3, 0.7))
		p.hline(24, 26, 9, Color(0.95, 0.85, 0.2))
		p.hline(24, 28, 9, Color(0.95, 0.85, 0.2))
		p.rect(26, 31, 2, 4, Color(0.2, 0.3, 0.15))
		p.rect(29, 31, 2, 4, Color(0.2, 0.3, 0.15))
		# two shadows. the photo only has one sun in it.
		p.ellipse(28, 36, 7, 1.5, Color(0, 0, 0, 0.3))
		p.ellipse(39, 35, 6, 1.2, Color(0, 0, 0, 0.22))
		# handwriting on the margin, too small to read, which is for the best
		p.hline(20, 41, 4, Color(0.5, 0.5, 0.55))
		p.hline(26, 41, 7, Color(0.5, 0.5, 0.55))
		p.hline(35, 42, 3, Color(0.5, 0.5, 0.55))
		return p.tex())


func _sun_tex(eyes_open: bool) -> Texture2D:
	var key := "pcdesk_sun_open" if eyes_open else "pcdesk_sun_closed"
	return AssetLib.get_or_build(key, func():
		var p: Painter = AssetLib.painter(60, 48, 2)
		var dark := Color(0.25, 0.18, 0.1)
		p.rect(0, 0, 60, 48, Color(0.93, 0.89, 0.72))
		p.rect_outline(0, 0, 60, 48, Color(0.75, 0.68, 0.5))
		for t in [Vector2(2, 2), Vector2(57, 2), Vector2(2, 45), Vector2(57, 45)]:
			p.dot(int(t.x), int(t.y), Color(0.4, 0.35, 0.3))
		p.circle(30, 22, 11, Color(0.98, 0.84, 0.2))
		p.ellipse_outline(30, 22, 11, 11, Color(0.8, 0.6, 0.1))
		for i in 12:
			var a := TAU * float(i) / 12.0
			p.line(int(round(30.0 + cos(a) * 13.0)), int(round(22.0 + sin(a) * 13.0)),
				int(round(30.0 + cos(a) * 17.0)), int(round(22.0 + sin(a) * 17.0)), Color(0.95, 0.62, 0.1))
		# the same gentle smile in both states - that's the problem
		p.hline(27, 28, 7, dark)
		p.dot(26, 27, dark)
		p.dot(34, 27, dark)
		p.dot(23, 25, Color(0.95, 0.6, 0.3))
		p.dot(38, 25, Color(0.95, 0.6, 0.3))
		if eyes_open:
			p.ellipse(26, 20, 2.2, 2.8, Color(0.98, 0.98, 0.95))
			p.ellipse(35, 20, 2.2, 2.8, Color(0.98, 0.98, 0.95))
			p.ellipse_outline(26, 20, 2.2, 2.8, dark)
			p.ellipse_outline(35, 20, 2.2, 2.8, dark)
			# pupils sit low and slightly inward: it is looking at the viewer
			p.dot(26, 21, Color(0.05, 0.05, 0.05))
			p.dot(35, 21, Color(0.05, 0.05, 0.05))
		else:
			p.hline(24, 20, 4, dark)
			p.dot(23, 19, dark)
			p.dot(28, 19, dark)
			p.hline(33, 20, 4, dark)
			p.dot(32, 19, dark)
			p.dot(37, 19, dark)
		return p.tex())


func _key_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_key_img", func():
		var p: Painter = AssetLib.painter(56, 40, 2)
		var shade := Color(0.16, 0.15, 0.18)
		p.rect(0, 0, 56, 40, Color(0.04, 0.04, 0.05))
		p.speckle(0, 0, 56, 40, Color(0.09, 0.09, 0.11), 0.25, 77)
		# a key, barely - one shade above the dark it lives in
		p.ellipse_outline(18, 20, 5, 5, shade)
		p.ellipse_outline(18, 20, 2.5, 2.5, shade)
		p.rect(23, 19, 14, 3, shade)
		p.rect(33, 22, 2, 3, shade)
		p.rect(36, 22, 2, 5, shade)
		return p.tex())


func _wave_tex() -> Texture2D:
	return AssetLib.get_or_build("pcdesk_waveform", func():
		var p: Painter = AssetLib.painter(94, 17, 2)
		p.rect(0, 0, 94, 17, Color(0.05, 0.1, 0.11))
		var wr := RandomNumberGenerator.new()
		wr.seed = 424242   # deterministic fake waveform
		for x in 94:
			var hh := 1 + wr.randi_range(0, 7) + wr.randi_range(0, 7)
			p.vline(x, 8 - int(hh / 2.0), hh, Color(0.2, 0.85, 0.7) if x % 2 == 0 else Color(0.15, 0.6, 0.5))
		return p.tex())


# ============================================================== synth audio

## ~10s of tape garble: hiss bed + speech-shaped saw blips + interference
## bursts where the tape eats a word. Deterministic; built once per session.
func _voicemail_stream() -> AudioStreamWAV:
	if _vm_stream != null:
		return _vm_stream
	var S := SfxSynth
	var rng := RandomNumberGenerator.new()
	rng.seed = 7003
	var parts: Array = []
	var offs: Array = []
	parts.append(S.noise(10.0, 0.05, 0.12, 0.3, 0.5, 300))
	offs.append(0.0)
	var t := 0.4
	while t < 9.0:
		# a "word": 2-5 quick pitched blips, then a breath of gap
		for i in rng.randi_range(2, 5):
			parts.append(S.tone(rng.randf_range(120.0, 340.0), rng.randf_range(0.05, 0.12), "saw", 0.1, 0.004, 0.03, 0.3, 22.0))
			offs.append(t)
			t += rng.randf_range(0.05, 0.11)
		t += rng.randf_range(0.15, 0.5)
	for i in 3:
		parts.append(S.noise(0.25, 0.18, 0.9, 0.01, 0.1, 400 + i))
		offs.append(2.0 + float(i) * 2.7)
	_vm_stream = S.to_wav(S.mix(parts, offs))
	return _vm_stream


## Power-down chime: the boot chime's tired inverse.
func _shutdown_stream() -> AudioStreamWAV:
	if _shutdown_wav != null:
		return _shutdown_wav
	var S := SfxSynth
	_shutdown_wav = S.to_wav(S.seq([
		S.tone(783.99, 0.14, "tri", 0.2, 0.01, 0.05),
		S.tone(587.33, 0.14, "tri", 0.2, 0.01, 0.05),
		S.tone(392.0, 0.2, "tri", 0.18, 0.01, 0.08),
		S.sweep(392.0, 60.0, 0.5, "sine", 0.22, 0.01, 0.35),
	]))
	return _shutdown_wav


# ============================================================== inner classes

## One draggable Winders window: bevel frame, gradient title bar, [_][X],
## scale-pop open/close, click-to-front. Content goes in `content`.
class XPWindow:
	extends Control

	const TITLE_H := 16
	const B := 3

	var desktop                      # the outer overlay (untyped by design)
	var win_title := ""
	var content: Control
	var on_closed := Callable()

	var _dragging := false
	var _drag_off := Vector2.ZERO
	var _task_btn: Button = null
	var _closing := false

	func _init(p_desktop, p_title: String, content_size: Vector2) -> void:
		desktop = p_desktop
		win_title = p_title
		size = Vector2(content_size.x + 2.0 * B, content_size.y + TITLE_H + 4.0 + 2.0 * B)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(desktop._bevel_panel(size, Color(0.72, 0.8, 0.74)))
		var tb := TextureRect.new()
		tb.texture = desktop._titlebar_tex()
		tb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tb.stretch_mode = TextureRect.STRETCH_SCALE
		tb.position = Vector2(B, B)
		tb.size = Vector2(size.x - 2.0 * B, TITLE_H)
		tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tb)
		var tl: Label = desktop._make_label(win_title, Vector2(B + 4.0, B + 2.0), Vector2(size.x - 46.0, 12), 8, Color(0.94, 1.0, 0.95))
		tl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		tl.add_theme_constant_override("shadow_offset_x", 1)
		tl.add_theme_constant_override("shadow_offset_y", 1)
		add_child(tl)
		var drag := Control.new()
		drag.position = Vector2(B, B)
		drag.size = Vector2(size.x - 2.0 * B - 34.0, TITLE_H)
		drag.mouse_filter = Control.MOUSE_FILTER_STOP
		drag.gui_input.connect(_on_title_input)
		add_child(drag)
		var min_btn: Button = desktop._make_button("_", Vector2(14, 12), Color(0.5, 0.72, 0.58), 8)
		min_btn.position = Vector2(size.x - 35.0, 5)
		min_btn.pressed.connect(minimize_win)
		add_child(min_btn)
		var close_btn: Button = desktop._make_button("X", Vector2(14, 12), Color(0.85, 0.35, 0.3), 8)
		close_btn.position = Vector2(size.x - 19.0, 5)
		close_btn.pressed.connect(close_win)
		add_child(close_btn)
		content = Control.new()
		content.position = Vector2(B, B + TITLE_H + 2.0)
		content.size = content_size
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(content)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			raise_win()

	func _on_title_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				raise_win()
				_dragging = true
				_drag_off = get_global_mouse_position() - global_position
			else:
				_dragging = false
		elif event is InputEventMouseMotion and _dragging:
			# follow the mouse, clamped so the title bar can never leave the desk
			var p := get_global_mouse_position() - _drag_off
			position = Vector2(clampf(p.x, 40.0 - size.x, 620.0), clampf(p.y, 0.0, 316.0))

	func raise_win() -> void:
		var par := get_parent()
		if par != null:
			par.move_child(self, par.get_child_count() - 1)

	func pop_open() -> void:
		pivot_offset = size / 2.0
		scale = Vector2(0.6, 0.6)
		modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.1)
		AudioBus.play_sfx("pop", 1.25, -8.0)

	func close_win() -> void:
		if _closing:
			return
		_closing = true
		if _task_btn != null and is_instance_valid(_task_btn):
			_task_btn.queue_free()
			_task_btn = null
		if on_closed.is_valid():
			on_closed.call()
		visible = true
		pivot_offset = size / 2.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "scale", Vector2(0.6, 0.6), 0.12)
		tw.tween_property(self, "modulate:a", 0.0, 0.12)
		tw.chain().tween_callback(queue_free)

	func minimize_win() -> void:
		if not visible or _closing:
			return
		visible = false
		_task_btn = desktop.add_task_button(self)

	func restore_win() -> void:
		if _closing:
			return
		if not visible:
			visible = true
			if _task_btn != null and is_instance_valid(_task_btn):
				_task_btn.queue_free()
				_task_btn = null
			pivot_offset = size / 2.0
			scale = Vector2(0.85, 0.85)
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2.ONE, 0.1)
		raise_win()


## A desktop icon: single click selects, double click opens.
class DesktopIcon:
	extends Control

	var desktop
	var app_id := ""

	var _hl: ColorRect
	var _lbl: Label

	func _init(p_desktop, p_id: String, p_name: String, tex: Texture2D) -> void:
		desktop = p_desktop
		app_id = p_id
		size = Vector2(52, 46)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_hl = ColorRect.new()
		_hl.color = Color(0.2, 0.45, 0.9, 0.4)
		_hl.size = size
		_hl.visible = false
		_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hl)
		var ic := TextureRect.new()
		ic.texture = tex
		ic.position = Vector2(14, 1)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_lbl = Label.new()
		_lbl.text = p_name
		_lbl.position = Vector2(0, 26)
		_lbl.size = Vector2(52, 20)
		_lbl.add_theme_font_size_override("font_size", 7)
		_lbl.add_theme_color_override("font_color", Color(0.97, 1.0, 0.97))
		_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		_lbl.add_theme_constant_override("shadow_offset_x", 1)
		_lbl.add_theme_constant_override("shadow_offset_y", 1)
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# filenames wrap mid-word, like every real desktop ever
		_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_lbl)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			desktop.select_icon(self)
			if event.double_click:
				desktop.open_app(app_id)

	func set_selected(v: bool) -> void:
		_hl.visible = v
