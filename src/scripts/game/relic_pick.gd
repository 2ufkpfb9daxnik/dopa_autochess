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
var _briefs: Array[RichTextLabel] = []
var _detail_buttons: Array[Button] = []
var _brief_texts: Array[String] = []
var _detail_texts: Array[String] = []
var _card_detailed: Array[bool] = []
var _reroll_buttons: Array[Button] = []
var _reroll_used: Array[bool] = []
var _title: Label
var _tip: PanelContainer
var _tip_label: Label
var _tip_owner: Control


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
	_layout()
	_set_choices(ids)
	call_deferred("_layout")


func close_pick() -> void:
	_hide_tip()
	visible = false
	top_level = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2.ZERO


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 50
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(0.98, 0.96, 0.88, 0.98)
	tip_style.border_color = Color(0.35, 0.28, 0.12, 0.95)
	tip_style.set_border_width_all(2)
	tip_style.set_corner_radius_all(10)
	tip_style.content_margin_left = 12
	tip_style.content_margin_right = 12
	tip_style.content_margin_top = 8
	tip_style.content_margin_bottom = 8
	_tip.add_theme_stylebox_override("panel", tip_style)
	_tip_label = Label.new()
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.06))
	_tip.add_child(_tip_label)
	add_child(_tip)
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
	root.clip_contents = false
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = SELECT_TEX
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.z_index = 0
	root.add_child(frame)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 2
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
	name_label.z_index = 3
	root.add_child(name_label)
	_names.append(name_label)
	var brief := RichTextLabel.new()
	brief.bbcode_enabled = true
	brief.fit_content = true
	brief.scroll_active = false
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief.add_theme_font_size_override("normal_font_size", 20)
	brief.add_theme_color_override("default_color", Color(0.9, 0.9, 0.84))
	brief.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.9))
	brief.add_theme_constant_override("outline_size", 6)
	brief.hint_underlined = false
	brief.meta_underlined = false
	brief.mouse_filter = Control.MOUSE_FILTER_STOP
	brief.z_index = 5
	brief.meta_hover_started.connect(_on_brief_meta_hover.bind(brief))
	brief.meta_hover_ended.connect(_on_brief_meta_unhover.bind(brief))
	brief.mouse_exited.connect(_on_brief_mouse_exited.bind(brief))
	root.add_child(brief)
	_briefs.append(brief)
	_brief_texts.append("")
	_detail_texts.append("")
	_card_detailed.append(false)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.z_index = 4
	var empty := StyleBoxEmpty.new()
	hit.add_theme_stylebox_override("normal", empty)
	hit.add_theme_stylebox_override("hover", empty)
	hit.add_theme_stylebox_override("pressed", empty)
	hit.add_theme_stylebox_override("focus", empty)
	hit.add_theme_stylebox_override("disabled", empty)
	hit.pressed.connect(_on_card_pressed.bind(index))
	root.add_child(hit)
	var detail := Button.new()
	detail.text = "詳細"
	detail.focus_mode = Control.FOCUS_NONE
	detail.z_index = 5
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	detail.pressed.connect(_on_detail_pressed.bind(index))
	root.add_child(detail)
	_detail_buttons.append(detail)
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
		_brief_texts[index] = ""
		_detail_texts[index] = ""
		_card_detailed[index] = false
		_detail_buttons[index].text = "詳細"
		_detail_buttons[index].visible = false
		_cards[index].visible = false
		_reroll_buttons[index].visible = false
		return
	_cards[index].visible = true
	_reroll_buttons[index].visible = true
	var data := RelicCatalog.get_relic(relic_id)
	var icon := _icons[index]
	icon.visible = true
	icon.modulate = Color.WHITE
	icon.texture = RelicCatalog.get_icon(relic_id)
	_names[index].text = str(data.get("name", ""))
	var brief := str(data.get("brief", ""))
	var detail := str(data.get("detail", "")).strip_edges()
	_brief_texts[index] = brief
	_detail_texts[index] = detail
	_card_detailed[index] = false
	_set_brief_text(index, brief)
	_detail_buttons[index].text = "詳細"
	_detail_buttons[index].visible = not detail.is_empty()


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
		var detail_h := 40.0
		var detail_pad := card_h * 0.04
		var brief_top := text_top + name_font * 1.7
		var brief_bottom := card_h - detail_h - detail_pad * 2.0
		_briefs[index].add_theme_font_size_override("normal_font_size", brief_font)
		_briefs[index].position = Vector2(card_w * 0.12, brief_top)
		_briefs[index].size = Vector2(card_w * 0.76, maxf(48.0, brief_bottom - brief_top))
		var shown := _detail_texts[index] if bool(_card_detailed[index]) else _brief_texts[index]
		if not shown.is_empty():
			_briefs[index].text = CharacterText.with_attribute_icons(shown, CharacterText.icon_px(brief_font))
		var detail_btn := _detail_buttons[index]
		var detail_w := minf(120.0, card_w * 0.42)
		detail_btn.position = Vector2((card_w - detail_w) * 0.5, card_h - detail_h - detail_pad)
		detail_btn.size = Vector2(detail_w, detail_h)
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


func _on_detail_pressed(index: int) -> void:
	if index < 0 or index >= CARD_COUNT:
		return
	if _detail_texts[index].is_empty():
		return
	_card_detailed[index] = not _card_detailed[index]
	var detailed := bool(_card_detailed[index])
	_set_brief_text(index, _detail_texts[index] if detailed else _brief_texts[index])
	_detail_buttons[index].text = "戻る" if detailed else "詳細"
	GameAudio.play_confirm()


func _set_brief_text(index: int, plain: String) -> void:
	if index < 0 or index >= _briefs.size():
		return
	var font_size := int(_briefs[index].get_theme_font_size("normal_font_size"))
	if font_size <= 0:
		font_size = 20
	_briefs[index].text = CharacterText.with_attribute_icons(plain, CharacterText.icon_px(font_size))


func _on_brief_meta_hover(meta: Variant, label: RichTextLabel) -> void:
	_show_tip(str(meta), label)


func _on_brief_meta_unhover(_meta: Variant, label: RichTextLabel) -> void:
	if _tip_owner == label:
		_hide_tip()


func _on_brief_mouse_exited(label: RichTextLabel) -> void:
	if _tip_owner == label:
		_hide_tip()


func _show_tip(text: String, owner: Control) -> void:
	if text.is_empty() or _tip == null or _tip_label == null:
		return
	_tip_owner = owner
	_tip_label.text = text
	_tip.visible = true
	_tip.reset_size()
	var tip_size := _tip.get_combined_minimum_size()
	_tip.size = tip_size
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + Vector2(12.0, -30.0)
	var view := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - tip_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, view.y - tip_size.y - 8.0))
	_tip.global_position = pos
	_tip.move_to_front()


func _hide_tip() -> void:
	_tip_owner = null
	if _tip != null:
		_tip.visible = false


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
