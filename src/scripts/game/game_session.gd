class_name GameSession
extends Node

signal state_changed
signal extension_choice_required
signal route_choice_required
signal run_completed
signal run_failed

enum Phase { PREP, BATTLE, ROUTE_CHOICE, EXTENSION_CHOICE }

enum RunEndReason { NONE, DEFEAT, CLEAR, VOLUNTARY_END }

const REROLL_COST := 2
const EXP_COST := 4
const EXP_GAIN := 4
const INITIAL_COINS := 20
const BATTLE_DURATION := 3.0
const SHOP_SIZE := 6
const NORMAL_MAX_ROUND := 20
const EXTENSION_ROUNDS := 5
const ROUND_END_FREE_XP := 2

var coins: int = INITIAL_COINS
var experience: int = 0
var player_hp: int = PlayerHp.INITIAL_HP
var round_number: int = 1
var phase: Phase = Phase.PREP
var shop_unit_ids: Array[int] = []

var coins_at_last_round_end: int = INITIAL_COINS
var win_streak: int = 0
var loss_streak: int = 0
var extended_mode: bool = false
var max_round: int = NORMAL_MAX_ROUND
var last_income_breakdown: Dictionary = {}
var cleanse_income: int = 0
var last_cleanse_income: int = 0
var route_options: Array[Dictionary] = []
var selected_route: Dictionary = {}
var free_rerolls: int = 0
var shop_locked: bool = false
var run_end_reason: RunEndReason = RunEndReason.NONE
## {uid: int, id: int}。uid は所持1個ごとの識別で、同じレリックを複数持てる。
var relics: Array[Dictionary] = []
var _relic_seq := 1
var relic_shop_discount := 0
var relic_043_armed: Array[int] = []
var relic_043_live: Array[int] = []
var relic_paid_free_used := false
var relic_buy_counts: Dictionary = {}
var relic_cost_rewarded: Dictionary = {}
var relic_076_slots: Array[int] = []
var relic_pending_units: Array[Dictionary] = []
var shop_odds_level: int = 1
var relic_end_xp: int = 0


func should_offer_relic_pick() -> bool:
	## 初回ラウンドを除き、ルート選択後の準備開始時にレリック3択を出す。
	return round_number > 1 and is_prep() and not is_run_over()


func add_relic(relic_id: int) -> int:
	if relic_id <= 0:
		return -1
	var uid := _relic_seq
	_relic_seq += 1
	var item := {"uid": uid, "id": relic_id}
	relics.append(item)
	RelicEconomy.on_gained(self, uid, relic_id)
	RelicEconomy.note_duplicate_name(self, relic_id)
	state_changed.emit()
	return uid


func relic_id_of(uid: int) -> int:
	for item in relics:
		if int(item.get("uid", -1)) == uid:
			return int(item.get("id", -1))
	return -1


func take_relic(uid: int) -> int:
	for index in relics.size():
		if int(relics[index].get("uid", -1)) != uid:
			continue
		var relic_id := int(relics[index].get("id", -1))
		relics.remove_at(index)
		RelicEconomy.strip_equipped_uid(self, uid)
		state_changed.emit()
		return relic_id
	return -1


func _ready() -> void:
	refresh_shop()


func is_prep() -> bool:
	return phase == Phase.PREP


func _economy_open() -> bool:
	return phase == Phase.PREP or phase == Phase.BATTLE


func is_route_choice() -> bool:
	return phase == Phase.ROUTE_CHOICE


func get_level() -> int:
	return PlayerLevel.get_level(experience)


func get_board_unit_cap() -> int:
	return PlayerLevel.get_board_unit_cap(get_level()) + RelicEconomy.deploy_bonus(self)


func debug_jump_round(target: int) -> void:
	if not is_prep() or is_run_over():
		return
	round_number = clampi(target, 1, 99)
	if round_number > NORMAL_MAX_ROUND:
		extended_mode = true
		max_round = maxi(max_round, round_number)
	state_changed.emit()


