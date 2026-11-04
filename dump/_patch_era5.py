# -*- coding: utf-8 -*-
from pathlib import Path

ROOT = Path(r"C:\Users\njjjkr\src\dopa_autochess")
BD = ROOT / "src/scripts/game/battle_director.gd"
GAME = ROOT / "src/scripts/game.gd"
GS = ROOT / "src/scripts/game/game_session.gd"

bd = BD.read_text(encoding="utf-8")
game = GAME.read_text(encoding="utf-8")
gs = GS.read_text(encoding="utf-8")


def once(src, old, new, label):
    if old not in src:
        raise SystemExit(f"MISSING [{label}]: {old[:120]!r}")
    if src.count(old) != 1:
        raise SystemExit(f"AMBIGUOUS [{label}]: {src.count(old)}")
    return src.replace(old, new, 1)


# buff target
bd = once(
    bd,
    '''\t\t"lowest_speed_speed":
\t\t\treturn _extreme(_side(actor.enemy), "speed", false)
''',
    '''\t\t"lowest_speed_speed", "lowest_speed_absorb":
\t\t\treturn _extreme(_side(actor.enemy), "speed", false)
\t\t"self_crit_rate":
\t\t\treturn actor
\t\t"highest_threat_taken_cut":
\t\t\treturn _extreme(_side(actor.enemy), "threat", true)
\t\t"highest_thunder_thunder":
\t\t\tvar th_pool: Array = []
\t\t\tfor entry in _side(actor.enemy):
\t\t\t\tvar ally: Fighter = entry
\t\t\t\tif ally.alive and ally.hp > 0 and ally.element == "thunder":
\t\t\t\t\tth_pool.append(ally)
\t\t\tif th_pool.is_empty():
\t\t\t\treturn actor
\t\t\treturn _extreme(th_pool, "attack", true)
\t\t"highest_water_water":
\t\t\tvar w_pool: Array = []
\t\t\tfor entry in _side(actor.enemy):
\t\t\t\tvar ally_w: Fighter = entry
\t\t\t\tif ally_w.alive and ally_w.hp > 0 and ally_w.element == "water":
\t\t\t\t\tw_pool.append(ally_w)
\t\t\tif w_pool.is_empty():
\t\t\t\treturn actor
\t\t\treturn _extreme(w_pool, "attack", true)
\t\t"highest_hp_wind_resist":
\t\t\treturn _extreme(_opponents(actor), "hp", true)
''',
    "buff_target",
)

bd = once(
    bd,
    '''\t\t"most_earth_dot_vuln":
\t\t\ttarget.kit["received_dot_taken"] = float(target.kit.get("received_dot_taken", 0.0)) + amount
\t\t"lowest_hp_dot_cut":
''',
    '''\t\t"most_earth_dot_vuln":
\t\t\ttarget.kit["received_dot_taken"] = float(target.kit.get("received_dot_taken", 0.0)) + amount
\t\t"lowest_speed_absorb":
\t\t\ttarget.kit["received_absorb"] = float(target.kit.get("received_absorb", 0.0)) + amount
\t\t"self_crit_rate":
\t\t\ttarget.crit_rate += amount / 100.0 if amount > 1.0 else amount
\t\t\t# buff_amount for 64 is flat points (10), stored as int via bind false -> need /100
\t\t"highest_threat_taken_cut":
\t\t\ttarget.kit["received_taken_cut"] = float(target.kit.get("received_taken_cut", 0.0)) + amount
\t\t"highest_thunder_thunder":
\t\t\ttarget.kit["received_thunder"] = float(target.kit.get("received_thunder", 0.0)) + amount
\t\t"highest_water_water":
\t\t\ttarget.kit["received_water"] = float(target.kit.get("received_water", 0.0)) + amount
\t\t"highest_hp_wind_resist":
\t\t\ttarget.kit["received_wind_resist"] = float(target.kit.get("received_wind_resist", 0.0)) - amount
\t\t"attr_resist_cut":
\t\t\ttarget.attribute_resist -= amount
\t\t"lowest_hp_dot_cut":
''',
    "apply",
)

# Fix self_crit_rate - buff_amount is int 10 meaning +10 percentage points = 0.10
# bind is false so buff_amount is 10.0 as float from sheet int. Apply should be amount/100.
bd = once(
    bd,
    '''\t\t"self_crit_rate":
\t\t\ttarget.crit_rate += amount / 100.0 if amount > 1.0 else amount
\t\t\t# buff_amount for 64 is flat points (10), stored as int via bind false -> need /100
''',
    '''\t\t"self_crit_rate":
\t\t\ttarget.crit_rate += amount / 100.0
''',
    "crit_fix",
)

