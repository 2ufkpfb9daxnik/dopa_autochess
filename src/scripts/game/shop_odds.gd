class_name ShopOdds
extends RefCounted

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

## Lv11〜20（6・7 コスト含む、高レベルほど高コスト寄り）
const HIGH_LEVEL_ODDS: Array[Array] = [
	[4, 8, 18, 35, 20, 10, 5],
	[3, 6, 15, 32, 20, 15, 9],
	[2, 5, 12, 28, 22, 18, 13],
	[2, 4, 10, 25, 22, 20, 17],
	[1, 3, 8, 22, 23, 22, 21],
	[1, 2, 6, 18, 24, 24, 25],
	[1, 2, 5, 15, 24, 26, 27],
	[0, 1, 4, 12, 24, 28, 31],
	[0, 1, 3, 10, 23, 30, 33],
	[0, 0, 2, 8, 22, 32, 36],
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


static func populate_odds_grid(grid: GridContainer, highlight_level: int) -> void:
	for child in grid.get_children():
		child.queue_free()
	const LV_WIDTH := 32
	const CELL_WIDTH := 40
	_add_grid_label(grid, "Lv", true, false, LV_WIDTH)
	for cost in range(1, MAX_COST + 1):
		_add_grid_label(grid, str(cost), true, false, CELL_WIDTH)
	for level in range(1, TABLE_LEVELS + 1):
		var is_current := level == highlight_level
		var level_text := str(level)
		if is_current:
			level_text += " ▶"
		_add_grid_label(grid, level_text, false, is_current, LV_WIDTH)
		var odds := get_odds(level)
		for cost_index in MAX_COST:
			_add_grid_label(
				grid,
				str(int(round(float(odds[cost_index])))),
				false,
				is_current,
				CELL_WIDTH
			)


static func _add_grid_label(
	grid: GridContainer,
	text: String,
	is_header: bool,
	is_highlight: bool,
	min_width: int
) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(min_width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_header:
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	elif is_highlight:
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	else:
		label.add_theme_font_size_override("font_size", 12)
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
