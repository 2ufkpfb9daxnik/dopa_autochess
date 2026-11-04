class_name PlayDemo
extends RefCounted

## タイトル無操作デモ用。盤面・ベンチ・レリックをランダムにそれっぽく組む。

const DEMO_META := &"play_demo"
const IDLE_SECONDS := 60.0
const DEMO_LEVEL_MIN := 11
const DEMO_LEVEL_MAX := 14
const BOARD_STAR_WEIGHTS := [1, 2, 2, 3, 3, 3, 4]
const BENCH_STAR_WEIGHTS := [1, 1, 1, 2, 2]
const MARQUEE_UNIT := "DEMO       "
const MARQUEE_SPEED := 56.0
const MARQUEE_META_OFFSET := &"marquee_offset"
const MARQUEE_META_CYCLE := &"marquee_cycle"


static func mark_pending(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.set_meta(DEMO_META, true)


static func consume_pending(tree: SceneTree) -> bool:
	if tree == null or not tree.has_meta(DEMO_META):
		return false
	var pending := bool(tree.get_meta(DEMO_META))
	tree.remove_meta(DEMO_META)
	return pending


static func seed_board(host: Node) -> void:
	if host == null:
		return
	_clear_allies(host)
	_clear_relics(host)
	var level := randi_range(DEMO_LEVEL_MIN, DEMO_LEVEL_MAX)
	host.session.experience = PlayerLevel.xp_to_reach(level)
	host.session.round_number = randi_range(8, 14)
	host.session.player_hp = RelicEconomy.player_max_hp(host.session)
	host.session.coins = randi_range(18, 48)
	host.session.selected_route = RouteChoice.for_stars(4)
	host.session.phase = GameSession.Phase.PREP
	host.session.run_end_reason = GameSession.RunEndReason.NONE
	host.board.board_unit_limit = host.session.get_board_unit_cap()
	host.board.set_unlocked_face_count(BoardController.unlocked_face_count_for_level(level))
	host.board.set_active_face(0)

	var pools := _synergy_pools()
	var focus := _pick_focus_synergies(pools, randi_range(2, 3))
	var board_cap: int = host.session.get_board_unit_cap()
	var board_count := clampi(board_cap - randi_range(0, 1), mini(6, board_cap), board_cap)
	var board_ids := _pick_board_ids(pools, focus, board_count)
	var board_specs := _make_specs(board_ids, BOARD_STAR_WEIGHTS)
	_sort_specs_for_formation(board_specs)
	_place_board(host, board_specs)

	var bench_count := randi_range(3, 6)
	var bench_ids := _pick_bench_ids(pools, focus, board_ids, bench_count)
	_place_bench(host, _make_specs(bench_ids, BENCH_STAR_WEIGHTS))
	_seed_relics(host)
	host.session.refresh_shop()
	host.session.state_changed.emit()
	if host.has_method("_update_ui"):
		host._update_ui()


static func spawn_enemies(host: Node) -> int:
	## プレイヤーに寄せつつ、少し長く耐えられるよう上振れさせる。
	var board: BoardController = host.board
	var units_root: Node3D = host.units_root
	var session: GameSession = host.session
	board.clear_enemy_units()
	var player_count := maxi(1, board.get_board_unit_count())
	var count := clampi(player_count + randi_range(0, 2), 1, BoardController.SLOTS_PER_FACE)
	var shop_level := clampi(RelicEconomy.shop_odds_level(session, false) + randi_range(1, 2), 1, ShopOdds.TABLE_LEVELS)
	var avg := board.get_board_star_average()
	var base := clampi(int(round(avg)) + 1, 2, GameUnit.MAX_STARS)
	var lo := clampi(base, 1, GameUnit.MAX_STARS)
	var hi := clampi(base + randi_range(0, 1), lo, GameUnit.MAX_STARS)
	for slot_index in count:
		var unit_id := UnitCatalog.random_unit_id_for_level(shop_level)
		var stars := randi_range(lo, hi)
		var unit := GameUnit.create(unit_id, stars)
		unit.is_enemy = true
		units_root.add_child(unit)
		board.place_enemy_unit(unit, slot_index)
	return count


static func make_overlay(on_exit: Callable) -> Control:
	var root := Control.new()
	root.name = "PlayDemoOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 120
	root.set_meta(&"on_exit", on_exit)
	root.set_meta(MARQUEE_META_OFFSET, 0.0)
	root.set_meta(MARQUEE_META_CYCLE, 1.0)
	root.gui_input.connect(func(event: InputEvent) -> void:
		if _is_exit_event(event):
			_request_exit(root)
	)
	var marquee := Control.new()
	marquee.name = "DemoMarquee"
	marquee.clip_contents = true
	marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(marquee)
	return root


static func layout_marquee(overlay: Control, column_rect: Rect2) -> void:
	if overlay == null:
		return
	var marquee := overlay.get_node_or_null("DemoMarquee") as Control
	if marquee == null:
		return
	marquee.position = column_rect.position
	marquee.size = column_rect.size
	_ensure_marquee_labels(marquee, column_rect.size)
	_place_marquee_labels(overlay, marquee)


static func tick_marquee(overlay: Control, delta: float) -> void:
	if overlay == null:
		return
	var marquee := overlay.get_node_or_null("DemoMarquee") as Control
	if marquee == null or marquee.size.y < 2.0:
		return
	var offset := float(overlay.get_meta(MARQUEE_META_OFFSET, 0.0))
	var cycle := maxf(float(overlay.get_meta(MARQUEE_META_CYCLE, 1.0)), 1.0)
	offset = fposmod(offset + MARQUEE_SPEED * delta, cycle)
	overlay.set_meta(MARQUEE_META_OFFSET, offset)
	_place_marquee_labels(overlay, marquee)


static func _ensure_marquee_labels(marquee: Control, column_size: Vector2) -> void:
	var font_size := clampi(int(column_size.x * 0.78), 22, 54)
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", font_size)
	probe.text = MARQUEE_UNIT
	var font := probe.get_theme_font("font")
	var unit_w := float(font_size) * float(MARQUEE_UNIT.length()) * 0.62
	if font != null:
		unit_w = font.get_string_size(MARQUEE_UNIT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	probe.free()
	unit_w = maxf(unit_w, 1.0)
	var need := maxi(4, int(ceil(column_size.y / unit_w)) + 3)
	while marquee.get_child_count() < need:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text = MARQUEE_UNIT
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.88))
		label.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
		marquee.add_child(label)
	for index in marquee.get_child_count():
		var label := marquee.get_child(index) as Label
		if label == null:
			continue
		label.visible = index < need
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_constant_override("outline_size", maxi(6, font_size / 6))
	marquee.set_meta(&"unit_w", unit_w)
	marquee.set_meta(&"font_size", font_size)
	marquee.set_meta(&"need", need)


