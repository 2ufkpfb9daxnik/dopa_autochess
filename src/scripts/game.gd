extends Node3D

const INCOME_FEEDBACK_DURATION := 2.0
var _action_column_width := 72.0
const BOTTOM_BUTTON_HEIGHT := 80
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
var _debug_show_relics := false
var _debug_tab_units: Button
var _debug_tab_relics: Button
var _debug_relic_hint: Label
const BATTLE_SPEEDS: Array[int] = [1, 2, 4, 8]
var _battle_speed_index := 0
var _battle_speed_button: Button
var _battle_playing := false
var _battle_restart_requested := false
var _battle_result: BattleResult
var _unit_inspect: UnitInspect
var _debuff_ritual: DebuffRitual
var _relic_pick: RelicPick
var _relic_pick_active := false
var _relic_tray: RelicTray
var _relic_synth: RelicSynth
## レリックを使う途中で、対象（キャラクターまたはレリック）を待っているレリックの uid。
var _relic_use_uid := -1
var _relic_use_mode := ""
var _last_reroll_button_text := ""
var _hp_exp_button: Button
var _flushing_relic_units := false
var _circle_wheel: CircleWheel
var _bench_board: BenchBoard
var _overflow_pile: OverflowPile
var _board_notice: BoardNotice
var _exp_hint_arrow: ExpHintArrow
var _formation_banner: FormationBanner
var _action_order_bar: ActionOrderBar
var _comment_flow: CommentFlow
const NOTICE_CIRCLE_CAP := "プレイヤーレベルより多い人数のキャラクターをサークルに入れることはできません。経験値を購入してください。"
const NOTICE_BENCH_FULL := "ベンチの空きがありません。"
const NOTICE_OVERFLOW := "キャラクターが溢れています！戦闘を開始できません。"
var _synergy_list: VBoxContainer
var _synergy_detail: PanelContainer
var _synergy_detail_body: RichTextLabel
var _synergy_members_flow: HFlowContainer
var _synergy_watch_check: CheckBox
var _synergy_open := ""
var _synergy_pointer_over_detail := false
var _synergy_close_left := -1.0
const SYNERGY_CLOSE_GRACE := 0.2
const SYNERGY_MEMBER_ICON := 40.0
## チェックしたシナジー名。ショップ該当枠の強調に使う。
var _watched_synergies: Dictionary = {}
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
var _demo_mode := false
var _tutorial_mode := false
var _tutorial: Tutorial
var _demo_exiting := false
var _demo_leave_started := false
var _demo_overlay: Control

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
@onready var run_end_vbox: VBoxContainer = $CanvasLayer/UI/RunEndOverlay/RunEndVBox
@onready var run_end_title: Label = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/RunEndTitle
@onready var run_end_summary: Label = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/RunEndSummary
@onready var run_end_review_buttons: GridContainer = $CanvasLayer/UI/RunEndOverlay/RunEndVBox/ReviewButtons
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
var _run_end_free_root: Control
var _run_end_diagonal := false
var _run_end_marquee_rows: Array[Label] = []
var _run_end_marquee_centers: Array[Vector2] = []
var _run_end_marquee_offset := 0.0
var _run_end_marquee_cycle := 1.0
var _run_end_marquee_angle := 0.0
var _run_end_marquee_dir := Vector2.RIGHT
var _run_end_marquee_box := Vector2.ZERO
var _run_end_title_phrase := ""
var _run_end_stats_scroll: ScrollContainer
var _run_end_stats_body: Label
const RUN_END_MARQUEE_SPEED := 180.0
const RUN_END_MARQUEE_ROWS := 5
const RUN_END_FRONT_Z := 80
const RUN_END_MARQUEE_Z := 5
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
	_demo_mode = PlayDemo.consume_pending(get_tree())
	_tutorial_mode = Tutorial.consume_pending(get_tree())
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
	if _demo_mode:
		_log("PLAY DEMO")
		GameAudio.set_se_suppressed(true)
		GameAudio.play_demo_bgm()
	elif _tutorial_mode:
		_log("チュートリアル")
		GameAudio.play_construction()
	else:
		_log("準備フェーズ開始")
		GameAudio.play_construction()
	call_deferred("_bind_button_confirms")
	_shop.setup_odds_table()
	_setup_log_panel()
	call_deferred("_finish_startup_layout")
	if _demo_mode:
		call_deferred("_begin_demo_mode")


func _bind_button_confirms() -> void:
	GameAudio.bind_buttons(self)


func _get_bottom_ui_width() -> float:
	return _action_column_width + BOTTOM_BAR_GAP + _shop.panel_width()


func _finish_startup_layout() -> void:
	_update_ui()
	await _fit_bottom_ui_layout()
	_layout_formation_ui()
	if _tutorial_mode:
		_begin_tutorial()


func _begin_tutorial() -> void:
	if not _tutorial_mode or _tutorial != null:
		return
	_tutorial = Tutorial.new()
	_tutorial.start(self)


func _begin_demo_mode() -> void:
	if not _demo_mode or _demo_exiting:
		return
	_mount_demo_overlay()
	_apply_demo_chrome()
	await _run_demo_loop()


func _mount_demo_overlay() -> void:
	if _demo_overlay != null:
		return
	_demo_overlay = PlayDemo.make_overlay(_exit_demo_to_title)
	($CanvasLayer/UI as Control).add_child(_demo_overlay)


func _apply_demo_chrome() -> void:
	prep_blocker.visible = false
	battle_overlay.visible = false
	income_overlay.visible = false
	extension_overlay.visible = false
	route_overlay.visible = false
	run_end_overlay.visible = false
	run_end_review_bar.visible = false
	run_stats_panel.visible = false
	## ショップは見せる。アクション列は DEMO マーキーに置き換える。
	bottom_ui.visible = true
	shop_panel.visible = true
	coin_row.visible = true
	action_column.visible = false
	battle_button.visible = false
	back_button.visible = false
	if _battle_speed_button != null:
		_battle_speed_button.visible = false
	if _debug_roster_button != null:
		_debug_roster_button.visible = false
	if _debug_roster_panel != null:
		_debug_roster_panel.visible = false
	if _hp_exp_button != null:
		_hp_exp_button.visible = false
	reroll_button.visible = false
	exp_button.visible = false
	input_handler.set_enabled(false)
	_shop.set_modal_blocked(true)
	_shop.hide_odds_table()
	if _circle_wheel != null:
		_circle_wheel.set_unit_drag_enabled(false)
		_circle_wheel.set_interaction_enabled(false)
		_circle_wheel.set_cleanse_enabled(false)
	if _bench_board != null:
		_bench_board.set_input_enabled(false)
	if _overflow_pile != null:
		_overflow_pile.set_input_enabled(false)
	if _relic_tray != null:
		_relic_tray.visible = true
	_refresh_demo_shop_slots()


func _refresh_demo_shop_slots() -> void:
	for index in shop_slots.get_child_count():
		var slot := shop_slots.get_child(index) as ShopSlotPanel
		if slot == null:
			continue
		if index >= session.shop_unit_ids.size() or session.shop_unit_ids[index] < 0:
			slot.set_sold_out()
			slot.disabled = true
			continue
		var unit_id: int = session.shop_unit_ids[index]
		var cost := RelicEconomy.shop_price(session, index)
		slot.set_unit(unit_id, cost)
		slot.disabled = true


func _can_continue_demo() -> bool:
	return is_inside_tree() and _demo_mode and not _demo_exiting and not _demo_leave_started


func _run_demo_loop() -> void:
	while _can_continue_demo():
		PlayDemo.seed_board(self)
		if not _can_continue_demo():
			break
		_apply_demo_chrome()
		_formation.refresh_widgets()
		_update_synergy_panel()
		if _formation_banner != null:
			_announce_formation_bonus()
		if board.get_front_unit_count() <= 0:
			await get_tree().create_timer(0.4).timeout
			if not _can_continue_demo():
				break
			continue
		session.start_battle()
		board.set_battle_mode(true)
		_battle_playing = true
		_battle_restart_requested = false
		_apply_battle_time_scale()
		_update_ui()
		var outcome: Dictionary = await _run_battle_attempt()
		## シーン遷移後は触らない（viewport が null になる）。
		if not is_inside_tree() or _demo_leave_started:
			return
		_battle_playing = false
		_battle_restart_requested = false
		Engine.time_scale = 1.0
		board.set_battle_mode(false)
		if _demo_exiting or not _demo_mode:
			break
		if bool(outcome.get("aborted", false)):
			break
		session.phase = GameSession.Phase.PREP
		_update_ui()
		await get_tree().create_timer(1.1).timeout
		if not _can_continue_demo():
			break
	if _demo_exiting and is_inside_tree() and not _demo_leave_started:
		_leave_demo_scene()


func _exit_demo_to_title() -> void:
	if _demo_exiting or _demo_leave_started:
		return
	_demo_exiting = true
	_demo_mode = false
	GameAudio.set_se_suppressed(false)
	Engine.time_scale = 1.0
	if _battle_playing and _combat != null:
		_combat.request_abort()
	else:
		_leave_demo_scene()


func _leave_demo_scene() -> void:
	if _demo_leave_started:
		return
	_demo_leave_started = true
	_demo_exiting = true
	_demo_mode = false
	GameAudio.set_se_suppressed(false)
	GameAudio.stop_demo_bgm()
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/title.tscn")


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
	_hp_exp_button = Button.new()
	_hp_exp_button.visible = false
	_hp_exp_button.custom_minimum_size = Vector2(0, BOTTOM_BUTTON_HEIGHT)
	_hp_exp_button.add_theme_font_size_override("font_size", 14)
	action_column.add_child(_hp_exp_button)
	action_column.move_child(_hp_exp_button, exp_button.get_index() + 1)
	_hp_exp_button.pressed.connect(func() -> void: _on_action(GameAction.simple(GameAction.Type.BUY_EXP_HP)))
	for slot in shop_slots.get_children():
		if slot is ShopSlotPanel:
			(slot as ShopSlotPanel).add_theme_font_size_override("font_size", BOTTOM_UI_FONT_SHOP)


func _attach_action_icons() -> void:
	_set_button_icon(reroll_button, "res://images/status/refresh.png", "ショップを更新する。")
	_set_button_icon(exp_button, "res://images/status/xp.png", "経験値を購入し、レベルが上がるとサークルに置くことができるキャラクターの数が増える。")


func _set_button_icon(button: Button, path: String, tip: String) -> void:
	button.icon = load(path)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 64)
	button.add_theme_constant_override("h_separation", 4)
	button.tooltip_text = tip


func _attach_held_coin_icon() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_STOP
	icon.tooltip_text = "所持コイン"
	icon.texture = load("res://images/status/coin.png")
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_badge.remove_child(coin_label)
	coin_badge.add_child(row)
	row.add_child(icon)
	row.add_child(coin_label)
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_label.mouse_filter = Control.MOUSE_FILTER_STOP
	coin_label.tooltip_text = "所持コイン"


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
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_attach_held_coin_icon()
	shop_lock_button.custom_minimum_size = Vector2(0, 32)
	if exp_button.get_parent() != exp_box:
		exp_button.get_parent().remove_child(exp_button)
		exp_box.add_child(exp_button)
	exp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attach_action_icons()
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
	# _mount_debug_grants()
	_mount_audio_settings()
	var ui := $CanvasLayer/UI as Control
	action_column.get_parent().remove_child(action_column)
	ui.add_child(action_column)
	action_column.mouse_filter = Control.MOUSE_FILTER_STOP
	## サークル外縁のヒットがアクション列に食い込むので、戦闘開始などが下に隠れないよう前面へ。
	action_column.z_index = 20
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
	var pick_btn := Button.new()
	pick_btn.text = "3択"
	pick_btn.tooltip_text = "本番と同じレリック3択を開く"
	pick_btn.pressed.connect(_debug_open_relic_pick)
	round_row.add_child(pick_btn)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	box.add_child(tab_row)
	var tab_group := ButtonGroup.new()
	_debug_tab_units = Button.new()
	_debug_tab_units.text = "キャラ"
	_debug_tab_units.toggle_mode = true
	_debug_tab_units.button_group = tab_group
	_debug_tab_units.button_pressed = true
	_debug_tab_units.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_tab_units.pressed.connect(_set_debug_catalog.bind(false))
	tab_row.add_child(_debug_tab_units)
	_debug_tab_relics = Button.new()
	_debug_tab_relics.text = "レリック"
	_debug_tab_relics.toggle_mode = true
	_debug_tab_relics.button_group = tab_group
	_debug_tab_relics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_tab_relics.pressed.connect(_set_debug_catalog.bind(true))
	tab_row.add_child(_debug_tab_relics)
	_debug_relic_hint = Label.new()
	_debug_relic_hint.text = "クリックで付与 / 右クリックで詳細"
	_debug_relic_hint.add_theme_font_size_override("font_size", 12)
	_debug_relic_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_debug_relic_hint.visible = false
	box.add_child(_debug_relic_hint)
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
	_rebuild_debug_grid()


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


