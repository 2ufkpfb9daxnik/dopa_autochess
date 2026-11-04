extends RefCounted

## レリック経済の共通の道具。RelicEconomy はテーマごとのファイルを1本の継承でつないだもの:
##   relic_economy_base（共通） ← relic_economy_growth（成長・戦闘への補正） ← relic_economy_quest（クエスト・戦闘結果）
##   ← relic_economy_gold（ゴールド・経験値・レベル） ← relic_economy_shop（ショップ・売買・合成）
##   ← relic_economy_use（手で使うレリック） ← relic_economy（入手・ラウンドの区切り。class_name RelicEconomy）
## 外からは今までどおり RelicEconomy.xxx で呼ぶ。各ファイルは自分より上（継承元）の関数だけを呼ぶ。


## 与ダメージを積む「ラウンドをまたぐ成長」。ギター(156)が換えられるのもこれだけ。
const DAMAGE_GROWTH_IDS: Array[int] = [141, 143, 144, 145, 146, 147, 149, 150, 151, 152, 154, 159, 160]


static func _value(relic_id: int, key: String) -> float:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	return float(effects.get(key, 0.0))


static func _count(session: GameSession, relic_id: int) -> int:
	var count := 0
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id:
			count += 1
	return count


## 持っている枚数 × 効果値（整数）。
static func _owned_value(session: GameSession, relic_id: int, key: String) -> int:
	return _count(session, relic_id) * int(_value(relic_id, key))


## 持っている枚数 × 効果値（小数。% のまま）。
static func _owned_float(session: GameSession, relic_id: int, key: String) -> float:
	return float(_count(session, relic_id)) * _value(relic_id, key)


## 残り回数（left）が残っている枚数。
static func _charges(session: GameSession, relic_id: int) -> int:
	var count := 0
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id and int(item.get("left", 0)) > 0:
			count += 1
	return count


static func _item(session: GameSession, uid: int) -> Dictionary:
	for item in session.relics:
		if int(item.get("uid", -1)) == uid:
			return item
	return {}


## 残り回数（left）が残っているものを、最大 limit 枚（-1 は全部）だけ1減らし、0になったものを消す。
## on_tick はその1枚を減らす直前に item を受け取って呼ぶ。減らした枚数を返す。
static func _tick_down(session: GameSession, relic_id: int, on_tick: Callable = Callable(), limit: int = -1) -> int:
	var ticked := 0
	var remove: Array[int] = []
	for item in session.relics:
		if limit >= 0 and ticked >= limit:
			break
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", 0))
		if left <= 0:
			continue
		if on_tick.is_valid():
			on_tick.call(item)
		item["left"] = left - 1
		ticked += 1
		if left - 1 <= 0:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)
	return ticked


## 残り（left）を step 減らし、0以下になったものを返す（消さない）。left が無いときは fallback から数える。
## _tick_down と違い、すでに0のものも減らして返す。
static func _count_down(session: GameSession, relic_id: int, step: int = 1, fallback: int = 0) -> Array:
	var expired: Array = []
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		var left := int(item.get("left", fallback)) - step
		item["left"] = left
		if left <= 0:
			expired.append(item)
	return expired


static func _consume_one(session: GameSession, relic_id: int) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != relic_id:
			continue
		session.take_relic(int(item.get("uid", -1)))
		return


static func _consume_all(session: GameSession, relic_id: int) -> void:
	var remove: Array[int] = []
	for item in session.relics:
		if int(item.get("id", -1)) == relic_id:
			remove.append(int(item.get("uid", -1)))
	for uid in remove:
		session.take_relic(uid)


static func _queue_unit(session: GameSession, unit_id: int, stars: int) -> void:
	if UnitCatalog.get_unit(unit_id).is_empty():
		return
	session.relic_pending_units.append({"id": unit_id, "stars": stars})


static func _queue_random_relic(session: GameSession) -> void:
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if pool.is_empty():
		return
	session.add_relic(pool[randi() % pool.size()])


## pick に合うレリックを1つ入れる。候補が無ければ何でも1つ。
static func _grant_random_where(session: GameSession, pick: Callable) -> void:
	var pool: Array[int] = []
	for relic_id in RelicCatalog.all_pick_ids():
		if bool(pick.call(relic_id)):
			pool.append(relic_id)
	if pool.is_empty():
		_queue_random_relic(session)
		return
	session.add_relic(pool[randi() % pool.size()])


static func _category(relic_id: int) -> String:
	return str(RelicCatalog.get_relic(relic_id).get("category", ""))


## プレイヤーHPを最大HPまで戻す。
static func _heal_player(session: GameSession, amount: int) -> void:
	session.player_hp = mini(player_max_hp(session), session.player_hp + amount)


static func player_max_hp(session: GameSession) -> int:
	var bonus := 0
	bonus += _owned_value(session, 171, "最大HP")
	bonus += int(round(float(PlayerHp.INITIAL_HP) * _count(session, 260) * _value(260, "最大HP") / 100.0))
	return PlayerHp.INITIAL_HP + bonus


static func _growth_of(session: GameSession, uid: int) -> float:
	return float(_item(session, uid).get("growth", 0.0))


static func _is_damage_growth(relic_id: int) -> bool:
	return DAMAGE_GROWTH_IDS.has(relic_id)


## 盤面からセッションを探す。盤面は戦闘用の SubViewport の下へ移されるので、
## 親の親までたどって session を持つノード（game）を見つける。
static func session_of_board(board: Node) -> GameSession:
	var node: Node = board
	while node != null:
		var found = node.get("session")
		if found is GameSession:
			return found as GameSession
		node = node.get_parent()
	return null


static func _owned_units(session: GameSession) -> Array:
	var host := session.get_parent()
	if host == null or host.get("board") == null:
		return []
	return host.board.get_all_units()


static func _equipped_owner(session: GameSession, uid: int) -> GameUnit:
	for unit in _owned_units(session):
		if unit != null and unit.equipped_relic_uids.has(uid):
			return unit
	return null


## unit が装備している relic_id の uid（装備の順）。
static func _equipped_uids(session: GameSession, unit: GameUnit, relic_id: int) -> Array[int]:
	var out: Array[int] = []
	if unit == null:
		return out
	for uid in unit.equipped_relic_uids:
		if session.relic_id_of(uid) == relic_id:
			out.append(uid)
	return out


static func strip_equipped_uid(session: GameSession, uid: int) -> void:
	if uid < 0:
		return
	for unit in _owned_units(session):
		if unit == null or unit.equipped_relic_uids.is_empty():
			continue
		while unit.equipped_relic_uids.has(uid):
			unit.equipped_relic_uids.erase(uid)


## サークルにいるキャラクターが装備している枚数（207 七曲り・209 讃歌）。
static func _circle_bearers(session: GameSession, relic_id: int) -> int:
	var host := session.get_parent()
	if host == null or host.get("board") == null:
		return 0
	var count := 0
	for unit in host.board.get_circle_units():
		if unit == null or unit.kit_flags.has("relic_temp"):
			continue
		count += _equipped_uids(session, unit, relic_id).size()
	return count
