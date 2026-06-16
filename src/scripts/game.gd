extends Node3D

const INCOME_FEEDBACK_DURATION := 2.0
const ACTION_COLUMN_HEIGHT := 112
const CAMERA_TWEEN_DURATION := 0.45

@onready var camera: Camera3D = $Camera3D
@onready var board: BoardController = $Board
@onready var units_root: Node3D = $Units
@onready var session: GameSession = $GameSession
@onready var input_handler: GameInputHandler = $GameInputHandler
@onready var drag_controller: UnitDragController = $UnitDragController
@onready var event_log: EventLog = $EventLog

@onready var round_label: Label = $CanvasLayer/UI/TopBar/RoundLabel
@onready var board_label: Label = $CanvasLayer/UI/TopBar/BoardLabel
@onready var bench_label: Label = $CanvasLayer/UI/TopBar/BenchLabel
@onready var coin_label: Label = $CanvasLayer/UI/BottomUI/CoinLabel
@onready var exp_status_label: Label = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpStatusLabel
@onready var shop_slots: HBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel/ShopSlots
@onready var bottom_ui: Control = $CanvasLayer/UI/BottomUI
@onready var bottom_bar: HBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar
@onready var shop_panel: VBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel
@onready var action_column: VBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn
@onready var reroll_button: Button = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/RerollButton
@onready var exp_button: Button = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpButton
@onready var battle_button: Button = $CanvasLayer/UI/TopBar/BattleButton
@onready var back_button: Button = $CanvasLayer/UI/TopBar/BackButton
@onready var sell_drag_hint_left: PanelContainer = $CanvasLayer/UI/SellDragHintLeft
@onready var sell_drag_hint_right: PanelContainer = $CanvasLayer/UI/SellDragHintRight
@onready var battle_overlay: PanelContainer = $CanvasLayer/UI/BattleOverlay
@onready var income_overlay: PanelContainer = $CanvasLayer/UI/IncomeOverlay
@onready var extension_overlay: PanelContainer = $CanvasLayer/UI/ExtensionOverlay
@onready var route_overlay: PanelContainer = $CanvasLayer/UI/RouteOverlay
@onready var synergy_panel: PanelContainer = $CanvasLayer/UI/SynergyPanel
@onready var prep_blocker: Control = $CanvasLayer/UI/PrepBlocker
@onready var event_log_label: RichTextLabel = $CanvasLayer/UI/EventLogPanel/EventLogVBox/ScrollContainer/EventLogLabel
@onready var continue_button: Button = $CanvasLayer/UI/ExtensionOverlay/ExtensionVBox/ContinueButton
@onready var end_run_button: Button = $CanvasLayer/UI/ExtensionOverlay/ExtensionVBox/EndRunButton
@onready var route_buttons: Array[Button] = [
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton0,
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton1,
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton2,
]
@onready var route_title_label: Label = $CanvasLayer/UI/RouteOverlay/RouteVBox/RouteTitle
@onready var synergy_label: RichTextLabel = $CanvasLayer/UI/SynergyPanel/SynergyVBox/SynergyLabel


func _ready() -> void:
	shop_slots.custom_minimum_size.y = ACTION_COLUMN_HEIGHT
	_setup_camera()
	drag_controller.setup(camera, board, _get_sell_zone_side)
	input_handler.action_triggered.connect(_on_action)
	drag_controller.sell_requested.connect(_on_sell_requested)
	drag_controller.drag_state_changed.connect(_on_drag_state_changed)
	session.state_changed.connect(_update_ui)
	board.merges_applied.connect(_on_merges_applied)
	board.units_changed.connect(_update_synergy_panel)
	event_log.message_added.connect(_refresh_event_log)
	session.extension_choice_required.connect(_on_extension_choice_required)
	session.route_choice_required.connect(_on_route_choice_required)
	session.run_completed.connect(_on_run_completed)
	reroll_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.REROLL)))
	exp_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.BUY_EXP)))
	battle_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.START_BATTLE)))
	back_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.GO_BACK)))
	continue_button.pressed.connect(_on_continue_extension)
	end_run_button.pressed.connect(_on_end_run)
	for index in route_buttons.size():
		route_buttons[index].pressed.connect(func() -> void: _on_route_selected(index))
	for index in shop_slots.get_child_count():
		var slot_button: Button = shop_slots.get_child(index) as Button
		slot_button.pressed.connect(func() -> void: _on_action(GameAction.shop_buy(index)))
	_log("準備フェーズ開始")
	_update_ui()


