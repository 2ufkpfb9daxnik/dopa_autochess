class_name RelicCombat
extends RefCounted

## まだ効果が入らないレリック（土台の仕組みが無いもの）。戦闘のレリックはほかはすべて適用済み。
## 148 反例: デバフに残り時間が無いので未適用。
## 経済側の未適用は relic_economy.gd の先頭を参照。


## bind で足し合わせる装備レリックの効果。能力ごとに [レリックID, 効果値の名前] を並べる。
## 同じレリックを複数装備したときは枚数ぶん足す。新しいレリックは該当する行に足すだけでよい。
const BIND_SUMS := {
	## 与ダメージ（%）
	"flat_damage": [[1, "与ダメージ"], [220, "与ダメージ"], [244, "与ダメージ"], [250, "与ダメージ"], [273, "与ダメージ"]],
	## 貫通率（%）
	"attack_pen": [[7, "貫通率"], [275, "貫通率"]],
	## 自分の属性の与ダメージ（%）。属性名つきのキー（「炎の与ダメージ」など）は _element_bonus_from で足す。
	"element_bonus": [[19, "属性の与ダメージ"]],
	## 最初の攻撃の与ダメージ（%）
	"opening_bonus": [[10, "最初の与ダメージ"], [222, "最初の与ダメージ"]],
	## 瀕死の与ダメージ（%）
	"low_bonus": [[20, "瀕死の与ダメージ"]],
	## 受けるダメージの軽減（%）。継続ダメージにも入るもの（162）と、入らないもの（014・206・231）。
	"taken_cut_dot": [[162, "受けるダメージ"]],
	"taken_cut": [[14, "受けるダメージ"], [206, "受けるダメージ"], [231, "受けるダメージ"]],
	## 命中したときの回復（%）と回数
	"heal_ratio": [[9, "回復"]],
	"heal_left": [[9, "回復の回数"]],
	## 吸血（%）
	"lifesteal": [[266, "吸血"], [280, "吸血"]],
	"layers": [[13, "層"]],
	"chase_left": [[11, "追撃の回数"]],
	"speed_step": [[18, "速度の上昇"]],
	"speed_cap": [[18, "速度の上限"]],
	"speed": [[2, "速度"], [215, "速度"], [230, "速度"], [241, "速度"]],
	"defense": [[3, "防御力"], [218, "防御力"], [243, "防御力"]],
	## 防御力の割合（%）
	"defense_rate": [[163, "防御力"]],
	"max_hp": [[4, "最大体力"], [202, "最大体力"], [219, "最大体力"], [228, "最大体力"], [232, "最大体力"]],
	## 最大体力の割合（%）
	"max_hp_rate": [[161, "最大体力"], [269, "最大体力"]],
	"attack": [[212, "攻撃力"], [237, "攻撃力"], [249, "攻撃力"]],
	## クリティカル率・クリティカルダメージ・属性耐性（%）
	"crit_rate": [[5, "クリティカル率"], [214, "クリティカル率"], [236, "クリティカル率"], [245, "クリティカル率"], [247, "クリティカル率"], [265, "クリティカル率"]],
	"crit_damage": [[6, "クリティカルダメージ"], [227, "クリティカルダメージ"], [265, "クリティカルダメージ"]],
	"attribute_resist": [[8, "属性耐性"]],
	"priority_cut": [[15, "優先度の低下"]],
	## 最大体力に対するシールド（%）
	"shield": [[175, "シールド"]],
	## ゲージの溜まり（%）
	"gauge": [[217, "ゲージ"]],
}


