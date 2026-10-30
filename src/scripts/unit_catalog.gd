class_name UnitCatalog
extends RefCounted

const PLACEHOLDER_ICON := preload("res://images/placeholder.png")
const PORTRAIT_TOP_SHIFT := 1.0 / 8.0
static var _icons: Dictionary = {}
static var _models: Dictionary = {}

const UNITS: Array[Dictionary] = [
	{"id": 1, "name": "アカシ", "cost": 5, "color": Color(0.95, 0.55, 0.12), "synergies": [], "synergy_names": ["ジャックポット", "スキューバ", "時をかける少女"]},
	{"id": 2, "name": "アサヒ", "cost": 2, "color": Color(0.22, 0.48, 0.95), "synergies": [], "synergy_names": ["ナギナタスタイル", "パンドラ・オートロード", "時をかける少女"]},
	{"id": 3, "name": "アシヤ", "cost": 7, "color": Color(0.28, 0.78, 0.38), "synergies": [], "synergy_names": ["わたしのグランパ", "パンドラ・オートロード", "ポップミュージック", "新しい下駄を履く"]},
	{"id": 4, "name": "アヅチ", "cost": 7, "color": Color(0.58, 0.28, 0.88), "synergies": [], "synergy_names": ["パプリカ", "伊豆は飛鳥", "時をかける少女", "カーテンコール"]},
	{"id": 5, "name": "アリタ", "cost": 3, "color": Color(0.95, 0.86, 0.22), "synergies": [], "synergy_names": ["ポップミュージック", "月2-263", "虚人たち"]},
	{"id": 6, "name": "アヤカワ", "cost": 6, "color": Color(0.18, 0.18, 0.24), "synergies": [], "synergy_names": ["モンスター", "時をかける少女", "狂気の沙汰も金次第"]},
	{"id": 7, "name": "アワジ", "cost": 3, "color": Color(0.55, 0.78, 0.95), "synergies": [], "synergy_names": ["カルカドル", "スキューバ", "ヨッパ谷への降下"]},
	{"id": 8, "name": "イクノ", "cost": 2, "color": Color(0.65, 0.82, 0.95), "synergies": [], "synergy_names": ["アンジップ", "モンスター", "文学部唯野教授"]},
	{"id": 9, "name": "イケダ", "cost": 6, "color": Color(0.28, 0.55, 0.88), "synergies": [], "synergy_names": ["オシレーター・スペースシップ", "カルカドル", "虚人たち"]},
	{"id": 10, "name": "イズミ", "cost": 5, "color": Color(0.72, 0.42, 0.78), "synergies": [], "synergy_names": ["わたしのグランパ", "カルカドル", "スウィング"]},
	{"id": 11, "name": "イセ", "cost": 5, "color": Color(0.55, 0.42, 0.72), "synergies": [], "synergy_names": ["ギプノーザ", "パプリカ", "伊豆は飛鳥"]},
	{"id": 12, "name": "イタミ", "cost": 5, "color": Color(0.42, 0.72, 0.55), "synergies": [], "synergy_names": ["パースペクティブ", "東海道戦争", "虚人たち"]},
	{"id": 13, "name": "イナベ", "cost": 5, "color": Color(0.35, 0.68, 0.48), "synergies": [], "synergy_names": ["オシレーター・スペースシップ", "ワンパターン", "文学部唯野教授"]},
	{"id": 14, "name": "イバラキ", "cost": 2, "color": Color(0.32, 0.58, 0.86), "synergies": [], "synergy_names": ["わたしのグランパ", "スウィング", "東雲"]},
	{"id": 15, "name": "ウダ", "cost": 4, "color": Color(0.88, 0.72, 0.28), "synergies": [], "synergy_names": ["わたしのグランパ", "旅のラゴス", "家族八景"]},
	{"id": 16, "name": "オウミ", "cost": 3, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["スウィング", "新しい下駄を履く", "世界はゴ冗談"]},
	{"id": 17, "name": "オオツ", "cost": 3, "color": Color(0.78, 0.55, 0.22), "synergies": [], "synergy_names": ["ランドセル", "大いなる助走", "ハイブリッド月"]},
	{"id": 18, "name": "オノ", "cost": 2, "color": Color(0.86, 0.38, 0.28), "synergies": [], "synergy_names": ["カルカドル", "笑うな", "ワンパターン"]},
	{"id": 19, "name": "カコガワ", "cost": 1, "color": Color(0.86, 0.38, 0.28), "synergies": [], "synergy_names": ["ジャックポット", "ナギナタスタイル", "朝のガスパール"]},
	{"id": 20, "name": "カシバ", "cost": 5, "color": Color(0.55, 0.42, 0.28), "synergies": [], "synergy_names": ["ビアンカ・オーバースタディ", "ポプリ", "狂気の沙汰も金次第"]},
	{"id": 21, "name": "カタノ", "cost": 4, "color": Color(0.55, 0.42, 0.28), "synergies": [], "synergy_names": ["スキューバ", "メタモルフォセス群島", "狂気の沙汰も金次第"]},
	{"id": 22, "name": "カツヤマ", "cost": 7, "color": Color(0.72, 0.55, 0.18), "synergies": [], "synergy_names": ["オシレーター・スペースシップ", "スキューバ", "時をかける少女", "文学部唯野教授"]},
	{"id": 23, "name": "カトウ", "cost": 3, "color": Color(0.9, 0.78, 0.28), "synergies": [], "synergy_names": ["マザリンの宝石", "旅のラゴス", "家族八景"]},
	{"id": 24, "name": "カドマ", "cost": 7, "color": Color(0.55, 0.42, 0.28), "synergies": [], "synergy_names": ["カルカドル", "ディープ・アーキテクチャ", "パースペクティブ", "マザリンの宝石"]},
	{"id": 25, "name": "カワイ", "cost": 1, "color": Color(0.42, 0.78, 0.55), "synergies": [], "synergy_names": ["家族八景", "文学部唯野教授", "農協月へ行く"]},
	{"id": 26, "name": "カンザキ", "cost": 2, "color": Color(0.42, 0.78, 0.55), "synergies": [], "synergy_names": ["スキューバ", "マザリンの宝石", "虚人たち"]},
	{"id": 27, "name": "キタザワ", "cost": 2, "color": Color(0.86, 0.38, 0.28), "synergies": [], "synergy_names": ["にぎやかな未来", "パースペクティブ", "朝のガスパール"]},
	{"id": 28, "name": "キノモト", "cost": 1, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["ポップミュージック", "モナドの領域", "新しい下駄を履く"]},
	{"id": 29, "name": "クドヤマ", "cost": 6, "color": Color(0.72, 0.42, 0.78), "synergies": [], "synergy_names": ["ソア橋", "カーテンコール", "家族八景"]},
	{"id": 30, "name": "クマノ", "cost": 6, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["パースペクティブ", "月2-263", "四つの署名"]},
	{"id": 31, "name": "クワナ", "cost": 4, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["モナドの領域", "世界はゴ冗談", "文学部唯野教授"]},
	{"id": 32, "name": "コウリョー", "cost": 4, "color": Color(0.72, 0.42, 0.78), "synergies": [], "synergy_names": ["アンジップ", "新しい下駄を履く", "四つの署名"]},
	{"id": 33, "name": "ゴジョー", "cost": 3, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["ギプノーザ", "ワンパターン", "世界はゴ冗談"]},
	{"id": 34, "name": "ゴセ", "cost": 5, "color": Color(0.55, 0.82, 0.95), "synergies": [], "synergy_names": ["大いなる助走", "シグナル・ノイズ", "家族八景"]},
	{"id": 35, "name": "サカイ", "cost": 7, "color": Color(0.42, 0.78, 0.55), "synergies": [], "synergy_names": ["スウィング", "スキューバ", "四つの署名", "家族八景"]},
	{"id": 36, "name": "サクライ", "cost": 6, "color": Color(0.28, 0.62, 0.78), "synergies": [], "synergy_names": ["ビアンカ・オーバースタディ", "モナドの領域", "ハイブリッド月"]},
	{"id": 42, "name": "スイタ", "cost": 3, "color": Color(0.42, 0.62, 0.28), "synergies": [], "synergy_names": ["オシレーター・スペースシップ", "時をかける少女", "ビストロン"]},
	{"id": 60, "name": "トヨノ", "cost": 1, "color": Color(0.9, 0.78, 0.32), "synergies": [], "synergy_names": ["パンドラ・オートロード", "ランドセル", "時をかける少女"]},
	{"id": 79, "name": "フクサキ", "cost": 4, "color": Color(0.28, 0.58, 0.86), "synergies": [], "synergy_names": ["ソア橋", "ポップミュージック", "時をかける少女"]},
	{"id": 88, "name": "ミヤケ", "cost": 6, "color": Color(0.9, 0.35, 0.28), "synergies": [], "synergy_names": ["ジャックポット", "時をかける少女", "ビストロン", "敵"]},
	{"id": 104, "name": "KTRNKSY", "cost": 2, "color": Color(0.86, 0.28, 0.2), "synergies": [], "synergy_names": ["わたしのグランパ", "時をかける少女", "ギリシャ語通訳"]},
]


