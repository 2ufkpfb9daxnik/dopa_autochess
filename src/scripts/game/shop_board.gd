class_name ShopBoard
extends RefCounted

const COLUMNS := 3
const SLOT_WIDTH := 132
const SLOT_HEIGHT := 148
const LAYOUT_SLOT_WIDTH := 112.0
const FRAME_ASPECT := 1024.0 / 1536.0
const HOVER_SCALE := 2.1
const SELL_ZONE_WIDTH := 72.0
const SLOT_SCENE := preload("res://scenes/shop_slot.tscn")

var slot_size := Vector2(SLOT_WIDTH, SLOT_HEIGHT)

var _host: Node
var _zoomed := false
var _display_scale := 1.0
var _rest_origin := Vector2.ZERO
var _rest_size := Vector2.ZERO
var _layout_position := Vector2.ZERO
var _layout_position_ready := false
var _placed_area := Rect2()
var _has_placed := false
var _hover_suspended := false
var _modal_blocked := false
var _capture_serial := 0
var _zoom_tween: Tween


func setup(host: Node) -> void:
	_host = host
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var parent: Node = _host.shop_slots.get_parent()
	var slot_index: int = _host.shop_slots.get_index()
	parent.add_child(grid)
	parent.move_child(grid, slot_index)
	_host.shop_slots.queue_free()
	_host.shop_slots = grid
	for index in GameSession.SHOP_SIZE:
		var slot := SLOT_SCENE.instantiate() as ShopSlotPanel
		if slot == null:
			push_error("ShopSlotPanel の生成に失敗しました")
			continue
		slot.pressed.connect(func() -> void:
			_host._on_action(GameAction.shop_buy(index))
		)
		_host.shop_slots.add_child(slot)
		slot.set_card_size(slot_size)


func panel_width() -> float:
	return float(COLUMNS) * slot_size.x + float(COLUMNS - 1) * 8.0


func setup_odds_table() -> void:
	_host.shop_odds_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _host.shop_odds_badge.gui_input.is_connected(_on_badge_gui_input):
		_host.shop_odds_badge.gui_input.connect(_on_badge_gui_input)
	_host._apply_hud_badge_style(_host.shop_odds_tooltip)
	_host.shop_odds_tooltip.z_index = 28
	_host.shop_odds_tooltip.visible = false


func hide_odds_table() -> void:
	_host.shop_odds_tooltip.visible = false


func fit_badge_width() -> void:
	_host.shop_odds_badge.custom_minimum_size.x = 0
	_host._position_coin_row_over_shop()


func place(area: Rect2) -> void:
	var shop_h := maxf(80.0, area.size.y)
	var gap := 2.0
	var slot_h := maxf(96.0, (shop_h - gap) / 2.0)
	var slot_w := slot_h * FRAME_ASPECT
	var max_w := maxf(72.0, (area.size.x - gap * float(COLUMNS - 1)) / float(COLUMNS))
	if slot_w > max_w:
		slot_w = max_w
		slot_h = slot_w / FRAME_ASPECT
	var next_slot := Vector2(slot_w, slot_h)
	if _has_placed and _placed_area.is_equal_approx(area) and slot_size.is_equal_approx(next_slot):
		return
	slot_size = next_slot
	_placed_area = area
	_has_placed = true
	_cancel_zoom_for_layout()
	for child in _host.shop_slots.get_children():
		var slot := child as ShopSlotPanel
		if slot != null:
			slot.set_card_size(slot_size)
			slot.set_text_scale(1.0)
	var grid_size := Vector2(
		slot_w * float(COLUMNS) + gap * float(COLUMNS - 1),
		slot_h * 2.0 + gap
	)
	_host.shop_slots.custom_minimum_size = grid_size
	_host.shop_slots.size = grid_size
	_host.shop_panel.custom_minimum_size.x = panel_width()
	_host.bottom_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_host.bottom_ui.offset_left = area.position.x
	_host.bottom_ui.offset_top = area.position.y
	_host.bottom_ui.offset_right = area.end.x
	_host.bottom_ui.offset_bottom = area.end.y
	_host.call_deferred("_position_coin_row_over_shop")
	_schedule_rest_capture()


func set_modal_blocked(blocked: bool) -> void:
	_modal_blocked = blocked
	if blocked:
		_cancel_zoom_for_layout()
	else:
		_hover_suspended = false
	_apply_slot_mouse_filter(not blocked)


func update_hover() -> void:
	if _modal_blocked or _hover_suspended or _host.shop_slots == null or _host.shop_panel == null or not _host.shop_panel.visible or _rest_size.x < 2.0:
		return
	var mouse: Vector2 = _host.get_viewport().get_mouse_position()
	var inside_rest: bool = _scaled_rect(1.0).grow(8.0).has_point(mouse)
	var inside_zoom: bool = _scaled_rect(HOVER_SCALE).grow(16.0).has_point(mouse)
	var zoom: bool = inside_zoom if _zoomed else inside_rest
	if zoom == _zoomed:
		return
	_zoomed = zoom
	_tween_zoom(HOVER_SCALE if zoom else 1.0)


