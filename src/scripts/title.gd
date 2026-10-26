extends Control


func _ready() -> void:
	$StartButton.pressed.connect(_on_start_pressed)
	var video := $Background as VideoStreamPlayer
	video.loop = true
	if not video.is_playing():
		video.play()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
