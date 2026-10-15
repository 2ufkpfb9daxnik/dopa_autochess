class_name CommentFlow
extends Control

const FONT_SIZE := 22
const LANE_HEIGHT := 30.0
const SPEED := 170.0

var _pending: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func push(text: String) -> void:
	if text.is_empty():
		return
	if size.x < 8.0:
		_pending.append(text)
		return
	_spawn(text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_flush_pending()


func _process(delta: float) -> void:
	var stale: Array[Node] = []
	for child in get_children():
		var label := child as Control
		label.position.x -= SPEED * delta
		if label.position.x + label.size.x < 0.0:
			stale.append(label)
	for label in stale:
		label.queue_free()


func _flush_pending() -> void:
	if size.x < 8.0 or _pending.is_empty():
		return
	var queued := _pending.duplicate()
	_pending.clear()
	for text in queued:
		_spawn(text)


func _spawn(text: String) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 8)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	label.reset_size()
	var text_size := label.get_minimum_size()
	label.size = Vector2(text_size.x, LANE_HEIGHT)
	var lane := _pick_lane()
	label.set_meta("lane", lane)
	label.position = Vector2(size.x, float(lane) * LANE_HEIGHT)


func _pick_lane() -> int:
	var lane_count := maxi(1, int(floor(size.y / LANE_HEIGHT)))
	var fallback := 0
	var fallback_right := INF
	for lane in lane_count:
		var right := _lane_right(lane)
		if right <= size.x - 24.0:
			return lane
		if right < fallback_right:
			fallback_right = right
			fallback = lane
	return fallback


func _lane_right(lane: int) -> float:
	var right := -INF
	for child in get_children():
		if int(child.get_meta("lane", -1)) != lane:
			continue
		var label := child as Control
		right = maxf(right, label.position.x + label.size.x)
	return right
