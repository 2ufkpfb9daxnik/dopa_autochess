class_name PlayerHp
extends RefCounted

const INITIAL_HP := 100


static func calc_loss_damage(round_number: int, remaining_enemy_units: int) -> int:
	return maxi(0, round_number) + maxi(0, remaining_enemy_units)
