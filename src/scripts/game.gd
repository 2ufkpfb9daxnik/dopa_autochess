extends Node3D

const INCOME_FEEDBACK_DURATION := 2.0
var _action_column_width := 72.0
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

var _log_expanded := false
var _log_scroll_position := 0
var _run_end_active := false
var _run_review_mode := RunReview.Mode.MENU
var _battle := BattleStage.new()
var _combat := BattleDirector.new()
var _shop := ShopBoard.new()
var _review := RunReview.new()
var _formation := FormationControls.new()
var _pending_bottom_refit := false
var _bottom_ui_layout_height := -1.0
var _last_prep_shop_ui_visible := true
var _debug_roster_button: Button
var _debug_roster_panel: PanelContainer
var _debug_roster_grid: GridContainer
var _debug_round_spin: SpinBox
var _debug_roster_open := false
const BATTLE_SPEEDS: Array[int] = [1, 2, 4, 8]
var _battle_speed_index := 0
var _battle_speed_button: Button
var _battle_playing := false
var _battle_result: BattleResult
var _unit_inspect: UnitInspect
var _debuff_ritual: DebuffRitual
var _last_reroll_button_text := ""
var _circle_wheel: CircleWheel
var _bench_board: BenchBoard
var _action_order_bar: ActionOrderBar
var _comment_flow: CommentFlow
var _synergy_list: VBoxContainer
var _synergy_detail: PanelContainer
var _synergy_detail_body: RichTextLabel
var _synergy_open := ""
var _log_column_rect := Rect2()
var _log_body_rect := Rect2()
var _drag_preview: Control
var _drag_name_label: Label
var _drag_cost_label: Label
var _drag_stars_label: Label
var _drag_bar: ColorRect
var _split_x := 0.0
var _hover_tip: PanelContainer
var _hover_tip_label: Label

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
	_shop.setup(self)
	_review.setup(self)
	_formation.setup(self)
	_combat.setup(self)
	_setup_bottom_ui_fonts()
	exp_button.custom_minimum_size = Vector2(0, BOTTOM_BUTTON_HEIGHT)
	reroll_button.custom_minimum_size = Vector2(0, BOTTOM_BUTTON_HEIGHT)
	action_column.custom_minimum_size.x = 0
	_battle.mount(self, $CanvasLayer, camera, board, units_root, $DirectionalLight3D)
	_setup_formation_ui()
	_mount_side_controls()
	_battle.setup_camera()
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
	review_board_button.pressed.connect(func() -> void: _review.enter(RunReview.Mode.BOARD))
	review_synergy_button.pressed.connect(func() -> void: _review.enter(RunReview.Mode.SYNERGY))
	review_log_button.pressed.connect(func() -> void: _review.enter(RunReview.Mode.LOG))
	review_stats_button.pressed.connect(func() -> void: _review.enter(RunReview.Mode.STATS))
	title_return_button.pressed.connect(_review.leave_to_title)
	back_to_run_end_button.pressed.connect(_review.return_to_menu)
	for index in route_buttons.size():
		route_buttons[index].pressed.connect(func() -> void: _on_route_selected(index))
	_log("準備フェーズ開始")
	GameAudio.play_construction()
	call_deferred("_bind_button_confirms")
	_shop.setup_odds_table()
	_setup_log_panel()
	call_deferred("_finish_startup_layout")


func _bind_button_confirms() -> void:
	GameAudio.bind_buttons(self)


func _get_bottom_ui_width() -> float:
	return _action_column_width + BOTTOM_BAR_GAP + _shop.panel_width()


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
	shop_lock_button.custom_minimum_size = Vector2(0, 32)
	if exp_button.get_parent() != exp_box:
		exp_button.get_parent().remove_child(exp_button)
		exp_box.add_child(exp_button)
	exp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_column.add_child(shop_odds_badge)
	action_column.add_child(shop_lock_button)
	var status_badges: Array[PanelContainer] = [round_badge, hp_badge, streak_badge]
	for badge in status_badges:
		var badge_parent := badge.get_parent()
		if badge_parent != null:
			badge_parent.remove_child(badge)
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_column.add_child(badge)
		var status_label := badge.get_child(0) as Label
		if status_label != null:
			status_label.add_theme_font_size_override("font_size", 14)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var side_buttons: Array[Button] = [battle_button, back_button]
	for button in side_buttons:
		var button_parent := button.get_parent()
		if button_parent != null:
			button_parent.remove_child(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 36)
		action_column.add_child(button)
	var ordered: Array[Control] = [
		shop_odds_badge,
		shop_lock_button,
		exp_hud_badge,
		reroll_button,
		round_badge,
		hp_badge,
		streak_badge,
		battle_button,
		back_button,
	]
	for index in ordered.size():
		action_column.move_child(ordered[index], index)
	_mount_battle_speed_button()
	top_bar.visible = false
	_mount_debug_grants()
	_mount_audio_settings()
	var ui := $CanvasLayer/UI as Control
	action_column.get_parent().remove_child(action_column)
	ui.add_child(action_column)
	action_column.mouse_filter = Control.MOUSE_FILTER_STOP
	action_column.z_index = 6
	action_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	_setup_column_hover_tips()