func _on_badge_gui_input(event: InputEvent) -> void:
	if _host._run_end_active or not _host.session.is_prep():
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _host.shop_odds_tooltip.visible:
		hide_odds_table()
	else:
		_show_odds_table()
	_host.get_viewport().set_input_as_handled()


func _show_odds_table() -> void:
	ShopOdds.populate_odds_grid(_host.shop_odds_grid, _host.session.get_level())
	_host.shop_odds_tooltip.visible = true
	_host.shop_odds_tooltip.move_to_front()
	call_deferred("_fit_tooltip_size")


func _fit_tooltip_size() -> void:
	_host.shop_odds_tooltip_vbox.reset_size()
	_host.shop_odds_grid.reset_size()
	await _host.get_tree().process_frame
	var content_size: Vector2 = _host.shop_odds_tooltip_vbox.get_minimum_size()
	var margins: Vector4 = _host._get_panel_content_margins(_host.shop_odds_tooltip)
	var fitted: Vector2 = content_size + Vector2(margins.x + margins.z, margins.y + margins.w)
	_host.shop_odds_tooltip.custom_minimum_size = fitted
	_host.shop_odds_tooltip.size = fitted
	_position_tooltip()


func _position_tooltip() -> void:
	var anchor_rect: Rect2 = _host.shop_odds_badge.get_global_rect()
	var tooltip_size: Vector2 = _host.shop_odds_tooltip.size
	var x: float = anchor_rect.position.x - tooltip_size.x - 6.0
	var y: float = anchor_rect.get_center().y - tooltip_size.y * 0.5
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	var max_x := maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)
	var max_y := maxf(8.0, viewport_size.y - tooltip_size.y - 8.0)
	x = clampf(x, 8.0, max_x)
	y = clampf(y, 8.0, max_y)
	_host.shop_odds_tooltip.global_position = Vector2(x, y)


func _cancel_zoom_for_layout() -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoomed = false
	_display_scale = 1.0
	_hover_suspended = true
	_restore_layout_placement()


func _restore_layout_placement() -> void:
	if _host.shop_slots == null:
		return
	_host.shop_slots.scale = Vector2.ONE
	_host.shop_slots.top_level = false
	_host.shop_slots.z_index = 0
	if _layout_position_ready:
		_host.shop_slots.position = _layout_position


func _schedule_rest_capture() -> void:
	_capture_serial += 1
	_capture_rest_rect(_capture_serial)


func _capture_rest_rect(serial: int) -> void:
	await _host.get_tree().process_frame
	if serial != _capture_serial or _host.shop_slots == null:
		return
	_restore_layout_placement()
	_rest_origin = _host.shop_slots.get_global_rect().position
	_rest_size = _host.shop_slots.size
	_layout_position = _host.shop_slots.position
	_layout_position_ready = true
	if not _modal_blocked:
		_hover_suspended = false


func _tween_zoom(shop_scale: float) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = _host.create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_apply_display_scale, _display_scale, shop_scale, 0.14)


func _apply_display_scale(amount: float) -> void:
	if _host.shop_slots == null or _rest_size.x < 2.0:
		return
	_display_scale = amount
	var zoomed := amount > 1.02
	_host.shop_slots.scale = Vector2.ONE
	var grid_size := _rest_size * amount
	if zoomed:
		if not _host.shop_slots.top_level:
			_layout_position = _host.shop_slots.position
			_layout_position_ready = true
		_host.shop_slots.top_level = true
		_host.shop_slots.z_index = 20
		_host.shop_slots.global_position = _rest_origin + Vector2(_rest_size.x * (1.0 - amount), 0.0)
		_host.shop_slots.size = grid_size
	else:
		_host.shop_slots.top_level = false
		_host.shop_slots.z_index = 0
		if _layout_position_ready:
			_host.shop_slots.position = _layout_position
		_host.shop_slots.size = _rest_size
	var gap := maxi(0, int(round(2.0 * amount)))
	_host.shop_slots.add_theme_constant_override("h_separation", gap)
	_host.shop_slots.add_theme_constant_override("v_separation", gap)
	var card := slot_size * amount
	for child in _host.shop_slots.get_children():
		var slot := child as ShopSlotPanel
		if slot == null:
			continue
		slot.set_card_size(card)
		slot.set_text_scale(amount)


func _apply_slot_mouse_filter(enabled: bool) -> void:
	if _host == null or _host.shop_slots == null:
		return
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_host.shop_slots.mouse_filter = filter
	for child in _host.shop_slots.get_children():
		var slot := child as Control
		if slot != null:
			slot.mouse_filter = filter


func _scaled_rect(shop_scale: float) -> Rect2:
	var origin := _rest_origin + Vector2(_rest_size.x * (1.0 - shop_scale), 0.0)
	return Rect2(origin, _rest_size * shop_scale)
