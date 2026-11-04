extends "res://scripts/game/relic_economy_quest.gd"

## ゴールド・利息・経験値・レベル・連勝連敗・プレイヤーHP。
## 継承のつながりは relic_economy_base.gd の先頭を参照。


# ---------------------------------------------------------------------------
# 利息
# ---------------------------------------------------------------------------

static func interest_step(session: GameSession) -> int:
	if _count(session, 50) > 0:
		return int(_value(50, "必要ゴールド"))
	return 8


## 046: 残りラウンドのあいだ利息が増える。呼ぶと1減る。
static func interest_extra(session: GameSession) -> int:
	return _tick_down(session, 46) * int(_value(46, "利息"))


## interest_extra の見込み（減らさない）。
static func interest_extra_preview(session: GameSession) -> int:
	return _charges(session, 46) * int(_value(46, "利息"))


static func interest_principal_extra(session: GameSession) -> int:
	return _owned_value(session, 65, "元手")


static func interest_flat(session: GameSession) -> int:
	return _owned_value(session, 64, "利息") + _owned_value(session, 137, "利息")


## 255 フィックス: 利息そのものを消す（変換もしない）。
static func hard_blocks_interest(session: GameSession) -> bool:
	return _count(session, 255) > 0


## 利息ゴールドが入らない（093 変換・255 封鎖）。
static func blocks_interest(session: GameSession) -> bool:
	return _count(session, 93) > 0 or hard_blocks_interest(session)


## 093 馬蹄: 利息を同量の経験値に変える。255があると利息自体が無いので無効。
static func converts_interest_to_xp(session: GameSession) -> bool:
	return _count(session, 93) > 0 and not hard_blocks_interest(session)


## 基本利息にフラット・046・ダイトー倍率を載せる。consume で046と倍率を消費する。
static func decorate_interest(session: GameSession, base_holding: int, consume: bool) -> int:
	var holding := maxi(0, base_holding) + interest_flat(session)
	if consume:
		holding += interest_extra(session)
	else:
		holding += interest_extra_preview(session)
	if session.next_interest_bonus > 0.0:
		holding = int(round(float(holding) * (1.0 + session.next_interest_bonus)))
		if consume:
			session.next_interest_bonus = 0.0
	return holding


# ---------------------------------------------------------------------------
# ラウンド開始のゴールド・経験値
# ---------------------------------------------------------------------------

static func round_start_gold(session: GameSession) -> int:
	var gold := 0
	for relic_id in [42, 255, 302, 313]:
		gold += _owned_value(session, relic_id, "ゴールド")
	gold += _owned_value(session, 308, "ゴールド") * session.relics.size()
	return gold


static func round_start_experience(session: GameSession) -> int:
	var xp := _tick_down(session, 85) * int(_value(85, "経験値"))
	xp += _owned_value(session, 254, "毎ラウンド")
	xp += _owned_value(session, 302, "経験値")
	xp += _advance_pilot(session)
	return xp


## 098: 間隔のラウンドごとに経験値と無料更新。
static func _advance_pilot(session: GameSession) -> int:
	var xp := 0
	var interval := maxi(int(_value(98, "間隔")), 1)
	for item in session.relics:
		if int(item.get("id", -1)) != 98:
			continue
		var age := int(item.get("age", 1)) + 1
		item["age"] = age
		if age % interval != 0:
			continue
		xp += int(_value(98, "経験値"))
		session.free_rerolls += int(_value(98, "無料更新"))
	return xp


## 263: 入手したときのゴールドを預け、残りラウンドが0で追加つきで戻る。
static func _resolve_timed_bank(session: GameSession) -> int:
	var gold := 0
	var finished := _count_down(session, 263)
	for item in finished:
		gold += int(item.get("bank", 0)) + int(_value(263, "追加"))
	for item in finished:
		session.take_relic(int(item.get("uid", -1)))
	return gold


