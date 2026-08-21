extends BaseRoom
## The Basement (spec 7.4). Low ceiling, green bulb, concrete, and thirty
## years of brand-free memorabilia. A nervous sphere lives here. He would
## like to stop being about to explode.

var _bomb: BlueBomb
var _arcade_sprite: Sprite2D
var _arcade_hs: Hotspot
var _crawl_hs: Hotspot = null
var _crawl_glow: Sprite2D
var _lava_sprite: Sprite2D
var _bulb_sprite: Sprite2D
var _heater_sprite: Sprite2D
var _wall_msg: Label
var _busy := false
var _phone_players: Array = []  # stopped on room exit so loops can't leak


func _exit_tree() -> void:
	for p in _phone_players:
		if p != null and is_instance_valid(p):
			p.stop()
	_phone_players.clear()


func _room_config() -> void:
	room_id = "basement"
	music_name = "basement"
	footstep_surface = "concrete"
	horizon_y = 205.0
	ambient_tint = Color(0.84, 1.0, 0.86)
	spawn_points = {
		"default": {"pos": Vector2(320, 302), "dir": "down"},
	}


func _room_setup() -> void:
	_build_walls()
	add_floor("solid", Color(0.44, 0.47, 0.44), Color(0.4, 0.43, 0.4))
	_build_memorabilia()
	_build_bomb()
	_build_arcade()


func _on_room_entered() -> void:
	if GameState.get_flag("basement_landed"):
		if GameState.get_flag("arcade_moved"):
			_reveal_crawlspace(true)
		return
	GameState.set_flag("basement_landed")
	GameState.lock_input()
	AudioBus.play_sfx("poof")
	dorko.position = Vector2(320, 302)
	# beanbag physics: one bounce, no dignity
	var tw := create_tween()
	tw.tween_property(dorko, "position:y", 296.0, 0.12)
	tw.tween_property(dorko, "position:y", 302.0, 0.12)
	await tw.finished
	GameState.unlock_input()
	say("...ow. Okay. Okay. That was fair.")


# ---------------------------------------------------------------- construction

func _build_walls() -> void:
	var wallc := Node2D.new()
	bg.add_child(wallc)
	add_parallax(wallc, 1.0)
	var wall := Sprite2D.new()
	wall.texture = AssetLib.get_or_build("base_wall", _build_wall_tex)
	wall.centered = false
	wallc.add_child(wall)
	# green bulb, hanging low
	_bulb_sprite = Sprite2D.new()
	_bulb_sprite.texture = AssetLib.get_or_build("base_bulb", _build_bulb_tex)
	_bulb_sprite.position = Vector2(320, 38)
	_bulb_sprite.z_index = -350
	bg.add_child(_bulb_sprite)
	# hidden message; the bike powers it into visibility for a moment
	_wall_msg = Label.new()
	_wall_msg.text = "IT'S DOWN THE HALL."
	_wall_msg.position = Vector2(230, 96)
	_wall_msg.add_theme_font_size_override("font_size", 14)
	_wall_msg.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75, 0.0))
	_wall_msg.z_index = -300
	add_child(_wall_msg)
	# floor drain
	var drain := add_prop(AssetLib.get_or_build("base_drain", _build_drain_tex), Vector2(396, 332), -450)
	add_hotspot({
		"name": "Drain",
		"pos": Vector2(396, 332),
		"size": Vector2(36, 20),
		"look": "It gurgles when I'm not looking. It's quiet now. Because I'm looking.",
		"touch": func(): say("No part of me goes near the grate. House rule. My rule. Same thing now."),
		"visual": drain,
	})


