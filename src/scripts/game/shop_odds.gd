class_name ShopOdds
extends RefCounted

const ODDS_ROW_SEPARATION := 5
const ODDS_LABEL_FONT_SIZE := 13
const ODDS_LABEL_OUTLINE_SIZE := 3
const MAX_COST := 7
const TABLE_LEVELS := 20
const BAND_BORDER := Color(0.35, 0.72, 1.0, 1.0)
const BAND_FILL := Color(0.22, 0.48, 0.92, 0.14)
const BAND_BORDER_WIDTH := 2

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


static func populate_current_odds_row(row: Container, level: int) -> void:
	for child in row.get_children():
		child.queue_free()
	row.add_theme_constant_override("separation", 1)
	var odds := get_odds(level)
	for cost_index in odds.size():
		var pct := int(round(float(odds[cost_index])))
		var label := Label.new()
		label.text = "%d  %d%%" % [cost_index + 1, pct]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	const COST_WIDTH := 28
	const CELL_WIDTH := 32
	grid.columns = TABLE_LEVELS + 1
	grid.add_theme_constant_override("v_separation", 0)
	_add_grid_cell(grid, "Lv", true, false, COST_WIDTH, 0, false, false)
	for level in range(1, TABLE_LEVELS + 1):
		var in_band := level == highlight_level
		_add_grid_cell(grid, str(level), true, in_band, CELL_WIDTH, 0, in_band, false)
	for cost in range(1, MAX_COST + 1):
		_add_grid_cell(grid, str(cost), true, false, COST_WIDTH, cost, false, false)
		for level in range(1, TABLE_LEVELS + 1):
			var odds := get_odds(level)
			var pct := int(round(float(odds[cost - 1])))
			var in_band := level == highlight_level
			_add_grid_cell(
				grid,
				str(pct),
				false,
				in_band,
				CELL_WIDTH,
				cost,
				false,
				in_band and cost == MAX_COST
			)


static func _add_grid_cell(
	grid: GridContainer,
	text: String,
	is_header: bool,
	in_band: bool,
	min_width: int,
	cost: int,
	band_top: bool,
	band_bottom: bool
) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_header:
		label.add_theme_font_size_override("font_size", 14)
		if cost > 0:
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", CostColors.get_color(cost))
			label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE)
		else:
			label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	else:
		label.add_theme_font_size_override("font_size", 13)
		if cost > 0 and text != "-":
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", CostColors.get_color(cost))
			label.add_theme_constant_override("outline_size", ODDS_LABEL_OUTLINE_SIZE)
		else:
			label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	if not in_band:
		label.custom_minimum_size = Vector2(min_width, 0)
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_child(label)
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = BAND_FILL
	box.border_color = BAND_BORDER
	box.border_width_left = BAND_BORDER_WIDTH
	box.border_width_right = BAND_BORDER_WIDTH
	box.border_width_top = BAND_BORDER_WIDTH if band_top else 0
	box.border_width_bottom = BAND_BORDER_WIDTH if band_bottom else 0
	box.content_margin_left = 1
	box.content_margin_right = 1
	box.content_margin_top = 1 if band_top else 0
	box.content_margin_bottom = 1 if band_bottom else 0
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(label)
	grid.add_child(panel)


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