## 063: 持っているゴールドの段で無料更新。
static func _coyote_rerolls(session: GameSession) -> int:
	var copies := _count(session, 63)
	if copies <= 0:
		return 0
	var held := session.coins
	var each := 0
	if held >= int(_value(63, "多い段")):
		each = 2
	elif held >= int(_value(63, "少ない段")):
		each = 1
	return copies * each


## 102: 控えのいちばん下を書き換えて、ゴールド。
static func _rewrite_bottom_bench(session: GameSession) -> void:
	var copies := _count(session, 102)
	if copies <= 0:
		return
	var host := session.get_parent()
	if host != null and host.has_method("relic_rewrite_bottom_bench"):
		host.relic_rewrite_bottom_bench(copies)
	session.add_coins(copies * int(_value(102, "ゴールド")))


## 077 再呼び出し: 収入のあとに、上限まで足りないぶんを入れる。1回で1枚の回数を使う。
static func refill_after_income(session: GameSession) -> void:
	var cap := maxi(session.get_level(), 1) * 10
	var gap := cap - session.coins
	if gap <= 0:
		return
	if _tick_down(session, 77, Callable(), 1) > 0:
		session.add_coins(gap)


# ---------------------------------------------------------------------------
# 経験値とレベル
# ---------------------------------------------------------------------------

## 254 二重: ゴールドで経験値を買えない。
static func blocks_gold_exp(session: GameSession) -> bool:
	return _count(session, 254) > 0


static func hp_exp_gain(session: GameSession) -> int:
	return GameSession.EXP_GAIN + (int(_value(254, "経験値")) if _count(session, 254) > 0 else 0)


static func hp_exp_cost(session: GameSession) -> int:
	if _count(session, 254) > 0:
		return int(_value(254, "HP"))
	if _count(session, 95) <= 0:
		return 0
	return int(_value(95, "HP"))


static func exp_cost(session: GameSession) -> int:
	if _count(session, 254) > 0:
		return 999
	var cost := GameSession.EXP_COST
	cost -= _charges(session, 52) * int(_value(52, "値引き"))
	cost -= _owned_value(session, 314, "値引き")
	return maxi(0, cost)


static func note_exp_bought(session: GameSession) -> void:
	session.free_rerolls += _owned_value(session, 45, "無料更新")
	_tick_down(session, 52, Callable(), 1)
	for _i in _count(session, 92):
		session.refresh_shop(false)


static func exp_bonus(session: GameSession) -> int:
	return _owned_value(session, 74, "経験値")


## 090 パレード: プレイヤーレベルの上限が上がる。
static func level_cap(session: GameSession) -> int:
	if _count(session, 90) > 0:
		return PlayerLevel.MAX_LEVEL + int(_value(90, "上限"))
	return PlayerLevel.MAX_LEVEL


static func note_level_up(session: GameSession, before: int, after: int) -> void:
	if after <= before:
		return
	var steps := after - before
	session.free_rerolls += _count(session, 73) * after * int(_value(73, "倍率"))
	var copies88 := _count(session, 88)
	if copies88 > 0:
		## 1レベル上がるたびに1回。
		for level in range(before + 1, after + 1):
			var cost := clampi(level - 4, 1, int(_value(88, "上限コスト")))
			var pool := UnitCatalog.get_unit_ids_by_cost(cost)
			for _i in copies88:
				if not pool.is_empty():
					_queue_unit(session, pool[randi() % pool.size()], 2)
			session.add_coins(copies88 * int(_value(88, "ゴールド")))
	_check_level_quest(session)
	if before < 8 and after >= 8:
		var copies89 := _count(session, 89)
		if copies89 > 0:
			session.free_rerolls += copies89 * int(_value(89, "無料更新"))
			_consume_all(session, 89)
	## 094: 覚えたキャラクターが、上がった段数ぶん入る。
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 94:
			continue
		var memory := int(item.get("memory", -1))
		if UnitCatalog.get_unit(memory).is_empty():
			continue
		for _step in steps:
			_queue_unit(session, memory, 1)
	var copies99 := _count(session, 99)
	if copies99 > 0:
		_heal_player(session, steps * copies99 * int(_value(99, "HP")))
		session.free_rerolls += steps * copies99 * int(_value(99, "無料更新"))
	note_level_growth(session, steps)


