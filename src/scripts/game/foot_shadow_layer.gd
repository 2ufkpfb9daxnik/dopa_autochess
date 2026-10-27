class_name FootShadowLayer
extends Control

const SHADOW_RADIUS := 0.55
const SHADOW_CORE := 0.5

var _camera: Camera3D
var _units_root: Node3D
var _texture: Texture2D


func setup(view_camera: Camera3D, units_root: Node3D) -> void:
	_camera = view_camera
	_units_root = units_root
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = canvas_material
	_texture = _make_soft_texture()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
	if _camera == null or _units_root == null or _texture == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var viewport := _camera.get_viewport()
	if viewport == null:
		return
	var viewport_size := Vector2(viewport.size)
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	for child in _units_root.get_children():
		if not child is GameUnit or not child.visible:
			continue
		_draw_unit_shadow(child as GameUnit, viewport_size)


func _draw_unit_shadow(unit: GameUnit, viewport_size: Vector2) -> void:
	var feet := unit.global_position
	feet.y = 0.0
	if _camera.is_position_behind(feet):
		return
	var center := _to_local_point(_camera.unproject_position(feet), viewport_size)
	var ground_right := _to_local_point(
		_camera.unproject_position(feet + Vector3(SHADOW_RADIUS, 0.0, 0.0)),
		viewport_size
	) - center
	var ground_forward := _to_local_point(
		_camera.unproject_position(feet + Vector3(0.0, 0.0, SHADOW_RADIUS)),
		viewport_size
	) - center
	if ground_right.length() < 1.0 or ground_forward.length() < 1.0:
		return
	var star_scale := 0.85 + float(unit.stars - 1) * 0.08
	draw_set_transform(
		center,
		ground_right.angle(),
		Vector2(ground_right.length(), ground_forward.length()) * star_scale
	)
	draw_texture_rect(_texture, Rect2(-Vector2.ONE, Vector2(2.0, 2.0)), false, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _to_local_point(viewport_point: Vector2, viewport_size: Vector2) -> Vector2:
	return Vector2(viewport_point.x / viewport_size.x, viewport_point.y / viewport_size.y) * size


func _make_soft_texture() -> Texture2D:
	var texture_size := 160
	var image := Image.create(texture_size, texture_size, false, Image.FORMAT_RGBA8)
	var half := float(texture_size) * 0.5
	for y in texture_size:
		for x in texture_size:
			var px := (float(x) + 0.5 - half) / half
			var py := (float(y) + 0.5 - half) / half
			var outside := Vector2(maxf(absf(px) - 0.04, 0.0), maxf(absf(py) - 0.04, 0.0))
			var dist := clampf(outside.length() / 0.9, 0.0, 1.0)
			var fade := dist * dist * (3.0 - 2.0 * dist)
			var shade := lerpf(SHADOW_CORE, 1.0, fade)
			image.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(image)
