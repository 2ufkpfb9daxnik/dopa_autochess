extends "res://scripts/game/relic_economy_growth.gd"

## クエスト・達成報酬と、戦闘結果で動くレリック。対人戦は無いので「プレイヤー同士の戦闘」はラウンドの戦闘として扱う。
## 継承のつながりは relic_economy_base.gd の先頭を参照。


## 戦闘終了時に勝敗と戦闘中の記録(stats)を受け取る。stats は BattleDirector.play() の "relic_stats"。
static func note_battle_outcome(session: GameSession, won: bool, stats: Dictionary) -> void:
	_apply_outcome_gold(session, won, int(stats.get("alive_allies", 0)))
	_apply_outcome_growth(session, stats.get("units", []))
	_apply_outcome_quests(session, stats)
	_apply_outcome_removals(session, won)
	_advance_homecoming(session, won)
	_note_slide(session, won)
	if won:
		session.relic_139_pending = _owned_value(session, 139, "値引き")


static func note_battle_finished(session: GameSession, won: bool) -> void:
	## 261: 戦闘ごとに1減り、0でゴールド。
	var finished := _count_down(session, 261)
	for item in finished:
		session.add_coins(int(_value(261, "ゴールド")))
	for item in finished:
		session.take_relic(int(item.get("uid", -1)))
	if not won and _count(session, 172) > 0:
		var missing := maxi(player_max_hp(session) - session.player_hp, 0)
		_heal_player(session, int(round(float(missing) * float(_count(session, 172)) * _value(172, "回復") / 100.0)))
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 259:
			continue
		if won:
			item["armed"] = true
		elif bool(item.get("armed", false)):
			session.take_relic(int(item.get("uid", -1)))
	note_streak_quests(session)


static func _apply_outcome_gold(session: GameSession, won: bool, alive_allies: int) -> void:
	var xp := 0
	if won:
		xp += _owned_value(session, 87, "勝ち")
		session.add_coins(_owned_value(session, 122, "ゴールド"))
		var per := maxi(int(_value(129, "人数")), 1)
		session.add_coins(_count(session, 129) * (alive_allies / per) * int(_value(129, "ゴールド")))
		if session.win_streak >= int(_value(134, "連勝")):
			xp += _owned_value(session, 134, "経験値")
	else:
		xp += _owned_value(session, 87, "負け")
		session.add_coins(_owned_value(session, 121, "ゴールド"))
		session.free_rerolls += _owned_value(session, 121, "無料更新")
		if session.loss_streak >= int(_value(135, "連敗")):
			session.free_rerolls += _owned_value(session, 135, "無料更新")
	if xp > 0:
		session.gain_experience(xp)


## 戦闘中の数を持ち越しで数えるクエスト（166・287〜291・184・300）。
static func _apply_outcome_quests(session: GameSession, stats: Dictionary) -> void:
	var team_max := maxi(int(stats.get("team_max", 0)), 1)
	if _count(session, 166) > 0:
		session.relic_166_bank += int(stats.get("team_taken", 0))
		var gate := maxi(1, int(ceil(float(team_max) * _value(166, "閾値") / 100.0)))
		while session.relic_166_bank >= gate:
			session.relic_166_bank -= gate
			session.add_relic(166)
	_progress_quest(session, 287, int(stats.get("team_dealt", 0)), team_max * int(_value(287, "倍率")), _grants(session, _is_strike_relic, 2))
	_progress_quest(session, 288, int(stats.get("team_taken", 0)), team_max * int(_value(288, "倍率")), _grants(session, _is_guard_relic, 2))
	_progress_quest(session, 289, int(stats.get("crits", 0)), int(_value(289, "進捗")), _grants(session, _is_crit_relic, 2))
	_progress_quest(session, 290, int(stats.get("hits", 0)), int(_value(290, "進捗")), _grants(session, _is_speed_relic, 2))
	_progress_quest(session, 291, int(stats.get("gauge_spent", 0)), int(_value(291, "ゲージ")), _grants(session, _is_gauge_relic, 2))
	var broken := int(stats.get("devices_broken", 0))
	_progress_quest(session, 184, broken, int(_value(184, "回数")), _grants(session, _is_guard_relic, 1))
	_progress_quest(session, 300, broken, int(_value(300, "進捗")), func() -> void:
		session.add_relic(181)
		session.add_relic(181)
	)