func _set_debug_catalog(show_relics: bool) -> void:
	if _debug_show_relics == show_relics:
		return
	_debug_show_relics = show_relics
	if _debug_relic_hint != null:
		_debug_relic_hint.visible = show_relics
	if _debug_tab_units != null:
		_debug_tab_units.set_pressed_no_signal(not show_relics)
	if _debug_tab_relics != null:
		_debug_tab_relics.set_pressed_no_signal(show_relics)
	_rebuild_debug_grid()
	_place_debug_roster()


func _rebuild_debug_grid() -> void:
	if _debug_roster_grid == null:
		return
	for child in _debug_roster_grid.get_children():
		_debug_roster_grid.remove_child(child)
		child.free()
	if _debug_show_relics:
		for relic_id in RelicCatalog.all_ids():
			_debug_roster_grid.add_child(_make_debug_relic_card(relic_id))
	else:
		for unit in UnitCatalog.UNITS:
			var unit_id := int(unit["id"])
			var card := ShopBoard.SLOT_SCENE.instantiate() as ShopSlotPanel
			if card == null:
				continue
			_debug_roster_grid.add_child(card)
			card.set_unit(unit_id)
			card.pressed.connect(_grant_debug_unit.bind(unit_id))


func _make_debug_relic_card(relic_id: int) -> Button:
	var data := RelicCatalog.get_relic(relic_id)
	var name_text := str(data.get("name", "？"))
	var brief := str(data.get("brief", "")).strip_edges()
	var category := str(data.get("category", "")).strip_edges()
	var tip := "%03d %s" % [relic_id, name_text]
	if not category.is_empty():
		tip += "\n[%s]" % category
	if not brief.is_empty():
		tip += "\n%s" % brief
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(72, 88)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.12, 0.13, 0.16, 0.92)
	plate.border_color = Color(0.55, 0.55, 0.5, 0.55)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", plate)
	var hover := plate.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.22, 0.28, 0.96)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", plate)
	button.add_theme_stylebox_override("focus", plate)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(box)
	var icon := TextureRect.new()
	icon.texture = RelicCatalog.get_icon(relic_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var id_label := Label.new()
	id_label.text = "%03d" % relic_id
	id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	id_label.add_theme_font_size_override("font_size", 11)
	id_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78))
	id_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(id_label)
	var name_label := Label.new()
	name_label.text = name_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	button.pressed.connect(_grant_debug_relic.bind(relic_id))
	button.gui_input.connect(_on_debug_relic_gui_input.bind(relic_id, button))
	return button


