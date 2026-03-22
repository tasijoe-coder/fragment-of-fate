extends Control

signal battle_finished(result)

const BattleEvent := preload("res://scripts/battle/battle_event.gd")
const BattleState := preload("res://scripts/battle/battle_state.gd")
const RuleEvaluator := preload("res://scripts/battle/rule_evaluator.gd")
const BattleTuning := preload("res://scripts/battle/battle_tuning.gd")

var _state: BattleState = BattleState.new()
var _rule_evaluator: RuleEvaluator = RuleEvaluator.new()
var _event_queue: Array = []
var _processing_events: bool = false
var _event_log_lines: Array = []
var _card_views: Dictionary = {}
var _card_base_positions: Dictionary = {}
var _card_launch_points: Dictionary = {}
var _active_total_labels: Dictionary = {}
var _active_attack_ghosts: Dictionary = {}
var _managed_tweens: Array = []
var _channel_tweens: Dictionary = {}
var _attack_sequence_ids: Dictionary = {
	"player": 0,
	"enemy": 0,
}
var _anchor_base_positions: Dictionary = {}
var _battle_ready: bool = false
var _battle_finished_emitted: bool = false
var _hovered_card_id: String = ""

@onready var _player_name_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerNameLabel
@onready var _player_hp_bar: ProgressBar = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerHpBar
@onready var _player_hp_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerHpLabel
@onready var _player_energy_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerEnergyLabel
@onready var _player_combo_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerComboLabel
@onready var _player_block_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/LeftInfo/PlayerBlockLabel

@onready var _encounter_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/CenterInfo/CenterInfoVBox/EncounterLabel
@onready var _status_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/CenterInfo/CenterInfoVBox/StatusLabel
@onready var _enemy_intent_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/CenterInfo/CenterInfoVBox/EnemyIntentLabel
@onready var _end_turn_button: Button = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/CenterInfo/CenterInfoVBox/ControlsRow/EndTurnButton

@onready var _enemy_name_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/RightInfo/EnemyNameLabel
@onready var _enemy_hp_bar: ProgressBar = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/RightInfo/EnemyHpBar
@onready var _enemy_hp_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/RightInfo/EnemyHpLabel
@onready var _enemy_block_label: Label = $MarginContainer/RootVBox/HeaderPanel/HeaderHBox/RightInfo/EnemyBlockLabel

@onready var _player_anchor: PanelContainer = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/BattlefieldLayout/BattlefieldVBox/PlayerRow/PlayerAnchor
@onready var _enemy_anchor: PanelContainer = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/BattlefieldLayout/BattlefieldVBox/EnemyRow/EnemyAnchor
@onready var _attack_fx_layer: Control = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/AttackFxLayer
@onready var _damage_fx_layer: Control = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/DamageFxLayer
@onready var _total_fx_layer: Control = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/TotalFxLayer

@onready var _card_detail_title_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/CardDetailTitleLabel
@onready var _card_detail_name_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/CardDetailNameLabel
@onready var _card_detail_body_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/CardDetailBodyLabel
@onready var _rule_summary_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/RuleSummaryLabel
@onready var _state_debug_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/StateDebugLabel
@onready var _event_log_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/EventLogLabel
@onready var _rule_title_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/RuleTitleLabel
@onready var _state_title_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/StateTitleLabel
@onready var _log_title_label: Label = $MarginContainer/RootVBox/BodyHBox/DebugPanel/DebugScroll/DebugVBox/LogTitleLabel

@onready var _hand_header_label: Label = $MarginContainer/RootVBox/HandPanel/HandVBox/HandHeaderLabel
@onready var _hand_scroll: ScrollContainer = $MarginContainer/RootVBox/HandPanel/HandVBox/HandScroll
@onready var _hand_area: Control = $MarginContainer/RootVBox/HandPanel/HandVBox/HandScroll/HandArea
@onready var _board_panel: PanelContainer = $MarginContainer/RootVBox/BodyHBox/BoardPanel
@onready var _debug_panel: PanelContainer = $MarginContainer/RootVBox/BodyHBox/DebugPanel
@onready var _hand_panel: PanelContainer = $MarginContainer/RootVBox/HandPanel
@onready var _player_anchor_label: Label = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/BattlefieldLayout/BattlefieldVBox/PlayerRow/PlayerAnchor/PlayerAnchorLabel
@onready var _enemy_anchor_label: Label = $MarginContainer/RootVBox/BodyHBox/BoardPanel/BoardRoot/BattlefieldLayout/BattlefieldVBox/EnemyRow/EnemyAnchor/EnemyAnchorLabel


func _ready() -> void:
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	resized.connect(_on_layout_resized)
	_end_turn_button.disabled = true
	_anchor_base_positions = {
		"player": _player_anchor.position,
		"enemy": _enemy_anchor.position,
	}
	_attack_fx_layer.z_index = BattleTuning.FX_LAYER_Z_ATTACK
	_total_fx_layer.z_index = BattleTuning.FX_LAYER_Z_TOTAL
	_damage_fx_layer.z_index = BattleTuning.FX_LAYER_Z_DAMAGE
	_configure_playable_ui()
	call_deferred("_refresh_layout_after_resize")


