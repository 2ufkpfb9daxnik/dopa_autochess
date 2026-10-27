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
	if _host.board.get_unlocked_face_count() <= 1:
		center_text += "\nLv7で2面"
	_host._circle_wheel.set_view(center_text, _host.board.get_wheel_slots())
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
			})
	_host._bench_board.set_slots(bench_view)
	_host._action_order_bar.set_entries(_host.board.get_action_order())
	var can_edit: bool = _host.session.is_prep() and not _host._run_end_active
	var can_rotate: bool = not _host._run_end_active and (
		_host.session.is_prep() or _host.session.phase == GameSession.Phase.BATTLE
	)
	_host._circle_wheel.set_unit_drag_enabled(can_edit)
	_host._circle_wheel.set_interaction_enabled(can_rotate)
	_host._bench_board.set_input_enabled(can_edit)


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


func on_circle_slot_move(from_slot: int, to_slot: int) -> void:
	var unit: GameUnit = _host.board.get_placed_unit(_host.board.active_face, from_slot)
	if unit == null:
		return
	if not _host.board.try_move_unit_to_circle(unit, _host.board.active_face, to_slot):
		_host._log("そこには配置できません")


func on_bench_slot_clicked(slot_index: int) -> void:
	if not _host.session.is_prep() or _host._run_end_active:
		return
	var unit: GameUnit = _host.board.bench_units[slot_index]
	if unit == null:
		return
	GameAudio.play_select_character()
	var dest: int = _host.board.find_empty_circle_slot(_host.board.active_face)
	if dest < 0:
		_host._log("この面は満員です")
		return
	if not _host.board.try_move_unit_to_circle(unit, _host.board.active_face, dest):
		_host._log("配置上限です")


func begin_drag(unit: GameUnit) -> void:
	_dragging_unit = unit
	GameAudio.play_select_character()
	var cost := unit.get_cost()
	var label_color := CostColors.get_shop_label_color(cost)
	_host._drag_bar.color = CostColors.get_color(cost)
	_host._drag_cost_label.text = str(cost)
	_host._drag_name_label.text = unit.get_display_name()
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
		if not _host.board.try_move_unit_to_circle(unit, _host.board.active_face, circle_slot):
			_host._log("配置上限です")
		return
	var bench_slot: int = _host._bench_board.slot_index_at_global(global_position)
	if bench_slot >= 0:
		_host.board.try_move_unit_to_bench(unit, bench_slot)
		return
	if _host._get_sell_zone_side(global_position) >= 0:
		_host._on_sell_requested(unit)


func unit_under_screen(screen_position: Vector2) -> GameUnit:
	if _host._circle_wheel == null:
		return null
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