static func _apply_outcome_removals(session: GameSession, won: bool) -> void:
	if won:
		_consume_all(session, 132)
		_consume_all(session, 136)
	else:
		_consume_all(session, 131)
		_consume_all(session, 137)


## 192 帰宅: ラウンドごとに1、勝つとさらに1減る。0でゴールドとレリック。
static func _advance_homecoming(session: GameSession, won: bool) -> void:
	for item in _count_down(session, 192, 2 if won else 1, int(_value(192, "ラウンド"))):
		session.take_relic(int(item.get("uid", -1)))
		session.add_coins(int(_value(192, "ゴールド")))
		_queue_random_relic(session)


# ---------------------------------------------------------------------------
# 進捗を数えるクエスト
# ---------------------------------------------------------------------------

## 進捗を amount 足して、goal に届いたらこのレリックを消して reward を呼ぶ（持っている1枚ごと）。
static func _progress_quest(session: GameSession, relic_id: int, amount: int, goal: int, reward: Callable) -> void:
	if amount <= 0:
		return
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != relic_id:
			continue
		item["progress"] = int(item.get("progress", 0)) + amount
		if int(item.get("progress", 0)) < maxi(goal, 1):
			continue
		session.take_relic(int(item.get("uid", -1)))
		reward.call()


## pick に合うレリックを count 個入れる報酬。
static func _grants(session: GameSession, pick: Callable, count: int) -> Callable:
	return func() -> void:
		for _i in count:
			_grant_random_where(session, pick)


## 294: 無料更新を使った回数。
static func note_free_reroll_used(session: GameSession) -> void:
	_progress_quest(session, 294, 1, int(_value(294, "進捗")), func() -> void:
		session.add_relic(62)
	)


## 295: 経験値を買った回数。
static func note_exp_purchase(session: GameSession) -> void:
	var pick := func(relic_id: int) -> bool:
		return _category(relic_id) == "経験値・レベル・出現率"
	_progress_quest(session, 295, 1, int(_value(295, "進捗")), _grants(session, pick, 1))


## 292: 同じキャラクターを合成した回数。
static func note_same_merge_quest(session: GameSession) -> void:
	_progress_quest(session, 292, 1, int(_value(292, "進捗")), func() -> void:
		session.add_relic(103 if randi() % 2 == 0 else 104)
	)


## 286: 味方が倒れた回数。上限の回数まで、届くたびにレリックが入る。
static func note_ally_down(session: GameSession) -> void:
	var cap := int(_value(286, "上限"))
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 286:
			continue
		if int(item.get("grants", 0)) >= cap:
			continue
		item["progress"] = int(item.get("progress", 0)) + 1
		if int(item.get("progress", 0)) < int(_value(286, "進捗")):
			continue
		item["progress"] = 0
		item["grants"] = int(item.get("grants", 0)) + 1
		_queue_random_relic(session)
		if int(item.get("grants", 0)) >= cap:
			session.take_relic(int(item.get("uid", -1)))


# ---------------------------------------------------------------------------
# 条件を満たしたら入るクエスト（296 連勝・297 連敗・298 レベル・299 星3）
# ---------------------------------------------------------------------------

## 入手したあと（armed）のもの。
static func _armed(session: GameSession, relic_id: int) -> Array:
	var out: Array = []
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) == relic_id and bool(item.get("armed", false)):
			out.append(item)
	return out


static func note_streak_quests(session: GameSession) -> void:
	if session.win_streak >= int(_value(296, "連勝")):
		for item in _armed(session, 296):
			session.add_coins(int(_value(296, "ゴールド")))
			session.free_rerolls += int(_value(296, "無料更新"))
			session.take_relic(int(item.get("uid", -1)))
	if session.loss_streak >= int(_value(297, "連敗")):
		for item in _armed(session, 297):
			session.add_coins(int(_value(297, "ゴールド")))
			_grant_random_where(session, _is_guard_relic)
			session.take_relic(int(item.get("uid", -1)))


