extends RefCounted
class_name RuleEvaluator

const BattleTuning := preload("res://scripts/battle/battle_tuning.gd")


func evaluate(state: BattleState, event: BattleEvent) -> Dictionary:
	var output: Dictionary = _empty_output()
	if state.battle_over and String(event.type) != "battle_started":
		return output

	match String(event.type):
		"battle_started":
			_on_battle_started(event, output)
		"turn_started":
			_on_turn_started(state, output)
		"card_played":
			_on_card_played(state, event, output)
		"effect_requested":
			_on_effect_requested(state, event, output)
		"turn_ended":
			_on_turn_ended(state, output)
		"enemy_action_requested":
			_on_enemy_action_requested(state, output)
		_:
			output.logs.append("尚未處理事件：%s。" % String(event.type))

	return output


func _on_battle_started(event: BattleEvent, output: Dictionary) -> void:
	var setup: Dictionary = event.payload.get("setup", {})
	if setup.is_empty():
		output.logs.append("戰鬥初始化略過：缺少 setup。")
		return

	output.ops.append({
		"type": "setup_battle",
		"setup": setup,
	})
	_push_event(output, "turn_started", "system")
	output.logs.append("已建立單場戰鬥初始化事件。")


func _on_turn_started(state: BattleState, output: Dictionary) -> void:
	output.ops.append({"type": "advance_turn"})
	output.ops.append({"type": "set_phase", "value": "player_turn"})
	output.ops.append({"type": "set_energy", "value": state.player_max_energy})
	output.ops.append({"type": "set_combo", "value": 0})
	output.ops.append({"type": "reset_turn_summary"})
	output.ops.append({
		"type": "draw_cards",
		"value": max(0, state.draw_per_turn - state.hand.size()),
	})
	output.cues.append({"type": "turn_started"})
	output.logs.append("玩家回合開始。")


func _on_card_played(state: BattleState, event: BattleEvent, output: Dictionary) -> void:
	if state.phase != "player_turn":
		output.cues.append({
			"type": "action_locked",
			"reason": "not_player_turn",
			"card_instance_id": String(event.payload.get("card_instance_id", "")),
		})
		output.logs.append("目前不是玩家回合，出牌要求已忽略。")
		return

	var card_instance_id: String = String(event.payload.get("card_instance_id", ""))
	var card: CardInstance = state.find_card_in_hand(card_instance_id)
	if card == null:
		output.logs.append("找不到手牌：%s。" % card_instance_id)
		return

	if state.player_energy < card.cost:
		output.cues.append({
			"type": "insufficient_energy",
			"card_instance_id": card.instance_id,
			"needed": card.cost,
			"available": state.player_energy,
		})
		output.logs.append("%s 所需能量不足。" % card.name)
		return

	output.ops.append({"type": "set_energy", "value": state.player_energy - card.cost})
	output.ops.append({
		"type": "move_card",
		"from": "hand",
		"to": "discard",
		"card_instance_id": card.instance_id,
	})
	output.ops.append({"type": "increment_turn_stat", "stat": "cards_played", "value": 1})
	output.cues.append({
		"type": "card_committed",
		"card_instance_id": card.instance_id,
		"card_name": card.name,
	})

	for effect in card.effects:
		_push_event(output, "effect_requested", "player", {
			"card_instance_id": card.instance_id,
			"card": card.to_view_model(),
			"effect": effect.duplicate(true),
		})

	output.logs.append("已將 %s 的 %d 個效果送入事件管線。" % [card.name, card.effects.size()])


func _on_effect_requested(state: BattleState, event: BattleEvent, output: Dictionary) -> void:
	var effect: Dictionary = event.payload.get("effect", {})
	var card: Dictionary = event.payload.get("card", {})
	if effect.is_empty():
		return

	match String(effect.get("type", "")):
		"gain_combo":
			var combo_amount: int = int(effect.get("amount", 0))
			output.ops.append({"type": "add_combo", "value": combo_amount})
			output.ops.append({"type": "record_combo_peak"})
			output.cues.append({
				"type": "combo_gain",
				"amount": combo_amount,
				"card_instance_id": String(event.payload.get("card_instance_id", "")),
			})
			output.logs.append("獲得 %d 點連擊。" % combo_amount)
		"draw":
			var draw_amount: int = int(effect.get("amount", 0))
			output.ops.append({"type": "draw_cards", "value": draw_amount})
			output.cues.append({
				"type": "draw_cards",
				"amount": draw_amount,
			})
			output.logs.append("已安排抽 %d 張牌。" % draw_amount)
		"attack":
			_resolve_attack_effect(state, event, card, effect, output)
		_:
			output.logs.append("尚未支援的效果類型：%s。" % String(effect.get("type", "未知")))