func _build_memorabilia() -> void:
	# --- VHS shelf (the wire manual)
	var shelf := add_prop(AssetLib.get_or_build("base_shelf", _build_shelf_tex), Vector2(92, 150), -380)
	add_hotspot({
		"name": "VHS Shelf",
		"pos": Vector2(92, 150),
		"size": Vector2(92, 110),
		"look": "Hand-labeled tapes. Someone's whole life, alphabetized by feeling.",
		"touch": _read_tapes,
		"visual": shelf,
		"interact": Vector2(110, 250),
	})
	# --- floppy pile
	var floppies := add_prop(AssetLib.get_or_build("base_floppies", _build_floppy_tex), Vector2(160, 254))
	add_hotspot({
		"name": "Floppy Disks",
		"pos": Vector2(160, 252),
		"size": Vector2(40, 26),
		"look": "Labels: TAXES, TAXES 2, do not, TAXES 3.",
		"touch": func(): say("I'm not touching 'do not'. It said not to. It's the only clear instruction in this house."),
		"visual": floppies,
		"interact": Vector2(160, 282),
	})
	# --- standee
	var standee := add_prop(AssetLib.get_or_build("base_standee", _build_standee_tex), Vector2(232, 226))
	add_hotspot({
		"name": "Cardboard Standee",
		"pos": Vector2(232, 220),
		"size": Vector2(56, 100),
		"look": "A '90s action hero named, according to the base, 'MAX BLAST'. His catchphrase has worn off.",
		"touch": func(): say("I steadied him. He'd do the same for me. He'd say something cool about it."),
		"visual": standee,
		"interact": Vector2(232, 276),
	})
	# --- boombox + cassettes on a crate
	var boombox := add_prop(AssetLib.get_or_build("base_boombox", _build_boombox_tex), Vector2(310, 246))
	add_hotspot({
		"name": "Boombox",
		"pos": Vector2(310, 244),
		"size": Vector2(56, 40),
		"look": "A boombox with one tape in it and gravel in its voice. The crate is its stage.",
		"touch": _touch_boombox,
		"visual": boombox,
		"interact": Vector2(310, 284),
	})
	# --- rotary phone on a little table
	var phone := add_prop(AssetLib.get_or_build("base_phone", _build_phone_tex), Vector2(392, 242))
	add_hotspot({
		"name": "Rotary Phone",
		"pos": Vector2(392, 240),
		"size": Vector2(40, 38),
		"look": "A rotary phone. Calling anyone takes a full minute of commitment per digit.",
		"touch": _touch_phone,
		"visual": phone,
		"interact": Vector2(392, 282),
	})
	# --- lava lamp on the shelf's end table
	_lava_sprite = add_prop(AssetLib.get_or_build("base_lava_dim", func(): return _build_lava_tex(false)), Vector2(56, 246))
	add_hotspot({
		"name": "Lava Lamp",
		"pos": Vector2(56, 244),
		"size": Vector2(26, 42),
		"look": "The blobs rise, think about it, and change their minds. Same.",
		"touch": func(): say("Warm. Not pizza-roll warm. Nothing is."),
		"visual": _lava_sprite,
		"interact": Vector2(70, 282),
	})
	# --- beanbag (the landing zone)
	var beanbag := add_prop(AssetLib.get_or_build("base_beanbag", _build_beanbag_tex), Vector2(320, 318), -440)
	add_hotspot({
		"name": "Beanbag",
		"pos": Vector2(320, 318),
		"size": Vector2(78, 34),
		"look": "It broke my fall. We have history now.",
		"touch": func(): say("Tempting. But I sit down in this house, I stay down. Look at everyone."),
		"visual": beanbag,
	})
	# --- exercise bike
	var bike := add_prop(AssetLib.get_or_build("base_bike", _build_bike_tex), Vector2(148, 314))
	add_hotspot({
		"name": "Exercise Bike",
		"pos": Vector2(148, 310),
		"size": Vector2(64, 52),
		"look": "Dust on the seat, dust on the handlebars, hope in the flywheel.",
		"touch": _ride_bike,
		"visual": bike,
		"interact": Vector2(190, 318),
	})
	# --- plastic trophy on a stool
	var trophy := add_prop(AssetLib.get_or_build("base_trophy", _build_trophy_tex), Vector2(508, 296))
	add_hotspot({
		"name": "Plastic Trophy",
		"pos": Vector2(508, 292),
		"size": Vector2(34, 44),
		"on_look": _look_trophy,
		"touch": _take_trophy,
		"visual": trophy,
		"interact": Vector2(508, 322),
	})
	# --- water heater
	_heater_sprite = add_prop(AssetLib.get_or_build("base_heater_open" if GameState.get_flag("heater_open") else "base_heater_shut", _heater_builder), Vector2(452, 174), -370)
	var heater := _heater_sprite
	add_hotspot({
		"name": "Water Heater",
		"pos": Vector2(452, 180),
		"size": Vector2(64, 120),
		"on_look": _look_heater,
		"touch": _touch_heater,
		"use_item": _use_on_heater,
		"visual": heater,
		"interact": Vector2(452, 262),
	})


func _build_bomb() -> void:
	_bomb = BlueBomb.new()
	_bomb.position = Vector2(462, 288)
	add_child(_bomb)
	register_depth(_bomb, 0.95)
	add_hotspot({
		"name": "Blue Bomb",
		"pos": Vector2(462, 262),
		"size": Vector2(66, 76),
		"on_look": _look_bomb,
		"touch": _touch_bomb,
		"on_talk": _talk_bomb,
		"use_item": _use_on_bomb,
		"interact": Vector2(438, 296),
	})


func _build_arcade() -> void:
	# crawlspace glow sits behind the cabinet; revealed when it moves
	_crawl_glow = Sprite2D.new()
	_crawl_glow.texture = AssetLib.get_or_build("base_crawl", _build_crawl_tex)
	_crawl_glow.position = Vector2(586, 176)
	_crawl_glow.z_index = -390
	_crawl_glow.visible = false
	bg.add_child(_crawl_glow)
	_arcade_sprite = add_prop(AssetLib.get_or_build("base_arcade", _build_arcade_tex), Vector2(576, 172), -360)
	if GameState.get_flag("arcade_moved"):
		_arcade_sprite.position.x = 508
	_arcade_hs = add_hotspot({
		"name": "GALAXY NIBBLER",
		"pos": Vector2(576, 190),
		"size": Vector2(74, 130),
		"on_look": _look_arcade,
		"touch": _touch_arcade,
		"use_item": _use_on_arcade,
		"visual": _arcade_sprite,
		"interact": Vector2(548, 266),
	})


# ---------------------------------------------------------------- flavor