func _mount_audio_settings() -> void:
	var settings := AudioSettings.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.z_index = 4
	action_column.add_child(settings)
	if _debug_roster_button != null:
		action_column.move_child(settings, _debug_roster_button.get_index())


func _mount_battle_speed_button() -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_cycle_battle_speed)
	action_column.add_child(button)
	action_column.move_child(button, battle_button.get_index())
	_battle_speed_button = button
	_refresh_battle_speed_button()


func _cycle_battle_speed() -> void:
	_battle_speed_index = (_battle_speed_index + 1) % BATTLE_SPEEDS.size()
	_refresh_battle_speed_button()
	_apply_battle_time_scale()


func _refresh_battle_speed_button() -> void:
	if _battle_speed_button == null:
		return
	_battle_speed_button.text = "×%d" % BATTLE_SPEEDS[_battle_speed_index]


func _apply_battle_time_scale() -> void:
	Engine.time_scale = float(BATTLE_SPEEDS[_battle_speed_index]) if _battle_playing else 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _mount_debug_grants() -> void:
	if not OS.is_debug_build():
		return
	var button := Button.new()
	button.text = "デバッグ"
	button.custom_minimum_size = Vector2(0, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_toggle_debug_roster)
	action_column.add_child(button)
	_debug_roster_button = button
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 18
	_apply_hud_badge_style(panel)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var round_row := HBoxContainer.new()
	round_row.add_theme_constant_override("separation", 6)
	box.add_child(round_row)
	var round_label := Label.new()
	round_label.text = "ラウンド"
	round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	round_row.add_child(round_label)
	var spin := SpinBox.new()
	spin.min_value = 1.0
	spin.max_value = 99.0
	spin.step = 1.0
	spin.rounded = true
	spin.value = 1.0
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_row.add_child(spin)
	_debug_round_spin = spin
	var jump := Button.new()
	jump.text = "移動"
	jump.pressed.connect(_jump_debug_round)
	round_row.add_child(jump)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)
	($CanvasLayer/UI as Control).add_child(panel)
	_debug_roster_panel = panel
	_debug_roster_grid = grid
	for unit in UnitCatalog.UNITS:
		var unit_id := int(unit["id"])
		var card := ShopBoard.SLOT_SCENE.instantiate() as ShopSlotPanel
		if card == null:
			continue
		grid.add_child(card)
		card.set_unit(unit_id)
		card.pressed.connect(_grant_debug_unit.bind(unit_id))


func _toggle_debug_roster() -> void:
	_set_debug_roster_open(not _debug_roster_open)


func _set_debug_roster_open(open: bool) -> void:
	if _debug_roster_panel == null:
		return
	_debug_roster_open = open and session.is_prep() and not _run_end_active
	_debug_roster_panel.visible = _debug_roster_open
	if _debug_roster_button != null:
		_debug_roster_button.text = "閉じる" if _debug_roster_open else "デバッグ"
	if _debug_roster_open:
		if _debug_round_spin != null:
			_debug_round_spin.value = float(session.round_number)
		_place_debug_roster()


func _place_debug_roster() -> void:
	if _debug_roster_panel == null or not _debug_roster_open:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 8.0
	var panel_pos := Vector2(margin, margin)
	var panel_size := Vector2(maxf(160.0, _split_x - margin * 2.0), maxf(160.0, viewport_size.y - margin * 2.0))
	_debug_roster_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_debug_roster_panel.position = panel_pos
	_debug_roster_panel.size = panel_size
	var card := _shop.slot_size
	if card.x < 8.0 or card.y < 8.0:
		card = Vector2(ShopBoard.LAYOUT_SLOT_WIDTH, ShopBoard.LAYOUT_SLOT_WIDTH / ShopBoard.FRAME_ASPECT)
	var gap := 2.0
	var inner_w := maxf(card.x, panel_size.x - 28.0)
	var columns := maxi(1, int((inner_w + gap) / (card.x + gap)))
	_debug_roster_grid.columns = columns
	for child in _debug_roster_grid.get_children():
		var slot := child as ShopSlotPanel
		if slot == null:
			continue
		slot.set_card_size(card)
		slot.set_text_scale(1.0)


