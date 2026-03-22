extends RefCounted
class_name CardInstance

var instance_id: String = ""
var card_id: String = ""
var name: String = ""
var cost: int = 0
var text: String = ""
var summary_rows: Array = []
var detail_text: String = ""
var tags: Array = []
var effects: Array = []


static func create_from_definition(definition: Dictionary, serial: int) -> CardInstance:
	var card: CardInstance = CardInstance.new()
	card.card_id = String(definition.get("id", ""))
	card.instance_id = "%s_%d" % [card.card_id, serial]
	card.name = String(definition.get("name", "Card"))
	card.cost = int(definition.get("cost", 0))
	card.text = String(definition.get("text", ""))
	card.summary_rows = definition.get("summary_rows", []).duplicate(true)
	card.detail_text = String(definition.get("detail_text", card.text))
	card.tags = definition.get("tags", []).duplicate(true)
	card.effects = definition.get("effects", []).duplicate(true)
	return card


func has_tag(tag_name: String) -> bool:
	return tags.has(tag_name)


func to_view_model() -> Dictionary:
	return {
		"instance_id": instance_id,
		"card_id": card_id,
		"name": name,
		"cost": cost,
		"text": text,
		"summary_rows": summary_rows.duplicate(true),
		"detail_text": detail_text,
		"tags": tags.duplicate(true),
		"effects": effects.duplicate(true),
	}