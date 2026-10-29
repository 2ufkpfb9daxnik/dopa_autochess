class_name CharacterText
extends RefCounted

const DIR := "res://data/characters/"
const DETAIL_ORDER: PackedStringArray = [
	"詳細な説明文",
	"バフ/デバフ",
	"効果値",
	"行動割合",
	"各種ステータス",
	"属性補正",
]
const SKIP_DETAIL: PackedStringArray = ["header", "簡単な説明文", "フレーバー"]
const STATUS_ICONS := {
	"HP": "res://images/status/hp.png",
	"最大HP": "res://images/status/hp.png",
	"攻撃": "res://images/status/attack.png",
	"攻撃力": "res://images/status/attack.png",
	"防御": "res://images/status/guard.png",
	"防御力": "res://images/status/guard.png",
	"ガード": "res://images/status/guard.png",
	"速度": "res://images/status/speed.png",
	"属性耐性": "res://images/status/resist.png",
	"優先度": "res://images/status/priority.png",
	"ターゲット優先度": "res://images/status/priority.png",
	"会心": "res://images/status/crit_rate.png",
	"クリティカル率": "res://images/status/crit_rate.png",
	"クリティカルダメージ倍率": "res://images/status/crit_mult.png",
	"使用": "res://images/status/use.png",
	"攻撃属性": "res://images/status/use.png",
	"得意": "res://images/status/strong.png",
	"苦手": "res://images/status/weak.png",
	"コスト": "res://images/status/coin.png",
	"コイン": "res://images/status/coin.png",
}
const ATTRIBUTE_ICONS := {
	"炎": {"path": "res://images/attributes/fire.png", "aspect": 0.7855},
	"水": {"path": "res://images/attributes/water.png", "aspect": 0.6284},
	"雷": {"path": "res://images/attributes/thunder.png", "aspect": 0.5451},
	"土": {"path": "res://images/attributes/earth.png", "aspect": 0.7791},
	"氷": {"path": "res://images/attributes/ice.png", "aspect": 0.6147},
	"風": {"path": "res://images/attributes/wind.png", "aspect": 0.7489},
	"吸収": {"path": "res://images/attributes/absorption.png", "aspect": 0.7087},
}


static func load_profile(unit_id: int) -> Dictionary:
	var path := DIR + "%03d.md" % unit_id
	if not FileAccess.file_exists(path):
		return {}
	return _parse(FileAccess.get_file_as_string(path))


static func status_icon(label: String) -> String:
	return str(STATUS_ICONS.get(label.strip_edges(), ""))


static func attribute_icon(attr_name: String) -> String:
	var entry: Variant = ATTRIBUTE_ICONS.get(attr_name.strip_edges(), null)
	if entry is Dictionary:
		return str((entry as Dictionary).get("path", ""))
	return ""


static func icon_px(font_size: int) -> int:
	return maxi(int(round(float(font_size) * 2.2)), 1)


static func with_attribute_icons(text: String, px: int) -> String:
	var result := text
	for attr_name in ATTRIBUTE_ICONS.keys():
		var entry: Dictionary = ATTRIBUTE_ICONS[attr_name]
		var path := str(entry.get("path", ""))
		var width := maxi(1, int(round(float(px) * float(entry.get("aspect", 1.0)))))
		var tag := "[hint=%s属性][img=%dx%d]%s[/img][/hint]" % [attr_name, width, px, path]
		result = result.replace(str(attr_name), tag)
	return result


static func summary_info(unit_id: int, stars: int) -> Dictionary:
	var profile := load_profile(unit_id)
	var fields: Dictionary = profile.get("fields", {})
	var sections: Dictionary = profile.get("sections", {})
	var data := UnitCatalog.get_unit(unit_id)
	return {
		"name": str(fields.get("名前", data.get("name", "キャラクター"))),
		"stars": clampi(stars, 1, 4),
		"cost": str(fields.get("コスト", data.get("cost", ""))),
		"synergies": str(fields.get("シナジー", UnitCatalog.get_synergy_names(unit_id))),
		"attack": str(fields.get("攻撃属性", "")).strip_edges(),
		"strong": _split_csv(str(fields.get("得意属性3つ", ""))),
		"weak": _split_csv(str(fields.get("苦手属性3つ", ""))),
		"stat_rows": stat_rows(unit_id, stars),
		"brief": str(sections.get("簡単な説明文", "")).strip_edges(),
	}


static func detail_blocks(unit_id: int) -> Array:
	var profile := load_profile(unit_id)
	var sections: Dictionary = profile.get("sections", {})
	var blocks: Array = []
	var used := {}
	for title in DETAIL_ORDER:
		used[title] = true
		var body := str(sections.get(title, "")).strip_edges()
		if body.is_empty():
			continue
		blocks.append({"title": title, "parts": _blocks_from_body(title, body)})
	for title in sections.keys():
		var key := str(title)
		if used.has(key) or SKIP_DETAIL.has(key):
			continue
		var body := str(sections[title]).strip_edges()
		if body.is_empty():
			continue
		blocks.append({"title": key, "parts": _blocks_from_body(key, body)})
	return blocks


