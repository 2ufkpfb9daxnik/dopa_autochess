class_name EventLog
extends Node

signal message_added(text: String)

const MAX_MESSAGES := 80

var _messages: Array[String] = []


func add(text: String) -> void:
	_messages.append(text)
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	message_added.emit(text)


func get_messages() -> Array[String]:
	return _messages.duplicate()


func get_display_text() -> String:
	return "\n".join(_messages)
