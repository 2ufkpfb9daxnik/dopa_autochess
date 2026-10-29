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
	## ルート選択UIは廃止。敵強度だけラウンドから決めて1件返す。
	return [default_for_round(upcoming_round)]


static func default_for_round(upcoming_round: int) -> Dictionary:
	var strength := Strength.MEDIUM
	if BOSS_ROUNDS.has(upcoming_round):
		strength = Strength.BOSS
	elif upcoming_round <= 3:
		strength = Strength.WEAK
	elif upcoming_round <= 8:
		strength = Strength.MEDIUM
	elif upcoming_round <= 14:
		strength = Strength.STRONG
	else:
		strength = Strength.ELITE
	return {
		"strength": strength,
		"strength_label": STRENGTH_LABELS[strength],
		"enemy_label": ENEMY_STARS[strength],
		"reward_type": "none",
		"reward_label": "",
	}


static func _make_option(strength: Strength) -> Dictionary:
	return {
		"strength": strength,
		"strength_label": STRENGTH_LABELS[strength],
		"enemy_label": ENEMY_STARS[strength],
		"reward_type": "none",
		"reward_label": "",
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
