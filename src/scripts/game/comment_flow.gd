class_name CommentFlow
extends Control

const FONT_SIZE := 40
const LANE_HEIGHT := 52.0
const START_Y := 16.0
const SPEED := 170.0
const _MASK_SHADER := """
shader_type canvas_item;
uniform vec4 hole;
varying vec2 canvas_position;

void vertex() {
	canvas_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (canvas_position.x >= hole.x && canvas_position.x <= hole.x + hole.z && canvas_position.y >= hole.y && canvas_position.y <= hole.y + hole.w) {
		discard;
	}
}
"""

var _pending: Array[String] = []
var _mask: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var shader := Shader.new()
	shader.code = _MASK_SHADER
	_mask = ShaderMaterial.new()
	_mask.shader = shader
	set_hole(Rect2())


func set_hole(rect: Rect2) -> void:
	if _mask == null:
		return
	_mask.set_shader_parameter("hole", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


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
	label.add_theme_constant_override("outline_size", 12)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.material = _mask
	add_child(label)
	label.reset_size()
	var text_size := label.get_minimum_size()
	label.size = Vector2(text_size.x, LANE_HEIGHT)
	var lane := _pick_lane()
	label.set_meta("lane", lane)
	label.position = Vector2(size.x, START_Y + float(lane) * LANE_HEIGHT)


func _pick_lane() -> int:
	var lane_count := maxi(1, int(floor(maxf(0.0, size.y - START_Y) / LANE_HEIGHT)))
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
