extends CanvasLayer
class_name PauseMenu

var resume: Callable

func _init() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		resume.call()
		get_viewport().set_input_as_handled()