func _on_debug_relic_gui_input(event: InputEvent, relic_id: int, source: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_on_relic_inspect(relic_id, source.get_global_rect().position)


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
	var gap := 2.0
	if _debug_show_relics:
		var cell := Vector2(72, 88)
		var inner_w := maxf(cell.x, panel_size.x - 28.0)
		_debug_roster_grid.columns = maxi(1, int((inner_w + gap) / (cell.x + gap)))
		for child in _debug_roster_grid.get_children():
			var relic_btn := child as Button
			if relic_btn != null:
				relic_btn.custom_minimum_size = cell
		return
	var card := _shop.slot_size
	if card.x < 8.0 or card.y < 8.0:
		card = Vector2(ShopBoard.LAYOUT_SLOT_WIDTH, ShopBoard.LAYOUT_SLOT_WIDTH / ShopBoard.FRAME_ASPECT)
	var inner_w := maxf(card.x, panel_size.x - 28.0)
	_debug_roster_grid.columns = maxi(1, int((inner_w + gap) / (card.x + gap)))
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


func _debug_open_relic_pick() -> void:
	if not OS.is_debug_build() or not session.is_prep() or _run_end_active or _relic_pick_active:
		return
	_set_debug_roster_open(false)
	_open_relic_pick()


func _grant_debug_relic(relic_id: int) -> void:
	if not OS.is_debug_build() or not session.is_prep() or _run_end_active:
		return
	var data := RelicCatalog.get_relic(relic_id)
	if data.is_empty() or int(data.get("id", -1)) <= 0:
		return
	session.add_relic(relic_id)
	GameAudio.play_confirm()
	_log("デバッグ付与: %03d %s" % [relic_id, str(data.get("name", ""))])


func _grant_debug_unit(unit_id: int) -> void:
	if not OS.is_debug_build() or not session.is_prep() or _run_end_active:
		return
	var data := UnitCatalog.get_unit(unit_id)
	if data.is_empty():
		return
	var unit := GameUnit.create(unit_id, 1)
	units_root.add_child(unit)
	var slot := board.find_empty_bench_slot()
	if slot < 0:
		board.push_overflow(unit)
		GameAudio.play_buy()
		_show_board_notice(NOTICE_OVERFLOW, true)
		_log("%s が溢れた" % str(data["name"]))
		return
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
				if _tutorial_mode and _tutorial != null:
					_tutorial.on_rerolled()
				_log("ショップを更新した")
		GameAction.Type.BUY_EXP:
			var cap_before_exp := session.get_board_unit_cap()
			if session.try_buy_exp():
				_log("経験値を購入した (+%d)" % (GameSession.EXP_GAIN + RelicEconomy.exp_bonus(session)))
				_note_deploy_cap_change(cap_before_exp)
				_clear_exp_purchase_hint()
		GameAction.Type.BUY_EXP_HP:
			var cap_before_hp := session.get_board_unit_cap()
			if session.try_buy_exp_with_hp():
				_log("経験値を購入した (+%d, HP-%d)" % [RelicEconomy.hp_exp_gain(session), RelicEconomy.hp_exp_cost(session)])
				_note_deploy_cap_change(cap_before_hp)
				_clear_exp_purchase_hint()
		GameAction.Type.SELL_UNDER_CURSOR:
			if not session.is_prep() or _formation.is_dragging():
				return
			var hover_unit := _formation.unit_under_screen(action.screen_position)
			if hover_unit != null:
				_on_sell_requested(hover_unit)
				_update_ui()
		GameAction.Type.START_BATTLE:
			if _battle_playing:
				_request_battle_restart()
			else:
				_start_battle()
		GameAction.Type.GO_BACK:
			get_tree().change_scene_to_file("res://scenes/title.tscn")


func _request_battle_restart() -> void:
	if not _battle_playing or _combat == null or _battle_restart_requested:
		return
	_battle_restart_requested = true
	_combat.request_abort()
	_update_ui()


func _buy_from_shop(slot_index: int) -> void:
	if board.bench_is_full():
		_show_board_notice(NOTICE_BENCH_FULL)
		return
	var unit_id := session.try_buy_shop_slot(slot_index, false)
	if unit_id < 0:
		return
	GameAudio.play_buy()
	var data := UnitCatalog.get_unit(unit_id)
	var unit := GameUnit.create(unit_id, 1)
	units_root.add_child(unit)
	board.place_on_bench(unit, board.find_empty_bench_slot())
	_log("%s ★ を購入した (%d コイン)" % [data["name"], data["cost"]])


## 味方を戦闘開始直前の見た目・位置に戻す（敵は呼び出し側で消し直す）。
func _reset_allies_for_battle_attempt() -> void:
	for unit in board.get_all_units():
		if unit == null or not is_instance_valid(unit) or unit.is_enemy:
			continue
		unit.battle_ko = false
		unit.defeat_playing = false
		unit.stop_guard_hit_shake()
		unit.rotation.x = 0.0
		unit.release_battle_clip()
		unit.clear_status_auras()
		unit.set_battle_walking(false)
		unit.refresh_visuals()
	board.refresh_presentation()


func _run_battle_attempt() -> Dictionary:
	_reset_allies_for_battle_attempt()
	board.clear_enemy_units()
	var enemy_count := 0
	if _demo_mode:
		enemy_count = PlayDemo.spawn_enemies(self)
	elif _tutorial_mode:
		enemy_count = Tutorial.spawn_enemy(self)
	else:
		var route := session.selected_route
		if route.is_empty():
			route = RouteChoice.default_for_round(session.round_number)
		enemy_count = EnemySpawn.spawn_for_battle(
			board,
			units_root,
			session,
			route
		)
	_log("敵 %d 体出現" % enemy_count)
	_update_ui()
	_announce_formation_bonus()
	return await _combat.play()


func _start_battle() -> void:
	if _battle_playing:
		_request_battle_restart()
		return
	if _tutorial_mode and _tutorial != null and not _tutorial.allows_battle():
		_log("チュートリアルの手順を先に済ませてください")
		return
	if not session.is_prep():
		return
	if board.has_overflow():
		_show_board_notice(NOTICE_OVERFLOW, true)
		return
	if not board.has_circle_ally():
		_log("サークルに1人以上配置してください")
		return
	_shop.hide_odds_table()
	_log("戦闘開始 (ラウンド %d)" % session.round_number)
	var secret_battle := session.extended_mode and session.round_number == session.max_round
	GameAudio.play_battle(secret_battle, _battle.is_clock_tower())
	session.start_battle()
	prep_blocker.visible = false
	battle_overlay.visible = false
	board.set_battle_mode(true)
	_battle_playing = true
	_battle_restart_requested = false
	_apply_battle_time_scale()
	var outcome: Dictionary = {}
	while is_inside_tree():
		outcome = await _run_battle_attempt()
		if not is_inside_tree():
			_battle_playing = false
			Engine.time_scale = 1.0
			return
		## やり直し: 今の戦闘を捨てて、戦闘開始ボタン直後と同じ手順をもう一度。
		if bool(outcome.get("aborted", false)) and _battle_restart_requested:
			_battle_restart_requested = false
			_log("戦闘やり直し (ラウンド %d)" % session.round_number)
			GameAudio.play_battle(secret_battle, _battle.is_clock_tower())
			_apply_battle_time_scale()
			_update_ui()
			continue
		break
	_battle_playing = false
	_battle_restart_requested = false
	Engine.time_scale = 1.0
	if _debuff_ritual != null:
		_debuff_ritual.close_ritual()
	if not is_inside_tree():
		return
	if bool(outcome.get("aborted", false)):
		if session.phase == GameSession.Phase.BATTLE:
			session.phase = GameSession.Phase.PREP
			session.state_changed.emit()
		battle_overlay.visible = false
		board.set_battle_mode(false)
		_update_ui()
		return
	if _tutorial_mode and _tutorial != null:
		if session.phase == GameSession.Phase.BATTLE:
			session.phase = GameSession.Phase.PREP
			session.state_changed.emit()
		battle_overlay.visible = false
		board.set_battle_mode(false)
		_tutorial.on_battle_ended(bool(outcome.get("won", false)))
		_update_ui()
		return
	var battle_won: bool = bool(outcome.get("won", false))
	var remaining_enemies: int = int(outcome.get("remaining", 0))
	var hp_before := session.player_hp
	var level_before := session.get_level()
	var cap_before_battle := session.get_board_unit_cap()
	var bench_count := 0
	for slot in board.bench_units:
		if slot != null:
			bench_count += 1
	RelicEconomy.on_round_end(session, bench_count, board.bench_units.size())
	## トバ（059）・ナバリ（066）のラウンドの経験値は finish_battle が使うので、その前に決める。
	session.toba_round_xp = _round_xp_bonus(59)
	session.nabari_round_xp = _round_xp_bonus(66)
	session.finish_battle(battle_won, remaining_enemies)
	RelicEconomy.note_battle_finished(session, battle_won)
	RelicEconomy.note_battle_outcome(session, battle_won, outcome.get("relic_stats", {}))
	session.player_hp = mini(session.player_hp, RelicEconomy.player_max_hp(session))
	_note_deploy_cap_change(cap_before_battle)
	if battle_won:
		_log("戦闘勝利 (経験値 +%d)" % GameSession.ROUND_END_FREE_XP)
	else:
		_log("戦闘敗北 (HP -%d, 残り %d)" % [session.last_loss_damage, session.player_hp])
	battle_overlay.visible = false
	board.set_battle_mode(false)
	_battle.reroll()
	_update_ui()
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
		_grant_ono_free_rerolls()
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
	if session.last_cleanse_income > 0:
		lines.append("デバフ解除の収益 +%d" % session.last_cleanse_income)
	if session.is_run_over():
		lines.append("")
		lines.append("次のラウンドなし")
		return "\n".join(lines)
	var hard_block_interest := RelicEconomy.hard_blocks_interest(session)
	var convert_interest_xp := RelicEconomy.converts_interest_to_xp(session)
	var income := RoundIncome.calc_round_start_income(
		session.coins_at_last_round_end,
		session.get_level(),
		session.get_active_streak(),
		session.round_number,
		RelicEconomy.interest_step(session),
		0 if hard_block_interest else RelicEconomy.interest_principal_extra(session)
	)
	var interest_xp := 0
	if hard_block_interest:
		income["total"] = int(income["total"]) - int(income["holding"])
		income["holding"] = 0
	else:
		var interest := RelicEconomy.decorate_interest(session, int(income["holding"]), false)
		if convert_interest_xp:
			interest_xp = interest
			income["total"] = int(income["total"]) - int(income["holding"])
			income["holding"] = 0
		else:
			income["holding"] = interest
			income["total"] = int(income["base"]) + int(income["holding"]) + int(income["streak"]) + int(income["round"])
	var streak_extra := RelicEconomy.streak_extra(session)
	income["streak"] = int(income["streak"]) + streak_extra
	income["total"] = int(income["total"]) + streak_extra
	lines.append("")
	if interest_xp > 0:
		lines.append("次の利子→経験値 %d" % interest_xp)
	else:
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
	route_overlay.visible = false
	prep_blocker.visible = true
	input_handler.set_enabled(false)
	var lines := PackedStringArray()
	for option in session.route_options:
		lines.append(str(option.get("button_text", RouteChoice.format_option(option))))
	if lines.is_empty():
		lines.append(str(RouteChoice.default_for_round(session.round_number).get("button_text", "★★")))
	if _battle_result != null and _battle_result.visible:
		_battle_result.show_routes(lines, _on_route_selected, RouteChoice.ROUTE_HINT)
		return
	if _battle_result != null:
		_battle_result.open(true, "ラウンド %d" % session.round_number)
		_battle_result.show_routes(lines, _on_route_selected, RouteChoice.ROUTE_HINT)


func _on_route_selected(index: int) -> void:
	var route := session.select_route(index)
	## 成否にかかわらず結果オーバーレイとブロッカーは外す（残ると次の戦闘開始が押せない）。
	if _battle_result != null:
		_battle_result.close()
	route_overlay.visible = false
	prep_blocker.visible = false
	if action_column != null:
		action_column.move_to_front()
	if route.is_empty():
		_shop.set_modal_blocked(false)
		input_handler.set_enabled(session.is_prep() and not _relic_pick_active)
		_update_ui()
		return
	GameAudio.play_construction()
	shop_panel.visible = true
	coin_row.visible = true
	board.reset_circle_rotation()
	if _circle_wheel != null:
		_circle_wheel.reset_visual_spin()
	var stars := int(route.get("stars", 0))
	_log("ラウンド %d 開始（%s）" % [session.round_number, RouteChoice.star_text(stars)])
	_grant_ono_free_rerolls()
	_show_income_feedback()
	_update_ui()
	if not session.should_offer_relic_pick() and not _relic_pick_active:
		prep_blocker.visible = false
		_shop.set_modal_blocked(false)
		input_handler.set_enabled(true)
		if action_column != null:
			action_column.move_to_front()


func _open_relic_pick() -> void:
	if _relic_pick == null or _relic_pick_active:
		return
	_relic_pick_active = true
	prep_blocker.visible = true
	input_handler.set_enabled(false)
	_shop.set_modal_blocked(true)
	_relic_pick.open_with(RelicCatalog.random_choices(3))


func _flush_relic_picks() -> void:
	if _relic_pick_active or _run_end_active:
		return
	if session == null or session.relic_pending_picks <= 0:
		return
	_open_relic_pick()


func _on_relic_tray_hovered(uid: int) -> void:
	var relic_id := session.relic_id_of(uid)
	if relic_id <= 0 or _unit_inspect == null:
		return
	_unit_inspect.open_relic(relic_id, get_viewport().get_mouse_position(), true)


func _on_relic_tray_hover_cleared() -> void:
	if _unit_inspect == null:
		return
	_unit_inspect.request_hover_close()


func _on_relic_inspect(relic_id: int, anchor: Vector2) -> void:
	if _unit_inspect == null:
		return
	_unit_inspect.open_relic(relic_id, anchor, true)


func _on_circle_relic_hovered(slot_index: int, relic_index: int) -> void:
	var unit := board.get_placed_unit(board.active_face, slot_index)
	if unit == null:
		unit = board.get_resolved_unit(board.active_face, slot_index)
	_open_unit_relic(unit, relic_index)


func _on_bench_relic_hovered(slot_index: int, relic_index: int) -> void:
	if slot_index < 0 or slot_index >= board.bench_units.size():
		return
	_open_unit_relic(board.bench_units[slot_index], relic_index)


func _open_unit_relic(unit: GameUnit, relic_index: int) -> void:
	if unit == null or _unit_inspect == null:
		return
	if relic_index < 0 or relic_index >= unit.equipped_relic_uids.size():
		return
	var relic_id := session.relic_id_of(unit.equipped_relic_uids[relic_index])
	if relic_id <= 0:
		return
	_unit_inspect.open_relic(relic_id, get_viewport().get_mouse_position(), true)


func _on_circle_relic_drag_started(slot_index: int, relic_index: int) -> void:
	var unit := board.get_placed_unit(board.active_face, slot_index)
	_lift_equipped_relic(unit, relic_index)


func _on_bench_relic_drag_started(slot_index: int, relic_index: int) -> void:
	if slot_index < 0 or slot_index >= board.bench_units.size():
		return
	_lift_equipped_relic(board.bench_units[slot_index], relic_index)


func _lift_equipped_relic(unit: GameUnit, relic_index: int) -> void:
	if unit == null or _relic_tray == null:
		return
	if relic_index < 0 or relic_index >= unit.equipped_relic_uids.size():
		return
	var uid := unit.equipped_relic_uids[relic_index]
	unit.equipped_relic_uids.remove_at(relic_index)
	_formation.refresh_widgets()
	_relic_tray.begin_drag(uid)


func _on_relic_drag_finished(uid: int, global_position: Vector2) -> void:
	if uid < 0:
		return
	var other := _relic_tray.uid_at(global_position) if _relic_tray != null else -1
	if other > 0 and other != uid:
		var left_id := session.relic_id_of(uid)
		var right_id := session.relic_id_of(other)
		if left_id > 0 and right_id > 0 and _relic_synth != null:
			_relic_synth.open_pair(uid, other, left_id, right_id)
		return
	var unit := _unit_under_point(global_position)
	if unit != null:
		_equip_relic_on(uid, unit)
		return
	_formation.refresh_widgets()


func _unit_under_point(global_position: Vector2) -> GameUnit:
	if _bench_board != null:
		var bench_slot := _bench_board.slot_index_at_global(global_position)
		if bench_slot >= 0 and bench_slot < board.bench_units.size():
			var benched := board.bench_units[bench_slot] as GameUnit
			if benched != null:
				return benched
	if _circle_wheel != null:
		var circle_slot := _circle_wheel.slot_index_at_global(global_position)
		if circle_slot >= 0:
			var placed := board.get_placed_unit(board.active_face, circle_slot)
			if placed != null:
				return placed
	return null


func _equip_relic_on(uid: int, unit: GameUnit) -> void:
	var relic_id := session.relic_id_of(uid)
	var data := RelicCatalog.get_relic(relic_id)
	if not bool(data.get("equippable", false)):
		_log("このレリックは装備できない")
		_formation.refresh_widgets()
		return
	if unit.equipped_relic_uids.has(uid):
		_formation.refresh_widgets()
		return
	if unit.equipped_relic_uids.size() >= GameUnit.RELIC_EQUIP_CAP:
		_log("レリックは1人%dつまで装備できます" % GameUnit.RELIC_EQUIP_CAP)
		_formation.refresh_widgets()
		return
	var synergy_name := str(data.get("synergy", "")).strip_edges()
	if not synergy_name.is_empty() and SynergyTracker.unit_has_synergy(unit, synergy_name, session, uid):
		var notice := "すでに%sのシナジーです" % synergy_name
		_show_board_notice(notice)
		_log(notice)
		_formation.refresh_widgets()
		return
	for owner in board.get_all_units():
		owner.equipped_relic_uids.erase(uid)
	unit.equipped_relic_uids.append(uid)
	_log("%s に %s を装備した" % [unit.get_display_name(), str(data.get("name", ""))])
	if unit.unit_id == 10:
		_izumi_on_relic_equipped(unit, uid)
	elif unit.unit_id == 14:
		_ibaraki_on_relic_equipped(unit)
	elif unit.unit_id == 16:
		_oumi_on_relic_equipped(unit)
	elif unit.unit_id == 17:
		_otsu_on_relic_equipped(unit)
	elif unit.unit_id == 35:
		_sakai_on_relic_equipped(unit)
		_mishima_on_relic_equipped(unit)
		_minoo_on_relic_equipped(unit)
	elif unit.unit_id == 47:
		_senboku_on_relic_equipped(unit)
	_formation.refresh_widgets()


func _izumi_on_relic_equipped(unit: GameUnit, uid: int) -> void:
	if unit == null or uid <= 0:
		return
	var flags: Dictionary = unit.kit_flags
	## 増えたレリックを装備し直したときは、スウィングも増やす1回も起きない。
	if uid == int(flags.get("copied_uid", -1)):
		return
	var hp_gain := _swing_on_relic_equipped(unit, "swing_hp", "swing_used", "swing_hp_bonus", false)
	if hp_gain > 0.0:
		_log("%s の最大体力が %d 上がった（スウィング）" % [unit.get_display_name(), int(hp_gain)])
	var copy_left := int(flags.get("copy_left", 1))
	if copy_left <= 0:
		return
	## 増えたレリックを装備できないときは増えず、1回も残る。
	if unit.equipped_relic_uids.size() >= GameUnit.RELIC_EQUIP_CAP:
		return
	var relic_id := session.relic_id_of(uid)
	if relic_id <= 0:
		return
	var copied_uid := session.add_relic(relic_id)
	if copied_uid <= 0:
		return
	flags["copy_left"] = copy_left - 1
	flags["copied_uid"] = copied_uid
	unit.kit_flags = flags
	_log("%s が増えたレリックを得た" % unit.get_display_name())
	for owner in board.get_all_units():
		owner.equipped_relic_uids.erase(copied_uid)
	unit.equipped_relic_uids.append(copied_uid)
	_log("%s が増えたレリックを装備した" % unit.get_display_name())


## スウィング: レリックを装備したとき、数える装備が上限より少なければ上昇が残る。
## 量は装備した時点の星の欄の値に、装備した時点のスウィング人数の倍率を掛け、
## 半分以上の端数を切り上げた整数（percent のときは整数の%）である。増えた量を返す。
func _swing_on_relic_equipped(unit: GameUnit, base_key: String, used_key: String, bonus_key: String, percent: bool) -> float:
	if unit == null:
		return 0.0
	var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
	if sheet.is_empty():
		return 0.0
	var cap := int(sheet.get("swing_cap", 1))
	var used := int(unit.kit_flags.get(used_key, 0))
	if used >= cap:
		return 0.0
	var base := float(sheet.get(base_key, 0.0))
	if percent:
		base *= 100.0
	var bonus := floorf(base * _swing_mult() + 0.5)
	if bonus <= 0.0:
		return 0.0
	unit.kit_flags[used_key] = used + 1
	if percent:
		unit.kit_flags[bonus_key] = float(unit.kit_flags.get(bonus_key, 0.0)) + bonus / 100.0
	else:
		unit.kit_flags[bonus_key] = int(unit.kit_flags.get(bonus_key, 0)) + int(bonus)
	return bonus


func _swing_synergy_count() -> int:
	var units: Array = []
	for entry in board.get_all_units():
		var ally: GameUnit = entry as GameUnit
		if ally == null or ally.is_enemy:
			continue
		units.append(ally)
	var counts := SynergyTracker.count_synergies(units, session)
	return int(counts.get("スウィング", 0))


func _swing_mult() -> float:
	var count := _swing_synergy_count()
	if count >= 9:
		return 1.8
	if count >= 7:
		return 1.6
	if count >= 5:
		return 1.4
	if count >= 3:
		return 1.2
	return 1.0


func _ibaraki_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 14:
		return
	var bonus := _swing_on_relic_equipped(unit, "swing_defense", "swing_def_used", "swing_defense_bonus", false)
	if bonus > 0.0:
		_log("%s の防御力が %d 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


func _oumi_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 16:
		return
	var bonus := _swing_on_relic_equipped(unit, "swing_water", "swing_water_used", "swing_water_bonus", true)
	if bonus > 0.0:
		_log("%s の水与ダメージが %d%% 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


func _otsu_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 17:
		return
	var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
	if sheet.is_empty():
		return
	## 数えるのは受け取った時点の星の上限まで。戦闘開始時に層を付けると数は消える（battle_director 側で0に戻す）。
	var cap := int(sheet.get("relic_count_cap", 1))
	var pending := int(unit.kit_flags.get("otsu_pending", 0))
	if pending >= cap:
		return
	unit.kit_flags["otsu_pending"] = pending + 1
	_log("%s は次の戦闘開始時に雷の層を付与する" % unit.get_display_name())


## サークルにいる味方のうち、星が最も高い unit_id の1体の「ラウンドの経験値」。いなければ0。
func _round_xp_bonus(unit_id: int) -> int:
	var best: GameUnit = null
	for unit in board.get_circle_units():
		if unit == null or unit.unit_id != unit_id or unit.is_enemy:
			continue
		if best == null or unit.stars > best.stars:
			best = unit
	if best == null:
		return 0
	var sheet := CharacterSheet.make(best.unit_id, best.stars)
	return maxi(1, int(sheet.get("round_xp", 1)))


func _senboku_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 47:
		return
	var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
	if sheet.is_empty():
		return
	var equip_cap := int(sheet.get("equip_cap", 1))
	var equip_used := int(unit.kit_flags.get("senboku_equip_used", 0))
	if equip_used < equip_cap:
		var hp_gain := int(sheet.get("equip_hp", 6))
		if hp_gain > 0:
			unit.kit_flags["senboku_equip_used"] = equip_used + 1
			unit.kit_flags["senboku_equip_hp"] = int(unit.kit_flags.get("senboku_equip_hp", 0)) + hp_gain
			_log("%s の最大体力が %d 上がった（装備）" % [unit.get_display_name(), hp_gain])
	var bonus := _swing_on_relic_equipped(unit, "swing_thunder", "swing_thunder_used", "swing_thunder_bonus", true)
	if bonus > 0.0:
		_log("%s の雷与ダメージが %d%% 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


func _ono_free_rerolls_on_board() -> int:
	var total := 0
	var seen: Dictionary = {}
	for unit in board.get_circle_units():
		if unit == null or unit.unit_id != 18 or unit.is_enemy:
			continue
		if seen.has(unit.get_instance_id()):
			continue
		seen[unit.get_instance_id()] = true
		var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
		total += int(sheet.get("free_rerolls", 1))
	return total


func _grant_ono_free_rerolls() -> void:
	var grant := _ono_free_rerolls_on_board()
	if grant <= 0:
		return
	session.free_rerolls += grant
	_log("オノの無料更新 +%d" % grant)



func _on_relic_synth_confirmed(left_uid: int, right_uid: int) -> void:
	var synth_gold := RelicEconomy.synth_gold(session)
	var left_id := session.take_relic(left_uid)
	var right_id := session.take_relic(right_uid)
	if left_id <= 0 or right_id <= 0:
		return
	for owner in board.get_all_units():
		owner.equipped_relic_uids.erase(left_uid)
		owner.equipped_relic_uids.erase(right_uid)
	var result_id := RelicCatalog.synthesize_id(left_id, right_id)
	session.add_relic(result_id)
	session.tally_relic_synths += 1
	_minoo_keep_material(left_id)
	if synth_gold > 0:
		session.add_coins(synth_gold)
	RelicEconomy.note_relic_synthesized(session)
	var data := RelicCatalog.get_relic(result_id)
	_log("レリックを合成した: %s" % str(data.get("name", "")))
	_note_synth_kit_charges()
	_formation.refresh_widgets()


func _note_synth_kit_charges() -> void:
	for unit in board.get_circle_units():
		if unit == null or unit.is_enemy:
			continue
		if unit.unit_id == 21 or unit.unit_id == 26:
			var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
			var cap := int(sheet.get("synth_charges", 1))
			var now := int(unit.kit_flags.get("synth_charges", 0))
			if now < cap:
				unit.kit_flags["synth_charges"] = now + 1
				_log("%s の合成回数が残った" % unit.get_display_name())
		elif unit.unit_id == 35:
			var sheet35 := CharacterSheet.make(unit.unit_id, unit.stars)
			var add := float(sheet35.get("synth_damage", 0.04))
			var cap35 := float(sheet35.get("synth_cap", 0.12))
			var now35 := float(unit.kit_flags.get("synth_bonus", 0.0))
			unit.kit_flags["synth_bonus"] = minf(cap35, now35 + add)
		elif unit.unit_id == 81:
			var sheet81 := CharacterSheet.make(unit.unit_id, unit.stars)
			var cap81 := int(sheet81.get("synth_cap", 2))
			var now81 := int(unit.kit_flags.get("maga_left", 0))
			if now81 < cap81:
				unit.kit_flags["maga_left"] = now81 + 1
				_log("%s の貫通が残った" % unit.get_display_name())


## ミシマ: 装備したとき、上限まで属性耐性が残る。外しても残る。
func _mishima_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 84:
		return
	var bonus := _swing_on_relic_equipped(unit, "swing_resist", "mishima_swing_used", "mishima_resist", true)
	if bonus > 0.0:
		_log("%s の属性耐性が %d%% 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


## ミノオ: 装備したとき、上限まで炎の与ダメージが残る。外しても残る。
func _minoo_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 86:
		return
	_minoo_seed_charges(unit)
	var bonus := _swing_on_relic_equipped(unit, "swing_fire", "minoo_swing_used", "minoo_fire", true)
	if bonus > 0.0:
		_log("%s の炎ダメージが %d%% 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


## ミノオの素材回数。マッチで一度入れ、星が上がった分だけ増やす。
func _minoo_seed_charges(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 86:
		return
	var sheet := CharacterSheet.make(unit.unit_id, unit.stars)
	var cap := int(sheet.get("material_cap", 1))
	if not bool(unit.kit_flags.get("minoo_seeded", false)):
		unit.kit_flags["minoo_seeded"] = true
		unit.kit_flags["minoo_left"] = cap
		unit.kit_flags["minoo_seen"] = cap
		return
	var seen := int(unit.kit_flags.get("minoo_seen", cap))
	if cap > seen:
		unit.kit_flags["minoo_left"] = int(unit.kit_flags.get("minoo_left", 0)) + cap - seen
		unit.kit_flags["minoo_seen"] = cap


## 合成の左の素材を1つ戻す。戻したレリックは新しい合成には数えない。選ぶ画面はなく、左を残す。
func _minoo_keep_material(left_id: int) -> void:
	if left_id <= 0:
		return
	var keeper: GameUnit = null
	for unit in board.get_circle_units():
		if unit == null or unit.is_enemy or unit.unit_id != 86:
			continue
		_minoo_seed_charges(unit)
		if int(unit.kit_flags.get("minoo_left", 0)) <= 0:
			continue
		if keeper == null or unit.unit_id < keeper.unit_id:
			keeper = unit
	if keeper == null:
		return
	keeper.kit_flags["minoo_left"] = int(keeper.kit_flags.get("minoo_left", 0)) - 1
	session.add_relic(left_id)
	_log("%s の素材が1つ残った" % keeper.get_display_name())


func _sakai_on_relic_equipped(unit: GameUnit) -> void:
	if unit == null or unit.unit_id != 35:
		return
	var bonus := _swing_on_relic_equipped(unit, "swing_speed", "swing_speed_used", "swing_speed_bonus", false)
	if bonus > 0.0:
		_log("%s の左右速度が %d 上がった（スウィング）" % [unit.get_display_name(), int(bonus)])


func _on_relic_chosen(relic_id: int) -> void:
	_relic_pick_active = false
	session.relic_pending_picks = maxi(0, session.relic_pending_picks - 1)
	session.add_relic(relic_id)
	var data := RelicCatalog.get_relic(relic_id)
	_log("レリック獲得: %s" % str(data.get("name", relic_id)))
	_update_ui()
	if _relic_pick_active or session.should_offer_relic_pick():
		return
	prep_blocker.visible = false
	_shop.set_modal_blocked(false)
	input_handler.set_enabled(true)
	if action_column != null:
		action_column.move_to_front()


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
	var refund := RelicEconomy.star_sell_refund(session, unit.get_cost(), unit.stars)
	session.add_sell_income(refund)
	RelicEconomy.note_unit_sold(session)
	unit.equipped_relic_uids.clear()
	var sold_id := unit.unit_id
	var sold_cost := unit.get_cost()
	var sold_stars := unit.stars
	board.remove_unit(unit)
	unit.queue_free()
	var free_slots := 0
	for slot in board.bench_units:
		if slot == null:
			free_slots += 1
	RelicEconomy.note_sold_unit(session, sold_id, sold_cost, sold_stars, free_slots)
	_flush_relic_units()
	board.try_absorb_overflow()
	_refresh_overflow_notice()
	_log("%s %s を売却した (+%d)" % [name, stars, refund])


func _on_merges_applied(messages: Array[String]) -> void:
	RelicEconomy.note_star_ups(session, messages.size())
	session.tally_merges += messages.size()
	for message in messages:
		_log("合成: %s" % message)
		GameAudio.play_fusion()
	board.try_absorb_overflow()
	_refresh_overflow_notice()


func _show_board_notice(text: String, persistent: bool = false) -> void:
	if _board_notice == null:
		return
	_board_notice.show_notice(text, persistent)
	if text == NOTICE_CIRCLE_CAP:
		_show_exp_purchase_hint()


func _show_exp_purchase_hint() -> void:
	if _exp_hint_arrow == null or exp_button == null or not exp_button.visible:
		return
	_exp_hint_arrow.point_at(exp_button)


func _clear_exp_purchase_hint() -> void:
	if _exp_hint_arrow != null:
		_exp_hint_arrow.clear()


func _refresh_overflow_notice() -> void:
	if _board_notice == null:
		return
	if board.has_overflow():
		_show_board_notice(NOTICE_OVERFLOW, true)
	elif _board_notice.is_persistent():
		_board_notice.clear_persistent()


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
	_update_sell_hint_refund(_formation.dragging_unit())
	var active_color := Color(1.0, 0.55, 0.55, 1.0)
	var idle_color := Color(1.0, 1.0, 1.0, 0.7)
	sell_drag_hint_right.modulate = active_color if sell_zone_side == 1 else idle_color


func _get_sell_zone_side(screen_pos: Vector2) -> int:
	if not session.is_prep():
		return -1
	if sell_drag_hint_right.get_global_rect().has_point(screen_pos):
		return 1
	## ショップ上に持っていっても売却できる。
	if bottom_ui.visible and bottom_ui.get_global_rect().has_point(screen_pos):
		return 1
	if shop_panel.visible and shop_panel.get_global_rect().has_point(screen_pos):
		return 1
	return -1


func _shop_ui_blocks_drop(screen_pos: Vector2) -> bool:
	if _get_sell_zone_side(screen_pos) >= 0:
		return false
	var action_rect := action_column.get_global_rect()
	if action_rect.has_point(screen_pos):
		return true
	return false


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
	_synergy_detail.z_index = 40
	_synergy_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_synergy_detail.mouse_entered.connect(_on_synergy_detail_mouse_entered)
	_synergy_detail.mouse_exited.connect(_on_synergy_detail_mouse_exited)
	var detail_panel := StyleBoxFlat.new()
	detail_panel.bg_color = Color(0.1, 0.11, 0.14, 1.0)
	detail_panel.border_color = Color(0.42, 0.4, 0.36, 1.0)
	detail_panel.set_border_width_all(2)
	detail_panel.set_corner_radius_all(4)
	detail_panel.content_margin_left = 2
	detail_panel.content_margin_right = 2
	detail_panel.content_margin_top = 2
	detail_panel.content_margin_bottom = 2
	_synergy_detail.add_theme_stylebox_override("panel", detail_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	_synergy_detail.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	var watch_row := HBoxContainer.new()
	watch_row.add_theme_constant_override("separation", 4)
	_synergy_watch_check = CheckBox.new()
	_synergy_watch_check.focus_mode = Control.FOCUS_NONE
	_synergy_watch_check.text = "ショップで強調"
	_synergy_watch_check.tooltip_text = "チェックすると、ショップでこのシナジーのキャラクターを強調します"
	_synergy_watch_check.toggled.connect(_on_synergy_detail_watch_toggled)
	watch_row.add_child(_synergy_watch_check)
	column.add_child(watch_row)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(280, 0)
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(detail_scroll)
	var detail_inner := VBoxContainer.new()
	detail_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_inner.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(detail_inner)
	_synergy_detail_body = RichTextLabel.new()
	_synergy_detail_body.bbcode_enabled = true
	_synergy_detail_body.fit_content = true
	_synergy_detail_body.scroll_active = false
	_synergy_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_detail_body.custom_minimum_size = Vector2(280, 0)
	_synergy_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_detail_body.add_theme_font_size_override("normal_font_size", 15)
	detail_inner.add_child(_synergy_detail_body)
	var members_title := Label.new()
	members_title.text = "所属キャラクター"
	members_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	members_title.add_theme_font_size_override("font_size", 14)
	members_title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	detail_inner.add_child(members_title)
	_synergy_members_flow = HFlowContainer.new()
	_synergy_members_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_members_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synergy_members_flow.add_theme_constant_override("h_separation", 8)
	_synergy_members_flow.add_theme_constant_override("v_separation", 8)
	detail_inner.add_child(_synergy_members_flow)
	ui.add_child(_synergy_detail)


func _update_synergy_panel() -> void:
	if _synergy_list == null:
		return
	var entries := SynergyTracker.list_synergies(board.get_circle_units(), session)
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


func _make_synergy_row(entry: Dictionary) -> Control:
	var synergy_name := str(entry["name"])
	var active := bool(entry["active"])
	var color: Color = entry["color"]
	var watched := bool(_watched_synergies.get(synergy_name, false))
	var button := Button.new()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if watched:
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(1.0, 0.92, 0.45, 0.95)
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
	button.mouse_entered.connect(_open_synergy_hover.bind(synergy_name))
	button.mouse_exited.connect(_on_synergy_row_mouse_exited)
	return button


func _on_synergy_detail_watch_toggled(pressed: bool) -> void:
	if _synergy_open.is_empty():
		return
	_on_synergy_watch_toggled(pressed, _synergy_open)
	_update_synergy_panel()


func _on_synergy_watch_toggled(pressed: bool, synergy_name: String) -> void:
	if pressed:
		_watched_synergies[synergy_name] = true
	else:
		_watched_synergies.erase(synergy_name)
	_refresh_shop_synergy_watch()


func _shop_watch_color_for_unit(unit_id: int) -> Color:
	if _watched_synergies.is_empty() or unit_id <= 0:
		return Color(0, 0, 0, 0)
	var data := UnitCatalog.get_unit(unit_id)
	for synergy_name in data.get("synergy_names", []):
		if bool(_watched_synergies.get(str(synergy_name), false)):
			return SynergyCatalog.color_of(str(synergy_name))
	return Color(0, 0, 0, 0)


func _refresh_shop_synergy_watch() -> void:
	if shop_slots == null:
		return
	for index in shop_slots.get_child_count():
		var slot := shop_slots.get_child(index) as ShopSlotPanel
		if slot == null:
			continue
		if index >= session.shop_unit_ids.size() or session.shop_unit_ids[index] < 0:
			slot.set_synergy_watch(false)
			continue
		var color := _shop_watch_color_for_unit(session.shop_unit_ids[index])
		slot.set_synergy_watch(color.a > 0.0, color)


func _open_synergy_hover(synergy_name: String) -> void:
	_synergy_close_left = -1.0
	_synergy_open = synergy_name
	_fill_synergy_detail(synergy_name, SynergyTracker.list_synergies(board.get_circle_units(), session))
	if _synergy_open.is_empty():
		return
	_synergy_detail.visible = true
	_place_synergy_detail()


func _on_synergy_row_mouse_exited() -> void:
	_request_synergy_hover_close()


func _on_synergy_detail_mouse_entered() -> void:
	_synergy_pointer_over_detail = true
	_synergy_close_left = -1.0


func _on_synergy_detail_mouse_exited() -> void:
	_synergy_pointer_over_detail = false
	_request_synergy_hover_close()


func _request_synergy_hover_close() -> void:
	if _synergy_detail == null or not _synergy_detail.visible:
		return
	if _is_pointer_over_synergy_detail():
		return
	_synergy_close_left = SYNERGY_CLOSE_GRACE


func _is_pointer_over_synergy_detail() -> bool:
	if _synergy_detail == null or not _synergy_detail.visible:
		return false
	if _synergy_pointer_over_detail:
		return true
	return _synergy_detail.get_global_rect().grow(16.0).has_point(get_viewport().get_mouse_position())


func _close_synergy_detail() -> void:
	_synergy_open = ""
	_synergy_pointer_over_detail = false
	_synergy_close_left = -1.0
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
	if _synergy_watch_check != null:
		_synergy_watch_check.set_block_signals(true)
		_synergy_watch_check.button_pressed = bool(_watched_synergies.get(synergy_name, false))
		_synergy_watch_check.set_block_signals(false)
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
	_fill_synergy_members(synergy_name)


func _owned_synergy_unit_ids() -> Dictionary:
	var owned: Dictionary = {}
	if board == null:
		return owned
	for unit in board.get_circle_units():
		if unit == null or not (unit is GameUnit) or unit.is_enemy:
			continue
		owned[unit.unit_id] = true
	for slot in board.bench_units:
		if slot == null or not (slot is GameUnit) or slot.is_enemy:
			continue
		owned[slot.unit_id] = true
	return owned


func _fill_synergy_members(synergy_name: String) -> void:
	if _synergy_members_flow == null:
		return
	for child in _synergy_members_flow.get_children():
		_synergy_members_flow.remove_child(child)
		child.free()
	var owned := _owned_synergy_unit_ids()
	var present: Array[int] = []
	var missing: Array[int] = []
	for unit_id in SynergyTracker.unit_ids_for(synergy_name):
		if owned.has(unit_id):
			present.append(unit_id)
		else:
			missing.append(unit_id)
	present.sort_custom(_sort_synergy_member_ids)
	missing.sort_custom(_sort_synergy_member_ids)
	for unit_id in present:
		_synergy_members_flow.add_child(_make_synergy_member_chip(unit_id, true))
	for unit_id in missing:
		_synergy_members_flow.add_child(_make_synergy_member_chip(unit_id, false))


func _synergy_member_meta(unit_id: int) -> Dictionary:
	var data := UnitCatalog.get_unit(unit_id)
	var display_name := str(data.get("name", ""))
	var cost := int(data.get("cost", 99))
	if display_name.is_empty() or cost >= 99:
		var fields: Dictionary = CharacterText.load_profile(unit_id).get("fields", {})
		if display_name.is_empty():
			display_name = str(fields.get("名前", "#%d" % unit_id))
		if cost >= 99:
			cost = int(str(fields.get("コスト", "99")).get_slice(" ", 0))
	return {"name": display_name, "cost": cost}


func _sort_synergy_member_ids(a: int, b: int) -> bool:
	var cost_a := int(_synergy_member_meta(a)["cost"])
	var cost_b := int(_synergy_member_meta(b)["cost"])
	if cost_a != cost_b:
		return cost_a < cost_b
	return a < b


func _make_synergy_member_chip(unit_id: int, present: bool) -> Control:
	var meta := _synergy_member_meta(unit_id)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(118, SYNERGY_MEMBER_ICON)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(SYNERGY_MEMBER_ICON, SYNERGY_MEMBER_ICON)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	icon.texture = UnitCatalog.make_portrait(unit_id, Vector2(SYNERGY_MEMBER_ICON, SYNERGY_MEMBER_ICON))
	row.add_child(icon)
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(meta["name"])
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9) if present else Color(0.62, 0.62, 0.64))
	row.add_child(name_label)
	## ベンチ／サークルにいない所属キャラは灰色フィルター。
	row.modulate = Color.WHITE if present else Color(0.48, 0.48, 0.5, 0.82)
	return row


func _place_synergy_detail() -> void:
	if _synergy_detail == null or not _synergy_detail.visible or synergy_panel == null:
		return
	var height := minf(460.0, maxf(160.0, synergy_panel.size.y))
	_synergy_detail.z_index = 40
	if _synergy_detail.get_parent() != null:
		_synergy_detail.get_parent().move_child(_synergy_detail, -1)
	## すき間なしで右隣に置き、カーソル移動で閉じにくくする。
	_synergy_detail.position = synergy_panel.position + Vector2(synergy_panel.size.x - 2.0, 0.0)
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
	_overflow_pile = OverflowPile.new()
	_overflow_pile.name = "OverflowPile"
	ui.add_child(_overflow_pile)
	ui.move_child(_overflow_pile, insert_at + 2)
	_board_notice = BoardNotice.new()
	_board_notice.name = "BoardNotice"
	ui.add_child(_board_notice)
	_exp_hint_arrow = ExpHintArrow.new()
	_exp_hint_arrow.name = "ExpHintArrow"
	ui.add_child(_exp_hint_arrow)
	_formation_banner = FormationBanner.new()
	_formation_banner.name = "FormationBanner"
	ui.add_child(_formation_banner)
	ui.add_child(_action_order_bar)
	ui.move_child(_action_order_bar, insert_at + 3)
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
	_circle_wheel.rotate_steps.connect(_on_circle_rotate_steps)
	_circle_wheel.visual_shift_changed.connect(func(shift: float) -> void: board.set_visual_shift(shift))
	_circle_wheel.center_pressed.connect(_formation.on_center_pressed)
	_circle_wheel.unit_drag_started.connect(_formation.on_circle_drag_started)
	_circle_wheel.unit_drag_finished.connect(_formation.on_circle_drag_finished)
	_circle_wheel.slot_move_requested.connect(_formation.on_circle_slot_move)
	_circle_wheel.unit_hovered.connect(_formation.on_circle_unit_hovered)
	_circle_wheel.hover_cleared.connect(_formation.on_inspect_hover_cleared)
	_circle_wheel.debuff_cleanse_requested.connect(_open_debuff_ritual)
	_debuff_ritual = DebuffRitual.new()
	_debuff_ritual.name = "DebuffRitual"
	_debuff_ritual.cleared.connect(_on_debuff_cleared)
	ui.add_child(_debuff_ritual)
	_relic_pick = RelicPick.new()
	_relic_pick.name = "RelicPick"
	_relic_pick.chosen.connect(_on_relic_chosen)
	ui.add_child(_relic_pick)
	_relic_tray = RelicTray.new()
	_relic_tray.name = "RelicTray"
	_relic_tray.hovered.connect(_on_relic_tray_hovered)
	_relic_tray.hover_cleared.connect(_on_relic_tray_hover_cleared)
	_relic_tray.drag_finished.connect(_on_relic_drag_finished)
	_relic_tray.clicked.connect(_on_relic_tray_clicked)
	ui.add_child(_relic_tray)
	_relic_synth = RelicSynth.new()
	_relic_synth.name = "RelicSynth"
	_relic_synth.confirmed.connect(_on_relic_synth_confirmed)
	ui.add_child(_relic_synth)
	_circle_wheel.relic_hovered.connect(_on_circle_relic_hovered)
	_circle_wheel.relic_drag_started.connect(_on_circle_relic_drag_started)
	_circle_wheel.relic_clicked.connect(_on_circle_relic_clicked)
	_bench_board.relic_clicked.connect(_on_bench_relic_clicked)
	_bench_board.relic_hovered.connect(_on_bench_relic_hovered)
	_bench_board.hover_cleared.connect(_formation.on_inspect_hover_cleared)
	_bench_board.unit_hovered.connect(_formation.on_bench_unit_hovered)
	_bench_board.relic_drag_started.connect(_on_bench_relic_drag_started)
	_bench_board.unit_drag_started.connect(_formation.on_bench_drag_started)
	_bench_board.unit_drag_finished.connect(_formation.on_bench_drag_finished)
	_overflow_pile.unit_drag_started.connect(_formation.on_overflow_drag_started)
	_overflow_pile.unit_drag_finished.connect(_formation.on_overflow_drag_finished)
	if not get_viewport().size_changed.is_connected(_layout_formation_ui):
		get_viewport().size_changed.connect(_layout_formation_ui)


func _on_circle_rotate_steps(steps: int) -> void:
	board.apply_spin_commit(steps)
	if posmod(steps, BoardController.SLOTS_PER_FACE) == 0:
		return
	_announce_formation_bonus()


func _announce_formation_bonus() -> void:
	if _formation_banner == null:
		return
	var rows := BattleDirector.formation_banner_rows(board)
	if rows.is_empty():
		return
	_formation_banner.show_formation_rows(rows)
	for row in rows:
		var label := str(row.get("label", ""))
		var attr_pct := int(row.get("attr_pct", 0))
		var aura_label := str(row.get("aura_label", ""))
		var aura_pct := int(row.get("aura_pct", 0))
		if aura_label.is_empty() or aura_pct <= 0:
			_log("%s陣形 属性+%d%%" % [label, attr_pct])
		else:
			_log("%s陣形 属性+%d%% / 隣接%s+%d%%" % [label, attr_pct, aura_label, aura_pct])


func _note_deploy_cap_change(before_cap: int) -> void:
	var after_cap := session.get_board_unit_cap()
	if after_cap <= before_cap:
		return
	_announce_deploy_cap(before_cap, after_cap)


func _announce_deploy_cap(from_count: int, to_count: int) -> void:
	if _formation_banner == null:
		return
	var text := "キャラクターの出撃可能数が%d人から%d人に上がった！" % [from_count, to_count]
	_formation_banner.show_message(text, Color(1.0, 0.92, 0.42), 2.8)
	_log(text)


func _open_debuff_ritual(slot_index: int) -> void:
	if session.phase != GameSession.Phase.BATTLE:
		return
	var unit := board.get_placed_unit(board.active_face, slot_index)
	if unit == null or not unit.debuffed or _debuff_ritual == null:
		return
	_debuff_ritual.open_for(unit)


func _on_debuff_cleared(unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	_combat.cleanse_debuff(unit)
	session.note_cleanse_income(1)
	_log("%s のデバフを解除した（収益 +1）" % unit.get_display_name())
	_formation.refresh_widgets()


func _ensure_run_end_free_root() -> void:
	if _run_end_free_root != null:
		return
	_run_end_free_root = Control.new()
	_run_end_free_root.name = "RunEndFreeRoot"
	_run_end_free_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_end_free_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_end_overlay.add_child(_run_end_free_root)
	for node in [
		run_end_title,
		run_end_summary,
		review_board_button,
		review_synergy_button,
		review_log_button,
		review_stats_button,
		title_return_button,
	]:
		if node.get_parent() != null:
			node.reparent(_run_end_free_root)
	if run_end_vbox != null:
		run_end_vbox.visible = false
	if run_end_review_buttons != null:
		run_end_review_buttons.visible = false


func layout_run_end_overlay() -> void:
	if not _run_end_active or run_end_overlay == null or not run_end_overlay.visible:
		return
	_ensure_run_end_free_root()
	var view := get_viewport().get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return
	run_end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	run_end_overlay.offset_left = 0.0
	run_end_overlay.offset_top = 0.0
	run_end_overlay.offset_right = 0.0
	run_end_overlay.offset_bottom = 0.0
	_run_end_free_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run_end_free_root.offset_left = 0.0
	_run_end_free_root.offset_top = 0.0
	_run_end_free_root.offset_right = 0.0
	_run_end_free_root.offset_bottom = 0.0
	_run_end_diagonal = (
		session.run_end_reason == GameSession.RunEndReason.CLEAR
		or session.run_end_reason == GameSession.RunEndReason.VOLUNTARY_END
	)
	if _run_end_diagonal:
		run_end_overlay.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_layout_run_end_diagonal(view)
	else:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.06, 0.08, 0.14, 0.94)
		panel.set_corner_radius_all(16)
		panel.set_content_margin_all(18)
		run_end_overlay.add_theme_stylebox_override("panel", panel)
		_layout_run_end_defeat(view)


func _place_run_end_rotated(control: Control, center: Vector2, angle: float, box: Vector2) -> void:
	control.reset_size()
	control.custom_minimum_size = box
	control.size = box
	control.pivot_offset = box * 0.5
	control.rotation = angle
	control.position = center - box * 0.5


func _ensure_run_end_marquee_rows(count: int) -> void:
	_ensure_run_end_free_root()
	while _run_end_marquee_rows.size() < count:
		var label := Label.new()
		label.name = "RunEndMarquee%d" % _run_end_marquee_rows.size()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.z_index = RUN_END_MARQUEE_Z
		_run_end_free_root.add_child(label)
		_run_end_marquee_rows.append(label)
	for index in _run_end_marquee_rows.size():
		_run_end_marquee_rows[index].visible = index < count
		_run_end_marquee_rows[index].z_index = RUN_END_MARQUEE_Z


func _hide_run_end_marquee_rows() -> void:
	for label in _run_end_marquee_rows:
		label.visible = false
	if _run_end_stats_scroll != null:
		_run_end_stats_scroll.visible = false


func _ensure_run_end_stats_scroll() -> void:
	_ensure_run_end_free_root()
	if _run_end_stats_scroll != null:
		return
	_run_end_stats_scroll = ScrollContainer.new()
	_run_end_stats_scroll.name = "RunEndStatsScroll"
	_run_end_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_run_end_stats_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_run_end_stats_scroll.z_index = RUN_END_FRONT_Z
	_run_end_free_root.add_child(_run_end_stats_scroll)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.04, 0.82)
	style.border_color = Color(1.0, 0.92, 0.86, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_run_end_stats_scroll.add_child(panel)
	_run_end_stats_body = Label.new()
	_run_end_stats_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_run_end_stats_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_end_stats_body.add_theme_font_size_override("font_size", 16)
	_run_end_stats_body.add_theme_color_override("font_color", Color(1.0, 0.96, 0.9))
	_run_end_stats_body.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.03, 0.9))
	_run_end_stats_body.add_theme_constant_override("outline_size", 4)
	panel.add_child(_run_end_stats_body)


func _place_run_end_marquee() -> void:
	if _run_end_marquee_cycle <= 0.0 or _run_end_marquee_box == Vector2.ZERO:
		return
	var wrapped := fposmod(_run_end_marquee_offset, _run_end_marquee_cycle)
	for index in _run_end_marquee_rows.size():
		var label := _run_end_marquee_rows[index]
		if not label.visible or index >= _run_end_marquee_centers.size():
			continue
		## 隣り合う行は逆方向。
		var shift := wrapped if (index % 2) == 0 else -wrapped
		var center := _run_end_marquee_centers[index] + _run_end_marquee_dir * shift
		label.size = _run_end_marquee_box
		label.pivot_offset = _run_end_marquee_box * 0.5
		label.rotation = _run_end_marquee_angle
		label.position = center - _run_end_marquee_box * 0.5


func _style_run_end_clear_button(button: Button, font_size: int) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.05, 0.72)
	normal.border_color = Color(1.0, 0.92, 0.86, 0.88)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.82, 0.12, 0.16, 0.88)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.08, 0.1, 0.92)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.97, 0.92))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.95))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.9))