bd = once(
    bd,
    '''\t\t"most_earth_dot_vuln":
\t\t\treturn "継続ダメージ %+d%%" % int(round(amount * 100.0))
\t\t"lowest_hp_dot_cut":
''',
    '''\t\t"most_earth_dot_vuln":
\t\t\treturn "継続ダメージ %+d%%" % int(round(amount * 100.0))
\t\t"lowest_speed_absorb":
\t\t\treturn "吸収与ダメージ %+d%%" % int(round(amount * 100.0))
\t\t"self_crit_rate":
\t\t\treturn "クリティカル率 %+d" % int(round(amount))
\t\t"highest_threat_taken_cut":
\t\t\treturn "受けるダメージ %+d%%" % int(round(-amount * 100.0))
\t\t"highest_thunder_thunder":
\t\t\treturn "雷与ダメージ %+d%%" % int(round(amount * 100.0))
\t\t"highest_water_water":
\t\t\treturn "水与ダメージ %+d%%" % int(round(amount * 100.0))
\t\t"highest_hp_wind_resist":
\t\t\treturn "風耐性 %+d%%" % int(round(-amount * 100.0))
\t\t"attr_resist_cut":
\t\t\treturn "属性耐性 %+d%%" % int(round(-amount * 100.0))
\t\t"lowest_hp_dot_cut":
''',
    "describe",
)

# roll_damage: nagano no crit when targeted; nada ice crit damage; nabari first cut
bd = once(
    bd,
    '''\tvar can_crit := allow_crit and not bool(attacker.kit.get("attack_no_crit", false))
\tvar crit_rate := attacker.crit_rate + RelicCombat.aura_crit(attacker, _fighters, board)
''',
    '''\tvar can_crit := allow_crit and not bool(attacker.kit.get("attack_no_crit", false))
\tif bool(defender.kit.get("block_incoming_crit", false)):
\t\tcan_crit = false
\tvar crit_rate := attacker.crit_rate + RelicCombat.aura_crit(attacker, _fighters, board)
\tcrit_rate += float(attacker.kit.get("nada_gauge_crit", 0.0)) / 100.0
\tif bool(attacker.kit.get("nawate_aoe_crit", false)):
\t\tcrit_rate += float(attacker.kit.get("aoe_crit", 0.0)) / 100.0
''',
    "roll_crit",
)

bd = once(
    bd,
    '''\tvar crit_damage := attacker.crit_damage + float(attacker.kit.get("front_crit_damage_active", 0.0)) / 100.0
\tif force_crit:
\t\tcrit_damage += float(attacker.kit.get("forced_crit_damage_bonus", 0.0)) / 100.0
''',
    '''\tvar crit_damage := attacker.crit_damage + float(attacker.kit.get("front_crit_damage_active", 0.0)) / 100.0
\tif force_crit:
\t\tcrit_damage += float(attacker.kit.get("forced_crit_damage_bonus", 0.0)) / 100.0
\tif crit and attacker.element == "ice" and attacker.sheet_id == 64:
\t\tcrit_damage += float(attacker.kit.get("ice_crit_damage", 200.0)) / 100.0
''',
    "ice_crit",
)

# penetration from nagano
bd = once(
    bd,
    '''\tvar penetration := attacker.penetration
\tif use_general_bonus:
\t\tpenetration += RelicCombat.attack_penetration(attacker)
\t\tpenetration += RelicCombat.aura_pen(attacker, _fighters, board)
\tpenetration = clampf(penetration, 0.0, 1.0)
''',
    '''\tvar penetration := attacker.penetration + float(attacker.kit.get("nagano_pen", 0.0))
\tif use_general_bonus:
\t\tpenetration += RelicCombat.attack_penetration(attacker)
\t\tpenetration += RelicCombat.aura_pen(attacker, _fighters, board)
\tpenetration = clampf(penetration, 0.0, 1.0)
''',
    "pen",
)

# taken cut nabari first
bd = once(
    bd,
    '''\t\ttaken_cut += float(defender.kit.get("received_taken_cut", 0.0))
\t\tamount *= maxf(0.0, 1.0 - taken_cut)
''',
    '''\t\ttaken_cut += float(defender.kit.get("received_taken_cut", 0.0))
\t\ttaken_cut += float(defender.kit.get("nabari_first_cut", 0.0))
\t\tamount *= maxf(0.0, 1.0 - taken_cut)
''',
    "taken",
)

# kit bonus ice nabari + thunder death taken + nose wind
bd = once(
    bd,
    '''\tif attacker.element == "ice":
\t\tbonus += float(attacker.kit.get("received_ice", 0.0))
''',
    '''\tif attacker.element == "ice":
\t\tbonus += float(attacker.kit.get("received_ice", 0.0))
\t\tbonus += float(attacker.kit.get("nabari_ice_empower", 0.0))
\tif attacker.element == "thunder":
\t\tbonus += float(defender.kit.get("naura_thunder_taken", 0.0))
\tif attacker.element == "wind":
\t\tbonus += float(defender.kit.get("nose_wind_taken", 0.0))
\tif attacker.sheet_id == 68 and bool(attacker.kit.get("nishimino_second", false)):
\t\tbonus += float(attacker.kit.get("nishimino_second_bonus", 0.0))
''',
    "kit_bonus",
)

