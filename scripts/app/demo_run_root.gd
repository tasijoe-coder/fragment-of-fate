extends Control

const ContentRegistry := preload("res://scripts/data/content_registry.gd")
const BattleScene := preload("res://scenes/battle/battle_scene.tscn")
const EncounterCleared := preload("res://scenes/overlays/encounter_cleared.tscn")
const RunEndScreen := preload("res://scenes/app/run_end_screen.tscn")

var _registry: ContentRegistry = ContentRegistry.new()
var _run_definition: Dictionary = {}
var _encounter_index: int = 0
var _battle_resolution_handled: bool = false

@onready var _scene_host: Control = $MarginContainer/VBox/SceneHost
@onready var _overlay_host: Control = $OverlayHost
@onready var _status_label: Label = $MarginContainer/VBox/HeaderPanel/HeaderVBox/StatusLabel
@onready var _route_label: Label = $MarginContainer/VBox/HeaderPanel/HeaderVBox/RouteLabel


func _ready() -> void:
	_registry.load_all()
	_start_run()


func _start_run() -> void:
	_clear_host(_scene_host)
	_clear_host(_overlay_host)
	_run_definition = _registry.get_run_definition("demo_vertical_slice")
	_encounter_index = 0
	_battle_resolution_handled = false
	_route_label.text = "固定構築：連擊 / 攻擊鏈"
	_launch_current_encounter()


func _launch_current_encounter() -> void:
	_clear_host(_scene_host)
	_clear_host(_overlay_host)
	_battle_resolution_handled = false

	var encounter_ids: Array = _run_definition.get("encounters", [])
	var encounter_id: String = String(encounter_ids[_encounter_index])
	var enemy_definition: Dictionary = _registry.get_enemy_definition(encounter_id)
	var battle_setup: Dictionary = {
		"player": _run_definition.get("player", {}).duplicate(true),
		"starting_deck": _registry.build_starting_deck(_run_definition.get("starting_deck", [])),
		"enemy": enemy_definition,
		"active_rule_chains": _registry.get_rule_chain_definitions(_run_definition.get("active_rule_chains", [])),
		"draw_per_turn": int(_run_definition.get("player", {}).get("draw_per_turn", 5)),
	}

	_status_label.text = "戰鬥 %d / %d - %s" % [
		_encounter_index + 1,
		encounter_ids.size(),
		String(enemy_definition.get("name", "戰鬥")),
	]

	var battle_scene = BattleScene.instantiate()
	battle_scene.battle_finished.connect(_on_battle_finished)
	_scene_host.add_child(battle_scene)
	battle_scene.call_deferred("start_battle", battle_setup)


func _on_battle_finished(result: Dictionary) -> void:
	if _battle_resolution_handled:
		return
	_battle_resolution_handled = true

	var victory: bool = bool(result.get("victory", false))
	if not victory:
		_show_run_end(false)
		return

	var encounter_ids: Array = _run_definition.get("encounters", [])
	if _encounter_index >= encounter_ids.size() - 1:
		_show_run_end(true)
		return

	var cleared_overlay = EncounterCleared.instantiate()
	cleared_overlay.configure(String(result.get("enemy_name", "戰鬥")))
	cleared_overlay.continue_requested.connect(_on_continue_to_next_encounter)
	_overlay_host.add_child(cleared_overlay)


func _on_continue_to_next_encounter() -> void:
	_encounter_index += 1
	_launch_current_encounter()


func _show_run_end(is_victory: bool) -> void:
	_clear_host(_overlay_host)
	var end_screen = RunEndScreen.instantiate()
	end_screen.configure(is_victory)
	end_screen.restart_requested.connect(_on_restart_requested)
	end_screen.return_to_title_requested.connect(_on_return_to_title_requested)
	_overlay_host.add_child(end_screen)


func _on_restart_requested() -> void:
	_start_run()


func _on_return_to_title_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/app/title_menu.tscn")


func _clear_host(host: Control) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