static func bind(fighter, host: Node) -> void:
	var ids := ids_of(fighter.unit, host)
	var sums := _bind_sums(ids)
	fighter.relic_ids = ids
	fighter.relic_flat_damage = sums["flat_damage"] / 100.0
	fighter.relic_attack_pen = sums["attack_pen"] / 100.0
	fighter.relic_element_bonus = sums["element_bonus"] / 100.0
	fighter.relic_element_bonus += _element_bonus_from(ids, fighter.element)
	fighter.relic_opening_bonus = sums["opening_bonus"] / 100.0
	fighter.relic_opening = fighter.relic_opening_bonus > 0.0
	## 010 だけが「最初の攻撃は外れない」。222 は外れても終わる。
	fighter.relic_opening_sure = ids.has(10)
	fighter.relic_low_bonus = sums["low_bonus"] / 100.0
	fighter.relic_taken_cut_dot = sums["taken_cut_dot"] / 100.0
	fighter.relic_taken_cut = fighter.relic_taken_cut_dot + sums["taken_cut"] / 100.0
	fighter.relic_heal_ratio = sums["heal_ratio"] / 100.0
	fighter.relic_heal_left = int(sums["heal_left"])
	## 266・280 吸血: 与えたダメージの割合が戻る。継続・範囲にも入る。
	fighter.relic_lifesteal = sums["lifesteal"] / 100.0
	fighter.relic_low_shield_ready = ids.has(266)
	fighter.relic_layers = int(sums["layers"])
	## relic_weaken_cut は「受けた弱体」。017 の付ける値は on_direct_hit で装備から取る。
	fighter.relic_weaken_cut = 0.0
	fighter.relic_chase_left = int(sums["chase_left"])
	fighter.relic_neighbor = ids.has(16)
	fighter.relic_speed_step = int(sums["speed_step"])
	fighter.relic_speed_cap = int(sums["speed_cap"])
	var flat_speed := int(sums["speed"])
	if flat_speed != 0:
		fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + flat_speed
	fighter.defense += sums["defense"]
	fighter.defense *= 1.0 + sums["defense_rate"] / 100.0
	var hp_bonus := int(sums["max_hp"])
	var hp_rate: float = sums["max_hp_rate"] / 100.0
	if hp_bonus != 0 or not is_zero_approx(hp_rate):
		var before: int = int(fighter.max_hp)
		fighter.max_hp = maxi(1, int(round(float(fighter.max_hp + hp_bonus) * (1.0 + hp_rate))))
		var gained: int = int(fighter.max_hp) - before
		if gained != 0:
			fighter.hp = clampi(int(fighter.hp) + gained, 1, int(fighter.max_hp))
	fighter.attack += sums["attack"]
	fighter.crit_rate += sums["crit_rate"] / 100.0
	fighter.crit_damage += sums["crit_damage"] / 100.0
	fighter.attribute_resist += sums["attribute_resist"] / 100.0
	var priority_cut := int(sums["priority_cut"])
	if priority_cut != 0:
		fighter.priority = maxi(0, fighter.priority - priority_cut)
	if ids.has(175):
		fighter.barrier += int(round(float(fighter.max_hp) * sums["shield"] / 100.0))
	var gauge_bonus: float = sums["gauge"]
	if gauge_bonus != 0.0:
		fighter.kit["gauge_rate"] = float(fighter.kit.get("gauge_rate", 1.0)) + gauge_bonus / 100.0
	_apply_pulse_kit(fighter, ids)


## BIND_SUMS の能力ごとの合計（効果値のまま。% の換算は bind でする）。
static func _bind_sums(ids: Array[int]) -> Dictionary:
	var sums := {}
	for stat in BIND_SUMS:
		var total := 0.0
		for entry in BIND_SUMS[stat]:
			total += _sum_one(ids, int(entry[0]), str(entry[1]))
		sums[stat] = total
	return sums


static func ids_of(unit: GameUnit, host: Node) -> Array[int]:
	var out: Array[int] = []
	if unit == null or host == null or host.get("session") == null:
		return out
	var session: GameSession = host.session
	for uid in unit.equipped_relic_uids:
		var relic_id := session.relic_id_of(int(uid))
		if relic_id > 0:
			out.append(relic_id)
	return out


static func attack_penetration(fighter) -> float:
	return fighter.relic_attack_pen


static func flat_outgoing(fighter) -> float:
	return fighter.relic_flat_damage


static func element_outgoing(fighter, element: String) -> float:
	if element.is_empty() or element != fighter.element:
		return 0.0
	return fighter.relic_element_bonus


static func named_coef(fighter, is_dot: bool) -> float:
	var coef := 1.0
	if not is_dot and fighter.relic_opening:
		coef *= 1.0 + fighter.relic_opening_bonus
	if not is_dot and fighter.relic_weaken_now > 0.0:
		coef *= maxf(0.0, 1.0 - fighter.relic_weaken_now)
	if fighter.relic_low_bonus > 0.0 and _is_low_hp(fighter):
		coef *= 1.0 + fighter.relic_low_bonus
	return coef