func _layout_run_end_diagonal(view: Vector2) -> void:
	## 文字向きは水平のまま、左上→右下の斜めに多行で流す。隣行は逆流。空白なし。
	if _run_end_title_phrase.is_empty():
		_run_end_title_phrase = run_end_title.text.strip_edges()
		if _run_end_title_phrase.is_empty():
			_run_end_title_phrase = "完全クリア"
	run_end_title.visible = false
	_ensure_run_end_marquee_rows(RUN_END_MARQUEE_ROWS)
	var title_font := int(clampf(minf(view.x, view.y) * 0.42, 160.0, 420.0))
	var probe := _run_end_marquee_rows[0]
	probe.add_theme_font_size_override("font_size", title_font)
	var font := probe.get_theme_font("font")
	var phrase_w := 0.0
	if font != null:
		phrase_w = font.get_string_size(_run_end_title_phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font).x
	if phrase_w < 8.0:
		phrase_w = float(title_font) * float(_run_end_title_phrase.length()) * 0.95
	_run_end_marquee_cycle = maxf(phrase_w, 1.0)
	var copies := maxi(8, int(ceili(view.length() * 2.5 / _run_end_marquee_cycle)) + 2)
	var continuous := _run_end_title_phrase.repeat(copies)
	var title_h := float(title_font) * 1.05
	_run_end_marquee_box = Vector2(_run_end_marquee_cycle * float(copies), title_h)
	_run_end_marquee_angle = atan2(view.y, view.x)
	_run_end_marquee_dir = Vector2(view.x, view.y).normalized()
	var perp := Vector2(-_run_end_marquee_dir.y, _run_end_marquee_dir.x)
	var row_gap := title_h * 0.92
	var stack_mid := view * 0.5 + perp * (-minf(view.x, view.y) * 0.02)
	_run_end_marquee_centers.clear()
	for index in RUN_END_MARQUEE_ROWS:
		var label := _run_end_marquee_rows[index]
		var row_t := float(index) - float(RUN_END_MARQUEE_ROWS - 1) * 0.5
		_run_end_marquee_centers.append(stack_mid + perp * (row_t * row_gap))
		label.text = continuous
		label.add_theme_font_size_override("font_size", title_font)
		label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0.35, 0.04, 0.06, 0.92))
		label.add_theme_constant_override("outline_size", maxi(18, title_font / 10))
		label.visible = true
	_place_run_end_marquee()
	## 統計とボタンは帯・テロップより前面へ。
	run_end_summary.visible = false
	_ensure_run_end_stats_scroll()
	_run_end_stats_body.text = _review.stats_text()
	_run_end_stats_body.add_theme_font_size_override("font_size", int(clampf(minf(view.x, view.y) * 0.018, 14.0, 18.0)))
	var stats_w := clampf(view.x * 0.42, 360.0, 560.0)
	var stats_h := clampf(view.y * 0.72, 360.0, view.y - 48.0)
	_run_end_stats_scroll.visible = true
	_run_end_stats_scroll.z_index = RUN_END_FRONT_Z
	_run_end_stats_scroll.rotation = 0.0
	_run_end_stats_scroll.position = Vector2(24.0, (view.y - stats_h) * 0.5)
	_run_end_stats_scroll.size = Vector2(stats_w, stats_h)
	_run_end_stats_body.custom_minimum_size = Vector2(stats_w - 36.0, 0.0)
	var buttons: Array[Button] = [
		review_board_button,
		review_synergy_button,
		review_stats_button,
		title_return_button,
	]
	if review_log_button.visible:
		buttons.insert(2, review_log_button)
	var btn_font := int(clampf(minf(view.x, view.y) * 0.032, 22.0, 40.0))
	var btn_box := Vector2(clampf(view.x * 0.34, 280.0, 460.0), clampf(view.y * 0.07, 56.0, 84.0))
	var btn_gap := btn_box.y + 16.0
	## 斜め並びだと押しにくいので、回転なしで画面縦に積む。
	var stack_h := btn_gap * float(buttons.size()) - 16.0
	var stack_x := clampf(view.x * 0.78, btn_box.x * 0.5 + 24.0, view.x - btn_box.x * 0.5 - 24.0)
	var stack_y := clampf(view.y * 0.42, 120.0, view.y - stack_h - 32.0)
	for index in buttons.size():
		var button := buttons[index]
		button.z_index = RUN_END_FRONT_Z + 1
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		_style_run_end_clear_button(button, btn_font)
		var center := Vector2(stack_x, stack_y + btn_gap * float(index) + btn_box.y * 0.5)
		_place_run_end_rotated(button, center, 0.0, btn_box)


