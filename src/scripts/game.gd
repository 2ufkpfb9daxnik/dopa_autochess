extends Node3D

const INCOME_FEEDBACK_DURATION := 2.0
const SHOP_SLOT_SCENE := preload("res://scenes/shop_slot.tscn")
const SHOP_COLUMNS := 3
const SHOP_SLOT_WIDTH := 132
const SHOP_SLOT_HEIGHT := 148
const SELL_ZONE_WIDTH := 72.0
const ACTION_COLUMN_WIDTH := 96
const BOTTOM_BUTTON_HEIGHT := 48
const BOTTOM_BAR_GAP := 12
const COIN_ABOVE_SHOP_GAP := 4.0
const BOTTOM_UI_MARGIN := 12.0
const BOTTOM_UI_FONT_COIN := 22
const BOTTOM_UI_FONT_EXP_STATUS := 17
const BOTTOM_UI_FONT_BUTTON := 16
const BOTTOM_UI_FONT_SHOP := 15
const HUD_BADGE_BG := Color(0.0, 0.0, 0.0, 0.45)
const HUD_BADGE_MARGIN_X := 8.0

const LOG_COLLAPSED_TOP := 56.0
const LOG_COLLAPSED_BOTTOM := 280.0
const LOG_EXPANDED_BOTTOM_PAD := 12.0
const SYNERGY_PANEL_NORMAL_BOTTOM := 520.0

enum RunReviewMode { MENU, BOARD, SYNERGY, LOG, STATS }

var _log_expanded := false
var _log_scroll_position := 0
var _run_end_active := false
var _run_review_mode := RunReviewMode.MENU
var _pending_bottom_refit := false
var _bottom_ui_layout_height := -1.0
var _last_prep_shop_ui_visible := true
var _last_reroll_button_text := ""
var _circle_wheel: CircleWheel
var _bench_board: BenchBoard
var _action_order_bar: ActionOrderBar
var _battle_viewport: SubViewportContainer
var _screen_divider: ColorRect
var _drag_preview: Control
var _drag_name_label: Label
var _drag_cost_label: Label
var _drag_stars_label: Label
var _drag_bar: ColorRect
var _dragging_unit: GameUnit
var _battle_view_height := 320.0
var _battle_rect := Rect2()
var _split_x := 0.0
var _battle_world: SubViewport
var _shop_slot_size := Vector2(SHOP_SLOT_WIDTH, SHOP_SLOT_HEIGHT)

@onready var camera: Camera3D = $Camera3D
@onready var board: BoardController = $Board
@onready var units_root: Node3D = $Units
@onready var session: GameSession = $GameSession
@onready var input_handler: GameInputHandler = $GameInputHandler
@onready var event_log: EventLog = $EventLog

@onready var round_badge: PanelContainer = $CanvasLayer/UI/TopBar/RoundBadge
@onready var round_label: Label = $CanvasLayer/UI/TopBar/RoundBadge/RoundLabel
@onready var hp_badge: PanelContainer = $CanvasLayer/UI/TopBar/HpBadge
@onready var hp_label: Label = $CanvasLayer/UI/TopBar/HpBadge/HpLabel
@onready var bench_badge: PanelContainer = $CanvasLayer/UI/TopBar/BenchBadge
@onready var bench_label: Label = $CanvasLayer/UI/TopBar/BenchBadge/BenchLabel
@onready var top_bar: HBoxContainer = $CanvasLayer/UI/TopBar
@onready var coin_row: HBoxContainer = $CanvasLayer/UI/CoinRow
@onready var coin_badge: PanelContainer = $CanvasLayer/UI/CoinRow/CoinBadge
@onready var coin_label: Label = $CanvasLayer/UI/CoinRow/CoinBadge/CoinLabel
@onready var streak_badge: PanelContainer = $CanvasLayer/UI/CoinRow/StreakBadge
@onready var streak_label: Label = $CanvasLayer/UI/CoinRow/StreakBadge/StreakLabel
@onready var exp_hud_badge: PanelContainer = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpHudBadge
@onready var exp_status_label: Label = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpHudBadge/ExpHudVBox/ExpStatusLabel
@onready var exp_progress_bar: ProgressBar = $CanvasLayer/UI/BottomUI/BottomBar/ActionColumn/ExpHudBadge/ExpHudVBox/ExpProgressBar
@onready var shop_slots: Container = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel/ShopSlots
@onready var bottom_ui: Control = $CanvasLayer/UI/BottomUI
@onready var bottom_bar: HBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar
@onready var shop_panel: VBoxContainer = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel
@onready var shop_odds_badge: PanelContainer = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel/ShopHeaderRow/ShopOddsBadge
@onready var shop_odds_row: Container = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel/ShopHeaderRow/ShopOddsBadge/ShopOddsRow
@onready var shop_odds_tooltip: PanelContainer = $CanvasLayer/UI/ShopOddsTooltip
@onready var shop_odds_tooltip_vbox: VBoxContainer = $CanvasLayer/UI/ShopOddsTooltip/ShopOddsTooltipVBox
@onready var shop_odds_grid: GridContainer = $CanvasLayer/UI/ShopOddsTooltip/ShopOddsTooltipVBox/ShopOddsGrid
@onready var shop_lock_button: Button = $CanvasLayer/UI/BottomUI/BottomBar/ShopPanel/ShopHeaderRow/ShopLockButton
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
	_setup_shop_slots()
	_setup_bottom_ui_fonts()
	exp_button.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, BOTTOM_BUTTON_HEIGHT)
	reroll_button.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, BOTTOM_BUTTON_HEIGHT)
	action_column.custom_minimum_size.x = ACTION_COLUMN_WIDTH
	_mount_battle_viewport()
	_setup_formation_ui()
	_mount_side_controls()
	_setup_camera()
	input_handler.action_triggered.connect(_on_action)
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
	shop_lock_button.pressed.connect(_on_shop_lock_pressed)
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
	_log("準備フェーズ開始")
	_setup_shop_odds_table()
	_setup_log_panel()
	call_deferred("_finish_startup_layout")


