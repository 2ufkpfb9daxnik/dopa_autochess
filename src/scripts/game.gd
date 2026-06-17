extends Node3D

const INCOME_FEEDBACK_DURATION := 2.0
const ACTION_COLUMN_HEIGHT := 112
const CAMERA_TWEEN_DURATION := 0.55

const LOG_COLLAPSED_TOP := 56.0
const LOG_COLLAPSED_BOTTOM := 280.0
const LOG_EXPANDED_BOTTOM_MARGIN := 168.0
const SYNERGY_PANEL_NORMAL_BOTTOM := 520.0

enum RunReviewMode { MENU, BOARD, SYNERGY, LOG, STATS }

var _camera_tween_start: Transform3D
var _camera_tween_end: Transform3D
var _log_expanded := false
var _log_scroll_position := 0
var _run_end_active := false
var _run_review_mode := RunReviewMode.MENU

@onready var camera: Camera3D = $Camera3D
@onready var board: BoardController = $Board
@onready var units_root: Node3D = $Units
@onready var session: GameSession = $GameSession
@onready var input_handler: GameInputHandler = $GameInputHandler
@onready var drag_controller: UnitDragController = $UnitDragController
@onready var event_log: EventLog = $EventLog

@onready var round_label: Label = $CanvasLayer/UI/TopBar/RoundLabel
@onready var hp_label: Label = $CanvasLayer/UI/TopBar/HpLabel
@onready var board_label: Label = $CanvasLayer/UI/TopBar/BoardLabel
@onready var bench_label: Label = $CanvasLayer/UI/TopBar/BenchLabel
@onready var coin_label: Label = $CanvasLayer/UI/BottomUI/CoinLabel
@onready var exp_status_label: Label = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpStatusLabel
@onready var shop_odds_tooltip: PanelContainer = $CanvasLayer/UI/ShopOddsTooltip
@onready var shop_odds_grid: GridContainer = $CanvasLayer/UI/ShopOddsTooltip/ShopOddsTooltipVBox/ShopOddsGrid
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
@onready var run_end_overlay: PanelContainer = $CanvasLayer/UI/RunEndOverlay
@onready var run_end_title: Label = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/RunEndTitle
@onready var run_end_summary: Label = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/RunEndSummary
@onready var run_end_review_bar: PanelContainer = $CanvasLayer/UI/RunEndReviewBar
@onready var review_bar_label: Label = $CanvasLayer/UI/RunEndReviewBar/RunEndReviewHBox/ReviewBarLabel
@onready var run_stats_panel: PanelContainer = $CanvasLayer/UI/RunStatsPanel
@onready var run_stats_label: Label = $CanvasLayer/UI/RunStatsPanel/RunStatsVBox/RunStatsScroll/RunStatsLabel
@onready var review_board_button: Button = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/ReviewButtons/ReviewBoardButton
@onready var review_synergy_button: Button = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/ReviewButtons/ReviewSynergyButton
@onready var review_log_button: Button = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/ReviewButtons/ReviewLogButton
@onready var review_stats_button: Button = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/ReviewButtons/ReviewStatsButton
@onready var title_return_button: Button = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/TitleReturnButton
@onready var back_to_run_end_button: Button = $CanvasLayer/UI/RunEndReviewBar/RunEndReviewHBox/BackToRunEndButton
@onready var synergy_panel: PanelContainer = $CanvasLayer/UI/SynergyPanel
@onready var prep_blocker: Control = $CanvasLayer/UI/PrepBlocker
@onready var event_log_panel: PanelContainer = $CanvasLayer/UI/EventLogPanel
@onready var event_log_scroll: ScrollContainer = $CanvasLayer/UI/EventLogPanel/EventLogVBox/ScrollContainer
@onready var event_log_label: RichTextLabel = $CanvasLayer/UI/EventLogPanel/EventLogVBox/ScrollContainer/EventLogLabel
@onready var continue_button: Button = $CanvasLayer/UI/ExtensionOverlay/ExtensionVBox/ContinueButton
@onready var end_run_button: Button = $CanvasLayer/UI/ExtensionOverlay/ExtensionVBox/EndRunButton
@onready var route_buttons: Array[Button] = [
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton0,
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton1,
	$CanvasLayer/UI/RouteOverlay/RouteVBox/RouteButtons/RouteButton2,
]
@onready var route_title_label: Label = $CanvasLayer/UI/RouteOverlay/RouteVBox/RouteTitle
@onready var synergy_label: RichTextLabel = $CanvasLayer/UI/SynergyPanel/SynergyVBox/ScrollContainer/SynergyLabel


