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
var _guide := Vector2.ZERO
var _radius := 110.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 96


func open_for(unit: GameUnit) -> void:
	_unit = unit
	_mode = randi() % 3
	_clicks = 0
	_wound = 0.0
	_tracing = false
	_orb_alive = [true, true, true]
	top_level = true
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	_guide = size * 0.5
	_radius = clampf(minf(size.x, size.y) * 0.16, 88.0, 140.0)
	_orbs = [
		_guide + Vector2(-_radius, 36.0),
		_guide + Vector2(0.0, -_radius * 0.15),
		_guide + Vector2(_radius, 36.0),
	]
	visible = true
	move_to_front()
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
			accept_event()
			return
		if _mode == 0 and button.button_index == MOUSE_BUTTON_RIGHT:
			_clicks += 1
			if _clicks >= 3:
				_succeed()
			else:
				queue_redraw()
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
	draw_string(font, _guide + Vector2(-120.0, -_radius - 78.0), title, HORIZONTAL_ALIGNMENT_LEFT, 240.0, 28, Color(0.86, 1.0, 0.55))
	var hint := _hint()
	draw_string(font, _guide + Vector2(-220.0, -_radius - 40.0), hint, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 18, Color(0.9, 0.96, 0.86))
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
		return "右クリックを 3 回"
	if _mode == 1:
		return "円をなぞる"
	return "玉を 3 つ潰す"


func _draw_clicks() -> void:
	for index in 3:
		var center := _guide + Vector2(float(index - 1) * 64.0, 10.0)
		var filled := index < _clicks
		draw_circle(center, 22.0, Color(0.45, 0.9, 0.2, 0.95) if filled else Color(0.15, 0.22, 0.1, 0.9))
		draw_arc(center, 22.0, 0.0, TAU, 24, Color(0.8, 1.0, 0.55), 3.0, true)


func _draw_circle_guide() -> void:
	draw_arc(_guide, _radius, 0.0, TAU, 64, Color(0.75, 0.95, 0.4, 0.9), 8.0, true)
	var shown := clampf(absf(_wound) / TAU, 0.0, 1.0)
	if shown > 0.02:
		draw_arc(_guide, _radius, -PI * 0.5, -PI * 0.5 + TAU * shown, 64, Color(0.95, 1.0, 0.7), 8.0, true)


func _draw_orbs() -> void:
	for index in _orbs.size():
		var center := _orbs[index]
		if not _orb_alive[index]:
			draw_circle(center, 10.0, Color(0.25, 0.4, 0.1, 0.7))
			continue
		draw_circle(center, 28.0, Color(0.42, 0.86, 0.16, 0.95))
		draw_circle(center + Vector2(-8.0, -8.0), 8.0, Color(0.8, 1.0, 0.55, 0.45))
		draw_arc(center, 28.0, 0.0, TAU, 24, Color(0.15, 0.28, 0.05), 3.0, true)


func _accumulate_circle(point: Vector2) -> void:
	var previous := _last_point - _guide
	var current := point - _guide
	if previous.length() < 24.0 or current.length() < 24.0:
		return
	if previous.length() > _radius * 1.8 or current.length() > _radius * 1.8:
		return
	_wound += previous.angle_to(current)
	queue_redraw()
	if absf(_wound) >= TAU * 0.9:
		_succeed()


func _crush_at(point: Vector2) -> void:
	for index in _orbs.size():
		if not _orb_alive[index]:
			continue
		if point.distance_to(_orbs[index]) > 34.0:
			continue
		_orb_alive[index] = false
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
	if unit != null and is_instance_valid(unit):
		cleared.emit(unit)
