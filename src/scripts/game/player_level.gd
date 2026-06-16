class_name PlayerLevel
extends RefCounted

const MAX_LEVEL := 20

## レベル N から N+1 に上がるのに必要な経験値（index 0 = Lv1→2）
const XP_TO_LEVEL_UP: Array[int] = [
	2, 2, 6, 10, 20, 36, 60, 68, 68,
	80, 95, 110, 130, 155, 185, 220, 260, 310, 365,
]


static func get_level(experience: int) -> int:
	var level := 1
	var remaining := experience
	while level < MAX_LEVEL:
		var need := XP_TO_LEVEL_UP[level - 1]
		if remaining < need:
			break
		remaining -= need
		level += 1
	return level


static func get_board_unit_cap(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL)


static func get_xp_into_current_level(experience: int) -> int:
	var level := get_level(experience)
	var spent := 0
	for i in range(level - 1):
		spent += XP_TO_LEVEL_UP[i]
	return experience - spent


static func get_xp_needed_for_next_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return XP_TO_LEVEL_UP[level - 1]


static func get_max_holding_bonus(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL)