func _jump_debug_round() -> void:
	if _debug_round_spin == null or not OS.is_debug_build() or not session.is_prep() or _run_end_active:
		return
	var target := int(_debug_round_spin.value)
	session.debug_jump_round(target)
	_log("ラウンド %d に移動した" % session.round_number)


func _grant_debug_unit(unit_id: int) -> void:
	if not OS.is_debug_build() or not session.is_prep() or _run_end_active:
		return
	var data := UnitCatalog.get_unit(unit_id)
	if data.is_empty():
		return
	var slot := board.find_empty_bench_slot()
	if slot < 0:
		_log("ベンチが満杯です")
		return
	var unit := GameUnit.create(unit_id, 1)
	units_root.add_child(unit)
	if not board.place_on_bench(unit, slot):
		unit.queue_free()
		return
	GameAudio.play_buy()
	_log("%s を取り出した" % str(data["name"]))


func _setup_column_hover_tips() -> void:
	_hover_tip = PanelContainer.new()
	_hover_tip.visible = false
	_hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tip.z_index = 40
	_apply_hud_badge_style(_hover_tip)
	_hover_tip_label = Label.new()
	_hover_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_tip_label.custom_minimum_size = Vector2(240, 0)
	_hover_tip_label.add_theme_font_size_override("font_size", 14)
	_hover_tip_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	_hover_tip.add_child(_hover_tip_label)
	($CanvasLayer/UI as Control).add_child(_hover_tip)
	_bind_hover_tip(hp_badge, "0になったらゲームオーバー。")
	_bind_hover_tip(exp_button, "経験値があがり、レベルが上がるとサークルに置くことができるキャラクターの数が増える。")
	_bind_hover_tip(reroll_button, "ショップを更新する。")


func _bind_hover_tip(control: Control, text: String) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in control.get_children():
		if child is Control and child != exp_button:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.mouse_entered.connect(func() -> void: _show_hover_tip(control, text))
	control.mouse_exited.connect(_hide_hover_tip)


func _show_hover_tip(anchor: Control, text: String) -> void:
	if _hover_tip == null:
		return
	_hover_tip_label.text = text
	_hover_tip.visible = true
	_hover_tip.reset_size()
	var content_size := _hover_tip_label.get_minimum_size()
	var margins := _get_panel_content_margins(_hover_tip)
	var fitted := content_size + Vector2(margins.x + margins.z, margins.y + margins.w)
	fitted.x = maxf(fitted.x, 240.0)
	_hover_tip.custom_minimum_size = fitted
	_hover_tip.size = fitted
	var anchor_rect := anchor.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	var x := anchor_rect.position.x - fitted.x - 8.0
	var y := anchor_rect.get_center().y - fitted.y * 0.5
	if x < 8.0:
		x = anchor_rect.end.x + 8.0
	x = clampf(x, 8.0, maxf(8.0, viewport_size.x - fitted.x - 8.0))
	y = clampf(y, 8.0, maxf(8.0, viewport_size.y - fitted.y - 8.0))
	_hover_tip.global_position = Vector2(x, y)


func _hide_hover_tip() -> void:
	if _hover_tip != null:
		_hover_tip.visible = false


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


func _format_streak_text() -> String:
	if session.win_streak > 0:
		return "連勝%d回" % session.win_streak
	if session.loss_streak > 0:
		return "連敗%d回" % session.loss_streak
	return ""


func _setup_log_panel() -> void:
	event_log_panel.visible = false
	event_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	shop_panel.custom_minimum_size.x = _shop.panel_width()
	_layout_formation_ui()
	if shop_odds_tooltip.visible:
		_shop.call_deferred("_fit_tooltip_size")
	if session.is_prep() and not _run_end_active:
		_shop.fit_badge_width()


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
	event_log_panel.visible = false


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


func _log(text: String) -> void:
	event_log.add(text)


