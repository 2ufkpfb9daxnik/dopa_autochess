class_name GameUnit
extends StaticBody3D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const STATUS_AURA_SHADER := preload("res://shaders/status_aura.gdshader")
const MAX_STARS := 4
const RELIC_EQUIP_CAP := 5
const TARGET_MODEL_HEIGHT := 1.05
const UNIT_RENDER_PRIORITY := 2
const ACTION_VALUE_NUMERATOR := 10000
const HP_BAR_WIDTH := 0.46
const HP_BAR_HEIGHT := 0.05
const GAUGE_BAR_GAP := 0.02
const HP_LAG_SECONDS := 0.45
const CATALOG_CLIPS := {
	1: {
		"idle": "look_around_001",
		"cast_a_spell": "agree_001",
		"fold_arms": "afraid_001",
		"hit_to_head": "hit_to_side_001",
		"defeat": "fall_001",
	},
	2: {
		"idle": "agree_001",
		"cast_a_spell": "この背中に背負っている銃で敵を射撃します。",
		"fold_arms": "make_a_call_01_001",
		"hit_to_head": "hit_to_side_001",
		"defeat": "fall_001",
	},
	4: {
		"idle": "turn_001",
		"cast_a_spell": "box_01_001",
		"fold_arms": "後ろの鐘に隠れます。_001",
		"hit_to_head": "hit_to_head_001",
		"defeat": "",
	},
	6: {
		"idle": "warm_up",
		"cast_a_spell": "crossover_dribble",
		"fold_arms": "dance_01",
		"hit_to_head": "hit_to_head",
		"defeat": "dive",
	},
}

var unit_id: int = -1
var stars: int = 1
var is_enemy: bool = false
var circle_face: int = -1
var circle_slot: int = -1
var bench_index: int = -1
var action_value: int = 1
var battle_ko := false
var debuffed := false
var debuff_home_face := -1
var debuff_home_slot := -1
var equipped_relic_uids: Array[int] = []

@onready var model_root: Node3D = $ModelRoot
@onready var label: Label3D = $Label3D

var _base_model_scale := 1.0
var _model_ground_y := 0.0
var _animation_player: AnimationPlayer
var _armature_root: Node3D
var _armature_rest := Transform3D.IDENTITY
var _battle_walking := false
var _clip_lock := false
var defeat_playing := false
var _guard_shake_time := 0.0
var _guard_shake_left := 0.0
var _hp_root: Node3D
var _hp_lag_mesh: MeshInstance3D
var _hp_fill_mesh: MeshInstance3D
var _gauge_track: MeshInstance3D
var _gauge_fill: MeshInstance3D
var _hp_current := 0
var _hp_max := 1
var _hp_lag := -1.0
var _buff_aura: Node3D
var _debuff_aura: Node3D
var _aura_time := 0.0
var _aura_flash: Node3D
var _has_buff_aura := false
var _has_debuff_aura := false


static func create(unit_id_value: int, star_count: int = 1) -> GameUnit:
	var unit: GameUnit = UNIT_SCENE.instantiate()
	unit.unit_id = unit_id_value
	unit.stars = clampi(star_count, 1, MAX_STARS)
	return unit


func _ready() -> void:
	visible = false
	_mount_catalog_model()
	_apply_render_priority_to_visuals(self, UNIT_RENDER_PRIORITY)
	_setup_model_animation()
	_fit_model_to_board()
	if unit_id >= 0:
		refresh_visuals()
	_apply_battle_walking_state()


func _mount_catalog_model() -> void:
	var scene := UnitCatalog.get_model_scene(unit_id)
	if scene == null or model_root == null:
		return
	for child in model_root.get_children():
		model_root.remove_child(child)
		child.free()
	model_root.add_child(scene.instantiate())


func hold_guard_pose() -> void:
	play_battle_role("guard")
	if _animation_player != null:
		_animation_player.pause()


func play_defeat_loop() -> void:
	visible = true
	label.visible = false
	if _hp_root != null:
		_hp_root.visible = false
	var length := play_battle_role("defeat")
	if _animation_player == null or length <= 0.0:
		return
	var anim_name := _animation_player.current_animation
	var anim := _animation_player.get_animation(anim_name)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR
	_animation_player.play(anim_name)


func play_guard_hit_shake() -> void:
	_guard_shake_time = 0.0
	_guard_shake_left = 0.32