func _setup_shop_slots() -> void:
	var grid := GridContainer.new()
	grid.columns = SHOP_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var parent := shop_slots.get_parent()
	var slot_index := shop_slots.get_index()
	parent.add_child(grid)
	parent.move_child(grid, slot_index)
	shop_slots.queue_free()
	shop_slots = grid
	for index in GameSession.SHOP_SIZE:
		var slot := SHOP_SLOT_SCENE.instantiate() as ShopSlotPanel
		if slot == null:
			push_error("ShopSlotPanel の生成に失敗しました")
			continue
		slot.pressed.connect(func() -> void: _on_action(GameAction.shop_buy(index)))
		shop_slots.add_child(slot)
		slot.set_card_size(_shop_slot_size)


func _get_shop_panel_width() -> float:
	return float(SHOP_COLUMNS) * _shop_slot_size.x + float(SHOP_COLUMNS - 1) * 8.0


func _get_bottom_ui_width() -> float:
	return ACTION_COLUMN_WIDTH + BOTTOM_BAR_GAP + _get_shop_panel_width()


func _finish_startup_layout() -> void:
	_update_ui()
	await _fit_bottom_ui_layout()
	_layout_formation_ui()


func _setup_bottom_ui_fonts() -> void:
	coin_row.mouse_filter = Control.MOUSE_FILTER_STOP
	coin_label.add_theme_font_size_override("font_size", BOTTOM_UI_FONT_COIN)
	streak_label.add_theme_font_size_override("font_size", 18)
	_apply_hud_badge_style(coin_badge)
	_apply_hud_badge_style(streak_badge)
	_apply_hud_badge_style(exp_hud_badge)
	_apply_hud_badge_style(shop_odds_badge)
	_apply_hud_badge_style(round_badge)
	_apply_hud_badge_style(hp_badge)
	_apply_hud_badge_style(bench_badge)
	_setup_shop_header_layout()
	shop_odds_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exp_status_label.add_theme_font_size_override("font_size", 13)
	exp_status_label.custom_minimum_size = Vector2(0, 0)
	exp_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	exp_progress_bar.custom_minimum_size = Vector2(16, 72)
	exp_progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exp_progress_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	var exp_bar_bg := StyleBoxFlat.new()
	exp_bar_bg.bg_color = Color(0.12, 0.14, 0.18)
	exp_bar_bg.set_corner_radius_all(3)
	var exp_bar_fill := StyleBoxFlat.new()
	exp_bar_fill.bg_color = Color(0.35, 0.72, 0.95)
	exp_bar_fill.set_corner_radius_all(3)
	exp_progress_bar.add_theme_stylebox_override("background", exp_bar_bg)
	exp_progress_bar.add_theme_stylebox_override("fill", exp_bar_fill)
	exp_button.add_theme_font_size_override("font_size", 14)
	reroll_button.add_theme_font_size_override("font_size", 14)
	for slot in shop_slots.get_children():
		if slot is ShopSlotPanel:
			(slot as ShopSlotPanel).add_theme_font_size_override("font_size", BOTTOM_UI_FONT_SHOP)


