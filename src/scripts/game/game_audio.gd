extends Node

const EFFECTS := "res://sounds/effects/"
const BGM := "res://sounds/bgm/"
const BATTLE := EFFECTS + "battle/"
const SETTINGS_PATH := "user://audio_settings.cfg"
const BGM_VOLUME_DB := -6.0
const MUTED_VOLUME_DB := -80.0
const MONEY_STAGGER := 0.1
const MONEY_VOICES := 3
const DOT_STAGGER := 0.08
const ATTRIBUTE_FOLDERS := {
	"fire": "fire",
	"water": "water",
	"thunder": "thunder",
	"earth": "earth",
	"ice": "ice",
	"wind": "wind",
	"absorb": "absorption",
}

enum BgmKind { NONE, CONSTRUCTION, BATTLE, SECRET, CLOCK, CLEAR, DEFEAT, WIN, LOSE }

static var _node: GameAudio

var _bgm: AudioStreamPlayer
var _bgm_kind: BgmKind = BgmKind.NONE
var _bgm_enabled := true
var _se_enabled := true
var _effect_lists: Dictionary = {}


func _enter_tree() -> void:
	_node = self
	_load_settings()
	if _bgm == null:
		_bgm = AudioStreamPlayer.new()
		add_child(_bgm)
	_apply_bgm_volume()


static func is_bgm_enabled() -> bool:
	return _node != null and _node._bgm_enabled


static func is_se_enabled() -> bool:
	return _node != null and _node._se_enabled


static func set_bgm_enabled(enabled: bool) -> void:
	if _node == null:
		return
	_node._bgm_enabled = enabled
	_node._apply_bgm_volume()
	_node._save_settings()


static func set_se_enabled(enabled: bool) -> void:
	if _node == null:
		return
	_node._se_enabled = enabled
	_node._save_settings()


static func bind_buttons(root: Node) -> void:
	if root is Button and not root.has_meta(&"confirm_bound"):
		root.set_meta(&"confirm_bound", true)
		(root as Button).pressed.connect(play_confirm)
	for child in root.get_children():
		bind_buttons(child)


static func play_confirm() -> void:
	_play(EFFECTS + "confirm.mp3")


static func play_confirm_strong() -> void:
	_play(EFFECTS + "confirm_strong.mp3")


static func play_buy() -> void:
	_play(EFFECTS + "buy_1.mp3")
	_play(EFFECTS + "buy_2.mp3")


static func play_fusion() -> void:
	_play(EFFECTS + "character_fusion.mp3")


static func play_select_character() -> void:
	var which := 1 if randi() % 2 == 0 else 2
	_play(EFFECTS + "select_character_%d.mp3" % which)


static func play_money_gain() -> void:
	if _node == null:
		return
	var indexes: Array[int] = [1, 2, 3, 4, 5]
	indexes.shuffle()
	for i in MONEY_VOICES:
		_node._play_later(EFFECTS + "money_%d.mp3" % indexes[i], MONEY_STAGGER * i)


static func play_construction() -> void:
	if _node == null:
		return
	_node._play_bgm(_node._random_track("construction"), BgmKind.CONSTRUCTION)


static func play_battle(secret: bool, clocktower: bool = false) -> void:
	if _node == null:
		return
	if secret:
		_node._play_bgm(BGM + "secret_battle.mp3", BgmKind.SECRET)
		return
	if clocktower:
		_node._play_clocktower()
		return
	_node._play_bgm(_node._random_track("stdbattle"), BgmKind.BATTLE)


static func play_result(won: bool) -> void:
	if _node == null:
		return
	if won:
		_node._play_bgm(BGM + "win.mp3", BgmKind.WIN)
	else:
		_node._play_bgm(BGM + "lose.mp3", BgmKind.LOSE)


static func play_after_clear() -> void:
	if _node == null:
		return
	_node._play_bgm(BGM + "after_clear.mp3", BgmKind.CLEAR)


static func play_battle_attack() -> void:
	if _node == null:
		return
	var folder := "blow" if randi() % 2 == 0 else "sword"
	_node._play_random_effect(BATTLE + folder)


static func play_battle_attribute(element: String) -> void:
	if _node == null:
		return
	var folder := str(ATTRIBUTE_FOLDERS.get(element, ""))
	if folder.is_empty():
		return
	_node._play_random_effect(BATTLE + "attributes/" + folder)


static func play_battle_critical() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "critical")


static func play_battle_break() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "break")


static func play_battle_gauge() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "gauge")


static func play_battle_dot(layers: int) -> void:
	if _node == null or layers <= 0:
		return
	for index in layers:
		var path := _node._random_effect(BATTLE + "dot")
		_node._play_later(path, DOT_STAGGER * index)


static func play_defeat() -> void:
	if _node == null:
		return
	_node._play_bgm(BGM + "defeat.mp3", BgmKind.DEFEAT)


static func stop_bgm() -> void:
	if _node == null or _node._bgm == null:
		return
	_node._bgm.stop()
	_node._bgm_kind = BgmKind.NONE


static func _play(path: String) -> void:
	if _node == null:
		return
	_node._play_now(path)


func _play_clocktower() -> void:
	if _bgm_kind == BgmKind.CLOCK and _bgm != null and _bgm.playing:
		return
	_play_bgm(BGM + "clocktower.mp3", BgmKind.CLOCK)


func _play_bgm(path: String, kind: BgmKind) -> void:
	if path.is_empty() or _bgm == null:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_bgm.stream = stream
	_bgm.play()
	_bgm_kind = kind
	_apply_bgm_volume()


func _random_track(prefix: String) -> String:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(BGM):
		if file_name.get_extension().to_lower() != "mp3":
			continue
		if not file_name.begins_with(prefix):
			continue
		paths.append(BGM.path_join(file_name))
	if paths.is_empty():
		return ""
	return paths[randi() % paths.size()]


func _play_random_effect(folder: String) -> void:
	_play_now(_random_effect(folder))


func _random_effect(folder: String) -> String:
	var dir := folder
	if not dir.ends_with("/"):
		dir += "/"
	var cached: Variant = _effect_lists.get(dir, null)
	var paths := PackedStringArray()
	if cached is PackedStringArray:
		paths = cached
	else:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.get_extension().to_lower() != "mp3":
				continue
			paths.append(dir.path_join(file_name))
		_effect_lists[dir] = paths
	if paths.is_empty():
		return ""
	return paths[randi() % paths.size()]


func _play_now(path: String) -> void:
	if path.is_empty() or not _se_enabled:
		return
	var loaded := load(path) as AudioStream
	if loaded == null:
		return
	var stream := loaded.duplicate() as AudioStream
	if stream == null:
		stream = loaded
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _apply_bgm_volume() -> void:
	if _bgm == null:
		return
	_bgm.volume_db = BGM_VOLUME_DB if _bgm_enabled else MUTED_VOLUME_DB


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_bgm_enabled = bool(config.get_value("audio", "bgm", true))
	_se_enabled = bool(config.get_value("audio", "se", true))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", _bgm_enabled)
	config.set_value("audio", "se", _se_enabled)
	config.save(SETTINGS_PATH)


func _play_later(path: String, delay: float) -> void:
	if delay <= 0.0:
		_play_now(path)
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void: _play_now(path))
