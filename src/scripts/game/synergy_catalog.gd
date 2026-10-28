class_name SynergyCatalog
extends RefCounted

const PATH := "res://data/synergies.md"

static var _loaded := false
static var _by_name: Dictionary = {}


static func get_by_name(synergy_name: String) -> Dictionary:
	_ensure()
	return _by_name.get(synergy_name, {})


static func color_of(synergy_name: String) -> Color:
	var hue := float(absi(synergy_name.hash()) % 1000) / 1000.0
	return Color.from_hsv(hue, 0.58, 0.95)


static func stage_count(synergy_name: String) -> int:
	var data := get_by_name(synergy_name)
	var stages: Array = data.get("stages", [])
	return stages.size()


static func reached_index(synergy_name: String, count: int) -> int:
	var data := get_by_name(synergy_name)
	var stages: Array = data.get("stages", [])
	var reached := 0
	for stage in stages:
		if count >= int(stage.get("count", 0)):
			reached += 1
		else:
			break
	return reached


static func is_active(synergy_name: String, count: int) -> bool:
	return reached_index(synergy_name, count) > 0


static func active_effect(synergy_name: String, count: int) -> String:
	var data := get_by_name(synergy_name)
	var stages: Array = data.get("stages", [])
	var effect := ""
	for stage in stages:
		if count >= int(stage.get("count", 0)):
			effect = str(stage.get("effect", ""))
		else:
			break
	return effect


static func stat_bonus(effect: String) -> Dictionary:
	var bonus := {
		"hp": 0.0,
		"attack": 0.0,
		"defense": 0.0,
		"speed": 0.0,
		"crit_damage": 0.0,
		"penetration": 0.0,
		"bonus_damage": 0.0,
		"gauge_rate": 0.0,
		"enemy_resist": 0.0,
		"enemy_taken": 0.0,
	}
	if effect.is_empty():
		return bonus
	var amount := _signed_percent(effect)
	if amount == 0.0:
		return bonus
	if effect.contains("敵の被ダメージ"):
		bonus["enemy_taken"] = amount
	elif effect.contains("全属性耐性") or effect.contains("属性耐性"):
		bonus["enemy_resist"] = amount
	elif effect.contains("体力"):
		bonus["hp"] = amount
	elif effect.contains("防御力"):
		bonus["defense"] = amount
	elif effect.contains("速度"):
		bonus["speed"] = amount
	elif effect.contains("攻撃力"):
		bonus["attack"] = amount
	elif effect.contains("クリティカルダメージ"):
		bonus["crit_damage"] = amount
	elif effect.contains("貫通"):
		bonus["penetration"] = amount
	elif effect.contains("ダメージ増加"):
		bonus["bonus_damage"] = amount
	elif effect.contains("ゲージ増加"):
		bonus["gauge_rate"] = amount
	return bonus


static func _signed_percent(text: String) -> float:
	var pattern := RegEx.new()
	pattern.compile("([+-]?\\d+(?:\\.\\d+)?)\\s*%")
	var found := pattern.search(text)
	if found == null:
		return 0.0
	return float(found.get_string(1)) / 100.0


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_by_name = {}
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var blocks := text.split("\n## ", false)
	for index in blocks.size():
		var block := blocks[index]
		if index == 0:
			continue
		var parsed := _parse_block(block)
		if parsed.is_empty():
			continue
		_by_name[str(parsed["name"])] = parsed


static func _parse_block(block: String) -> Dictionary:
	var lines := block.split("\n")
	if lines.is_empty():
		return {}
	var synergy_name := lines[0].strip_edges()
	if synergy_name.is_empty():
		return {}
	var summary_lines: PackedStringArray = []
	var stages: Array[Dictionary] = []
	var in_stages := false
	var in_table := false
	for line_index in range(1, lines.size()):
		var line := lines[line_index].strip_edges()
		if line.begins_with("### "):
			in_stages = line.contains("段階")
			in_table = false
			continue
		if in_stages:
			if line.begins_with("|"):
				in_table = true
				var stage := _parse_stage_row(line)
				if not stage.is_empty():
					stages.append(stage)
				continue
			if in_table:
				break
			continue
		if line.is_empty() or line.begins_with("|") or line.begins_with("#"):
			continue
		summary_lines.append(line)
	return {
		"name": synergy_name,
		"summary": "\n".join(summary_lines),
		"stages": stages,
	}


static func _parse_stage_row(line: String) -> Dictionary:
	if line.contains("---") or line.contains("人数"):
		return {}
	var cells := line.split("|")
	if cells.size() < 3:
		return {}
	var count_text := cells[1].strip_edges()
	if not count_text.is_valid_int():
		return {}
	return {
		"count": int(count_text),
		"effect": cells[2].strip_edges(),
	}