func _apply_hud_badge_style(badge: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = HUD_BADGE_BG
	box.set_corner_radius_all(4)
	box.content_margin_left = 4
	box.content_margin_top = 4
	box.content_margin_right = 4
	box.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", box)


func _setup_shop_header_layout() -> void:
	shop_odds_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _mount_side_controls() -> void:
	var odds_column := VBoxContainer.new()
	odds_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	odds_column.add_theme_constant_override("separation", 1)
	shop_odds_badge.add_child(odds_column)
	shop_odds_row.queue_free()
	shop_odds_row = odds_column
	var header_row := shop_lock_button.get_parent()
	header_row.remove_child(shop_odds_badge)
	header_row.remove_child(shop_lock_button)
	header_row.visible = false
	var exp_box := exp_status_label.get_parent()
	coin_badge.get_parent().remove_child(coin_badge)
	exp_box.add_child(coin_badge)
	exp_box.move_child(coin_badge, 0)
	coin_label.add_theme_font_size_override("font_size", 14)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_column.add_child(shop_lock_button)
	action_column.add_child(shop_odds_badge)
	shop_lock_button.custom_minimum_size = Vector2(0, 32)
	var ui := $CanvasLayer/UI as Control
	action_column.get_parent().remove_child(action_column)
	ui.add_child(action_column)
	action_column.mouse_filter = Control.MOUSE_FILTER_STOP
	action_column.z_index = 6
	action_column.alignment = BoxContainer.ALIGNMENT_BEGIN


func _setup_shop_odds_table() -> void:
	shop_odds_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	if not shop_odds_badge.gui_input.is_connected(_on_shop_odds_badge_gui_input):
		shop_odds_badge.gui_input.connect(_on_shop_odds_badge_gui_input)
	_apply_hud_badge_style(shop_odds_tooltip)
	shop_odds_tooltip.z_index = 28
	shop_odds_tooltip.visible = false


func _on_shop_odds_badge_gui_input(event: InputEvent) -> void:
	if _run_end_active or not session.is_prep():
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_toggle_shop_odds_table()
	get_viewport().set_input_as_handled()


func _toggle_shop_odds_table() -> void:
	if shop_odds_tooltip.visible:
		_hide_shop_odds_table()
	else:
		_show_shop_odds_table()


func _show_shop_odds_table() -> void:
	ShopOdds.populate_odds_grid(shop_odds_grid, session.get_level())
	shop_odds_tooltip.visible = true
	shop_odds_tooltip.move_to_front()
	call_deferred("_fit_shop_odds_tooltip_size")


func _hide_shop_odds_table() -> void:
	shop_odds_tooltip.visible = false


func _get_panel_content_margins(panel: PanelContainer) -> Vector4:
	var style := panel.get_theme_stylebox("panel")
	if style == null:
		return Vector4(8.0, 8.0, 8.0, 8.0)
	return Vector4(
		style.content_margin_left,
		style.content_margin_top,
		style.content_margin_right,
		style.content_margin_bottom
	)


func _fit_shop_odds_tooltip_size() -> void:
	shop_odds_tooltip_vbox.reset_size()
	shop_odds_grid.reset_size()
	await get_tree().process_frame
	var content_size := shop_odds_tooltip_vbox.get_minimum_size()
	var margins := _get_panel_content_margins(shop_odds_tooltip)
	var fitted := content_size + Vector2(margins.x + margins.z, margins.y + margins.w)
	shop_odds_tooltip.custom_minimum_size = fitted
	shop_odds_tooltip.size = fitted
	_position_shop_odds_tooltip()


func _position_shop_odds_tooltip() -> void:
	var anchor_rect := shop_odds_badge.get_global_rect()
	var tooltip_size := shop_odds_tooltip.size
	var x := anchor_rect.position.x - tooltip_size.x - 6.0
	var y := anchor_rect.get_center().y - tooltip_size.y * 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var max_x := maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)
	var max_y := maxf(8.0, viewport_size.y - tooltip_size.y - 8.0)
	x = clampf(x, 8.0, max_x)
	y = clampf(y, 8.0, max_y)
	shop_odds_tooltip.global_position = Vector2(x, y)


func _fit_shop_odds_badge_width() -> void:
	shop_odds_badge.custom_minimum_size.x = 0
	_position_coin_row_over_shop()


func _format_streak_text() -> String:
	if session.win_streak > 0:
		return "連勝%d回" % session.win_streak
	if session.loss_streak > 0:
		return "連敗%d回" % session.loss_streak
	return ""


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


func _on_shop_lock_pressed() -> void:
	session.toggle_shop_lock()
	_update_ui()


func _fit_bottom_ui_layout() -> void:
	await get_tree().process_frame
	coin_row.reset_size()
	bottom_bar.reset_size()
	shop_panel.reset_size()
	for slot in shop_slots.get_children():
		if slot is Control:
			(slot as Control).reset_size()
	await get_tree().process_frame
	shop_panel.custom_minimum_size.x = _get_shop_panel_width()
	_layout_formation_ui()
	if shop_odds_tooltip.visible:
		call_deferred("_fit_shop_odds_tooltip_size")
	if session.is_prep() and not _run_end_active:
		_fit_shop_odds_badge_width()


func _position_coin_row_over_shop() -> void:
	if not coin_row.visible:
		return
	coin_row.z_index = 25
	coin_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	coin_row.reset_size()
	var coin_size := coin_row.get_combined_minimum_size()
	coin_row.position = top_bar.position + Vector2(top_bar.size.x + 8.0, 0.0)
	coin_row.size = coin_size


func _request_bottom_ui_refit() -> void:
	if _pending_bottom_refit:
		return
	_pending_bottom_refit = true
	call_deferred("_run_bottom_ui_refit")


func _run_bottom_ui_refit() -> void:
	_pending_bottom_refit = false
	await _fit_bottom_ui_layout()


