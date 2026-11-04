class_name BattleResult
extends Control

const DANCE_DIR := "res://images/frames/dance"
const LOSE_DIR := "res://images/frames/lose"
const FRAME_FPS := 24.0
const FRAME_ASPECT := 1344.0 / 768.0
const DANCE_COUNT := 5
const ClearStripesScript := preload("res://scripts/game/clear_stripes.gd")

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
var _flow_bands: Array[float] = []
var _clear_marquee_rows: Array[Label] = []
var _clear_marquee_centers: Array[Vector2] = []
var _clear_marquee_offset := 0.0
var _clear_marquee_cycle := 1.0
var _clear_marquee_angle := 0.0
var _clear_marquee_dir := Vector2.RIGHT
var _clear_marquee_box := Vector2.ZERO
const CLEAR_MARQUEE_SPEED := 180.0
const CLEAR_MARQUEE_ROWS := 5
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
	_clear_mark.text = "クリア"
	_clear_mark.visible = false
	_clear_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_mark.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clear_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clear_mark.clip_text = false
	_clear_mark.z_index = 2
	_clear_mark.add_theme_constant_override("outline_size", 36)
	_clear_mark.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_clear_mark.add_theme_color_override("font_outline_color", Color(0.35, 0.04, 0.06, 0.92))
	_body = _make_label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_title.z_index = 2
	_body.z_index = 2
	_hp_caption = _make_label(84, HORIZONTAL_ALIGNMENT_LEFT)
	_hp_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hp_caption.add_theme_constant_override("outline_size", 12)
	_hp_caption.z_index = 2
	_hp_caption.visible = false
	_hp_caption.clip_contents = true
	_hp_value = _make_label(200, HORIZONTAL_ALIGNMENT_LEFT)
	_hp_value.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hp_value.add_theme_constant_override("outline_size", 16)
	_hp_value.z_index = 2
	_hp_value.visible = false
	_hp_value.clip_contents = true
	resized.connect(_on_resized)
	if not get_viewport().size_changed.is_connected(_fit_viewport):
		get_viewport().size_changed.connect(_fit_viewport)


func _has_point(point: Vector2) -> bool:
	## 表示中だけ全面モーダル。非表示やサイズ0では一切拾わない。
	if not visible or size.x < 2.0 or size.y < 2.0:
		return false
	return true


func open(won: bool, body: String, hp_before: int = -1, hp_after: int = -1) -> void:
	_fill = Color(0.82, 0.1, 0.14, 1.0) if won else Color(0.12, 0.28, 0.78, 1.0)
	_title.text = "勝利！" if won else "敗北"
	_striped = false
	_flow_bands.clear()
	_hide_clear_marquee_rows()
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 100
	top_level = true
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	var viewport := get_viewport()
	if viewport != null:
		size = viewport.get_visible_rect().size
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
	_clear_mark.visible = false
	_striped = true
	_clear_marquee_offset = 0.0
	_flow_bands.clear()
	ClearStripesScript.seed_bands(_flow_bands, size)
	_layout_content()
	queue_redraw()


func _ensure_clear_marquee_rows(count: int) -> void:
	while _clear_marquee_rows.size() < count:
		var label := Label.new()
		label.name = "ClearMarquee%d" % _clear_marquee_rows.size()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.z_index = 2
		add_child(label)
		_clear_marquee_rows.append(label)
	for index in _clear_marquee_rows.size():
		_clear_marquee_rows[index].visible = index < count


func _hide_clear_marquee_rows() -> void:
	for label in _clear_marquee_rows:
		label.visible = false


func _place_clear_marquee() -> void:
	if _clear_marquee_cycle <= 0.0 or _clear_marquee_box == Vector2.ZERO:
		return
	var wrapped := fposmod(_clear_marquee_offset, _clear_marquee_cycle)
	for index in _clear_marquee_rows.size():
		var label := _clear_marquee_rows[index]
		if not label.visible or index >= _clear_marquee_centers.size():
			continue
		var shift := wrapped if (index % 2) == 0 else -wrapped
		var center := _clear_marquee_centers[index] + _clear_marquee_dir * shift
		label.size = _clear_marquee_box
		label.pivot_offset = _clear_marquee_box * 0.5
		label.rotation = _clear_marquee_angle
		label.position = center - _clear_marquee_box * 0.5