# bind flags
bd = once(
    bd,
    '''\t\tif fighter.sheet_id == 61:
\t\t\tfighter.kit["gauge"] = clampi(int(flags.get("torahime_gauge", int(fighter.kit.get("gauge", 0)))), 0, 100)
\t\t\tfighter.kit["extra_earth_armed"] = bool(flags.get("extra_earth_armed", false))
\t_recompute_speed(fighter, true)
''',
    '''\t\tif fighter.sheet_id == 61:
\t\t\tfighter.kit["gauge"] = clampi(int(flags.get("torahime_gauge", int(fighter.kit.get("gauge", 0)))), 0, 100)
\t\t\tfighter.kit["extra_earth_armed"] = bool(flags.get("extra_earth_armed", false))
\t\tif fighter.sheet_id == 62:
\t\t\tfighter.kit["block_incoming_crit"] = true
\t\t\tfighter.kit["nagano_force_hit_armed"] = false
\t\tif fighter.sheet_id in [63, 64, 65, 68]:
\t\t\tfighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
\t\t\tif fighter.sheet_id == 64:
\t\t\t\tfighter.kit["gauge"] = clampi(int(flags.get("nada_gauge", int(fighter.kit.get("gauge", 0)))), 0, 100)
\t\t\t\tfighter.kit["nada_gauge_crit"] = float(flags.get("nada_gauge_crit", 0.0))
\t\t\t\tfighter.kit["nada_first_fill"] = not bool(flags.get("nada_filled_once", false))
\t\tif fighter.sheet_id == 67:
\t\t\tfighter.kit["aoe_charges_left"] = int(fighter.kit.get("aoe_charges", 1))
\t\tif fighter.sheet_id == 68:
\t\t\tfighter.kit["nishimino_double_armed"] = bool(flags.get("nishimino_double_armed", false))
\t\t\tfighter.kit["nishimino_second_bonus"] = float(flags.get("nishimino_second_bonus", 0.0))
\t\tif fighter.sheet_id == 69:
\t\t\tfighter.kit["mark_moves_left"] = int(fighter.kit.get("mark_moves", 1))
\t\t\tfighter.kit["nose_mark_id"] = -1
\t_recompute_speed(fighter, true)
''',
    "bind",
)

# note primary / targeted - nagano, nabari
bd = once(
    bd,
    '''func _note_primary_target_effects(actor: Fighter, target: Fighter) -> void:
\t_taishi_on_targeted(actor, target)
''',
    '''func _note_primary_target_effects(actor: Fighter, target: Fighter) -> void:
\t_taishi_on_targeted(actor, target)
\t_era5_on_targeted(actor, target)
''',
    "note_primary",
)

# pick target nabari taunt + nose mark
bd = once(
    bd,
    '''\tif actor.sheet_id == 61 and int(actor.kit.get("lock_left", 0)) > 0:
\t\tvar locked := _fighter_by_id(int(actor.kit.get("lock_target_id", -1)))
\t\tif locked != null and locked.alive and locked.hp > 0 and locked.enemy != actor.enemy:
\t\t\treturn locked
\tif actor.sheet_id == 32 and bool(actor.kit.get("started_front", false)):
''',
    '''\tif actor.sheet_id == 61 and int(actor.kit.get("lock_left", 0)) > 0:
\t\tvar locked := _fighter_by_id(int(actor.kit.get("lock_target_id", -1)))
\t\tif locked != null and locked.alive and locked.hp > 0 and locked.enemy != actor.enemy:
\t\t\treturn locked
\tif actor.sheet_id == 69 and int(actor.kit.get("nose_mark_id", -1)) > 0 and actor.element == "wind":
\t\tvar marked_nose := _fighter_by_id(int(actor.kit.get("nose_mark_id", -1)))
\t\tif marked_nose != null and marked_nose.alive and marked_nose.hp > 0 and marked_nose.enemy != actor.enemy:
\t\t\treturn marked_nose
\tvar nabari := _nabari_taunt_target(actor)
\tif nabari != null:
\t\treturn nabari
\tif actor.sheet_id == 32 and bool(actor.kit.get("started_front", false)):
''',
    "pick",
)

# force hit nagano
bd = once(
    bd,
    '''\tif actor.sheet_id == 47 and actor.element == "thunder" and int(actor.kit.get("force_hit_left", 0)) > 0:
\t\tforced = true
\t\tactor.kit["force_hit_left"] = int(actor.kit.get("force_hit_left", 0)) - 1
''',
    '''\tif actor.sheet_id == 47 and actor.element == "thunder" and int(actor.kit.get("force_hit_left", 0)) > 0:
\t\tforced = true
\t\tactor.kit["force_hit_left"] = int(actor.kit.get("force_hit_left", 0)) - 1
\tif actor.sheet_id == 62 and bool(actor.kit.get("nagano_force_hit_armed", false)):
\t\tforced = true
\t\tactor.kit["nagano_force_hit_armed"] = false
''',
    "force_hit",
)

