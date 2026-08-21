# DORKO — Architecture Contract

This document is the authoritative API reference for building rooms,
minigames, and UI on top of the core. Read it fully before adding content.
The core lives in `scripts/autoload/`, `scripts/core/`, and `actors/`.

## Project shape

- Godot 4.3, GDScript only, 640×360 canvas_items stretch, nearest filtering.
- **All art and audio is generated in code.** No binary assets. Textures come
  from `Painter` / `AssetLib`; audio from `SfxSynth` / `MusicGen` / `AssetLib`.
- Rooms are thin `.tscn` wrappers (one root Node2D + script) over scripts in
  `scripts/rooms/`. Everything is built in `_room_setup()`.
- Canvas layers: room (0) < overlays (50) < inventory/pause UI (55) <
  dialogue (60) < VHS filter (100) < fade (110) < cursor (120).

## Autoloads (in order)

### Boot
`launch_room: String`, `smoke_test: bool` — CLI args (`-- --room X`, `-- --smoke`).
Registers all input actions in code: `move_left/right/up/down`, `inventory`,
`advance`, `pause`, `choice_1..4`, `battle_uppercut`.

### AssetLib — procedural asset factory (all cached)
- `painter(w, h, pixel_size := 1, bg := transparent) -> Painter`
- `get_or_build(key: String, builder: Callable) -> Texture2D` — use for ALL
  room-local art; key must be globally unique (prefix with room name).
- `solid(w, h, color) -> Texture2D`
- `tex(name) -> Texture2D` — core set: `cursor_eye/hand/mouth`, `shadow`,
  `slot_bg`, `pixel`.
- `item_icon(id) -> Texture2D` (32×32), `portrait(id) -> Texture2D` (48×48;
  ids: `dorko`, `couch_guy`, `blue_bomb`, `turquoise_one`, fallback silhouette).
- `floor_tex(key, opts) -> Texture2D` — perspective floor; see BaseRoom.add_floor.
- `wall_tex(key, w, h, top: Color, bottom: Color, grime := 0.0) -> Texture2D`
- `sfx(name) -> AudioStreamWAV` — see list below. `music(name) -> AudioStreamWAV`.

SFX names: `tick pop click blip chime_boot error_dlg keypad_beep keypad_laugh
door_unlock door_open thud_{carpet,tile,concrete}_{1,2} clink static_burst
laugh_track trapdoor fall_whistle poof bwomp party_horn puff ding bell punch
thwip explosion splat beat perfect miss_buzz swoosh crowd_loop heartbeat
whip_pan`. Music names: `orange living kitchen basement turquoise battle hold`.
Add new SFX to `asset_lib.gd::_build_sfx` (match arm), new songs to
`music_gen.gd::song`.

### GameState
- `set_flag(name, value := true)`, `get_flag(name) -> bool`, `clear_flag(name)`,
  signal `flag_changed(name, value)`. Setting a flag autosaves (unless the name
  starts with `_`).
- `current_room`, `current_spawn` (managed by SceneRouter).
- `lock_input()` / `unlock_input()` / `is_input_locked()` — counting lock; every
  lock MUST be paired with exactly one unlock (cutscenes use this).
- `save_game()`, `load_game() -> String` (returns room id), `has_save()`,
  `delete_save()`, `new_game()`.
- `settings: Dictionary` — `master_vol music_vol sfx_vol vhs_filter text_speed
  fullscreen`; `apply_settings()`, `save_settings()`.

### Inventory
- `items: Array` of ids (max 10), `add_item(id, silent := false) -> bool`,
  `remove_item(id)`, `has_item(id)`, `combine(a, b) -> String` ("" = refused).
- `get_def(id) -> Dictionary`, `display_name(id)`, `look_text(id)`.
- Signals: `item_added`, `item_removed`, `changed`.
- Items/combos are defined in `data/items.json`. New items need an icon case in
  `asset_lib.gd::_build_item_icon`.

### AudioBus
- `play_sfx(name, pitch := 1.0, vol_db := 0.0) -> AudioStreamPlayer` (keep the
  return value to `.stop()` loops like `crowd_loop`).
- `play_stream(stream, pitch, vol_db)` for custom-synthesized audio.
- `blip(pitch)`, `footstep(surface)` (`carpet|tile|concrete`).
- `play_music(name, crossfade := 1.2)`, `stop_music(fade := 0.8)`.
- `set_volume("Master"|"Music"|"SFX", linear)`, `get_volume(bus)`.