func _layout_run_end_defeat(view: Vector2) -> void:
	var panel_w := clampf(view.x * 0.46, 460.0, 640.0)
	var panel_h := clampf(view.y * 0.82, 520.0, view.y - 40.0)
	var origin := (view - Vector2(panel_w, panel_h)) * 0.5
	_hide_run_end_marquee_rows()
	if not _run_end_title_phrase.is_empty():
		run_end_title.text = _run_end_title_phrase
	run_end_title.visible = true
	run_end_title.z_index = RUN_END_FRONT_Z
	run_end_title.rotation = 0.0
	run_end_title.pivot_offset = Vector2.ZERO
	run_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_end_title.add_theme_font_size_override("font_size", 42)
	run_end_title.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	run_end_title.add_theme_constant_override("outline_size", 10)
	run_end_title.position = origin + Vector2(24.0, 18.0)
	run_end_title.size = Vector2(panel_w - 48.0, 64.0)
	run_end_summary.visible = false
	_ensure_run_end_stats_scroll()
	_run_end_stats_body.text = _review.stats_text()
	_run_end_stats_scroll.visible = true
	_run_end_stats_scroll.z_index = RUN_END_FRONT_Z
	_run_end_stats_scroll.position = origin + Vector2(24.0, 90.0)
	_run_end_stats_scroll.size = Vector2(panel_w - 48.0, panel_h - 280.0)
	_run_end_stats_body.custom_minimum_size = Vector2(panel_w - 84.0, 0.0)
	var buttons: Array[Button] = [
		review_board_button,
		review_synergy_button,
		review_stats_button,
		title_return_button,
	]
	if review_log_button.visible:
		buttons.insert(2, review_log_button)
	var y := origin.y + panel_h - 48.0 * float(buttons.size()) - 16.0
	for button in buttons:
		button.z_index = RUN_END_FRONT_Z + 1
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.rotation = 0.0
		button.pivot_offset = Vector2.ZERO
		button.add_theme_font_size_override("font_size", 18)
		button.position = Vector2(origin.x + (panel_w - 240.0) * 0.5, y)
		button.size = Vector2(240.0, 40.0)
		y += 48.0


