class_name RoundIncome
extends RefCounted

const BASE_INCOME := 5
const COINS_PER_HOLDING_STEP := 8


static func calc_holding_bonus(coins_held: int, player_level: int, step: int = COINS_PER_HOLDING_STEP, extra_gold: int = 0) -> int:
	var counted := mini(maxi(coins_held, 0) + maxi(extra_gold, 0), maxi(player_level, 1) * 10)
	return counted / maxi(step, 1)


static func calc_streak_bonus(streak_count: int) -> int:
	return maxi(0, streak_count)


static func calc_round_start_income(
	coins_held: int,
	player_level: int,
	streak_count: int,
	round_number: int,
	interest_step: int = COINS_PER_HOLDING_STEP,
	extra_gold: int = 0
) -> Dictionary:
	var base := BASE_INCOME
	var holding := calc_holding_bonus(coins_held, player_level, interest_step, extra_gold)
	var streak := calc_streak_bonus(streak_count)
	var round_bonus := maxi(0, round_number)
	return {
		"total": base + holding + streak + round_bonus,
		"base": base,
		"holding": holding,
		"streak": streak,
		"round": round_bonus,
	}
