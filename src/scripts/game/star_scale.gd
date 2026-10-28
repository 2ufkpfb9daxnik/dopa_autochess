class_name StarScale
extends RefCounted

## Blank ★2+ cells are ★1 × (scale[star] / scale[★1]).
## Stat scales and the effect fallback live in res://data/star_scales.json.

const PATH := "res://data/star_scales.json"
const EFFECT_DEFAULT: Array[float] = [1.0, 1.2, 1.5, 1.7]

static var _scales: Dictionary = {}
static var _effect_default: Array[float] = [1.0, 1.2, 1.5, 1.7]
static var _loaded := false


static func resolve(stat_name: String, row: Array, stars: int, effect: bool) -> float:
	_ensure()
	var index := clampi(stars, 1, 4) - 1
	var actual: Variant = _cell(row, index)
	if actual != null:
		return float(actual)
	if index == 0:
		return 0.0
	var base: Variant = _cell(row, 0)
	if base == null:
		return 0.0
	var origin := _scale_at(stat_name, 0, effect)
	if origin == 0.0:
		return 0.0
	return float(base) * _scale_at(stat_name, index, effect) / origin


static func rows(body: String, columns: int) -> Dictionary:
	var result := {}
	for raw_line in body.split("\n"):
		var line := str(raw_line).strip_edges()
		if not line.begins_with("|"):
			continue
		var cells := split_row(line)
		if cells.is_empty() or is_label_row(str(cells[0])):
			continue
		var values: Array = []
		for index in columns:
			var cell := ""
			if index + 1 < cells.size():
				cell = str(cells[index + 1])
			values.append(number_or_null(cell))
		result[str(cells[0])] = values
	return result


static func split_row(line: String) -> PackedStringArray:
	var trimmed := line.strip_edges()
	if trimmed.begins_with("|"):
		trimmed = trimmed.substr(1)
	if trimmed.ends_with("|"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	var cells := PackedStringArray()
	for part in trimmed.split("|"):
		cells.append(str(part).strip_edges())
	return cells


static func is_label_row(name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed in ["ステータス", "効果値", "行動", "属性"]:
		return true
	return trimmed.replace(":", "").replace("-", "").strip_edges().is_empty()


static func number_or_null(cell: String) -> Variant:
	var text := cell.strip_edges()
	if text.is_empty() or text == "-":
		return null
	if not text.is_valid_float():
		return null
	return float(text)


static func format_number(value: float) -> String:
	var rounded := snappedf(value, 0.01)
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	var text := "%0.2f" % rounded
	if text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	return text


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var raw_scales: Variant = data.get("scales", {})
	if typeof(raw_scales) == TYPE_DICTIONARY:
		_scales = raw_scales
	var raw_default: Variant = data.get("effectDefault", [])
	if raw_default is Array and raw_default.size() >= 4:
		_effect_default = [
			float(raw_default[0]),
			float(raw_default[1]),
			float(raw_default[2]),
			float(raw_default[3]),
		]


static func _scale_at(stat_name: String, index: int, effect: bool) -> float:
	var raw: Variant = _scales.get(stat_name, null)
	if raw is Array and index < raw.size():
		return float(raw[index])
	if effect and index < _effect_default.size():
		return _effect_default[index]
	return 1.0


static func _cell(row: Array, index: int) -> Variant:
	if index < 0 or index >= row.size():
		return null
	var value: Variant = row[index]
	if value == null:
		return null
	return float(value)