func refresh_shop(paid_gold: bool = false) -> void:
	shop_unit_ids.clear()
	var level := RelicEconomy.shop_odds_level(self, paid_gold)
	shop_odds_level = level
	for _i in SHOP_SIZE:
		shop_unit_ids.append(UnitCatalog.random_unit_id_for_level(level))
	RelicEconomy.on_shop_refreshed(self)
	state_changed.emit()


func apply_round_start_shop() -> void:
	var force_refresh := false
	for item in relics:
		if int(item.get("id", -1)) == 58:
			force_refresh = true
			break
	if shop_locked and not force_refresh:
		shop_locked = false
		state_changed.emit()
		return
	shop_locked = false
	refresh_shop()


func toggle_shop_lock() -> void:
	if not is_prep():
		return
	shop_locked = not shop_locked
	state_changed.emit()


func try_buy_shop_slot(slot_index: int, bench_full: bool) -> int:
	if not _economy_open() or slot_index >= shop_unit_ids.size():
		return -1
	var unit_id: int = shop_unit_ids[slot_index]
	if unit_id < 0:
		return -1
	var cost := RelicEconomy.shop_price(self, slot_index)
	if coins < cost or bench_full:
		return -1
	coins -= cost
	RelicEconomy.note_gold_spent(self, cost)
	shop_unit_ids[slot_index] = -1
	RelicEconomy.note_unit_bought(self, int(UnitCatalog.get_unit(unit_id)["cost"]), 1)
	state_changed.emit()
	return unit_id


func try_reroll() -> bool:
	if not _economy_open() or shop_locked:
		return false
	if free_rerolls > 0:
		free_rerolls -= 1
		refresh_shop(false)
		return true
	var reroll_cost := RelicEconomy.paid_reroll_cost(self)
	if coins < reroll_cost:
		return false
	coins -= reroll_cost
	RelicEconomy.note_gold_spent(self, reroll_cost)
	refresh_shop(reroll_cost > 0)
	RelicEconomy.note_paid_reroll(self, reroll_cost)
	GameAudio.play_money_gain()
	return true


func try_buy_exp() -> bool:
	var exp_cost := RelicEconomy.exp_cost(self)
	if not _economy_open() or coins < exp_cost:
		return false
	coins -= exp_cost
	RelicEconomy.note_gold_spent(self, exp_cost)
	gain_experience(EXP_GAIN + RelicEconomy.exp_bonus(self))
	RelicEconomy.note_exp_bought(self)
	state_changed.emit()
	GameAudio.play_money_gain()
	return true


func try_buy_exp_with_hp() -> bool:
	var hp_cost := RelicEconomy.hp_exp_cost(self)
	if hp_cost <= 0 or not _economy_open() or player_hp < hp_cost:
		return false
	player_hp -= hp_cost
	gain_experience(EXP_GAIN)
	if player_hp <= 0:
		finish_run(RunEndReason.DEFEAT)
		return true
	state_changed.emit()
	return true


func add_sell_income(amount: int) -> void:
	add_coins(amount)
	state_changed.emit()
	if amount > 0:
		GameAudio.play_money_gain()


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	if amount < 0:
		coins += amount
		return
	var bonus_per := RelicEconomy.crossing_bonus(self)
	var adding := amount
	while adding > 0:
		var before := coins
		coins += adding
		adding = 0
		if bonus_per <= 0:
			break
		var crossed := int(floor(float(coins) / 10.0)) - int(floor(float(before) / 10.0))
		if crossed <= 0:
			break
		adding = crossed * bonus_per


func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	var before := get_level()
	experience += amount
	RelicEconomy.apply_hologram(self, before)
	var after := get_level()
	if after > before:
		RelicEconomy.note_level_up(self, before, after)
	state_changed.emit()


func note_cleanse_income(amount: int = 1) -> void:
	if amount <= 0:
		return
	cleanse_income += amount
	state_changed.emit()


func add_free_experience(amount: int) -> void:
	gain_experience(amount)


func start_battle() -> void:
	if not is_prep():
		return
	phase = Phase.BATTLE
	state_changed.emit()


