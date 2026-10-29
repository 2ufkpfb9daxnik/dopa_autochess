class_name BattleResult
extends Control

const DANCE_DIR := "res://images/frames/dance"
const LOSE_DIR := "res://images/frames/lose"
const FRAME_FPS := 24.0
const FRAME_ASPECT := 1344.0 / 768.0
const DANCE_COUNT := 5

var _dances: Array[TextureRect] = []
var _dance_places: Array[Dictionary] = []
var _defeat_view: SubViewportContainer
var _defeat_viewport: SubViewport
var _title: Label
var _clear_mark: Label
var _hp_caption: Label
var _hp_value: Label
var _body: Label
var _routes: VBoxContainer
var _fill := Color(0.82, 0.1, 0.14, 1.0)
var _frame_paths: PackedStringArray = []
var _frame_index := 0
var _frame_time := 0.0
var _playing := false
var _striped := false
var _path_cache: Dictionary = {}
var modal_changed: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _index in DANCE_COUNT:
		var dance := TextureRect.new()
		dance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dance.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dance.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		dance.z_index = 1
		dance.visible = false
		add_child(dance)
		_dances.append(dance)
	_defeat_view = SubViewportContainer.new()
	_defeat_view.name = "DefeatActor"
	_defeat_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_view.stretch = true
	_defeat_view.visible = false
	_defeat_view.z_index = 1
	add_child(_defeat_view)
	_defeat_viewport = SubViewport.new()
	_defeat_viewport.name = "DefeatWorld"
	_defeat_viewport.own_world_3d = true
	_defeat_viewport.transparent_bg = true
	_defeat_viewport.handle_input_locally = false
	_defeat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_defeat_viewport.size = Vector2i(960, 1280)
	_defeat_view.add_child(_defeat_viewport)
	_mount_defeat_stage()
	_title = _make_label(144, HORIZONTAL_ALIGNMENT_RIGHT)
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.add_theme_constant_override("outline_size", 14)
	_clear_mark = _make_label(480, HORIZONTAL_ALIGNMENT_CENTER)
	_clear_mark.text = "クリア！"
	_clear_mark.visible = false
	_clear_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clear_mark.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_clear_mark.clip_text = false
	_clear_mark.z_index = 2
	_clear_mark.add_theme_constant_override("outline_size", 36)
	_clear_mark.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_body = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_title.z_index = 2
	_body.z_index = 2
	_hp_caption = _make_label(84, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hp_caption.add_theme_constant_override("outline_size", 12)
	_hp_caption.z_index = 2
	_hp_caption.visible = false
	_hp_caption.clip_contents = true
	_hp_value = _make_label(200, HORIZONTAL_ALIGNMENT_RIGHT)
	_hp_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hp_value.add_theme_constant_override("outline_size", 16)
	_hp_value.z_index = 2
	_hp_value.visible = false
	_hp_value.clip_contents = true
	resized.connect(_on_resized)
	if not get_viewport().size_changed.is_connected(_fit_viewport):
		get_viewport().size_changed.connect(_fit_viewport)


func _has_point(point: Vector2) -> bool:
	if size.x < 2.0 or size.y < 2.0:
		return false
	if point.y <= point.x * size.y / size.x:
		return true
	return _routes != null and _routes.get_rect().has_point(point)


func open(won: bool, body: String, hp_before: int = -1, hp_after: int = -1) -> void:
	_fill = Color(0.82, 0.1, 0.14, 1.0) if won else Color(0.12, 0.28, 0.78, 1.0)
	_title.text = "勝利！" if won else "敗北"
	_striped = false
	_clear_mark.visible = false
	_body.text = body
	var show_hp := not won and hp_before >= 0 and hp_after != hp_before
	_hp_caption.visible = show_hp
	_hp_value.visible = show_hp
	if show_hp:
		_hp_caption.text = "プレイヤーHP減少"
		_hp_value.text = "%d → %d  (%d)" % [hp_before, hp_after, hp_after - hp_before]
	_frame_paths = _paths_for(DANCE_DIR if won else LOSE_DIR)
	_frame_index = 0
	_frame_time = 0.0
	_playing = won and not _frame_paths.is_empty()
	_dance_places.clear()
	for dance in _dances:
		dance.visible = _playing
	_defeat_view.visible = not won
	if _playing:
		_show_frame(0)
	if won:
		_defeat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_routes()
	z_as_relative = false
	z_index = 100
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	visible = true
	move_to_front()
	_layout_content()
	queue_redraw()
	if not won:
		_play_defeat_actor()
	if modal_changed.is_valid():
		modal_changed.call(true)


func show_clear_banner() -> void:
	if _clear_mark == null:
		return
	_clear_mark.visible = true
	_striped = true
	_layout_content()
	queue_redraw()


func close() -> void:
	_playing = false
	_clear_routes()
	_defeat_view.visible = false
	_defeat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _clear_mark != null:
		_clear_mark.visible = false
	visible = false
	if modal_changed.is_valid():
		modal_changed.call(false)


func show_routes(lines: PackedStringArray, pick: Callable) -> void:
	_clear_routes()
	_routes = VBoxContainer.new()
	_routes.mouse_filter = Control.MOUSE_FILTER_STOP
	_routes.z_index = 3
	_routes.add_theme_constant_override("separation", 8)
	add_child(_routes)
	for index in lines.size():
		var button := Button.new()
		button.text = lines[index]
		button.custom_minimum_size = Vector2(240, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picked := index
		button.pressed.connect(func() -> void: pick.call(picked))
		_routes.add_child(button)
	_layout_content()


func _process(delta: float) -> void:
	if not _playing or _frame_paths.is_empty():
		return
	_frame_time += delta
	var step := 1.0 / FRAME_FPS
	var advanced := false
	var steps := 0
	while _frame_time >= step and steps < 4:
		_frame_time -= step
		_frame_index = (_frame_index + 1) % _frame_paths.size()
		advanced = true
		steps += 1
	if _frame_time >= step:
		_frame_time = 0.0
	if advanced:
		_show_frame(_frame_index)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var triangle := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
	])
	if not _striped:
		draw_colored_polygon(triangle, _fill)
		return
	var normal := Vector2(-size.y, size.x).normalized()
	var span := -Vector2(size.x, 0.0).dot(normal)
	var thickness := 22.0
	var period := 36.0
	var offset := -span
	while offset < -0.5:
		var near := minf(offset + thickness, 0.0)
		var poly := _clip_strip(triangle, normal, offset, near)
		if poly.size() >= 3:
			draw_colored_polygon(poly, _fill)
		offset += period