func close() -> void:
	_playing = false
	_striped = false
	_flow_bands.clear()
	_hide_clear_marquee_rows()
	_clear_routes()
	_defeat_view.visible = false
	_defeat_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _clear_mark != null:
		_clear_mark.visible = false
	## top_level / 全面サイズのまま残すと、閉じたあとも入力を奪うことがある。
	visible = false
	top_level = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2.ZERO
	if modal_changed.is_valid():
		modal_changed.call(false)


func show_routes(lines: PackedStringArray, pick: Callable, hint: String = "") -> void:
	_clear_routes()
	_routes = VBoxContainer.new()
	_routes.mouse_filter = Control.MOUSE_FILTER_STOP
	_routes.z_index = 20
	_routes.clip_contents = false
	_routes.add_theme_constant_override("separation", 12)
	add_child(_routes)
	if not hint.is_empty():
		var tip := Label.new()
		tip.text = hint
		tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_font_size_override("font_size", 18)
		tip.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
		tip.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.06, 0.9))
		tip.add_theme_constant_override("outline_size", 6)
		_routes.add_child(tip)
	var large := lines.size() <= 2
	for index in lines.size():
		var button := Button.new()
		button.text = lines[index]
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.custom_minimum_size = Vector2(360, 110 if large else 72)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 56 if large else 26)
		var picked := index
		button.pressed.connect(func() -> void: pick.call(picked))
		_routes.add_child(button)
	move_child(_routes, get_child_count() - 1)
	_layout_content()