func _refit_bottom_ui_layout() -> void:
	await _fit_bottom_ui_layout()


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
	event_log_panel.anchor_left = 0.0
	event_log_panel.anchor_right = 0.0
	event_log_panel.anchor_top = 0.0
	event_log_panel.anchor_bottom = 0.0
	var panel_right := _battle_rect.end.x - 8.0 if _battle_rect.size.x > 1.0 else 188.0
	var panel_left := panel_right - 168.0
	var panel_top := _battle_rect.position.y + top_bar.size.y + 8.0 if _battle_rect.size.y > 1.0 else LOG_COLLAPSED_TOP
	event_log_panel.offset_left = panel_left
	event_log_panel.offset_right = panel_right
	event_log_panel.offset_top = panel_top
	if _log_expanded:
		event_log_panel.offset_bottom = _battle_rect.end.y - 8.0 if _battle_rect.size.y > 1.0 else LOG_COLLAPSED_BOTTOM
		event_log_scroll.custom_minimum_size = Vector2(150, 0)
	else:
		event_log_panel.offset_bottom = panel_top + 132.0
		event_log_scroll.custom_minimum_size = Vector2(150, 80)


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


func _get_bottom_ui_occupied_height() -> float:
	return bottom_ui.size.y + BOTTOM_UI_MARGIN


func _setup_camera() -> void:
	camera.current = true
	camera.fov = 34.0
	camera.near = 0.05
	camera.global_position = Vector3(0.0, 1.4, 4.9)
	camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)


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
		GameAction.Type.DRAG_PRESS, GameAction.Type.DRAG_MOVE, GameAction.Type.DRAG_RELEASE:
			pass
		GameAction.Type.SHOP_BUY:
			_buy_from_shop(action.shop_slot)
		GameAction.Type.REROLL:
			if session.try_reroll():
				_log("ショップを更新した")
		GameAction.Type.BUY_EXP:
			if session.try_buy_exp():
				_log("経験値を購入した (+%d)" % GameSession.EXP_GAIN)
		GameAction.Type.SELL_UNDER_CURSOR:
			if not session.is_prep() or _dragging_unit != null:
				return
			var hover_unit := _unit_under_screen(action.screen_position)
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
	if board.get_front_unit_count() <= 0:
		_log("前衛に1人以上配置してください")
		return
	_hide_shop_odds_table()
	_log("戦闘開始 (ラウンド %d)" % session.round_number)
	session.start_battle()
	input_handler.set_enabled(false)
	prep_blocker.visible = true
	battle_overlay.visible = true
	board.set_battle_mode(true)
	var enemy_count := EnemySpawn.spawn_for_battle(
		board,
		units_root,
		session.round_number,
		session.selected_route
	)
	_log("敵 %d 体出現" % enemy_count)
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
		_show_route_choice()
		_update_ui()
		return
	prep_blocker.visible = false
	shop_panel.visible = true
	coin_row.visible = true
	if session.phase == GameSession.Phase.PREP:
		_log("ラウンド %d 開始" % session.round_number)
		if not session.last_income_breakdown.is_empty():
			_show_income_feedback()
	input_handler.set_enabled(session.is_prep())
	_update_ui()


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
	coin_row.visible = true
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
	coin_row.visible = false
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
	lines.append("サークル (%d / %d)" % [
		board.get_board_unit_count(),
		session.get_board_unit_cap(),
	])
	for face_index in board.get_unlocked_face_count():
		lines.append("%d面" % [face_index + 1])
		for slot_index in BoardController.SLOTS_PER_FACE:
			var placed := board.get_placed_unit(face_index, slot_index)
			if placed == null:
				continue
			var row_label := "前衛" if slot_index < BoardController.FRONT_COUNT else "後衛"
			lines.append("  %s %s %s (%dコスト)" % [
				row_label,
				placed.get_display_name(),
				placed.get_star_text(),
				placed.get_cost(),
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
	if _battle_rect.size.y <= 1.0:
		return
	synergy_panel.offset_top = _battle_rect.position.y
	if active:
		synergy_panel.offset_bottom = _battle_rect.end.y - 8.0
	else:
		synergy_panel.offset_bottom = _battle_rect.position.y + 118.0


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
	label.text = "収入 +%d\n(基本 %d / 所持 %d / 連勝敗 %d / ラウンド %d)" % [
		breakdown["total"],
		breakdown["base"],
		breakdown["holding"],
		breakdown["streak"],
		breakdown["round"],
	]
	income_overlay.visible = true
	_log("収入 +%d (基本 %d / 所持 %d / 連勝 %d / ラウンド %d)" % [
		breakdown["total"], breakdown["base"], breakdown["holding"], breakdown["streak"], breakdown["round"]
	])
	await get_tree().create_timer(INCOME_FEEDBACK_DURATION).timeout
	income_overlay.visible = false


func _on_drag_state_changed(is_dragging: bool, sell_zone_side: int) -> void:
	sell_drag_hint_left.visible = false
	sell_drag_hint_right.visible = is_dragging and session.is_prep()
	if not sell_drag_hint_right.visible:
		return
	sell_drag_hint_right.z_index = 30
	var active_color := Color(1.0, 0.55, 0.55, 1.0)
	var idle_color := Color(1.0, 1.0, 1.0, 0.7)
	sell_drag_hint_right.modulate = active_color if sell_zone_side == 1 else idle_color


func _get_sell_zone_side(screen_pos: Vector2) -> int:
	if not session.is_prep():
		return -1
	if sell_drag_hint_right.get_global_rect().has_point(screen_pos):
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


func _mount_battle_viewport() -> void:
	var layer := $CanvasLayer
	var background := ColorRect.new()
	background.color = Color(0.06, 0.07, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(background)
	layer.move_child(background, 0)
	_battle_viewport = SubViewportContainer.new()
	_battle_viewport.name = "BattleViewport"
	_battle_viewport.stretch = true
	_battle_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_viewport.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_battle_viewport.offset_bottom = _battle_view_height
	layer.add_child(_battle_viewport)
	layer.move_child(_battle_viewport, 1)
	var viewport := SubViewport.new()
	viewport.name = "BattleWorld"
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(640, 480)
	_battle_world = viewport
	_battle_viewport.add_child(viewport)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.17, 0.19, 0.23)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.73, 0.78)
	environment.ambient_light_energy = 1.1
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 4.2, 0.4)
	fill_light.omni_range = 16.0
	fill_light.light_energy = 1.3
	viewport.add_child(fill_light)
	camera.reparent(viewport)
	$DirectionalLight3D.reparent(viewport)
	board.reparent(viewport)
	units_root.reparent(viewport)
	_screen_divider = ColorRect.new()
	_screen_divider.color = Color(0.86, 0.74, 0.38)
	_screen_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_divider.set_anchors_preset(Control.PRESET_TOP_WIDE)
	layer.add_child(_screen_divider)
	layer.move_child(_screen_divider, 2)