func stop_guard_hit_shake() -> void:
	_guard_shake_left = 0.0
	if is_instance_valid(model_root):
		model_root.position.x = 0.0
		model_root.position.z = 0.0


func _process(delta: float) -> void:
	_process_guard_shake(delta)
	_process_hp_lag(delta)
	_process_status_aura(delta)


func set_status_auras(has_buff: bool, has_debuff: bool) -> void:
	_has_buff_aura = has_buff
	_has_debuff_aura = has_debuff
	if has_buff:
		_buff_aura = _ensure_aura(_buff_aura, true)
		_buff_aura.visible = true
	elif _buff_aura != null:
		_buff_aura.visible = false
	if has_debuff:
		_debuff_aura = _ensure_aura(_debuff_aura, false)
		_debuff_aura.visible = true
	elif _debuff_aura != null:
		_debuff_aura.visible = false


func clear_status_auras() -> void:
	set_status_auras(false, false)
	clear_aura_flash()


func flash_status_aura(is_buff: bool) -> void:
	clear_aura_flash()
	_aura_flash = _make_aura_root(is_buff, true)
	_aura_flash.name = "AuraFlash"
	add_child(_aura_flash)


func clear_aura_flash() -> void:
	if _aura_flash != null and is_instance_valid(_aura_flash):
		_aura_flash.queue_free()
	_aura_flash = null


func _process_status_aura(delta: float) -> void:
	if not _has_buff_aura and not _has_debuff_aura and _aura_flash == null:
		return
	_aura_time += delta
	if _buff_aura != null and _buff_aura.visible:
		_animate_aura_root(_buff_aura, delta, 1.15, 1.0)
	if _debuff_aura != null and _debuff_aura.visible:
		_animate_aura_root(_debuff_aura, delta, -1.45, 1.15)
	if _aura_flash != null and is_instance_valid(_aura_flash):
		_animate_aura_root(_aura_flash, delta, 2.1, 1.35)


func _animate_aura_root(root: Node3D, delta: float, spin: float, breath_speed: float) -> void:
	root.rotation.y = wrapf(root.rotation.y + delta * spin, 0.0, TAU)
	var breath := 1.0 + 0.045 * sin(_aura_time * (3.4 + breath_speed) + float(root.get_instance_id() % 7))
	root.scale = Vector3(breath, 1.0 + 0.03 * sin(_aura_time * 2.7 + 0.8), breath)
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			mesh_instance.rotation.y = wrapf(mesh_instance.rotation.y + delta * spin * 0.35, 0.0, TAU)
			mesh_instance.rotation.x = 0.08 * sin(_aura_time * 1.7 + mesh_instance.position.y)


func _ensure_aura(current: Node3D, is_buff: bool) -> Node3D:
	if current != null and is_instance_valid(current):
		return current
	var aura := _make_aura_root(is_buff, false)
	aura.name = "BuffAura" if is_buff else "DebuffAura"
	add_child(aura)
	return aura


func _make_aura_root(is_buff: bool, flash: bool) -> Node3D:
	var root := Node3D.new()
	var primary := Color(0.38, 0.98, 0.78, 0.72) if is_buff else Color(0.78, 0.32, 1.0, 0.78)
	var secondary := Color(1.0, 0.88, 0.42, 0.58) if is_buff else Color(0.48, 0.95, 0.28, 0.62)
	var density := 1.25 if flash else 1.0
	root.add_child(_make_aura_shell(Vector3(0.0, 0.52, 0.0), Vector3(0.7, 1.05, 0.7), primary, 0.62, 2.4, density))
	root.add_child(_make_aura_shell(Vector3(0.0, 0.48, 0.0), Vector3(0.86, 0.78, 0.86), secondary, 0.9, 3.3, density * 0.85))
	root.add_child(_make_aura_shell(Vector3(0.0, 0.28, 0.0), Vector3(0.98, 0.42, 0.98), primary, 1.15, 1.8, density * 0.7))
	return root


