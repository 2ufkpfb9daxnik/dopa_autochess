class_name AttributeHitFx
extends Node3D

const ROOT := "res://images/frames/battle"
const FPS := 24.0
const PIXEL_SIZE := 0.0042
const FOLDERS := {
	"fire": "fire",
	"water": "water",
	"thunder": "thunder",
	"earth": "earth",
	"ice": "ice",
	"wind": "wind",
	"absorb": "absorption",
}

static var _path_cache: Dictionary = {}

var _sprite: Sprite3D
var _paths: PackedStringArray = []
var _time := 0.0


static func play(parent: Node, element: String, world_pos: Vector3) -> void:
	if parent == null:
		return
	var fx := AttributeHitFx.new()
	parent.add_child(fx)
	fx._begin(element, world_pos)


func _begin(element: String, world_pos: Vector3) -> void:
	_paths = _paths_for(element)
	if _paths.is_empty():
		queue_free()
		return
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.transparent = true
	_sprite.centered = true
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_sprite.render_priority = 2
	add_child(_sprite)
	var pos := world_pos
	pos.y += 0.55
	pos.z = lerpf(pos.z, 0.0, 0.4)
	global_position = pos
	_show_frame(0)


func _process(delta: float) -> void:
	if _paths.is_empty() or _sprite == null:
		queue_free()
		return
	_time += delta
	var index := int(_time * FPS)
	if index >= _paths.size():
		queue_free()
		return
	_show_frame(index)


func _show_frame(index: int) -> void:
	var texture := ResourceLoader.load(_paths[index], "", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if texture != null:
		_sprite.texture = texture


static func _paths_for(element: String) -> PackedStringArray:
	var key := str(element)
	if _path_cache.has(key):
		return _path_cache[key]
	var folder := str(FOLDERS.get(key, key))
	var dir_path := ROOT.path_join(folder)
	var names: PackedStringArray = []
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension().to_lower() != "png":
			continue
		names.append(file_name)
	names.sort()
	var paths: PackedStringArray = []
	for file_name in names:
		paths.append(dir_path.path_join(file_name))
	_path_cache[key] = paths
	return paths
