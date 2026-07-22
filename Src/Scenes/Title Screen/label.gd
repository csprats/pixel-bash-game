extends Label

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	if (Input.is_action_just_pressed("ui_accept")):
		GameManager.change_scene(GameManager.MENU_SCENE)

func _on_timer_timeout() -> void:
	visible = !visible
	pass
