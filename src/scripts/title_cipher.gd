class_name TitleCipher
extends Control

const CIPHER := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#$%&*+=?/<>ΔλΣΩЖЮЯ█▓▒░"

@export var target_text := "Dopa\nAuto\nchess"
@export var font_size := 600
## Positive values add space between lines. Negative pulls lines closer (can overlap).
@export var line_spacing := -300
@export var horizontal_alignment := HORIZONTAL_ALIGNMENT_RIGHT

var _glyphs: PackedStringArray = []
var _chaos: PackedFloat32Array = []
var _scramble_left: PackedFloat32Array = []
var _centers: PackedVector2Array = []
var _font: Font
var _hovering := false
var _mouse := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _mouse_speed := 0.0
var _still_time := 0.0
var _layout_dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	_rebuild_state()
	resized.connect(func() -> void:
		_layout_dirty = true
		queue_redraw()
	)
	set_process(true)


func _rebuild_state() -> void:
	_glyphs.clear()
	_chaos = PackedFloat32Array()
	_scramble_left = PackedFloat32Array()
	_centers = PackedVector2Array()
	for index in target_text.length():
		var ch := target_text.substr(index, 1)
		_glyphs.append(ch)
		_chaos.append(0.0)
		_scramble_left.append(0.04)
		_centers.append(Vector2.ZERO)
	_layout_dirty = true
	queue_redraw()


func _process(delta: float) -> void:
	var global_mouse := get_global_mouse_position()
	var reach := float(font_size) * 0.55
	_hovering = get_global_rect().grow(reach).has_point(global_mouse)
	if _hovering:
		_mouse = get_global_transform_with_canvas().affine_inverse() * global_mouse
		_mouse_speed = _mouse.distance_to(_last_mouse) / maxf(delta, 0.0001)
		if _mouse_speed < 28.0:
			_still_time += delta
		else:
			_still_time = 0.0
		_last_mouse = _mouse
	else:
		_mouse_speed = 0.0
		_still_time = 0.0
	if _layout_dirty:
		_layout_glyphs()
		_layout_dirty = false
	var radius := float(font_size) * 1.35
	var changed := false
	for index in _glyphs.size():
		var ch := target_text.substr(index, 1)
		if _is_fixed(ch):
			_glyphs[index] = ch
			_chaos[index] = 0.0
			continue
		var influence := 0.0
		if _hovering:
			var dist := _centers[index].distance_to(_mouse)
			influence = clampf(1.0 - dist / maxf(1.0, radius), 0.0, 1.0)
			influence = pow(influence, 0.85)
		var before := _chaos[index]
		if influence > 0.01:
			# Moving near a glyph breaks it open.
			if _mouse_speed > 24.0:
				_chaos[index] = minf(1.0, _chaos[index] + delta * lerpf(3.0, 12.0, influence) * clampf(_mouse_speed / 320.0, 0.45, 1.8))
			elif _still_time > 0.1:
				# Holding still lets the cipher settle back.
				_chaos[index] = maxf(0.0, _chaos[index] - delta * lerpf(1.0, 3.6, influence) * clampf((_still_time - 0.1) * 2.2, 0.35, 2.0))
			else:
				# Fresh hover: a short burst of collapse even without much motion.
				_chaos[index] = minf(1.0, _chaos[index] + delta * lerpf(1.6, 6.5, influence))
		else:
			_chaos[index] = maxf(0.0, _chaos[index] - delta * 5.5)
		if not is_equal_approx(before, _chaos[index]):
			changed = true
		if _chaos[index] <= 0.001:
			if _glyphs[index] != ch:
				_glyphs[index] = ch
				changed = true
			continue
		_scramble_left[index] -= delta * lerpf(8.0, 36.0, _chaos[index])
		if _scramble_left[index] <= 0.0:
			_glyphs[index] = _random_cipher()
			_scramble_left[index] = randf_range(0.012, lerpf(0.08, 0.018, _chaos[index]))
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	if _layout_dirty:
		_layout_glyphs()
		_layout_dirty = false
	var color := Color(0.96, 0.96, 0.94)
	var cursor := _text_origin()
	var line_height := _line_height()
	for index in target_text.length():
		var target_ch := target_text.substr(index, 1)
		if target_ch == "\n":
			cursor.x = _text_origin().x
			cursor.y += line_height
			continue
		var advance := _advance(target_ch)
		if target_ch == " ":
			cursor.x += advance
			continue
		var shown := _glyphs[index] if index < _glyphs.size() else target_ch
		var draw_pos := Vector2(cursor.x, cursor.y + float(font_size) * 0.82)
		var glyph_color := color
		if index < _chaos.size() and _chaos[index] > 0.001:
			var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.05 + float(index) * 1.7)
			glyph_color = color.lerp(Color(0.45, 1.0, 0.78), _chaos[index] * 0.5 * pulse)
		draw_string(_font, draw_pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, glyph_color)
		cursor.x += advance


func _layout_glyphs() -> void:
	if _font == null or _centers.size() != target_text.length():
		return
	var cursor := _text_origin()
	var line_height := _line_height()
	for index in target_text.length():
		var target_ch := target_text.substr(index, 1)
		if target_ch == "\n":
			_centers[index] = cursor + Vector2(0.0, line_height * 0.5)
			cursor.x = _text_origin().x
			cursor.y += line_height
			continue
		var advance := _advance(target_ch)
		_centers[index] = cursor + Vector2(advance * 0.5, line_height * 0.45)
		cursor.x += advance


func _line_height() -> float:
	return maxf(float(font_size) * 0.16, float(font_size) + float(line_spacing))


func _text_origin() -> Vector2:
	var lines := target_text.split("\n")
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_count := maxi(lines.size(), 1)
	var block_h := float(font_size) * 0.82 + float(line_count - 1) * _line_height()
	var origin_x := 0.0
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			origin_x = (size.x - widest) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			origin_x = size.x - widest
		_:
			origin_x = 0.0
	var origin_y := maxf(0.0, size.y - block_h - 8.0)
	return Vector2(origin_x, origin_y)


func _advance(ch: String) -> float:
	var sample := ch if ch != " " else "A"
	return _font.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _is_fixed(ch: String) -> bool:
	return ch == "\n" or ch == " " or ch == "\t"


func _random_cipher() -> String:
	return CIPHER.substr(randi() % CIPHER.length(), 1)
