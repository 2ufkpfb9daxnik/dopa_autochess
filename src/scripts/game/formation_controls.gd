class_name FormationControls
extends RefCounted

var _host: Node
var _dragging_unit: GameUnit


func setup(host: Node) -> void:
	_host = host


func is_dragging() -> bool:
	return _dragging_unit != null


func refresh_widgets() -> void:
	if _host._circle_wheel == null:
		return
	_host.board.board_unit_limit = _host.session.get_board_unit_cap()
	_host.board.set_unlocked_face_count(BoardController.unlocked_face_count_for_level(_host.session.get_level()))
	var center_text := "%d面\n%d/%d" % [
		_host.board.active_face + 1,
		_host.board.get_board_unit_count(),
		_host.session.get_board_unit_cap(),
	]
	if _host.session.get_level() >= 7:
		center_text += "\n[font_size=22][color=#ffcf4a]面の移動！[/color][/font_size]"
	var wheel_slots: Array = _host.board.get_wheel_slots()
	for slot_index in wheel_slots.size():
		var shown: GameUnit = _host.board.get_placed_unit(_host.board.active_face, slot_index)
		if shown == null:
			shown = _host.board.get_resolved_unit(_host.board.active_face, slot_index)
		wheel_slots[slot_index]["relic_ids"] = _relic_ids_on(shown)
	_host._circle_wheel.set_view(center_text, wheel_slots)
	var bench_view: Array = []
	for slot in _host.board.bench_units:
		var unit := slot as GameUnit
		if unit == null:
			bench_view.append({"occupied": false})
		else:
			bench_view.append({
				"occupied": true,
				"name": unit.get_display_name(),
				"stars": unit.get_star_text(),
				"cost": unit.get_cost(),
				"unit_id": unit.unit_id,
				"relic_ids": _relic_ids_on(unit),
			})
	_host._bench_board.set_slots(bench_view)
	if _host._overflow_pile != null:
		_host._overflow_pile.set_units(_host.board.get_overflow_units())
	_host._action_order_bar.set_entries(_host.board.get_action_order())
	var can_edit: bool = _host.session.is_prep() and not _host._run_end_active
	var can_rotate: bool = not _host._run_end_active and (
		_host.session.is_prep() or _host.session.phase == GameSession.Phase.BATTLE
	)
	_host._circle_wheel.set_unit_drag_enabled(can_edit)
	_host._circle_wheel.set_interaction_enabled(can_rotate)
	_host._circle_wheel.set_cleanse_enabled(_host.session.phase == GameSession.Phase.BATTLE)
	_host._bench_board.set_input_enabled(can_edit)
	if _host._overflow_pile != null:
		_host._overflow_pile.set_input_enabled(can_edit)
	_refresh_relic_tray()


func _refresh_relic_tray() -> void:
	if _host._relic_tray == null:
		return
	var equipped := {}
	for unit in _host.board.get_all_units():
		var relic_unit := unit as GameUnit
		if relic_unit == null:
			continue
		for uid in relic_unit.equipped_relic_uids:
			equipped[uid] = true
	var loose: Array = []
	for item in _host.session.relics:
		if equipped.has(int(item.get("uid", -1))):
			continue
		loose.append(item)
	_host._relic_tray.set_entries(loose)


func _relic_ids_on(unit: GameUnit) -> Array:
	var ids: Array = []
	if unit == null:
		return ids
	for uid in unit.equipped_relic_uids:
		ids.append(_host.session.relic_id_of(int(uid)))
	return ids


func on_center_pressed() -> void:
	if _host._run_end_active or _host.session.phase == GameSession.Phase.ROUTE_CHOICE or _host.session.phase == GameSession.Phase.EXTENSION_CHOICE:
		return
	if _host.board.get_unlocked_face_count() <= 1:
		_host._log("2面はレベル7で開きます")
		return
	_host.board.cycle_face()
	_host._log("%d面を表示" % [_host.board.active_face + 1])


func on_circle_drag_started(slot_index: int) -> void:
	var unit: GameUnit = _host.board.get_placed_unit(_host.board.active_face, slot_index)
	if unit == null:
		return
	begin_drag(unit)


func on_bench_drag_started(slot_index: int) -> void:
	var unit: GameUnit = _host.board.bench_units[slot_index]
	if unit == null:
		return
	begin_drag(unit)


func on_circle_drag_finished(_slot_index: int, global_position: Vector2) -> void:
	finish_drag(global_position)


func on_bench_drag_finished(_slot_index: int, global_position: Vector2) -> void:
	finish_drag(global_position)


func on_circle_unit_clicked(slot_index: int) -> void:
	var unit: GameUnit = _host.board.get_placed_unit(_host.board.active_face, slot_index)
	if unit == null:
		unit = _host.board.get_resolved_unit(_host.board.active_face, slot_index)
	if unit == null or _host._unit_inspect == null:
		return
	_host._unit_inspect.open_unit(unit.unit_id, unit.stars, _host.get_viewport().get_mouse_position(), _relic_ids_on(unit))


