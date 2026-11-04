extends "res://scripts/game/relic_economy_shop.gd"

## 手で使うレリック（レリックをクリックして使う）。
## 継承のつながりは relic_economy_base.gd の先頭を参照。

const USE_NONE := ""
const USE_NOW := "now"
const USE_UNIT := "unit"
const USE_RELIC := "relic"
## 消費の対象にできないもの: 階段1・2・3、クロージャ。
const UNCONSUMABLE: Array[int] = [312, 313, 314, 302]
## レリックを消して報酬を得るもの（303〜306）。
const CONSUMERS: Array[int] = [303, 304, 305, 306]


## そのレリックの使い方。USE_NONE は使えない。
static func use_mode(session: GameSession, uid: int) -> String:
	var item := _item(session, uid)
	if item.is_empty():
		return USE_NONE
	match int(item.get("id", -1)):
		103, 104, 190, 156:
			return USE_UNIT
		108:
			return USE_NOW
		191:
			return USE_NOW if item.has("egg") else USE_UNIT
		180:
			if bool(item.get("leisure_copy", false)) or session.relic_180_used >= int(_value(180, "回数")):
				return USE_NONE
			return USE_NOW
		303, 304, 305, 306:
			return USE_RELIC
	return USE_NONE


## 使う前の確認文。
static func use_prompt(session: GameSession, uid: int) -> String:
	var relic_id := session.relic_id_of(uid)
	match relic_id:
		103, 104:
			return "複製するキャラクターを選んでください（コスト%d以下）" % int(_value(relic_id, "上限コスト"))
		190:
			return "次の戦闘でコピーを出すサークルの味方を選んでください"
		191:
			if _item(session, uid).has("egg"):
				return "卵を割って、入れたときの星で控えに戻しますか？"
			return "卵に入れるキャラクターを選んでください"
		156:
			return "ギターを付けるキャラクターを選んでください。付いている成長の与ダメージをゴールドに換えます"
		180:
			return "レジャーを1つ消費して、最大体力のレリックを2つ得ますか？"
		108:
			return "サークルの味方を、それぞれコストが1高いキャラクターに変えますか？"
		303, 304, 305, 306:
			return "消すレリックを選んでください"
	return ""


## 156 ギター: 装備者の成長レリックを換えたときのゴールド。
static func guitar_gold(session: GameSession, owner: GameUnit) -> int:
	if owner == null:
		return 0
	var percent := 0.0
	for other in owner.equipped_relic_uids:
		if _is_damage_growth(session.relic_id_of(other)):
			percent += _growth_of(session, other)
	return int(floor(percent)) * int(_value(156, "ゴールド"))


## 対象のいらない使用。成功したら true。
static func use_now(session: GameSession, uid: int) -> bool:
	var item := _item(session, uid)
	if item.is_empty():
		return false
	match int(item.get("id", -1)):
		108:
			## 108 西通り: 使うと、サークルの味方がコスト+1のキャラクターに変わる。
			var host_108 := session.get_parent()
			if host_108 == null or not host_108.has_method("relic_upgrade_board_costs"):
				return false
			session.take_relic(uid)
			host_108.relic_upgrade_board_costs(int(_value(108, "コスト上昇")))
			return true
		180:
			if use_mode(session, uid) != USE_NOW:
				return false
			session.relic_180_used += 1
			session.take_relic(uid)
			for _i in int(_value(180, "回数")):
				session.add_relic(180, {"leisure_copy": true, "max_hp_rate": _value(180, "最大体力"), "from_shinan": true})
			return true
		191:
			if not item.has("egg"):
				return false
			var egg: Dictionary = item["egg"]
			item.erase("egg")
			_queue_unit(session, int(egg.get("id", -1)), int(egg.get("stars", 1)))
			return true
	return false


## キャラクターを対象にする使用（103・104・190・191・156）。成功したら true。
static func use_on_unit(session: GameSession, uid: int, unit: GameUnit) -> bool:
	var item := _item(session, uid)
	if item.is_empty() or unit == null or unit.is_enemy:
		return false
	var relic_id := int(item.get("id", -1))
	match relic_id:
		103, 104:
			if unit.get_cost() > int(_value(relic_id, "上限コスト")):
				return false
			_queue_unit(session, unit.unit_id, unit.stars)
			session.take_relic(uid)
			return true
		190:
			if unit.circle_slot < 0:
				return false
			item["copy_unit"] = unit.get_instance_id()
			return true
		156:
			## ギターは装備しているキャラクターにだけ効く。付いていなければ付ける。
			if not unit.equipped_relic_uids.has(uid):
				if unit.equipped_relic_uids.size() >= GameUnit.RELIC_EQUIP_CAP:
					return false
				strip_equipped_uid(session, uid)
				unit.equipped_relic_uids.append(uid)
			var gold := guitar_gold(session, unit)
			for other in unit.equipped_relic_uids:
				if _is_damage_growth(session.relic_id_of(other)):
					_item(session, other)["growth"] = 0.0
			session.add_coins(gold)
			return true
		191:
			if item.has("egg"):
				return false
			item["egg"] = {"id": unit.unit_id, "stars": unit.stars, "left": int(_value(191, "ラウンド"))}
			return true
	return false


## レリックを消す使用（303〜306）。成功したら true。
static func use_on_relic(session: GameSession, uid: int, target_uid: int) -> bool:
	var relic_id := session.relic_id_of(uid)
	var target_id := session.relic_id_of(target_uid)
	if target_id <= 0 or UNCONSUMABLE.has(target_id):
		return false
	if not CONSUMERS.has(relic_id):
		return false
	if target_uid != uid:
		session.take_relic(target_uid)
	session.take_relic(uid)
	match relic_id:
		303:
			session.add_coins(int(_value(303, "ゴールド")))
		304:
			session.gain_experience(int(_value(304, "経験値")))
		305:
			session.free_rerolls += int(_value(305, "無料更新"))
		306:
			_heal_player(session, int(_value(306, "HP")))
	## 船酔い(171)・レコード(260)を消したときは、プレイヤーHPが新しい最大HPを超えない。
	session.player_hp = mini(session.player_hp, player_max_hp(session))
	return true


## 191 見学: ラウンドが進むと卵が割れて、星が1段高く戻る。
static func advance_eggs(session: GameSession) -> void:
	for item in session.relics:
		if int(item.get("id", -1)) != 191 or not item.has("egg"):
			continue
		var egg: Dictionary = item["egg"]
		egg["left"] = int(egg.get("left", 1)) - 1
		if int(egg["left"]) > 0:
			continue
		item.erase("egg")
		_queue_unit(session, int(egg.get("id", -1)), mini(int(egg.get("stars", 1)) + 1, GameUnit.MAX_STARS))


## 190 破壊: 選んだ味方（インスタンスID）。戦闘で使ったら消える。
static func take_destruction_targets(session: GameSession) -> Array[int]:
	var out: Array[int] = []
	for item in session.relics.duplicate():
		if int(item.get("id", -1)) != 190 or not item.has("copy_unit"):
			continue
		out.append(int(item["copy_unit"]))
		session.take_relic(int(item.get("uid", -1)))
	return out
