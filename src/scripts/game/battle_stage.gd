class_name BattleStage
extends RefCounted

const COLUMN_WIDTH := 640.0
const BACKGROUND_DIR := "res://images/backgrounds/battle"
const UI_BACKGROUND_PATH := "res://images/ui/background.png"
const EDGE_FEATHER := 48.0
const _EDGE_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size;
uniform float feather;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = min(local_position.x, rect_size.x - local_position.x);
	edge = min(edge, rect_size.y - local_position.y);
	tex.a *= smoothstep(0.0, max(feather, 0.001), edge);
	COLOR = tex;
}
"""

var viewport_container: SubViewportContainer
var background: TextureRect
var ui_background: TextureRect
var shadow_layer: FootShadowLayer
var world: SubViewport
var battle_rect := Rect2()
var view_height := 320.0

var _host: Node
var _camera: Camera3D
var _background_path := ""


func mount(host: Node, layer: CanvasLayer, camera: Camera3D, board: BoardController, units: Node3D, light: Node3D) -> void:
	_host = host
	_camera = camera
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.07, 0.09)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(backdrop)
	layer.move_child(backdrop, 0)
	ui_background = TextureRect.new()
	ui_background.name = "UiBackground"
	ui_background.texture = load(UI_BACKGROUND_PATH)
	ui_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ui_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ui_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_background)
	layer.move_child(ui_background, 1)
	background = TextureRect.new()
	background.name = "BattleBackground"
	background.texture = _pick_random_background_texture()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var edge_shader := Shader.new()
	edge_shader.code = _EDGE_SHADER
	var edge_material := ShaderMaterial.new()
	edge_material.shader = edge_shader
	background.material = edge_material
	layer.add_child(background)
	layer.move_child(background, 2)
	shadow_layer = FootShadowLayer.new()
	shadow_layer.setup(camera, units)
	layer.add_child(shadow_layer)
	layer.move_child(shadow_layer, 3)
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "BattleViewport"
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	viewport_container.offset_bottom = view_height
	layer.add_child(viewport_container)
	layer.move_child(viewport_container, 4)
	var viewport := SubViewport.new()
	viewport.name = "BattleWorld"
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(640, 480)
	world = viewport
	viewport_container.add_child(viewport)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.73, 0.78)
	environment.ambient_light_energy = 1.1
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 4.2, 0.4)
	fill_light.omni_range = 16.0
	fill_light.light_energy = 1.3
	viewport.add_child(fill_light)
	camera.reparent(viewport)
	light.reparent(viewport)
	board.reparent(viewport)
	units.reparent(viewport)


func setup_camera() -> void:
	_camera.current = true
	_camera.fov = 34.0
	_camera.near = 0.05
	_camera.global_position = Vector3(0.0, 1.1, 4.9)
	_camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)


func column_width(span_height: float) -> float:
	var texture := background.texture if background != null else null
	if texture == null or span_height <= 0.0:
		return COLUMN_WIDTH
	var tex_size := texture.get_size()
	if tex_size.y <= 0.0:
		return COLUMN_WIDTH
	return span_height * tex_size.x / tex_size.y


func place(viewport_size: Vector2) -> void:
	if ui_background != null:
		_place_control(ui_background, Rect2(Vector2.ZERO, viewport_size))
	_place_background()
	_place_control(viewport_container, battle_rect)
	if shadow_layer != null:
		_place_control(shadow_layer, battle_rect)
	if world != null:
		world.size = Vector2i(maxi(8, int(battle_rect.size.x)), maxi(8, int(battle_rect.size.y)))


func reroll() -> void:
	if background == null:
		return
	background.texture = _pick_random_background_texture()
	_host._layout_formation_ui()


func _place_background() -> void:
	if background == null or background.texture == null:
		return
	var tex_size := background.texture.get_size()
	if tex_size.y <= 0.0:
		return
	var span := battle_rect.end.y
	if span <= 0.0:
		return
	var drawn := Vector2(span * tex_size.x / tex_size.y, span)
	var origin := Vector2(battle_rect.position.x + (battle_rect.size.x - drawn.x) * 0.5, 0.0)
	background.stretch_mode = TextureRect.STRETCH_SCALE
	_place_control(background, Rect2(origin, drawn))
	var edge := background.material as ShaderMaterial
	if edge == null:
		return
	edge.set_shader_parameter("rect_size", drawn)
	edge.set_shader_parameter("feather", EDGE_FEATHER)


func _pick_random_background_texture() -> Texture2D:
	var paths := _list_background_paths()
	if paths.is_empty():
		return null
	var candidates: PackedStringArray = []
	for path in paths:
		if path != _background_path:
			candidates.append(path)
	if candidates.is_empty():
		candidates = paths
	_background_path = candidates[randi() % candidates.size()]
	return load(_background_path)


func _list_background_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(BACKGROUND_DIR):
		if file_name.get_extension().to_lower() != "png":
			continue
		paths.append(BACKGROUND_DIR.path_join(file_name))
	return paths


func _place_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
