class_name CostColors
extends RefCounted

const COLORS: Dictionary = {
	1: Color(0.62, 0.64, 0.68),
	2: Color(0.55, 0.36, 0.18),
	3: Color(0.28, 0.78, 0.38),
	4: Color(0.28, 0.48, 0.95),
	5: Color(0.62, 0.32, 0.88),
	6: Color(0.95, 0.84, 0.18),
	7: Color(0.92, 0.24, 0.24),
}

static var _shop_style_cache: Dictionary = {}


static func get_color(cost: int) -> Color:
	return COLORS.get(clampi(cost, 1, 7), Color.WHITE)


static func get_shop_stylebox(cost: int) -> StyleBoxFlat:
	if _shop_style_cache.has(cost):
		return _shop_style_cache[cost]
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.14, 0.17, 0.21)
	box.border_color = get_color(cost)
	box.set_border_width_all(3)
	box.set_corner_radius_all(6)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	_shop_style_cache[cost] = box
	return box


static func get_empty_shop_stylebox() -> StyleBoxFlat:
	if _shop_style_cache.has(0):
		return _shop_style_cache[0]
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.14, 0.17)
	box.border_color = Color(0.32, 0.34, 0.38)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	_shop_style_cache[0] = box
	return box


static func make_border_material(cost: int) -> StandardMaterial3D:
	var color := get_color(cost)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	return material
