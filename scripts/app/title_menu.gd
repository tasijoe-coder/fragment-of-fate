extends Control


func _ready() -> void:
	$MarginContainer/VBox/StartRunButton.pressed.connect(_on_start_run_pressed)


func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/app/demo_run_root.tscn")
