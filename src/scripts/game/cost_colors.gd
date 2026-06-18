class_name CostColors
extends RefCounted

const COLORS: Dictionary = {
	1: Color(0.62, 0.64, 0.68),  # 灰
	2: Color(0.28, 0.75, 0.38),  # 緑
	3: Color(0.28, 0.48, 0.95),  # 青
	4: Color(0.58, 0.32, 0.88),  # 紫
	5: Color(0.98, 0.68, 0.18),  # オレンジ寄りの黄
	6: Color(0.92, 0.24, 0.24),  # 赤
	7: Color(0.08, 0.08, 0.10),  # 黒
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
	box.content_margin_left = 4
	box.content_margin_right = 4
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


static func get_shop_bottom_bar_stylebox(cost: int) -> StyleBoxFlat:
	var key := cost + 1000
	if _shop_style_cache.has(key):
		return _shop_style_cache[key]
	var box := StyleBoxFlat.new()
	if cost <= 0:
		box.bg_color = Color(0.12, 0.14, 0.17)
	else:
		box.bg_color = get_color(cost)
	box.set_corner_radius(Corner.CORNER_BOTTOM_LEFT, 3)
	box.set_corner_radius(Corner.CORNER_BOTTOM_RIGHT, 3)
	_shop_style_cache[key] = box
	return box


static func get_shop_label_color(cost: int) -> Color:
	if cost <= 0:
		return Color(0.82, 0.84, 0.88)
	var color := get_color(cost)
	if color.r * 0.299 + color.g * 0.587 + color.b * 0.114 > 0.62:
		return Color(0.08, 0.08, 0.1)
	return Color.WHITE


static func make_border_material(cost: int) -> StandardMaterial3D:
	var color := get_color(cost)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_receive_shadows = true
	return material