func _refresh_event_log(text: String = "") -> void:
	if _comment_flow == null or text.is_empty():
		return
	_comment_flow.push(text)


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
			if not session.is_prep() or _formation.is_dragging():
				return
			var hover_unit := _formation.unit_under_screen(action.screen_position)
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
	GameAudio.play_buy()
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
	_shop.hide_odds_table()
	_log("戦闘開始 (ラウンド %d)" % session.round_number)
	var secret_battle := session.extended_mode and session.round_number == session.max_round
	GameAudio.play_battle(secret_battle, _battle.is_clock_tower())
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
	_battle_playing = true
	_apply_battle_time_scale()
	var outcome: Dictionary = await _combat.play()
	_battle_playing = false
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	var battle_won: bool = bool(outcome.get("won", false))
	var remaining_enemies: int = int(outcome.get("remaining", 0))
	var hp_before := session.player_hp
	var level_before := session.get_level()
	session.finish_battle(battle_won, remaining_enemies)
	if battle_won:
		_log("戦闘勝利 (経験値 +%d)" % GameSession.ROUND_END_FREE_XP)
	else:
		var fought_round := session.round_number - 1
		var damage := PlayerHp.calc_loss_damage(fought_round, remaining_enemies)
		_log("戦闘敗北 (HP -%d, 残り %d)" % [damage, session.player_hp])
	battle_overlay.visible = false
	board.set_battle_mode(false)
	_battle.reroll()
	if _battle_result != null:
		_battle_result.open(battle_won, _battle_result_body(battle_won, hp_before, level_before), hp_before, session.player_hp)
	GameAudio.play_result(battle_won)
	if not is_inside_tree():
		return
	if session.is_run_over():
		if _battle_result != null:
			_battle_result.show_routes(PackedStringArray(["確認"]), func(_index: int) -> void:
				_battle_result.close()
				if session.run_end_reason == GameSession.RunEndReason.DEFEAT:
					GameAudio.play_defeat()
				else:
					GameAudio.play_after_clear()
				_review.show_end_screen()
			)
		else:
			_review.show_end_screen()
		return
	if session.phase == GameSession.Phase.EXTENSION_CHOICE:
		extension_overlay.visible = false
		input_handler.set_enabled(false)
		prep_blocker.visible = true
		if _battle_result != null:
			_battle_result.show_routes(PackedStringArray(["延長する", "ここで終了"]), func(index: int) -> void:
				if index == 0:
					_on_continue_extension()
				else:
					_on_end_run()
			)
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


func _battle_result_body(won: bool, hp_before: int, level_before: int) -> String:
	var hp_after := session.player_hp
	var lines: PackedStringArray = []
	if won:
		var hp_line := "HP  %d → %d" % [hp_before, hp_after]
		if hp_after != hp_before:
			var delta := hp_after - hp_before
			hp_line += "  (%s%d)" % ["+" if delta > 0 else "", delta]
		lines.append(hp_line)
	var xp_line := "経験値 +%d" % GameSession.ROUND_END_FREE_XP
	var level_after := session.get_level()
	if level_after > level_before:
		xp_line += "   Lv.%d" % level_after
	lines.append(xp_line)
	if won:
		lines.append("連勝 %d" % session.win_streak)
	else:
		lines.append("連敗 %d" % session.loss_streak)
	if session.is_run_over():
		lines.append("")
		lines.append("次のラウンドなし")
		return "\n".join(lines)
	var income := RoundIncome.calc_round_start_income(
		session.coins_at_last_round_end,
		session.get_level(),
		session.get_active_streak(),
		session.round_number
	)
	lines.append("")
	lines.append("次の利子 %d" % int(income["holding"]))
	lines.append("次の収入 +%d" % int(income["total"]))
	lines.append("基本 %d / 利子 %d / 連勝敗 %d / ラウンド %d" % [
		int(income["base"]),
		int(income["holding"]),
		int(income["streak"]),
		int(income["round"]),
	])
	return "\n".join(lines)


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
	var lines := PackedStringArray()
	for index in session.route_options.size():
		var option: Dictionary = session.route_options[index]
		lines.append("%s\n%s\n%s" % [
			option["strength_label"],
			option["enemy_label"],
			option["reward_label"],
		])
	if _battle_result != null and _battle_result.visible:
		route_overlay.visible = false
		_battle_result.show_routes(lines, _on_route_selected)
		prep_blocker.visible = true
		input_handler.set_enabled(false)
		return
	route_title_label.text = "ラウンド %d — ルートを選択" % session.round_number
	for index in route_buttons.size():
		if index >= lines.size():
			route_buttons[index].visible = false
			continue
		route_buttons[index].visible = true
		route_buttons[index].text = lines[index]
	route_overlay.visible = true
	prep_blocker.visible = true
	input_handler.set_enabled(false)


