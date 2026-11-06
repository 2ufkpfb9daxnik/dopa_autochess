class_name Tutorial
extends Control

## タイトルから入る操作案内。ショップの並びは固定で、戦闘の乱数はシードで揃える。

const META := &"play_tutorial"
const SEED := 20261106
const OPENING: Array[int] = [19, 25, 28, 46, 47, 49]
const REROLLED: Array[int] = [53, 56, 57, 60, 69, 71]
const RELIC_ID := 1
const ENEMY_ID := 25

enum Step { BUY, PLACE, EXP, REROLL, EQUIP, BATTLE, FIGHT, DONE }

var _host: Node
var _step := Step.BUY
var _banner: PanelContainer
var _label: Label
var _leave_button: Button
var _focus := Rect2()
var _pulse := 0.0
var _relic_given := false
var _reroll_done := false


static func mark_pending(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.set_meta(META, true)


static func consume_pending(tree: SceneTree) -> bool:
	if tree == null or not tree.has_meta(META):
		return false
	var pending := bool(tree.get_meta(META))
	tree.remove_meta(META)
	return pending


static func spawn_enemy(host: Node) -> int:
	var board: BoardController = host.board
	var units_root: Node3D = host.units_root
	board.clear_enemy_units()
	var unit := GameUnit.create(ENEMY_ID, 1)
	unit.is_enemy = true
	units_root.add_child(unit)
	board.place_enemy_unit(unit, 0)
	return 1


func start(host: Node) -> void:
	_host = host
	seed(SEED)
	var session: GameSession = host.session
	session.shop_unit_ids = OPENING.duplicate()
	session.coins = GameSession.INITIAL_COINS
	session.state_changed.emit()
	name = "Tutorial"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 70
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_banner()
	var ui := host.get_node("CanvasLayer/UI") as Control
	ui.add_child(self)
	move_to_front()
	_apply_step_text()
	set_process(true)


func allows_battle() -> bool:
	return _step == Step.BATTLE or _step == Step.FIGHT


func on_rerolled() -> void:
	if _step != Step.REROLL or _host == null:
		return
	var session: GameSession = _host.session
	session.shop_unit_ids = REROLLED.duplicate()
	session.state_changed.emit()
	_reroll_done = true


func on_battle_ended(won: bool) -> void:
	_step = Step.DONE
	_focus = Rect2()
	queue_redraw()
	if won:
		_label.text = "戦闘に勝ちました。買う、置く、経験値、更新、レリックの装備、戦闘開始。ここまでが一通りです。"
	else:
		_label.text = "戦闘が終わりました。勝敗より、買う、置く、経験値、更新、レリックの装備、戦闘開始の順が分かれば十分です。"
	_leave_button.text = "タイトルへ戻る"
	_leave_button.custom_minimum_size = Vector2(220, 48)


func _process(delta: float) -> void:
	_pulse += delta
	_layout_banner()
	_advance()
	_focus = _focus_rect()
	queue_redraw()


func _advance() -> void:
	if _host == null or _step == Step.DONE or _step == Step.FIGHT:
		return
	if not _step_done():
		return
	_step += 1
	if _step == Step.EQUIP and not _relic_given:
		_relic_given = true
		_host.session.add_relic(RELIC_ID)
	if _step == Step.FIGHT:
		pass
	_apply_step_text()


func _step_done() -> bool:
	var session: GameSession = _host.session
	var board: BoardController = _host.board
	match _step:
		Step.BUY:
			return _has_ally(board)
		Step.PLACE:
			return board.has_circle_ally()
		Step.EXP:
			return session.get_level() >= 2
		Step.REROLL:
			return _reroll_done
		Step.EQUIP:
			return _someone_equipped(board)
		Step.BATTLE:
			return session.phase == GameSession.Phase.BATTLE
		_:
			return false


func _apply_step_text() -> void:
	match _step:
		Step.BUY:
			_label.text = "ショップの左端、カコガワをクリックして買いましょう。1コインで、買ったキャラクターはベンチに入ります。"
		Step.PLACE:
			_label.text = "ベンチのキャラクターを、中央のサークルへドラッグして配置しましょう。レベル1では1人まで置けます。"
		Step.EXP:
			_label.text = "光っている経験値ボタンを押しましょう。4コインで経験値を買い、レベルが上がるとサークルに置ける人数が増えます。"
		Step.REROLL:
			_label.text = "光っている更新ボタンを押しましょう。2コインでショップの並びが入れ替わります。"
		Step.EQUIP:
			_label.text = "出てきたレリック「美術館」を、サークルのキャラクターへドラッグして装備しましょう。装備しているあいだ、そのキャラクターのダメージが15%上がります。持っているだけでは効きません。"
		Step.BATTLE:
			_label.text = "戦闘開始を押しましょう。敵は弱い1体だけです。"
		Step.FIGHT:
			_label.text = "戦闘中です。装備したレリックは、そのキャラクターの攻撃に入ります。"
		Step.DONE:
			pass


func _focus_rect() -> Rect2:
	if _host == null or _step == Step.FIGHT or _step == Step.DONE:
		return Rect2()
	var target: Control = null
	match _step:
		Step.BUY:
			var slots: Container = _host.shop_slots
			if slots != null and slots.get_child_count() > 0:
				target = slots.get_child(0) as Control
		Step.PLACE:
			target = _host._bench_board
		Step.EXP:
			target = _host.exp_button
		Step.REROLL:
			target = _host.reroll_button
		Step.EQUIP:
			var tray: RelicTray = _host._relic_tray
			if tray != null:
				var relic_rect := tray.icon_global_rect()
				if relic_rect.size.x > 1.0:
					return relic_rect.grow(6.0)
		Step.BATTLE:
			target = _host.battle_button
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return Rect2()
	return target.get_global_rect().grow(6.0)


func _draw() -> void:
	if _focus.size.x < 2.0:
		return
	var rect := Rect2(_focus.position - global_position, _focus.size)
	var alpha := 0.55 + 0.4 * absf(sin(_pulse * 4.0))
	draw_rect(rect, Color(1.0, 0.86, 0.2, alpha), false, 4.0)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.94)
	style.border_color = Color(0.95, 0.82, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_banner.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_banner.add_child(column)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	column.add_child(_label)
	_leave_button = Button.new()
	_leave_button.text = "タイトルへ"
	_leave_button.custom_minimum_size = Vector2(140, 36)
	_leave_button.add_theme_font_size_override("font_size", 18)
	_leave_button.pressed.connect(_leave)
	column.add_child(_leave_button)
	add_child(_banner)


func _layout_banner() -> void:
	if _banner == null:
		return
	var width := minf(760.0, maxf(280.0, size.x - 48.0))
	_banner.custom_minimum_size.x = width
	_banner.position = Vector2((size.x - width) * 0.5, 16.0)
	_banner.size.x = width


func _leave() -> void:
	if _host == null:
		return
	_host.get_tree().change_scene_to_file("res://scenes/title.tscn")


func _has_ally(board: BoardController) -> bool:
	if board.has_circle_ally():
		return true
	for slot in board.bench_units:
		if slot != null:
			return true
	return false


func _someone_equipped(board: BoardController) -> bool:
	for unit in board.get_all_units():
		if unit != null and is_instance_valid(unit) and not unit.equipped_relic_uids.is_empty():
			return true
	return false
