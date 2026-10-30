class_name RunReview
extends RefCounted

enum Mode { MENU, BOARD, SYNERGY, LOG, STATS }

var _host: Node


func setup(host: Node) -> void:
	_host = host


func show_end_screen() -> void:
	if _host._run_end_active:
		return
	_host._run_end_active = true
	_host._run_review_mode = Mode.MENU
	_host.battle_overlay.visible = false
	_host.extension_overlay.visible = false
	_host.route_overlay.visible = false
	_host.income_overlay.visible = false
	_host.run_stats_panel.visible = false
	_host.run_end_review_bar.visible = false
	_host.run_end_title.text = end_title()
	_host.run_end_summary.text = end_summary()
	_host.run_stats_label.text = stats_text()
	_host.run_end_overlay.visible = true
	_host.prep_blocker.visible = true
	_host.input_handler.set_enabled(false)
	_host.shop_panel.visible = false
	_host.coin_row.visible = false
	_host._collapse_log_panel()
	_host._set_synergy_panel_review_mode(false)
	match _host.session.run_end_reason:
		GameSession.RunEndReason.DEFEAT:
			_host._log("HPが0になった")
		GameSession.RunEndReason.CLEAR:
			_host._log("ゲームクリア")
		GameSession.RunEndReason.VOLUNTARY_END:
			pass
	_host.run_end_overlay.z_index = 70
	_host.run_end_review_bar.z_index = 70
	_host.run_stats_panel.z_index = 70
	var reason: GameSession.RunEndReason = _host.session.run_end_reason
	_host._battle.set_clear_art(reason == GameSession.RunEndReason.CLEAR)
	_host._battle.set_clear_stripes(reason == GameSession.RunEndReason.CLEAR or reason == GameSession.RunEndReason.VOLUNTARY_END)
	_host._update_ui()


func enter(mode: Mode) -> void:
	if not _host._run_end_active:
		return
	_host._run_review_mode = mode
	_host.run_end_overlay.visible = false
	_host.run_end_review_bar.visible = true
	_host.prep_blocker.visible = false
	_host.run_stats_panel.visible = false
	_host._set_synergy_panel_review_mode(false)
	if _host._log_expanded:
		_host._log_expanded = false
		_host._apply_log_panel_layout()
	match mode:
		Mode.BOARD:
			_host.review_bar_label.text = "ラン終了 — 編成を確認中"
			_host._battle.setup_camera()
		Mode.SYNERGY:
			_host.review_bar_label.text = "ラン終了 — シナジーを確認中"
			_host._set_synergy_panel_review_mode(true)
			_host._update_synergy_panel()
		Mode.LOG:
			_host.review_bar_label.text = "ラン終了 — ログを確認中"
			_host._log_expanded = true
			_host._apply_log_panel_layout()
			_host._refresh_event_log()
		Mode.STATS:
			_host.review_bar_label.text = "ラン終了 — 戦績詳細"
			_host.run_stats_label.text = stats_text()
			_host.run_stats_panel.visible = true


func return_to_menu() -> void:
	if not _host._run_end_active:
		return
	_host._run_review_mode = Mode.MENU
	_host.run_end_overlay.visible = true
	_host.run_end_review_bar.visible = false
	_host.run_stats_panel.visible = false
	_host.prep_blocker.visible = true
	_host._set_synergy_panel_review_mode(false)
	if _host._log_expanded:
		_host._log_expanded = false
		_host._apply_log_panel_layout()


func leave_to_title() -> void:
	_host.get_tree().change_scene_to_file("res://scenes/title.tscn")


func end_title() -> String:
	match _host.session.run_end_reason:
		GameSession.RunEndReason.DEFEAT:
			return "敗北"
		GameSession.RunEndReason.CLEAR:
			return "完全クリア"
		GameSession.RunEndReason.VOLUNTARY_END:
			return "クリア"
	return "ラン終了"


func reached_round() -> int:
	if _host.session.run_end_reason == GameSession.RunEndReason.DEFEAT:
		return maxi(1, _host.session.round_number - 1)
	return mini(_host.session.round_number - 1, _host.session.max_round)


func end_summary() -> String:
	var reached := reached_round()
	return "到達ラウンド: %d / %d\nHP: %d  Lv.%d  コイン: %d" % [
		reached,
		_host.session.max_round,
		_host.session.player_hp,
		_host.session.get_level(),
		_host.session.coins,
	]


func stats_text() -> String:
	var lines: PackedStringArray = []
	var reached := reached_round()
	lines.append("結果: %s" % end_title())
	lines.append("到達ラウンド: %d / %d" % [reached, _host.session.max_round])
	lines.append("HP: %d / %d" % [_host.session.player_hp, PlayerHp.INITIAL_HP])
	lines.append("レベル: %d" % _host.session.get_level())
	lines.append("経験値: %d" % _host.session.experience)
	lines.append("コイン: %d" % _host.session.coins)
	lines.append("連勝: %d  連敗: %d" % [_host.session.win_streak, _host.session.loss_streak])
	lines.append("延長モード: %s" % ("あり" if _host.session.extended_mode else "なし"))
	lines.append("")
	lines.append("サークル (%d / %d)" % [
	
			_host.board.get_board_unit_count(),
		_host.session.get_board_unit_cap(),
	])
	for face_index in _host.board.get_unlocked_face_count():
		lines.append("%d面" % [face_index + 1])
		for slot_index in BoardController.SLOTS_PER_FACE:
			var placed: GameUnit = _host.board.get_placed_unit(face_index, slot_index)
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
	for slot in _host.board.bench_units:
		if slot == null:
			continue
		bench_count += 1
	lines.append("")
	lines.append("ベンチ (%d)" % bench_count)
	for slot in _host.board.bench_units:
		var unit: GameUnit = slot as GameUnit
		if unit == null:
			continue
		lines.append("  %s %s (%dコスト)" % [
			unit.get_display_name(),
			unit.get_star_text(),
			unit.get_cost(),
		])
	var synergies := SynergyTracker.list_synergies(_host.board.get_circle_units(), _host.session)
	if synergies.is_empty():
		lines.append("")
		lines.append("シナジー: なし")
	else:
		lines.append("")
		lines.append("シナジー:")
		for entry in synergies:
			lines.append("  %s  %d人 / %d段階" % [
				entry["name"],
				entry["count"],
				entry["stage_count"],
			])
	return "\n".join(lines)