func _layout_formation_ui() -> void:
	if not is_inside_tree() or _demo_leave_started:
		return
	if _circle_wheel == null or _battle.viewport_container == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
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
	if _relic_tray != null:
		_relic_tray.position = Vector2.ZERO
		_relic_tray.size = viewport_size
		## 戦闘開始などのアクション列のすぐ左、サークル右端から縦→左へ。
		var tray_gap := 8.0
		var origin_x := shop_x - tray_gap - RelicTray.ICON
		_relic_tray.set_layout(
			Vector2(origin_x, circle_top + tray_gap),
			Vector2(battle_x, viewport_size.y - tray_gap),
			Rect2(_circle_wheel.position, _circle_wheel.size)
		)
		_relic_tray.z_index = 12
		## シナジー詳細より奥に固定（チェックをクリックできるように）。
		if _synergy_detail != null and _synergy_detail.get_parent() != null:
			_synergy_detail.z_index = 40
			_synergy_detail.get_parent().move_child(_synergy_detail, -1)
	if _board_notice != null:
		var notice_top := _battle.battle_rect.end.y
		var notice_bottom := _circle_wheel.position.y + wheel_size * 0.18
		var notice_h := maxf(72.0, notice_bottom - notice_top)
		_place_control(_board_notice, Rect2(battle_x, notice_top, battle_w, notice_h))
	if _formation_banner != null:
		var banner_h := maxf(96.0, _battle.view_height * 0.28)
		var banner_top := _battle.battle_rect.position.y + _battle.view_height * 0.28
		_place_control(_formation_banner, Rect2(battle_x, banner_top, battle_w, banner_h))
	var right_x := shop_x
	var right_bottom := bottom
	var right_h := right_bottom - top
	var mid_gap := 6.0
	var sell_h := ShopBoard.SELL_ZONE_HEIGHT
	var usable_h := maxf(160.0, right_h - sell_h - mid_gap * 2.0)
	var shop_area_h := usable_h * 0.4
	var bench_h := usable_h - shop_area_h
	var cards_x := right_x + _action_column_width + 8.0
	_shop.place(Rect2(cards_x, top, cards_w, shop_area_h))
	var sell_top := top + shop_area_h + mid_gap
	var bench_top := sell_top + sell_h + mid_gap
	_bench_board.position = Vector2(cards_x - 6.0, bench_top)
	_bench_board.size = Vector2(_shop.panel_width() + 12.0, bench_h)
	_place_overflow_pile(right_x, cards_x, bench_top, bench_h)
	if _demo_mode and _demo_overlay != null:
		## アクション列の位置に縦流し DEMO を置く。
		PlayDemo.layout_marquee(
			_demo_overlay,
			Rect2(right_x, top, _action_column_width, right_h)
		)
	## 売却帯はベンチのすぐ上（ショップとのあいだ）。
	_place_sell_zone(Rect2(cards_x - 6.0, sell_top, _shop.panel_width() + 12.0, sell_h))
	_place_side_column(right_x)
	_place_debug_roster()
	_layout_log_column()
	_layout_comment_flow()
	if _run_end_active:
		layout_run_end_overlay()
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
	if _comment_flow == null or synergy_panel == null or _circle_wheel == null:
		return
	## シナジーとサークルのあいだ。縦幅はシナジーパネルに合わせる。
	var syn := Rect2(synergy_panel.position, synergy_panel.size)
	var circle := Rect2(_circle_wheel.position, _circle_wheel.size)
	var left := syn.end.x + 4.0
	var right := circle.position.x - 4.0
	if right - left < 120.0:
		left = syn.position.x + syn.size.x * 0.55
		right = circle.position.x + circle.size.x * 0.22
	var band := Rect2(
		Vector2(left, syn.position.y),
		Vector2(maxf(120.0, right - left), maxf(96.0, syn.size.y))
	)
	_comment_flow.z_index = 7
	_comment_flow.mouse_filter = Control.MOUSE_FILTER_STOP
	_place_control(_comment_flow, band)


