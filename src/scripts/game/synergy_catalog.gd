class_name SynergyCatalog
extends RefCounted

const TIERS: Array[int] = [2, 4, 6, 8, 10]

const SYNERGIES: Array[Dictionary] = [
	{"id": 0, "name": "赤", "desc": "攻撃・爆発"},
	{"id": 1, "name": "青", "desc": "妨害・凍結"},
	{"id": 2, "name": "緑", "desc": "回復・成長"},
	{"id": 3, "name": "黄", "desc": "攻撃速度・連撃"},
	{"id": 4, "name": "紫", "desc": "変異・ランダム"},
	{"id": 5, "name": "白", "desc": "シールド・復活"},
	{"id": 6, "name": "黒", "desc": "暗殺・吸収"},
	{"id": 7, "name": "灰", "desc": "機械・召喚"},
]


static func get_synergy(synergy_id: int) -> Dictionary:
	for synergy in SYNERGIES:
		if synergy["id"] == synergy_id:
			return synergy
	return {}


static func get_synergy_name(synergy_id: int) -> String:
	var data := get_synergy(synergy_id)
	if data.is_empty():
		return "?"
	return data["name"]


static func get_active_tier(count: int) -> int:
	var tier := 0
	for index in TIERS.size():
		if count >= TIERS[index]:
			tier = index + 1
	return tier