func _on_route_selected(index: int) -> void:
	var route := session.select_route(index)
	if route.is_empty():
		return
	if _battle_result != null:
		_battle_result.close()
	GameAudio.play_construction()
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
	if _battle_result != null and _battle_result.visible:
		_battle_result.show_clear_banner()
		_battle_result.show_routes(PackedStringArray(["確認"]), func(_index: int) -> void:
			_battle_result.close()
			_review.show_end_screen()
		)
		return
	_review.show_end_screen()


func _on_run_completed() -> void:
	GameAudio.play_after_clear()


func _on_run_failed() -> void:
	GameAudio.play_defeat()


func _set_synergy_panel_review_mode(_active: bool) -> void:
	_layout_log_column()


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
		GameAudio.play_fusion()


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


func _setup_synergy_list() -> void:
	synergy_label.visible = false
	var scroll := synergy_label.get_parent() as ScrollContainer
	_synergy_list = VBoxContainer.new()
	_synergy_list.name = "SynergyList"
	_synergy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_synergy_list)
	var ui := $CanvasLayer/UI
	_synergy_detail = PanelContainer.new()
	_synergy_detail.name = "SynergyDetail"
	_synergy_detail.visible = false
	_synergy_detail.z_index = 30
	_synergy_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	_synergy_detail.add_child(margin)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(280, 0)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(detail_scroll)
	_synergy_detail_body = RichTextLabel.new()
	_synergy_detail_body.bbcode_enabled = true
	_synergy_detail_body.fit_content = true
	_synergy_detail_body.scroll_active = false
	_synergy_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_detail_body.custom_minimum_size = Vector2(280, 0)
	_synergy_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_detail_body.add_theme_font_size_override("normal_font_size", 15)
	detail_scroll.add_child(_synergy_detail_body)
	ui.add_child(_synergy_detail)


func _update_synergy_panel() -> void:
	if _synergy_list == null:
		return
	var entries := SynergyTracker.list_synergies(board.get_circle_units())
	for child in _synergy_list.get_children():
		_synergy_list.remove_child(child)
		child.free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "なし"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		_synergy_list.add_child(empty)
		_close_synergy_detail()
		return
	var still_open := false
	for entry in entries:
		if str(entry["name"]) == _synergy_open:
			still_open = true
		_synergy_list.add_child(_make_synergy_row(entry))
	if _synergy_open.is_empty():
		return
	if not still_open:
		_close_synergy_detail()
		return
	_fill_synergy_detail(_synergy_open, entries)
	_place_synergy_detail()


