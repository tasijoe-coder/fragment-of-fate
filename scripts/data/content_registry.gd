extends RefCounted
class_name ContentRegistry

const JsonLoader := preload("res://scripts/data/json_loader.gd")
const CardInstance := preload("res://scripts/battle/card_instance.gd")

var _json_loader: JsonLoader = JsonLoader.new()
var _cards_by_id: Dictionary = {}
var _enemies_by_id: Dictionary = {}
var _rule_chains_by_id: Dictionary = {}
var _runs_by_id: Dictionary = {}


func load_all() -> void:
	_load_cards()
	_load_enemies()
	_load_rule_chains()
	_load_runs()


func get_run_definition(run_id: String) -> Dictionary:
	return _runs_by_id.get(run_id, {}).duplicate(true)


func get_enemy_definition(enemy_id: String) -> Dictionary:
	return _enemies_by_id.get(enemy_id, {}).duplicate(true)


func get_rule_chain_definitions(ids: Array) -> Array:
	var chains: Array = []
	for chain_id in ids:
		var definition: Dictionary = _rule_chains_by_id.get(String(chain_id), {})
		if not definition.is_empty():
			chains.append(definition.duplicate(true))
	return chains


func build_starting_deck(card_ids: Array) -> Array:
	var deck: Array = []
	var serial: int = 1
	for card_id in card_ids:
		var definition: Dictionary = _cards_by_id.get(String(card_id), {})
		if definition.is_empty():
			continue
		deck.append(CardInstance.create_from_definition(definition, serial))
		serial += 1
	return deck


func _load_cards() -> void:
	_cards_by_id.clear()
	for file_path in _list_json_files("res://data/cards"):
		var payload: Dictionary = _json_loader.load_json(file_path)
		for definition in payload.get("cards", []):
			_cards_by_id[String(definition.get("id", ""))] = definition.duplicate(true)


func _load_enemies() -> void:
	_enemies_by_id.clear()
	for file_path in _list_json_files("res://data/enemies"):
		var definition: Dictionary = _json_loader.load_json(file_path)
		if not definition.is_empty():
			_enemies_by_id[String(definition.get("id", ""))] = definition.duplicate(true)


func _load_rule_chains() -> void:
	_rule_chains_by_id.clear()
	for file_path in _list_json_files("res://data/rule_chains"):
		var payload: Dictionary = _json_loader.load_json(file_path)
		for definition in payload.get("rule_chains", []):
			_rule_chains_by_id[String(definition.get("id", ""))] = definition.duplicate(true)


func _load_runs() -> void:
	_runs_by_id.clear()
	for file_path in _list_json_files("res://data/runs"):
		var definition: Dictionary = _json_loader.load_json(file_path)
		if not definition.is_empty():
			_runs_by_id[String(definition.get("id", ""))] = definition.duplicate(true)


func _list_json_files(dir_path: String) -> Array:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error("Missing content directory: %s" % dir_path)
		return []

	var files: Array = []
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if dir.current_is_dir():
			continue
		if entry.get_extension() != "json":
			continue
		files.append("%s/%s" % [dir_path, entry])
	dir.list_dir_end()
	files.sort()
	return files