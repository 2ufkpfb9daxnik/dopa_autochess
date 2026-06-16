class_name RoundIncome
extends RefCounted

const BASE_INCOME := 5
const COINS_PER_HOLDING_STEP := 10


static func calc_holding_bonus(coins_held: int, player_level: int) -> int:
	var raw := coins_held / COINS_PER_HOLDING_STEP
	var cap := PlayerLevel.get_max_holding_bonus(player_level)
	return mini(raw, cap)


static func calc_streak_bonus(streak_count: int) -> int:
	if streak_count < 2:
		return 0
	if streak_count <= 5:
		return 1
	return 3


static func calc_round_start_income(
	coins_held: int,
	player_level: int,
	streak_count: int
) -> Dictionary:
	var base := BASE_INCOME
	var holding := calc_holding_bonus(coins_held, player_level)
	var streak := calc_streak_bonus(streak_count)
	return {
		"total": base + holding + streak,
		"base": base,
		"holding": holding,
		"streak": streak,
	}