func _ready() -> void:
	shop_slots.custom_minimum_size.y = ACTION_COLUMN_HEIGHT
	_setup_camera()
	drag_controller.setup(camera, board, _get_sell_zone_side)
	input_handler.action_triggered.connect(_on_action)
	drag_controller.sell_requested.connect(_on_sell_requested)
	drag_controller.drag_state_changed.connect(_on_drag_state_changed)
	session.state_changed.connect(_update_ui)
	board.merges_applied.connect(_on_merges_applied)
	board.units_changed.connect(_update_ui)
	event_log.message_added.connect(_refresh_event_log)
	session.extension_choice_required.connect(_on_extension_choice_required)
	session.route_choice_required.connect(_on_route_choice_required)
	session.run_completed.connect(_on_run_completed)
	session.run_failed.connect(_on_run_failed)
	reroll_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.REROLL)))
	exp_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.BUY_EXP)))
	battle_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.START_BATTLE)))
	back_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.GO_BACK)))
	continue_button.pressed.connect(_on_continue_extension)
	end_run_button.pressed.connect(_on_end_run)
	review_board_button.pressed.connect(func() -> void: _enter_run_review(RunReviewMode.BOARD))
	review_synergy_button.pressed.connect(func() -> void: _enter_run_review(RunReviewMode.SYNERGY))
	review_log_button.pressed.connect(func() -> void: _enter_run_review(RunReviewMode.LOG))
	review_stats_button.pressed.connect(func() -> void: _enter_run_review(RunReviewMode.STATS))
	title_return_button.pressed.connect(_leave_to_title)
	back_to_run_end_button.pressed.connect(_return_to_run_end_menu)
	for index in route_buttons.size():
		route_buttons[index].pressed.connect(func() -> void: _on_route_selected(index))
	for index in shop_slots.get_child_count():
		var slot_button: Button = shop_slots.get_child(index) as Button
		slot_button.pressed.connect(func() -> void: _on_action(GameAction.shop_buy(index)))
	_log("準備フェーズ開始")
	_setup_shop_odds_tooltip()
	_setup_log_panel()
	_update_ui()


func _setup_log_panel() -> void:
	_bind_log_panel_input(event_log_panel)
	_apply_log_panel_layout()