func _make_aura_shell(offset: Vector3, mesh_scale: Vector3, color: Color, flow_speed: float, patch_scale: float, density: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	mesh_instance.mesh = sphere
	mesh_instance.position = offset
	mesh_instance.scale = mesh_scale
	mesh_instance.material_override = _make_aura_material(color, flow_speed, patch_scale, density)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _make_aura_material(color: Color, flow_speed: float, patch_scale: float, density: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STATUS_AURA_SHADER
	mat.set_shader_parameter("aura_color", color)
	mat.set_shader_parameter("flow_speed", flow_speed)
	mat.set_shader_parameter("patch_scale", patch_scale)
	mat.set_shader_parameter("threshold_low", 0.3)
	mat.set_shader_parameter("threshold_high", 0.7)
	mat.set_shader_parameter("rim_boost", 0.75)
	mat.set_shader_parameter("density", density)
	mat.render_priority = UNIT_RENDER_PRIORITY + 1
	return mat


static func make_transfer_orb(is_buff: bool) -> Node3D:
	var root := Node3D.new()
	var primary := Color(0.5, 1.0, 0.82, 0.85) if is_buff else Color(0.82, 0.38, 1.0, 0.88)
	var secondary := Color(1.0, 0.92, 0.5, 0.7) if is_buff else Color(0.55, 0.98, 0.32, 0.72)
	root.add_child(_make_transfer_shell(0.22, primary, 1.4, 3.2, 1.35))
	root.add_child(_make_transfer_shell(0.34, secondary, 1.8, 2.2, 0.95))
	return root


static func _make_transfer_shell(radius: float, color: Color, flow_speed: float, patch_scale: float, density: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 18
	sphere.rings = 10
	mesh_instance.mesh = sphere
	var mat := ShaderMaterial.new()
	mat.shader = STATUS_AURA_SHADER
	mat.set_shader_parameter("aura_color", color)
	mat.set_shader_parameter("flow_speed", flow_speed)
	mat.set_shader_parameter("patch_scale", patch_scale)
	mat.set_shader_parameter("threshold_low", 0.28)
	mat.set_shader_parameter("threshold_high", 0.66)
	mat.set_shader_parameter("rim_boost", 0.55)
	mat.set_shader_parameter("density", density)
	mat.render_priority = UNIT_RENDER_PRIORITY + 2
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _process_guard_shake(delta: float) -> void:
	if _guard_shake_left <= 0.0 or model_root == null:
		return
	_guard_shake_left -= delta
	_guard_shake_time += delta
	if _guard_shake_left <= 0.0:
		model_root.position.x = 0.0
		model_root.position.z = 0.0
		return
	model_root.position.x = sin(_guard_shake_time * 46.0) * 0.02
	model_root.position.z = sin(_guard_shake_time * 37.0 + 1.1) * 0.014


func _process_hp_lag(delta: float) -> void:
	if _hp_root == null or not _hp_root.visible:
		return
	_hp_root.rotation.y = -rotation.y
	if _hp_lag <= float(_hp_current):
		return
	var step := float(_hp_max) * delta / HP_LAG_SECONDS
	_hp_lag = maxf(float(_hp_current), _hp_lag - step)
	_place_hp_meshes()


func set_battle_walking(active: bool) -> void:
	if _clip_lock:
		return
	if _battle_walking == active:
		return
	_battle_walking = active
	if is_node_ready():
		_apply_battle_walking_state()


func play_battle_role(role: String) -> float:
	_clip_lock = role != "idle"
	defeat_playing = role == "defeat"
	if _animation_player == null:
		return 0.0
	var fragment := "idle"
	match role:
		"attack", "buff":
			fragment = "cast_a_spell"
		"guard":
			fragment = "fold_arms"
		"hit":
			fragment = "hit_to_head"
		"defeat":
			fragment = "defeat"
	var anim_name := _find_clip(fragment)
	if anim_name.is_empty():
		return 0.0
	var anim := _animation_player.get_animation(anim_name)
	if anim == null:
		return 0.0
	if role == "idle":
		anim.loop_mode = Animation.LOOP_LINEAR
		_animation_player.speed_scale = 1.0
		_animation_player.play(anim_name)
		return 0.0
	anim.loop_mode = Animation.LOOP_NONE
	var speed := 1.35
	var from := anim.length * 0.08
	if _named_battle_clips():
		speed = 1.0
		from = 0.0
	else:
		match role:
			"guard":
				speed = 1.0
				from = anim.length * 0.55
			"hit", "defeat":
				speed = 1.0
				from = 0.0
	_animation_player.speed_scale = speed
	_animation_player.play(anim_name)
	_animation_player.seek(from, true)
	return maxf(0.05, (anim.length - from) / speed)


func release_battle_clip() -> void:
	_clip_lock = false
	defeat_playing = false
	if _animation_player != null:
		_animation_player.speed_scale = 1.0
		_animation_player.stop()
	_lock_model_position()


func set_battle_hp(current: int, maximum: int) -> void:
	label.visible = false
	label.text = ""
	_ensure_hp_bar()
	_hp_current = maxi(current, 0)
	_hp_max = maxi(maximum, 1)
	if _hp_lag < 0.0 or _hp_lag < float(_hp_current):
		_hp_lag = float(_hp_current)
	_hp_root.visible = true
	_place_hp_bar()
	_place_hp_meshes()


func set_battle_gauge(current: int, maximum: int) -> void:
	_ensure_hp_bar()
	var show := maximum > 0
	if _gauge_track != null:
		_gauge_track.visible = show
	if _gauge_fill == null:
		return
	_gauge_fill.visible = show
	if not show:
		return
	var ratio := clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	_gauge_fill.position.y = -(HP_BAR_HEIGHT + GAUGE_BAR_GAP)
	_place_hp_fill(_gauge_fill, ratio)


func popup_battle_text(text: String, color: Color) -> void:
	var popup := Label3D.new()
	popup.text = text
	popup.font_size = 42
	popup.outline_size = 8
	popup.modulate = Color(color.r, color.g, color.b, 0.0)
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.scale = Vector3(2.4, 2.4, 2.4)
	var start := Vector3(randf_range(-0.36, 0.36), 1.12 + randf_range(0.0, 0.32), randf_range(-0.06, 0.06))
	var dipped := start + Vector3(0.0, -0.1, 0.0)
	var risen := dipped + Vector3(randf_range(-0.1, 0.1), randf_range(0.42, 0.68), 0.0)
	popup.position = start
	popup.render_priority = 8
	popup.outline_render_priority = 7
	popup.no_depth_test = true
	add_child(popup)
	var tween := create_tween()
	tween.tween_property(popup, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate:a", color.a, 0.2)
	tween.parallel().tween_property(popup, "position", dipped, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "position", risen, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.7)
	tween.finished.connect(popup.queue_free)


func _setup_model_animation() -> void:
	_animation_player = _find_animation_player(model_root)
	_armature_root = _find_armature_root(model_root)
	if _armature_root != null:
		_armature_rest = _armature_root.transform
	if _animation_player != null:
		_animation_player.stop()


func _apply_battle_walking_state() -> void:
	if _battle_walking:
		play_battle_role("idle")
		_clip_lock = false
		return
	if _animation_player == null:
		return
	_animation_player.speed_scale = 1.0
	_animation_player.stop()
	if _animation_player.has_animation("RESET"):
		_animation_player.play("RESET")
	_lock_model_position()


func _find_clip(fragment: String) -> String:
	if _animation_player == null:
		return ""
	if _named_battle_clips():
		return _catalog_clip(fragment)
	var fallback := ""
	for anim_name in _animation_player.get_animation_list():
		if anim_name == "RESET":
			continue
		var lower := anim_name.to_lower()
		if fragment in lower:
			return anim_name
		if fallback.is_empty():
			fallback = anim_name
	return fallback


func _named_battle_clips() -> bool:
	return CATALOG_CLIPS.has(unit_id)


func _catalog_clip(fragment: String) -> String:
	var table: Dictionary = CATALOG_CLIPS.get(unit_id, {})
	var wanted := str(table.get(fragment, "")).replace(".", "_")
	if wanted.is_empty():
		return ""
	if _animation_player.has_animation(wanted):
		return wanted
	for anim_name in _animation_player.get_animation_list():
		if String(anim_name).begins_with(wanted) or wanted.begins_with(String(anim_name)):
			return anim_name
	return ""


func _lock_model_position() -> void:
	if _armature_root != null:
		_armature_root.transform = _armature_rest


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_armature_root(root: Node) -> Node3D:
	var skeleton := _find_skeleton3d(root)
	if skeleton != null and skeleton.get_parent() is Node3D:
		return skeleton.get_parent() as Node3D
	for child in root.get_children():
		if child is Node3D and "Armature" in child.name:
			return child as Node3D
	return null


func _find_skeleton3d(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton3d(child)
		if found != null:
			return found
	return null


func refresh_visuals() -> void:
	label.visible = false
	label.text = ""
	_hide_hp_bar()
	_apply_model_star_scale()
	_apply_enemy_model_tint()
	_refresh_action_value()


func _ensure_hp_bar() -> void:
	if _hp_root != null:
		return
	_hp_root = Node3D.new()
	_hp_root.name = "HpBar"
	_hp_root.visible = false
	add_child(_hp_root)
	_hp_root.add_child(_make_hp_quad(Color(0.45, 0.46, 0.48), 3))
	_hp_lag_mesh = _make_hp_quad(Color(0.9, 0.18, 0.14), 4)
	_hp_fill_mesh = _make_hp_quad(Color(0.24, 0.78, 0.3), 5)
	_hp_root.add_child(_hp_lag_mesh)
	_hp_root.add_child(_hp_fill_mesh)
	_gauge_track = _make_hp_quad(Color(0.32, 0.4, 0.48), 3)
	_gauge_fill = _make_hp_quad(Color(0.25, 0.78, 0.98), 6)
	_gauge_track.position.y = -(HP_BAR_HEIGHT + GAUGE_BAR_GAP)
	_gauge_fill.position.y = _gauge_track.position.y
	_gauge_track.visible = false
	_gauge_fill.visible = false
	_hp_root.add_child(_gauge_track)
	_hp_root.add_child(_gauge_fill)


func _make_hp_quad(color: Color, priority: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	mesh_instance.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.sorting_offset = float(priority)
	return mesh_instance


func _hide_hp_bar() -> void:
	_hp_lag = -1.0
	if _hp_root != null:
		_hp_root.visible = false


func _place_hp_bar() -> void:
	if _hp_root == null:
		return
	var star_scale := 0.85 + float(stars - 1) * 0.08
	_hp_root.position = Vector3(0.0, TARGET_MODEL_HEIGHT * star_scale + 0.18, 0.0)
	_hp_root.rotation.y = -rotation.y


func _place_hp_meshes() -> void:
	if _hp_lag_mesh == null or _hp_fill_mesh == null:
		return
	_place_hp_fill(_hp_lag_mesh, _hp_lag / float(_hp_max))
	_place_hp_fill(_hp_fill_mesh, float(_hp_current) / float(_hp_max))


func _place_hp_fill(mesh: MeshInstance3D, ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	mesh.visible = clamped > 0.001
	mesh.scale = Vector3(maxf(clamped, 0.001), 1.0, 1.0)
	mesh.position.x = HP_BAR_WIDTH * (clamped - 1.0) * 0.5


func _fit_model_to_board() -> void:
	var aabb := _bounds_before_scale(model_root)
	var model_height := maxf(aabb.size.y, 0.001)
	_base_model_scale = TARGET_MODEL_HEIGHT / model_height
	_model_ground_y = -aabb.position.y * _base_model_scale
	_apply_model_star_scale()


func _bounds_before_scale(root: Node3D) -> AABB:
	var mesh_aabb := _compute_visual_aabb(root)
	var skeleton := _find_skeleton3d(root)
	if skeleton == null or skeleton.get_bone_count() == 0:
		return mesh_aabb
	var min_y := INF
	var max_y := -INF
	var to_root := root.global_transform.affine_inverse() * skeleton.global_transform
	for bone_index in skeleton.get_bone_count():
		var point: Vector3 = to_root * skeleton.get_bone_global_pose(bone_index).origin
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	var bone_height := max_y - min_y
	if bone_height <= mesh_aabb.size.y or bone_height < 0.05:
		return mesh_aabb
	return AABB(Vector3(mesh_aabb.position.x, min_y, mesh_aabb.position.z), Vector3(mesh_aabb.size.x, bone_height, mesh_aabb.size.z))


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


func get_cost() -> int:
	return UnitCatalog.get_unit(unit_id)["cost"]


func get_display_name() -> String:
	return UnitCatalog.get_unit(unit_id)["name"]


func get_star_text() -> String:
	return "★".repeat(stars)


func is_on_board() -> bool:
	return circle_face >= 0 and circle_slot >= 0


func is_on_bench() -> bool:
	return bench_index >= 0


func clear_location() -> void:
	circle_face = -1
	circle_slot = -1
	bench_index = -1


func _refresh_action_value() -> void:
	if unit_id < 0:
		return
	var speed := maxi(40, 150 - get_cost() * 8 + (stars - 1) * 10)
	action_value = maxi(1, int(round(float(ACTION_VALUE_NUMERATOR) / float(speed))))


func _apply_render_priority_to_visuals(node: Node, priority: int) -> void:
	if node is MeshInstance3D:
		_set_mesh_material_render_priority(node as MeshInstance3D, priority)
	elif node is Label3D:
		var label := node as Label3D
		label.render_priority = priority
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