func _setup_camera() -> void:
	var framing := board.get_prep_framing()
	var focus: Vector3 = framing["focus"]
	camera.global_position = board.compute_prep_camera_position(
		focus,
		float(framing["horizontal_half"]),
		float(framing["vertical_half"]),
		camera.fov,
		_get_camera_aspect()
	)
	camera.look_at(focus, Vector3.UP)


func _get_camera_aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)


func _get_prep_camera_position() -> Vector3:
	var framing := board.get_prep_framing()
	return board.compute_prep_camera_position(
		framing["focus"],
		float(framing["horizontal_half"]),
		float(framing["vertical_half"]),
		camera.fov,
		_get_camera_aspect()
	)


func _log(text: String) -> void:
	event_log.add(text)


func _refresh_event_log(_text: String = "") -> void:
	event_log_label.text = event_log.get_display_text()
	call_deferred("_scroll_event_log_to_bottom")


func _scroll_event_log_to_bottom() -> void:
	var scroll: ScrollContainer = event_log_label.get_parent()
	if scroll.get_v_scroll_bar():
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _on_action(action: GameAction) -> void:
	if session.phase == GameSession.Phase.EXTENSION_CHOICE:
		return
	if session.phase == GameSession.Phase.ROUTE_CHOICE:
		return
	match action.type:
		GameAction.Type.DRAG_PRESS:
			if session.is_prep():
				drag_controller.handle_drag_press(action.screen_position)
		GameAction.Type.DRAG_MOVE:
			if session.is_prep() and drag_controller.is_dragging():
				drag_controller.handle_drag_move(action.screen_position)
		GameAction.Type.DRAG_RELEASE:
			if session.is_prep():
				drag_controller.handle_drag_release(action.screen_position, _shop_ui_blocks_drop)
				_update_ui()
		GameAction.Type.SHOP_BUY:
			_buy_from_shop(action.shop_slot)
		GameAction.Type.REROLL:
			if session.try_reroll():
				_log("ショップを更新した")
		GameAction.Type.BUY_EXP:
			if session.try_buy_exp():
				_log("経験値を購入した (+%d)" % GameSession.EXP_GAIN)
		GameAction.Type.START_BATTLE:
			_start_battle()
		GameAction.Type.GO_BACK:
			get_tree().change_scene_to_file("res://scenes/title.tscn")


func _buy_from_shop(slot_index: int) -> void:
	var unit_id := session.try_buy_shop_slot(slot_index, board.bench_is_full())
	if unit_id < 0:
		return
	var data := UnitCatalog.get_unit(unit_id)
	var unit := GameUnit.create(unit_id, 1)
	units_root.add_child(unit)
	board.place_on_bench(unit, board.find_empty_bench_slot())
	_log("%s ★ を購入した (%d コイン)" % [data["name"], data["cost"]])


func _start_battle() -> void:
	if not session.is_prep():
		return
	_log("戦闘開始 (ラウンド %d)" % session.round_number)
	session.start_battle()
	input_handler.set_enabled(false)
	prep_blocker.visible = true
	battle_overlay.visible = true
	shop_panel.visible = false
	coin_label.visible = false
	board.set_battle_mode(true)
	await _animate_camera(true)
	_update_ui()
	await get_tree().create_timer(session.get_battle_duration()).timeout
	session.finish_battle(true)
	_log("戦闘終了 (経験値 +%d)" % GameSession.ROUND_END_FREE_XP)
	board.set_battle_mode(false)
	await _animate_camera(false)
	battle_overlay.visible = false
	if session.phase == GameSession.Phase.EXTENSION_CHOICE:
		input_handler.set_enabled(false)
		prep_blocker.visible = true
		_update_ui()
		return
	if session.phase == GameSession.Phase.ROUTE_CHOICE:
		prep_blocker.visible = true
		input_handler.set_enabled(false)
		shop_panel.visible = false
		coin_label.visible = false
		_show_route_choice()
		_update_ui()
		return
	prep_blocker.visible = false
	shop_panel.visible = true
	coin_label.visible = true
	if session.phase == GameSession.Phase.PREP:
		_log("ラウンド %d 開始" % session.round_number)
		if not session.last_income_breakdown.is_empty():
			_show_income_feedback()
	input_handler.set_enabled(session.is_prep())
	_update_ui()