# attack packets nawate full aoe
bd = once(
    bd,
    '''\telif actor.sheet_id == 51 and actor.element == "ice" and bool(actor.kit.get("extra_ice_armed", false)):
\t\tactor.kit["extra_ice_armed"] = false
\t\tvar need51 := maxi(1, int(actor.kit.get("extra_targets", 1)))
\t\tvar picks51 := _takatsuki_extra_targets(actor, primary, need51)
\t\tif not picks51.is_empty():
\t\t\tsplash = true
\t\t\textras = picks51
\textras = _era2_attack_extras(actor, primary, extras)
''',
    '''\telif actor.sheet_id == 51 and actor.element == "ice" and bool(actor.kit.get("extra_ice_armed", false)):
\t\tactor.kit["extra_ice_armed"] = false
\t\tvar need51 := maxi(1, int(actor.kit.get("extra_targets", 1)))
\t\tvar picks51 := _takatsuki_extra_targets(actor, primary, need51)
\t\tif not picks51.is_empty():
\t\t\tsplash = true
\t\t\textras = picks51
\telif actor.sheet_id == 67 and actor.element == "wind" and bool(actor.kit.get("nawate_full_aoe", false)):
\t\tactor.kit["nawate_full_aoe"] = false
\t\tactor.kit["nawate_aoe_crit"] = true
\t\tsplash = true
\t\textras = []
\t\tfor entry in _opponents(actor):
\t\t\tvar foe: Fighter = entry
\t\t\tif foe != primary and foe.alive:
\t\t\t\textras.append(foe)
\telif actor.sheet_id == 67 and actor.element == "wind" and _noukyo_splash_count(actor) > 1:
\t\tsplash = true
\t\textras = _goshodan_extras(actor, primary, _noukyo_splash_count(actor) - 1)
\textras = _era2_attack_extras(actor, primary, extras)
''',
    "packets",
)

# after break for nawate
bd = once(
    bd,
    '''\tif direct:
\t\tbroke = _reduce_break_gauge(actor, target)
\t\t_era4_note_break(actor, target, broke)
''',
    '''\tif direct:
\t\tbroke = _reduce_break_gauge(actor, target)
\t\t_era4_note_break(actor, target, broke)
\t\tif broke and actor.sheet_id == 67 and actor.element == "wind" and int(actor.kit.get("aoe_charges_left", 0)) > 0:
\t\t\tactor.kit["nawate_full_aoe"] = true
\t\t\tactor.kit["aoe_charges_left"] = int(actor.kit.get("aoe_charges_left", 0)) - 1
''',
    "nawate_break",
)

# kits after turn era5 gauges
bd = once(
    bd,
    '''\t_era3_on_ally_action(actor, was_buff)
\tawait _era2_after_turn(actor, was_buff)
''',
    '''\t_era3_on_ally_action(actor, was_buff)
\t_era5_on_ally_action(actor, was_buff)
\tawait _era2_after_turn(actor, was_buff)
''',
    "kits_after",
)

# support nose remember - when buff applied to foe side... our buffs are allies. Enemy buffs: when enemy buffs ally, nose remembers the buffed enemy.
bd = once(
    bd,
    '''\t\t\t\t_set_single_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
\t\t\t\tif actor.sheet_id == 11:
\t\t\t\t\tactor.kit["front_buff_active"] = true
\t\t\t\t_refresh_unit_aura(ally.unit)
\t\t\t\tally.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
\t\t\t\t_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
\t\t\t\tawait _note_arita_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
''',
    '''\t\t\t\t_set_single_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
\t\t\t\tif actor.sheet_id == 11:
\t\t\t\t\tactor.kit["front_buff_active"] = true
\t\t\t\t_refresh_unit_aura(ally.unit)
\t\t\t\tally.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
\t\t\t\t_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
\t\t\t\t_nose_note_enemy_buff(actor, ally)
\t\t\t\tawait _note_arita_buff(actor, ally, kind, float(actor.kit.get("buff_amount", 0.0)))
''',
    "nose_buff",
)

# also front-style buffs
bd = once(
    bd,
    '''\t\t\t_set_single_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
\t\t\tactor.kit["front_buff_active"] = true
\t\t\t_refresh_unit_aura(ally_front.unit)
\t\t\tally_front.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
\t\t\t_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally_front.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
\t\t\tawait _note_arita_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
''',
    '''\t\t\t_set_single_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
\t\t\tactor.kit["front_buff_active"] = true
\t\t\t_refresh_unit_aura(ally_front.unit)
\t\t\tally_front.unit.popup_battle_text("バフ", Color(0.55, 0.95, 0.62))
\t\t\t_host._log("%s が %s にバフ（%s）" % [actor.unit.get_display_name(), ally_front.unit.get_display_name(), _describe_effect(kind, float(actor.kit.get("buff_amount", 0.0)))])
\t\t\t_nose_note_enemy_buff(actor, ally_front)
\t\t\tawait _note_arita_buff(actor, ally_front, kind, float(actor.kit.get("buff_amount", 0.0)))
''',
    "nose_buff2",
)

