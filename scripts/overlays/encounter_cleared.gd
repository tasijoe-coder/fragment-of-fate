extends Control

signal continue_requested


func _ready() -> void:
	$CenterContainer/Panel/VBox/ContinueButton.pressed.connect(_on_continue_pressed)


func configure(encounter_name: String) -> void:
	$CenterContainer/Panel/VBox/TitleLabel.text = "%s 已擊破" % encounter_name


func _on_continue_pressed() -> void:
	continue_requested.emit()