func _on_resized() -> void:
	_layout_content()
	queue_redraw()


func _fit_viewport() -> void:
	if not is_inside_tree() or not top_level:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if position != Vector2.ZERO or size != viewport_size:
		position = Vector2.ZERO
		size = viewport_size


func _show_frame(index: int) -> void:
	if index < 0 or index >= _frame_paths.size():
		return
	var texture := ResourceLoader.load(_frame_paths[index], "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
	if texture == null:
		return
	for dance in _dances:
		dance.texture = texture


func _layout_content() -> void:
	if _title == null or size.x < 2.0:
		return
	var text_w := clampf(size.x * 0.46, 420.0, 860.0)
	var column_x := size.x - text_w - 28.0
	_title.position = Vector2(column_x, 4.0)
	_title.size = Vector2(text_w, 168.0)
	_body.position = Vector2(column_x, 176.0)
	_body.size = Vector2(text_w, 150.0)
	if _routes != null:
		_routes.position = Vector2(column_x, 332.0)
		_routes.size = Vector2(text_w, 280.0)
	if _hp_value != null and _hp_value.visible:
		var gap := 24.0
		var hp_right := column_x - gap
		var hp_top := 8.0
		var block_bottom := hp_top + 320.0
		var min_x := block_bottom * size.x / maxf(1.0, size.y) + 12.0
		var hp_w := maxf(180.0, hp_right - min_x)
		_hp_caption.position = Vector2(hp_right - hp_w, hp_top)
		_hp_caption.size = Vector2(hp_w, 96.0)
		_fit_label_font(_hp_caption, 84, 36)
		_hp_value.position = Vector2(hp_right - hp_w, _hp_caption.position.y + _hp_caption.size.y + 6.0)
		_hp_value.size = Vector2(hp_w, 220.0)
		_fit_label_font(_hp_value, 200, 64)
	if _clear_mark != null:
		var mark_size := int(maxf(220.0, size.y * 0.52))
		_clear_mark.add_theme_font_size_override("font_size", mark_size)
		_clear_mark.position = Vector2(size.x * 0.02, size.y * 0.34)
		_clear_mark.size = Vector2(size.x * 0.96, size.y * 0.64)
	var base := _base_dance_size()
	_defeat_view.size = base
	_defeat_view.position = Vector2(size.x - base.x - 4.0, size.y * 0.16)
	if _playing and _dance_places.is_empty():
		_scatter_dances(base)
	else:
		_apply_dance_places(base)


func _clip_strip(subject: PackedVector2Array, normal: Vector2, far_limit: float, near_limit: float) -> PackedVector2Array:
	var above := _clip_halfplane(subject, normal, far_limit, false)
	return _clip_halfplane(above, normal, near_limit, true)


func _clip_halfplane(subject: PackedVector2Array, normal: Vector2, limit: float, keep_below: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if subject.size() < 3:
		return output
	var previous: Vector2 = subject[subject.size() - 1]
	var previous_inside := _inside_halfplane(previous, normal, limit, keep_below)
	for current in subject:
		var current_inside := _inside_halfplane(current, normal, limit, keep_below)
		if current_inside:
			if not previous_inside:
				output.append(_cross_halfplane(previous, current, normal, limit))
			output.append(current)
		elif previous_inside:
			output.append(_cross_halfplane(previous, current, normal, limit))
		previous = current
		previous_inside = current_inside
	return output


func _inside_halfplane(point: Vector2, normal: Vector2, limit: float, keep_below: bool) -> bool:
	var signed := point.dot(normal)
	if keep_below:
		return signed <= limit + 0.5
	return signed >= limit - 0.5


func _cross_halfplane(start: Vector2, finish: Vector2, normal: Vector2, limit: float) -> Vector2:
	var start_signed := start.dot(normal) - limit
	var finish_signed := finish.dot(normal) - limit
	var span := start_signed - finish_signed
	if absf(span) < 0.0001:
		return finish
	return start.lerp(finish, start_signed / span)


func _base_dance_size() -> Vector2:
	var dance_h := size.y * 0.78
	var dance_w := dance_h * FRAME_ASPECT
	var max_w := size.x * 0.7
	if dance_w > max_w:
		dance_w = max_w
		dance_h = dance_w / FRAME_ASPECT
	return Vector2(dance_w, dance_h)


func _scatter_dances(base: Vector2) -> void:
	_dance_places.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var placed: Array[Rect2] = []
	for _index in _dances.size():
		var scale := rng.randf_range(1.0, 1.35)
		var dims := base * scale
		var rect := _pick_dance_rect(rng, dims, placed)
		placed.append(rect)
		_dance_places.append({
			"scale": scale,
			"nx": rect.position.x / size.x,
			"ny": rect.position.y / size.y,
		})
	_apply_dance_places(base)


func _pick_dance_rect(rng: RandomNumberGenerator, dims: Vector2, placed: Array[Rect2]) -> Rect2:
	var best := Rect2(Vector2.ZERO, dims)
	var best_score := 1000000000.0
	var min_x := -dims.x * 0.28
	var max_x := size.x - dims.x * 0.62
	var min_y := -dims.y * 0.2
	var max_y := size.y - dims.y * 0.55
	if max_x < min_x:
		max_x = min_x
	if max_y < min_y:
		max_y = min_y
	for _attempt in 40:
		var rect := Rect2(Vector2(rng.randf_range(min_x, max_x), rng.randf_range(min_y, max_y)), dims)
		var score := _dance_overlap(rect, placed)
		if score < best_score:
			best = rect
			best_score = score
		if score <= 0.0:
			break
	return best


func _dance_overlap(rect: Rect2, placed: Array[Rect2]) -> float:
	var score := 0.0
	var area := maxf(1.0, rect.size.x * rect.size.y)
	for other in placed:
		var shared := rect.intersection(other)
		if shared.size.x > 0.0 and shared.size.y > 0.0:
			score += shared.size.x * shared.size.y / area
		var gap := rect.get_center().distance_to(other.get_center())
		var needed := (maxf(rect.size.x, rect.size.y) + maxf(other.size.x, other.size.y)) * 0.28
		if gap < needed:
			score += (needed - gap) / needed
	return score


func _apply_dance_places(base: Vector2) -> void:
	for index in _dances.size():
		var dance := _dances[index]
		if index >= _dance_places.size():
			dance.visible = false
			continue
		var place: Dictionary = _dance_places[index]
		var dims := base * float(place.get("scale", 1.0))
		var pos := Vector2(float(place.get("nx", 0.0)) * size.x, float(place.get("ny", 0.0)) * size.y)
		pos.x = clampf(pos.x, -dims.x * 0.35, maxf(-dims.x * 0.35, size.x - dims.x * 0.55))
		pos.y = clampf(pos.y, -dims.y * 0.25, maxf(-dims.y * 0.25, size.y - dims.y * 0.5))
		dance.position = pos
		dance.size = dims
		dance.visible = _playing


func _mount_defeat_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.82, 0.9)
	environment.ambient_light_energy = 0.9
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_defeat_viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	light.light_energy = 1.35
	_defeat_viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.62, 0.62, 1.12)
	camera.fov = 28.0
	_defeat_viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.3, 0.0))
	camera.current = true


