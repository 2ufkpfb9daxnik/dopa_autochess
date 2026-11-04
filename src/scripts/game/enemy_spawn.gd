class_name EnemySpawn
extends RefCounted

## プレイヤーの盤面に寄せつつ、挑戦★で少しだけ上下する。


static func spawn_for_battle(
	board: BoardController,
	units_root: Node3D,
	session: GameSession,
	route: Dictionary
) -> int:
	board.clear_enemy_units()
	var challenge := int(route.get("stars", 2))
	if challenge <= 0:
		challenge = 2
	challenge = clampi(challenge, 1, 4)
	var player_count := maxi(1, board.get_board_unit_count())
	var count := clampi(player_count + _count_bias(challenge), 1, BoardController.SLOTS_PER_FACE)
	var shop_level := RelicEconomy.shop_odds_level(session, false) + _shop_bias(challenge)
	shop_level = clampi(shop_level, 1, ShopOdds.TABLE_LEVELS)
	var star_range := _star_range(board.get_board_star_average(), challenge)
	for slot_index in count:
		var unit_id := UnitCatalog.random_unit_id_for_level(shop_level)
		var stars := randi_range(star_range.x, star_range.y)
		var unit := GameUnit.create(unit_id, stars)
		unit.is_enemy = true
		units_root.add_child(unit)
		board.place_enemy_unit(unit, slot_index)
	return count


static func _count_bias(challenge: int) -> int:
	match challenge:
		1:
			return randi_range(-1, 0)
		2:
			return 0
		3:
			return randi_range(0, 1)
		4:
			return randi_range(1, 2)
		_:
			return 0


static func _shop_bias(challenge: int) -> int:
	## ★2を基準に、コスト帯を少しだけずらす。
	return challenge - 2


static func _star_range(player_avg: float, challenge: int) -> Vector2i:
	var base := clampi(int(round(player_avg)), 1, GameUnit.MAX_STARS)
	var lo := base
	var hi := base
	match challenge:
		1:
			lo = base - 1
			hi = base
		2:
			lo = base
			hi = base
		3:
			lo = base
			hi = base + 1
		4:
			lo = base + 1
			hi = base + 1
		_:
			pass
	lo = clampi(lo, 1, GameUnit.MAX_STARS)
	hi = clampi(maxi(lo, hi), 1, GameUnit.MAX_STARS)
	return Vector2i(lo, hi)