static func _check_level_quest(session: GameSession) -> void:
	if session.get_level() < int(_value(298, "レベル")):
		return
	for item in _armed(session, 298):
		session.take_relic(int(item.get("uid", -1)))
		_grant_random_where(session, func(relic_id: int) -> bool:
			return _category(relic_id) == "合成装備レベルの強さ"
		)


## 299: 星3にしたとき、残り回数のある1枚ぶんゴールド。
static func _grant_star3_quest(session: GameSession) -> void:
	if _tick_down(session, 299, Callable(), 1) > 0:
		session.add_coins(int(_value(299, "ゴールド")))


# ---------------------------------------------------------------------------
# レリックが入る・増えるもの
# ---------------------------------------------------------------------------

## 178 落語: 同じキャラクターを合成したとき、元の1枚（seed）の回数ぶん複製が入る。
static func _trigger_merge_copy(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 178 or not bool(item.get("seed", false)):
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		item["left"] = left - 1
		## 回数を使い切っても、手元の落語そのものは残る。
		session.add_relic(178, {"from_copy": true, "seed": false})
		return


## 285: 残りラウンドのあいだ、ラウンドごとにレリックが1つ入る。
static func _advance_grant_rounds(session: GameSession) -> void:
	_tick_down(session, 285, func(_item_285: Dictionary) -> void:
		_queue_random_relic(session)
	)


static func note_duplicate_name(session: GameSession, relic_id: int) -> void:
	if _count(session, 307) <= 0:
		return
	var name := str(RelicCatalog.get_relic(relic_id).get("name", ""))
	var owned := 0
	for item in session.relics:
		if str(RelicCatalog.get_relic(int(item.get("id", -1))).get("name", "")) == name:
			owned += 1
	if owned >= 2:
		session.add_coins(_owned_value(session, 307, "ゴールド"))


static func trigger_shinan(session: GameSession) -> void:
	if _count(session, 301) <= 0:
		return
	## 指南で入った1つでは、指南はもう発動しない。
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if not pool.is_empty():
		session.add_relic(pool[randi() % pool.size()], {"from_shinan": true})


## 309 幻想: レリックを合成したとき、さらに1つ入る（指南は発動しない）。
static func note_relic_synthesized(session: GameSession) -> void:
	for _i in _count(session, 309):
		var pool: Array[int] = RelicCatalog.all_pick_ids()
		if pool.is_empty():
			return
		session.add_relic(pool[randi() % pool.size()], {"from_shinan": true})


## 302 クロージャ: 階段1・2・3をすべて持ったら入る。一度入ったら残る。
static func check_closure(session: GameSession) -> void:
	if _count(session, 302) > 0:
		return
	if _count(session, 312) > 0 and _count(session, 313) > 0 and _count(session, 314) > 0:
		## 入手条件で入ったクロージャでも、指南(301)の追加は入る。
		session.add_relic(302)


# ---------------------------------------------------------------------------
# 報酬の候補。効果値の名前で選ぶ。
# ---------------------------------------------------------------------------

static func _has_effect_key(relic_id: int, needles: Array) -> bool:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	for key in effects.keys():
		for needle in needles:
			if str(key).find(str(needle)) >= 0:
				return true
	return false


static func _is_strike_relic(relic_id: int) -> bool:
	return _category(relic_id) == "合成装備レベルの強さ" and _has_effect_key(relic_id, ["与ダメージ", "貫通", "クリティカル"])


static func _is_guard_relic(relic_id: int) -> bool:
	return _category(relic_id) == "(プレイヤーもキャラクターも)HP、防御の増強、回復"


## クエスト自身（291 金魚の「ゲージ」など、進捗の数）は候補に入れない。
static func _is_quest_relic(relic_id: int) -> bool:
	return _category(relic_id) == "クエスト・達成報酬"


static func _is_crit_relic(relic_id: int) -> bool:
	return not _is_quest_relic(relic_id) and _has_effect_key(relic_id, ["クリティカル率", "クリティカルダメージ"])


static func _is_speed_relic(relic_id: int) -> bool:
	return not _is_quest_relic(relic_id) and _has_effect_key(relic_id, ["速度"])


static func _is_gauge_relic(relic_id: int) -> bool:
	return not _is_quest_relic(relic_id) and _has_effect_key(relic_id, ["ゲージ"])