func _read_tapes() -> void:
	DialogueManager.say_seq([
		["Dorko", "The labels, in order of shouting:"],
		["Dorko", "'CUT RED FIRST (home video)'. Sure. Normal home video title."],
		["Dorko", "'then the one that isn't there'. There's a gap on the shelf where a tape isn't. Helpful."],
		["Dorko", "'green is a trick. dont'. No apostrophe. They were in a hurry, or past caring."],
		["Dorko", "'blue last obviously'. Obviously."],
		["Dorko", "Somebody labeled these for exactly one future situation. I hate how ready I feel."],
	])


func _touch_boombox() -> void:
	if _busy:
		return
	if not GameState.get_flag("basement_boombox_played"):
		_busy = true
		AudioBus.play_sfx("click", 0.9)
		# ~4s of a child's tape: squeaky babble saying dorko dorko dorko, then laughter
		var voice := SfxSynth.seq([
			SfxSynth.tone(520.0, 0.16, "square", 0.14, 0.01, 0.05), SfxSynth.tone(660.0, 0.13, "square", 0.13, 0.01, 0.05), SfxSynth.silence(0.14),
			SfxSynth.tone(540.0, 0.16, "square", 0.14, 0.01, 0.05), SfxSynth.tone(680.0, 0.13, "square", 0.13, 0.01, 0.05), SfxSynth.silence(0.14),
			SfxSynth.tone(500.0, 0.16, "square", 0.14, 0.01, 0.05), SfxSynth.tone(640.0, 0.15, "square", 0.13, 0.01, 0.06), SfxSynth.silence(0.3),
			SfxSynth.sweep(700.0, 1000.0, 0.22, "sine", 0.12, 0.01, 0.05), SfxSynth.silence(0.08),
			SfxSynth.sweep(750.0, 1050.0, 0.2, "sine", 0.12, 0.01, 0.05), SfxSynth.silence(0.08),
			SfxSynth.sweep(800.0, 1150.0, 0.3, "sine", 0.12, 0.01, 0.1),
		])
		AudioBus.play_stream(SfxSynth.to_wav(SfxSynth.mix([voice, SfxSynth.noise(4.0, 0.02, 0.2, 0.2, 0.4, 88)])), 1.6, -4.0)
		await get_tree().create_timer(4.2).timeout
		if not is_inside_tree():
			return
		GameState.set_flag("basement_boombox_played")
		_busy = false
		say("A kid's voice. Saying my name. Then laughing. I'm going to think about the lava lamp instead.")
	elif not GameState.get_flag("basement_tape_taken"):
		if Inventory.add_item("cassette_tape"):
			UILayer.fly_item("cassette_tape", Vector2(310, 236))
			GameState.set_flag("basement_tape_taken")
			AudioBus.play_sfx("click", 1.2)
			say("Ejected. The boombox kept the silence. I kept the tape.")
	else:
		say("It plays static now, out of principle.")


func _touch_phone() -> void:
	if _busy:
		return
	_busy = true
	AudioBus.play_sfx("click", 1.1)
	# dial tone that slowly admits it's the hold music
	var tone_player := AudioBus.play_stream(SfxSynth.to_wav(SfxSynth.mix([
		SfxSynth.tone(350.0, 2.2, "sine", 0.12, 0.02, 0.4),
		SfxSynth.tone(440.0, 2.2, "sine", 0.12, 0.02, 0.4),
	])), 1.0, -6.0)
	_phone_players.append(tone_player)
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	if tone_player and is_instance_valid(tone_player):
		tone_player.stop()
	# NOTE: the hold track is loop-enabled — it MUST be tracked in
	# _phone_players so _exit_tree can stop it if the player walks out mid-call.
	var hold := AudioBus.play_stream(AssetLib.music("hold"), 1.0, -10.0)
	_phone_players.append(hold)
	await get_tree().create_timer(2.6).timeout
	if hold and is_instance_valid(hold):
		hold.stop()
	if not is_inside_tree():
		return
	AudioBus.play_sfx("clink", 0.6)
	_busy = false
	say("The dial tone turned into the hold music. Nobody dialed. I hung up before it could get to the chorus.")


func _ride_bike() -> void:
	if _busy:
		return
	_busy = true
	GameState.lock_input()
	# three seconds of honest cardio
	for i in 6:
		AudioBus.play_sfx("tick", 0.6 + 0.05 * i, -10.0)
		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			return
	# the lamp brightens, the bulb flickers, the wall says something it shouldn't
	_lava_sprite.texture = AssetLib.get_or_build("base_lava_lit", func(): return _build_lava_tex(true))
	_bulb_sprite.modulate = Color(1.4, 1.5, 1.4)
	var tw := create_tween()
	tw.tween_property(_wall_msg, "theme_override_colors/font_color", Color(0.7, 1.0, 0.75, 0.9), 0.4)
	tw.tween_interval(1.4)
	tw.tween_property(_wall_msg, "theme_override_colors/font_color", Color(0.7, 1.0, 0.75, 0.0), 0.8)
	tw.parallel().tween_property(_bulb_sprite, "modulate", Color.WHITE, 0.8)
	await tw.finished
	if not is_inside_tree():
		return
	GameState.unlock_input()
	_busy = false
	say("The wall said something about a hall. The bike counts that as one session. So do I.")