func _setup_formation_ui() -> void:
	var ui := $CanvasLayer/UI
	_circle_wheel = CircleWheel.new()
	_bench_board = BenchBoard.new()
	_action_order_bar = ActionOrderBar.new()
	_drag_preview = Control.new()
	_drag_preview.visible = false
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.z_index = 40
	_drag_preview.custom_minimum_size = Vector2(76, 96)
	_drag_preview.size = Vector2(76, 96)
	var icon := TextureRect.new()
	icon.texture = preload("res://images/placeholder.png")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_bottom = -24
	_drag_preview.add_child(icon)
	_drag_bar = ColorRect.new()
	_drag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drag_bar.offset_top = -24
	_drag_bar.offset_bottom = 0
	_drag_preview.add_child(_drag_bar)
	_drag_cost_label = Label.new()
	_drag_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_cost_label.position = Vector2(4, 74)
	_drag_cost_label.size = Vector2(22, 20)
	_drag_cost_label.add_theme_font_size_override("font_size", 14)
	_drag_preview.add_child(_drag_cost_label)
	_drag_name_label = Label.new()
	_drag_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_name_label.position = Vector2(24, 74)
	_drag_name_label.size = Vector2(48, 20)
	_drag_name_label.add_theme_font_size_override("font_size", 12)
	_drag_preview.add_child(_drag_name_label)
	_drag_stars_label = Label.new()
	_drag_stars_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_stars_label.position = Vector2(4, 2)
	_drag_stars_label.size = Vector2(68, 18)
	_drag_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_drag_stars_label.add_theme_font_size_override("font_size", 14)
	_drag_stars_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_drag_preview.add_child(_drag_stars_label)
	var insert_at := route_overlay.get_index()
	ui.add_child(_circle_wheel)
	ui.move_child(_circle_wheel, insert_at)
	ui.add_child(_bench_board)
	ui.move_child(_bench_board, insert_at + 1)
	ui.add_child(_action_order_bar)
	ui.move_child(_action_order_bar, insert_at + 2)
	ui.add_child(_drag_preview)
	_circle_wheel.rotate_steps.connect(func(steps: int) -> void: board.apply_spin_commit(steps))
	_circle_wheel.visual_shift_changed.connect(func(shift: float) -> void: board.set_visual_shift(shift))
	_circle_wheel.center_pressed.connect(_on_circle_center_pressed)
	_circle_wheel.unit_drag_started.connect(_on_circle_drag_started)
	_circle_wheel.unit_drag_finished.connect(_on_circle_drag_finished)
	_circle_wheel.slot_move_requested.connect(_on_circle_slot_move)
	_bench_board.unit_drag_started.connect(_on_bench_drag_started)
	_bench_board.unit_drag_finished.connect(_on_bench_drag_finished)
	_bench_board.slot_clicked.connect(_on_bench_slot_clicked)
	if not get_viewport().size_changed.is_connected(_layout_formation_ui):
		get_viewport().size_changed.connect(_layout_formation_ui)