func _bind_log_panel_input(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	if not control.gui_input.is_connected(_on_event_log_panel_gui_input):
		control.gui_input.connect(_on_event_log_panel_gui_input)
	for child in control.get_children():
		if child is Control:
			_bind_log_panel_input(child as Control)


func _setup_shop_odds_tooltip() -> void:
	action_column.mouse_filter = Control.MOUSE_FILTER_STOP
	action_column.mouse_entered.connect(_show_shop_odds_tooltip)
	action_column.mouse_exited.connect(_defer_hide_shop_odds_tooltip)
	exp_status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	exp_button.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_odds_tooltip.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_odds_tooltip.mouse_entered.connect(_show_shop_odds_tooltip)
	shop_odds_tooltip.mouse_exited.connect(_defer_hide_shop_odds_tooltip)
	shop_odds_tooltip.visible = false


func _show_shop_odds_tooltip() -> void:
	ShopOdds.populate_odds_grid(shop_odds_grid, session.get_level())
	shop_odds_tooltip.visible = true
	call_deferred("_position_shop_odds_tooltip")


func _defer_hide_shop_odds_tooltip() -> void:
	call_deferred("_try_hide_shop_odds_tooltip")


func _try_hide_shop_odds_tooltip() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	if action_column.get_global_rect().has_point(mouse_pos):
		return
	if shop_odds_tooltip.get_global_rect().has_point(mouse_pos):
		return
	shop_odds_tooltip.visible = false


func _position_shop_odds_tooltip() -> void:
	var anchor_rect := action_column.get_global_rect()
	var tooltip_size := shop_odds_tooltip.size
	var x := anchor_rect.position.x + anchor_rect.size.x * 0.5 - tooltip_size.x * 0.5
	var y := anchor_rect.position.y - tooltip_size.y - 2.0
	var viewport_size := get_viewport().get_visible_rect().size
	x = clampf(x, 8.0, viewport_size.x - tooltip_size.x - 8.0)
	y = clampf(y, 8.0, viewport_size.y - tooltip_size.y - 8.0)
	shop_odds_tooltip.global_position = Vector2(x, y)


func _on_event_log_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_toggle_log_expanded()
		get_viewport().set_input_as_handled()


func _toggle_log_expanded() -> void:
	_save_log_scroll()
	_log_expanded = not _log_expanded
	_apply_log_panel_layout()
	call_deferred("_restore_log_scroll")


func _collapse_log_panel() -> void:
	if not _log_expanded:
		return
	_save_log_scroll()
	_log_expanded = false
	_apply_log_panel_layout()
	call_deferred("_restore_log_scroll")


func _apply_log_panel_layout() -> void:
	event_log_panel.offset_left = -188.0
	event_log_panel.offset_right = -8.0
	event_log_panel.offset_top = LOG_COLLAPSED_TOP
	if _log_expanded:
		event_log_panel.anchor_bottom = 1.0
		event_log_panel.offset_bottom = -LOG_EXPANDED_BOTTOM_MARGIN
		event_log_scroll.custom_minimum_size = Vector2(160, 0)
	else:
		event_log_panel.anchor_bottom = 0.0
		event_log_panel.offset_bottom = LOG_COLLAPSED_BOTTOM
		event_log_scroll.custom_minimum_size = Vector2(160, 200)


func _save_log_scroll() -> void:
	var bar := event_log_scroll.get_v_scroll_bar()
	if bar:
		_log_scroll_position = int(bar.value)


func _restore_log_scroll() -> void:
	var bar := event_log_scroll.get_v_scroll_bar()
	if bar:
		bar.value = _log_scroll_position


func _unhandled_input(event: InputEvent) -> void:
	if not _log_expanded:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			_collapse_log_panel()
			get_viewport().set_input_as_handled()


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
	var bar := event_log_scroll.get_v_scroll_bar()
	if not bar:
		return
	if _log_expanded and bar.value < bar.max_value - 4.0:
		return
	bar.value = bar.max_value


func _on_action(action: GameAction) -> void:
	if action.type == GameAction.Type.CLOSE_LOG:
		_collapse_log_panel()
		return
	if _run_end_active:
		return
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
		GameAction.Type.SELL_UNDER_CURSOR:
			if not session.is_prep() or drag_controller.is_dragging():
				return
			var hover_unit := drag_controller.pick_unit_at_screen(action.screen_position)
			if hover_unit != null:
				_on_sell_requested(hover_unit)
				_update_ui()
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
	if board.get_board_unit_count() <= 0:
		_log("盤面に1体以上配置してください")
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
	var battle_won := true
	var remaining_enemies := 0
	session.finish_battle(battle_won, remaining_enemies)
	if battle_won:
		_log("戦闘勝利 (経験値 +%d)" % GameSession.ROUND_END_FREE_XP)
	else:
		var fought_round := session.round_number - 1
		var damage := PlayerHp.calc_loss_damage(fought_round, remaining_enemies)
		_log("戦闘敗北 (HP -%d, 残り %d)" % [damage, session.player_hp])
	board.set_battle_mode(false)
	await _animate_camera(false)
	battle_overlay.visible = false
	if session.is_run_over():
		_show_run_end_screen()
		return
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
	var start_transform := camera.global_transform
	var end_transform := _camera_transform_looking_at(target_pos, focus)
	_camera_tween_start = start_transform
	_camera_tween_end = end_transform
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_apply_camera_tween, 0.0, 1.0, CAMERA_TWEEN_DURATION)
	await tween.finished


func _camera_transform_looking_at(pos: Vector3, focus: Vector3) -> Transform3D:
	var forward := focus - pos
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return Transform3D(Basis.looking_at(forward, Vector3.UP), pos)


func _apply_camera_tween(weight: float) -> void:
	camera.global_transform = _camera_tween_start.interpolate_with(_camera_tween_end, weight)


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
	_log("ランを終了した")
	session.choose_extension(false)
	_show_run_end_screen()


