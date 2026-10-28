extends SceneTree


func _init() -> void:
	Engine.time_scale = 8.0
	var started := Time.get_ticks_msec()
	var timer := create_timer(1.0)
	timer.timeout.connect(func() -> void:
		print("timer_ms ", Time.get_ticks_msec() - started)
		quit()
	)