func _layout_formation_ui() -> void:
	if _circle_wheel == null or _battle_viewport == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var top := 8.0
	var slot_w := clampf(viewport_size.x * 0.078, 84.0, 112.0)
	var cards_w := slot_w * float(SHOP_COLUMNS) + 8.0 * float(SHOP_COLUMNS - 1)
	var right_w := ACTION_COLUMN_WIDTH + 8.0 + cards_w
	_split_x = viewport_size.x - right_w - 8.0
	var left_x := 8.0
	var left_w := _split_x - 16.0
	var left_h := viewport_size.y - top - 8.0
	_battle_view_height = left_h * 0.58
	_battle_rect = Rect2(left_x, top, left_w, _battle_view_height)
	_place_control(_battle_viewport, _battle_rect)
	if _battle_world != null:
		_battle_world.size = Vector2i(maxi(8, int(_battle_rect.size.x)), maxi(8, int(_battle_rect.size.y)))
	_screen_divider.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_screen_divider.offset_left = _split_x - 1.0
	_screen_divider.offset_right = _split_x + 1.0
	_screen_divider.offset_top = top
	_screen_divider.offset_bottom = viewport_size.y - 8.0
	var circle_top := _battle_rect.end.y + 8.0
	var circle_band := maxf(120.0, viewport_size.y - 8.0 - circle_top)
	var wheel_size := minf(left_w, circle_band)
	_circle_wheel.position = Vector2(left_x + (left_w - wheel_size) * 0.5, circle_top + (circle_band - wheel_size) * 0.5)
	_circle_wheel.size = Vector2(wheel_size, wheel_size)
	var right_x := _split_x + 8.0
	var right_bottom := viewport_size.y - 8.0
	var right_h := right_bottom - top
	var shop_area_h := right_h * 0.4
	var bench_top := top + shop_area_h + 6.0
	var bench_h := right_bottom - bench_top
	var cards_x := right_x + ACTION_COLUMN_WIDTH + 8.0
	_place_shop(Rect2(cards_x, top, cards_w, shop_area_h))
	_bench_board.position = Vector2(cards_x - 6.0, bench_top)
	_bench_board.size = Vector2(_get_shop_panel_width() + 12.0, bench_h)
	_place_side_column(right_x)
	_place_top_bar(Vector2(left_x, top))
	synergy_panel.anchor_left = 0.0
	synergy_panel.anchor_right = 0.0
	synergy_panel.anchor_top = 0.0
	synergy_panel.anchor_bottom = 0.0
	var hud_clearance := top_bar.size.y + 8.0
	synergy_panel.offset_left = _battle_rect.position.x
	synergy_panel.offset_top = _battle_rect.position.y + hud_clearance
	synergy_panel.offset_right = _battle_rect.position.x + 148.0
	if _run_review_mode == RunReviewMode.SYNERGY:
		synergy_panel.offset_bottom = _battle_rect.end.y - 8.0
	else:
		synergy_panel.offset_bottom = synergy_panel.offset_top + 118.0
	_action_order_bar.z_index = 8
	_action_order_bar.position = Vector2(synergy_panel.offset_right + 6.0, synergy_panel.offset_top)
	_action_order_bar.size = Vector2(78.0, maxf(120.0, viewport_size.y - 8.0 - synergy_panel.offset_top))
	_apply_log_panel_layout()
	battle_overlay.anchor_left = 0.0
	battle_overlay.anchor_right = 0.0
	battle_overlay.anchor_top = 0.0
	battle_overlay.anchor_bottom = 0.0
	battle_overlay.offset_left = _battle_rect.position.x + _battle_rect.size.x * 0.5 - 90.0
	battle_overlay.offset_right = battle_overlay.offset_left + 180.0
	battle_overlay.offset_top = _battle_rect.position.y + _battle_rect.size.y * 0.32
	battle_overlay.offset_bottom = battle_overlay.offset_top + 52.0
	income_overlay.anchor_left = 0.0
	income_overlay.anchor_right = 0.0
	income_overlay.anchor_top = 0.0
	income_overlay.anchor_bottom = 0.0
	income_overlay.offset_left = _battle_rect.position.x + _battle_rect.size.x * 0.5 - 130.0
	income_overlay.offset_right = income_overlay.offset_left + 260.0
	income_overlay.offset_top = _battle_rect.position.y + top_bar.size.y + 10.0
	income_overlay.offset_bottom = income_overlay.offset_top + 78.0


func _place_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _place_top_bar(origin: Vector2) -> void:
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.z_index = 25
	top_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_bar.reset_size()
	var bar_size := top_bar.get_combined_minimum_size()
	top_bar.position = origin
	top_bar.size = Vector2(maxf(bar_size.x, 1.0), maxf(bar_size.y, 36.0))


func _place_side_column(column_x: float) -> void:
	action_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	action_column.position = Vector2(column_x, bottom_ui.offset_top)
	action_column.custom_minimum_size = Vector2(ACTION_COLUMN_WIDTH, 0)
	var column_h := action_column.get_combined_minimum_size().y
	action_column.size = Vector2(ACTION_COLUMN_WIDTH, maxf(column_h, 1.0))


func _place_shop(area: Rect2) -> void:
	var shop_h := maxf(80.0, area.size.y)
	var slot_w := clampf((area.size.x - 16.0) / float(SHOP_COLUMNS), 72.0, 150.0)
	var slot_h := clampf((shop_h - 8.0) / 2.0, 96.0, 240.0)
	_shop_slot_size = Vector2(slot_w, slot_h)
	for child in shop_slots.get_children():
		var slot := child as ShopSlotPanel
		if slot != null:
			slot.set_card_size(_shop_slot_size)
	shop_panel.custom_minimum_size.x = _get_shop_panel_width()
	bottom_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bottom_ui.offset_left = area.position.x
	bottom_ui.offset_top = area.position.y
	bottom_ui.offset_right = area.end.x
	bottom_ui.offset_bottom = area.end.y
	sell_drag_hint_left.visible = false
	sell_drag_hint_right.z_index = 30
	sell_drag_hint_right.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sell_drag_hint_right.offset_left = area.end.x - SELL_ZONE_WIDTH
	sell_drag_hint_right.offset_right = area.end.x
	sell_drag_hint_right.offset_top = area.position.y
	sell_drag_hint_right.offset_bottom = area.end.y
	var sell_label := sell_drag_hint_right.get_node_or_null("SellDragLabelRight") as Label
	if sell_label != null:
		sell_label.text = "売却"
	call_deferred("_position_coin_row_over_shop")