static func _place_marquee_labels(overlay: Control, marquee: Control) -> void:
	var unit_w := maxf(float(marquee.get_meta(&"unit_w", 1.0)), 1.0)
	var font_size := int(marquee.get_meta(&"font_size", 32))
	var need := int(marquee.get_meta(&"need", 0))
	overlay.set_meta(MARQUEE_META_CYCLE, unit_w)
	var offset := float(overlay.get_meta(MARQUEE_META_OFFSET, 0.0))
	var box := Vector2(unit_w, float(font_size) * 1.15)
	## 時計回り90度で横書き DEMO が上→下向きになる。
	var angle := PI * 0.5
	for index in need:
		if index >= marquee.get_child_count():
			break
		var label := marquee.get_child(index) as Label
		if label == null or not label.visible:
			continue
		## 上から下へ流す。
		var along := -unit_w + fposmod(offset, unit_w) + float(index) * unit_w
		var center := Vector2(marquee.size.x * 0.5, along + box.x * 0.5)
		label.size = box
		label.pivot_offset = box * 0.5
		label.rotation = angle
		label.position = center - box * 0.5


static func is_exit_event(event: InputEvent) -> bool:
	return _is_exit_event(event)


static func _request_exit(root: Control) -> void:
	if root == null or not root.has_meta(&"on_exit"):
		return
	var cb: Callable = root.get_meta(&"on_exit")
	if cb.is_valid():
		cb.call()


