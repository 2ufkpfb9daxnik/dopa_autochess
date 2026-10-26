class_name ShopSlotPanel
extends Button

const PLACEHOLDER_TEXTURE := preload("res://images/placeholder.png")
const _FRAME_BLEED := 1.22

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


func _ready() -> void:
	text = ""
	flat = true
	clip_contents = false
	resized.connect(_fit_frame)
	_illustration.texture = PLACEHOLDER_TEXTURE
	set_sold_out()
	_fit_frame()


func set_sold_out() -> void:
	_content_root.visible = true
	_bottom_bar_panel.visible = true
	_empty_label.visible = false
	_illustration.texture = PLACEHOLDER_TEXTURE
	_illustration.modulate = Color(1.0, 1.0, 1.0, 0.22)
	_synergy_label.text = ""
	_stars_label.text = ""
	_cost_label.text = ""
	_name_label.text = "売り切れ"
	apply_cost_style(0)


func set_unit(unit_id: int) -> void:
	var data := UnitCatalog.get_unit(unit_id)
	_content_root.visible = true
	_bottom_bar_panel.visible = true
	_empty_label.visible = false
	_illustration.texture = PLACEHOLDER_TEXTURE
	_illustration.modulate = Color.WHITE
	_cost_label.text = str(data["cost"])
	_name_label.text = data["name"]
	_stars_label.text = "★"
	_synergy_label.text = UnitCatalog.get_synergy_lines(unit_id)
	apply_cost_style(int(data["cost"]))


func set_card_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	_fit_frame()


func set_text_scale(amount: float) -> void:
	_apply_font(_synergy_label, 13, amount)
	_apply_font(_stars_label, 16, amount)
	_apply_font(_cost_label, 20, amount)
	_apply_font(_name_label, 14, amount)
	_apply_font(_empty_label, 15, amount)
	var band := -40.0 * amount
	if _synergy_backdrop != null:
		_synergy_backdrop.offset_top = band
	_synergy_label.offset_top = band


func _apply_font(label: Label, base_size: int, amount: float) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", maxi(8, int(round(float(base_size) * amount))))


func _fit_frame() -> void:
	if _frame == null or size.x < 2.0 or size.y < 2.0:
		return
	var drawn := size * _FRAME_BLEED
	var origin := (size - drawn) * 0.5
	_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.position = origin
	_frame.size = drawn


func apply_cost_style(cost: int) -> void:
	var style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_stylebox_override("focus", style)
	_bottom_bar_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var name_color := Color(0.95, 0.96, 0.98)
	var cost_color := name_color
	if cost > 0:
		cost_color = CostColors.get_color(cost)
		if cost_color.get_luminance() < 0.45:
			cost_color = cost_color.lerp(Color.WHITE, 0.62)
	_cost_label.add_theme_color_override("font_color", cost_color)
	_name_label.add_theme_color_override("font_color", name_color)