func _look_trophy() -> void:
	if Inventory.has_item("plastic_trophy") or GameState.get_flag("heater_open"):
		say("The stool misses it. Stools don't say much, but they feel plenty.")
	elif GameState.get_flag("basement_trophy_taken"):
		say("Gone to a better shelf. Mine.")
	else:
		say("PARTICIPANT. No year, no event. Just the concept, in gold-ish.")


func _take_trophy() -> void:
	if GameState.get_flag("basement_trophy_taken"):
		say("Already collected. My proudest participation.")
		return
	if Inventory.add_item("plastic_trophy"):
		UILayer.fly_item("plastic_trophy", Vector2(508, 284))
		GameState.set_flag("basement_trophy_taken")
		say("A trophy for showing up. I did show up. Via trapdoor, but it counts.")


# ---------------------------------------------------------------- water heater

func _heater_builder() -> Texture2D:
	return _build_heater_tex(GameState.get_flag("heater_open"))


func _look_heater() -> void:
	if GameState.get_flag("heater_open"):
		say("Panel's off. It drips like it's timing something.")
	else:
		say("A water heater with a bolted panel. It's seen the bomb every day for thirty years. Imagine the small talk.")


func _touch_heater() -> void:
	if GameState.get_flag("heater_open"):
		if not GameState.get_flag("basement_rag_taken"):
			_try_take_rag()
		else:
			say("Warm inside. Wet. I already took the best rag.")
	else:
		say("The panel's bolted shut. Finger-proof. I'd need something flat, stiff, and expendable.")


## Guarded pickup: the rag stays claimable until it actually fits in a pocket.
func _try_take_rag() -> void:
	if Inventory.add_item("wet_rag"):
		GameState.set_flag("basement_rag_taken")
		UILayer.fly_item("wet_rag", Vector2(452, 200))
		say("One professionally damp rag, acquired.")
	else:
		say("The rag's right there. My pockets voted no. Democracy.")


func _use_on_heater(item_id: String) -> bool:
	if item_id != "plastic_trophy":
		if item_id == "wind_up_key":
			say("Wrong appliance. The key has one destiny and this isn't it.")
			return true
		return false
	if GameState.get_flag("heater_open"):
		say("Once was enough. The trophy agrees.")
		return true
	AudioBus.play_sfx("door_unlock", 0.8)
	GameState.set_flag("heater_open")
	_heater_sprite.texture = AssetLib.get_or_build("base_heater_open", func(): return _build_heater_tex(true))
	if Inventory.add_item("wet_rag"):
		GameState.set_flag("basement_rag_taken")
		UILayer.fly_item("wet_rag", Vector2(452, 200))
		say("Pried it open. The trophy bent. Still says PARTICIPANT. Truer than ever. And inside: one professionally damp rag.")
	else:
		say("Pried it open. There's a damp rag in there — it can wait until my pockets can.")
	return true


# ---------------------------------------------------------------- Blue Bomb

func _look_bomb() -> void:
	if GameState.get_flag("bomb_defused"):
		say("He keeps standing up and sitting down, testing whether standing is still allowed. It is.")
	else:
		say("His fuse is burning, but so slowly it's more of a lifestyle.")


func _talk_bomb() -> void:
	if GameState.get_flag("bomb_defused"):
		DialogueManager.start("blue_bomb", "defused_start")
	elif GameState.get_flag("fuse_wet"):
		DialogueManager.start("blue_bomb", "wet_start")
	elif GameState.get_flag("key_jammed"):
		DialogueManager.start("blue_bomb", "jammed_start")
	else:
		DialogueManager.start("blue_bomb", "start")


func _touch_bomb() -> void:
	if GameState.get_flag("bomb_defused"):
		say("A quick pat. He's just a guy now. A sphere of guy.")
		return
	if GameState.get_flag("fuse_wet") and GameState.get_flag("key_jammed"):
		var panel = load("res://scripts/minigames/wire_panel.gd").new()
		panel.on_success = _on_defused
		SceneRouter.push_overlay(panel)
		return
	if not GameState.get_flag("key_jammed"):
		say("He flinched so hard I flinched. The key has to stop first. Something has to jam it.")
	else:
		say("The fuse is still live. Wet first. Then wires. He was very clear, very quietly.")


func _use_on_bomb(item_id: String) -> bool:
	match item_id:
		"cassette_tape":
			if GameState.get_flag("key_jammed"):
				say("The key's already wearing its tape. One accessory per key.")
				return true
			Inventory.remove_item("cassette_tape")
			GameState.set_flag("key_jammed")
			AudioBus.play_sfx("clink", 0.8)
			_bomb.refresh()
			DialogueManager.say("Blue Bomb", "Oh. Oh that's— I feel lighter. Is this what lighter feels like.")
			return true
		"ramune_bottle", "wet_rag":
			if not GameState.get_flag("key_jammed"):
				DialogueManager.say("Blue Bomb", "N-not yet— the key would just wind me dry again— the key first, sorry, I have a whole order—")
				return true
			if GameState.get_flag("fuse_wet"):
				say("The fuse is out of the fire business. It's damp and it's done.")
				return true
			Inventory.remove_item(item_id)
			GameState.set_flag("fuse_wet")
			AudioBus.play_sfx("puff", 1.3)
			AudioBus.play_sfx("static_burst", 1.8, -14.0)
			_bomb.refresh()
			if item_id == "ramune_bottle":
				DialogueManager.say("Blue Bomb", "Fizzy. It's fizzy on my— thank you. The bubbles are doing the work. Tell the marble it did great.")
			else:
				DialogueManager.say("Blue Bomb", "Cold— wet— perfect— that rag has been in that heater since before some of my fears existed.")
			return true
		"perfect_pizza_roll":
			say("Heat, meet bomb. No. This is the worst idea I've had all house.")
			return true
		"wind_up_key":
			say("He gave it to me. Giving it back sends the wrong message about progress.")
			return true
	return false


