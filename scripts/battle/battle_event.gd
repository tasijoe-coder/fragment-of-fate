extends RefCounted
class_name BattleEvent

const TYPE_LABELS: Dictionary = {
	"battle_started": "戰鬥開始",
	"turn_started": "回合開始",
	"card_played": "出牌請求",
	"effect_requested": "效果請求",
	"turn_ended": "回合結束",
	"enemy_action_requested": "敵方行動請求",
}

const SOURCE_LABELS: Dictionary = {
	"system": "系統",
	"player": "玩家",
	"enemy": "敵人",
}

const EFFECT_LABELS: Dictionary = {
	"attack": "攻擊",
	"gain_combo": "獲得連擊",
	"draw": "抽牌",
}

var type: StringName = &""
var source: StringName = &""
var payload: Dictionary = {}


static func create(event_type: Variant, event_source: Variant, event_payload: Dictionary = {}) -> BattleEvent:
	var event: BattleEvent = BattleEvent.new()
	event.type = StringName(String(event_type))
	event.source = StringName(String(event_source))
	event.payload = event_payload.duplicate(true)
	return event


func describe() -> String:
	var type_key: String = String(type)
	var source_key: String = String(source)
	var text: String = "%s <- %s" % [
		String(TYPE_LABELS.get(type_key, type_key)),
		String(SOURCE_LABELS.get(source_key, source_key)),
	]

	if payload.has("instance_id"):
		text += " | 卡牌=%s" % String(payload.get("instance_id", ""))

	if payload.has("card_instance_id"):
		text += " | 卡牌=%s" % String(payload.get("card_instance_id", ""))

	if payload.has("damage"):
		text += " | 傷害=%d" % int(payload.get("damage", 0))

	if payload.has("effect"):
		var effect: Dictionary = payload.get("effect", {})
		var effect_key: String = String(effect.get("type", "unknown"))
		text += " | 效果=%s" % String(EFFECT_LABELS.get(effect_key, effect_key))

	if payload.has("card"):
		var card: Dictionary = payload.get("card", {})
		text += " | %s" % String(card.get("name", "未知卡牌"))

	return text