static func _is_exit_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


static func _clear_allies(host: Node) -> void:
	var doomed: Array[GameUnit] = []
	for unit in host.board.get_all_units():
		if unit == null or not is_instance_valid(unit) or unit.is_enemy:
			continue
		doomed.append(unit)
	for unit in doomed:
		host.board.remove_unit(unit)
		unit.queue_free()
	host.board.clear_enemy_units()


static func _clear_relics(host: Node) -> void:
	host.session.relics.clear()
	host.session.relic_pending_picks = 0
	host.session.relic_pending_units.clear()
	host.session.relic_043_armed.clear()
	host.session.relic_043_live.clear()
	host.session.relic_076_slots.clear()


static func _synergy_pools() -> Dictionary:
	var pools: Dictionary = {}
	for unit in UnitCatalog.UNITS:
		var unit_id := int(unit["id"])
		for entry in unit.get("synergy_names", []):
			var synergy_name := str(entry)
			if synergy_name.is_empty():
				continue
			if not pools.has(synergy_name):
				pools[synergy_name] = []
			(pools[synergy_name] as Array).append(unit_id)
	return pools


static func _pick_focus_synergies(pools: Dictionary, count: int) -> Array[String]:
	var candidates: Array[String] = []
	for synergy_name in pools.keys():
		var members: Array = pools[synergy_name]
		var need := _first_stage_need(str(synergy_name))
		if members.size() >= need:
			candidates.append(str(synergy_name))
	candidates.shuffle()
	var focus: Array[String] = []
	for synergy_name in candidates:
		if focus.size() >= count:
			break
		focus.append(synergy_name)
	if focus.is_empty() and not candidates.is_empty():
		focus.append(candidates[0])
	return focus


static func _first_stage_need(synergy_name: String) -> int:
	var data := SynergyCatalog.get_by_name(synergy_name)
	var stages: Array = data.get("stages", [])
	if stages.is_empty():
		return 2
	return maxi(2, int(stages[0].get("count", 2)))


static func _pick_board_ids(pools: Dictionary, focus: Array[String], count: int) -> Array[int]:
	var picked: Array[int] = []
	var used: Dictionary = {}
	for synergy_name in focus:
		var need := _first_stage_need(synergy_name)
		var pool: Array = (pools.get(synergy_name, []) as Array).duplicate()
		pool.shuffle()
		var added := 0
		for unit_id_value in pool:
			var unit_id := int(unit_id_value)
			if used.has(unit_id):
				continue
			picked.append(unit_id)
			used[unit_id] = true
			added += 1
			if added >= need or picked.size() >= count:
				break
		if picked.size() >= count:
			break
	var all_ids: Array[int] = []
	for unit in UnitCatalog.UNITS:
		all_ids.append(int(unit["id"]))
	all_ids.shuffle()
	for unit_id in all_ids:
		if picked.size() >= count:
			break
		if used.has(unit_id):
			continue
		picked.append(unit_id)
		used[unit_id] = true
	return picked


static func _pick_bench_ids(pools: Dictionary, focus: Array[String], board_ids: Array[int], count: int) -> Array[int]:
	var picked: Array[int] = []
	var used: Dictionary = {}
	for unit_id in board_ids:
		used[unit_id] = true
	## フォーカスシナジーの端数をベンチに置き、作りかけ感を出す。
	for synergy_name in focus:
		var pool: Array = (pools.get(synergy_name, []) as Array).duplicate()
		pool.shuffle()
		for unit_id_value in pool:
			if picked.size() >= maxi(1, count / 2):
				break
			var unit_id := int(unit_id_value)
			if used.has(unit_id):
				continue
			picked.append(unit_id)
			used[unit_id] = true
			break
	var all_ids: Array[int] = []
	for unit in UnitCatalog.UNITS:
		all_ids.append(int(unit["id"]))
	all_ids.shuffle()
	for unit_id in all_ids:
		if picked.size() >= count:
			break
		if used.has(unit_id):
			continue
		picked.append(unit_id)
		used[unit_id] = true
	return picked