func _on_defused() -> void:
	GameState.set_flag("bomb_defused")
	_bomb.refresh()
	AudioBus.play_sfx("puff", 0.9)
	GameState.lock_input()
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	# he stands. wobbles. renegotiates his whole deal.
	var tw := create_tween()
	tw.tween_property(_bomb, "rotation", 0.12, 0.2)
	tw.tween_property(_bomb, "rotation", -0.1, 0.2)
	tw.tween_property(_bomb, "rotation", 0.0, 0.15)
	await tw.finished
	GameState.unlock_input()
	DialogueManager.say_seq([
		["Blue Bomb", "I don't know what I'm supposed to do now. I was the bomb. Now I'm... a ball?"],
		["Dorko", "Welcome to the club."],
		["Blue Bomb", "Is there a jacket. Does the club have a— sorry. Take this. It's yours. It was never really mine, it was just IN me—"],
	])
	await DialogueManager.dialogue_finished
	if not is_inside_tree():
		return
	if Inventory.add_item("wind_up_key"):
		UILayer.fly_item("wind_up_key", _bomb.global_position + Vector2(0, -40))
	DialogueManager.say("Blue Bomb", "There's a room behind the arcade machine. I could hear it humming. Don't— actually, go. I'm not the boss of you. I'm not the boss of anything.")


# ---------------------------------------------------------------- arcade

func _look_arcade() -> void:
	if GameState.get_flag("arcade_moved"):
		say("GALAXY NIBBLER, relocated. Behind where it stood: a crawlspace, glowing like a swimming pool at night.")
	elif GameState.get_flag("bomb_defused"):
		say("Scuff marks arc across the floor under it. This cabinet moonwalks when nobody's watching.")
	else:
		say("GALAXY NIBBLER. The screen is dead but the cabinet hums. Cabinets shouldn't hum. Shelves shouldn't breathe. This house needs a talking-to.")


func _touch_arcade() -> void:
	if GameState.get_flag("arcade_moved"):
		say("It's moved all it's moving.")
	elif not GameState.get_flag("bomb_defused"):
		say("I'm not shoving furniture around next to a live bomb. Even a polite one.")
	else:
		say("It won't budge. There's a sliding mechanism locked behind the coin door, and the coin door wants a key. Everything in this house wants something.")


func _use_on_arcade(item_id: String) -> bool:
	if item_id != "wind_up_key":
		if item_id == "cassette_tape":
			say("Wrong slot, wrong decade, wrong everything.")
			return true
		return false
	if GameState.get_flag("arcade_moved"):
		say("Already unlocked. The key remembers. Keys remember everything.")
		return true
	if not GameState.get_flag("bomb_defused"):
		say("Not while he's ticking adjacent. Priorities.")
		return true
	AudioBus.play_sfx("door_unlock")
	GameState.lock_input()
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree():
		return true
	AudioBus.play_sfx("swoosh", 0.8)
	var tw := create_tween()
	tw.tween_property(_arcade_sprite, "position:x", 508.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	Fx.shake(0.5, 2.5)
	await tw.finished
	GameState.set_flag("arcade_moved")
	_reveal_crawlspace(false)
	GameState.unlock_input()
	say("The key fit the coin door. The coin door freed the slider. The cabinet slid. Behind it: a crawlspace, and light with a temperature I don't have a word for.")
	return true


func _reveal_crawlspace(silent: bool) -> void:
	_crawl_glow.visible = true
	if _crawl_hs != null:
		return
	_crawl_hs = add_hotspot({
		"name": "Crawlspace",
		"pos": Vector2(602, 218),
		"size": Vector2(56, 90),
		"look": "Turquoise light, a low ceiling, and a hum like a fridge that learned meditation.",
		"touch": _enter_crawlspace,
		"interact": Vector2(586, 276),
	})
	if not silent:
		AudioBus.play_sfx("static_burst", 0.5, -12.0)


func _enter_crawlspace() -> void:
	AudioBus.play_sfx("swoosh", 1.1)
	SceneRouter.goto_room("turquoise_room")


# ---------------------------------------------------------------- textures

func _build_wall_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(320, 103, 2)
	var block_a := Color(0.4, 0.44, 0.4)
	var block_b := Color(0.36, 0.4, 0.37)
	var mortar := Color(0.28, 0.31, 0.28)
	# cinder blocks
	for by in range(8, 103, 12):
		for bx in range(0, 320, 24):
			var off := 12 if (by / 12) % 2 == 1 else 0
			p.rect(bx - off, by, 24, 12, block_a if ((bx + by) / 24) % 2 == 0 else block_b)
			p.hline(bx - off, by, 24, mortar)
			p.vline(bx - off, by, 12, mortar)
	# the low ceiling: joists overhead
	p.rect(0, 0, 320, 8, Color(0.22, 0.18, 0.14))
	for jx in range(6, 320, 34):
		p.rect(jx, 0, 5, 8, Color(0.3, 0.24, 0.18))
	# damp corner stain
	p.speckle(250, 60, 70, 40, Color(0.25, 0.3, 0.27), 0.15, 33)
	p.speckle(0, 8, 320, 92, Color(0.3, 0.34, 0.3), 0.02, 34)
	return p.tex()


func _build_bulb_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 30, 2)
	p.vline(15, 0, 8, Color(0.2, 0.2, 0.18))
	p.circle(15, 12, 4, Color(0.75, 1.0, 0.78))
	p.circle(15, 12, 2.5, Color(0.9, 1.0, 0.92))
	p.circle(15, 14, 10, Color(0.6, 1.0, 0.65, 0.08))
	p.circle(15, 14, 6, Color(0.7, 1.0, 0.72, 0.1))
	return p.tex()