### SceneRouter
- `goto_room(room_id, spawn := "default")` — 0.4s fade + tracking line +
  autosave. Room registry: `SceneRouter.ROOMS` (id -> tscn path).
- `goto_scene(path)` for non-room scenes (battle, ending); `goto_main_menu()`.
- `push_overlay(node)` / `pop_overlay()` / `has_overlay()` / `top_overlay()` —
  full-screen minigames/PC desktop. Overlay = any Control/Node2D; it is freed
  on pop. Overlays lock player input automatically. **Overlays handle their own
  Esc** (UILayer deliberately ignores Esc while an overlay is up).
- `transitioning: bool`, signal `room_changed(room_id)`.

### UILayer
- `float_text(pos, text, color := WHITE)`, `toast(text)`.
- `bubble(target: Node2D, text, pitch := 1.0, duration := 2.6)` — speech bubble
  following a world node (NPC barks).
- `fly_item(id, from_pos)` — pickup animation (Hotspot.give_item calls this).
- Inventory bar: hover bottom edge or I/Tab. Pause menu on Esc (in rooms only).

### DialogueManager
- `start(id, node_key := "start")`, `say(speaker, text)` (text: String or Array
  = random pick), `dorko(text)`, `say_seq([[speaker, text], ...])`.
- If a dialogue is active, new `start`/`say` calls **queue** and play after.
- `register_tree(dict)` for runtime-built trees; JSON files in
  `data/dialogue/*.json` auto-load (needs top-level `"id"`, `"nodes"`).
- Node keys: `speaker`, `text` (String|Array), `portrait`, `set_flag`,
  `gives_item`, `next`, `choices` [{`text`, `next`, `requires_flag`,
  `requires_not_flag`, `requires_item`, `once`, `set_flag`, `gives_item`}].
- Generic Dorko lines: `use_fail()`, `talk_fail()`, `touch_default()`,
  `combine_fail()`.
- `active: bool`, signals `dialogue_started(id)`, `dialogue_finished(id)`.
- Per-speaker blip pitch: add to `PITCH` const (or tree-level `"speakers"`
  dict: `{"Name": {"pitch": 1.2}}`). Name colors: `NAME_COLORS`.

### CursorManager
- `verb` (VERB_EYE/VERB_HAND/VERB_MOUTH/VERB_ITEM), `item_id`.
- `set_item(id)`, `clear_item()`, `cycle(dir)`, `set_hover_text(text)`.
- Scroll/right-click cycling is built in. Esc policy lives in UILayer.

### Fx
- `set_vhs_enabled(bool)`, `flash(color := WHITE, duration := 0.18)`,
  `shake(duration := 0.35, strength := 6.0)` (targets top overlay if present,
  else the current scene).

## BaseRoom (scripts/core/base_room.gd)

Subclass pattern — **never override `_ready`**:

```gdscript
extends BaseRoom

func _room_config() -> void:
    room_id = "orange_room"        # must match SceneRouter.ROOMS key
    music_name = "orange"          # "" keeps current music
    footstep_surface = "carpet"
    horizon_y = 195.0              # wall/floor seam; floor runs to y=360
    back_half = 175.0; front_half = 345.0   # floor trapezoid half-widths
    spawn_points = {
        "default": {"pos": Vector2(320, 290), "dir": "down"},
        "from_kitchen": {"pos": Vector2(600, 250), "dir": "left"},
    }

func _room_setup() -> void: ...    # build walls, floor, props, hotspots
func _on_room_entered() -> void: ...  # opening beats (may be async)
```

Helpers:
- `add_floor(pattern, col_a, col_b, cell := 1.0, z_far := 3.0)` — pattern:
  `checker|stripes_z|stripes_x|grid|solid`. Draws horizon_y..360.
- `add_rect(rect, color, z := -700)`, `add_poly(points, color, z := -700)` —
  background shapes (z < -500 = behind floor; use -400..-100 for on-wall art).
- `add_prop(texture, pos, z := auto, centered := true) -> Sprite2D` — z
  defaults to the sprite's ground line (its bottom edge y), which layers
  correctly against Dorko (z_index = his y).
- `add_parallax(node, factor := 1.0)` — background shifts opposite Dorko.
- `register_depth(node, base_scale := 1.0)` — per-frame depth scale (0.55 back
  → 1.1 front) + z from y. Dorko is registered automatically. Register NPCs
  that stand on the floor. `depth_scale(y) -> float`.
