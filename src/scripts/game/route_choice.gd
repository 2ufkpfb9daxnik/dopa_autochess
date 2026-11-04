class_name RouteChoice
extends RefCounted

## 挑戦の★。数が多いほど敵が強く、レリック選択回数が増える。
const STAR4_CHANCE := 0.16
const ROUTE_HINT := "★が多いほど難しく、報酬も多い"


static func generate_options(_upcoming_round: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		_make_option(1),
		_make_option(2),
		_make_option(3),
	]
	if randf() < STAR4_CHANCE:
		options.append(_make_option(4))
	return options


static func default_for_round(_upcoming_round: int) -> Dictionary:
	## ルート未選択時（ラウンド1など）の既定。普通相当。
	return _make_option(2)


static func for_stars(stars: int) -> Dictionary:
	return _make_option(stars)


static func _make_option(stars: int) -> Dictionary:
	var clamped := clampi(stars, 1, 4)
	var mark := star_text(clamped)
	return {
		"stars": clamped,
		"relic_picks": clamped,
		"strength": clamped,
		"strength_label": mark,
		"enemy_label": mark,
		"reward_type": "relic_picks",
		"reward_label": "レリック×%d" % clamped,
		"button_text": "%s\nレリック×%d" % [mark, clamped],
	}


static func star_text(stars: int) -> String:
	var out := ""
	for _i in clampi(stars, 1, 4):
		out += "★"
	return out


static func format_option(option: Dictionary) -> String:
	var stars := int(option.get("stars", 2))
	return "%s / レリック×%d" % [star_text(stars), stars]


static func get_gold_reward(_strength: int) -> int:
	return 0