func _on_turn_ended(state: BattleState, output: Dictionary) -> void:
	if state.phase != "player_turn":
		output.cues.append({"type": "action_locked", "reason": "turn_already_ending"})
		output.logs.append("目前不是玩家行動階段，結束回合要求已忽略。")
		return

	output.ops.append({"type": "set_phase", "value": "enemy_turn"})
	output.ops.append({"type": "discard_hand"})
	output.ops.append({"type": "set_combo", "value": 0})
	_push_event(output, "enemy_action_requested", "enemy")
	output.logs.append("已安排敵方行動。")


func _on_enemy_action_requested(state: BattleState, output: Dictionary) -> void:
	var intent: Dictionary = state.enemy_intent
	if intent.is_empty():
		output.logs.append("敵方意圖為空，略過敵方行動。")
		_push_event(output, "turn_started", "system")
		return

	var projected_player_hp: int = state.player_hp
	var projected_player_block: int = state.player_block
	var intent_type: String = String(intent.get("type", ""))

	match intent_type:
		"block":
			var block_amount: int = int(intent.get("block", 0))
			output.ops.append({"type": "set_enemy_block", "value": state.enemy_block + block_amount})
			output.cues.append({
				"type": "block_gain",
				"target": "enemy",
				"amount": block_amount,
				"label": "防禦",
			})
			output.logs.append("敵人獲得 %d 點防禦。" % block_amount)
		"attack":
			var attack_resolution: Dictionary = _resolve_damage_packets(
				state.player_block,
				state.player_hp,
				int(intent.get("damage", 0)),
				1,
				String(intent.get("label", "攻擊"))
			)
			projected_player_hp = int(attack_resolution.get("final_hp", state.player_hp))
			projected_player_block = int(attack_resolution.get("final_block", state.player_block))
			output.ops.append({"type": "set_player_block", "value": projected_player_block})
			output.ops.append({"type": "set_player_hp", "value": projected_player_hp})
			output.ops.append({"type": "increment_turn_stat", "stat": "damage_taken", "value": int(attack_resolution.get("total_hp_damage", 0))})
			output.cues.append({
				"type": "attack_sequence",
				"source": "enemy",
				"target": "player",
				"card_name": String(intent.get("label", "攻擊")),
				"card_instance_id": "",
				"hits": attack_resolution.get("hits", []).duplicate(true),
				"total_hp_damage": int(attack_resolution.get("total_hp_damage", 0)),
				"total_absorbed": int(attack_resolution.get("total_absorbed", 0)),
				"interval_seconds": BattleTuning.CHAIN_INTERVAL,
			})
			output.logs.append("敵方攻擊已結算。")
		"block_attack":
			var guard_amount: int = int(intent.get("block", 0))
			output.ops.append({"type": "set_enemy_block", "value": state.enemy_block + guard_amount})
			output.cues.append({
				"type": "block_gain",
				"target": "enemy",
				"amount": guard_amount,
				"label": "防禦",
			})
			var guarded_attack: Dictionary = _resolve_damage_packets(
				state.player_block,
				state.player_hp,
				int(intent.get("damage", 0)),
				1,
				String(intent.get("label", "攻擊"))
			)
			projected_player_hp = int(guarded_attack.get("final_hp", state.player_hp))
			projected_player_block = int(guarded_attack.get("final_block", state.player_block))
			output.ops.append({"type": "set_player_block", "value": projected_player_block})
			output.ops.append({"type": "set_player_hp", "value": projected_player_hp})
			output.ops.append({"type": "increment_turn_stat", "stat": "damage_taken", "value": int(guarded_attack.get("total_hp_damage", 0))})
			output.cues.append({
				"type": "attack_sequence",
				"source": "enemy",
				"target": "player",
				"card_name": String(intent.get("label", "攻擊")),
				"card_instance_id": "",
				"hits": guarded_attack.get("hits", []).duplicate(true),
				"total_hp_damage": int(guarded_attack.get("total_hp_damage", 0)),
				"total_absorbed": int(guarded_attack.get("total_absorbed", 0)),
				"interval_seconds": BattleTuning.CHAIN_INTERVAL,
			})
			output.logs.append("敵方防禦與攻擊已結算。")
		_:
			output.logs.append("尚未支援的敵方意圖類型：%s。" % intent_type)

	output.ops.append({"type": "advance_enemy_intent"})
	if projected_player_hp > 0:
		_push_event(output, "turn_started", "system")


