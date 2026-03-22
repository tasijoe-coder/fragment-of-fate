extends RefCounted
class_name JsonLoader


func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing JSON file: %s" % path)
		return {}

	var raw_text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw_text)
	if parsed == null:
		push_error("Failed to parse JSON: %s" % path)
		return {}

	return parsed
