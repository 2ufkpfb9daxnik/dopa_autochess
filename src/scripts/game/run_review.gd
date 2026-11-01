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
	_host._run_end_title_phrase = end_title()
	_host._run_end_marquee_offset = 0.0
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
	_host.layout_run_end_overlay()
	_host.call_deferred("layout_run_end_overlay")


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
	_host.layout_run_end_overlay()
	_host.call_deferred("layout_run_end_overlay")


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
	## 終了画面にもフル統計を出す。
	return stats_text()


func stats_text() -> String:
	var s: GameSession = _host.session
	var lines: PackedStringArray = []
	var reached := reached_round()
	var battles := s.tally_battles_won + s.tally_battles_lost
	var win_rate := 0.0 if battles <= 0 else 100.0 * float(s.tally_battles_won) / float(battles)

	lines.append("【結果】")
	lines.append("結果: %s" % end_title())
	lines.append("到達ラウンド: %d / %d" % [reached, s.max_round])
	lines.append("現在ラウンド番号: %d" % s.round_number)
	lines.append("延長モード: %s" % ("あり" if s.extended_mode else "なし"))
	lines.append("通常上限: %d  延長込み上限: %d" % [GameSession.NORMAL_MAX_ROUND, s.max_round])
	lines.append("")

	lines.append("【プレイヤー】")
	lines.append("残りHP: %d / %d" % [s.player_hp, PlayerHp.INITIAL_HP])
	lines.append("被ダメージ合計: %d" % s.tally_damage_taken)
	lines.append("HP消費で買った経験値: %d回（HP %d）" % [s.tally_hp_exp_buys, s.tally_hp_spent_on_exp])
	lines.append("レベル: %d（最高 Lv.%d）" % [s.get_level(), s.tally_peak_level])
	lines.append("経験値: %d" % s.experience)
	lines.append("出撃上限: %d" % s.get_board_unit_cap())
	lines.append("ショップ出現レベル: %d" % s.shop_odds_level)
	lines.append("")

	lines.append("【経済】")
	lines.append("所持コイン: %d（ピーク %d）" % [s.coins, s.tally_peak_coins])
	lines.append("獲得コイン合計: %d" % s.tally_gold_gained)
	lines.append("消費コイン合計: %d" % s.tally_gold_spent)
	lines.append("ラウンド開始収入合計: %d" % s.tally_income_gold)
	lines.append("浄化収入合計: %d" % s.tally_cleanse_gold)
	if not s.last_income_breakdown.is_empty():
		lines.append("直近収入内訳: 基本%d 利息%d ストリーク%d ラウンド%d 合計%d" % [
			int(s.last_income_breakdown.get("base", 0)),
			int(s.last_income_breakdown.get("holding", 0)),
			int(s.last_income_breakdown.get("streak", 0)),
			int(s.last_income_breakdown.get("round", 0)),
			int(s.last_income_breakdown.get("total", 0)),
		])
	lines.append("直近浄化収入: %d" % s.last_cleanse_income)
	lines.append("無料リロール残り: %d" % s.free_rerolls)
	lines.append("有料リロール回数: %d" % s.tally_rerolls_paid)
	lines.append("無料リロール使用: %d" % s.tally_rerolls_free)
	lines.append("経験値購入: %d回" % s.tally_exp_buys)
	lines.append("ショップロック切替: %d回" % s.tally_shop_locks)
	lines.append("ショップロック中: %s" % ("はい" if s.shop_locked else "いいえ"))
	lines.append("")

	lines.append("【戦闘】")
	lines.append("勝利: %d  敗北: %d  合計: %d" % [s.tally_battles_won, s.tally_battles_lost, battles])
	lines.append("勝率: %.1f%%" % win_rate)
	lines.append("現在連勝: %d  現在連敗: %d" % [s.win_streak, s.loss_streak])
	lines.append("最大連勝: %d  最大連敗: %d" % [s.tally_max_win_streak, s.tally_max_loss_streak])
	lines.append("ルート選択回数: %d" % s.tally_routes_picked)
	if not s.selected_route.is_empty():
		lines.append("直近ルート: 敵%s / 報酬 %s" % [
			str(s.selected_route.get("enemy_label", "?")),
			str(s.selected_route.get("reward_label", "なし")),
		])
	lines.append("")

	lines.append("【編成・ショップ】")
	lines.append("購入ユニット: %d" % s.tally_units_bought)
	lines.append("売却: %d" % s.tally_units_sold)
	lines.append("合成回数: %d" % s.tally_merges)
	lines.append("サークル配置ピーク: %d" % s.tally_peak_board)
	lines.append("サークル (%d / %d)" % [
		_host.board.get_board_unit_count(),
		s.get_board_unit_cap(),
	])
	lines.append("解放面数: %d" % _host.board.get_unlocked_face_count())
	var cost_hist: Dictionary = {}
	var star_hist: Dictionary = {}
	var unit_hist: Dictionary = {}
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
			cost_hist[placed.get_cost()] = int(cost_hist.get(placed.get_cost(), 0)) + 1
			star_hist[placed.stars] = int(star_hist.get(placed.stars, 0)) + 1
			unit_hist[placed.unit_id] = int(unit_hist.get(placed.unit_id, 0)) + 1
	var bench_count := 0
	for slot in _host.board.bench_units:
		if slot == null:
			continue
		bench_count += 1
	lines.append("ベンチ (%d / %d)" % [bench_count, _host.board.bench_units.size()])
	for slot in _host.board.bench_units:
		var unit: GameUnit = slot as GameUnit
		if unit == null:
			continue
		lines.append("  %s %s (%dコスト)" % [
			unit.get_display_name(),
			unit.get_star_text(),
			unit.get_cost(),
		])
		cost_hist[unit.get_cost()] = int(cost_hist.get(unit.get_cost(), 0)) + 1
		star_hist[unit.stars] = int(star_hist.get(unit.stars, 0)) + 1
		unit_hist[unit.unit_id] = int(unit_hist.get(unit.unit_id, 0)) + 1
	if not cost_hist.is_empty():
		var cost_bits: PackedStringArray = []
		var costs := cost_hist.keys()
		costs.sort()
		for cost in costs:
			cost_bits.append("%dコ×%d" % [int(cost), int(cost_hist[cost])])
		lines.append("コスト内訳: %s" % "  ".join(cost_bits))
	if not star_hist.is_empty():
		var star_bits: PackedStringArray = []
		var stars := star_hist.keys()
		stars.sort()
		for star in stars:
			star_bits.append("%d★×%d" % [int(star), int(star_hist[star])])
		lines.append("星内訳: %s" % "  ".join(star_bits))
	if not unit_hist.is_empty():
		lines.append("所持キャラ種類: %d" % unit_hist.size())
	var overflow_units: Array = _host.board.get_overflow_units()
	if overflow_units.is_empty():
		lines.append("オーバーフロー: なし")
	else:
		lines.append("オーバーフロー (%d)" % overflow_units.size())
		for item in overflow_units:
			var over: GameUnit = item as GameUnit
			if over == null:
				continue
			lines.append("  %s %s (%dコスト)" % [
				over.get_display_name(),
				over.get_star_text(),
				over.get_cost(),
			])
	lines.append("")

	var synergies := SynergyTracker.list_synergies(_host.board.get_circle_units(), s)
	if synergies.is_empty():
		lines.append("【シナジー】なし")
	else:
		lines.append("【シナジー】")
		for entry in synergies:
			lines.append("  %s  %d人 / %d段階" % [
				entry["name"],
				entry["count"],
				entry["stage_count"],
			])
	lines.append("")

	lines.append("【レリック】所持 %d（入手累計 %d）" % [s.relics.size(), s.tally_relics_gained])
	if s.relics.is_empty():
		lines.append("  （なし）")
	else:
		var by_id: Dictionary = {}
		for item in s.relics:
			var rid := int(item.get("id", -1))
			by_id[rid] = int(by_id.get(rid, 0)) + 1
		var ids := by_id.keys()
		ids.sort()
		for rid in ids:
			var data := RelicCatalog.get_relic(int(rid))
			var nm := str(data.get("name", "？"))
			var n := int(by_id[rid])
			if n > 1:
				lines.append("  %s ×%d" % [nm, n])
			else:
				lines.append("  %s" % nm)
	if not s.relic_buy_counts.is_empty():
		lines.append("レリック入手回数メモ:")
		for key in s.relic_buy_counts.keys():
			lines.append("  id %s: %s" % [str(key), str(s.relic_buy_counts[key])])
	lines.append("")

	lines.append("【ショップ残枠】")
	var shop_left := 0
	for unit_id in s.shop_unit_ids:
		if int(unit_id) < 0:
			continue
		shop_left += 1
		var udata := UnitCatalog.get_unit(int(unit_id))
		lines.append("  %s (%dコスト)" % [str(udata.get("name", "?")), int(udata.get("cost", 0))])
	if shop_left == 0:
		lines.append("  （空き）")
	lines.append("")

	lines.append("【イベントログ】直近")
	var messages: Array = []
	if _host.event_log != null:
		messages = _host.event_log.get_messages()
	if messages.is_empty():
		lines.append("  （なし）")
	else:
		var start := maxi(0, messages.size() - 40)
		for index in range(start, messages.size()):
			lines.append("  %s" % str(messages[index]))

	return "\n".join(lines)
