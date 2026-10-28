extends Control

const FILL := Color(0.82, 0.1, 0.14, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 55
	visible = false


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var normal := Vector2(-size.y, size.x).normalized()
	var span := -Vector2(size.x, 0.0).dot(normal)
	var thickness := 22.0
	var period := 36.0
	var triangle := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		Vector2(size.x, size.y),
	])
	var offset := -span
	while offset < -0.5:
		var near := minf(offset + thickness, 0.0)
		var poly := _clip_strip(triangle, normal, offset, near)
		if poly.size() >= 3:
			draw_colored_polygon(poly, FILL)
		offset += period


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