func _refresh_formation_widgets() -> void:
	if _circle_wheel == null:
		return
	board.board_unit_limit = session.get_board_unit_cap()
	board.set_unlocked_face_count(BoardController.unlocked_face_count_for_level(session.get_level()))
	var center_text := "%d面\n%d/%d" % [
		board.active_face + 1,
		board.get_board_unit_count(),
		session.get_board_unit_cap(),
	]
	if board.get_unlocked_face_count() <= 1:
		center_text += "\nLv7で2面"
	_circle_wheel.set_view(center_text, board.get_wheel_slots())
	var bench_view: Array = []
	for slot in board.bench_units:
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
	_bench_board.set_slots(bench_view)
	_action_order_bar.set_entries(board.get_action_order())
	var can_edit := session.is_prep() and not _run_end_active
	var can_rotate := not _run_end_active and (
		session.is_prep() or session.phase == GameSession.Phase.BATTLE
	)
	_circle_wheel.set_unit_drag_enabled(can_edit)
	_circle_wheel.set_interaction_enabled(can_rotate)
	_bench_board.set_input_enabled(can_edit)


func _on_circle_center_pressed() -> void:
	if _run_end_active or session.phase == GameSession.Phase.ROUTE_CHOICE or session.phase == GameSession.Phase.EXTENSION_CHOICE:
		return
	if board.get_unlocked_face_count() <= 1:
		_log("2面はレベル7で開きます")
		return
	board.cycle_face()
	_log("%d面を表示" % [board.active_face + 1])


func _on_circle_drag_started(slot_index: int) -> void:
	var unit := board.get_placed_unit(board.active_face, slot_index)
	if unit != null:
		_begin_unit_drag(unit)


func _on_bench_drag_started(slot_index: int) -> void:
	var unit: GameUnit = board.bench_units[slot_index]
	if unit != null:
		_begin_unit_drag(unit)


func _on_circle_drag_finished(_slot_index: int, global_position: Vector2) -> void:
	_finish_unit_drag(global_position)


func _on_bench_drag_finished(_slot_index: int, global_position: Vector2) -> void:
	_finish_unit_drag(global_position)


func _on_circle_slot_move(from_slot: int, to_slot: int) -> void:
	var unit := board.get_placed_unit(board.active_face, from_slot)
	if unit == null:
		return
	if not board.try_move_unit_to_circle(unit, board.active_face, to_slot):
		_log("そこには配置できません")


func _on_bench_slot_clicked(slot_index: int) -> void:
	if not session.is_prep() or _run_end_active:
		return
	var unit: GameUnit = board.bench_units[slot_index]
	if unit == null:
		return
	var dest := board.find_empty_circle_slot(board.active_face)
	if dest < 0:
		_log("この面は満員です")
		return
	if not board.try_move_unit_to_circle(unit, board.active_face, dest):
		_log("配置上限です")


func _begin_unit_drag(unit: GameUnit) -> void:
	_dragging_unit = unit
	var cost := unit.get_cost()
	var label_color := CostColors.get_shop_label_color(cost)
	_drag_bar.color = CostColors.get_color(cost)
	_drag_cost_label.text = str(cost)
	_drag_name_label.text = unit.get_display_name()
	_drag_stars_label.text = unit.get_star_text()
	_drag_cost_label.add_theme_color_override("font_color", label_color)
	_drag_name_label.add_theme_color_override("font_color", label_color)
	_drag_preview.visible = true
	_drag_preview.global_position = get_viewport().get_mouse_position() - _drag_preview.size * 0.5
	_on_drag_state_changed(true, -1)


func _finish_unit_drag(global_position: Vector2) -> void:
	var unit := _dragging_unit
	_dragging_unit = null
	_drag_preview.visible = false
	_on_drag_state_changed(false, -1)
	if unit == null or not is_instance_valid(unit) or not session.is_prep():
		return
	var circle_slot := _circle_wheel.slot_index_at_global(global_position)
	if circle_slot >= 0:
		if not board.try_move_unit_to_circle(unit, board.active_face, circle_slot):
			_log("配置上限です")
		return
	var bench_slot := _bench_board.slot_index_at_global(global_position)
	if bench_slot >= 0:
		board.try_move_unit_to_bench(unit, bench_slot)
		return
	if _get_sell_zone_side(global_position) >= 0:
		_on_sell_requested(unit)


func _unit_under_screen(screen_position: Vector2) -> GameUnit:
	if _circle_wheel == null:
		return null
	var circle_slot := _circle_wheel.slot_index_at_global(screen_position)
	if circle_slot >= 0:
		return board.get_placed_unit(board.active_face, circle_slot)
	var bench_slot := _bench_board.slot_index_at_global(screen_position)
	if bench_slot >= 0:
		return board.bench_units[bench_slot]
	return null


