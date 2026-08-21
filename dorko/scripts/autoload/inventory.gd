extends Node
## Item list + combination rules. Definitions live in res://data/items.json.

signal item_added(id: String)
signal item_removed(id: String)
signal changed
signal selection_feedback(text: String)  # UI toasts ("bar is full", etc.)

const MAX_SLOTS := 10
const ITEMS_PATH := "res://data/items.json"

var items: Array = []          # of String ids, in pickup order
var defs: Dictionary = {}      # id -> {name, look_text, combinable_with}
var combos: Array = []         # [{a, b, result, set_flag?, line?}]


func _ready() -> void:
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		push_error("Inventory: missing " + ITEMS_PATH)
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Inventory: bad items.json")
		return
	for item in data.get("items", []):
		defs[item.id] = item
	combos = data.get("combinations", [])


func reset() -> void:
	items = []
	changed.emit()


func get_def(id: String) -> Dictionary:
	return defs.get(id, {"id": id, "name": id, "look_text": "It resists description."})


func display_name(id: String) -> String:
	return get_def(id).get("name", id)


func look_text(id: String) -> String:
	return get_def(id).get("look_text", "It resists description.")


func has_item(id: String) -> bool:
	return items.has(id)


func add_item(id: String, silent := false) -> bool:
	if items.size() >= MAX_SLOTS:
		selection_feedback.emit("Pockets are a finite resource.")
		return false
	if items.has(id):
		return false
	items.append(id)
	changed.emit()
	if not silent:
		item_added.emit(id)
		AudioBus.play_sfx("pop")
	return true


func remove_item(id: String) -> void:
	if items.has(id):
		items.erase(id)
		item_removed.emit(id)
		changed.emit()


## Try to combine two held items. Returns the result id, or "" if they refuse.
func combine(a: String, b: String) -> String:
	for c in combos:
		if (c.a == a and c.b == b) or (c.a == b and c.b == a):
			remove_item(a)
			remove_item(b)
			add_item(c.result, true)
			AudioBus.play_sfx("pop", 1.2)
			if c.has("set_flag"):
				GameState.set_flag(c.set_flag)
			if c.has("line"):
				DialogueManager.say("Dorko", c.line)
			changed.emit()
			return c.result
	return ""