func finish_battle(won: bool = true, remaining_enemy_units: int = 0) -> void:
	last_cleanse_income = cleanse_income
	if cleanse_income > 0:
		add_coins(cleanse_income)
		cleanse_income = 0
		GameAudio.play_money_gain()
	coins_at_last_round_end = coins
	gain_experience(ROUND_END_FREE_XP + relic_end_xp)
	relic_end_xp = 0

	if won:
		if loss_streak > 0:
			RelicEconomy.note_streak_broken(self)
		win_streak += 1
		loss_streak = 0
	else:
		if win_streak > 0:
			RelicEconomy.note_streak_broken(self)
		loss_streak += 1
		win_streak = 0
		var damage := PlayerHp.calc_loss_damage(round_number, remaining_enemy_units)
		player_hp = maxi(0, player_hp - damage)

	round_number += 1

	if not won and player_hp <= 0:
		finish_run(RunEndReason.DEFEAT)
		return

	if not extended_mode and round_number == NORMAL_MAX_ROUND + 1:
		phase = Phase.EXTENSION_CHOICE
		extension_choice_required.emit()
		state_changed.emit()
		return

	if round_number > max_round:
		finish_run(RunEndReason.CLEAR)
		return

	_generate_route_options()
	phase = Phase.ROUTE_CHOICE
	route_choice_required.emit()
	state_changed.emit()


func select_route(index: int) -> Dictionary:
	if not is_route_choice() or index < 0 or index >= route_options.size():
		return {}
	var coins_before := coins
	selected_route = route_options[index]
	_apply_route_reward(selected_route)
	RelicEconomy.prepare_round(self)
	_apply_round_start_income()
	if coins > coins_before:
		GameAudio.play_money_gain()
	phase = Phase.PREP
	apply_round_start_shop()
	state_changed.emit()
	return selected_route


func _generate_route_options() -> void:
	route_options = RouteChoice.generate_options(round_number)


func _apply_route_reward(route: Dictionary) -> void:
	if route.is_empty():
		return
	match route["reward_type"]:
		"gold":
			add_coins(RouteChoice.get_gold_reward(route["strength"]))
		"reroll":
			free_rerolls += 1
		"augment", "equipment":
			pass


func choose_extension(continue_run: bool) -> void:
	if not continue_run:
		finish_run(RunEndReason.VOLUNTARY_END)
		return
	extended_mode = true
	max_round = NORMAL_MAX_ROUND + EXTENSION_ROUNDS
	_generate_route_options()
	phase = Phase.ROUTE_CHOICE
	route_choice_required.emit()
	state_changed.emit()


func _apply_round_start_income() -> void:
	var blocks_interest := RelicEconomy.blocks_interest(self)
	last_income_breakdown = RoundIncome.calc_round_start_income(
		coins_at_last_round_end,
		get_level(),
		get_active_streak(),
		round_number,
		RelicEconomy.interest_step(self),
		0 if blocks_interest else RelicEconomy.interest_principal_extra(self)
	)
	if blocks_interest:
		last_income_breakdown["holding"] = 0
	else:
		last_income_breakdown["holding"] = int(last_income_breakdown["holding"]) + RelicEconomy.interest_extra(self) + RelicEconomy.interest_flat(self)
	last_income_breakdown["streak"] = int(last_income_breakdown["streak"]) + RelicEconomy.streak_extra(self)
	last_income_breakdown["total"] = int(last_income_breakdown["base"]) + int(last_income_breakdown["holding"]) + int(last_income_breakdown["streak"]) + int(last_income_breakdown["round"]) + RelicEconomy.apply_round_open(self)
	add_coins(int(last_income_breakdown["total"]))
	state_changed.emit()


func get_active_streak() -> int:
	return maxi(win_streak, loss_streak)


func get_battle_duration() -> float:
	return BATTLE_DURATION


func is_run_over() -> bool:
	return run_end_reason != RunEndReason.NONE


func finish_run(reason: RunEndReason) -> void:
	if run_end_reason != RunEndReason.NONE:
		return
	run_end_reason = reason
	phase = Phase.PREP
	match reason:
		RunEndReason.DEFEAT:
			run_failed.emit()
		_:
			run_completed.emit()
	state_changed.emit()
