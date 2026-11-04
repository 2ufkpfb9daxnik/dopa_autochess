extends Node

const EFFECTS := "res://sounds/effects/"
const BGM := "res://sounds/bgm/"
const BATTLE := EFFECTS + "battle/"
const SETTINGS_PATH := "user://audio_settings.cfg"
const BGM_VOLUME_DB := -6.0
## 秘密戦闘曲は基準より少し大きくする。
const SECRET_BGM_BONUS_DB := 3.0
const MUTED_VOLUME_DB := -80.0
const NORMAL_BATTLE_EXTRA := ["stable_audio_3_00014.mp3"]
const BGM_TEST_EXCLUDE := ["secret_battle.mp3"]
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

enum BgmKind { NONE, CONSTRUCTION, BATTLE, SECRET, CLOCK, CLEAR, DEFEAT, WIN, LOSE, TEST }

static var _node: GameAudio

const BUFF_BUS := "BuffReverb"

var _bgm: AudioStreamPlayer
var _bgm_kind: BgmKind = BgmKind.NONE
var _bgm_enabled := true
var _se_enabled := true
## デモ中だけ効果音を止める（設定ファイルには書かない）。
var _se_suppressed := false
## デモBGM: ループせず、曲終了で次のランダム曲へ。
var _demo_bgm := false
var _demo_bgm_path := ""
var _effect_lists: Dictionary = {}
var _buff_bus_ready := false


func _enter_tree() -> void:
	_node = self
	_load_settings()
	_ensure_buff_reverb_bus()
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


static func set_se_suppressed(suppressed: bool) -> void:
	if _node == null:
		return
	_node._se_suppressed = suppressed


static func play_demo_bgm() -> void:
	## construction / stdbattle をランダムに。1曲終わったら別曲へ。
	if _node == null:
		return
	_node._demo_bgm = true
	_node._ensure_demo_bgm_finished()
	_node._play_next_demo_bgm()


static func stop_demo_bgm() -> void:
	if _node == null:
		return
	_node._demo_bgm = false
	_node._demo_bgm_path = ""
	stop_bgm()


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
	_node._play_bgm(_node._random_battle_track(), BgmKind.BATTLE)


static func play_result(won: bool) -> void:
	if _node == null:
		return
	if won:
		_node._play_bgm(BGM + "win.mp3", BgmKind.WIN)
	else:
		_node._play_random_effect(BATTLE + "defeat")
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


static func play_battle_miss() -> void:
	## 専用missフォルダは無いので、打撃／斬撃を小さめに鳴らして空振りにする。
	if _node == null:
		return
	var folder := "blow" if randi() % 2 == 0 else "sword"
	_node._play_random_effect(BATTLE + folder, -7.0)


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


static func play_battle_support() -> void:
	## バフ／デバフ行動。反響付きバス＋短いエコーで広がりを出す。
	if _node == null:
		return
	_node._ensure_buff_reverb_bus()
	var path := _node._random_effect(BATTLE + "guard")
	if path.is_empty():
		return
	_node._play_now(path, -1.0, BUFF_BUS)
	_node._play_later(path, 0.06, -9.0, BUFF_BUS)
	_node._play_later(path, 0.13, -16.0, BUFF_BUS)


static func play_battle_guard() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "guard")


static func play_battle_fall() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "fall")


static func play_battle_slay() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "slay")


static func play_debuff_ritual(mode: int) -> void:
	if _node == null:
		return
	var folder := "right_click"
	match mode:
		1:
			folder = "circle"
		2:
			folder = "tap"
		_:
			folder = "right_click"
	_node._play_random_effect(BATTLE + "debuff/" + folder)


static func play_debuff_remove() -> void:
	if _node == null:
		return
	_node._play_random_effect(BATTLE + "debuff/remove")


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


func _ensure_demo_bgm_finished() -> void:
	if _bgm == null:
		return
	if not _bgm.finished.is_connected(_on_demo_bgm_finished):
		_bgm.finished.connect(_on_demo_bgm_finished)


func _on_demo_bgm_finished() -> void:
	if not _demo_bgm:
		return
	_play_next_demo_bgm()


func _play_next_demo_bgm() -> void:
	var path := _random_demo_track(_demo_bgm_path)
	if path.is_empty():
		return
	_demo_bgm_path = path
	var kind := BgmKind.CONSTRUCTION if path.get_file().begins_with("construction") else BgmKind.BATTLE
	_play_bgm(path, kind)


