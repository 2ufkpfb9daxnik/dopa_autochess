class_name GameUnit
extends StaticBody3D

const UNIT_SCENE := preload("res://scenes/unit.tscn")
const MAX_STARS := 4

var unit_id: int = -1
var stars: int = 1
var board_hex: Vector2i = Vector2i(-1, -1)
var bench_index: int = -1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label: Label3D = $Label3D


static func create(unit_id_value: int, star_count: int = 1) -> GameUnit:
	var unit: GameUnit = UNIT_SCENE.instantiate()
	unit.unit_id = unit_id_value
	unit.stars = clampi(star_count, 1, MAX_STARS)
	return unit


func _ready() -> void:
	if unit_id >= 0:
		refresh_visuals()


func refresh_visuals() -> void:
	var data := UnitCatalog.get_unit(unit_id)
	var material := StandardMaterial3D.new()
	material.albedo_color = data["color"]
	mesh_instance.material_override = material
	var scale := 0.85 + float(stars - 1) * 0.08
	mesh_instance.scale = Vector3.ONE * scale
	var synergy_text := UnitCatalog.get_synergy_names(unit_id)
	label.text = "%s\n%d\n%s" % ["★".repeat(stars), data["cost"], synergy_text]
	label.modulate = Color.WHITE if stars <= 2 else Color(1.0, 0.95, 0.7)


func get_cost() -> int:
	return UnitCatalog.get_unit(unit_id)["cost"]


func get_display_name() -> String:
	return UnitCatalog.get_unit(unit_id)["name"]


func get_star_text() -> String:
	return "★".repeat(stars)


func is_on_board() -> bool:
	return board_hex.x >= 0


func is_on_bench() -> bool:
	return bench_index >= 0


func clear_location() -> void:
	board_hex = Vector2i(-1, -1)
	bench_index = -1
