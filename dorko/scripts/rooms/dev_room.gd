extends BaseRoom
## Developer test room from milestone M1. Not reachable in the normal game;
## boot straight into it with:  godot --path dorko -- --room dev_room

func _room_config() -> void:
	room_id = "dev_room"
	music_name = "hold"
	footstep_surface = "tile"
	horizon_y = 195.0
	spawn_points = {"default": {"pos": Vector2(320, 290), "dir": "down"}}


func _room_setup() -> void:
	# wall + floor
	var wall := add_rect(Rect2(0, 0, 640, horizon_y), Color(0.25, 0.45, 0.55))
	add_parallax(wall, 1.0)
	add_rect(Rect2(0, 40, 640, 8), Color(0.2, 0.36, 0.45), -790)
	add_floor("checker", Color(0.62, 0.6, 0.55), Color(0.5, 0.48, 0.44), 1.0)

	# one test hotspot: a traffic cone with opinions
	var cone_tex := AssetLib.get_or_build("dev_cone", func():
		var p: Painter = AssetLib.painter(20, 26, 2)
		p.poly(PackedVector2Array([Vector2(9, 2), Vector2(11, 2), Vector2(17, 22), Vector2(3, 22)]), Color(1.0, 0.45, 0.1))
		p.rect(1, 22, 18, 3, Color(0.9, 0.4, 0.08))
		p.hline(5, 12, 10, Color(0.95, 0.9, 0.85))
		p.hline(6, 16, 8, Color(0.95, 0.9, 0.85))
		return p.tex())
	var cone := add_prop(cone_tex, Vector2(430, 234))
	var cone_use := func(item_id: String) -> bool:
		if item_id == "bread":
			say("The cone is not hungry. The cone is never hungry.")
			return true
		return false
	add_hotspot({
		"name": "Traffic Cone",
		"pos": Vector2(430, 240),
		"size": Vector2(44, 56),
		"look": [
			"A traffic cone. There is no traffic. It's being proactive.",
			"Orange. Confident. Waiting for a road.",
		],
		"touch": func(): say("I patted the cone. One of us felt something."),
		"use_item": cone_use,
		"visual": cone,
		"interact": Vector2(430, 262),
	})