static func _make_specs(unit_ids: Array[int], star_weights: Array) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for unit_id in unit_ids:
		var sheet := CharacterSheet.make(unit_id, 1)
		specs.append({
			"id": unit_id,
			"stars": int(star_weights[randi() % star_weights.size()]),
			"element": str(sheet.get("element", "fire")),
		})
	return specs


static func _sort_specs_for_formation(specs: Array[Dictionary]) -> void:
	specs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ae := str(a.get("element", ""))
		var be := str(b.get("element", ""))
		if ae == be:
			return int(a.get("stars", 1)) > int(b.get("stars", 1))
		return ae < be
	)


static func _place_board(host: Node, specs: Array[Dictionary]) -> void:
	var faces: int = host.board.get_unlocked_face_count()
	var order: Array[Vector2i] = []
	## スロット優先で縦に積むと陣形スタックが自然に立つ。
	for slot_index in BoardController.SLOTS_PER_FACE:
		for face_index in faces:
			order.append(Vector2i(face_index, slot_index))
	var index := 0
	for spec in specs:
		if index >= order.size():
			break
		var unit := GameUnit.create(int(spec["id"]), int(spec["stars"]))
		host.units_root.add_child(unit)
		var pos: Vector2i = order[index]
		if not host.board.place_on_circle(unit, pos.x, pos.y, false):
			unit.queue_free()
			continue
		index += 1
	host.board.refresh_presentation()
	host.board.units_changed.emit()


static func _place_bench(host: Node, specs: Array[Dictionary]) -> void:
	var board: BoardController = host.board
	var units_root: Node3D = host.units_root
	for spec in specs:
		var slot: int = board.find_empty_bench_slot()
		if slot < 0:
			break
		var unit := GameUnit.create(int(spec["id"]), int(spec["stars"]))
		units_root.add_child(unit)
		if not board.place_on_bench(unit, slot, false):
			unit.queue_free()


static func _seed_relics(host: Node) -> void:
	var session: GameSession = host.session
	var board: BoardController = host.board
	var equippable: Array[int] = []
	for relic_id in RelicCatalog.all_ids():
		var data := RelicCatalog.get_relic(relic_id)
		if data.is_empty() or int(data.get("id", -1)) <= 0:
			continue
		if not bool(data.get("equippable", false)):
			continue
		## 入手時に消える／3択を開くものは避ける。
		if relic_id in [41, 60, 67, 84, 97, 124, 310]:
			continue
		equippable.append(relic_id)
	if equippable.is_empty():
		return
	equippable.shuffle()
	var grant_count := mini(equippable.size(), randi_range(5, 8))
	var granted: Array[int] = []
	for i in grant_count:
		var uid: int = session.add_relic(equippable[i], {"from_shinan": true})
		if uid > 0:
			granted.append(uid)
	var board_units: Array[GameUnit] = []
	for unit in board.get_circle_units():
		if unit != null and is_instance_valid(unit) and not unit.is_enemy:
			board_units.append(unit)
	board_units.shuffle()
	var equip_count := mini(granted.size(), mini(board_units.size(), randi_range(3, 5)))
	for i in equip_count:
		var uid := granted[i]
		var unit := board_units[i % board_units.size()]
		_try_equip(host, uid, unit)


static func _try_equip(host: Node, uid: int, unit: GameUnit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var session: GameSession = host.session
	var board: BoardController = host.board
	var relic_id: int = session.relic_id_of(uid)
	var data := RelicCatalog.get_relic(relic_id)
	if not bool(data.get("equippable", false)):
		return
	if unit.equipped_relic_uids.size() >= GameUnit.RELIC_EQUIP_CAP:
		return
	var synergy_name := str(data.get("synergy", "")).strip_edges()
	if not synergy_name.is_empty() and SynergyTracker.unit_has_synergy(unit, synergy_name, session, uid):
		return
	for owner in board.get_all_units():
		if owner != null:
			owner.equipped_relic_uids.erase(uid)
	unit.equipped_relic_uids.append(uid)