static func begin_attack(fighter) -> bool:
	fighter.relic_killed = false
	if fighter.relic_weaken_left > 0 and fighter.relic_weaken_cut > 0.0:
		fighter.relic_weaken_now = fighter.relic_weaken_cut
		fighter.relic_weaken_left = 0
	else:
		fighter.relic_weaken_now = 0.0
	return fighter.relic_opening and fighter.relic_opening_sure


static func finish_attack(fighter) -> void:
	fighter.relic_opening = false
	fighter.relic_weaken_now = 0.0
	if fighter.relic_speed_step <= 0 or fighter.relic_speed_cap <= 0:
		return
	var room: int = int(fighter.relic_speed_cap) - int(fighter.relic_speed_stack)
	if room <= 0:
		return
	var gain: int = mini(int(fighter.relic_speed_step), room)
	fighter.relic_speed_stack += gain
	fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + gain


static func on_direct_hit(actor, target, fighters: Dictionary) -> void:
	if actor.relic_heal_left > 0 and actor.relic_heal_ratio > 0.0 and actor.alive:
		var amount := int(round(float(actor.max_hp) * actor.relic_heal_ratio))
		if amount > 0:
			## 法螺話(173)の余剰シールドも入るよう、回復の共通入口を通す。
			heal(actor, amount)
			actor.relic_heal_left -= 1
	if actor.relic_layers > 0 and target != null:
		target.layers[actor.element] = int(target.layers.get(actor.element, 0)) + actor.relic_layers
	## 017 異邦人: 付ける値は装備者のレリックから取る。relic_weaken_cut は「受けた弱体」にも使うので、
	## 029・195 で弱体を受けた敵が、命中した味方へ弱体を移さないようにする。
	var cut := _sum_one(actor.relic_ids, 17, "次の与ダメージ") / 100.0
	if cut <= 0.0 or target == null or not is_instance_valid(target.unit):
		return
	if not target.alive:
		_release_mark(actor, fighters)
		return
	_release_mark(actor, fighters)
	actor.relic_mark_id = target.unit.get_instance_id()
	target.relic_weaken_cut = cut
	target.relic_weaken_left = 1
	target.relic_weaken_source = actor.unit.get_instance_id()


static func note_kill(actor) -> void:
	actor.relic_killed = true


static func clear_touching(dead, fighters: Dictionary) -> void:
	dead.relic_weaken_left = 0
	dead.relic_weaken_now = 0.0
	var dead_id := 0
	if is_instance_valid(dead.unit):
		dead_id = dead.unit.get_instance_id()
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.relic_weaken_source == dead_id and dead_id != 0:
			fighter.relic_weaken_left = 0
			fighter.relic_weaken_now = 0.0
		if fighter.relic_mark_id == dead_id and dead_id != 0:
			fighter.relic_mark_id = 0


static func _release_mark(actor, fighters: Dictionary) -> void:
	if actor.relic_mark_id != 0 and fighters.has(actor.relic_mark_id):
		var prev = fighters[actor.relic_mark_id]
		prev.relic_weaken_left = 0
		prev.relic_weaken_now = 0.0
	actor.relic_mark_id = 0


static func _is_low_hp(fighter) -> bool:
	var line := int(ceil(float(fighter.max_hp) / 2.0))
	return fighter.hp <= line


static func aura_outgoing(attacker, fighters: Dictionary, board: BoardController) -> float:
	var bonus := 0.0
	var bearer21 = _unique_living(fighters, 21, attacker.enemy, board)
	if bearer21 != null:
		bonus += _value(21, "与ダメージ") / 100.0
	var bearer25 = _unique_living(fighters, 25, attacker.enemy, board)
	if bearer25 != null and _row(attacker.unit, board).x == 1:
		bonus += _value(25, "与ダメージ") / 100.0
	bonus += _neighbor_damage(attacker, fighters, board)
	bonus += _owned_outgoing(attacker, board)
	if _row(attacker.unit, board).x == 1 and attacker.relic_ids.has(248):
		bonus += _sum_one(attacker.relic_ids, 248, "与ダメージ") / 100.0
	bonus += float(attacker.kit.get("tuple_bonus", 0.0))
	bonus += _neighbor_ally_damage(attacker, fighters, board)
	return bonus


static func _owned_outgoing(attacker, board: BoardController) -> float:
	if attacker.enemy:
		return 0.0
	var session := _session_of(board)
	if session == null:
		return 0.0
	return RelicEconomy.owned_outgoing(session)


