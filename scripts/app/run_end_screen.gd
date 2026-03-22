extends Control

signal restart_requested
signal return_to_title_requested


func _ready() -> void:
	$CenterContainer/Panel/VBox/RestartButton.pressed.connect(_on_restart_pressed)
	$CenterContainer/Panel/VBox/ReturnButton.pressed.connect(_on_return_pressed)


func configure(is_victory: bool) -> void:
	$CenterContainer/Panel/VBox/TitleLabel.text = "勝利" if is_victory else "失敗"
	$CenterContainer/Panel/VBox/BodyLabel.text = "這條連擊路線已順利打通。" if is_victory else "你倒在競技場中，這次挑戰到此結束。"


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_return_pressed() -> void:
	return_to_title_requested.emit()
