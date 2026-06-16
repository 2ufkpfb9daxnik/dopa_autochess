class_name GameInputHandler
extends Node

signal action_triggered(action: GameAction)

var input_enabled: bool = true


func set_enabled(enabled: bool) -> void:
	input_enabled = enabled


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey and event.is_pressed() and not event.echo:
		_handle_key(event as InputEventKey)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		action_triggered.emit(GameAction.drag_press(event.position))
	else:
		action_triggered.emit(GameAction.drag_release(event.position))


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	action_triggered.emit(GameAction.drag_move(event.position))


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_D:
			action_triggered.emit(GameAction.simple(GameAction.Type.REROLL))
		KEY_F:
			action_triggered.emit(GameAction.simple(GameAction.Type.BUY_EXP))
		KEY_E:
			action_triggered.emit(
				GameAction.at_screen(
					GameAction.Type.SELL_UNDER_CURSOR,
					get_viewport().get_mouse_position()
				)
			)
		KEY_SPACE:
			action_triggered.emit(GameAction.simple(GameAction.Type.START_BATTLE))
		KEY_ESCAPE:
			action_triggered.emit(GameAction.simple(GameAction.Type.CLOSE_LOG))
