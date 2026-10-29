class_name RelicCatalog
extends RefCounted

const DIR := "res://data/relics/"
const IMAGE_DIR := "res://images/relics/"
## UI確認用: いま抽選に出すレリックは 001-006 のみ。
const PICK_POOL: Array[int] = [1, 2, 3, 4, 5, 6]

static var _cache: Dictionary = {}
static var _all_ids: Array[int] = []


static func all_pick_ids() -> Array[int]:
	return PICK_POOL.duplicate()


static func all_ids() -> Array[int]:
	if not _all_ids.is_empty():
		return _all_ids
	var dir := DirAccess.open(DIR)
	if dir == null:
		return _all_ids
	var names: PackedStringArray = []
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "md":
			continue
		names.append(file_name)
	names.sort()
	for file_name in names:
		var stem := file_name.get_basename()
		if not stem.is_valid_int():
			continue
		_all_ids.append(int(stem))
	return _all_ids


static func relic_count() -> int:
	return maxi(all_ids().size(), 1)


## 内部IDの和と積を混ぜ、レリック総数で折り返す。画面には出さない。
static func synthesize_id(left_id: int, right_id: int) -> int:
	var ids := all_ids()
	if ids.is_empty():
		return 1
	var mixed := absi(left_id + right_id + left_id * right_id)
	return int(ids[mixed % ids.size()])


static func get_relic(relic_id: int) -> Dictionary:
	if _cache.has(relic_id):
		return _cache[relic_id]
	var path := DIR + "%03d.md" % relic_id
	if not FileAccess.file_exists(path):
		var empty := {"id": relic_id, "name": "？", "brief": "", "category": "", "equippable": false, "synthesis": false, "effects": {}}
		_cache[relic_id] = empty
		return empty
	var parsed := _parse(FileAccess.get_file_as_string(path), relic_id)
	_cache[relic_id] = parsed
	return parsed


static func get_icon(relic_id: int) -> Texture2D:
	var path := IMAGE_DIR + "%03d.png" % relic_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func random_choices(count: int = 3) -> Array[int]:
	var pool: Array[int] = all_pick_ids()
	pool.shuffle()
	var out: Array[int] = []
	for index in mini(count, pool.size()):
		out.append(pool[index])
	while out.size() < count and not pool.is_empty():
		out.append(pool[randi() % pool.size()])
	return out


static func _parse(text: String, fallback_id: int) -> Dictionary:
	var fields: Dictionary = {}
	var sections: Dictionary = {}
	var current := "header"
	var buf: PackedStringArray = []
	for raw_line in text.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.begins_with("# "):
			continue
		if stripped.begins_with("## "):
			sections[current] = "\n".join(buf).strip_edges()
			current = stripped.substr(3).strip_edges()
			buf = PackedStringArray()
			continue
		buf.append(line)
	sections[current] = "\n".join(buf).strip_edges()
	var header := str(sections.get("header", ""))
	for raw_line in header.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("- ") or line.find(":") < 0:
			continue
		var body := line.substr(2)
		var split_at := body.find(":")
		fields[body.substr(0, split_at).strip_edges()] = body.substr(split_at + 1).strip_edges()
	var effects: Dictionary = {}
	var effect_body := str(sections.get("効果値", ""))
	for raw_line in effect_body.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("|"):
			continue
		var cells := line.split("|")
		if cells.size() < 3:
			continue
		var key := str(cells[1]).strip_edges()
		var value := str(cells[2]).strip_edges()
		if key.is_empty() or key == "---" or key == "効果値" or value == "---:" or value == "値":
			continue
		if value.is_valid_float():
			effects[key] = float(value)
	var relic_id := int(str(fields.get("ID", fallback_id)))
	return {
		"id": relic_id,
		"name": str(fields.get("名前", "レリック")),
		"category": str(fields.get("分類", "")),
		"equippable": str(fields.get("装備可能", "")).strip_edges() == "はい",
		"synthesis": str(fields.get("合成可能", "")).strip_edges() == "はい",
		"brief": str(sections.get("簡単な説明文", "")).strip_edges(),
		"detail": str(sections.get("詳細な説明文", "")).strip_edges(),
		"effects": effects,
	}