func _on_run_completed() -> void:
	pass


func _on_run_failed() -> void:
	pass


func _show_run_end_screen() -> void:
	if _run_end_active:
		return
	_run_end_active = true
	_run_review_mode = RunReviewMode.MENU
	battle_overlay.visible = false
	extension_overlay.visible = false
	route_overlay.visible = false
	income_overlay.visible = false
	run_stats_panel.visible = false
	run_end_review_bar.visible = false
	run_end_title.text = _get_run_end_title()
	run_end_summary.text = _build_run_end_summary()
	run_stats_label.text = _build_run_stats_text()
	run_end_overlay.visible = true
	prep_blocker.visible = true
	input_handler.set_enabled(false)
	shop_panel.visible = false
	coin_label.visible = false
	_collapse_log_panel()
	_set_synergy_panel_review_mode(false)
	match session.run_end_reason:
		GameSession.RunEndReason.DEFEAT:
			_log("HPが0になった")
		GameSession.RunEndReason.CLEAR:
			_log("ゲームクリア")
		GameSession.RunEndReason.VOLUNTARY_END:
			pass
	_update_ui()


func _enter_run_review(mode: RunReviewMode) -> void:
	if not _run_end_active:
		return
	_run_review_mode = mode
	run_end_overlay.visible = false
	run_end_review_bar.visible = true
	prep_blocker.visible = false
	run_stats_panel.visible = false
	_set_synergy_panel_review_mode(false)
	if _log_expanded:
		_log_expanded = false
		_apply_log_panel_layout()
	match mode:
		RunReviewMode.BOARD:
			review_bar_label.text = "ラン終了 — 編成を確認中"
			_setup_camera()
		RunReviewMode.SYNERGY:
			review_bar_label.text = "ラン終了 — シナジーを確認中"
			_set_synergy_panel_review_mode(true)
			_update_synergy_panel()
		RunReviewMode.LOG:
			review_bar_label.text = "ラン終了 — ログを確認中"
			_log_expanded = true
			_apply_log_panel_layout()
			_refresh_event_log()
		RunReviewMode.STATS:
			review_bar_label.text = "ラン終了 — 戦績詳細"
			run_stats_label.text = _build_run_stats_text()
			run_stats_panel.visible = true


func _return_to_run_end_menu() -> void:
	if not _run_end_active:
		return
	_run_review_mode = RunReviewMode.MENU
	run_end_overlay.visible = true
	run_end_review_bar.visible = false
	run_stats_panel.visible = false
	prep_blocker.visible = true
	_set_synergy_panel_review_mode(false)
	if _log_expanded:
		_log_expanded = false
		_apply_log_panel_layout()


func _leave_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _get_run_end_title() -> String:
	match session.run_end_reason:
		GameSession.RunEndReason.DEFEAT:
			return "敗北"
		GameSession.RunEndReason.CLEAR:
			return "完全クリア"
		GameSession.RunEndReason.VOLUNTARY_END:
			return "クリア"
	return "ラン終了"


func _get_reached_round() -> int:
	if session.run_end_reason == GameSession.RunEndReason.DEFEAT:
		return maxi(1, session.round_number - 1)
	return mini(session.round_number - 1, session.max_round)


func _build_run_end_summary() -> String:
	var reached := _get_reached_round()
	return "到達ラウンド: %d / %d\nHP: %d  Lv.%d  コイン: %d" % [
		reached,
		session.max_round,
		session.player_hp,
		session.get_level(),
		session.coins,
	]


