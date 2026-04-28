extends Node

const SAVE_FILE_PATH: String = "user://player_profile.cfg"

const DEFAULT_MOUSE_SENSITIVITY: float = 0.006
const MIN_MOUSE_SENSITIVITY: float = 0.001
const MAX_MOUSE_SENSITIVITY: float = 0.02

const KNIFE_SKINS: Dictionary = {
	"default": {
		"display_name": "Default Knife",
		"cost": 0,
		"color": Color(1.0, 1.0, 1.0, 1.0),
	},
	"gold": {
		"display_name": "Gold Knife",
		"cost": 5,
		"color": Color(1.0, 0.76, 0.18, 1.0),
	},
	"crimson": {
		"display_name": "Crimson Knife",
		"cost": 8,
		"color": Color(1.0, 0.18, 0.18, 1.0),
	},
	"void": {
		"display_name": "Void Knife",
		"cost": 12,
		"color": Color(0.42, 0.25, 1.0, 1.0),
	},
}

var coins: int = 0
var owned_knife_skins: Array[String] = ["default"]
var equipped_knife_skin: String = "default"
var mouse_sensitivity: float = DEFAULT_MOUSE_SENSITIVITY
var won_once: bool = false

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_FILE_PATH)
	if err != OK:
		save_profile()
		return

	coins = int(config.get_value("currency", "coins", 0))
	mouse_sensitivity = clampf(float(config.get_value("settings", "mouse_sensitivity", DEFAULT_MOUSE_SENSITIVITY)), MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
	won_once = bool(config.get_value("progress", "won_once", false))

	var owned_csv: String = str(config.get_value("cosmetics", "owned_knife_skins", "default"))
	owned_knife_skins.clear()
	for skin_id in owned_csv.split(",", false):
		if KNIFE_SKINS.has(skin_id) and not owned_knife_skins.has(skin_id):
			owned_knife_skins.append(skin_id)
	if not owned_knife_skins.has("default"):
		owned_knife_skins.push_front("default")

	equipped_knife_skin = str(config.get_value("cosmetics", "equipped_knife_skin", "default"))
	if not owned_knife_skins.has(equipped_knife_skin):
		equipped_knife_skin = "default"

func save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("currency", "coins", coins)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("progress", "won_once", won_once)
	config.set_value("cosmetics", "owned_knife_skins", _get_owned_knife_skins_csv())
	config.set_value("cosmetics", "equipped_knife_skin", equipped_knife_skin)
	config.save(SAVE_FILE_PATH)

func _get_owned_knife_skins_csv() -> String:
	var skin_ids: PackedStringArray = PackedStringArray()
	for skin_id in owned_knife_skins:
		skin_ids.append(skin_id)
	return ",".join(skin_ids)

func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	save_profile()

func owns_knife_skin(skin_id: String) -> bool:
	return owned_knife_skins.has(skin_id)

func buy_or_equip_knife_skin(skin_id: String) -> bool:
	if not KNIFE_SKINS.has(skin_id):
		return false

	if owns_knife_skin(skin_id):
		equipped_knife_skin = skin_id
		save_profile()
		return true

	var cost: int = int(KNIFE_SKINS[skin_id]["cost"])
	if coins < cost:
		return false

	coins -= cost
	owned_knife_skins.append(skin_id)
	equipped_knife_skin = skin_id
	save_profile()
	return true

func get_knife_skin_ids() -> Array[String]:
	return ["default", "gold", "crimson", "void"]

func get_knife_skin_display_name(skin_id: String) -> String:
	var skin_data: Dictionary = KNIFE_SKINS.get(skin_id, KNIFE_SKINS["default"])
	return str(skin_data["display_name"])

func get_knife_skin_cost(skin_id: String) -> int:
	var skin_data: Dictionary = KNIFE_SKINS.get(skin_id, KNIFE_SKINS["default"])
	return int(skin_data["cost"])

func get_equipped_knife_skin_color() -> Color:
	var skin_data: Dictionary = KNIFE_SKINS.get(equipped_knife_skin, KNIFE_SKINS["default"])
	return skin_data["color"] as Color

func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)
	save_profile()
