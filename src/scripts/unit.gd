class_name GameUnit
extends StaticBody3D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const MAX_STARS := 4
const TARGET_MODEL_HEIGHT := 0.78
const UNIT_RENDER_PRIORITY := 2

var unit_id: int = -1
var stars: int = 1
var is_enemy: bool = false
var board_hex: Vector2i = Vector2i(-1, -1)
var bench_index: int = -1

@onready var model_root: Node3D = $ModelRoot
@onready var label: Label3D = $Label3D

var _cost_border: MeshInstance3D
var _base_model_scale := 1.0
var _model_ground_y := 0.0


static func create(unit_id_value: int, star_count: int = 1) -> GameUnit:
	var unit: GameUnit = UNIT_SCENE.instantiate()
	unit.unit_id = unit_id_value
	unit.stars = clampi(star_count, 1, MAX_STARS)
	return unit


func _ready() -> void:
	_apply_render_priority_to_visuals(self, UNIT_RENDER_PRIORITY)
	_fit_model_to_board()
	if unit_id >= 0:
		refresh_visuals()


func refresh_visuals() -> void:
	var data := UnitCatalog.get_unit(unit_id)
	var synergy_text := UnitCatalog.get_synergy_names(unit_id)
	label.text = "%s\n%d\n%s" % ["★".repeat(stars), data["cost"], synergy_text]
	if is_enemy:
		label.modulate = Color(1.0, 0.78, 0.78)
	elif stars <= 2:
		label.modulate = Color.WHITE
	else:
		label.modulate = Color(1.0, 0.95, 0.7)
	_apply_model_star_scale()
	_apply_enemy_model_tint()
	_refresh_cost_border()


func _fit_model_to_board() -> void:
	var aabb := _compute_visual_aabb(model_root)
	if aabb.size.y <= 0.001:
		return
	_base_model_scale = TARGET_MODEL_HEIGHT / aabb.size.y
	_model_ground_y = -aabb.position.y * _base_model_scale
	_apply_model_star_scale()


func _apply_model_star_scale() -> void:
	var star_scale := 0.85 + float(stars - 1) * 0.08
	var scale := _base_model_scale * star_scale
	model_root.scale = Vector3.ONE * scale
	model_root.position.y = _model_ground_y * star_scale


func _apply_enemy_model_tint() -> void:
	_set_mesh_overlay(model_root, is_enemy)


func _set_mesh_overlay(node: Node, enemy: bool) -> void:
	if node is GeometryInstance3D:
		var instance := node as GeometryInstance3D
		if enemy:
			var overlay := StandardMaterial3D.new()
			overlay.albedo_color = Color(0.88, 0.22, 0.24, 0.42)
			overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			instance.material_overlay = overlay
		else:
			instance.material_overlay = null
	for child in node.get_children():
		_set_mesh_overlay(child, enemy)


func _compute_visual_aabb(root: Node3D) -> AABB:
	var merged := AABB()
	var found := false
	for child in root.get_children():
		if not child is Node3D:
			continue
		var child_aabb := _mesh_aabb_in_node_space(child as Node3D, Transform3D.IDENTITY)
		if child_aabb.size.length_squared() <= 0.0001:
			continue
		if found:
			merged = merged.merge(child_aabb)
		else:
			merged = child_aabb
			found = true
	return merged


func _mesh_aabb_in_node_space(node: Node3D, parent_xf: Transform3D) -> AABB:
	var xf := parent_xf * node.transform
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			return xf * mesh.get_aabb()

	var merged := AABB()
	var found := false
	for child in node.get_children():
		if not child is Node3D:
			continue
		var child_aabb := _mesh_aabb_in_node_space(child as Node3D, xf)
		if child_aabb.size.length_squared() <= 0.0001:
			continue
		if found:
			merged = merged.merge(child_aabb)
		else:
			merged = child_aabb
			found = true
	return merged


func _refresh_cost_border() -> void:
	if _cost_border == null:
		_cost_border = MeshInstance3D.new()
		_cost_border.name = "CostBorder"
		var mesh := TorusMesh.new()
		mesh.inner_radius = HexMath.HEX_SIZE * 0.80
		mesh.outer_radius = HexMath.HEX_SIZE * 0.98
		mesh.ring_segments = 6
		mesh.rings = 3
		_cost_border.mesh = mesh
		_cost_border.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		_cost_border.position.y = 0.01
		add_child(_cost_border)
	if unit_id < 0:
		_cost_border.visible = false
		return
	_cost_border.visible = true
	var material := CostColors.make_border_material(get_cost())
	material.render_priority = UNIT_RENDER_PRIORITY
	_cost_border.material_override = material


func get_cost() -> int:
	return UnitCatalog.get_unit(unit_id)["cost"]


func get_display_name() -> String:
	return UnitCatalog.get_unit(unit_id)["name"]


func get_star_text() -> String:
	return "★".repeat(stars)


func is_on_board() -> bool:
	return board_hex.x >= 0


func is_on_bench() -> bool:
	return bench_index >= 0


func clear_location() -> void:
	board_hex = Vector2i(-1, -1)
	bench_index = -1


func _apply_render_priority_to_visuals(node: Node, priority: int) -> void:
	if node is MeshInstance3D:
		_set_mesh_material_render_priority(node as MeshInstance3D, priority)
	elif node is Label3D:
		var label := node as Label3D
		label.outline_render_priority = priority - 1
	for child in node.get_children():
		_apply_render_priority_to_visuals(child, priority)


func _set_mesh_material_render_priority(mesh_instance: MeshInstance3D, priority: int) -> void:
	if mesh_instance.material_override != null:
		var override_mat := mesh_instance.material_override.duplicate()
		override_mat.render_priority = priority
		mesh_instance.material_override = override_mat
	if mesh_instance.mesh == null:
		return
	for surface_idx in mesh_instance.mesh.get_surface_count():
		var surface_mat := mesh_instance.get_surface_override_material(surface_idx)
		if surface_mat == null:
			surface_mat = mesh_instance.mesh.surface_get_material(surface_idx)
		if surface_mat == null:
			continue
		var mat := surface_mat.duplicate()
		mat.render_priority = priority
		mesh_instance.set_surface_override_material(surface_idx, mat)