func _play_defeat_actor() -> void:
	var previous := _defeat_viewport.get_node_or_null("DefeatUnit")
	if previous != null:
		previous.queue_free()
	var unit := (load("res://scenes/unit.tscn") as PackedScene).instantiate() as GameUnit
	unit.name = "DefeatUnit"
	unit.rotation.y = PI
	_defeat_viewport.add_child(unit)
	unit.play_defeat_loop()
	_defeat_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _clear_routes() -> void:
	if _routes != null and is_instance_valid(_routes):
		_routes.queue_free()
	_routes = null


func _fit_label_font(label: Label, max_size: int, min_size: int) -> void:
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var limit := maxf(8.0, label.size.x - 8.0)
	var chosen := max_size
	while chosen > min_size and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > limit:
		chosen -= 2
	while chosen > 28 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, chosen).x > limit:
		chosen -= 2
	label.add_theme_font_size_override("font_size", chosen)
	label.size.y = font.get_height(chosen) + 6.0


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label


func _paths_for(dir_path: String) -> PackedStringArray:
	var cached: Variant = _path_cache.get(dir_path, null)
	if cached is PackedStringArray:
		return cached as PackedStringArray
	var paths := PackedStringArray()
	var names: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		_path_cache[dir_path] = paths
		return paths
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "png":
			continue
		names.append(file_name)
	names.sort()
	for file_name in names:
		paths.append(dir_path.path_join(file_name))
	_path_cache[dir_path] = paths
	return paths
