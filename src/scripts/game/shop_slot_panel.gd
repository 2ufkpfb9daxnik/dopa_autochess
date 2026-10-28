class_name ShopSlotPanel
extends Button

const PLACEHOLDER_TEXTURE := preload("res://images/placeholder.png")
const _FRAME_BLEED := 1.22
const _MIN_FONT := 7

@onready var _frame: TextureRect = $Frame
@onready var _illustration: TextureRect = $ContentRoot/Illustration
@onready var _synergy_backdrop: ColorRect = $ContentRoot/SynergyBackdrop
@onready var _synergy_label: Label = $ContentRoot/SynergyLabel
@onready var _stars_label: Label = $ContentRoot/StarsLabel
@onready var _bottom_bar_panel: Panel = $BottomBarPanel
@onready var _cost_label: Label = $BottomBarPanel/BottomBar/CostLabel
@onready var _name_label: Label = $BottomBarPanel/BottomBar/NameLabel
@onready var _content_root: Control = $ContentRoot
@onready var _empty_label: Label = $EmptyLabel

var _footer: VBoxContainer
var _synergy_box: VBoxContainer
var _name_line: FitLine
var _text_scale := 1.0
var _synergy_lines: PackedStringArray = []
var _name_text := ""


class FitLine:
	extends Control

	var source := ""
	var max_size := 13
	var font_color := Color(0.95, 0.96, 0.98)
	var use_shadow := true

	func setup(line: String, font_size: int, color: Color) -> void:
		source = line
		max_size = maxi(ShopSlotPanel._MIN_FONT, font_size)
		font_color = color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, _font().get_height(max_size))
		queue_redraw()

	func _font() -> Font:
		var theme_font := get_theme_font("font")
		if theme_font == null:
			return ThemeDB.fallback_font
		return theme_font

	func _draw() -> void:
		if source.is_empty() or size.x < 2.0:
			return
		var font := _font()
		var chosen := max_size
		var limit := maxf(4.0, size.x - 4.0)
		while chosen > ShopSlotPanel._MIN_FONT:
			if font.get_string_size(source, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x <= limit:
				break
			chosen -= 1
		var text_height := font.get_height(chosen)
		var baseline := font.get_ascent(chosen) + maxf(0.0, (size.y - text_height) * 0.5)
		if use_shadow:
			draw_string(font, Vector2(1.0, baseline + 1.0), source, HORIZONTAL_ALIGNMENT_CENTER, size.x, chosen, Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0.0, baseline), source, HORIZONTAL_ALIGNMENT_CENTER, size.x, chosen, font_color)


func _ready() -> void:
	text = ""
	flat = true
	clip_contents = false
	_build_footer()
	resized.connect(_fit_frame)
	_illustration.texture = PLACEHOLDER_TEXTURE
	set_sold_out()
	_fit_frame()


func set_sold_out() -> void:
	_content_root.visible = true
	_empty_label.visible = false
	_illustration.texture = PLACEHOLDER_TEXTURE
	_illustration.modulate = Color(1.0, 1.0, 1.0, 0.22)
	_synergy_lines = PackedStringArray()
	_name_text = "売り切れ"
	_stars_label.text = ""
	_cost_label.text = ""
	apply_cost_style(0)
	_rebuild_lines()
	_refresh_text_layout()


func set_unit(unit_id: int) -> void:
	var data := UnitCatalog.get_unit(unit_id)
	_content_root.visible = true
	_empty_label.visible = false
	_illustration.texture = PLACEHOLDER_TEXTURE
	_illustration.modulate = Color.WHITE
	_cost_label.text = str(data["cost"])
	_name_text = str(data["name"])
	_stars_label.text = "★"
	_synergy_lines = _split_synergies(UnitCatalog.get_synergy_lines(unit_id))
	apply_cost_style(int(data["cost"]))
	_rebuild_lines()
	_refresh_text_layout()


func set_card_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	_fit_frame()


func set_text_scale(amount: float) -> void:
	_text_scale = amount
	_apply_font(_stars_label, 16, amount)
	_apply_font(_cost_label, 20, amount)
	_rebuild_lines()
	_refresh_text_layout()


func _build_footer() -> void:
	var bar := _cost_label.get_parent()
	bar.remove_child(_cost_label)
	add_child(_cost_label)
	_cost_label.layout_mode = 0
	_cost_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.visible = false
	_bottom_bar_panel.visible = false
	_synergy_label.visible = false
	_synergy_backdrop.visible = false
	_footer = VBoxContainer.new()
	_footer.layout_mode = 0
	_footer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_footer.add_theme_constant_override("separation", 0)
	add_child(_footer)
	_synergy_box = VBoxContainer.new()
	_synergy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_box.add_theme_constant_override("separation", 0)
	_footer.add_child(_synergy_box)
	_name_line = FitLine.new()
	_name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_name_line)


func _split_synergies(raw: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	for part in raw.split("\n", false):
		var line := str(part).strip_edges()
		if not line.is_empty():
			lines.append(line)
	return lines


func _rebuild_lines() -> void:
	if _synergy_box == null or _name_line == null:
		return
	for child in _synergy_box.get_children():
		_synergy_box.remove_child(child)
		child.free()
	var synergy_size := maxi(_MIN_FONT, int(round(13.0 * _text_scale)))
	var synergy_color := Color(0.96, 0.97, 1.0)
	for line in _synergy_lines:
		var row := FitLine.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_synergy_box.add_child(row)
		row.setup(line, synergy_size, synergy_color)
	_name_line.setup(_name_text, maxi(_MIN_FONT, int(round(14.0 * _text_scale))), Color(0.95, 0.96, 0.98))


func _refresh_text_layout() -> void:
	if _footer == null or size.x < 2.0 or size.y < 2.0:
		return
	_footer.position = Vector2(size.x * 0.12, size.y * 0.58)
	_footer.size = Vector2(size.x * 0.76, size.y * 0.34)
	_cost_label.position = Vector2(size.x * 0.11, size.y * 0.07)
	_cost_label.size = Vector2(size.x * 0.28, size.y * 0.1)


func _apply_font(label: Label, base_size: int, amount: float) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", maxi(_MIN_FONT, int(round(float(base_size) * amount))))


func _fit_frame() -> void:
	if _frame == null or size.x < 2.0 or size.y < 2.0:
		return
	var drawn := size * _FRAME_BLEED
	var origin := (size - drawn) * 0.5
	_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.position = origin
	_frame.size = drawn
	_refresh_text_layout()


func apply_cost_style(cost: int) -> void:
	var style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_stylebox_override("focus", style)
	var cost_color := Color(0.95, 0.96, 0.98)
	if cost > 0:
		cost_color = CostColors.get_color(cost)
		if cost_color.get_luminance() < 0.45:
			cost_color = cost_color.lerp(Color.WHITE, 0.62)
	_cost_label.add_theme_color_override("font_color", cost_color)
