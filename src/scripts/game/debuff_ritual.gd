class_name DebuffRitual
extends Control

signal cleared(unit: GameUnit)

var _unit: GameUnit
var _mode := 0
var _clicks := 0
var _wound := 0.0
var _tracing := false
var _last_point := Vector2.ZERO
var _orbs: Array[Vector2] = []
var _orb_alive: Array[bool] = []
var _orb_vel: Array[Vector2] = []
var _orb_radius := 110.0
var _guide := Vector2.ZERO
var _radius := 110.0
var _circle_se_cooldown := 0.0
const RIGHT_CLICK_NEED := 3


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 96
	set_process(false)


func open_for(unit: GameUnit) -> void:
	_unit = unit
	_mode = randi() % 3
	_clicks = 0
	_wound = 0.0
	_tracing = false
	_circle_se_cooldown = 0.0
	_orb_alive = [true, true, true]
	top_level = true
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	_guide = size * 0.5
	_radius = clampf(minf(size.x, size.y) * 0.16, 88.0, 140.0)
	_orb_radius = clampf(minf(size.x, size.y) * 0.145, 100.0, 150.0)
	_scatter_orbs()
	visible = true
	set_process(_mode == 1 or _mode == 2)
	GameAudio.play_debuff_ritual(_mode)
	move_to_front()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	if _circle_se_cooldown > 0.0:
		_circle_se_cooldown = maxf(0.0, _circle_se_cooldown - delta)
	if _mode != 2:
		return
	var margin := _orb_radius + 12.0
	var top := 96.0 + _orb_radius
	var bottom := size.y - 72.0 - _orb_radius
	for index in _orbs.size():
		if not _orb_alive[index]:
			continue
		_orbs[index] += _orb_vel[index] * delta
		var pos := _orbs[index]
		var vel := _orb_vel[index]
		if pos.x < margin:
			pos.x = margin
			vel.x = absf(vel.x)
		elif pos.x > size.x - margin:
			pos.x = size.x - margin
			vel.x = -absf(vel.x)
		if pos.y < top:
			pos.y = top
			vel.y = absf(vel.y)
		elif pos.y > bottom:
			pos.y = bottom
			vel.y = -absf(vel.y)
		_orbs[index] = pos
		_orb_vel[index] = vel
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			if _mode == 1 and button.button_index == MOUSE_BUTTON_LEFT:
				_tracing = false
			return
		if _back_rect().has_point(button.position):
			visible = false
			set_process(false)
			accept_event()
			return
		if _mode == 0 and button.button_index == MOUSE_BUTTON_RIGHT:
			_right_click()
			accept_event()
			return
		if _mode == 2 and button.button_index == MOUSE_BUTTON_LEFT:
			_crush_at(button.position)
			accept_event()
			return
		if _mode == 1 and button.button_index == MOUSE_BUTTON_LEFT:
			_tracing = true
			_last_point = button.position
			accept_event()
	elif event is InputEventMouseMotion and _mode == 1 and _tracing:
		var motion := event as InputEventMouseMotion
		_accumulate_circle(motion.position)
		_last_point = motion.position
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.02, 0.55))
	var font := ThemeDB.fallback_font
	var title := "デバフ解除"
	draw_string(font, Vector2(size.x * 0.05, 52.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.9, 36, Color(0.86, 1.0, 0.55))
	var hint := _hint()
	var hint_size := int(clampf(minf(size.x, size.y) * 0.22, 140.0, 260.0))
	draw_string(font, Vector2(size.x * 0.02, 56.0 + float(hint_size)), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.96, hint_size, Color(0.98, 1.0, 0.9))
	if _mode == 0:
		_draw_clicks()
	elif _mode == 1:
		_draw_circle_guide()
	else:
		_draw_orbs()
	var back := _back_rect()
	draw_rect(back, Color(0.08, 0.1, 0.08, 0.92))
	draw_rect(back, Color(0.7, 0.9, 0.5), false, 2.0)
	draw_string(font, back.position + Vector2(28.0, 28.0), "戻る", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 18, Color(0.9, 0.95, 0.86))


func _hint() -> String:
	if _mode == 0:
		return "3回右クリック！！"
	if _mode == 1:
		return "丸くなぞる！！"
	return "3つ潰す！！"


func _draw_clicks() -> void:
	var spacing := 72.0
	var start := _guide + Vector2(-spacing, 36.0)
	for index in RIGHT_CLICK_NEED:
		var center := start + Vector2(spacing * float(index), 0.0)
		var filled := index < _clicks
		var color := Color(0.45, 0.9, 0.2, 0.92) if filled else Color(0.16, 0.24, 0.1, 0.88)
		draw_circle(center, 28.0, color)
		draw_arc(center, 28.0, 0.0, TAU, 28, Color(0.8, 1.0, 0.55), 4.0, true)


func _right_click() -> void:
	if _clicks >= RIGHT_CLICK_NEED:
		return
	_clicks += 1
	GameAudio.play_debuff_ritual(0)
	if _clicks >= RIGHT_CLICK_NEED:
		_succeed()
	else:
		queue_redraw()


func _draw_circle_guide() -> void:
	# Guide: cool cyan. Progress: complementary warm magenta-orange so travel is obvious.
	draw_arc(_guide, _radius, 0.0, TAU, 64, Color(0.2, 0.78, 0.92, 0.95), 10.0, true)
	var shown := clampf(absf(_wound) / TAU, 0.0, 1.0)
	if shown > 0.02:
		draw_arc(_guide, _radius, -PI * 0.5, -PI * 0.5 + TAU * shown, 64, Color(1.0, 0.28, 0.55, 1.0), 12.0, true)


func _draw_orbs() -> void:
	for index in _orbs.size():
		var center := _orbs[index]
		if not _orb_alive[index]:
			draw_circle(center, _orb_radius * 0.22, Color(0.25, 0.4, 0.1, 0.55))
			continue
		draw_circle(center, _orb_radius, Color(0.42, 0.86, 0.16, 0.92))
		draw_circle(center + Vector2(-_orb_radius * 0.28, -_orb_radius * 0.28), _orb_radius * 0.28, Color(0.8, 1.0, 0.55, 0.42))
		draw_arc(center, _orb_radius, 0.0, TAU, 48, Color(0.15, 0.28, 0.05), 5.0, true)
		draw_arc(center, _orb_radius * 0.72, 0.0, TAU, 36, Color(0.9, 1.0, 0.65, 0.35), 3.0, true)


func _scatter_orbs() -> void:
	_orbs.clear()
	_orb_vel.clear()
	var margin := _orb_radius + 24.0
	var top := 110.0 + _orb_radius
	var bottom := size.y - 90.0 - _orb_radius
	var min_sep := _orb_radius * 2.15
	for _attempt in 48:
		if _orbs.size() >= 3:
			break
		var candidate := Vector2(
			randf_range(margin, maxf(margin + 1.0, size.x - margin)),
			randf_range(top, maxf(top + 1.0, bottom))
		)
		var ok := true
		for existing in _orbs:
			if candidate.distance_to(existing) < min_sep:
				ok = false
				break
		if not ok:
			continue
		_orbs.append(candidate)
		var angle := randf() * TAU
		var speed := randf_range(55.0, 120.0)
		_orb_vel.append(Vector2(cos(angle), sin(angle)) * speed)
	while _orbs.size() < 3:
		var fallback := _guide + Vector2(randf_range(-180.0, 180.0), randf_range(-90.0, 140.0))
		_orbs.append(fallback)
		var angle := randf() * TAU
		_orb_vel.append(Vector2(cos(angle), sin(angle)) * randf_range(55.0, 120.0))


func _accumulate_circle(point: Vector2) -> void:
	var previous := _last_point - _guide
	var current := point - _guide
	if previous.length() < 24.0 or current.length() < 24.0:
		return
	if previous.length() > _radius * 1.8 or current.length() > _radius * 1.8:
		return
	var before := absf(_wound)
	_wound += previous.angle_to(current)
	if absf(_wound) > before and _circle_se_cooldown <= 0.0:
		GameAudio.play_debuff_ritual(1)
		_circle_se_cooldown = 0.28
	queue_redraw()
	if absf(_wound) >= TAU * 0.9:
		_succeed()


func _crush_at(point: Vector2) -> void:
	for index in _orbs.size():
		if not _orb_alive[index]:
			continue
		if point.distance_to(_orbs[index]) > _orb_radius:
			continue
		_orb_alive[index] = false
		GameAudio.play_debuff_ritual(2)
		queue_redraw()
		if not _orb_alive.has(true):
			_succeed()
		return


func _back_rect() -> Rect2:
	return Rect2(_guide + Vector2(-48.0, _radius + 56.0), Vector2(96.0, 40.0))


func _succeed() -> void:
	var unit := _unit
	visible = false
	_tracing = false
	set_process(false)
	GameAudio.play_debuff_remove()
	if unit != null and is_instance_valid(unit):
		cleared.emit(unit)