static func aura_speed(fighter, fighters: Dictionary, board: BoardController) -> int:
	if _unique_living(fighters, 22, fighter.enemy, board) == null:
		return 0
	return int(_value(22, "速度"))


static func aura_defense(fighter, fighters: Dictionary, board: BoardController) -> float:
	if _row(fighter.unit, board).x != 0:
		return 0.0
	if _unique_living(fighters, 24, fighter.enemy, board) == null:
		return 0.0
	return _value(24, "防御力")


static func aura_pen(attacker, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 34, attacker.enemy, _board) == null:
		return 0.0
	return _value(34, "貫通率") / 100.0


static func aura_crit(attacker, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 27, attacker.enemy, _board) == null:
		return 0.0
	return _value(27, "クリティカル率") / 100.0


static func aura_resist(defender, fighters: Dictionary, _board: BoardController) -> float:
	if _unique_living(fighters, 28, defender.enemy, _board) == null:
		return 0.0
	return _value(28, "属性耐性") / 100.0


## is_dot のときは、継続ダメージにも入るもの（165・174・176・270・268）だけを足す。
static func aura_taken_cut(defender, fighters: Dictionary, board: BoardController, is_dot: bool = false) -> float:
	var cut := 0.0
	if not is_dot and _unique_living(fighters, 23, defender.enemy, board) != null:
		cut += _value(23, "受けるダメージ") / 100.0
	cut += float(_count_side(fighters, 165, defender.enemy)) * _value(165, "受けるダメージ") / 100.0
	if not defender.enemy and _owned_count(board, 176) >= int(_value(176, "枚数")):
		cut += _value(176, "受けるダメージ") / 100.0
	cut += _adjacent_mitigation(defender, fighters, board)
	## 268 セクション: 積みが上限に届いていれば軽減も入る。
	var hit_stack := float(defender.kit.get("relic_hit_stack", 0.0))
	var hit_cap := float(defender.kit.get("relic_hit_cap", 0.0))
	if hit_stack > 0.0 and hit_cap > 0.0 and hit_stack >= hit_cap:
		cut += float(defender.relic_ids.count(268)) * _value(268, "軽減") / 100.0
	if not defender.enemy:
		cut += _owned_taken_cut(board)
	if defender.relic_ids.has(270):
		cut += _ostrich_cut(defender, fighters, board)
	if is_dot:
		## 177 よろめき・185 土の装置・199 地震も継続ダメージに入る（攻撃側は _roll_damage で足す）。
		cut += extra_taken_cut(defender)
		return cut
	cut += _guard_neighbor_cut(defender, fighters, board)
	return cut


static func _ostrich_cut(defender, fighters: Dictionary, board: BoardController) -> float:
	return float(_neighbors(defender, fighters, board).size()) * _sum_one(defender.relic_ids, 270, "受けるダメージ") / 100.0


static func _neighbors(fighter, fighters: Dictionary, board: BoardController) -> Array:
	var out: Array = []
	var row := _row(fighter.unit, board)
	if row.x < 0:
		return out
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == fighter or ally.enemy != fighter.enemy or not _living(ally):
			continue
		var ally_row := _row(ally.unit, board)
		if ally_row.x == row.x and absi(ally_row.y - row.y) == 1:
			out.append(ally)
	return out


static func _session_of(board: BoardController) -> GameSession:
	return RelicEconomy.session_of_board(board)


static func _owned_count(board: BoardController, relic_id: int) -> int:
	var session := _session_of(board)
	return RelicEconomy._count(session, relic_id) if session != null else 0


static func _owned_taken_cut(board: BoardController) -> float:
	var session := _session_of(board)
	return RelicEconomy.owned_taken_cut(session) if session != null else 0.0


static func aura_priority(fighter, fighters: Dictionary, board: BoardController) -> int:
	var bonus := 0
	var row := _row(fighter.unit, board)
	if row.x < 0:
		return 0
	for key in fighters.keys():
		var bearer = fighters[key]
		if bearer.enemy != fighter.enemy or not _living(bearer) or not bearer.relic_ids.has(39):
			continue
		var bearer_row := _row(bearer.unit, board)
		if bearer_row.x != row.x:
			continue
		if bearer == fighter or absi(bearer_row.y - row.y) == 1:
			bonus += int(_value(39, "優先度の上昇"))
	return bonus