# debuff target nose marked
bd = once(
    bd,
    '''\tif actor.sheet_id == 49:
\t\tvar hitter49 := _fighter_by_id(int(actor.kit.get("last_hitter_id", -1)))
\t\tif hitter49 != null and hitter49.alive and hitter49.hp > 0 and hitter49.enemy != actor.enemy:
\t\t\treturn hitter49
\t\treturn _extreme(_opponents(actor), "threat", true)
''',
    '''\tif actor.sheet_id == 49:
\t\tvar hitter49 := _fighter_by_id(int(actor.kit.get("last_hitter_id", -1)))
\t\tif hitter49 != null and hitter49.alive and hitter49.hp > 0 and hitter49.enemy != actor.enemy:
\t\t\treturn hitter49
\t\treturn _extreme(_opponents(actor), "threat", true)
\tif actor.sheet_id == 62:
\t\tvar last62 := _fighter_by_id(int(actor.kit.get("last_attack_target_id", -1)))
\t\tif last62 != null and last62.alive and last62.hp > 0 and last62.enemy != actor.enemy:
\t\t\treturn last62
\t\treturn _extreme(_opponents(actor), "threat", true)
\tif actor.sheet_id == 69:
\t\tvar marked69 := _fighter_by_id(int(actor.kit.get("nose_mark_id", -1)))
\t\tif marked69 != null and marked69.alive and marked69.hp > 0 and marked69.enemy != actor.enemy:
\t\t\treturn marked69
\t\treturn _extreme(_opponents(actor), "threat", true)
''',
    "debuff_target",
)

# threat nose priority cut when marked
bd = once(
    bd,
    '''\tif fighter.sheet_id == 49 and fighter.hp >= fighter.max_hp and fighter.hp > 0:
\t\tvalue += int(fighter.kit.get("full_priority", 0))
''',
    '''\tif fighter.sheet_id == 49 and fighter.hp >= fighter.max_hp and fighter.hp > 0:
\t\tvalue += int(fighter.kit.get("full_priority", 0))
\tif fighter.sheet_id == 69 and int(fighter.kit.get("nose_mark_id", -1)) > 0 and fighter.hp > 0:
\t\tvalue -= int(fighter.kit.get("priority_cut", 0))
''',
    "threat",
)

# after attack resolve for era5
bd = once(
    bd,
    '''\t\t_era3_on_crit(actor)
\tactor.kit["tarumi_aoe_resolving"] = false
''',
    '''\t\t_era3_on_crit(actor)
\t\t_era5_after_packet(actor, target, direct)
\tactor.kit["tarumi_aoe_resolving"] = false
\tactor.kit["nawate_aoe_crit"] = false
''',
    "after_packet",
)

# ko death naura
bd = once(
    bd,
    '''func _era2_on_death(dead: Fighter) -> void:
''',
    '''func _era2_on_death(dead: Fighter) -> void:
\t_naura_on_death(dead)
''',
    "death",
)

# opening / start
bd = once(
    bd,
    '''\t_era4_battle_start_sync()
''',
    '''\t_era4_battle_start_sync()
\t_era5_battle_start_sync()
''',
    "start",
)

# damage dealt for kills / absorb layers / nose
bd = once(
    bd,
    '''\t_era4_on_damage_dealt(actor, target, dealt)
''',
    '''\t_era4_on_damage_dealt(actor, target, dealt)
\t_era5_on_damage_dealt(actor, target, dealt)
''',
    "dmg",
)

# XP for nabari - extend toba function or separate
if "nabari_round_xp" not in gs:
    gs = once(
        gs,
        "var toba_round_xp: int = 0\n",
        "var toba_round_xp: int = 0\nvar nabari_round_xp: int = 0\n",
        "gs_field",
    )
    gs = once(
        gs,
        "\tgain_experience(ROUND_END_FREE_XP + relic_end_xp + toba_round_xp)\n\trelic_end_xp = 0\n\ttoba_round_xp = 0\n",
        "\tgain_experience(ROUND_END_FREE_XP + relic_end_xp + toba_round_xp + nabari_round_xp)\n\trelic_end_xp = 0\n\ttoba_round_xp = 0\n\tnabari_round_xp = 0\n",
        "gs_xp",
    )

if "_nabari_round_xp_bonus" not in game:
    game = once(
        game,
        "\tsession.toba_round_xp = _toba_round_xp_bonus()\n",
        "\tsession.toba_round_xp = _toba_round_xp_bonus()\n\tsession.nabari_round_xp = _nabari_round_xp_bonus()\n",
        "game_xp",
    )
    game = once(
        game,
        "func _toba_round_xp_bonus() -> int:\n",
        '''func _nabari_round_xp_bonus() -> int:
	var best: GameUnit = null
	for unit in board.get_circle_units():
		if unit == null or unit.unit_id != 66 or unit.is_enemy:
			continue
		if best == null or unit.stars > best.stars or (unit.stars == best.stars and unit.unit_id < best.unit_id):
			best = unit
	if best == null:
		return 0
	var sheet := CharacterSheet.make(best.unit_id, best.stars)
	return maxi(1, int(sheet.get("round_xp", 1)))


func _toba_round_xp_bonus() -> int:
''',
        "game_fn",
    )

