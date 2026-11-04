class_name PlayerLevel
extends RefCounted

const MAX_LEVEL := 20
## パレード(090)などで上限が上がったときの上限。
const EXTENDED_MAX_LEVEL := 21

## レベル N から N+1 に上がるのに必要な経験値（index 0 = Lv1→2）
## 最後の 430（Lv20→21）は設計書に値が無いため、伸び幅から置いた暫定値。パレード(090)専用。
const XP_TO_LEVEL_UP: Array[int] = [
	2, 2, 6, 10, 20, 36, 60, 68, 68,
	80, 95, 110, 130, 155, 185, 220, 260, 310, 365,
	430,
]


static func _cap(max_level: int) -> int:
	return clampi(max_level, 1, EXTENDED_MAX_LEVEL)


static func get_level(experience: int, max_level: int = MAX_LEVEL) -> int:
	var cap := _cap(max_level)
	var level := 1
	var remaining := experience
	while level < cap:
		var need := XP_TO_LEVEL_UP[level - 1]
		if remaining < need:
			break
		remaining -= need
		level += 1
	return level


static func get_board_unit_cap(level: int) -> int:
	return clampi(level, 1, EXTENDED_MAX_LEVEL)


static func get_xp_into_current_level(experience: int, max_level: int = MAX_LEVEL) -> int:
	var level := get_level(experience, max_level)
	var spent := 0
	for i in range(level - 1):
		spent += XP_TO_LEVEL_UP[i]
	return experience - spent


static func get_xp_needed_for_next_level(level: int, max_level: int = MAX_LEVEL) -> int:
	if level >= _cap(max_level):
		return 0
	return XP_TO_LEVEL_UP[level - 1]


static func xp_to_reach(level: int) -> int:
	var total := 0
	var steps := mini(level - 1, XP_TO_LEVEL_UP.size())
	for index in steps:
		total += XP_TO_LEVEL_UP[index]
	return total


static func get_max_holding_bonus(level: int) -> int:
	return clampi(level, 1, EXTENDED_MAX_LEVEL)
