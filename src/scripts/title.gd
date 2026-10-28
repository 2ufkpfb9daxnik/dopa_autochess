extends Control

const FRAME_DIR := "res://images/frames"

var _video: VideoStreamPlayer
var _frame_flash: TextureRect
var _frame_paths: PackedStringArray = []
var _last_stream_position := 0.0
var _stream_position_ready := false
var _hide_flash_next_frame := false


func _ready() -> void:
	GameAudio.stop_bgm()
	$StartButton.pressed.connect(_on_start_pressed)
	_video = $Background as VideoStreamPlayer
	_video.loop = true
	_frame_paths = _list_frame_paths()
	_frame_flash = TextureRect.new()
	_frame_flash.name = "LoopFrame"
	_frame_flash.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_frame_flash.visible = false
	add_child(_frame_flash)
	move_child(_frame_flash, _video.get_index() + 1)
	if not _video.is_playing():
		_video.play()
	var settings := AudioSettings.new()
	settings.button_font = 32
	settings.button_height = 64.0
	settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings.offset_left = -196.0
	settings.offset_top = 20.0
	settings.offset_right = -20.0
	settings.offset_bottom = 84.0
	settings.z_index = 10
	add_child(settings)


func _process(_delta: float) -> void:
	if _hide_flash_next_frame:
		_frame_flash.visible = false
		_hide_flash_next_frame = false
	if _video == null or not _video.is_playing():
		return
	var position := _video.stream_position
	if _stream_position_ready and position + 0.05 < _last_stream_position:
		_show_loop_frame()
	_last_stream_position = position
	_stream_position_ready = true


func _show_loop_frame() -> void:
	if _frame_paths.is_empty():
		return
	var texture := load(_frame_paths[randi() % _frame_paths.size()]) as Texture2D
	if texture == null:
		return
	_frame_flash.texture = texture
	var view := size
	var tex_size := texture.get_size()
	var fit := 1.0
	if tex_size.x > 0.0 and tex_size.y > 0.0 and view.x > 0.0 and view.y > 0.0:
		fit = minf(view.x / tex_size.x, view.y / tex_size.y)
	var drawn := tex_size * fit * randf_range(0.35, 1.6)
	var center := Vector2(randf_range(0.0, view.x), randf_range(0.0, view.y))
	_frame_flash.size = drawn
	_frame_flash.pivot_offset = drawn * 0.5
	_frame_flash.position = center - drawn * 0.5
	_frame_flash.rotation = randf() * TAU
	_frame_flash.visible = true
	_hide_flash_next_frame = true


func _list_frame_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(FRAME_DIR):
		if file_name.get_extension().to_lower() != "png":
			continue
		paths.append(FRAME_DIR.path_join(file_name))
	return paths


func _on_start_pressed() -> void:
	GameAudio.play_confirm_strong()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