APPEND = r'''

func _era5_battle_start_sync() -> void:
	for key in _fighters.keys():
		var fighter: Fighter = _fighters[key]
		if fighter.sheet_id == 63:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 65:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 68:
			fighter.kit["gauge"] = clampi(int(fighter.kit.get("gauge", 0)), 0, 100)
			_show_gauge(fighter)
		if fighter.sheet_id == 64:
			_show_gauge(fighter)


func _era5_on_targeted(actor: Fighter, target: Fighter) -> void:
	if target == null or actor == null or actor.enemy == target.enemy:
		return
	if target.sheet_id == 62 and target.alive and target.hp > 0:
		var pen := float(target.kit.get("pen_per_hit", 0.1))
		target.kit["nagano_pen"] = minf(1.0, float(target.kit.get("nagano_pen", 0.0)) + pen)
		_cut_ap(target, maxi(1, int(target.kit.get("ap_cut", 40))))
		target.kit["nagano_force_hit_armed"] = true
		target.kit["block_incoming_crit"] = true
	if target.sheet_id == 66 and target.alive and target.hp > 0:
		if not bool(actor.kit.get("nabari_first_done", false)):
			actor.kit["nabari_first_done"] = true
			target.kit["nabari_first_cut"] = float(target.kit.get("first_taken_cut", 0.3))
			if not bool(target.kit.get("nabari_ice_armed", false)):
				target.kit["nabari_ice_armed"] = true
				target.kit["nabari_ice_empower"] = float(target.kit.get("ice_empower", 0.2))
			if not bool(target.kit.get("nabari_ap_zero_used", false)) and target.hp > 0:
				target.kit["nabari_ap_zero_used"] = true
				target.ap = 0
				if is_instance_valid(target.unit):
					target.unit.action_value = 0
					target.unit.popup_battle_text("割込", Color(0.7, 0.9, 1.0))


func _nabari_taunt_target(actor: Fighter) -> Fighter:
	if actor == null:
		return null
	if bool(actor.kit.get("nabari_first_done", false)):
		return null
	var nabari := _best_sheet(not actor.enemy, 66)
	if nabari == null or nabari.hp <= 0:
		return null
	return nabari


func _era5_on_ally_action(actor: Fighter, was_buff: bool) -> void:
	# nagahama damage gauge handled on hit; kill gauge on damage
	var greek := _greek_gauge_step(actor.enemy)
	var pandora := _pandora_gauge_step(actor.enemy)
	for entry in _side(actor.enemy):
		var ally: Fighter = entry
		if not ally.alive or ally.hp <= 0:
			continue
		if ally.sheet_id == 65:
			var gain := greek
			if ally == actor:
				gain += pandora
			_naura_add_gauge(ally, gain, false)
		if ally.sheet_id == 68 and ally == actor and not _is_backline(ally):
			_nishimino_add_gauge(ally, pandora)
	if actor.sheet_id == 64 and bool(actor.kit.get("did_attack", false)):
		_nada_add_gauge(actor, _soar_bridge_gauge_step(actor.enemy), false)


func _nagahama_add_gauge(fighter: Fighter, amount: int) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	fighter.kit["nagahama_extra_layers"] = true
	_show_gauge(fighter)
	if is_instance_valid(fighter.unit):
		fighter.unit.popup_battle_text("多層", Color(0.75, 0.55, 1.0))
	_host._log("%s のゲージが満ち、次の吸収で層が多く付く" % fighter.unit.get_display_name())


func _nada_add_gauge(fighter: Fighter, amount: int, from_crit: bool) -> void:
	if fighter == null or amount <= 0:
		return
	# gauge persists even at 0 hp
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		if is_instance_valid(fighter.unit):
			fighter.unit.kit_flags["nada_gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	var add := float(fighter.kit.get("gauge_crit", 25.0))
	if bool(fighter.kit.get("nada_first_fill", true)):
		add *= 2.0
		fighter.kit["nada_first_fill"] = false
		if is_instance_valid(fighter.unit):
			fighter.unit.kit_flags["nada_filled_once"] = true
	var base := fighter.crit_rate * 100.0
	var now := float(fighter.kit.get("nada_gauge_crit", 0.0))
	var room := maxf(0.0, 100.0 - base - now)
	fighter.kit["nada_gauge_crit"] = now + minf(add, room)
	if is_instance_valid(fighter.unit):
		fighter.unit.kit_flags["nada_gauge"] = 0
		fighter.unit.kit_flags["nada_gauge_crit"] = float(fighter.kit.get("nada_gauge_crit", 0.0))
		fighter.unit.popup_battle_text("会心+", Color(1.0, 0.85, 0.4))
	_show_gauge(fighter)
	_host._log("%s のゲージが満ち、クリティカル率が上がった" % fighter.unit.get_display_name())


func _naura_add_gauge(fighter: Fighter, amount: int, after_crit: bool) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	_show_gauge(fighter)
	_naura_break_reduce(fighter, maxi(1, int(fighter.kit.get("break_extra", 2))), true)
	if is_instance_valid(fighter.unit):
		fighter.unit.popup_battle_text("撃破-", Color(0.9, 0.85, 0.4))


func _naura_break_reduce(naura: Fighter, times: int, prefer_last: bool) -> void:
	var target: Fighter = null
	if prefer_last:
		target = _fighter_by_id(int(naura.kit.get("last_attack_target_id", -1)))
	if target == null or not target.alive or target.hp <= 0 or target.enemy == naura.enemy:
		target = _extreme(_opponents(naura), "threat", true)
	if target == null:
		return
	for _i in times:
		var left_b := int(target.break_left.get("thunder", BREAK_MAX))
		if left_b <= 0:
			break
		target.break_left["thunder"] = maxi(0, left_b - BREAK_STEP)
		if int(target.break_left["thunder"]) <= 0:
			target.break_left["thunder"] = BREAK_MAX


func _naura_on_death(dead: Fighter) -> void:
	if dead == null or dead.sheet_id != 65:
		return
	var times := maxi(1, int(dead.kit.get("death_break", 2)))
	var taken := float(dead.kit.get("death_thunder_taken", 0.15))
	for entry in _opponents(dead):
		var foe: Fighter = entry
		if _is_backline(foe) or not foe.alive or foe.hp <= 0:
			continue
		for _i in times:
			var left_b := int(foe.break_left.get("thunder", BREAK_MAX))
			if left_b <= 0:
				break
			foe.break_left["thunder"] = maxi(0, left_b - BREAK_STEP)
			if int(foe.break_left["thunder"]) <= 0:
				foe.break_left["thunder"] = BREAK_MAX
		var prev := float(foe.kit.get("naura_thunder_taken", 0.0))
		if taken >= prev:
			foe.kit["naura_thunder_taken"] = taken
			foe.kit["naura_thunder_taken_once"] = true


func _nishimino_add_gauge(fighter: Fighter, amount: int) -> void:
	if fighter == null or not fighter.alive or fighter.hp <= 0 or amount <= 0:
		return
	var gauge := int(fighter.kit.get("gauge", 0)) + amount
	GameAudio.play_battle_gauge()
	if gauge < 100:
		fighter.kit["gauge"] = gauge
		_show_gauge(fighter)
		return
	fighter.kit["gauge"] = 0
	var bonus := float(fighter.kit.get("second_base", 0.4))
	var relics := 0
	if _host != null and _host.session != null:
		relics = mini(maxi(1, int(fighter.kit.get("relic_cap", 2))), _host.session.relics.size())
	bonus += float(fighter.kit.get("relic_ratio", 0.15)) * float(relics)
	fighter.kit["nishimino_double_armed"] = true
	fighter.kit["nishimino_second_bonus"] = bonus
	if is_instance_valid(fighter.unit):
		fighter.unit.kit_flags["nishimino_double_armed"] = true
		fighter.unit.kit_flags["nishimino_second_bonus"] = bonus
		fighter.unit.popup_battle_text("二連", Color(0.45, 0.75, 1.0))
	_show_gauge(fighter)


func _noukyo_splash_count(actor: Fighter) -> int:
	if not _has_synergy(actor, "農協月へ行く") and actor.sheet_id != 67:
		return 1
	var count := _synergy_member_count(actor.enemy, "農協月へ行く")
	if count >= 6:
		return 3
	if count >= 2:
		return 2
	return 1


func _nose_note_enemy_buff(buffer: Fighter, target: Fighter) -> void:
	if buffer == null or target == null or buffer == target:
		return
	# enemy team buffs their ally: nose on opposing side remembers target
	for entry in _side(not buffer.enemy):
		var nose: Fighter = entry
		if nose.sheet_id != 69 or not nose.alive or nose.hp <= 0:
			continue
		if int(nose.kit.get("mark_moves_left", 0)) <= 0:
			continue
		nose.kit["nose_mark_id"] = target.unit.get_instance_id() if is_instance_valid(target.unit) else -1
		_host._log("%s が %s を覚えた" % [nose.unit.get_display_name(), target.unit.get_display_name()])


func _era5_after_packet(actor: Fighter, target: Fighter, direct: bool) -> void:
	if actor == null or target == null:
		return
	if actor.sheet_id == 63 and actor.element == "absorb" and bool(actor.kit.get("nagahama_extra_layers", false)) and direct:
		actor.kit["nagahama_extra_layers"] = false
		var extra := maxi(1, int(actor.kit.get("extra_layers", 1)))
		_add_layers(target, "absorb", extra)
		# paprika base layer already via continuity; side target highest hp front
		var side: Fighter = null
		var best_hp := -1
		for entry in _opponents(actor):
			var foe: Fighter = entry
			if foe == target or _is_backline(foe) or not foe.alive or foe.hp <= 0:
				continue
			if side == null or foe.hp > best_hp or (foe.hp == best_hp and foe.unit.unit_id < side.unit.unit_id):
				side = foe
				best_hp = foe.hp
		if side != null:
			_add_layers(side, "absorb", maxi(1, int(actor.kit.get("side_layers", 1))))
	if actor.sheet_id == 69 and actor.element == "wind" and direct:
		var mid := int(actor.kit.get("nose_mark_id", -1))
		if mid > 0 and is_instance_valid(target.unit) and target.unit.get_instance_id() == mid:
			# only clear on actual damage - checked in damage dealt
			pass
	if actor.sheet_id == 68 and actor.element == "water" and direct and bool(actor.kit.get("nishimino_double_armed", false)):
		actor.kit["nishimino_pending_second"] = true


func _era5_on_damage_dealt(actor: Fighter, target: Fighter, dealt: int) -> void:
	if actor == null:
		return
	if actor.sheet_id == 63 and dealt > 0 and target != null and not target.alive:
		_nagahama_add_gauge(actor, _bistron_gauge_step(actor.enemy))
	if target != null and target.sheet_id == 63 and dealt > 0 and target.alive:
		_nagahama_add_gauge(target, _oscillator_gauge_step(target.enemy))
	if actor.sheet_id == 64:
		if dealt > 0 and target != null and not target.alive:
			_nada_add_gauge(actor, _bistron_gauge_step(actor.enemy), false)
		if dealt > 0 and bool(actor.kit.get("last_roll_crit", false)):
			_nada_add_gauge(actor, maxi(1, int(actor.kit.get("crit_gauge", 10))), true)
	if actor.sheet_id == 65 and dealt > 0 and bool(actor.kit.get("last_roll_crit", false)) and actor.element == "thunder":
		_naura_add_gauge(actor, maxi(1, int(actor.kit.get("crit_gauge", 6))), true)
	if dealt > 0 and target != null and bool(target.kit.get("naura_thunder_taken_once", false)) and actor.element == "thunder":
		target.kit["naura_thunder_taken"] = 0.0
		target.kit["naura_thunder_taken_once"] = false
	if actor.sheet_id == 69 and actor.element == "wind" and dealt > 0:
		var mid := int(actor.kit.get("nose_mark_id", -1))
		if mid > 0 and is_instance_valid(target.unit) and target.unit.get_instance_id() == mid:
			actor.kit["nose_mark_id"] = -1
			actor.kit["mark_moves_left"] = maxi(0, int(actor.kit.get("mark_moves_left", 0)) - 1)
			if not bool(target.kit.get("nose_wind_marked", false)):
				target.kit["nose_wind_marked"] = true
				target.kit["nose_wind_taken"] = float(actor.kit.get("wind_taken", 0.15))
	if actor.sheet_id == 66 and bool(actor.kit.get("nabari_first_cut_clear", false)):
		pass
	# clear nabari first cut after the redirected first attack resolves damage path via attacker flag
	if bool(actor.kit.get("nabari_first_done", false)) and float(target.kit.get("nabari_first_cut", 0.0)) > 0.0 if target != null else false:
		if target.sheet_id == 66:
			target.kit["nabari_first_cut"] = 0.0


func _era5_finish_attack(actor: Fighter, primary: Fighter) -> void:
	if actor == null or actor.sheet_id != 68:
		return
	if not bool(actor.kit.get("nishimino_pending_second", false)):
		return
	actor.kit["nishimino_pending_second"] = false
	actor.kit["nishimino_double_armed"] = false
	if is_instance_valid(actor.unit):
		actor.unit.kit_flags["nishimino_double_armed"] = false
	var foe := _extreme(_opponents(actor), "hp", true)
	if foe == null:
		return
	actor.kit["nishimino_second"] = true
	await _resolve_packet(actor, foe, true, false, false)
	actor.kit["nishimino_second"] = false
'''

