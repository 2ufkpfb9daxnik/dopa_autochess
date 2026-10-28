class_name UnitCatalog
extends RefCounted

const PLACEHOLDER_ICON := preload("res://images/placeholder.png")
static var _icons: Dictionary = {}

const UNITS: Array[Dictionary] = [
	{"id": 1, "name": "アカシ", "cost": 5, "color": Color(0.95, 0.55, 0.12), "synergies": [], "synergy_names": ["ジャックポット", "スキューバ", "時をかける少女"]},
	{"id": 2, "name": "アサヒ", "cost": 2, "color": Color(0.22, 0.48, 0.95), "synergies": [], "synergy_names": ["ナギナタスタイル", "パンドラ・オートロード", "時をかける少女"]},
	{"id": 3, "name": "アシヤ", "cost": 7, "color": Color(0.28, 0.78, 0.38), "synergies": [], "synergy_names": ["わたしのグランパ", "パンドラ・オートロード", "ポップミュージック", "新しい下駄を履く"]},
	{"id": 4, "name": "アヅチ", "cost": 7, "color": Color(0.58, 0.28, 0.88), "synergies": [], "synergy_names": ["パプリカ", "伊豆は飛鳥", "時をかける少女", "カーテンコール"]},
	{"id": 5, "name": "アリタ", "cost": 3, "color": Color(0.95, 0.86, 0.22), "synergies": [], "synergy_names": ["ポップミュージック", "月2-263", "虚人たち"]},
	{"id": 6, "name": "アヤカワ", "cost": 6, "color": Color(0.18, 0.18, 0.24), "synergies": [], "synergy_names": ["モンスター", "時をかける少女", "狂気の沙汰も金次第"]},
]


static func get_icon(unit_id: int) -> Texture2D:
	if _icons.has(unit_id):
		return _icons[unit_id] as Texture2D
	var path := "res://images/characters/%03d.png" % unit_id
	var texture: Texture2D = PLACEHOLDER_ICON
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path) as Texture2D
		if loaded != null:
			texture = loaded
	_icons[unit_id] = texture
	return texture


static func get_unit(unit_id: int) -> Dictionary:
	for unit in UNITS:
		if int(unit["id"]) == unit_id:
			return unit
	return {}


static func get_synergies(unit_id: int) -> Array:
	var data := get_unit(unit_id)
	return data.get("synergies", [])


static func get_synergy_names(unit_id: int) -> String:
	return " ".join(_synergy_name_list(unit_id))


static func get_synergy_lines(unit_id: int) -> String:
	return "\n".join(_synergy_name_list(unit_id))


static func _synergy_name_list(unit_id: int) -> PackedStringArray:
	var data := get_unit(unit_id)
	var names: PackedStringArray = []
	if data.has("synergy_names"):
		for entry in data["synergy_names"]:
			names.append(str(entry))
		return names
	for synergy_id in get_synergies(unit_id):
		names.append(SynergyCatalog.get_synergy_name(int(synergy_id)))
	return names


static func get_unit_ids_by_cost(cost: int) -> Array[int]:
	var ids: Array[int] = []
	for unit in UNITS:
		if int(unit["cost"]) == cost:
			ids.append(int(unit["id"]))
	return ids


static func get_nearest_cost_with_units(target_cost: int) -> int:
	if get_unit_ids_by_cost(target_cost).size() > 0:
		return target_cost
	for delta in range(1, ShopOdds.MAX_COST + 1):
		if target_cost - delta >= 1 and get_unit_ids_by_cost(target_cost - delta).size() > 0:
			return target_cost - delta
		if get_unit_ids_by_cost(target_cost + delta).size() > 0:
			return target_cost + delta
	return int(UNITS[0]["cost"])


static func random_unit_id_for_level(level: int) -> int:
	var cost := ShopOdds.roll_cost(level)
	var pool := get_unit_ids_by_cost(cost)
	if pool.is_empty():
		pool = get_unit_ids_by_cost(get_nearest_cost_with_units(cost))
	return pool[randi_range(0, pool.size() - 1)]


static func random_unit_id() -> int:
	return random_unit_id_for_level(1)