func on_circle_slot_move(from_slot: int, to_slot: int) -> void:
	var unit: GameUnit = _host.board.get_placed_unit(_host.board.active_face, from_slot)
	if unit == null:
		return
	var dest_empty := _host.board.get_placed_unit(_host.board.active_face, to_slot) == null
	if dest_empty and _host.board.would_exceed_board_limit(unit):
		_host._show_board_notice(_host.NOTICE_CIRCLE_CAP)
		return
	if not _host.board.try_move_unit_to_circle(unit, _host.board.active_face, to_slot):
		if _host.board.would_exceed_board_limit(unit):
			_host._show_board_notice(_host.NOTICE_CIRCLE_CAP)
		else:
			_host._log("そこには配置できません")


func on_bench_slot_clicked(slot_index: int) -> void:
	var unit: GameUnit = _host.board.bench_units[slot_index]
	if unit == null or _host._unit_inspect == null:
		return
	_host._unit_inspect.open_unit(unit.unit_id, unit.stars, _host.get_viewport().get_mouse_position(), _relic_ids_on(unit))


func on_overflow_drag_started(index: int) -> void:
	var unit: GameUnit = _host._overflow_pile.unit_at(index)
	if unit == null:
		return
	begin_drag(unit)


func on_overflow_drag_finished(_index: int, global_position: Vector2) -> void:
	finish_drag(global_position)


func on_overflow_clicked(index: int) -> void:
	var unit: GameUnit = _host._overflow_pile.unit_at(index)
	if unit == null or _host._unit_inspect == null:
		return
	_host._unit_inspect.open_unit(unit.unit_id, unit.stars, _host.get_viewport().get_mouse_position(), _relic_ids_on(unit))


func begin_drag(unit: GameUnit) -> void:
	_dragging_unit = unit
	GameAudio.play_select_character()
	var cost := unit.get_cost()
	var label_color := CostColors.get_shop_label_color(cost)
	_host._drag_bar.color = CostColors.get_color(cost)
	_host._drag_cost_label.text = str(cost)
	_host._drag_name_label.text = unit.get_display_name()
	var drag_icon := _host._drag_preview.get_node_or_null("DragIcon") as TextureRect
	if drag_icon != null:
		drag_icon.texture = UnitCatalog.make_portrait(unit.unit_id, drag_icon.size)
	_host._drag_stars_label.text = unit.get_star_text()
	_host._drag_cost_label.add_theme_color_override("font_color", label_color)
	_host._drag_name_label.add_theme_color_override("font_color", label_color)
	_host._drag_preview.visible = true
	_host._drag_preview.global_position = _host.get_viewport().get_mouse_position() - _host._drag_preview.size * 0.5
	_host._on_drag_state_changed(true, -1)


func finish_drag(global_position: Vector2) -> void:
	var unit := _dragging_unit
	_dragging_unit = null
	_host._drag_preview.visible = false
	_host._on_drag_state_changed(false, -1)
	if unit == null or not is_instance_valid(unit) or not _host.session.is_prep():
		return
	var circle_slot: int = _host._circle_wheel.slot_index_at_global(global_position)
	if circle_slot >= 0:
		var dest_empty := _host.board.get_placed_unit(_host.board.active_face, circle_slot) == null
		if dest_empty and _host.board.would_exceed_board_limit(unit):
			_host._show_board_notice(_host.NOTICE_CIRCLE_CAP)
			return
		if not _host.board.try_move_unit_to_circle(unit, _host.board.active_face, circle_slot):
			if _host.board.would_exceed_board_limit(unit):
				_host._show_board_notice(_host.NOTICE_CIRCLE_CAP)
		_host._refresh_overflow_notice()
		return
	var bench_slot: int = _host._bench_board.slot_index_at_global(global_position)
	if bench_slot >= 0:
		_host.board.try_move_unit_to_bench(unit, bench_slot)
		_host.board.try_absorb_overflow()
		_host._refresh_overflow_notice()
		return
	if _host._get_sell_zone_side(global_position) >= 0:
		_host._on_sell_requested(unit)


func unit_under_screen(screen_position: Vector2) -> GameUnit:
	if _host._circle_wheel == null:
		return null
	if _host._overflow_pile != null:
		var overflow_index: int = _host._overflow_pile.index_at_global(screen_position)
		if overflow_index >= 0:
			return _host._overflow_pile.unit_at(overflow_index)
	var circle_slot: int = _host._circle_wheel.slot_index_at_global(screen_position)
	if circle_slot >= 0:
		return _host.board.get_placed_unit(_host.board.active_face, circle_slot)
	var bench_slot: int = _host._bench_board.slot_index_at_global(screen_position)
	if bench_slot >= 0:
		return _host.board.bench_units[bench_slot]
	return null


func handle_mouse_motion(event: InputEvent) -> void:
	if _dragging_unit == null or not (event is InputEventMouseMotion):
		return
	var motion := event as InputEventMouseMotion
	_host._drag_preview.global_position = motion.global_position - _host._drag_preview.size * 0.5
	_host._on_drag_state_changed(true, _host._get_sell_zone_side(motion.global_position))