func _build_drain_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(20, 12, 2)
	p.ellipse(10, 6, 9, 5, Color(0.3, 0.33, 0.3))
	p.ellipse(10, 6, 7, 3.5, Color(0.18, 0.2, 0.18))
	p.hline(5, 5, 10, Color(0.1, 0.12, 0.1))
	p.hline(5, 7, 10, Color(0.1, 0.12, 0.1))
	p.vline(7, 4, 5, Color(0.1, 0.12, 0.1))
	p.vline(12, 4, 5, Color(0.1, 0.12, 0.1))
	return p.tex()


func _build_shelf_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(46, 56, 2)
	p.rect(1, 1, 44, 54, Color(0.42, 0.3, 0.18))
	p.rect_outline(1, 1, 44, 54, Color(0.28, 0.19, 0.1))
	var labels := [Color(0.9, 0.3, 0.25), Color(0.9, 0.9, 0.85), Color(0.95, 0.85, 0.3), Color(0.35, 0.5, 0.9), Color(0.4, 0.8, 0.45), Color(0.9, 0.9, 0.85)]
	var li := 0
	for row in 3:
		p.rect(3, 4 + row * 17, 40, 14, Color(0.2, 0.14, 0.08))
		p.hline(3, 17 + row * 17, 40, Color(0.5, 0.38, 0.22))
		var tapes: int = [4, 3, 4][row]
		var tx := 5
		for t in tapes:
			# one slot on the middle row stays empty: the tape that isn't there
			if row == 1 and t == 1:
				tx += 10
				continue
			p.rect(tx, 6 + row * 17, 8, 11, Color(0.12, 0.12, 0.14))
			p.rect(tx + 1, 8 + row * 17, 6, 2, labels[li % labels.size()])
			li += 1
			tx += 10
	return p.tex()


func _build_floppy_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(22, 14, 2)
	for i in 4:
		var y := 10 - i * 3
		var c: Color = [Color(0.25, 0.28, 0.6), Color(0.6, 0.25, 0.28), Color(0.28, 0.28, 0.3), Color(0.25, 0.5, 0.3)][i]
		p.rect(3 + (i % 2) * 2, y, 14, 4, c)
		p.rect_outline(3 + (i % 2) * 2, y, 14, 4, c.darkened(0.4))
		p.rect(6 + (i % 2) * 2, y + 1, 5, 2, Color(0.9, 0.9, 0.85))
	return p.tex()


func _build_standee_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 52, 2)
	var skin := Color(0.9, 0.7, 0.55)
	# MAX BLAST: jaw first, questions later
	p.rect(6, 40, 18, 6, Color(0.7, 0.65, 0.55))  # base
	p.rect(11, 34, 8, 7, Color(0.25, 0.3, 0.55))  # jeans, acid-washed by time
	p.rect(10, 20, 10, 15, Color(0.65, 0.2, 0.2)) # jacket
	p.rect(8, 21, 3, 9, Color(0.65, 0.2, 0.2))
	p.rect(19, 21, 3, 9, Color(0.65, 0.2, 0.2))
	p.rect(12, 12, 6, 8, skin)
	p.rect(11, 9, 8, 4, Color(0.35, 0.22, 0.12))  # hair with structural integrity
	p.hline(12, 15, 2, Color(0.1, 0.1, 0.1))
	p.hline(16, 15, 2, Color(0.1, 0.1, 0.1))
	p.hline(13, 18, 4, Color(0.6, 0.4, 0.3))       # the confident line of a mouth
	p.rect(6, 24, 3, 3, skin)                      # thumbs-up, eroded
	# faded explosion behind him
	p.circle(22, 14, 5, Color(0.95, 0.7, 0.2, 0.5))
	p.circle(24, 12, 3, Color(0.95, 0.4, 0.15, 0.5))
	p.hline(7, 46, 16, Color(0.4, 0.35, 0.3))
	return p.tex()