func _animate_camera(to_battle: bool) -> void:
	var focus: Vector3
	var target_pos: Vector3
	if to_battle:
		focus = board.get_camera_focus_battle()
		target_pos = board.compute_camera_position(focus, board.get_battle_board_span(), camera.fov)
	else:
		focus = board.get_camera_focus_prep()
		target_pos = _get_prep_camera_position()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_pos, CAMERA_TWEEN_DURATION)
	await tween.finished
	camera.look_at(focus, Vector3.UP)


func _on_extension_choice_required() -> void:
	extension_overlay.visible = true
	prep_blocker.visible = true
	_log("20ラウンド達成。延長するか選択")


func _on_continue_extension() -> void:
	extension_overlay.visible = false
	session.choose_extension(true)
	_log("延長モード (+5ラウンド) を選択")
	_show_route_choice()
	_update_ui()


func _on_route_choice_required() -> void:
	pass


func _show_route_choice() -> void:
	route_title_label.text = "ラウンド %d — ルートを選択" % session.round_number
	for index in route_buttons.size():
		if index >= session.route_options.size():
			route_buttons[index].visible = false
			continue
		var option: Dictionary = session.route_options[index]
		route_buttons[index].visible = true
		route_buttons[index].text = "%s\n%s\n%s" % [
			option["strength_label"],
			option["enemy_label"],
			option["reward_label"],
		]
	route_overlay.visible = true
	prep_blocker.visible = true
	input_handler.set_enabled(false)


func _on_route_selected(index: int) -> void:
	var route := session.select_route(index)
	if route.is_empty():
		return
	route_overlay.visible = false
	prep_blocker.visible = false
	shop_panel.visible = true
	coin_label.visible = true
	_log("ルート選択: %s (%s)" % [
		RouteChoice.format_option(route),
		route["strength_label"],
	])
	match route["reward_type"]:
		"gold":
			_log("報酬: ゴールド +%d" % RouteChoice.get_gold_reward(route["strength"]))
		"reroll":
			_log("報酬: 無料更新を獲得")
		"augment":
			_log("報酬: オーグメント (仮)")
		"equipment":
			_log("報酬: 装備 (仮)")
	_log("ラウンド %d 開始" % session.round_number)
	_show_income_feedback()
	input_handler.set_enabled(true)
	_update_ui()


func _on_end_run() -> void:
	extension_overlay.visible = false
	prep_blocker.visible = false
	_log("ランを終了した")
	session.choose_extension(false)


func _on_run_completed() -> void:
	input_handler.set_enabled(false)
	prep_blocker.visible = true
	battle_overlay.visible = true
	battle_overlay.get_node("BattleLabel").text = "クリア"
	_log("ゲームクリア")
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_sell_requested(unit: GameUnit) -> void:
	var name := unit.get_display_name()
	var stars := unit.get_star_text()
	var refund := unit.get_cost()
	session.add_sell_income(refund)
	board.remove_unit(unit)
	unit.queue_free()
	_log("%s %s を売却した (+%d)" % [name, stars, refund])


func _on_merges_applied(messages: Array[String]) -> void:
	for message in messages:
		_log("合成: %s" % message)


func _show_income_feedback() -> void:
	var breakdown: Dictionary = session.last_income_breakdown
	if breakdown.is_empty():
		return
	var label: Label = income_overlay.get_node("IncomeLabel")
	label.text = "収入 +%d\n(基本 %d / 所持 %d / 連勝敗 %d)" % [
		breakdown["total"],
		breakdown["base"],
		breakdown["holding"],
		breakdown["streak"],
	]
	income_overlay.visible = true
	_log("収入 +%d (基本 %d / 所持 %d / 連勝 %d)" % [
		breakdown["total"], breakdown["base"], breakdown["holding"], breakdown["streak"]
	])
	await get_tree().create_timer(INCOME_FEEDBACK_DURATION).timeout
	income_overlay.visible = false


func _on_drag_state_changed(is_dragging: bool, sell_zone_side: int) -> void:
	sell_drag_hint_left.visible = is_dragging
	sell_drag_hint_right.visible = is_dragging
	if not is_dragging:
		return
	var left_zone := _get_left_sell_zone_rect()
	var right_zone := _get_right_sell_zone_rect()
	sell_drag_hint_left.global_position = left_zone.position
	sell_drag_hint_left.size = left_zone.size
	sell_drag_hint_right.global_position = right_zone.position
	sell_drag_hint_right.size = right_zone.size
	var active_color := Color(1.0, 0.55, 0.55, 1.0)
	var idle_color := Color(1.0, 1.0, 1.0, 0.55)
	sell_drag_hint_left.modulate = active_color if sell_zone_side == 0 else idle_color
	sell_drag_hint_right.modulate = active_color if sell_zone_side == 1 else idle_color