func _configure_playable_ui() -> void:
	_hand_panel.custom_minimum_size = Vector2(0, BattleTuning.HAND_PANEL_HEIGHT)
	_hand_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_hand_scroll.custom_minimum_size = Vector2(0, BattleTuning.HAND_AREA_HEIGHT)
	_hand_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_hand_area.custom_minimum_size = Vector2(0, BattleTuning.HAND_AREA_HEIGHT)
	_board_panel.custom_minimum_size = Vector2(0, BattleTuning.BOARD_PANEL_MIN_HEIGHT)
	_debug_panel.custom_minimum_size = Vector2(BattleTuning.DEBUG_PANEL_WIDTH, 0)
	_end_turn_button.custom_minimum_size = BattleTuning.HUD_END_TURN_BUTTON_SIZE
	_end_turn_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_player_hp_bar.custom_minimum_size = Vector2(0, BattleTuning.HUD_BAR_HEIGHT)
	_enemy_hp_bar.custom_minimum_size = Vector2(0, BattleTuning.HUD_BAR_HEIGHT)
	_set_control_font(_player_name_label, BattleTuning.HUD_SECTION_TITLE_SIZE)
	_set_control_font(_enemy_name_label, BattleTuning.HUD_SECTION_TITLE_SIZE)
	_set_control_font(_encounter_label, BattleTuning.HUD_SECTION_TITLE_SIZE)
	_set_control_font(_player_hp_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_player_energy_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_player_combo_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_player_block_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_enemy_hp_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_enemy_block_label, BattleTuning.HUD_STAT_FONT_SIZE)
	_set_control_font(_status_label, BattleTuning.HUD_STATUS_FONT_SIZE)
	_set_control_font(_enemy_intent_label, BattleTuning.HUD_STATUS_FONT_SIZE)
	_set_control_font(_hand_header_label, BattleTuning.HAND_HEADER_FONT_SIZE)
	_set_control_font(_end_turn_button, BattleTuning.HUD_BUTTON_FONT_SIZE)
	_set_control_font(_player_anchor_label, BattleTuning.HUD_ANCHOR_FONT_SIZE)
	_set_control_font(_enemy_anchor_label, BattleTuning.HUD_ANCHOR_FONT_SIZE)
	_set_control_font(_card_detail_title_label, BattleTuning.CARD_DETAIL_TITLE_SIZE)
	_set_control_font(_card_detail_name_label, BattleTuning.CARD_DETAIL_NAME_SIZE)
	_set_control_font(_card_detail_body_label, BattleTuning.CARD_DETAIL_BODY_SIZE)
	_set_control_font(_rule_title_label, BattleTuning.DEBUG_TITLE_FONT_SIZE)
	_set_control_font(_state_title_label, BattleTuning.DEBUG_TITLE_FONT_SIZE)
	_set_control_font(_log_title_label, BattleTuning.DEBUG_TITLE_FONT_SIZE)
	_set_control_font(_rule_summary_label, BattleTuning.DEBUG_FONT_SIZE)
	_set_control_font(_state_debug_label, BattleTuning.DEBUG_FONT_SIZE)
	_set_control_font(_event_log_label, BattleTuning.DEBUG_FONT_SIZE)
	_debug_panel.modulate = BattleTuning.DEBUG_PANEL_MODULATE
	_clear_card_detail_panel()


func _on_layout_resized() -> void:
	call_deferred("_refresh_layout_after_resize")


func _refresh_layout_after_resize() -> void:
	if not is_inside_tree():
		return
	_anchor_base_positions = {
		"player": _player_anchor.position,
		"enemy": _enemy_anchor.position,
	}
	if _battle_ready and not _processing_events:
		_refresh_ui()


func _set_control_font(control: Control, font_size: int) -> void:
	control.add_theme_font_size_override("font_size", font_size)


func _exit_tree() -> void:
	_battle_ready = false
	_invalidate_attack_sequences()
	_kill_managed_tweens()


func start_battle(setup: Dictionary) -> void:
	_battle_ready = true
	_battle_finished_emitted = false
	_hovered_card_id = ""
	_event_queue.clear()
	_event_log_lines.clear()
	_card_views.clear()
	_card_base_positions.clear()
	_card_launch_points.clear()
	_reset_presentation_state()
	_state = BattleState.new()
	_append_log("戰鬥初始化完成。")
	_queue_event(BattleEvent.create("battle_started", "system", {"setup": setup}))
	_refresh_ui()


func _queue_event(event: BattleEvent) -> void:
	_event_queue.append(event)
	if _processing_events:
		return

	_processing_events = true
	while not _event_queue.is_empty():
		var next_event: BattleEvent = _event_queue.pop_front()
		apply_event_result({
			"type": "update_debug",
			"fields": {
				"event_counter": int(_state.debug.get("event_counter", 0)) + 1,
				"queue_depth": _event_queue.size(),
				"last_event": next_event.describe(),
			}
		})
		_append_log("[事件] %s" % next_event.describe())

		var evaluation: Dictionary = _rule_evaluator.evaluate(_state, next_event)
		for op in evaluation.get("ops", []):
			apply_event_result(op)
		for log_line in evaluation.get("logs", []):
			_append_log("  %s" % String(log_line))
		_refresh_ui()
		for cue in evaluation.get("cues", []):
			apply_event_result({
				"type": "update_debug",
				"fields": {"last_cue": String(cue.get("type", ""))},
			})
			_process_presentation_cue(cue)

		if _state.battle_over:
			_event_queue.clear()
			break

		for follow_up in evaluation.get("events", []):
			_event_queue.append(follow_up)

	_processing_events = false
	_refresh_ui()
	_maybe_emit_battle_finished()