func _build_boombox_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(30, 22, 2)
	# crate first
	p.rect(2, 12, 26, 10, Color(0.5, 0.38, 0.22))
	p.rect_outline(2, 12, 26, 10, Color(0.35, 0.26, 0.14))
	p.vline(9, 12, 10, Color(0.42, 0.32, 0.18))
	p.vline(20, 12, 10, Color(0.42, 0.32, 0.18))
	# boombox on top
	p.rect(3, 2, 24, 10, Color(0.2, 0.2, 0.24))
	p.rect_outline(3, 2, 24, 10, Color(0.1, 0.1, 0.12))
	p.circle(8, 7, 3, Color(0.35, 0.35, 0.4))
	p.circle(8, 7, 1.5, Color(0.15, 0.15, 0.18))
	p.circle(22, 7, 3, Color(0.35, 0.35, 0.4))
	p.circle(22, 7, 1.5, Color(0.15, 0.15, 0.18))
	p.rect(13, 5, 5, 4, Color(0.1, 0.1, 0.12))
	p.rect(14, 6, 3, 2, Color(0.6, 0.45, 0.25))   # the tape, visible in the deck
	p.hline(4, 3, 8, Color(0.5, 0.5, 0.55))
	# a couple of loose cassettes beside it
	p.rect(24, 14, 5, 3, Color(0.15, 0.15, 0.18))
	p.rect(23, 18, 5, 3, Color(0.6, 0.2, 0.2))
	return p.tex()


func _build_phone_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(22, 20, 2)
	# little table
	p.rect(2, 12, 18, 2, Color(0.45, 0.32, 0.18))
	p.vline(4, 14, 6, Color(0.35, 0.24, 0.13))
	p.vline(17, 14, 6, Color(0.35, 0.24, 0.13))
	# rotary phone, cherry red
	p.poly(PackedVector2Array([Vector2(4, 12), Vector2(18, 12), Vector2(16, 5), Vector2(6, 5)]), Color(0.75, 0.15, 0.15))
	p.circle(11, 9, 3, Color(0.9, 0.85, 0.8))
	for i in 6:
		var a := TAU * float(i) / 8.0 - 1.9
		p.dot(int(11 + cos(a) * 2.2), int(9 + sin(a) * 2.2), Color(0.3, 0.1, 0.1))
	p.rect(5, 3, 12, 3, Color(0.6, 0.1, 0.1))  # handset
	p.dot(5, 4, Color(0.4, 0.05, 0.05))
	p.dot(16, 4, Color(0.4, 0.05, 0.05))
	return p.tex()


func _build_lava_tex(lit: bool) -> Texture2D:
	var p: Painter = AssetLib.painter(14, 24, 2)
	var glass := Color(0.5, 0.25, 0.45, 0.9) if not lit else Color(0.7, 0.3, 0.55, 0.95)
	var blob := Color(0.95, 0.5, 0.2) if not lit else Color(1.0, 0.65, 0.25)
	p.poly(PackedVector2Array([Vector2(4, 4), Vector2(10, 4), Vector2(12, 18), Vector2(2, 18)]), glass)
	p.ellipse(7, 15, 2.5, 2, blob)
	p.ellipse(6, 9, 1.5, 2, blob)
	p.dot(9, 6, blob)
	p.rect(3, 18, 8, 3, Color(0.75, 0.7, 0.3))
	p.rect(4, 1, 6, 3, Color(0.75, 0.7, 0.3))
	if lit:
		p.ellipse(7, 11, 5, 8, Color(1.0, 0.7, 0.3, 0.15))
	return p.tex()


func _build_beanbag_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(42, 20, 2)
	p.ellipse(21, 12, 19, 7, Color(0.5, 0.2, 0.4))
	p.ellipse(21, 9, 16, 6, Color(0.62, 0.28, 0.5))
	p.ellipse(19, 7, 8, 3, Color(0.72, 0.38, 0.58))
	# the dent of one significant landing
	p.ellipse(23, 8, 6, 2.5, Color(0.45, 0.18, 0.36))
	return p.tex()


func _build_bike_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(34, 28, 2)
	var steel := Color(0.6, 0.6, 0.65)
	p.circle(9, 20, 6, Color(0.3, 0.3, 0.34))     # flywheel
	p.circle(9, 20, 4, Color(0.45, 0.45, 0.5))
	p.line(9, 20, 20, 10, steel)                   # frame
	p.line(20, 10, 27, 14, steel)
	p.line(27, 14, 27, 20, steel)
	p.hline(24, 20, 7, Color(0.25, 0.25, 0.28))    # base
	p.hline(4, 26, 26, Color(0.25, 0.25, 0.28))
	p.rect(18, 8, 5, 2, Color(0.2, 0.2, 0.22))     # seat
	p.line(6, 12, 10, 14, steel)                   # handlebars
	p.circle(9, 20, 1.2, Color(0.15, 0.15, 0.18))
	p.speckle(2, 6, 30, 20, Color(0.7, 0.7, 0.72, 0.5), 0.03, 44)  # dust
	return p.tex()