static func note_front_hit(target, fighters: Dictionary, board: BoardController) -> void:
	var bearer = _unique_living(fighters, 33, target.enemy, board)
	if bearer != target or _row(target.unit, board).x != 0:
		return
	var cut := _value(33, "受けるダメージ") / 100.0
	var row := _row(target.unit, board)
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == target or ally.enemy != target.enemy or not _living(ally):
			continue
		if _row(ally.unit, board).x != 0:
			continue
		if ally.relic_next_cut <= 0.0:
			ally.relic_next_cut = cut


static func crit_layer_bearer(actor, fighters: Dictionary, charges_left: int, board: BoardController = null):
	if charges_left <= 0:
		return null
	return _unique_living(fighters, 31, actor.enemy, board)


static func _neighbor_damage(attacker, fighters: Dictionary, board: BoardController) -> float:
	## 026: 隣の装備者1人ごとに1回分（装備者の枚数は見ない）。
	var bonus := 0.0
	var rate := _value(26, "与ダメージ") / 100.0
	for bearer in _neighbors(attacker, fighters, board):
		if bearer.relic_ids.has(26):
			bonus += rate
	return bonus


static func _guard_neighbor_cut(defender, fighters: Dictionary, board: BoardController) -> float:
	if _unique_living(fighters, 35, defender.enemy, board) == null:
		return 0.0
	var row := _row(defender.unit, board)
	if row.x != 0:
		return 0.0
	for key in fighters.keys():
		var ally = fighters[key]
		if ally == defender or ally.enemy != defender.enemy or not ally.guarding or not _living(ally):
			continue
		var ally_row := _row(ally.unit, board)
		if ally_row.x == 0 and absi(ally_row.y - row.y) == 1:
			return _value(35, "受けるダメージ") / 100.0
	return 0.0


static func bearer_deployed(fighters: Dictionary, board: BoardController, relic_id: int, ally_enemy: bool) -> bool:
	var unit := _designated_unit(fighters, board, relic_id, ally_enemy)
	return unit != null and fighters.has(unit.get_instance_id())


static func _unique_living(fighters: Dictionary, relic_id: int, ally_enemy: bool, board: BoardController = null):
	var unit := _designated_unit(fighters, board, relic_id, ally_enemy)
	if unit == null or not fighters.has(unit.get_instance_id()):
		return null
	var fighter = fighters[unit.get_instance_id()]
	if not _living(fighter):
		return null
	return fighter


static func _designated_unit(fighters: Dictionary, board: BoardController, relic_id: int, ally_enemy: bool) -> GameUnit:
	var chosen: GameUnit = null
	## 戦闘に出ている（出ていた）キャラクターだけから選ぶ。控えや別の面の装備者では消えない。
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.enemy != ally_enemy or not is_instance_valid(fighter.unit):
			continue
		if not fighter.relic_ids.has(relic_id):
			continue
		if _smaller_bearer(fighter.unit, chosen):
			chosen = fighter.unit
	return chosen


static func _smaller_bearer(unit: GameUnit, chosen: GameUnit) -> bool:
	if chosen == null:
		return true
	if unit.unit_id != chosen.unit_id:
		return unit.unit_id < chosen.unit_id
	return unit.get_instance_id() < chosen.get_instance_id()


static func _living(fighter) -> bool:
	return fighter != null and fighter.alive and fighter.hp > 0 and is_instance_valid(fighter.unit)


static func _row(unit: GameUnit, board: BoardController) -> Vector2i:
	if unit == null or board == null:
		return Vector2i(-1, -1)
	if unit.is_enemy:
		var slot := board.front_slot_of(unit)
		if slot >= 0:
			return Vector2i(0, slot)
		return Vector2i(-1, -1)
	for slot_index in BoardController.SLOTS_PER_FACE:
		if board.get_resolved_unit(board.active_face, slot_index) == unit:
			return Vector2i(0 if slot_index < BoardController.FRONT_COUNT else 1, slot_index % BoardController.FRONT_COUNT)
	return Vector2i(-1, -1)


static func _element_bonus_from(ids: Array[int], element: String) -> float:
	if element.is_empty():
		return 0.0
	var key := "%sの与ダメージ" % _element_label(element)
	if key == "の与ダメージ":
		return 0.0
	var total := 0.0
	for relic_id in ids:
		var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
		total += float(effects.get(key, 0.0))
	return total / 100.0