func apply_event_result(result: Dictionary) -> void:
	match String(result.get("type", "")):
		"setup_battle":
			var setup: Dictionary = result.get("setup", {})
			var player: Dictionary = setup.get("player", {})
			var enemy: Dictionary = setup.get("enemy", {})
			_state.player_name = String(player.get("name", "?拙振"))
			_state.player_max_hp = int(player.get("max_hp", 0))
			_state.player_hp = int(player.get("max_hp", 0))
			_state.player_max_energy = int(player.get("max_energy", 0))
			_state.player_energy = 0
			_state.player_block = 0
			_state.player_combo = 0
			_state.enemy_id = String(enemy.get("id", "enemy"))
			_state.enemy_name = String(enemy.get("name", "?萎犖"))
			_state.encounter_name = _state.enemy_name
			_state.enemy_max_hp = int(enemy.get("max_hp", 0))
			_state.enemy_hp = int(enemy.get("max_hp", 0))
			_state.enemy_block = int(enemy.get("starting_block", 0))
			_state.enemy_intent_cycle = enemy.get("intent_cycle", []).duplicate(true)
			_state.enemy_intent_index = 0
			_state.enemy_intent = _state.enemy_intent_cycle[0].duplicate(true) if not _state.enemy_intent_cycle.is_empty() else {}
			_state.draw_per_turn = int(result.get("setup", {}).get("draw_per_turn", 5))
			_state.turn_number = 0
			_state.phase = "boot"
			_state.battle_over = false
			_state.winner = ""
			_state.active_rule_chains = setup.get("active_rule_chains", []).duplicate(true)
			_state.draw_pile = setup.get("starting_deck", []).duplicate()
			_state.hand = []
			_state.discard_pile = []
			_state.turn_summary = {
				"cards_played": 0,
				"damage_dealt": 0,
				"damage_taken": 0,
				"combo_peak": 0,
			}
			_state.debug = {
				"event_counter": 0,
				"queue_depth": 0,
				"last_event": "",
				"last_cue": "",
			}
		"advance_turn":
			_state.turn_number += 1
		"set_phase":
			_state.phase = String(result.get("value", ""))
		"set_energy":
			_state.player_energy = clampi(int(result.get("value", 0)), 0, _state.player_max_energy)
		"set_combo":
			_state.player_combo = max(0, int(result.get("value", 0)))
		"add_combo":
			_state.player_combo += max(0, int(result.get("value", 0)))
		"record_combo_peak":
			_state.turn_summary["combo_peak"] = max(int(_state.turn_summary.get("combo_peak", 0)), _state.player_combo)
		"reset_turn_summary":
			_state.turn_summary = {
				"cards_played": 0,
				"damage_dealt": 0,
				"damage_taken": 0,
				"combo_peak": _state.player_combo,
			}
		"draw_cards":
			_draw_cards(int(result.get("value", 0)))
		"move_card":
			var moved_card = _take_card_from_zone(_zone_for_name(String(result.get("from", ""))), String(result.get("card_instance_id", "")))
			if moved_card != null:
				_zone_for_name(String(result.get("to", ""))).append(moved_card)
		"discard_hand":
			while not _state.hand.is_empty():
				_state.discard_pile.append(_state.hand.pop_front())
		"set_enemy_hp":
			_state.enemy_hp = max(0, int(result.get("value", 0)))
			if _state.enemy_hp <= 0:
				_state.battle_over = true
				_state.winner = "player"
				_state.phase = "battle_over"
		"set_player_hp":
			_state.player_hp = max(0, int(result.get("value", 0)))
			if _state.player_hp <= 0:
				_state.battle_over = true
				_state.winner = "enemy"
				_state.phase = "battle_over"
		"set_enemy_block":
			_state.enemy_block = max(0, int(result.get("value", 0)))
		"set_player_block":
			_state.player_block = max(0, int(result.get("value", 0)))
		"advance_enemy_intent":
			if not _state.enemy_intent_cycle.is_empty():
				_state.enemy_intent_index = (_state.enemy_intent_index + 1) % _state.enemy_intent_cycle.size()
				_state.enemy_intent = _state.enemy_intent_cycle[_state.enemy_intent_index].duplicate(true)
		"increment_turn_stat":
			var stat_name: String = String(result.get("stat", ""))
			_state.turn_summary[stat_name] = int(_state.turn_summary.get(stat_name, 0)) + int(result.get("value", 0))
		"update_debug":
			for key in result.get("fields", {}).keys():
				_state.debug[key] = result.get("fields", {})[key]

func _draw_cards(amount: int) -> void:
	for _index in range(max(0, amount)):
		if _state.draw_pile.is_empty():
			if _state.discard_pile.is_empty():
				return
			while not _state.discard_pile.is_empty():
				_state.draw_pile.append(_state.discard_pile.pop_front())

		if _state.draw_pile.is_empty():
			return

		_state.hand.append(_state.draw_pile.pop_front())


func _zone_for_name(zone_name: String) -> Array:
	match zone_name:
		"hand":
			return _state.hand
		"draw":
			return _state.draw_pile
		"discard":
			return _state.discard_pile
		_:
			return []


func _take_card_from_zone(zone: Array, card_instance_id: String):
	for index in range(zone.size()):
		if zone[index].instance_id == card_instance_id:
			return zone.pop_at(index)
	return null


func _process_presentation_cue(cue: Dictionary) -> void:
	match String(cue.get("type", "")):
		"insufficient_energy":
			_present_insufficient_energy(cue)
		"combo_gain":
			_pulse_node(_player_combo_label, Color(0.82, 1.0, 0.82, 1.0))
		"draw_cards":
			_pulse_node(_hand_area, Color(0.82, 0.9, 1.0, 1.0))
		"block_gain":
			_present_block_gain(cue)
		"attack_sequence":
			_play_attack_sequence(cue)
		"turn_started":
			_pulse_node(_player_energy_label, Color(0.88, 0.95, 1.0, 1.0))