func _input(event: InputEvent) -> void:
	if _dragging_unit == null or not (event is InputEventMouseMotion):
		return
	var motion := event as InputEventMouseMotion
	_drag_preview.global_position = motion.global_position - _drag_preview.size * 0.5
	_on_drag_state_changed(true, _get_sell_zone_side(motion.global_position))


func _update_ui() -> void:
	board.board_unit_limit = session.get_board_unit_cap()
	_refresh_formation_widgets()
	call_deferred("_layout_formation_ui")
	if _run_end_active:
		battle_button.disabled = true
		back_button.disabled = true
		reroll_button.disabled = true
		exp_button.disabled = true
		input_handler.set_enabled(false)
		bottom_ui.visible = false
		action_column.visible = false
		shop_panel.visible = false
		coin_row.visible = false
		for index in shop_slots.get_child_count():
			var slot := shop_slots.get_child(index) as ShopSlotPanel
			slot.disabled = true
			slot.set_sold_out()
		_update_synergy_panel()
		return
	back_button.disabled = false
	coin_label.text = "コイン: %d" % session.coins
	var streak_text := _format_streak_text()
	streak_label.text = streak_text
	var streak_visible := not streak_text.is_empty()
	if streak_badge.visible != streak_visible:
		streak_badge.visible = streak_visible
		_request_bottom_ui_refit()
	else:
		streak_badge.visible = streak_visible
	var level := session.get_level()
	var xp_into := PlayerLevel.get_xp_into_current_level(session.experience)
	var xp_need := PlayerLevel.get_xp_needed_for_next_level(level)
	if xp_need > 0:
		exp_status_label.text = "Lv.%d\n%d/%d" % [level, xp_into, xp_need]
		exp_progress_bar.visible = true
		exp_progress_bar.max_value = float(xp_need)
		exp_progress_bar.value = float(xp_into)
	else:
		exp_status_label.text = "Lv.%d\nMAX" % level
		exp_progress_bar.visible = true
		exp_progress_bar.max_value = 1.0
		exp_progress_bar.value = 1.0
	ShopOdds.populate_current_odds_row(shop_odds_row, level)
	_fit_shop_odds_badge_width()
	if not session.is_prep() or _run_end_active:
		_hide_shop_odds_table()
	elif shop_odds_tooltip.visible:
		ShopOdds.populate_odds_grid(shop_odds_grid, level)
		call_deferred("_fit_shop_odds_tooltip_size")
	shop_lock_button.text = "🔒" if session.shop_locked else "🔓"
	shop_lock_button.disabled = not session.is_prep()
	var round_cap := session.max_round
	round_label.text = "ラウンド: %d / %d" % [mini(session.round_number, round_cap), round_cap]
	hp_label.text = "HP: %d" % session.player_hp
	var bench_count := 0
	for slot in board.bench_units:
		if slot != null:
			bench_count += 1
	bench_label.text = "ベンチ: %d / %d" % [bench_count, board.bench_units.size()]
	reroll_button.text = "更新 (%d)" % GameSession.REROLL_COST
	if session.free_rerolls > 0:
		reroll_button.text = "更新 (無料×%d)" % session.free_rerolls
	var reroll_text := reroll_button.text
	var reroll_text_changed := reroll_text != _last_reroll_button_text
	if reroll_text_changed:
		_last_reroll_button_text = reroll_text
	reroll_button.disabled = not session.is_prep() or session.shop_locked or (
		session.free_rerolls <= 0 and session.coins < GameSession.REROLL_COST
	)
	exp_button.text = "経験値+%d\n(%d)" % [GameSession.EXP_GAIN, GameSession.EXP_COST]
	exp_button.disabled = not session.is_prep() or session.coins < GameSession.EXP_COST
	battle_button.disabled = not session.is_prep() or board.get_front_unit_count() <= 0
	input_handler.set_enabled(session.is_prep())
	var show_prep_shop_ui := (
		session.is_prep()
		or session.phase == GameSession.Phase.BATTLE
		or session.phase == GameSession.Phase.ROUTE_CHOICE
	) and not _run_end_active
	bottom_ui.visible = show_prep_shop_ui
	action_column.visible = show_prep_shop_ui
	shop_panel.visible = show_prep_shop_ui
	coin_row.visible = show_prep_shop_ui
	if show_prep_shop_ui != _last_prep_shop_ui_visible:
		_last_prep_shop_ui_visible = show_prep_shop_ui
		_bottom_ui_layout_height = -1.0
		_request_bottom_ui_refit()
	for index in shop_slots.get_child_count():
		var slot := shop_slots.get_child(index) as ShopSlotPanel
		if index >= session.shop_unit_ids.size() or session.shop_unit_ids[index] < 0:
			slot.set_sold_out()
			slot.disabled = true
			continue
		var unit_id: int = session.shop_unit_ids[index]
		var data := UnitCatalog.get_unit(unit_id)
		slot.set_unit(unit_id)
		var cost: int = data["cost"]
		slot.disabled = not session.is_prep() or session.coins < cost or board.bench_is_full()
	_update_synergy_panel()
	if session.is_prep() and not _run_end_active:
		if reroll_text_changed:
			_request_bottom_ui_refit()
		else:
			call_deferred("_position_coin_row_over_shop")