## 属性の内部名から、効果値の名前に使う日本語名へ。日本語名はそのまま返す。
const ELEMENT_LABELS := {
	"fire": "炎", "water": "水", "thunder": "雷", "earth": "土", "ice": "氷", "wind": "風", "absorb": "吸収",
}


static func _element_label(element: String) -> String:
	return str(ELEMENT_LABELS.get(element, element))


static func _apply_pulse_kit(fighter, ids: Array[int]) -> void:
	## 164 就職・269 接着剤: 装備者の2行動ごとに回復。割合は枚数ぶん足す。
	var heal_ratio := (_sum_one(ids, 164, "回復") + _sum_one(ids, 269, "回復")) / 100.0
	if heal_ratio > 0.0:
		var gap := int(_value(164 if ids.has(164) else 269, "間隔"))
		fighter.kit["relic_pulse_gap"] = maxi(gap, 1)
		fighter.kit["relic_pulse_heal"] = heal_ratio
		fighter.kit["relic_pulse_left"] = maxi(gap, 1)
	## 272 近影: 時間ごとに与ダメージ。枚数ぶん足す。
	if ids.has(272):
		fighter.kit["relic_ramp_ap"] = int(round(_value(272, "間隔") * float(AP_PER_SECOND)))
		fighter.kit["relic_ramp_step"] = _sum_one(ids, 272, "与ダメージ") / 100.0
		fighter.kit["relic_ramp_clock"] = 0
	## 268 セクション: 通常の攻撃か被弾で積む。
	if ids.has(268):
		fighter.kit["relic_hit_step"] = _sum_one(ids, 268, "与ダメージ") / 100.0
		fighter.kit["relic_hit_cap"] = _value(268, "上限") / 100.0
		fighter.kit["relic_hit_stack"] = 0.0
	## 267 連中: 1行動ごとに速度。上限なし。
	if ids.has(267):
		fighter.kit["relic_speed_grow"] = int(_sum_one(ids, 267, "速度"))


static func _count_side(fighters: Dictionary, relic_id: int, ally_enemy: bool) -> int:
	var count := 0
	for key in fighters.keys():
		var fighter = fighters[key]
		if fighter.enemy == ally_enemy and _living(fighter) and fighter.relic_ids.has(relic_id):
			count += 1
	return count


static func _adjacent_mitigation(defender, fighters: Dictionary, board: BoardController) -> float:
	## 174 マイホーム: 隣に味方がいれば1回分、隣の装備者の人数だけさらに足す。
	if not defender.relic_ids.has(174):
		return 0.0
	var near := _neighbors(defender, fighters, board)
	if near.is_empty():
		return 0.0
	var times := 1
	for ally in near:
		if ally.relic_ids.has(174):
			times += 1
	return float(times) * _value(174, "受けるダメージ") / 100.0


static func _neighbor_ally_damage(attacker, fighters: Dictionary, board: BoardController) -> float:
	## 281: 隣の装備者の枚数ぶん。
	var bonus := 0.0
	for bearer in _neighbors(attacker, fighters, board):
		if bearer.relic_ids.has(281):
			bonus += _sum_one(bearer.relic_ids, 281, "与ダメージ") / 100.0
	return bonus


static func apply_front_hp_aura(fighters: Dictionary, board: BoardController) -> void:
	for side in [false, true]:
		## 前衛にいる味方が装備している枚数。
		var stacks := 0
		for key in fighters.keys():
			var bearer = fighters[key]
			if bearer.enemy == side and _living(bearer) and _row(bearer.unit, board).x == 0:
				stacks += bearer.relic_ids.count(168)
		if stacks <= 0:
			continue
		var rate := float(stacks) * _value(168, "最大体力") / 100.0
		for key in fighters.keys():
			var fighter = fighters[key]
			if fighter.enemy != side or not _living(fighter):
				continue
			if _row(fighter.unit, board).x != 0:
				continue
			var before: int = int(fighter.max_hp)
			fighter.max_hp = maxi(1, int(round(float(fighter.max_hp) * (1.0 + rate))))
			fighter.hp = mini(int(fighter.max_hp), int(fighter.hp) + (int(fighter.max_hp) - before))