func _random_demo_track(except_path: String = "") -> String:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(BGM):
		if file_name.get_extension().to_lower() != "mp3":
			continue
		if not (file_name.begins_with("construction") or file_name.begins_with("stdbattle")):
			continue
		paths.append(BGM.path_join(file_name))
	if paths.is_empty():
		return ""
	if paths.size() == 1:
		return paths[0]
	var choices: PackedStringArray = []
	for path in paths:
		if path != except_path:
			choices.append(path)
	if choices.is_empty():
		choices = paths
	return choices[randi() % choices.size()]


## タイトルの音声テスト用。BGM フォルダ内の mp3 を名前順で返す（秘密戦闘曲は除外）。
static func list_bgm_tracks() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(BGM):
		if file_name.get_extension().to_lower() != "mp3":
			continue
		if file_name in BGM_TEST_EXCLUDE:
			continue
		paths.append(BGM.path_join(file_name))
	paths.sort()
	return paths


static func play_bgm_track(path: String) -> void:
	if _node == null or path.is_empty():
		return
	_node._play_bgm(path, BgmKind.TEST)


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
		## デモは曲終了を拾うためループしない。
		(stream as AudioStreamMP3).loop = not _demo_bgm
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


func _random_battle_track() -> String:
	var paths: PackedStringArray = []
	for file_name in DirAccess.get_files_at(BGM):
		if file_name.get_extension().to_lower() != "mp3":
			continue
		if file_name.begins_with("stdbattle") or file_name in NORMAL_BATTLE_EXTRA:
			paths.append(BGM.path_join(file_name))
	if paths.is_empty():
		return ""
	return paths[randi() % paths.size()]


func _ensure_buff_reverb_bus() -> void:
	if _buff_bus_ready and AudioServer.get_bus_index(BUFF_BUS) >= 0:
		return
	var index := AudioServer.get_bus_index(BUFF_BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUFF_BUS)
		AudioServer.set_bus_send(index, &"Master")
	## 既存エフェクトを消してから Reverb を載せ直す。
	while AudioServer.get_bus_effect_count(index) > 0:
		AudioServer.remove_bus_effect(index, 0)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.62
	reverb.damping = 0.28
	reverb.spread = 0.78
	reverb.hipass = 0.08
	reverb.dry = 0.58
	reverb.wet = 0.52
	reverb.predelay_msec = 28.0
	reverb.predelay_feedback = 0.18
	AudioServer.add_bus_effect(index, reverb)
	_buff_bus_ready = true


func _play_random_effect(folder: String, volume_db: float = 0.0, bus: String = "Master") -> void:
	_play_now(_random_effect(folder), volume_db, bus)


func _random_effect(folder: String) -> String:
	var dir := folder.rstrip("/")
	var cached: Variant = _effect_lists.get(dir, null)
	var paths := PackedStringArray()
	if cached is PackedStringArray and not (cached as PackedStringArray).is_empty():
		paths = cached
	else:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.get_extension().to_lower() != "mp3":
				continue
			paths.append(dir.path_join(file_name))
		## 空はキャッシュしない（初回失敗で永久に無音になるのを防ぐ）。
		if not paths.is_empty():
			_effect_lists[dir] = paths
	if paths.is_empty():
		return ""
	return paths[randi() % paths.size()]


func _play_now(path: String, volume_db: float = 0.0, bus: String = "Master") -> void:
	if path.is_empty() or not _se_enabled or _se_suppressed:
		return
	var loaded := load(path) as AudioStream
	if loaded == null:
		return
	var stream := loaded.duplicate() as AudioStream
	if stream == null:
		stream = loaded
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = bus
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _apply_bgm_volume() -> void:
	if _bgm == null:
		return
	if not _bgm_enabled:
		_bgm.volume_db = MUTED_VOLUME_DB
		return
	var bonus := SECRET_BGM_BONUS_DB if _bgm_kind == BgmKind.SECRET else 0.0
	_bgm.volume_db = BGM_VOLUME_DB + bonus


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


func _play_later(path: String, delay: float, volume_db: float = 0.0, bus: String = "Master") -> void:
	if delay <= 0.0:
		_play_now(path, volume_db, bus)
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void: _play_now(path, volume_db, bus))