static func get_icon(unit_id: int) -> Texture2D:
	if unit_id < 1:
		return PLACEHOLDER_ICON
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


static func portrait_source_rect(texture: Texture2D, dest_size: Vector2) -> Rect2:
	var tex_size := texture.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0:
		return Rect2(Vector2.ZERO, tex_size)
	var window := Rect2(0.0, tex_size.y * PORTRAIT_TOP_SHIFT, tex_size.x, tex_size.y * 0.5)
	if window.end.y > tex_size.y:
		window.position.y = maxf(0.0, tex_size.y - window.size.y)
	if dest_size.x <= 1.0 or dest_size.y <= 1.0:
		return window
	var scale := maxf(dest_size.x / window.size.x, dest_size.y / window.size.y)
	var crop := dest_size / scale
	crop.x = minf(crop.x, window.size.x)
	crop.y = minf(crop.y, window.size.y)
	var origin := Vector2(window.position.x + (window.size.x - crop.x) * 0.5, window.position.y)
	return Rect2(origin, crop)


static func make_portrait(unit_id: int, dest_size: Vector2) -> Texture2D:
	var source := get_icon(unit_id)
	var region := portrait_source_rect(source, dest_size)
	if region.position == Vector2.ZERO and region.size.is_equal_approx(source.get_size()):
		return source
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas


static func get_model_scene(unit_id: int) -> PackedScene:
	if unit_id < 1:
		return null
	if _models.has(unit_id):
		return _models[unit_id] as PackedScene
	var scene: PackedScene = null
	var dir_path := "res://models/characters/%03d" % unit_id
	var dir := DirAccess.open(dir_path)
	if dir != null:
		for file_name in dir.get_files():
			if file_name.get_extension().to_lower() != "glb":
				continue
			scene = load(dir_path.path_join(file_name)) as PackedScene
			if scene != null:
				break
	_models[unit_id] = scene
	return scene


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
		names.append(str(synergy_id))
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
