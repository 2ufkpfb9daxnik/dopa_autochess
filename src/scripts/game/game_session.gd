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
const SHOP_SIZE := 5
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
var route_options: Array[Dictionary] = []
var selected_route: Dictionary = {}
var free_rerolls: int = 0
var run_end_reason: RunEndReason = RunEndReason.NONE


func _ready() -> void:
	refresh_shop()


func is_prep() -> bool:
	return phase == Phase.PREP


func is_route_choice() -> bool:
	return phase == Phase.ROUTE_CHOICE


func get_level() -> int:
	return PlayerLevel.get_level(experience)


func get_board_unit_cap() -> int:
	return PlayerLevel.get_board_unit_cap(get_level())


func refresh_shop() -> void:
	shop_unit_ids.clear()
	var level := get_level()
	for _i in SHOP_SIZE:
		shop_unit_ids.append(UnitCatalog.random_unit_id_for_level(level))
	state_changed.emit()


func try_buy_shop_slot(slot_index: int, bench_full: bool) -> int:
	if not is_prep() or slot_index >= shop_unit_ids.size():
		return -1
	var unit_id: int = shop_unit_ids[slot_index]
	if unit_id < 0:
		return -1
	var cost: int = UnitCatalog.get_unit(unit_id)["cost"]
	if coins < cost or bench_full:
		return -1
	coins -= cost
	shop_unit_ids[slot_index] = -1
	state_changed.emit()
	return unit_id


func try_reroll() -> bool:
	if not is_prep():
		return false
	if free_rerolls > 0:
		free_rerolls -= 1
		refresh_shop()
		return true
	if coins < REROLL_COST:
		return false
	coins -= REROLL_COST
	refresh_shop()
	return true


func try_buy_exp() -> bool:
	if not is_prep() or coins < EXP_COST:
		return false
	coins -= EXP_COST
	experience += EXP_GAIN
	state_changed.emit()
	return true


func add_sell_income(amount: int) -> void:
	coins += amount
	state_changed.emit()


func add_free_experience(amount: int) -> void:
	experience += amount
	state_changed.emit()


func start_battle() -> void:
	if not is_prep():
		return
	phase = Phase.BATTLE
	state_changed.emit()


func finish_battle(won: bool = true, remaining_enemy_units: int = 0) -> void:
	coins_at_last_round_end = coins
	experience += ROUND_END_FREE_XP

	if won:
		win_streak += 1
		loss_streak = 0
	else:
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
	selected_route = route_options[index]
	_apply_route_reward(selected_route)
	_apply_round_start_income()
	phase = Phase.PREP
	refresh_shop()
	state_changed.emit()
	return selected_route


func _generate_route_options() -> void:
	route_options = RouteChoice.generate_options(round_number)


func _apply_route_reward(route: Dictionary) -> void:
	if route.is_empty():
		return
	match route["reward_type"]:
		"gold":
			coins += RouteChoice.get_gold_reward(route["strength"])
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
	last_income_breakdown = RoundIncome.calc_round_start_income(
		coins_at_last_round_end,
		get_level(),
		get_active_streak(),
		round_number
	)
	coins += last_income_breakdown["total"]
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
