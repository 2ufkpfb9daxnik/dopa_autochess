class_name RoundIncome
extends RefCounted

const BASE_INCOME := 5
const COINS_PER_HOLDING_STEP := 10


static func calc_holding_bonus(coins_held: int, player_level: int) -> int:
	var raw := coins_held / COINS_PER_HOLDING_STEP
	var cap := PlayerLevel.get_max_holding_bonus(player_level)
	return mini(raw, cap)


static func calc_streak_bonus(streak_count: int) -> int:
	return maxi(0, streak_count)


static func calc_round_start_income(
	coins_held: int,
	player_level: int,
	streak_count: int,
	round_number: int
) -> Dictionary:
	var base := BASE_INCOME
	var holding := calc_holding_bonus(coins_held, player_level)
	var streak := calc_streak_bonus(streak_count)
	var round_bonus := maxi(0, round_number)
	return {
		"total": base + holding + streak + round_bonus,
		"base": base,
		"holding": holding,
		"streak": streak,
		"round": round_bonus,
	}