func _refresh_ui() -> void:
	if not _battle_ready:
		return

	var snapshot: Dictionary = _state.snapshot()
	var player: Dictionary = snapshot.get("player", {})
	var enemy: Dictionary = snapshot.get("enemy", {})

	_player_name_label.text = String(player.get("name", "命運編織者"))
	_player_hp_bar.max_value = max(1, float(player.get("max_hp", 1)))
	_player_hp_bar.value = float(player.get("hp", 0))
	_player_hp_label.text = "生命：%d / %d" % [int(player.get("hp", 0)), int(player.get("max_hp", 0))]
	_player_energy_label.text = "能量：%d / %d" % [int(player.get("energy", 0)), int(player.get("max_energy", 0))]
	_player_combo_label.text = "連擊：%d" % int(player.get("combo", 0))
	_player_block_label.text = "防禦：%d" % int(player.get("block", 0))

	_enemy_name_label.text = String(enemy.get("name", "敵人"))
	_enemy_hp_bar.max_value = max(1, float(enemy.get("max_hp", 1)))
	_enemy_hp_bar.value = float(enemy.get("hp", 0))
	_enemy_hp_label.text = "生命：%d / %d" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0))]
	_enemy_block_label.text = "防禦：%d" % int(enemy.get("block", 0))

	_encounter_label.text = "戰鬥：%s" % String(snapshot.get("encounter_name", "戰鬥"))
	_enemy_intent_label.text = _build_intent_text(enemy.get("intent", {}))
	_status_label.text = _build_status_text(snapshot)
	_rule_summary_label.text = "\n".join(PackedStringArray(snapshot.get("rules", [])))
	_state_debug_label.text = _state.to_debug_string()
	_event_log_label.text = "\n".join(PackedStringArray(_event_log_lines))
	_end_turn_button.disabled = _state.phase != "player_turn" or _state.battle_over
	_hand_header_label.text = "手牌（%d） | 抽牌堆 %d | 棄牌堆 %d" % [
		_state.hand.size(),
		int(snapshot.get("draw_count", 0)),
		int(snapshot.get("discard_count", 0)),
	]
	_rebuild_hand(snapshot.get("hand", []))
	_refresh_card_detail_panel(snapshot.get("hand", []))


func _build_status_text(snapshot: Dictionary) -> String:
	if bool(snapshot.get("battle_over", false)):
		return "戰鬥勝利" if String(snapshot.get("winner", "")) == "player" else "戰鬥失敗"

	match String(snapshot.get("phase", "boot")):
		"player_turn":
			return "先疊連擊，準備好再結束。"
		"enemy_turn":
			return "%s 行動中..." % _state.enemy_name
		_:
			return "戰鬥初始化中..."


func _build_intent_text(intent: Dictionary) -> String:
	if intent.is_empty():
		return "敵方意圖：無"

	var text: String = "敵方意圖：%s" % String(intent.get("label", "行動"))
	if intent.has("damage"):
		text += " | %d 傷害" % int(intent.get("damage", 0))
	if intent.has("block"):
		text += " | %d 防禦" % int(intent.get("block", 0))
	return text

func _rebuild_hand(hand_view: Array) -> void:
	for child in _hand_area.get_children():
		_hand_area.remove_child(child)
		child.queue_free()
	_card_views.clear()
	_card_base_positions.clear()

	var viewport_width: float = max(_hand_scroll.size.x, BattleTuning.HAND_CARD_WIDTH + BattleTuning.HAND_HORIZONTAL_PADDING * 2.0)
	_hand_area.custom_minimum_size = Vector2(viewport_width, BattleTuning.HAND_AREA_HEIGHT)
	_hand_area.size = _hand_area.custom_minimum_size

	if hand_view.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "目前沒有可用手牌。"
		empty_label.position = BattleTuning.HAND_EMPTY_LABEL_POSITION
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hand_area.add_child(empty_label)
		return

	var step_x: float = BattleTuning.HAND_CARD_SPACING
	var total_width: float = BattleTuning.HAND_CARD_WIDTH + step_x * float(max(0, hand_view.size() - 1))
	var content_width: float = max(viewport_width, total_width + BattleTuning.HAND_HORIZONTAL_PADDING * 2.0)
	var centered_offset: float = max(0.0, (viewport_width - (total_width + BattleTuning.HAND_HORIZONTAL_PADDING * 2.0)) * 0.5)
	var start_x: float = BattleTuning.HAND_HORIZONTAL_PADDING + centered_offset
	_hand_area.custom_minimum_size = Vector2(content_width, BattleTuning.HAND_AREA_HEIGHT)
	_hand_area.size = _hand_area.custom_minimum_size

	for index in range(hand_view.size()):
		var card: Dictionary = hand_view[index]
		var instance_id: String = String(card.get("instance_id", ""))
		var button: Button = Button.new()
		button.flat = false
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.disabled = false
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = _build_card_detail_text(card)
		button.size = Vector2(BattleTuning.HAND_CARD_WIDTH, BattleTuning.HAND_CARD_HEIGHT)
		button.custom_minimum_size = button.size
		button.position = Vector2(start_x + step_x * index, BattleTuning.HAND_START_Y)
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_on_card_mouse_entered.bind(instance_id))
		button.mouse_exited.connect(_on_card_mouse_exited.bind(instance_id))
		button.pressed.connect(_on_card_pressed.bind(instance_id))
		button.add_theme_stylebox_override("normal", _build_card_style(Color(0.15, 0.18, 0.24, 1.0), Color(0.34, 0.4, 0.48, 1.0)))
		button.add_theme_stylebox_override("hover", _build_card_style(Color(0.18, 0.22, 0.29, 1.0), Color(0.52, 0.6, 0.68, 1.0)))
		button.add_theme_stylebox_override("pressed", _build_card_style(Color(0.16, 0.19, 0.25, 1.0), Color(0.66, 0.74, 0.82, 1.0)))
		button.add_theme_stylebox_override("focus", _build_card_style(Color(0.18, 0.22, 0.29, 1.0), Color(0.52, 0.6, 0.68, 1.0)))

		var margin: MarginContainer = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.layout_mode = 1
		margin.anchors_preset = 15
		margin.anchor_right = 1.0
		margin.anchor_bottom = 1.0
		margin.grow_horizontal = 2
		margin.grow_vertical = 2
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		button.add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		var top_row: HBoxContainer = HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_theme_constant_override("separation", 12)
		vbox.add_child(top_row)

		var name_label: Label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.text = String(card.get("name", "卡牌"))
		name_label.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_TITLE_SIZE)
		top_row.add_child(name_label)

		var cost_label: Label = Label.new()
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.text = str(int(card.get("cost", 0)))
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_label.custom_minimum_size = Vector2(44, 34)
		cost_label.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_COST_SIZE)
		top_row.add_child(cost_label)

		var summary_box: VBoxContainer = VBoxContainer.new()
		summary_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		summary_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		summary_box.add_theme_constant_override("separation", BattleTuning.HAND_CARD_ROW_SEPARATION)
		vbox.add_child(summary_box)
		_populate_card_summary(summary_box, card)

		_hand_area.add_child(button)
		_card_views[instance_id] = {
			"button": button,
			"cost_label": cost_label,
			"card": card,
		}
		_card_base_positions[instance_id] = button.position

	_update_hand_focus_visuals()


