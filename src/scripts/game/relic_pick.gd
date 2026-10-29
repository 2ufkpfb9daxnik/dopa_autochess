class_name RelicPick
extends Control

signal chosen(relic_id: int)

const SELECT_TEX := preload("res://images/ui/select.png")
const REFRESH_TEX := preload("res://images/status/refresh.png")
const CARD_COUNT := 3

var _choices: Array[int] = []
var _cards: Array[Control] = []
var _icons: Array[TextureRect] = []
var _names: Array[Label] = []
var _briefs: Array[Label] = []
var _reroll_buttons: Array[Button] = []
var _reroll_used: Array[bool] = []
var _title: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 95
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func open_with(ids: Array[int]) -> void:
	_reset_rerolls()
	_set_choices(ids)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true
	z_as_relative = false
	z_index = 95
	move_to_front()
	call_deferred("_layout")


func close_pick() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_title = Label.new()
	_title.text = "レリックを 1 つ選ぶ"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 42)
	_title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	_title.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.9))
	_title.add_theme_constant_override("outline_size", 10)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	for index in CARD_COUNT:
		var card := _make_card(index)
		_cards.append(card)
		add_child(card)
		var reroll := _make_reroll_button(index)
		_reroll_buttons.append(reroll)
		add_child(reroll)
		_reroll_used.append(false)
	resized.connect(_layout)
	_layout()


func _make_card(index: int) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = SELECT_TEX
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(_on_card_pressed.bind(index))
	root.add_child(hit)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	_icons.append(icon)
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	name_label.add_theme_constant_override("outline_size", 8)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_label)
	_names.append(name_label)
	var brief := Label.new()
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_theme_font_size_override("font_size", 20)
	brief.add_theme_color_override("font_color", Color(0.9, 0.9, 0.84))
	brief.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	brief.add_theme_constant_override("outline_size", 6)
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(brief)
	_briefs.append(brief)
	return root


func _make_reroll_button(index: int) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "この枠だけ振り直す（1回）"
	button.icon = REFRESH_TEX
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 64)
	button.pressed.connect(_on_slot_reroll_pressed.bind(index))
	return button


func _reset_rerolls() -> void:
	for index in CARD_COUNT:
		_reroll_used[index] = false
		_apply_reroll_visual(index)


func _apply_reroll_visual(index: int) -> void:
	if index < 0 or index >= _reroll_buttons.size():
		return
	var button := _reroll_buttons[index]
	var used := bool(_reroll_used[index])
	button.disabled = used
	button.modulate = Color(0.48, 0.48, 0.5, 0.85) if used else Color(1, 1, 1, 1)
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if used else Control.CURSOR_POINTING_HAND


func _set_choices(ids: Array[int]) -> void:
	_choices.clear()
	for relic_id in ids:
		_choices.append(int(relic_id))
	while _choices.size() < CARD_COUNT:
		_choices.append(-1)
	for index in CARD_COUNT:
		_fill_card(index, _choices[index])


func _fill_card(index: int, relic_id: int) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	if relic_id <= 0:
		_icons[index].texture = null
		_names[index].text = ""
		_briefs[index].text = ""
		_cards[index].visible = false
		_reroll_buttons[index].visible = false
		return
	_cards[index].visible = true
	_reroll_buttons[index].visible = true
	var data := RelicCatalog.get_relic(relic_id)
	_icons[index].texture = RelicCatalog.get_icon(relic_id)
	_names[index].text = str(data.get("name", ""))
	_briefs[index].text = str(data.get("brief", ""))


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		return
	size = view
	position = Vector2.ZERO
	var side := clampf(view.x * 0.018, 10.0, 28.0)
	var gap := clampf(view.x * 0.012, 10.0, 22.0)
	var card_w := (view.x - side * 2.0 - gap * float(CARD_COUNT - 1)) / float(CARD_COUNT)
	var reroll_size := clampf(card_w * 0.18, 56.0, 78.0)
	var title_h := 52.0
	var bottom_pad := 18.0
	var card_y := view.y * 0.07 + title_h
	var max_h := view.y - card_y - reroll_size - 28.0 - bottom_pad
	var card_h := minf(card_w * 1.38, max_h)
	var row_w := card_w * float(CARD_COUNT) + gap * float(CARD_COUNT - 1)
	var start_x := (view.x - row_w) * 0.5
	_title.position = Vector2(view.x * 0.1, view.y * 0.02)
	_title.size = Vector2(view.x * 0.8, title_h)
	var name_font := int(clampf(card_w * 0.065, 24.0, 36.0))
	var brief_font := int(clampf(card_w * 0.042, 16.0, 24.0))
	for index in CARD_COUNT:
		var card := _cards[index]
		var x := start_x + float(index) * (card_w + gap)
		card.position = Vector2(x, card_y)
		card.size = Vector2(card_w, card_h)
		var icon_size := card_w * 0.34
		var icon_y := card_h * 0.08
		_icons[index].position = Vector2((card_w - icon_size) * 0.5, icon_y)
		_icons[index].size = Vector2(icon_size, icon_size)
		var text_top := icon_y + icon_size + card_h * 0.02
		_names[index].add_theme_font_size_override("font_size", name_font)
		_names[index].position = Vector2(card_w * 0.07, text_top)
		_names[index].size = Vector2(card_w * 0.86, name_font * 1.6)
		var brief_top := text_top + name_font * 1.7
		_briefs[index].add_theme_font_size_override("font_size", brief_font)
		_briefs[index].position = Vector2(card_w * 0.07, brief_top)
		_briefs[index].size = Vector2(card_w * 0.86, maxf(48.0, card_h - brief_top - card_h * 0.06))
		var reroll := _reroll_buttons[index]
		reroll.add_theme_constant_override("icon_max_width", int(reroll_size * 0.78))
		reroll.position = Vector2(x + (card_w - reroll_size) * 0.5, card_y + card_h + 10.0)
		reroll.size = Vector2(reroll_size, reroll_size)


func _on_card_pressed(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	var relic_id := _choices[index]
	if relic_id <= 0:
		return
	GameAudio.play_confirm_strong()
	chosen.emit(relic_id)
	close_pick()


func _on_slot_reroll_pressed(index: int) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	if _reroll_used[index]:
		return
	var next_id := _roll_for_slot(index)
	if next_id <= 0:
		return
	GameAudio.play_confirm()
	_choices[index] = next_id
	_fill_card(index, next_id)
	_reroll_used[index] = true
	_apply_reroll_visual(index)


func _roll_for_slot(index: int) -> int:
	var pool: Array[int] = RelicCatalog.all_pick_ids()
	if pool.is_empty():
		return -1
	var blocked: Dictionary = {}
	for other in CARD_COUNT:
		if other == index:
			continue
		var other_id := _choices[other] if other < _choices.size() else -1
		if other_id > 0:
			blocked[other_id] = true
	var candidates: Array[int] = []
	for relic_id in pool:
		if blocked.has(relic_id):
			continue
		if index < _choices.size() and relic_id == _choices[index]:
			continue
		candidates.append(relic_id)
	if candidates.is_empty():
		for relic_id in pool:
			if index < _choices.size() and relic_id == _choices[index]:
				continue
			candidates.append(relic_id)
	if candidates.is_empty():
		return pool[randi() % pool.size()]
	return candidates[randi() % candidates.size()]