func _build_run_stats_text() -> String:
	var lines: PackedStringArray = []
	var reached := _get_reached_round()
	lines.append("結果: %s" % _get_run_end_title())
	lines.append("到達ラウンド: %d / %d" % [reached, session.max_round])
	lines.append("HP: %d / %d" % [session.player_hp, PlayerHp.INITIAL_HP])
	lines.append("レベル: %d" % session.get_level())
	lines.append("経験値: %d" % session.experience)
	lines.append("コイン: %d" % session.coins)
	lines.append("連勝: %d  連敗: %d" % [session.win_streak, session.loss_streak])
	lines.append("延長モード: %s" % ("あり" if session.extended_mode else "なし"))
	lines.append("")
	lines.append("盤面 (%d / %d)" % [
		board.get_board_unit_count(),
		session.get_board_unit_cap(),
	])
	for unit in board.get_all_units():
		if not unit.is_on_board():
			continue
		lines.append("  %s %s (%dコスト)" % [
			unit.get_display_name(),
			unit.get_star_text(),
			unit.get_cost(),
		])
	var bench_count := 0
	for slot in board.bench_units:
		if slot == null:
			continue
		bench_count += 1
	lines.append("")
	lines.append("ベンチ (%d)" % bench_count)
	for slot in board.bench_units:
		var unit: GameUnit = slot as GameUnit
		if unit == null:
			continue
		lines.append("  %s %s (%dコスト)" % [
			unit.get_display_name(),
			unit.get_star_text(),
			unit.get_cost(),
		])
	var synergies := SynergyTracker.get_active_synergies(board.get_all_units())
	if synergies.is_empty():
		lines.append("")
		lines.append("シナジー: 発動なし")
	else:
		lines.append("")
		lines.append("シナジー:")
		for entry in synergies:
			lines.append("  %s Lv.%d (%d体)" % [
				entry["name"],
				entry["tier"],
				entry["count"],
			])
	return "\n".join(lines)


func _set_synergy_panel_review_mode(active: bool) -> void:
	if active:
		var height := get_viewport().get_visible_rect().size.y
		synergy_panel.offset_bottom = height - 8.0
	else:
		synergy_panel.offset_bottom = SYNERGY_PANEL_NORMAL_BOTTOM


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
	if _run_end_active:
		battle_button.disabled = true
		back_button.disabled = true
		reroll_button.disabled = true
		exp_button.disabled = true
		input_handler.set_enabled(false)
		shop_panel.visible = false
		coin_label.visible = false
		for index in shop_slots.get_child_count():
			var slot_button: Button = shop_slots.get_child(index) as Button
			slot_button.disabled = true
		_update_synergy_panel()
		return
	back_button.disabled = false
	coin_label.text = "コイン: %d" % session.coins
	var level := session.get_level()
	var xp_into := PlayerLevel.get_xp_into_current_level(session.experience)
	var xp_need := PlayerLevel.get_xp_needed_for_next_level(level)
	if xp_need > 0:
		exp_status_label.text = "Lv.%d  経験値 %d/%d" % [level, xp_into, xp_need]
	else:
		exp_status_label.text = "Lv.%d  経験値 MAX" % level
	if shop_odds_tooltip.visible:
		ShopOdds.populate_odds_grid(shop_odds_grid, level)
		call_deferred("_position_shop_odds_tooltip")
	var round_cap := session.max_round
	round_label.text = "ラウンド: %d / %d" % [mini(session.round_number, round_cap), round_cap]
	hp_label.text = "HP: %d" % session.player_hp
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
	battle_button.disabled = not session.is_prep() or board.get_board_unit_count() <= 0
	input_handler.set_enabled(session.is_prep())
	shop_panel.visible = session.is_prep()
	coin_label.visible = session.is_prep()
	for index in shop_slots.get_child_count():
		var slot_button: Button = shop_slots.get_child(index) as Button
		if index >= session.shop_unit_ids.size() or session.shop_unit_ids[index] < 0:
			slot_button.text = "売り切れ"
			slot_button.disabled = true
			_apply_shop_slot_style(slot_button, 0)
			continue
		var unit_id: int = session.shop_unit_ids[index]
		var data := UnitCatalog.get_unit(unit_id)
		var synergy_text := UnitCatalog.get_synergy_names(unit_id)
		slot_button.text = "%s ★\n%d コイン\n%s" % [data["name"], data["cost"], synergy_text]
		var cost: int = data["cost"]
		slot_button.disabled = not session.is_prep() or session.coins < cost or board.bench_is_full()
		_apply_shop_slot_style(slot_button, cost)
	_update_synergy_panel()


func _apply_shop_slot_style(button: Button, cost: int) -> void:
	var style := CostColors.get_empty_shop_stylebox() if cost <= 0 else CostColors.get_shop_stylebox(cost)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	button.add_theme_stylebox_override("focus", style)
