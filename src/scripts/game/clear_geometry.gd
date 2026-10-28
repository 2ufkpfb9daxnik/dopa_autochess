class_name ClearGeometry
extends Control

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 45
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	_draw_flow_field()
	_draw_warped_lattice()
	_draw_travelers()


func _scroll() -> Vector2:
	return Vector2(_time * 280.0, _time * 170.0)


func _warp(point: Vector2) -> Vector2:
	var x := point.x + _scroll().x
	var y := point.y + _scroll().y
	return point + Vector2(
		sin(y * 0.011 + _time * 1.5) * 42.0 + sin(x * 0.006 + _time * 0.85) * 26.0,
		cos(x * 0.01 + _time * 1.2) * 40.0 + cos(y * 0.008 - _time * 1.05) * 24.0
	)


func _draw_flow_field() -> void:
	var step := 46.0
	var scroll := _scroll()
	var cols := int(size.x / step) + 3
	var rows := int(size.y / step) + 3
	var origin := Vector2(-fposmod(scroll.x, step), -fposmod(scroll.y, step))
	for y in rows:
		for x in cols:
			var point := origin + Vector2(float(x) * step, float(y) * step)
			var world := point + scroll
			var angle := sin(world.x * 0.008 + _time * 1.4) * 1.6 + cos(world.y * 0.011 - _time * 0.9) * 1.8
			var direction := Vector2(cos(angle), sin(angle)) * 22.0
			var hue := fposmod(world.x * 0.00035 + world.y * 0.0005 + _time * 0.04, 1.0)
			draw_line(point, point + direction, Color.from_hsv(hue, 0.5, 1.0, 0.62), 5.5, true)


func _draw_warped_lattice() -> void:
	var cell := 86.0
	var scroll := _scroll()
	var cols := int(size.x / cell) + 4
	var rows := int(size.y / cell) + 4
	var origin := Vector2(-fposmod(scroll.x, cell) - cell, -fposmod(scroll.y, cell) - cell)
	for y in rows:
		for x in cols:
			var corner := origin + Vector2(float(x) * cell, float(y) * cell)
			var polygon := PackedVector2Array([
				_warp(corner),
				_warp(corner + Vector2(cell, 0.0)),
				_warp(corner + Vector2(cell, cell)),
				_warp(corner + Vector2(0.0, cell)),
			])
			var hue := fposmod((corner.x + scroll.x) * 0.0009 + (corner.y + scroll.y) * 0.0006 + _time * 0.06, 1.0)
			draw_colored_polygon(polygon, Color.from_hsv(hue, 0.42, 0.98, 0.13))
			var outline := polygon.duplicate()
			outline.append(polygon[0])
			draw_polyline(outline, Color.from_hsv(fposmod(hue + 0.12, 1.0), 0.32, 1.0, 0.78), 5.5, true)


func _draw_travelers() -> void:
	_draw_circle_chain(0.18, 0.08, Color(1.0, 0.93, 0.72, 0.84))
	_draw_circle_chain(0.5, 2.1, Color(0.68, 0.9, 1.0, 0.8))
	_draw_circle_chain(0.82, 4.0, Color(1.0, 0.68, 0.78, 0.8))


func _draw_circle_chain(y_ratio: float, phase: float, color: Color) -> void:
	var radius := minf(size.x, size.y) * 0.1
	var gap := radius * 0.72
	var count := int((size.x + radius * 6.0) / gap) + 2
	var shift := fposmod(_time * 260.0 + phase * 70.0, gap)
	for index in count:
		var x := -radius * 3.0 + float(index) * gap - shift
		var y := size.y * y_ratio + sin(_time * 0.85 + float(index) * 0.42 + phase) * size.y * 0.2
		draw_arc(Vector2(x, y), radius, 0.0, TAU, 36, color, 7.0, true)
