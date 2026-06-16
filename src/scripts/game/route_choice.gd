class_name RouteChoice
extends RefCounted

enum Strength { WEAK, MEDIUM, STRONG, ELITE, BOSS }

const BOSS_ROUNDS: Array[int] = [5, 10, 15, 20, 25]
const REWARD_TYPES: Array[String] = ["augment", "gold", "reroll", "equipment"]
const REWARD_LABELS: Dictionary = {
	"augment": "オーグメント",
	"gold": "ゴールド",
	"reroll": "無料更新",
	"equipment": "装備",
}

const STRENGTH_LABELS: Dictionary = {
	Strength.WEAK: "弱",
	Strength.MEDIUM: "中",
	Strength.STRONG: "強",
	Strength.ELITE: "エリート",
	Strength.BOSS: "ボス",
}

const ENEMY_STARS: Dictionary = {
	Strength.WEAK: "★",
	Strength.MEDIUM: "★★",
	Strength.STRONG: "★★★",
	Strength.ELITE: "★★★★",
	Strength.BOSS: "★★★★★",
}


static func generate_options(upcoming_round: int) -> Array[Dictionary]:
	if BOSS_ROUNDS.has(upcoming_round):
		return _generate_boss_options(upcoming_round)
	var options: Array[Dictionary] = []
	options.append(_make_option(Strength.WEAK))
	options.append(_make_option(Strength.MEDIUM))
	options.append(_make_option(Strength.STRONG))
	if randf() < 0.18:
		var replace_index := randi_range(0, 2)
		options[replace_index] = _make_option(Strength.ELITE)
	return options


static func _generate_boss_options(upcoming_round: int) -> Array[Dictionary]:
	return [
		_make_option(Strength.BOSS),
		_make_option(Strength.MEDIUM),
		_make_option(Strength.WEAK),
	]


static func _make_option(strength: Strength) -> Dictionary:
	var reward_type: String = REWARD_TYPES[randi_range(0, REWARD_TYPES.size() - 1)]
	return {
		"strength": strength,
		"strength_label": STRENGTH_LABELS[strength],
		"enemy_label": ENEMY_STARS[strength],
		"reward_type": reward_type,
		"reward_label": REWARD_LABELS[reward_type],
	}


const GOLD_REWARDS: Dictionary = {
	Strength.WEAK: 3,
	Strength.MEDIUM: 5,
	Strength.STRONG: 8,
	Strength.ELITE: 12,
	Strength.BOSS: 15,
}


static func get_gold_reward(strength: Strength) -> int:
	return int(GOLD_REWARDS.get(strength, 3))


static func format_option(option: Dictionary) -> String:
	return "敵%s / 報酬: %s" % [option["enemy_label"], option["reward_label"]]