func _place_control(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y


func _place_overflow_pile(action_x: float, cards_x: float, bench_top: float, bench_h: float) -> void:
	if _overflow_pile == null:
		return
	var units := board.get_overflow_units()
	_overflow_pile.set_units(units)
	if units.is_empty():
		return
	var pile_w := maxf(120.0, _overflow_pile.custom_minimum_size.x)
	var pile_h := maxf(110.0, _overflow_pile.custom_minimum_size.y)
	var left := action_x - pile_w * 0.55
	var top := bench_top + bench_h - pile_h - 4.0
	_overflow_pile.z_index = 35
	_overflow_pile.position = Vector2(left, top)
	_overflow_pile.size = Vector2(maxi(int(cards_x - left + 24.0), int(pile_w)), pile_h)


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
	if _hp_exp_button != null and _hp_exp_button.visible:
		width_buttons.append(_hp_exp_button)
	if _battle_speed_button != null:
		width_buttons.append(_battle_speed_button)
	for button in width_buttons:
		button.custom_minimum_size.x = 0
	action_column.custom_minimum_size.x = 0
	var width := action_column.get_combined_minimum_size().x
	_action_column_width = maxf(36.0, ceil(width))


func _place_sell_zone(rect: Rect2) -> void:
	var zone := sell_drag_hint_right
	zone.z_index = 30
	zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
	zone.offset_left = rect.position.x
	zone.offset_top = rect.position.y
	zone.offset_right = rect.end.x
	zone.offset_bottom = rect.end.y
	_ensure_sell_hint_row()
	if zone.visible:
		_update_sell_hint_refund(_formation.dragging_unit())


func _ensure_sell_hint_row() -> void:
	var zone := sell_drag_hint_right
	if zone.get_node_or_null("SellDragRow") != null:
		return
	var old := zone.get_node_or_null("SellDragLabelRight")
	if old != null:
		old.queue_free()
	var row := HBoxContainer.new()
	row.name = "SellDragRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	var prefix := Label.new()
	prefix.name = "SellPrefix"
	prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prefix.add_theme_font_size_override("font_size", 18)
	prefix.text = "売却("
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.name = "SellCoinIcon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load("res://images/status/coin.png")
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amount := Label.new()
	amount.name = "SellAmount"
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_font_size_override("font_size", 18)
	amount.text = "0)"
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prefix)
	row.add_child(icon)
	row.add_child(amount)
	zone.add_child(row)


func _update_sell_hint_refund(unit: GameUnit) -> void:
	_ensure_sell_hint_row()
	var amount := sell_drag_hint_right.get_node_or_null("SellDragRow/SellAmount") as Label
	if amount == null:
		return
	var refund := 0
	if unit != null and is_instance_valid(unit):
		refund = RelicEconomy.star_sell_refund(session, unit.get_cost(), unit.stars)
	amount.text = "%d)" % refund


func _place_side_column(column_x: float) -> void:
	action_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	action_column.position = Vector2(column_x, bottom_ui.offset_top)
	action_column.custom_minimum_size = Vector2(_action_column_width, 0)
	var column_h := action_column.get_combined_minimum_size().y
	action_column.size = Vector2(_action_column_width, maxf(column_h, 1.0))