## 行動した本人のレリック（164・269 の回復、267 の速度）。速度が変わったら true。
static func tick_actor(fighter) -> bool:
	if not _living(fighter):
		return false
	var gap := int(fighter.kit.get("relic_pulse_gap", 0))
	if gap > 0:
		var left := int(fighter.kit.get("relic_pulse_left", gap)) - 1
		if left <= 0:
			heal(fighter, int(round(float(fighter.max_hp) * float(fighter.kit.get("relic_pulse_heal", 0.0)))))
			left = gap
		fighter.kit["relic_pulse_left"] = left
	var grow := int(fighter.kit.get("relic_speed_grow", 0))
	if grow > 0:
		fighter.kit["relic_speed"] = int(fighter.kit.get("relic_speed", 0)) + grow
		return true
	return false


static func note_hit_stack(fighter) -> void:
	if fighter == null:
		return
	var step := float(fighter.kit.get("relic_hit_step", 0.0))
	if step <= 0.0:
		return
	var cap := float(fighter.kit.get("relic_hit_cap", 0.0))
	var stack := float(fighter.kit.get("relic_hit_stack", 0.0))
	var next := stack + step
	if cap > 0.0:
		next = minf(cap, next)
	fighter.kit["relic_hit_stack"] = next
	fighter.relic_flat_damage += next - stack


static func _value(relic_id: int, key: String) -> float:
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	return float(effects.get(key, 0.0))


static func _sum_one(ids: Array[int], relic_id: int, key: String) -> float:
	var total := 0.0
	var effects: Dictionary = RelicCatalog.get_relic(relic_id).get("effects", {})
	var value := float(effects.get(key, 0.0))
	for owned in ids:
		if owned == relic_id:
			total += value
	return total


# ---------------------------------------------------------------------------
# 戦闘中の追加効果（167・173・177・185・186・189・194・196・199・216・274・276・277・278・283・284）
# ---------------------------------------------------------------------------

## 「秒」で書かれた効果の換算。速度100のキャラクター1行動ぶんの行動ポイントを1秒とする（暫定）。
const AP_PER_SECOND := 655


## 装備レリック由来で、bind のあとに決まる値（セッションの積みなど）。
static func bind_extras(fighter, host: Node) -> void:
	var ids: Array[int] = fighter.relic_ids
	var session: GameSession = host.session if host != null and host.get("session") != null else null
	if session != null and not fighter.enemy and is_instance_valid(fighter.unit):
		var rate := (RelicEconomy.growth_max_hp(session, fighter.unit) + RelicEconomy.leisure_max_hp(session, fighter.unit) - RelicEconomy.owned_max_hp_cut(session)) / 100.0
		if not is_zero_approx(rate):
			var before: int = int(fighter.max_hp)
			fighter.max_hp = maxi(1, int(round(float(fighter.max_hp) * (1.0 + rate))))
			fighter.hp = clampi(int(fighter.hp) + int(fighter.max_hp) - before, 1, int(fighter.max_hp))
	var staggers := ids.count(177)
	fighter.relic_hit_cut = float(staggers) * _value(177, "受けるダメージ") / 100.0 if staggers >= 2 else 0.0
	fighter.relic_survive_ready = ids.has(277)
	fighter.relic_debuff_guard_ap = int(_value(278, "行動ポイント")) if ids.has(278) else 0
	fighter.relic_sea_clock = 0


## 回復の共通入口。最大体力を超えたぶんは法螺話(173)でシールドになる。実際に増えた体力を返す。
static func heal(fighter, amount: int) -> int:
	if fighter == null or amount <= 0 or not fighter.alive:
		return 0
	var gained: int = mini(amount, int(fighter.max_hp) - int(fighter.hp))
	fighter.hp += maxi(gained, 0)
	var over: int = amount - maxi(gained, 0)
	var copies: int = fighter.relic_ids.count(173)
	if over > 0 and copies > 0:
		var cap := int(round(float(fighter.max_hp) * float(copies) * _value(173, "シールド") / 100.0))
		var held: int = mini(int(fighter.kit.get("overheal_shield", 0)), int(fighter.barrier))
		var add: int = mini(over, maxi(cap - held, 0))
		if add > 0:
			fighter.barrier += add
			fighter.kit["overheal_shield"] = held + add
	if is_instance_valid(fighter.unit):
		fighter.unit.set_battle_hp(fighter.hp, fighter.max_hp)
	return maxi(gained, 0)