- `add_hotspot(cfg) -> Hotspot`, cfg keys:
  `name` (cursor label), `pos` (center), `size` (Vector2),
  `look` (String|Array), `on_look` (Callable, overrides look),
  `touch` (Callable), `use_item` (func(item_id) -> bool; return false for the
  generic refusal), `talk` (dialogue id), `interact` (Vector2 walk-to point —
  defaults to pos clamped to the floor; SET THIS for wall objects),
  `walk_required` (bool), `visual` (CanvasItem to pulse on hover).
- `add_exit(cfg)` — hotspot that changes rooms: extra keys `target`, `spawn`,
  `condition` (Callable -> bool), `locked_line`, `on_exit` (Callable overriding
  the transition).
- `say(text)` — Dorko one-liner.
- `point_walkable(p)`, `clamp_to_walk(p)`, `dorko` (the player node).

Interaction rules (already implemented — do not duplicate):
- Eye looks from anywhere; Hand/Mouth/Item walk Dorko to `interact` first.
- Item use calls `use_item(item_id)`; returning `false` plays a random generic
  refusal. The item is NOT consumed automatically — call
  `Inventory.remove_item(id)` yourself when consumed.
- Click on floor = walk. WASD always works. Both blocked while dialogue,
  overlay, transition, or `GameState.lock_input()` is active.

## Dorko (actors/dorko.gd)

- `walk_to(target, on_arrive := Callable())`, `stop()`, `teleport(pos, face)`,
  `face_towards(point)`, `control_enabled` (set false during cutscenes),
  `facing` ("down|up|left|right"), `sprite` (AnimatedSprite2D: `walk_*`,
  `idle_*`).

## Painter (scripts/core/painter.gd)

Virtual-pixel canvas: `Painter.new(w, h, px, bg)`; methods `dot rect
rect_outline hline vline line ellipse ellipse_outline circle poly speckle
checker`; `tex() -> ImageTexture`. All coords in virtual pixels; deterministic
(seeded) randomness only.

## SfxSynth / MusicGen (static)

- `SfxSynth.tone(freq, dur, wave, vol, attack, release, vibrato, vib_rate)`,
  `sweep(f0, f1, ...)`, `noise(dur, vol, cutoff, ...)`, `seq([...])`,
  `mix([...], offsets)`, `gain(samples, x)`, `silence(dur)`,
  `midi_hz(note)`, `to_wav(samples, loop := false)`. Waves: sine/square/saw/tri.
- `MusicGen.chords(bpm, beats_per_chord, chord_list, wave, vol, vibrato, stab)`,
  `MusicGen.line(bpm, [[midi, beats], ...], wave, vol, release)`.

## GDScript 4.3 rules that have already bitten us

1. `min/max/clamp/lerp` return Variant — with `:=` inference use
   `minf/maxf/clampf/lerpf` (or declare the type explicitly).
2. **No multiline lambdas inside dictionary/array literals.** Assign the lambda
   to a local `var` first, then reference it. Multiline lambdas as a *final
   call argument* are fine (used with `get_or_build`).
3. Rooms must not override `_ready()`; use the three hooks.
4. Every texture goes through `AssetLib.get_or_build` with a unique key —
   rebuilding per-frame is a bug.
5. Cutscene pattern:
   `GameState.lock_input()` … `await` beats … `GameState.unlock_input()` —
   always balanced, including early returns.
6. Use `await get_tree().create_timer(x).timeout` for beats; never busy-wait.
7. Coroutines die with their node — put long sequences on nodes that survive
   (or keep the sequence inside the room that owns it and don't change rooms
   mid-sequence except as the final step).
8. Deterministic art: seed every RandomNumberGenerator used for textures.
9. Indent with TABS (project style).
10. `AudioStreamWAV` from `SfxSynth.to_wav` — 22050 Hz mono; keep music loops
    ≤ ~16s (generation cost is real).

## Validation

```bash
godot --headless --import .                 # must print no SCRIPT ERROR
godot --headless --path . -- --smoke        # must end with SMOKE OK, exit 0
godot --headless --path . -- --room <id>    # boot straight into a room
```

The smoke runner (`tests/smoke_runner.gd`) tours every room registered in
`SceneRouter.ROOMS` whose tscn exists, draining any dialogue it finds. Rooms
with blocking opening cutscenes must still finish them within a few clicks.