func _populate_card_summary(summary_box: VBoxContainer, card: Dictionary) -> void:
	var summary_rows: Array = _build_card_summary_rows(card)
	if summary_rows.is_empty():
		var fallback_label: Label = Label.new()
		fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fallback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fallback_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fallback_label.text = String(card.get("text", ""))
		fallback_label.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_BODY_SIZE)
		summary_box.add_child(fallback_label)
		return

	for row_data in summary_rows:
		var row: Dictionary = row_data
		var label_text: String = String(row.get("label", "")).strip_edges()
		var value_text: String = String(row.get("value", "")).strip_edges()
		if label_text.is_empty():
			var single_line: Label = Label.new()
			single_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			single_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			single_line.text = value_text
			single_line.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_ROW_VALUE_SIZE)
			summary_box.add_child(single_line)
			continue

		var row_box: HBoxContainer = HBoxContainer.new()
		row_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_box.add_theme_constant_override("separation", 8)
		summary_box.add_child(row_box)

		var key_label: Label = Label.new()
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.text = label_text
		key_label.custom_minimum_size = Vector2(BattleTuning.HAND_CARD_ROW_KEY_WIDTH, BattleTuning.HAND_CARD_ROW_MIN_HEIGHT)
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.modulate = Color(0.76, 0.8, 0.88, 1.0)
		key_label.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_ROW_LABEL_SIZE)
		row_box.add_child(key_label)

		var value_label: Label = Label.new()
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.custom_minimum_size = Vector2(0, BattleTuning.HAND_CARD_ROW_MIN_HEIGHT)
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.text = value_text
		value_label.add_theme_font_size_override("font_size", BattleTuning.HAND_CARD_ROW_VALUE_SIZE)
		row_box.add_child(value_label)


func _build_card_summary_rows(card: Dictionary) -> Array:
	var rows: Array = card.get("summary_rows", [])
	if not rows.is_empty():
		return rows

	var fallback_rows: Array = []
	for raw_line in String(card.get("text", "")).split("\n", false):
		var line_text: String = String(raw_line).strip_edges()
		if line_text.is_empty():
			continue
		fallback_rows.append({"label": "", "value": line_text})
	return fallback_rows


func _build_card_detail_text(card: Dictionary) -> String:
	var detail_text: String = String(card.get("detail_text", "")).strip_edges()
	if not detail_text.is_empty():
		return detail_text
	return String(card.get("text", "")).strip_edges()


func _refresh_card_detail_panel(hand_view: Array) -> void:
	if _hovered_card_id.is_empty():
		_clear_card_detail_panel()
		return

	for card in hand_view:
		if String(card.get("instance_id", "")) == _hovered_card_id:
			_show_card_detail_panel(card)
			return

	_hovered_card_id = ""
	_clear_card_detail_panel()


func _show_card_detail_panel(card: Dictionary) -> void:
	_card_detail_name_label.text = "%s · %d 費" % [String(card.get("name", "卡牌")), int(card.get("cost", 0))]
	var detail_text: String = _build_card_detail_text(card)
	_card_detail_body_label.text = detail_text if not detail_text.is_empty() else "沒有額外說明。"


func _clear_card_detail_panel() -> void:
	_card_detail_name_label.text = "滑鼠懸停手牌"
	_card_detail_body_label.text = "查看完整效果說明。"


func _build_card_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	return style