## 097 ホログラム: レベル9になったら、レベル10の経験値まで上がって消える。
static func apply_hologram(session: GameSession, before: int) -> void:
	if _count(session, 97) <= 0 or before >= 9 or session.get_level() < 9:
		return
	var gate := PlayerLevel.xp_to_reach(10)
	if session.experience < gate:
		session.experience = gate
	_consume_all(session, 97)


## 097 を入手したとき。すでにレベル9以上ならすぐ入る。
static func _grant_hologram_now(session: GameSession, uid: int) -> void:
	var before := session.get_level()
	if before >= 10:
		session.take_relic(uid)
		return
	if before < 9:
		return
	var gate := PlayerLevel.xp_to_reach(10)
	if session.experience < gate:
		session.experience = gate
	session.take_relic(uid)
	var after := session.get_level()
	if after > before:
		note_level_up(session, before, after)


## 094 を入手したとき、コストの決まったキャラクターを1つ覚えて入れる。
static func _remember_unit(session: GameSession, item: Dictionary) -> void:
	var pool := UnitCatalog.get_unit_ids_by_cost(int(_value(94, "コスト")))
	if pool.is_empty():
		return
	var unit_id := pool[randi() % pool.size()]
	item["memory"] = unit_id
	_queue_unit(session, unit_id, 1)


# ---------------------------------------------------------------------------
# ゴールドのその他
# ---------------------------------------------------------------------------

## 078: ゴールドが10の位をまたぐたびに足すぶん（GameSession.add_coins が使う）。
static func crossing_bonus(session: GameSession) -> int:
	return _owned_value(session, 78, "ゴールド")


static func deploy_bonus(session: GameSession) -> int:
	return _owned_value(session, 91, "出撃") + _owned_value(session, 253, "出撃") + _owned_value(session, 314, "出撃")


## 183 横車: 攻撃を受ける装置が壊れたとき。1戦闘の回数は戦闘側で数える。
static func device_break_gold(session: GameSession) -> int:
	return _owned_value(session, 183, "ゴールド")


# ---------------------------------------------------------------------------
# 連勝・連敗と敗北のダメージ
# ---------------------------------------------------------------------------

static func streak_extra(session: GameSession) -> int:
	if maxi(session.win_streak, session.loss_streak) <= 0:
		return 0
	return _owned_value(session, 127, "ゴールド")


static func round_streak_gold(session: GameSession) -> int:
	if maxi(session.win_streak, session.loss_streak) < int(_value(140, "連")):
		return 0
	return _owned_value(session, 140, "ゴールド")


## 133: 連勝・連敗が途切れたとき、残り回数のある1枚ごとにゴールド。
static func note_streak_broken(session: GameSession) -> void:
	session.add_coins(_tick_down(session, 133) * int(_value(133, "ゴールド")))


## 123 羅針: 連勝・連敗の増え方が倍になる。
static func streak_step(session: GameSession) -> int:
	var step := 1
	for _i in _count(session, 123):
		step *= int(_value(123, "倍率"))
	return maxi(step, 1)


## 敗北のプレイヤーダメージ。091 パラダイス！は+1、253 断層は倍。128 レオニードは-1で最低1。
static func loss_damage(session: GameSession, damage: int) -> int:
	if damage <= 0:
		return damage
	damage += _owned_value(session, 91, "ダメージ")
	for _i in _count(session, 253):
		damage *= int(_value(253, "倍率"))
	var cut := _owned_value(session, 128, "ダメージ")
	if cut > 0:
		damage = maxi(1, damage - cut)
	return damage
