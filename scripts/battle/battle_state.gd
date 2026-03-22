extends RefCounted
class_name BattleState

var player_name: String = ""
var player_hp: int = 0
var player_max_hp: int = 0
var player_energy: int = 0
var player_max_energy: int = 0
var player_block: int = 0
var player_combo: int = 0

var enemy_id: String = ""
var enemy_name: String = ""
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_block: int = 0
var enemy_intent_index: int = 0
var enemy_intent: Dictionary = {}
var enemy_intent_cycle: Array = []

var encounter_name: String = ""
var draw_per_turn: int = 5
var turn_number: int = 0
var phase: String = "boot"
var battle_over: bool = false
var winner: String = ""

var active_rule_chains: Array = []
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

var turn_summary: Dictionary = {
	"cards_played": 0,
	"damage_dealt": 0,
	"damage_taken": 0,
	"combo_peak": 0,
}

var debug: Dictionary = {
	"event_counter": 0,
	"queue_depth": 0,
	"last_event": "",
	"last_cue": "",
}


func find_card_in_hand(instance_id: String):
	for card in hand:
		if card.instance_id == instance_id:
			return card
	return null


func snapshot() -> Dictionary:
	var hand_view: Array = []
	for card in hand:
		hand_view.append(card.to_view_model())

	var rule_summaries: Array = []
	for chain in active_rule_chains:
		rule_summaries.append(String(chain.get("summary", String(chain.get("id", "規則")))))

	return {
		"player": {
			"name": player_name,
			"hp": player_hp,
			"max_hp": player_max_hp,
			"energy": player_energy,
			"max_energy": player_max_energy,
			"block": player_block,
			"combo": player_combo,
		},
		"enemy": {
			"id": enemy_id,
			"name": enemy_name,
			"hp": enemy_hp,
			"max_hp": enemy_max_hp,
			"block": enemy_block,
			"intent": enemy_intent.duplicate(true),
		},
		"turn_number": turn_number,
		"phase": phase,
		"battle_over": battle_over,
		"winner": winner,
		"encounter_name": encounter_name,
		"hand": hand_view,
		"draw_count": draw_pile.size(),
		"discard_count": discard_pile.size(),
		"turn_summary": turn_summary.duplicate(true),
		"debug": debug.duplicate(true),
		"rules": rule_summaries,
	}


func to_debug_string() -> String:
	var intent_label: String = String(enemy_intent.get("label", "-"))
	var lines: Array = [
		"階段：%s" % phase,
		"回合：%d" % turn_number,
		"敵方意圖：%s" % intent_label,
		"手牌 / 抽牌堆 / 棄牌堆：%d / %d / %d" % [hand.size(), draw_pile.size(), discard_pile.size()],
		"已出牌：%d" % int(turn_summary.get("cards_played", 0)),
		"造成 / 承受傷害：%d / %d" % [int(turn_summary.get("damage_dealt", 0)), int(turn_summary.get("damage_taken", 0))],
		"最高連擊：%d" % int(turn_summary.get("combo_peak", 0)),
		"事件編號：%d | 佇列：%d" % [int(debug.get("event_counter", 0)), int(debug.get("queue_depth", 0))],
	]
	return "\n".join(PackedStringArray(lines))