## 攻撃する側と受ける側の組で決まる与ダメージ（274 カメオ、276 部屋、186 火の装置、216/189 召喚）。
static func pair_outgoing(attacker, defender, fighters: Dictionary, board: BoardController) -> float:
	var bonus := 0.0
	if defender != null and int(defender.max_hp) > int(attacker.max_hp):
		bonus += float(attacker.relic_ids.count(274)) * _value(274, "与ダメージ") / 100.0
	if defender != null:
		var foe_col := _row(defender.unit, board).y
		if foe_col >= 0:
			for key in fighters.keys():
				var bearer = fighters[key]
				if bearer.enemy != attacker.enemy or not _living(bearer) or not bearer.relic_ids.has(276):
					continue
				var col := _row(bearer.unit, board).y
				if col >= 0 and absi(col - foe_col) == 1:
					bonus += _value(276, "受けるダメージ") / 100.0
	if not attacker.enemy and _row(attacker.unit, board).x == 1:
		bonus += float(attacker.kit.get("fire_device_bonus", 0.0))
	return bonus


## 召喚物・コピーの与ダメージ（216 は出した本人の装備、189 は持っているだけで入る）。
static func summon_outgoing(summoner, session: GameSession) -> float:
	var bonus := float(summoner.relic_ids.count(216)) * _value(216, "召喚の与ダメージ") / 100.0
	if not summoner.enemy and session != null:
		bonus += float(RelicEconomy._count(session, 189)) * _value(189, "与ダメージ") / 100.0
	return bonus


## 受けるダメージの軽減（177 よろめきの積み、185 土の装置、199 地震）。
static func extra_taken_cut(defender) -> float:
	return float(defender.relic_hit_cut) + float(defender.kit.get("device_taken_cut", 0.0))


## 177: 攻撃を受けるたびに積む。継続ダメージの被弾でも積む。
static func note_hit_taken(defender) -> void:
	if defender == null or not defender.relic_ids.has(177):
		return
	defender.relic_hit_cut += _value(177, "受けるダメージ") / 100.0


## 277 完結: 倒れるダメージを1戦闘に1回だけ体力1で耐える。耐えたら true。
static func try_survive(target, incoming: int) -> bool:
	if not target.relic_survive_ready or incoming < int(target.hp) or int(target.hp) <= 0:
		return false
	target.relic_survive_ready = false
	target.relic_untargetable_ap = int(round(_value(277, "時間") * float(AP_PER_SECOND)))
	return true


## 278 執念: まだデバフを受けない時間か。
static func blocks_debuff(target) -> bool:
	return int(target.relic_debuff_guard_ap) > 0


## 行動ポイントが減るたびに呼ぶ。lost はその味方の減ったぶん、spent は経過ぶん。
static func tick_time(fighter, lost: int, spent: int) -> void:
	if int(fighter.relic_untargetable_ap) > 0:
		fighter.relic_untargetable_ap = maxi(0, int(fighter.relic_untargetable_ap) - spent)
	if int(fighter.relic_debuff_guard_ap) > 0:
		fighter.relic_debuff_guard_ap = maxi(0, int(fighter.relic_debuff_guard_ap) - lost)
	if fighter.relic_ids.has(284):
		fighter.relic_sea_clock += spent
	var ramp_ap := int(fighter.kit.get("relic_ramp_ap", 0))
	if ramp_ap > 0:
		var clock := int(fighter.kit.get("relic_ramp_clock", 0)) + spent
		while clock >= ramp_ap:
			clock -= ramp_ap
			fighter.relic_flat_damage += float(fighter.kit.get("relic_ramp_step", 0.0))
		fighter.kit["relic_ramp_clock"] = clock


## 284 海: 間隔ぶん経ったら true を返し、時計を戻す。
static func take_sea_pulse(fighter) -> bool:
	if not fighter.relic_ids.has(284):
		return false
	var gap := int(round(_value(284, "間隔") * float(AP_PER_SECOND)))
	if gap <= 0 or int(fighter.relic_sea_clock) < gap:
		return false
	fighter.relic_sea_clock -= gap
	return true


## 283 違反: 返すダメージ。
static func reflect_amount(target, dealt: int) -> int:
	var copies: int = target.relic_ids.count(283)
	if copies <= 0 or dealt <= 0:
		return 0
	return int(round(float(dealt) * float(copies) * _value(283, "反射") / 100.0))


## 037 ドローン: 範囲シナジーで攻撃する味方の範囲の体数が1多い（1つだけ入る）。
static func drone_extra(actor, fighters: Dictionary, board: BoardController) -> int:
	return 1 if _unique_living(fighters, 37, actor.enemy, board) != null else 0
