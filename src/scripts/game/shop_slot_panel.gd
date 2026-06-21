class_name ShopSlotPanel
extends Button

const PLACEHOLDER_TEXTURE := preload("res://images/placeholder.png")
const ILLUSTRATION_HEIGHT := 132.0

@onready var _illustration: TextureRect = $ContentRoot/Illustration
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
	_illustration.texture = PLACEHOLDER_TEXTURE
	_illustration.custom_minimum_size.y = ILLUSTRATION_HEIGHT
	set_sold_out()


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


func apply_cost_style(cost: int) -> void:
	var style := CostColors.get_empty_shop_stylebox() if cost <= 0 else CostColors.get_shop_stylebox(cost)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_stylebox_override("focus", style)
	var bottom_style := CostColors.get_shop_bottom_bar_stylebox(cost)
	_bottom_bar_panel.add_theme_stylebox_override("panel", bottom_style)
	var label_color := CostColors.get_shop_label_color(cost)
	_cost_label.add_theme_color_override("font_color", label_color)
	_name_label.add_theme_color_override("font_color", label_color)
