extends Node
## Root scene. Bootstraps input actions and navigates to MainMenu.

func _ready() -> void:
	_register_input_actions()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _register_input_actions() -> void:
	if not InputMap.has_action("shoot_ball"):
		InputMap.add_action("shoot_ball")
		var space := InputEventKey.new()
		space.keycode = KEY_SPACE
		InputMap.action_add_event("shoot_ball", space)
		var touch := InputEventScreenTouch.new()
		InputMap.action_add_event("shoot_ball", touch)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot_ball", mouse)
