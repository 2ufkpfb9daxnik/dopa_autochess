class_name ShopOdds
extends RefCounted

const ODDS_ROW_SEPARATION := 5
const ODDS_LABEL_FONT_SIZE := 13
const ODDS_LABEL_OUTLINE_SIZE := 3
const MAX_COST := 7
const TABLE_LEVELS := 20

## Lv1〜10 の 1〜5 コスト（公式表）
const BASE_ODDS: Array[Array] = [
	[100, 0, 0, 0, 0],
	[100, 0, 0, 0, 0],
	[75, 25, 0, 0, 0],
	[55, 30, 15, 0, 0],
	[45, 33, 20, 2, 0],
	[30, 40, 25, 5, 0],
	[19, 30, 40, 10, 1],
	[15, 20, 32, 30, 3],
	[10, 17, 25, 33, 15],
	[5, 10, 20, 40, 25],
]

## Lv11〜20（6・7 コスト含む。Lv15 のみコスト5=40%、Lv20 はコスト6最多）
const HIGH_LEVEL_ODDS: Array[Array] = [
	[3, 6, 14, 28, 26, 18, 5],   # Lv11
	[2, 5, 12, 26, 30, 17, 8],   # Lv12
	[2, 4, 10, 23, 34, 20, 7],   # Lv13
	[1, 4, 9, 21, 37, 21, 7],    # Lv14
	[1, 3, 8, 20, 40, 20, 8],    # Lv15
	[1, 3, 7, 16, 35, 26, 12],   # Lv16
	[1, 2, 6, 14, 30, 30, 17],   # Lv17
	[0, 2, 5, 12, 26, 34, 21],   # Lv18
	[0, 1, 4, 10, 22, 38, 25],   # Lv19
	[0, 1, 4, 10, 20, 40, 25],   # Lv20
]

## Lv8〜10 の 6・7 コスト（5 コスト表から按分）
const MID_EXTENDED: Array[Array] = [
	[0, 1, 0],  # L8: cost6=1
	[0, 2, 1],  # L9: cost6=2, cost7=1
	[0, 5, 2],  # L10: cost6=5, cost7=2
]


static func get_odds(level: int) -> Array:
	var clamped := clampi(level, 1, TABLE_LEVELS)
	var result: Array = []
	result.resize(MAX_COST)
	result.fill(0.0)
	if clamped <= BASE_ODDS.size():
		var base: Array = BASE_ODDS[clamped - 1]
		for cost_index in base.size():
			result[cost_index] = float(base[cost_index])
		if clamped >= 8:
			var ext_index := clamped - 8
			var ext: Array = MID_EXTENDED[ext_index]
			result[5] = float(ext[1])
			result[6] = float(ext[2])
			result[4] -= float(ext[0] + ext[1] + ext[2])
			if result[4] < 0.0:
				result[4] = 0.0
		return _normalize(result)
	var high: Array = HIGH_LEVEL_ODDS[clamped - 11]
	for cost_index in high.size():
		result[cost_index] = float(high[cost_index])
	return _normalize(result)


static func roll_cost(level: int) -> int:
	var odds := get_odds(level)
	var roll := randf() * 100.0
	var cumulative := 0.0
	for cost in MAX_COST:
		cumulative += float(odds[cost])
		if roll < cumulative:
			return cost + 1
	return MAX_COST


static func populate_current_odds_row(row: HBoxContainer, level: int) -> void:
	for child in row.get_children():
		child.queue_free()
	row.add_theme_constant_override("separation", ODDS_ROW_SEPARATION)
	var odds := get_odds(level)
	for cost_index in odds.size():
		var pct := int(round(float(odds[cost_index])))
		if pct <= 0:
			continue
		var label := Label.new()
		label.text = "%d%%" % pct
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", CostColors.get_color(cost_index + 1))
		label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE)
		label.add_theme_font_size_override("font_size", ODDS_LABEL_FONT_SIZE)
		row.add_child(label)


static func measure_current_odds_row_width(level: int) -> float:
	var font := ThemeDB.fallback_font
	var odds := get_odds(level)
	var total := 0.0
	var count := 0
	for cost_index in odds.size():
		var pct := int(round(float(odds[cost_index])))
		if pct <= 0:
			continue
		total += font.get_string_size(
			"%d%%" % pct,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ODDS_LABEL_FONT_SIZE
		).x
		count += 1
	if count == 0:
		return 0.0
	if count == 1:
		return total
	return total + ODDS_ROW_SEPARATION * float(count - 1)


static func populate_odds_grid(grid: GridContainer, highlight_level: int) -> void:
	for child in grid.get_children():
		child.queue_free()
	const LV_WIDTH := 36
	const CELL_WIDTH := 44
	_add_grid_label(grid, "Lv", true, false, LV_WIDTH, 0)
	for cost in range(1, MAX_COST + 1):
		_add_grid_label(grid, str(cost), true, false, CELL_WIDTH, cost)
	for level in range(1, TABLE_LEVELS + 1):
		var is_current := level == highlight_level
		var level_text := str(level)
		if is_current:
			level_text += " ▶"
		_add_grid_label(grid, level_text, false, is_current, LV_WIDTH, 0)
		var odds := get_odds(level)
		for cost_index in MAX_COST:
			var pct := int(round(float(odds[cost_index])))
			var cell_text := str(pct) if pct > 0 else "-"
			_add_grid_label(
				grid,
				cell_text,
				false,
				is_current,
				CELL_WIDTH,
				cost_index + 1
			)


static func _add_grid_label(
	grid: GridContainer,
	text: String,
	is_header: bool,
	is_highlight: bool,
	min_width: int,
	cost: int = 0
) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(min_width, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if is_header:
		label.add_theme_font_size_override("font_size", 14)
		if cost > 0:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", CostColors.get_color(cost))
			label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE)
		else:
			label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	elif is_highlight:
		label.add_theme_font_size_override("font_size", 14)
		if cost > 0 and text != "-":
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", CostColors.get_color(cost))
			label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE + 1)
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	else:
		label.add_theme_font_size_override("font_size", 13)
		if cost > 0 and text != "-":
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", CostColors.get_color(cost))
			label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE)
		else:
			label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	grid.add_child(label)


static func _normalize(odds: Array) -> Array:
	var total := 0.0
	for value in odds:
		total += float(value)
	if total <= 0.0:
		odds[0] = 100.0
		return odds
	if is_equal_approx(total, 100.0):
		return odds
	var scaled: Array = []
	scaled.resize(odds.size())
	for index in odds.size():
		scaled[index] = float(odds[index]) / total * 100.0
	return scaled