func _resolve_attack_effect(state: BattleState, event: BattleEvent, card: Dictionary, effect: Dictionary, output: Dictionary) -> void:
	var chain_context: Dictionary = _apply_rule_chains(state, card, effect)
	var combo_gain_before: int = int(chain_context.get("combo_gain_before", 0))
	if combo_gain_before > 0:
		output.ops.append({"type": "add_combo", "value": combo_gain_before})
		output.ops.append({"type": "record_combo_peak"})
		output.cues.append({
			"type": "combo_gain",
			"amount": combo_gain_before,
			"card_instance_id": String(event.payload.get("card_instance_id", "")),
		})

	var base_damage: int = int(effect.get("base_damage", 0))
	var damage_bonus: int = int(chain_context.get("damage_bonus", 0))
	var damage_per_hit: int = base_damage + damage_bonus
	var hits: int = max(1, int(effect.get("hits", 1)))
	var damage_resolution: Dictionary = _resolve_damage_packets(
		state.enemy_block,
		state.enemy_hp,
		damage_per_hit,
		hits,
		String(card.get("name", "攻擊"))
	)
	output.ops.append({"type": "set_enemy_block", "value": int(damage_resolution.get("final_block", state.enemy_block))})
	output.ops.append({"type": "set_enemy_hp", "value": int(damage_resolution.get("final_hp", state.enemy_hp))})
	output.ops.append({"type": "increment_turn_stat", "stat": "damage_dealt", "value": int(damage_resolution.get("total_hp_damage", 0))})
	output.cues.append({
		"type": "attack_sequence",
		"source": "player",
		"target": "enemy",
		"card_name": String(card.get("name", "攻擊")),
		"card_instance_id": String(event.payload.get("card_instance_id", "")),
		"hits": damage_resolution.get("hits", []).duplicate(true),
		"total_hp_damage": int(damage_resolution.get("total_hp_damage", 0)),
		"total_absorbed": int(damage_resolution.get("total_absorbed", 0)),
		"interval_seconds": BattleTuning.CHAIN_COMPRESSED_INTERVAL if hits >= BattleTuning.CHAIN_COMPRESS_HIT_THRESHOLD else BattleTuning.CHAIN_INTERVAL,
		"momentum": String(effect.get("momentum", "strike")),
	})
	output.logs.append("%s 已結算，總共造成 %d 點生命傷害。" % [String(card.get("name", "攻擊")), int(damage_resolution.get("total_hp_damage", 0))])


func _apply_rule_chains(state: BattleState, card: Dictionary, effect: Dictionary) -> Dictionary:
	var context: Dictionary = {
		"combo_gain_before": 0,
		"damage_bonus": 0,
	}

	for chain in state.active_rule_chains:
		if String(chain.get("trigger", "")) != "effect_requested":
			continue

		var applies_to: Dictionary = chain.get("applies_to", {})
		if String(applies_to.get("effect_type", "")) != String(effect.get("type", "")):
			continue

		var tags_any: Array = applies_to.get("tags_any", [])
		if not tags_any.is_empty() and not _card_matches_any_tag(card, tags_any):
			continue

		for modifier in chain.get("modifiers", []):
			match String(modifier.get("type", "")):
				"gain_combo_before_attack":
					context["combo_gain_before"] += int(effect.get(String(modifier.get("field", "combo_gain_before")), 0))
				"scale_attack_damage_from_combo":
					var combo_after_gain: int = state.player_combo + int(context.get("combo_gain_before", 0))
					var combo_offset: int = int(modifier.get("combo_offset", 0))
					var combo_scale: int = int(effect.get(String(modifier.get("field", "combo_scale")), 0))
					context["damage_bonus"] += max(combo_after_gain - combo_offset, 0) * combo_scale

	return context


func _resolve_damage_packets(start_block: int, start_hp: int, damage_per_hit: int, hits: int, label: String) -> Dictionary:
	var current_block: int = start_block
	var current_hp: int = start_hp
	var total_hp_damage: int = 0
	var total_absorbed: int = 0
	var packets: Array = []

	for hit_index in range(hits):
		var absorbed: int = min(current_block, damage_per_hit)
		current_block -= absorbed
		var hp_damage: int = max(0, damage_per_hit - absorbed)
		current_hp = max(0, current_hp - hp_damage)
		total_hp_damage += hp_damage
		total_absorbed += absorbed
		packets.append({
			"index": hit_index,
			"label": label,
			"damage": damage_per_hit,
			"absorbed": absorbed,
			"hp_damage": hp_damage,
			"block_after": current_block,
			"hp_after": current_hp,
		})

	return {
		"hits": packets,
		"final_block": current_block,
		"final_hp": current_hp,
		"total_hp_damage": total_hp_damage,
		"total_absorbed": total_absorbed,
	}


func _card_matches_any_tag(card: Dictionary, tags_any: Array) -> bool:
	var card_tags: Array = card.get("tags", [])
	for tag_name in tags_any:
		if card_tags.has(tag_name):
			return true
	return false


func _push_event(output: Dictionary, event_type: String, source: String, payload: Dictionary = {}) -> void:
	output.events.append(BattleEvent.create(event_type, source, payload))


func _empty_output() -> Dictionary:
	return {
		"ops": [],
		"events": [],
		"cues": [],
		"logs": [],
	}