static func _parse(text: String) -> Dictionary:
	var sections := {}
	var fields := {}
	var current := "header"
	var buf := PackedStringArray()
	for raw_line in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var line := str(raw_line)
		if line.begins_with("## "):
			sections[current] = "\n".join(buf).strip_edges()
			current = line.substr(3).strip_edges()
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
	return {"fields": fields, "sections": sections}


static func stat_rows(unit_id: int, stars: int) -> Array:
	var sheet := CharacterSheet.make(unit_id, stars)
	if sheet.is_empty():
		return []
	return [
		_stat_item("HP", str(int(sheet["hp"]))),
		_stat_item("攻撃", str(int(round(float(sheet["attack"]))))),
		_stat_item("防御", str(int(round(float(sheet["defense"]))))),
		_stat_item("速度", str(int(sheet["speed"]))),
		_stat_item("属性耐性", _signed_percent(float(sheet["attribute_resist"]))),
		_stat_item("優先度", str(int(sheet["priority"]))),
		_stat_item("会心", _signed_percent(float(sheet["crit_rate"]))),
	]


static func _stat_item(label: String, value: String) -> Dictionary:
	return {"label": label, "value": value, "icon": status_icon(label)}


static func _split_csv(value: String) -> PackedStringArray:
	var out := PackedStringArray()
	for part in value.split(","):
		var item := part.strip_edges()
		if not item.is_empty():
			out.append(item)
	return out


static func _blocks_from_body(title: String, body: String) -> Array:
	var parts: Array = []
	var paragraph := PackedStringArray()
	var table_rows: Array = []
	var in_table := false
	for raw_line in body.split("\n"):
		var stripped := str(raw_line).strip_edges()
		if stripped.begins_with("|"):
			if not in_table:
				_flush_paragraph(parts, paragraph)
				paragraph = PackedStringArray()
				in_table = true
				table_rows = []
			var cells := StarScale.split_row(stripped)
			if _is_separator(cells):
				continue
			var row: Array = []
			for cell in cells:
				row.append(str(cell))
			table_rows.append(row)
			continue
		if in_table:
			parts.append({"kind": "table", "rows": _finalize_table(title, table_rows)})
			in_table = false
			table_rows = []
		paragraph.append(str(raw_line))
	if in_table:
		parts.append({"kind": "table", "rows": _finalize_table(title, table_rows)})
	_flush_paragraph(parts, paragraph)
	return parts


static func _flush_paragraph(parts: Array, paragraph: PackedStringArray) -> void:
	var text := "\n".join(paragraph).strip_edges()
	if text.is_empty():
		return
	parts.append({"kind": "text", "text": text})


static func _is_separator(cells: PackedStringArray) -> bool:
	if cells.is_empty():
		return true
	for cell in cells:
		if not str(cell).replace(":", "").replace("-", "").strip_edges().is_empty():
			return false
	return true


static func _finalize_table(title: String, rows: Array) -> Array:
	if rows.is_empty():
		return rows
	var effect := title.begins_with("効果値")
	var stats := title.begins_with("各種ステータス")
	var attrs := title.begins_with("属性補正")
	var out: Array = []
	var header: Array = rows[0]
	var pretty_header: Array = []
	for cell in header:
		pretty_header.append(_pretty_star_label(str(cell)))
	out.append(pretty_header)
	for index in range(1, rows.size()):
		var source: Array = rows[index]
		if effect or stats:
			out.append(_scaled_row(source, effect))
		elif attrs:
			out.append(_attribute_row(source))
		else:
			var copy: Array = []
			for cell in source:
				copy.append(_pretty_star_label(str(cell)))
			out.append(copy)
	return out


static func _scaled_row(source: Array, effect: bool) -> Array:
	var stat_name := ""
	if source.size() > 0:
		stat_name = str(source[0])
	var values: Array = []
	for index in 4:
		var raw := ""
		if index + 1 < source.size():
			raw = str(source[index + 1])
		values.append(StarScale.number_or_null(raw))
	var rendered: Array = [stat_name]
	for index in 4:
		var cell: Variant = values[index]
		if cell == null and index > 0:
			cell = StarScale.resolve(stat_name, values, index + 1, effect)
		if cell == null:
			rendered.append("")
		else:
			rendered.append(StarScale.format_number(float(cell)))
	return rendered


static func _attribute_row(source: Array) -> Array:
	var rendered: Array = []
	for index in source.size():
		var text := str(source[index]).strip_edges()
		if index > 0 and text.is_empty():
			text = "0"
		rendered.append(text)
	return rendered


static func _pretty_star_label(text: String) -> String:
	match text:
		"★1":
			return "★"
		"★2":
			return "★★"
		"★3":
			return "★★★"
		"★4":
			return "★★★★"
	return text


static func _signed_percent(ratio: float) -> String:
	var points := int(round(ratio * 100.0))
	if points > 0:
		return "+%d%%" % points
	return "%d%%" % points