func _build_trophy_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(18, 24, 2)
	# stool
	p.rect(3, 16, 12, 2, Color(0.45, 0.32, 0.18))
	p.vline(4, 18, 6, Color(0.35, 0.24, 0.13))
	p.vline(13, 18, 6, Color(0.35, 0.24, 0.13))
	# trophy
	var gold := Color(0.95, 0.8, 0.25)
	p.ellipse(9, 6, 4, 3, gold)
	p.vline(8, 9, 3, gold)
	p.vline(9, 9, 3, gold)
	p.rect(6, 12, 7, 2, Color(0.55, 0.35, 0.15))
	p.line(5, 4, 5, 7, gold)
	p.line(13, 4, 13, 7, gold)
	p.dot(7, 5, Color(1.0, 0.95, 0.7))
	return p.tex()


func _build_heater_tex(open: bool) -> Texture2D:
	var p: Painter = AssetLib.painter(34, 62, 2)
	var body := Color(0.75, 0.73, 0.68)
	p.ellipse(17, 6, 14, 5, body)
	p.rect(3, 6, 28, 46, body)
	p.ellipse(17, 52, 14, 5, Color(0.6, 0.58, 0.54))
	p.vline(3, 6, 46, Color(0.55, 0.53, 0.5))
	p.vline(30, 6, 46, Color(0.55, 0.53, 0.5))
	p.vline(8, 6, 46, Color(0.85, 0.83, 0.78))
	# pipes
	p.rect(10, 0, 3, 6, Color(0.5, 0.5, 0.52))
	p.rect(21, 0, 3, 6, Color(0.5, 0.5, 0.52))
	# warning label nobody has read since the Clinton administration
	p.rect(10, 14, 14, 6, Color(0.9, 0.85, 0.5))
	p.hline(12, 16, 10, Color(0.5, 0.3, 0.1))
	if open:
		p.rect(9, 28, 16, 16, Color(0.15, 0.13, 0.11))
		p.rect_outline(9, 28, 16, 16, Color(0.4, 0.38, 0.35))
		p.dot(12, 40, Color(0.5, 0.7, 0.9))   # drips
		p.dot(18, 43, Color(0.5, 0.7, 0.9, 0.7))
	else:
		p.rect_outline(9, 28, 16, 16, Color(0.5, 0.48, 0.45))
		p.dot(11, 30, Color(0.4, 0.38, 0.35))
		p.dot(23, 30, Color(0.4, 0.38, 0.35))
		p.dot(11, 42, Color(0.4, 0.38, 0.35))
		p.dot(23, 42, Color(0.4, 0.38, 0.35))
	return p.tex()


func _build_arcade_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(38, 66, 2)
	var cab := Color(0.2, 0.16, 0.35)
	p.rect(3, 2, 32, 62, cab)
	p.rect_outline(3, 2, 32, 62, Color(0.1, 0.08, 0.2))
	# marquee
	p.rect(5, 4, 28, 8, Color(0.1, 0.08, 0.22))
	p.hline(7, 7, 24, Color(0.3, 0.9, 0.85))       # GALAXY NIBBLER in spirit
	p.dot(9, 9, Color(0.9, 0.9, 0.3))
	p.dot(28, 9, Color(0.9, 0.4, 0.8))
	# dead screen
	p.rect(7, 14, 24, 18, Color(0.04, 0.05, 0.06))
	p.line(9, 16, 14, 21, Color(0.1, 0.14, 0.15))
	# control deck
	p.poly(PackedVector2Array([Vector2(5, 34), Vector2(33, 34), Vector2(35, 42), Vector2(3, 42)]), Color(0.3, 0.24, 0.5))
	p.circle(12, 38, 1.5, Color(0.9, 0.3, 0.3))
	p.circle(19, 38, 1.5, Color(0.95, 0.85, 0.3))
	p.dot(27, 37, Color(0.2, 0.15, 0.3))
	# coin door with its stubborn little lock
	p.rect(12, 48, 14, 12, Color(0.14, 0.11, 0.26))
	p.rect_outline(12, 48, 14, 12, Color(0.35, 0.3, 0.55))
	p.dot(24, 54, Color(0.8, 0.8, 0.85))            # the lock
	p.rect(15, 51, 3, 5, Color(0.05, 0.04, 0.1))
	p.rect(20, 51, 3, 5, Color(0.05, 0.04, 0.1))
	# scuff marks peeking out from under the cabinet
	p.hline(1, 64, 8, Color(0.32, 0.34, 0.3))
	return p.tex()


func _build_crawl_tex() -> Texture2D:
	var p: Painter = AssetLib.painter(34, 62, 2)
	p.rect(4, 10, 26, 50, Color(0.03, 0.05, 0.06))
	p.rect(6, 14, 22, 46, Color(0.05, 0.1, 0.12))
	# turquoise light leaking from a low opening
	p.rect(8, 34, 18, 26, Color(0.06, 0.2, 0.2))
	p.rect(10, 40, 14, 20, Color(0.1, 0.45, 0.42))
	p.rect(12, 46, 10, 14, Color(0.2, 0.8, 0.72))
	p.ellipse(17, 60, 12, 4, Color(0.25, 0.85, 0.75, 0.5))
	p.rect_outline(4, 10, 26, 50, Color(0.2, 0.24, 0.2))
	return p.tex()