func _process(delta: float) -> void:
	if _striped and visible:
		if _flow_bands.is_empty():
			ClearStripesScript.seed_bands(_flow_bands, size)
		ClearStripesScript.advance_bands(_flow_bands, size, delta)
		if not _clear_marquee_rows.is_empty() and _clear_marquee_rows[0].visible:
			_clear_marquee_offset += CLEAR_MARQUEE_SPEED * delta
			_place_clear_marquee()
		queue_redraw()
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
	if _striped:
		ClearStripesScript.draw_flowing_bands(self, size, _fill, _flow_bands)
		return
	var triangle := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
	])
	draw_colored_polygon(triangle, _fill)


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
	if _striped:
		var angle := atan2(size.y, size.x)
		var dir := Vector2(size.x, size.y).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var title_font := int(clampf(minf(size.x, size.y) * 0.14, 72.0, 160.0))
		_title.add_theme_font_size_override("font_size", title_font)
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var title_box := Vector2(minf(size.x * 0.9, size.length() * 0.7), float(title_font) * 1.4)
		var title_center := size * 0.5 + perp * (-minf(size.x, size.y) * 0.18) + dir * (-minf(size.x, size.y) * 0.12)
		_title.size = title_box
		_title.pivot_offset = title_box * 0.5
		_title.rotation = angle
		_title.position = title_center - title_box * 0.5
		_body.add_theme_font_size_override("font_size", 22)
		_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var body_box := Vector2(clampf(size.x * 0.4, 320.0, 520.0), 120.0)
		var body_center := title_center + perp * (minf(size.x, size.y) * 0.1)
		_body.size = body_box
		_body.pivot_offset = body_box * 0.5
		_body.rotation = angle
		_body.position = body_center - body_box * 0.5
		if _routes != null:
			## タイトル文字の左下付近に沿わせる（斜めレイアウト）。
			var route_h := maxf(_routes.get_combined_minimum_size().y + 8.0, 160.0)
			var route_box := Vector2(clampf(size.x * 0.42, 360.0, 560.0), route_h)
			var route_center := (
				title_center
				+ perp * (title_box.y * 0.55 + route_box.y * 0.42)
				+ dir * (-title_box.x * 0.22)
			)
			_routes.size = route_box
			_routes.pivot_offset = route_box * 0.5
			_routes.rotation = angle
			_routes.position = route_center - route_box * 0.5
			for child in _routes.get_children():
				var button := child as Button
				if button == null:
					continue
				button.add_theme_font_size_override("font_size", 28)
				button.custom_minimum_size = Vector2(route_box.x - 24.0, 64.0)
	else:
		## 勝利／敗北共通: タイトル左下にルート選択を置く。
		_title.rotation = 0.0
		_title.pivot_offset = Vector2.ZERO
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_title.add_theme_font_size_override("font_size", 144)
		_title.position = Vector2(column_x, 4.0)
		_title.size = Vector2(text_w, 168.0)
		_body.rotation = 0.0
		_body.pivot_offset = Vector2.ZERO
		_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var below_title := _title.position.y + _title.size.y + 8.0
		if _routes != null:
			_routes.rotation = 0.0
			_routes.pivot_offset = Vector2.ZERO
			var route_min := _routes.get_combined_minimum_size()
			var route_h := maxf(route_min.y + 8.0, 120.0)
			var route_y := clampf(below_title, 8.0, maxf(8.0, size.y - route_h - 16.0))
			_routes.position = Vector2(column_x, route_y)
			_routes.size = Vector2(text_w, route_h)
			for child in _routes.get_children():
				var button := child as Button
				if button == null:
					continue
				button.add_theme_font_size_override("font_size", 26)
				button.custom_minimum_size = Vector2(text_w - 16.0, 64.0)
			below_title = _routes.position.y + route_h + 12.0
		## 本文はルートの下に必要な分だけ。巨大なヒット領域を残さない。
		_body.position = Vector2(column_x, below_title)
		_body.size = Vector2(text_w, minf(180.0, maxf(80.0, size.y - below_title - 24.0)))
	if _hp_value != null and _hp_value.visible:
		## 右カラムの経験値と被らないよう、画面左端へ置く。
		var left_pad := 28.0
		var hp_top := size.y * 0.48
		var hp_w := clampf(size.x * 0.42, 380.0, 720.0)
		_hp_caption.position = Vector2(left_pad, hp_top)
		_hp_caption.size = Vector2(hp_w, 96.0)
		_fit_label_font(_hp_caption, 84, 36)
		_hp_value.position = Vector2(left_pad, _hp_caption.position.y + _hp_caption.size.y + 6.0)
		_hp_value.size = Vector2(hp_w, 220.0)
		_fit_label_font(_hp_value, 200, 64)
	if _striped:
		## 文字向きはそのまま、左上→右下へ多行で流す。隣行は逆流。空白なし。
		_ensure_clear_marquee_rows(CLEAR_MARQUEE_ROWS)
		if _clear_mark != null:
			_clear_mark.visible = false
		var mark_size := int(clampf(minf(size.x, size.y) * 0.42, 160.0, 420.0))
		var phrase := "クリア"
		var probe := _clear_marquee_rows[0]
		probe.add_theme_font_size_override("font_size", mark_size)
		var font := probe.get_theme_font("font")
		var phrase_w := float(mark_size) * 3.0
		if font != null:
			phrase_w = font.get_string_size(phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size).x
		phrase_w = maxf(phrase_w, 1.0)
		_clear_marquee_cycle = phrase_w
		var copies := maxi(8, int(ceili(size.length() * 2.5 / phrase_w)) + 2)
		var continuous := phrase.repeat(copies)
		var title_h := float(mark_size) * 1.05
		_clear_marquee_box = Vector2(phrase_w * float(copies), title_h)
		_clear_marquee_angle = atan2(size.y, size.x)
		_clear_marquee_dir = Vector2(size.x, size.y).normalized()
		var perp := Vector2(-_clear_marquee_dir.y, _clear_marquee_dir.x)
		var row_gap := title_h * 0.92
		var stack_mid := size * 0.5 + perp * (-minf(size.x, size.y) * 0.02)
		_clear_marquee_centers.clear()
		for index in CLEAR_MARQUEE_ROWS:
			var label := _clear_marquee_rows[index]
			var row_t := float(index) - float(CLEAR_MARQUEE_ROWS - 1) * 0.5
			_clear_marquee_centers.append(stack_mid + perp * (row_t * row_gap))
			label.text = continuous
			label.add_theme_font_size_override("font_size", mark_size)
			label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
			label.add_theme_color_override("font_outline_color", Color(0.35, 0.04, 0.06, 0.92))
			label.add_theme_constant_override("outline_size", maxi(18, mark_size / 10))
			label.visible = true
		_place_clear_marquee()
	else:
		_hide_clear_marquee_rows()
		if _clear_mark != null:
			_clear_mark.rotation = 0.0
			_clear_mark.pivot_offset = Vector2.ZERO
	var base := _base_dance_size()
	_defeat_view.size = base
	_defeat_view.position = Vector2(size.x - base.x - 4.0, size.y * 0.16)
	if _playing and _dance_places.is_empty():
		_scatter_dances(base)
	else:
		_apply_dance_places(base)


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
		var old := _routes
		_routes = null
		if old.get_parent() == self:
			remove_child(old)
		old.queue_free()
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