func _update_hand_focus_visuals() -> void:
	for instance_id in _card_views.keys():
		var button: Button = _card_views[String(instance_id)]["button"]
		var is_hovered: bool = String(instance_id) == _hovered_card_id
		var any_hover: bool = not _hovered_card_id.is_empty()
		button.z_index = BattleTuning.HAND_HOVER_Z_INDEX if is_hovered else 0
		button.modulate = Color.WHITE if (is_hovered or not any_hover) else BattleTuning.HAND_UNFOCUSED_MODULATE
		button.position = _card_target_position(String(instance_id))
		button.scale = _card_target_scale(is_hovered, any_hover)



func _card_target_position(instance_id: String) -> Vector2:
	var base_position: Vector2 = _card_base_positions.get(instance_id, Vector2.ZERO)
	var lift: float = -BattleTuning.HAND_HOVER_LIFT if instance_id == _hovered_card_id else 0.0
	return base_position + Vector2(0, lift)


func _card_target_scale(is_hovered: bool, any_hover: bool) -> Vector2:
	if is_hovered:
		return Vector2.ONE * BattleTuning.HAND_HOVER_SCALE
	if any_hover:
		return Vector2.ONE * BattleTuning.HAND_UNFOCUSED_SCALE
	return Vector2.ONE

func _present_insufficient_energy(cue: Dictionary) -> void:
	var instance_id: String = String(cue.get("card_instance_id", ""))
	var view: Dictionary = _card_views.get(instance_id, {})
	if not view.is_empty():
		var button: Button = view["button"]
		var cost_label: Label = view["cost_label"]
		var original_position: Vector2 = _card_target_position(instance_id)
		button.position = original_position
		var shake: Tween = _create_managed_tween("card_shake:%s" % instance_id)
		shake.tween_property(button, "position", original_position + Vector2(BattleTuning.ENERGY_SHAKE_LEFT_DISTANCE, 0), BattleTuning.ENERGY_SHAKE_STEP_ONE)
		shake.tween_property(button, "position", original_position + Vector2(BattleTuning.ENERGY_SHAKE_RIGHT_DISTANCE, 0), BattleTuning.ENERGY_SHAKE_STEP_TWO)
		shake.tween_property(button, "position", original_position + Vector2(BattleTuning.ENERGY_SHAKE_RETURN_DISTANCE, 0), BattleTuning.ENERGY_SHAKE_STEP_THREE)
		shake.tween_property(button, "position", original_position, BattleTuning.ENERGY_SHAKE_STEP_FOUR)
		cost_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
		var label_tween: Tween = _create_managed_tween("card_cost:%s" % instance_id)
		label_tween.tween_property(cost_label, "modulate", Color.WHITE, BattleTuning.PULSE_FADE_TIME)

	_pulse_node(_player_energy_label, Color(1.0, 0.55, 0.55, 1.0))


func _present_block_gain(cue: Dictionary) -> void:
	var target: String = String(cue.get("target", "enemy"))
	var anchor_position: Vector2 = _anchor_center(_enemy_anchor if target == "enemy" else _player_anchor)
	_spawn_floating_text(anchor_position + Vector2(0, -24), "%s +%d" % [String(cue.get("label", "?脩戌")), int(cue.get("amount", 0))], Color(0.45, 0.72, 1.0, 1.0))
	_pulse_node(_enemy_anchor if target == "enemy" else _player_anchor, Color(0.78, 0.88, 1.0, 1.0))


func _play_attack_sequence(cue: Dictionary) -> void:
	var source: String = String(cue.get("source", "player"))
	var target: String = String(cue.get("target", "enemy"))
	var source_position: Vector2 = _anchor_center(_player_anchor)
	if source == "player":
		source_position = _card_launch_points.get(String(cue.get("card_instance_id", "")), _anchor_center(_player_anchor))
	else:
		source_position = _anchor_center(_enemy_anchor)

	var target_anchor: PanelContainer = _enemy_anchor if target == "enemy" else _player_anchor
	var target_position: Vector2 = _anchor_center(target_anchor)
	var hits: Array = cue.get("hits", [])
	var interval: float = float(cue.get("interval_seconds", BattleTuning.CHAIN_INTERVAL))
	var sequence_id: int = _begin_attack_sequence(target)
	_clear_total_label(target, true)
	_present_attack_ghost(target, source_position, target_position, String(cue.get("card_name", "?餅?")))
	_run_hit_sequence(target, sequence_id, target_anchor, target_position, hits, interval, cue)


func _present_attack_ghost(target: String, source_position: Vector2, target_position: Vector2, title: String) -> void:
	var existing = _active_attack_ghosts.get(target, null)
	if existing != null and is_instance_valid(existing):
		existing.queue_free()

	var ghost: Label = Label.new()
	ghost.text = title
	ghost.position = _to_layer_position(_attack_fx_layer, source_position)
	ghost.modulate = Color(1.0, 0.95, 0.86, 1.0)
	_attack_fx_layer.add_child(ghost)
	_active_attack_ghosts[target] = ghost
	var tween: Tween = _create_managed_tween("attack_ghost:%s" % target)
	tween.tween_property(ghost, "position", _to_layer_position(_attack_fx_layer, target_position), BattleTuning.ATTACK_FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		if is_instance_valid(ghost):
			ghost.queue_free()
		if _active_attack_ghosts.get(target) == ghost:
			_active_attack_ghosts.erase(target)
	)


