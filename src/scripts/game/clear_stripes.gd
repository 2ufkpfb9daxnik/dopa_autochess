class_name ClearStripes
extends Control

const FILL := Color(0.82, 0.1, 0.14, 1.0)
## 対角方向の帯厚・間隔・流速（画面対角スパンに対する比率）。
const THICKNESS_RATIO := 0.26
const GAP_RATIO := 0.14
const SPEED_RATIO := 0.28

## 各帯の中心（対角法線方向の符号付き距離）。hi 側へ流れて降りていく。
var _bands: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 55
	visible = false
	set_process(false)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		restart_flow()
		set_process(true)
	else:
		set_process(false)
		_bands.clear()


func restart_flow() -> void:
	seed_bands(_bands, size)
	queue_redraw()


func _process(delta: float) -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	if _bands.is_empty():
		seed_bands(_bands, size)
	advance_bands(_bands, size, delta)
	queue_redraw()


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	draw_flowing_bands(self, size, FILL, _bands)


static func seed_bands(bands: Array[float], area: Vector2) -> void:
	bands.clear()
	var metrics := band_metrics(area)
	if metrics.is_empty():
		return
	var lo: float = metrics.lo
	var hi: float = metrics.hi
	var half: float = metrics.half
	var period: float = metrics.period
	## 見える範囲を埋めるところから開始（上側=lo から順に）。
	var center := lo - half
	while center <= hi + half + period:
		bands.append(center)
		center += period


static func band_metrics(area: Vector2) -> Dictionary:
	if area.x < 2.0 or area.y < 2.0:
		return {}
	var normal := Vector2(-area.y, area.x).normalized()
	var corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(area.x, 0.0),
		Vector2(area.x, area.y),
		Vector2(0.0, area.y),
	])
	var lo := INF
	var hi := -INF
	for corner in corners:
		var signed := corner.dot(normal)
		lo = minf(lo, signed)
		hi = maxf(hi, signed)
	var span := hi - lo
	if span <= 0.001:
		return {}
	var thickness := span * THICKNESS_RATIO
	var gap := span * GAP_RATIO
	return {
		"normal": normal,
		"corners": corners,
		"lo": lo,
		"hi": hi,
		"span": span,
		"half": thickness * 0.5,
		"period": thickness + gap,
		"speed": span * SPEED_RATIO,
	}


static func advance_bands(bands: Array[float], area: Vector2, delta: float) -> void:
	var metrics := band_metrics(area)
	if metrics.is_empty():
		bands.clear()
		return
	var lo: float = metrics.lo
	var hi: float = metrics.hi
	var half: float = metrics.half
	var period: float = metrics.period
	var speed: float = metrics.speed
	var step := speed * delta
	## 左上→右下の帯が、法線方向に向かって下へ流れる。
	for i in bands.size():
		bands[i] = bands[i] + step
	## 画面外（下側）へ出た帯を削除。
	var write := 0
	for center in bands:
		if center - half <= hi + 1.0:
			bands[write] = center
			write += 1
	bands.resize(write)
	if bands.is_empty():
		seed_bands(bands, area)
		return
	## 上側が空いたら、ひとつずつ新しい帯を生成。
	var entry := lo - half
	bands.sort()
	while bands[0] >= entry + period - 0.01:
		bands.insert(0, bands[0] - period)


static func draw_flowing_bands(item: CanvasItem, area: Vector2, color: Color, bands: Array[float]) -> void:
	var metrics := band_metrics(area)
	if metrics.is_empty() or bands.is_empty():
		return
	var normal: Vector2 = metrics.normal
	var corners: PackedVector2Array = metrics.corners
	var half: float = metrics.half
	for center in bands:
		var poly := clip_strip(corners, normal, center + half, center - half)
		if poly.size() >= 3:
			item.draw_colored_polygon(poly, color)


## 互換: 静止の2帯（旧クリア帯）。流れ描画へ寄せたい場合は draw_flowing_bands を使う。
static func draw_diagonal_color_bands(item: CanvasItem, area: Vector2, color: Color) -> void:
	var metrics := band_metrics(area)
	if metrics.is_empty():
		return
	var lo: float = metrics.lo
	var hi: float = metrics.hi
	var span: float = metrics.span
	var period: float = metrics.period
	var half: float = metrics.half
	var bands: Array[float] = []
	var center := lo + half
	while center <= hi:
		bands.append(center)
		center += period * 2.0
	draw_flowing_bands(item, area, color, bands)


static func clip_strip(subject: PackedVector2Array, normal: Vector2, high_limit: float, low_limit: float) -> PackedVector2Array:
	var below := clip_halfplane(subject, normal, high_limit, true)
	return clip_halfplane(below, normal, low_limit, false)


static func clip_halfplane(subject: PackedVector2Array, normal: Vector2, limit: float, keep_below: bool) -> PackedVector2Array:
	var output := PackedVector2Array()
	if subject.size() < 3:
		return output
	var previous: Vector2 = subject[subject.size() - 1]
	var previous_inside := inside_halfplane(previous, normal, limit, keep_below)
	for current in subject:
		var current_inside := inside_halfplane(current, normal, limit, keep_below)
		if current_inside:
			if not previous_inside:
				output.append(cross_halfplane(previous, current, normal, limit))
			output.append(current)
		elif previous_inside:
			output.append(cross_halfplane(previous, current, normal, limit))
		previous = current
		previous_inside = current_inside
	return output


static func inside_halfplane(point: Vector2, normal: Vector2, limit: float, keep_below: bool) -> bool:
	var signed := point.dot(normal)
	if keep_below:
		return signed <= limit + 0.5
	return signed >= limit - 0.5


static func cross_halfplane(start: Vector2, finish: Vector2, normal: Vector2, limit: float) -> Vector2:
	var start_signed := start.dot(normal) - limit
	var finish_signed := finish.dot(normal) - limit
	var span := start_signed - finish_signed
	if absf(span) < 0.0001:
		return finish
	return start.lerp(finish, start_signed / span)