func _get_left_sell_zone_rect() -> Rect2:
	var action_rect := action_column.get_global_rect()
	return Rect2(
		Vector2(0.0, action_rect.position.y),
		Vector2(action_rect.position.x, action_rect.size.y)
	)


func _get_right_sell_zone_rect() -> Rect2:
	var shop_rect := shop_panel.get_global_rect()
	var viewport_width := get_viewport().get_visible_rect().size.x
	return Rect2(
		Vector2(shop_rect.end.x, shop_rect.position.y),
		Vector2(viewport_width - shop_rect.end.x, shop_rect.size.y)
	)


func _get_sell_zone_side(screen_pos: Vector2) -> int:
	if _get_left_sell_zone_rect().has_point(screen_pos):
		return 0
	if _get_right_sell_zone_rect().has_point(screen_pos):
		return 1
	return -1


func _shop_ui_blocks_drop(screen_pos: Vector2) -> bool:
	if _get_sell_zone_side(screen_pos) >= 0:
		return false
	var action_rect := action_column.get_global_rect()
	if action_rect.has_point(screen_pos):
		return true
	return shop_panel.get_global_rect().has_point(screen_pos)


func _update_synergy_panel() -> void:
	var active := SynergyTracker.get_active_synergies(board.get_all_units())
	if active.is_empty():
		synergy_label.text = "発動中なし"
		return
	var lines: PackedStringArray = []
	for entry in active:
		var next_threshold := SynergyCatalog.TIERS[entry["tier"] - 1] if entry["tier"] > 0 else 2
		var next_text := ""
		if entry["tier"] < SynergyCatalog.TIERS.size():
			next_text = " → 次 %d" % SynergyCatalog.TIERS[entry["tier"]]
		lines.append("%s Lv.%d (%d/%d)%s" % [
			entry["name"], entry["tier"], entry["count"], next_threshold, next_text
		])
	synergy_label.text = "\n".join(lines)


func _update_ui() -> void:
	board.board_unit_limit = session.get_board_unit_cap()
	coin_label.text = "コイン: %d" % session.coins
	var level := session.get_level()
	var xp_into := PlayerLevel.get_xp_into_current_level(session.experience)
	var xp_need := PlayerLevel.get_xp_needed_for_next_level(level)
	if xp_need > 0:
		exp_status_label.text = "Lv.%d  経験値 %d/%d" % [level, xp_into, xp_need]
	else:
		exp_status_label.text = "Lv.%d  経験値 MAX" % level
	var round_cap := session.max_round
	round_label.text = "ラウンド: %d / %d" % [mini(session.round_number, round_cap), round_cap]
	board_label.text = "盤面: %d / %d" % [board.get_board_unit_count(), session.get_board_unit_cap()]
	var bench_count := 0
	for slot in board.bench_units:
		if slot != null:
			bench_count += 1
	bench_label.text = "ベンチ: %d / %d" % [bench_count, HexMath.BENCH_SIZE]
	reroll_button.text = "更新 (%d)" % GameSession.REROLL_COST
	if session.free_rerolls > 0:
		reroll_button.text = "更新 (無料×%d)" % session.free_rerolls
	reroll_button.disabled = not session.is_prep() or (
		session.free_rerolls <= 0 and session.coins < GameSession.REROLL_COST
	)
	exp_button.text = "経験値+%d\n(%d)" % [GameSession.EXP_GAIN, GameSession.EXP_COST]
	exp_button.disabled = not session.is_prep() or session.coins < GameSession.EXP_COST
	battle_button.disabled = not session.is_prep()
	input_handler.set_enabled(session.is_prep())
	shop_panel.visible = session.is_prep()
	coin_label.visible = session.is_prep()
	for index in shop_slots.get_child_count():
		var slot_button: Button = shop_slots.get_child(index) as Button
		if index >= session.shop_unit_ids.size() or session.shop_unit_ids[index] < 0:
			slot_button.text = "売り切れ"
			slot_button.disabled = true
			continue
		var unit_id: int = session.shop_unit_ids[index]
		var data := UnitCatalog.get_unit(unit_id)
		var synergy_text := UnitCatalog.get_synergy_names(unit_id)
		slot_button.text = "%s ★\n%d コイン\n%s" % [data["name"], data["cost"], synergy_text]
		var cost: int = data["cost"]
		slot_button.disabled = not session.is_prep() or session.coins < cost or board.bench_is_full()
	_update_synergy_panel()