func _process(delta: float) -> void:
	if not is_inside_tree() or _demo_leave_started or get_viewport() == null:
		return
	if _demo_mode and not _demo_exiting and _demo_overlay != null:
		PlayDemo.tick_marquee(_demo_overlay, delta)
	if _run_end_active and _run_end_diagonal and not _run_end_marquee_rows.is_empty():
		_run_end_marquee_offset += RUN_END_MARQUEE_SPEED * delta
		_place_run_end_marquee()
	if not _demo_exiting:
		_shop.update_hover()
	if _synergy_close_left < 0.0:
		return
	if _is_pointer_over_synergy_detail():
		_synergy_close_left = -1.0
		return
	_synergy_close_left -= delta
	if _synergy_close_left > 0.0:
		return
	_synergy_close_left = -1.0
	if not _is_pointer_over_synergy_detail():
		_close_synergy_detail()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or _demo_leave_started:
		return
	if _demo_mode and not _demo_exiting and PlayDemo.is_exit_event(event):
		_exit_demo_to_title()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _relic_use_uid >= 0 and _handle_relic_use_input(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	_formation.handle_mouse_motion(event)


## 手元のレリックをクリックしたとき。使えるレリックなら確認を出す。
func _on_relic_tray_clicked(uid: int) -> void:
	if session == null or not session.is_prep() or _relic_synth == null:
		return
	var mode := RelicEconomy.use_mode(session, uid)
	if mode == RelicEconomy.USE_NONE:
		return
	var relic_id := session.relic_id_of(uid)
	_relic_synth.open_confirm("使う", relic_id, RelicEconomy.use_prompt(session, uid), func() -> void:
		_begin_relic_use(uid, mode)
	)


## キャラクターに付いているレリックをクリックしたとき。手元と同じく、使えるレリックなら確認を出す。
func _on_circle_relic_clicked(slot_index: int, relic_index: int) -> void:
	_on_equipped_relic_clicked(board.get_placed_unit(board.active_face, slot_index), relic_index)


func _on_bench_relic_clicked(slot_index: int, relic_index: int) -> void:
	if slot_index < 0 or slot_index >= board.bench_units.size():
		return
	_on_equipped_relic_clicked(board.bench_units[slot_index], relic_index)


func _on_equipped_relic_clicked(unit: GameUnit, relic_index: int) -> void:
	if unit == null or session == null or not session.is_prep() or _relic_synth == null:
		return
	if relic_index < 0 or relic_index >= unit.equipped_relic_uids.size():
		return
	var uid := unit.equipped_relic_uids[relic_index]
	## 156 ギター: 付いているキャラクターがそのまま対象。対象を選ばずに換える。
	if session.relic_id_of(uid) == 156:
		var gold := RelicEconomy.guitar_gold(session, unit)
		var body := "%s に付いている成長の与ダメージを、%d ゴールドに換えますか？" % [unit.get_display_name(), gold]
		_relic_synth.open_confirm("使う", 156, body, func() -> void:
			if RelicEconomy.use_on_unit(session, uid, unit):
				_log("ギターで %d ゴールドに換えた" % gold)
			_after_relic_use()
		)
		return
	_on_relic_tray_clicked(uid)


## 盤面のキャラクターに付いているレリックのうち、その位置にあるもの。無ければ -1。
func _equipped_relic_uid_at(at: Vector2) -> int:
	if _bench_board != null:
		var hit: Vector2i = _bench_board._relic_hit(_bench_board._to_local(at))
		if hit.x >= 0 and hit.x < board.bench_units.size():
			var benched := board.bench_units[hit.x] as GameUnit
			if benched != null and hit.y >= 0 and hit.y < benched.equipped_relic_uids.size():
				return benched.equipped_relic_uids[hit.y]
	if _circle_wheel != null:
		var hit_c: Vector2i = _circle_wheel._relic_hit(_circle_wheel._to_local(at))
		if hit_c.x >= 0:
			var placed := board.get_placed_unit(board.active_face, hit_c.x)
			if placed != null and hit_c.y >= 0 and hit_c.y < placed.equipped_relic_uids.size():
				return placed.equipped_relic_uids[hit_c.y]
	return -1


func _begin_relic_use(uid: int, mode: String) -> void:
	var name := str(RelicCatalog.get_relic(session.relic_id_of(uid)).get("name", ""))
	if mode == RelicEconomy.USE_NOW:
		if RelicEconomy.use_now(session, uid):
			_log("%s を使った" % name)
		_after_relic_use()
		return
	_relic_use_uid = uid
	_relic_use_mode = mode
	var prompt := RelicEconomy.use_prompt(session, uid) + "（右クリックで取りやめ）"
	_show_board_notice(prompt, true)
	_log(prompt)


## 対象を選ぶあいだの入力。処理したら true。
func _handle_relic_use_input(event: InputEvent) -> bool:
	var cancel := false
	if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		cancel = true
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var button := (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_RIGHT:
			cancel = true
		elif button == MOUSE_BUTTON_LEFT:
			_pick_relic_use_target((event as InputEventMouseButton).global_position)
			return true
	if cancel:
		_end_relic_use()
		_log("レリックを使うのをやめた")
		return true
	return false


func _pick_relic_use_target(at: Vector2) -> void:
	var uid := _relic_use_uid
	var relic_id := session.relic_id_of(uid)
	var name := str(RelicCatalog.get_relic(relic_id).get("name", ""))
	var used := false
	if _relic_use_mode == RelicEconomy.USE_UNIT:
		var unit := _unit_under_point(at)
		if unit == null:
			return
		used = RelicEconomy.use_on_unit(session, uid, unit)
		if used and relic_id == 191:
			_put_unit_in_egg(unit)
		if used:
			_log("%s を %s に使った" % [name, unit.get_display_name()])
		else:
			_log("%s は %s には使えない" % [name, unit.get_display_name()])
	elif _relic_use_mode == RelicEconomy.USE_RELIC:
		var target := _relic_tray.uid_at(at) if _relic_tray != null else -1
		## キャラクターに付いているレリックも、消す対象に選べる。
		if target < 0:
			target = _equipped_relic_uid_at(at)
		if target < 0:
			return
		var target_name := str(RelicCatalog.get_relic(session.relic_id_of(target)).get("name", ""))
		used = RelicEconomy.use_on_relic(session, uid, target)
		if used:
			_log("%s で %s を消した" % [name, target_name])
		else:
			_log("%s は消せない" % target_name)
	_end_relic_use()
	_after_relic_use()


## 見学(191): 卵に入れたキャラクターは盤面から外す。装備は手元に戻る。
func _put_unit_in_egg(unit: GameUnit) -> void:
	unit.equipped_relic_uids.clear()
	board.remove_unit(unit)
	unit.queue_free()


func _end_relic_use() -> void:
	_relic_use_uid = -1
	_relic_use_mode = ""
	if _board_notice != null and _board_notice.is_persistent():
		_board_notice.clear_persistent()
	_refresh_overflow_notice()


func _after_relic_use() -> void:
	_formation.refresh_widgets()
	_update_ui()


func relic_rewrite_bottom_bench(times: int) -> void:
	var columns := 3
	var rows := int(board.bench_units.size() / columns)
	if rows <= 0:
		return
	var start := (rows - 1) * columns
	for _time in times:
		for slot_index in range(start, start + columns):
			var unit := board.bench_units[slot_index] as GameUnit
			if unit == null:
				continue
			var choices: Array[int] = []
			for candidate in UnitCatalog.get_unit_ids_by_cost(unit.get_cost()):
				if candidate != unit.unit_id:
					choices.append(candidate)
			if choices.is_empty():
				continue
			var stars := unit.stars
			var relics: Array[int] = []
			for uid in unit.equipped_relic_uids:
				relics.append(uid)
			board.remove_unit(unit)
			unit.queue_free()
			var created := GameUnit.create(choices[randi() % choices.size()], stars)
			units_root.add_child(created)
			created.equipped_relic_uids = relics
			board.place_on_bench(created, slot_index, false)
	board.resolve_merges()


## 西通り(108): サークルの味方をコスト+上昇のランダムキャラに変換。コスト7は不変。合成上限で頭打ち。
func relic_upgrade_board_costs(bump: int = 1) -> void:
	var cap := RelicEconomy.synth_cost_cap(session)
	var targets: Array[GameUnit] = []
	for unit in board.get_circle_units():
		if unit != null and is_instance_valid(unit) and not unit.is_enemy:
			targets.append(unit)
	for unit in targets:
		var cost := unit.get_cost()
		## コスト7は変わらない。
		if cost >= ShopOdds.MAX_COST:
			continue
		var target_cost := clampi(mini(cost + maxi(bump, 0), cap), 1, ShopOdds.MAX_COST)
		var choices: Array[int] = []
		for candidate in UnitCatalog.get_unit_ids_by_cost(target_cost):
			if candidate != unit.unit_id:
				choices.append(candidate)
		if choices.is_empty():
			choices = UnitCatalog.get_unit_ids_by_cost(target_cost)
		if choices.is_empty():
			continue
		var stars := unit.stars
		var relics: Array[int] = []
		for uid in unit.equipped_relic_uids:
			relics.append(uid)
		var face := unit.circle_face
		var slot := unit.circle_slot
		board.remove_unit(unit)
		unit.queue_free()
		var created := GameUnit.create(choices[randi() % choices.size()], stars)
		units_root.add_child(created)
		created.equipped_relic_uids = relics
		board.place_on_circle(created, face, slot, false)
	board.resolve_merges()
	_formation.refresh_widgets()
	_log("西通りでサークルのキャラクターが入れ替わった")


func _flush_relic_units() -> void:
	if _flushing_relic_units or session.relic_pending_units.is_empty():
		return
	_flushing_relic_units = true
	var pending := session.relic_pending_units.duplicate()
	session.relic_pending_units.clear()
	for entry in pending:
		var unit_id := int(entry.get("id", -1))
		var stars := int(entry.get("stars", 1))
		var data := UnitCatalog.get_unit(unit_id)
		if data.is_empty():
			continue
		var unit := GameUnit.create(unit_id, stars)
		units_root.add_child(unit)
		var slot := board.find_empty_bench_slot()
		if slot < 0:
			board.push_overflow(unit)
			_show_board_notice(NOTICE_OVERFLOW, true)
			_log("%s が溢れた" % str(data["name"]))
			continue
		if not board.place_on_bench(unit, slot):
			unit.queue_free()
			continue
		_log("%s を獲得した" % str(data["name"]))
	_flushing_relic_units = false


func _update_ui() -> void:
	_flush_relic_units()
	_flush_relic_picks()
	board.board_unit_limit = session.get_board_unit_cap()
	_formation.refresh_widgets()
	call_deferred("_layout_formation_ui")
	if _demo_leave_started or not is_inside_tree():
		return
	if _demo_mode and not _demo_exiting:
		_apply_demo_chrome()
		round_label.text = "ラウンド: %d / %d" % [session.round_number, session.max_round]
		hp_label.text = "HP: %d / %d" % [session.player_hp, RelicEconomy.player_max_hp(session)]
		coin_label.text = str(session.coins)
		_update_synergy_panel()
		return
	if _run_end_active:
		call_deferred("layout_run_end_overlay")
		_set_debug_roster_open(false)
		battle_button.disabled = true
		back_button.disabled = true
		reroll_button.disabled = true
		exp_button.disabled = true
		if _hp_exp_button != null:
			_hp_exp_button.visible = false
			_hp_exp_button.disabled = true
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
	coin_label.text = str(session.coins)
	var streak_text := _format_streak_text()
	streak_label.text = streak_text
	var streak_visible := not streak_text.is_empty()
	if streak_badge.visible != streak_visible:
		streak_badge.visible = streak_visible
		_request_bottom_ui_refit()
	else:
		streak_badge.visible = streak_visible
	var level := session.get_level()
	var level_cap := RelicEconomy.level_cap(session)
	var xp_into := PlayerLevel.get_xp_into_current_level(session.experience, level_cap)
	var xp_need := PlayerLevel.get_xp_needed_for_next_level(level, level_cap)
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
	var odds_level := RelicEconomy.shop_odds_level(session, false)
	ShopOdds.populate_current_odds_row(shop_odds_row, odds_level)
	_shop.fit_badge_width()
	if not session.is_prep() or _run_end_active:
		_shop.hide_odds_table()
	elif shop_odds_tooltip.visible:
		ShopOdds.populate_odds_grid(shop_odds_grid, odds_level)
		_shop.call_deferred("_fit_tooltip_size")
	shop_lock_button.text = "🔒" if session.shop_locked else "🔓"
	shop_lock_button.disabled = not session.is_prep()
	var round_cap := session.max_round
	round_label.text = "ラウンド: %d / %d" % [mini(session.round_number, round_cap), round_cap]
	hp_label.text = "HP: %d / %d" % [session.player_hp, RelicEconomy.player_max_hp(session)]
	var bench_count := 0
	for slot in board.bench_units:
		if slot != null:
			bench_count += 1
	if _bench_board != null:
		_bench_board.set_count(bench_count, board.bench_units.size())
	bench_badge.visible = false
	var paid_reroll := RelicEconomy.paid_reroll_cost(session)
	## 258 雲: ゴールドを払って更新できない。
	var paid_reroll_blocked := RelicEconomy.blocks_paid_reroll(session)
	reroll_button.text = "(不可)" if paid_reroll_blocked else "(%d)" % paid_reroll
	if session.free_rerolls > 0:
		reroll_button.text = "無料×%d" % session.free_rerolls
	var reroll_text := reroll_button.text
	var reroll_text_changed := reroll_text != _last_reroll_button_text
	if reroll_text_changed:
		_last_reroll_button_text = reroll_text
	var economy_open := session.is_prep() or session.phase == GameSession.Phase.BATTLE
	reroll_button.disabled = not economy_open or session.shop_locked or (
		session.free_rerolls <= 0 and (paid_reroll_blocked or session.coins < paid_reroll)
	)
	var exp_cost := RelicEconomy.exp_cost(session)
	## 254 二重: ゴールドで経験値を買えない。
	var gold_exp_blocked := RelicEconomy.blocks_gold_exp(session)
	if gold_exp_blocked:
		exp_button.text = "+%d\n(不可)" % (GameSession.EXP_GAIN + RelicEconomy.exp_bonus(session))
	else:
		exp_button.text = "+%d\n(%d)" % [GameSession.EXP_GAIN + RelicEconomy.exp_bonus(session), exp_cost]
	var hp_cost := RelicEconomy.hp_exp_cost(session)
	if _hp_exp_button != null:
		_hp_exp_button.visible = hp_cost > 0
		_hp_exp_button.text = "HP-%d\n+%d" % [hp_cost, RelicEconomy.hp_exp_gain(session)]
		_hp_exp_button.disabled = not economy_open or session.player_hp < hp_cost
	exp_button.disabled = not economy_open or gold_exp_blocked or session.coins < exp_cost
	exp_button.mouse_filter = Control.MOUSE_FILTER_STOP
	reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if _battle_playing:
		battle_button.text = "やり直し中…" if _battle_restart_requested else "戦闘やり直し"
		battle_button.disabled = _battle_restart_requested
	else:
		battle_button.text = "戦闘開始"
		battle_button.disabled = not session.is_prep() or not board.has_circle_ally() or board.has_overflow()
	if _debug_roster_button != null:
		_debug_roster_button.disabled = not session.is_prep()
		if not session.is_prep():
			_set_debug_roster_open(false)
	if _debug_roster_grid != null:
		var debug_blocked := not session.is_prep()
		for child in _debug_roster_grid.get_children():
			var card := child as BaseButton
			if card != null:
				card.disabled = debug_blocked
	input_handler.set_enabled(economy_open and not _run_end_active and not _relic_pick_active)
	if _relic_pick_active and not _battle_playing:
		battle_button.disabled = true
		reroll_button.disabled = true
		exp_button.disabled = true
		if _hp_exp_button != null:
			_hp_exp_button.disabled = true
		shop_lock_button.disabled = true
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
		var cost := RelicEconomy.shop_price(session, index)
		slot.set_unit(unit_id, cost)
		slot.disabled = not economy_open or session.coins < cost
	_refresh_shop_synergy_watch()
	_refresh_overflow_notice()
	_update_synergy_panel()
	if economy_open and not _run_end_active:
		if reroll_text_changed:
			_request_bottom_ui_refit()
		else:
			call_deferred("_position_coin_row_over_shop")