if "func _era5_battle_start_sync" not in bd:
    bd = bd.rstrip() + "\n" + APPEND + "\n"

# Hook nishimino second after attack packets
bd = once(
    bd,
    '''\tif actor.sheet_id == 61 and float(actor.kit.get("torahime_pending_earth", 0.0)) > 0.0 and not bool(actor.kit.get("extra_earth_armed", false)):
\t\tactor.kit["torahime_pending_earth"] = 0.0
\tif ikeda_armed:
''',
    '''\tif actor.sheet_id == 61 and float(actor.kit.get("torahime_pending_earth", 0.0)) > 0.0 and not bool(actor.kit.get("extra_earth_armed", false)):
\t\tactor.kit["torahime_pending_earth"] = 0.0
\tawait _era5_finish_attack(actor, primary)
\tif ikeda_armed:
''',
    "finish_atk",
)

# Fix after_packet - `target` and `direct` may not be in scope after the for loop.
# Need to fix that replacement - it was inside the for loop incorrectly.
# Read what happened.

BD.write_text(bd, encoding="utf-8")
GAME.write_text(game, encoding="utf-8")
GS.write_text(gs, encoding="utf-8")
print("wrote; verifying after_packet hook")
bd2 = BD.read_text(encoding="utf-8")
idx = bd2.find("_era5_after_packet")
print(repr(bd2[idx-200:idx+200]) if idx>=0 else "NOT FOUND")