func _run_hit_sequence(target: String, sequence_id: int, target_anchor: PanelContainer, target_position: Vector2, hits: Array, interval: float, cue: Dictionary) -> void:
	await get_tree().create_timer(BattleTuning.ATTACK_FLIGHT_TIME).timeout
	if not _is_attack_sequence_current(target, sequence_id):
		return

	for index in range(hits.size()):
		if not _is_attack_sequence_current(target, sequence_id):
			return

		var hit: Dictionary = hits[index]
		var absorbed: int = int(hit.get("absorbed", 0))
		var hp_damage: int = int(hit.get("hp_damage", 0))
		var hp_before: int = int(hit.get("hp_after", 0)) + hp_damage
		var block_before: int = int(hit.get("block_after", 0)) + absorbed
		_apply_visual_track_state(target, hp_before, block_before)
		_play_impact_motion(target, target_anchor, absorbed > 0 and hp_damage == 0)
		if absorbed > 0:
			_spawn_floating_text(target_position + Vector2(-18, -30), "?脩戌 %d" % absorbed, Color(0.45, 0.72, 1.0, 1.0))
			if hp_damage > 0:
				await get_tree().create_timer(BattleTuning.BLOCK_TO_HP_GAP).timeout
				if not _is_attack_sequence_current(target, sequence_id):
					return
		if hp_damage > 0:
			_spawn_floating_text(target_position + Vector2(20, -44), str(hp_damage), Color(1.0, 0.46, 0.46, 1.0))
		_animate_visual_tracks(target, int(hit.get("hp_after", 0)), int(hit.get("block_after", 0)))

		if index < hits.size() - 1:
			await get_tree().create_timer(interval).timeout
			if not _is_attack_sequence_current(target, sequence_id):
				return

	if _is_attack_sequence_current(target, sequence_id):
		_show_total_label(target, target_position, cue)

func _apply_visual_track_state(target: String, hp_value: int, block_value: int) -> void:
	if target == "enemy":
		_enemy_hp_bar.value = hp_value
		_enemy_hp_label.text = "生命：%d / %d" % [hp_value, _state.enemy_max_hp]
		_enemy_block_label.text = "防禦：%d" % block_value
	else:
		_player_hp_bar.value = hp_value
		_player_hp_label.text = "生命：%d / %d" % [hp_value, _state.player_max_hp]
		_player_block_label.text = "防禦：%d" % block_value


func _animate_visual_tracks(target: String, hp_after: int, block_after: int) -> void:
	if target == "enemy":
		var tween: Tween = _create_managed_tween("hp_track:enemy")
		tween.tween_property(_enemy_hp_bar, "value", hp_after, BattleTuning.HP_TRACK_TWEEN_TIME)
		_enemy_hp_label.text = "生命：%d / %d" % [hp_after, _state.enemy_max_hp]
		_enemy_block_label.text = "防禦：%d" % block_after
	else:
		var tween_player: Tween = _create_managed_tween("hp_track:player")
		tween_player.tween_property(_player_hp_bar, "value", hp_after, BattleTuning.HP_TRACK_TWEEN_TIME)
		_player_hp_label.text = "生命：%d / %d" % [hp_after, _state.player_max_hp]
		_player_block_label.text = "防禦：%d" % block_after


func _play_impact_motion(target: String, target_anchor: PanelContainer, reverse_momentum: bool) -> void:
	var start_pos: Vector2 = _anchor_base_positions.get(target, target_anchor.position)
	target_anchor.position = start_pos
	var offset: Vector2 = Vector2(-BattleTuning.IMPACT_PUSH_DISTANCE, 0) if target == "enemy" else Vector2(BattleTuning.IMPACT_PUSH_DISTANCE, 0)
	if reverse_momentum:
		offset *= BattleTuning.IMPACT_BLOCK_REVERSE_SCALE
	var tween: Tween = _create_managed_tween("impact:%s" % target)
	tween.tween_property(target_anchor, "position", start_pos + offset, BattleTuning.IMPACT_HIT_STOP_TIME)
	tween.tween_property(target_anchor, "position", start_pos, BattleTuning.IMPACT_RETURN_TIME)


func _show_total_label(target: String, target_position: Vector2, cue: Dictionary) -> void:
	_clear_total_label(target, false)
	var total_label: Label = Label.new()
	total_label.text = "TOTAL %d" % int(cue.get("total_hp_damage", 0))
	total_label.position = _to_layer_position(_total_fx_layer, target_position + Vector2(-24, -82))
	total_label.modulate = Color(1.0, 0.93, 0.66, 1.0)
	_total_fx_layer.add_child(total_label)
	_active_total_labels[target] = total_label
	var target_channel: String = "total:%s" % target
	var tween: Tween = _create_managed_tween(target_channel)
	tween.parallel().tween_property(total_label, "position", total_label.position + Vector2(0, -BattleTuning.TOTAL_RISE_DISTANCE), BattleTuning.TOTAL_POPUP_LIFETIME)
	tween.parallel().tween_property(total_label, "modulate", Color(1.0, 0.93, 0.66, 0.0), BattleTuning.TOTAL_POPUP_LIFETIME)
	tween.finished.connect(func() -> void:
		if is_instance_valid(total_label):
			total_label.queue_free()
		if _active_total_labels.get(target) == total_label:
			_active_total_labels.erase(target)
	)