func _make_synergy_row(entry: Dictionary) -> Button:
	var synergy_name := str(entry["name"])
	var active := bool(entry["active"])
	var color: Color = entry["color"]
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_text = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.text = "%s\n%d人  %d段階" % [synergy_name, int(entry["count"]), int(entry["stage_count"])]
	button.add_theme_font_size_override("font_size", 13)
	var text_color := Color(1, 1, 1, 1.0 if active else 0.48)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.34 if active else 0.12)
	style.border_color = Color(color.r, color.g, color.b, 1.0 if active else 0.4)
	style.border_width_left = 5
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_left = 3
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color.a = minf(1.0, style.bg_color.a + 0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(_toggle_synergy_detail.bind(synergy_name))
	return button


func _toggle_synergy_detail(synergy_name: String) -> void:
	if _synergy_detail.visible and _synergy_open == synergy_name:
		_close_synergy_detail()
		return
	_synergy_open = synergy_name
	_fill_synergy_detail(synergy_name, SynergyTracker.list_synergies(board.get_circle_units()))
	_synergy_detail.visible = true
	_place_synergy_detail()


func _close_synergy_detail() -> void:
	_synergy_open = ""
	if _synergy_detail != null:
		_synergy_detail.visible = false


func _fill_synergy_detail(synergy_name: String, entries: Array[Dictionary]) -> void:
	var entry := {}
	for candidate in entries:
		if str(candidate["name"]) == synergy_name:
			entry = candidate
			break
	if entry.is_empty():
		_close_synergy_detail()
		return
	var color: Color = entry["color"]
	var lines: PackedStringArray = []
	lines.append("[color=#%s][b]%s[/b][/color]" % [color.to_html(false), synergy_name])
	lines.append("%d人 / %d段階" % [int(entry["count"]), int(entry["stage_count"])])
	var summary := str(entry.get("summary", "")).strip_edges()
	if not summary.is_empty():
		lines.append("")
		lines.append(summary)
	var stages: Array = entry.get("stages", [])
	if not stages.is_empty():
		lines.append("")
		lines.append("[b]段階[/b]")
		var reached := int(entry["tier"])
		for index in stages.size():
			var stage: Dictionary = stages[index]
			var row := "%d人  %s" % [int(stage.get("count", 0)), str(stage.get("effect", ""))]
			if str(stage.get("effect", "")).is_empty():
				row = "%d人" % int(stage.get("count", 0))
			if index == reached - 1:
				lines.append("[color=#%s]%s  ← 現在[/color]" % [color.to_html(false), row])
			elif index < reached:
				lines.append("[color=#ffffffaa]%s[/color]" % row)
			else:
				lines.append("[color=#ffffff77]%s[/color]" % row)
	_synergy_detail_body.text = "\n".join(lines)


func _place_synergy_detail() -> void:
	if _synergy_detail == null or not _synergy_detail.visible or synergy_panel == null:
		return
	var height := minf(460.0, maxf(160.0, synergy_panel.size.y))
	_synergy_detail.position = synergy_panel.position + Vector2(synergy_panel.size.x + 8.0, 0.0)
	_synergy_detail.size = Vector2(320.0, height)


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
	icon.name = "DragIcon"
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
	_comment_flow = CommentFlow.new()
	_comment_flow.name = "CommentFlow"
	_comment_flow.z_index = 0
	ui.add_child(_comment_flow)
	ui.move_child(_comment_flow, 0)
	_battle_result = BattleResult.new()
	_battle_result.name = "BattleResult"
	_battle_result.z_index = 100
	_battle_result.modal_changed = func(active: bool) -> void:
		_shop.set_modal_blocked(active)
	ui.add_child(_battle_result)
	_unit_inspect = UnitInspect.new()
	_unit_inspect.name = "UnitInspect"
	ui.add_child(_unit_inspect)
	_setup_synergy_list()
	ui.add_child(_drag_preview)
	_circle_wheel.rotate_steps.connect(func(steps: int) -> void: board.apply_spin_commit(steps))
	_circle_wheel.visual_shift_changed.connect(func(shift: float) -> void: board.set_visual_shift(shift))
	_circle_wheel.center_pressed.connect(_formation.on_center_pressed)
	_circle_wheel.unit_drag_started.connect(_formation.on_circle_drag_started)
	_circle_wheel.unit_drag_finished.connect(_formation.on_circle_drag_finished)
	_circle_wheel.slot_move_requested.connect(_formation.on_circle_slot_move)
	_circle_wheel.unit_clicked.connect(_formation.on_circle_unit_clicked)
	_circle_wheel.debuff_cleanse_requested.connect(_open_debuff_ritual)
	_debuff_ritual = DebuffRitual.new()
	_debuff_ritual.name = "DebuffRitual"
	_debuff_ritual.cleared.connect(_on_debuff_cleared)
	ui.add_child(_debuff_ritual)
	_bench_board.unit_drag_started.connect(_formation.on_bench_drag_started)
	_bench_board.unit_drag_finished.connect(_formation.on_bench_drag_finished)
	_bench_board.slot_clicked.connect(_formation.on_bench_slot_clicked)
	if not get_viewport().size_changed.is_connected(_layout_formation_ui):
		get_viewport().size_changed.connect(_layout_formation_ui)


func _open_debuff_ritual(slot_index: int) -> void:
	var unit := board.get_placed_unit(board.active_face, slot_index)
	if unit == null or not unit.debuffed or _debuff_ritual == null:
		return
	_debuff_ritual.open_for(unit)


func _on_debuff_cleared(unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_combat.cleanse_debuff(unit)
	_log("%s のデバフを解除した" % unit.get_display_name())
	_formation.refresh_widgets()


func _layout_formation_ui() -> void:
	if _circle_wheel == null or _battle.viewport_container == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var top := 8.0
	var bottom := viewport_size.y - 8.0
	var left_h := bottom - top
	_battle.view_height = left_h * 0.58
	var battle_bottom := top + _battle.view_height
	var battle_w := _battle.column_width(battle_bottom)
	_fit_action_column_width()
	var cards_w := ShopBoard.LAYOUT_SLOT_WIDTH * float(ShopBoard.COLUMNS) + 8.0 * float(ShopBoard.COLUMNS - 1)
	var shop_w := _action_column_width + 8.0 + cards_w
	var shop_x := viewport_size.x - 8.0 - shop_w
	var battle_x := shop_x - 8.0 - battle_w
	var log_x := 8.0
	var log_w := maxf(0.0, battle_x - 8.0 - log_x)
	_split_x = shop_x - 8.0
	_log_column_rect = Rect2(log_x, top, log_w, bottom - top)
	_battle.battle_rect = Rect2(battle_x, top, battle_w, _battle.view_height)
	_battle.place(viewport_size)
	var circle_top := _battle.battle_rect.end.y + 4.0
	var circle_bottom := viewport_size.y - 2.0
	var diameter := minf(battle_w, maxf(96.0, circle_bottom - circle_top))
	var wheel_size := diameter + CircleWheel.RIM_GRAB * 2.0
	var wheel_center := Vector2(battle_x + battle_w * 0.5, circle_bottom - diameter * 0.5)
	_circle_wheel.z_index = 9
	_circle_wheel.position = wheel_center - Vector2(wheel_size, wheel_size) * 0.5
	_circle_wheel.size = Vector2(wheel_size, wheel_size)
	var right_x := shop_x
	var right_bottom := bottom
	var right_h := right_bottom - top
	var shop_area_h := right_h * 0.4
	var bench_top := top + shop_area_h + 6.0
	var bench_h := right_bottom - bench_top
	var cards_x := right_x + _action_column_width + 8.0
	_shop.place(Rect2(cards_x, top, cards_w, shop_area_h))
	_bench_board.position = Vector2(cards_x - 6.0, bench_top)
	_bench_board.size = Vector2(_shop.panel_width() + 12.0, bench_h)
	_place_sell_zone(Rect2(_bench_board.position, _bench_board.size))
	_place_side_column(right_x)
	_place_debug_roster()
	_layout_log_column()
	_layout_comment_flow()
	battle_overlay.anchor_left = 0.0
	battle_overlay.anchor_right = 0.0
	battle_overlay.anchor_top = 0.0
	battle_overlay.anchor_bottom = 0.0
	battle_overlay.offset_left = _battle.battle_rect.position.x + _battle.battle_rect.size.x * 0.5 - 90.0
	battle_overlay.offset_right = battle_overlay.offset_left + 180.0
	battle_overlay.offset_top = _battle.battle_rect.position.y + _battle.battle_rect.size.y * 0.32
	battle_overlay.offset_bottom = battle_overlay.offset_top + 52.0
	income_overlay.anchor_left = 0.0
	income_overlay.anchor_right = 0.0
	income_overlay.anchor_top = 0.0
	income_overlay.anchor_bottom = 0.0
	income_overlay.offset_left = _battle.battle_rect.position.x + _battle.battle_rect.size.x * 0.5 - 130.0
	income_overlay.offset_right = income_overlay.offset_left + 260.0
	income_overlay.offset_top = _battle.battle_rect.position.y + 10.0
	income_overlay.offset_bottom = income_overlay.offset_top + 78.0


func _layout_log_column() -> void:
	if synergy_panel == null or _action_order_bar == null:
		return
	var column := _log_column_rect
	if column.size.x <= 1.0 or column.size.y <= 1.0:
		return
	var gap := 6.0
	var review_synergy := _run_review_mode == RunReview.Mode.SYNERGY
	var synergy_ratio := 0.64 if review_synergy else 0.42
	var synergy_h := maxf(96.0, (column.size.y - gap) * synergy_ratio)
	synergy_h = minf(synergy_h, column.size.y - gap - 96.0)
	var action_h := maxf(96.0, column.size.y - gap - synergy_h)
	var y := column.position.y
	_action_order_bar.z_index = 8
	_action_order_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_action_order_bar.position = Vector2(column.position.x, y)
	_action_order_bar.size = Vector2(column.size.x, action_h)
	y += action_h + gap
	_place_control(synergy_panel, Rect2(column.position.x, y, column.size.x, maxf(96.0, column.end.y - y)))
	var synergy_scroll := synergy_label.get_parent() as ScrollContainer
	if synergy_scroll != null:
		synergy_scroll.custom_minimum_size = Vector2(maxf(80.0, column.size.x - 24.0), 0.0)
	_place_synergy_detail()


func _layout_comment_flow() -> void:
	if _comment_flow == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_comment_flow.z_index = 0
	if _comment_flow.get_parent() != null:
		_comment_flow.get_parent().move_child(_comment_flow, 0)
	_place_control(_comment_flow, Rect2(Vector2.ZERO, viewport_size))
	var hole := _battle.battle_rect
	if _battle.viewport_container != null:
		hole = _battle.viewport_container.get_global_rect()
	_comment_flow.set_hole(hole)


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


func _fit_action_column_width() -> void:
	var width_buttons: Array[Button] = [exp_button, reroll_button, battle_button, back_button, shop_lock_button]
	if _battle_speed_button != null:
		width_buttons.append(_battle_speed_button)
	for button in width_buttons:
		button.custom_minimum_size.x = 0
	action_column.custom_minimum_size.x = 0
	var width := action_column.get_combined_minimum_size().x
	_action_column_width = maxf(36.0, ceil(width))


func _place_sell_zone(bench_rect: Rect2) -> void:
	var zone := sell_drag_hint_right
	zone.z_index = 30
	zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
	zone.offset_left = bench_rect.position.x - ShopBoard.SELL_ZONE_WIDTH
	zone.offset_right = bench_rect.position.x
	zone.offset_top = bench_rect.position.y
	zone.offset_bottom = bench_rect.end.y
	var sell_label := zone.get_node_or_null("SellDragLabelRight") as Label
	if sell_label != null:
		sell_label.text = "売却"


func _place_side_column(column_x: float) -> void:
	action_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	action_column.position = Vector2(column_x, bottom_ui.offset_top)
	action_column.custom_minimum_size = Vector2(_action_column_width, 0)
	var column_h := action_column.get_combined_minimum_size().y
	action_column.size = Vector2(_action_column_width, maxf(column_h, 1.0))


func _process(_delta: float) -> void:
	_shop.update_hover()


func _input(event: InputEvent) -> void:
	_formation.handle_mouse_motion(event)


func _update_ui() -> void:
	board.board_unit_limit = session.get_board_unit_cap()
	_formation.refresh_widgets()
	call_deferred("_layout_formation_ui")
	if _run_end_active:
		_set_debug_roster_open(false)
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
	_shop.fit_badge_width()
	if not session.is_prep() or _run_end_active:
		_shop.hide_odds_table()
	elif shop_odds_tooltip.visible:
		ShopOdds.populate_odds_grid(shop_odds_grid, level)
		_shop.call_deferred("_fit_tooltip_size")
	shop_lock_button.text = "🔒" if session.shop_locked else "🔓"
	shop_lock_button.disabled = not session.is_prep()
	var round_cap := session.max_round
	round_label.text = "ラウンド: %d / %d" % [mini(session.round_number, round_cap), round_cap]
	hp_label.text = "HP: %d" % session.player_hp
	var bench_count := 0
	for slot in board.bench_units:
		if slot != null:
			bench_count += 1
	if _bench_board != null:
		_bench_board.set_count(bench_count, board.bench_units.size())
	bench_badge.visible = false
	reroll_button.text = "更新 (%d)" % GameSession.REROLL_COST
	if session.free_rerolls > 0:
		reroll_button.text = "更新 (無料×%d)" % session.free_rerolls
	var reroll_text := reroll_button.text
	var reroll_text_changed := reroll_text != _last_reroll_button_text
	if reroll_text_changed:
		_last_reroll_button_text = reroll_text
	var economy_open := session.is_prep() or session.phase == GameSession.Phase.BATTLE
	reroll_button.disabled = not economy_open or session.shop_locked or (
		session.free_rerolls <= 0 and session.coins < GameSession.REROLL_COST
	)
	exp_button.text = "経験値+%d\n(%d)" % [GameSession.EXP_GAIN, GameSession.EXP_COST]
	exp_button.disabled = not economy_open or session.coins < GameSession.EXP_COST
	exp_button.mouse_filter = Control.MOUSE_FILTER_STOP
	reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_button.disabled = not session.is_prep() or board.get_front_unit_count() <= 0
	if _debug_roster_button != null:
		_debug_roster_button.disabled = not session.is_prep()
		if not session.is_prep():
			_set_debug_roster_open(false)
	if _debug_roster_grid != null:
		var debug_blocked := not session.is_prep() or board.bench_is_full()
		for child in _debug_roster_grid.get_children():
			var card := child as BaseButton
			if card != null:
				card.disabled = debug_blocked
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
