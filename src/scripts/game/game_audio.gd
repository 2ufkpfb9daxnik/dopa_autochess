extends Node

const EFFECTS := "res://sounds/effects/"
const BGM := "res://sounds/bgm/"
const MONEY_STAGGER := 0.1
const MONEY_VOICES := 3

enum BgmKind { NONE, CONSTRUCTION, BATTLE, SECRET, CLOCK, CLEAR, DEFEAT }

static var _node: GameAudio

var _bgm: AudioStreamPlayer
var _bgm_kind: BgmKind = BgmKind.NONE


func _enter_tree() -> void:
	_node = self
	if _bgm == null:
		_bgm = AudioStreamPlayer.new()
		_bgm.volume_db = -6.0
		add_child(_bgm)


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


static func play_after_clear() -> void:
	if _node == null:
		return
	_node._play_bgm(BGM + "after_clear.mp3", BgmKind.CLEAR)


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


func _play_now(path: String) -> void:
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _play_later(path: String, delay: float) -> void:
	if delay <= 0.0:
		_play_now(path)
		return
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void: _play_now(path))