func _clear_total_label(target: String, interrupted: bool) -> void:
	var existing = _active_total_labels.get(target, null)
	_active_total_labels.erase(target)
	_kill_tween_channel("total:%s" % target)
	if existing == null or not is_instance_valid(existing):
		return
	if not interrupted:
		existing.queue_free()
		return
	var fade_tween: Tween = _create_managed_tween()
	fade_tween.parallel().tween_property(existing, "position", existing.position + Vector2(0, -8), BattleTuning.TOTAL_INTERRUPT_TIME)
	fade_tween.parallel().tween_property(existing, "modulate", Color(existing.modulate.r, existing.modulate.g, existing.modulate.b, 0.0), BattleTuning.TOTAL_INTERRUPT_TIME)
	fade_tween.finished.connect(func() -> void:
		if is_instance_valid(existing):
			existing.queue_free()
	)


func _spawn_floating_text(global_position: Vector2, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = _to_layer_position(_damage_fx_layer, global_position)
	label.modulate = color
	_damage_fx_layer.add_child(label)
	var tween: Tween = _create_managed_tween()
	tween.parallel().tween_property(label, "position", _to_layer_position(_damage_fx_layer, global_position + Vector2(0, -BattleTuning.FLOAT_TEXT_RISE_DISTANCE)), BattleTuning.FLOAT_TEXT_MOVE_TIME)
	tween.parallel().tween_property(label, "modulate", Color(color.r, color.g, color.b, 0.0), BattleTuning.FLOAT_TEXT_FADE_TIME)
	tween.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _pulse_node(node: CanvasItem, flash_color: Color) -> void:
	node.modulate = flash_color
	var tween: Tween = _create_managed_tween(_node_channel("pulse", node))
	tween.tween_property(node, "modulate", Color.WHITE, BattleTuning.PULSE_FADE_TIME)


func _anchor_center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _to_layer_position(layer: Control, global_position: Vector2) -> Vector2:
	return layer.get_global_transform().affine_inverse() * global_position


func _append_log(line: String) -> void:
	_event_log_lines.append(line)
	while _event_log_lines.size() > 34:
		_event_log_lines.pop_front()


func _reset_presentation_state() -> void:
	_invalidate_attack_sequences()
	_kill_managed_tweens()
	_active_total_labels.clear()
	_active_attack_ghosts.clear()
	_clear_layer(_attack_fx_layer)
	_clear_layer(_damage_fx_layer)
	_clear_layer(_total_fx_layer)
	_player_anchor.position = _anchor_base_positions.get("player", _player_anchor.position)
	_enemy_anchor.position = _anchor_base_positions.get("enemy", _enemy_anchor.position)
	_player_anchor.modulate = Color.WHITE
	_enemy_anchor.modulate = Color.WHITE
	_player_energy_label.modulate = Color.WHITE
	_player_combo_label.modulate = Color.WHITE
	_hand_area.modulate = Color.WHITE


func _clear_layer(layer: Control) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()


func _create_managed_tween(channel: String = "") -> Tween:
	if not channel.is_empty():
		_kill_tween_channel(channel)
	var tween: Tween = create_tween()
	_managed_tweens.append(tween)
	if not channel.is_empty():
		_channel_tweens[channel] = tween
	tween.finished.connect(func() -> void:
		_managed_tweens.erase(tween)
		if not channel.is_empty() and _channel_tweens.get(channel) == tween:
			_channel_tweens.erase(channel)
	)
	return tween


func _kill_tween_channel(channel: String) -> void:
	var existing: Tween = _channel_tweens.get(channel, null)
	if existing == null:
		return
	_channel_tweens.erase(channel)
	_managed_tweens.erase(existing)
	existing.kill()


func _kill_managed_tweens() -> void:
	var tweens: Array = _managed_tweens.duplicate()
	_managed_tweens.clear()
	_channel_tweens.clear()
	for tween in tweens:
		if tween != null:
			tween.kill()


func _invalidate_attack_sequences() -> void:
	_attack_sequence_ids["player"] = int(_attack_sequence_ids.get("player", 0)) + 1
	_attack_sequence_ids["enemy"] = int(_attack_sequence_ids.get("enemy", 0)) + 1


func _begin_attack_sequence(target: String) -> int:
	var sequence_id: int = int(_attack_sequence_ids.get(target, 0)) + 1
	_attack_sequence_ids[target] = sequence_id
	return sequence_id


func _is_attack_sequence_current(target: String, sequence_id: int) -> bool:
	return is_inside_tree() and _battle_ready and int(_attack_sequence_ids.get(target, -1)) == sequence_id


func _node_channel(prefix: String, node: Object) -> String:
	return "%s:%s" % [prefix, node.get_instance_id()]


func _maybe_emit_battle_finished() -> void:
	if _battle_finished_emitted:
		return
	if not _state.battle_over:
		return
	_battle_finished_emitted = true
	battle_finished.emit({
		"victory": _state.winner == "player",
		"enemy_name": _state.enemy_name,
	})


func _on_card_pressed(card_instance_id: String) -> void:
	if _card_views.has(card_instance_id):
		_card_launch_points[card_instance_id] = _card_views[card_instance_id]["button"].get_global_rect().get_center()
	_queue_event(BattleEvent.create("card_played", "player", {"card_instance_id": card_instance_id}))


func _on_card_mouse_entered(card_instance_id: String) -> void:
	_hovered_card_id = card_instance_id
	if _card_views.has(card_instance_id):
		_show_card_detail_panel(_card_views[card_instance_id].get("card", {}))
	_update_hand_focus_visuals()


func _on_card_mouse_exited(card_instance_id: String) -> void:
	if _hovered_card_id == card_instance_id:
		_hovered_card_id = ""
		_clear_card_detail_panel()
	_update_hand_focus_visuals()


func _on_end_turn_pressed() -> void:
	_queue_event(BattleEvent.create("turn_ended", "player"))
