# res://scripts/player_controller.gd
class_name player_controller
extends Node

## Signals
signal card_selected(card_ui: Control)
signal card_dropped_on_board(card_ui: Control)
signal targeting_started(source: Node)
signal targeting_ended(source: Node, target: Node)

## Player ID (0 or 1)
@export var player_id: int = 0

## Hand container reference
@export var hand_container: Control

## Lane references (set by main_game.gd)
var front_lanes: Array[Control] = []
var back_lanes: Array[Control] = []
var enemy_front_lanes: Array[Control] = []
var enemy_back_lanes: Array[Control] = []

## Hero areas
@export var enemy_hero_area: Control
@export var hero_area: Control

## Scene references
@export var card_ui_scene: PackedScene
@export var minion_scene: PackedScene
@export var targeting_arrow_scene: PackedScene

## Current targeting arrow
var _targeting_arrow: Node = null

## Currently dragged card (from hand)
var _dragged_card: Control = null

## Currently selected board entity (for attacking OR moving)
var _selected_attacker: Node = null

## Is AI controlled?
@export var is_ai: bool = false

## AI action delay (seconds between actions)
@export var ai_action_delay: float = 0.8

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.card_drawn.connect(_on_card_drawn)
	
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	GameManager.register_controller_ready()


func get_scale_factor() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return clampf(viewport_height / REFERENCE_HEIGHT, 0.8, 2.0)


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == player_id:
		_enable_hand_interaction(true)
		_refresh_board_minions()
		
		if is_ai:
			call_deferred("_ai_take_turn")
	else:
		_enable_hand_interaction(false)


func _on_card_drawn(draw_player_id: int, card: CardData) -> void:
	if draw_player_id != player_id:
		return
	
	if not hand_container:
		push_warning("[PlayerController %d] Cannot add card - no hand_container!" % player_id)
		return
	
	if not card_ui_scene:
		push_warning("No card UI scene set for player %d" % player_id)
		return
	
	var card_ui_instance = card_ui_scene.instantiate()
	hand_container.add_child(card_ui_instance)
	
	if card_ui_instance.has_method("setup"):
		card_ui_instance.setup(card, player_id)
	
	if card_ui_instance.has_signal("card_drag_started"):
		card_ui_instance.card_drag_started.connect(_on_card_drag_started)
	if card_ui_instance.has_signal("card_drag_ended"):
		card_ui_instance.card_drag_ended.connect(_on_card_drag_ended)


func _on_card_drag_started(card_ui_instance: Control) -> void:
	if is_ai:
		return
	_dragged_card = card_ui_instance


func _on_card_drag_ended(dragged: Control, global_pos: Vector2) -> void:
	if is_ai or not dragged:
		return
	
	_dragged_card = null
	
	var target_lane := _get_lane_at_position(global_pos)
	if target_lane:
		var lane_index: int = target_lane.get_meta("lane_index", -1)
		var is_front: bool = target_lane.get_meta("is_front", true)
		var is_player_lane: bool = target_lane.get_meta("is_player", true)
		
		if is_player_lane == (player_id == 0):
			var success = await _try_play_card_to_lane(dragged, lane_index, is_front)
			if not success and is_instance_valid(dragged):
				dragged.return_to_hand()
		else:
			dragged.return_to_hand()
	else:
		dragged.return_to_hand()


func _get_lane_at_position(global_pos: Vector2) -> Control:
	for lane in front_lanes + back_lanes:
		if lane and lane.get_global_rect().has_point(global_pos):
			return lane
	return null


func _get_minion_slot(lane: Control) -> Control:
	return lane.find_child("MinionSlot", false, false) as Control


func _is_lane_empty(lane: Control) -> bool:
	var slot = _get_minion_slot(lane)
	if slot:
		return slot.get_child_count() == 0
	return true


## Get the minion in a lane (if any)
func _get_minion_in_lane(lane: Control) -> Node:
	var slot = _get_minion_slot(lane)
	if slot and slot.get_child_count() > 0:
		for child in slot.get_children():
			if child is Minion:
				return child
	return null


## Check if a lane can accept a Huddle minion
func _can_place_huddle_in_lane(lane: Control) -> bool:
	var existing := _get_minion_in_lane(lane)
	return existing != null  # Huddle requires an existing minion


func _try_play_card_to_lane(card_ui_instance: Control, lane_index: int, is_front: bool) -> bool:
	# Validate card_data exists
	if not card_ui_instance or not card_ui_instance.card_data:
		push_error("_try_play_card_to_lane: card_ui has no card_data")
		return false
	
	var card_data: CardData = card_ui_instance.card_data
	
	var target_lane: Control
	if is_front:
		if lane_index < front_lanes.size():
			target_lane = front_lanes[lane_index]
	else:
		if lane_index < back_lanes.size():
			target_lane = back_lanes[lane_index]
	
	if not target_lane:
		return false
	
	var existing_minion := _get_minion_in_lane(target_lane)
	var lane_empty := existing_minion == null
	
	# Check if lane is occupied
	if not lane_empty:
		# Only Huddle minions can be played in occupied lanes
		if not card_data.has_keyword("Huddle"):
			print("[PlayerController %d] Lane %d %s is occupied (need Huddle)" % [player_id, lane_index, "front" if is_front else "back"])
			return false
	
	if not GameManager.play_card(player_id, card_data):
		return false
	
	_animate_card_play(card_ui_instance)
	
	if card_data.card_type == CardData.CardType.MINION:
		await get_tree().create_timer(0.2).timeout
		_spawn_minion_in_lane(card_data, lane_index, is_front, existing_minion)
	
	return true


func _animate_card_play(card_ui_instance: Control) -> void:
	if not card_ui_instance.top_level:
		var gpos = card_ui_instance.global_position
		card_ui_instance.top_level = true
		card_ui_instance.global_position = gpos
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui_instance, "modulate:a", 0.0, 0.2)
	tween.tween_property(card_ui_instance, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_callback(card_ui_instance.queue_free).set_delay(0.2)


## Spawn a minion in a lane - UPDATED for Huddle support
func _spawn_minion_in_lane(card: CardData, lane_index: int, is_front: bool, existing_minion: Node = null) -> Node:
	if not minion_scene:
		return null
	
	var target_lane: Control
	if is_front:
		target_lane = front_lanes[lane_index] if lane_index < front_lanes.size() else null
	else:
		target_lane = back_lanes[lane_index] if lane_index < back_lanes.size() else null
	
	if not target_lane:
		return null
	
	var slot = _get_minion_slot(target_lane)
	if not slot:
		return null
	
	var minion_instance: Node = minion_scene.instantiate()
	
	# === HUDDLE LOGIC ===
	if existing_minion and card.has_keyword("Huddle"):
		# Attach as huddle minion instead of placing normally
		slot.add_child(minion_instance)
		minion_instance.initialize(card, player_id)
		minion_instance.lane_index = lane_index
		minion_instance.is_front_row = is_front
		
		# Attach to existing minion
		existing_minion.attach_huddle(minion_instance)
		
		# Register on board (but it's hidden behind the front minion)
		GameManager.register_minion_on_board(player_id, minion_instance)
		
		
		print("[PlayerController %d] Huddle minion %s attached behind %s" % [
			player_id, card.card_name, existing_minion.card_data.card_name
		])
		
		return minion_instance
	
	# === NORMAL PLACEMENT ===
	slot.add_child(minion_instance)
	minion_instance.initialize(card, player_id)
	minion_instance.lane_index = lane_index
	minion_instance.is_front_row = is_front
	
	# Connect signals
	if minion_instance.has_signal("minion_clicked"):
		minion_instance.minion_clicked.connect(_on_minion_clicked)
	if minion_instance.has_signal("minion_targeted"):
		minion_instance.minion_targeted.connect(_on_minion_targeted)
	if minion_instance.has_signal("minion_drag_started"):
		minion_instance.minion_drag_started.connect(_on_minion_drag_started)
	
	GameManager.register_minion_on_board(player_id, minion_instance)
	
	# Trigger Battlecry / On-play
	if card.has_keyword("Battlecry") or card.has_keyword("On-play"):
		GameManager.trigger_battlecry(player_id, minion_instance, card, null)
	
	
	_animate_minion_summon(minion_instance)
	
	return minion_instance


func _animate_minion_summon(minion_instance: Node) -> void:
	minion_instance.modulate.a = 0.0
	minion_instance.scale = Vector2(0.1, 0.1)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(minion_instance, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(minion_instance, "scale", Vector2.ONE, 0.4)


## ============================================================================
## NEW KEYWORD SIGNAL HANDLERS
## ============================================================================

func _on_persistent_respawn(respawn_player_id: int, card: CardData, lane_index: int, is_front: bool) -> void:
	if respawn_player_id != player_id:
		return
	print("[PlayerController %d] Respawning Persistent minion: %s" % [player_id, card.card_name])
	
	var target_lane: Control
	if is_front:
		target_lane = front_lanes[lane_index] if lane_index < front_lanes.size() else null
	else:
		target_lane = back_lanes[lane_index] if lane_index < back_lanes.size() else null
	
	if not target_lane:
		return
	
	var slot = _get_minion_slot(target_lane)
	if not slot:
		return
	
	if slot.get_child_count() > 0:
		print("[PlayerController %d] Lane occupied, cannot respawn Persistent" % player_id)
		return
	
	var minion_instance: Node = minion_scene.instantiate()
	slot.add_child(minion_instance)
	minion_instance.initialize(card, player_id)
	
	# Override health to 1
	minion_instance.current_health = 1
	minion_instance.max_health = 1
	minion_instance._update_visuals()
	
	minion_instance.lane_index = lane_index
	minion_instance.is_front_row = is_front
	minion_instance.just_played = true
	
	if minion_instance.has_signal("minion_clicked"):
		minion_instance.minion_clicked.connect(_on_minion_clicked)
	if minion_instance.has_signal("minion_targeted"):
		minion_instance.minion_targeted.connect(_on_minion_targeted)
	if minion_instance.has_signal("minion_drag_started"):
		minion_instance.minion_drag_started.connect(_on_minion_drag_started)
	
	GameManager.register_minion_on_board(player_id, minion_instance)
	_animate_persistent_respawn(minion_instance)


func _animate_persistent_respawn(minion_instance: Node) -> void:
	minion_instance.modulate = Color(1, 1, 1, 0)
	minion_instance.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(minion_instance, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(minion_instance, "scale", Vector2.ONE, 0.5)
	
	# Flash golden to indicate Persistent triggered
	tween.tween_property(minion_instance, "modulate", Color(1.2, 1.0, 0.5), 0.2)
	tween.tween_property(minion_instance, "modulate", Color.WHITE, 0.2)


## ============================================================================
## TARGETING AND COMBAT
## ============================================================================

func _try_start_arrow_interaction(minion_instance: Node) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	if minion_instance.owner_id != player_id:
		if _selected_attacker:
			_on_minion_targeted(minion_instance)
		return
	
	var can_attack_enemies = minion_instance.can_attack()
	if not minion_instance.is_front_row and not minion_instance.has_snipe:
		can_attack_enemies = false
	
	var can_move_lanes = (not minion_instance.has_attacked) and (not minion_instance.has_moved_this_turn)
	
	if can_attack_enemies or can_move_lanes:
		_selected_attacker = minion_instance
		_start_targeting(minion_instance)
		_highlight_valid_targets()
	else:
		print("[PlayerController %d] Minion cannot act (Attack: %s, Move: %s)" % [player_id, can_attack_enemies, can_move_lanes])


func _on_minion_clicked(minion_instance: Node) -> void:
	_try_start_arrow_interaction(minion_instance)


func _on_minion_drag_started(minion_instance: Node) -> void:
	_try_start_arrow_interaction(minion_instance)


func _on_minion_drag_ended(_minion_instance: Node, _global_pos: Vector2) -> void:
	pass


func _on_minion_targeted(minion_instance: Node) -> void:
	if not _selected_attacker:
		return
	
	if minion_instance.owner_id == player_id:
		_cancel_targeting()
		return
	
	var allowed_to_attack = _selected_attacker.can_attack()
	if not _selected_attacker.is_front_row and not _selected_attacker.has_snipe:
		allowed_to_attack = false
	
	if not allowed_to_attack:
		print("[PlayerController %d] Minion cannot attack from back row!" % player_id)
		_cancel_targeting()
		return
	
	if minion_instance.has_hidden:
		print("[PlayerController %d] Cannot target Hidden minion!" % player_id)
		_cancel_targeting()
		return
	
	if not GameManager.is_valid_attack_target(_selected_attacker.owner_id, minion_instance):
		print("[PlayerController %d] Must target a Taunt minion in that row!" % player_id)
		_cancel_targeting()
		return
	
	var is_front_row_target = minion_instance.is_front_row
	var front_row_empty = _is_enemy_front_row_empty()
	
	if not _selected_attacker.has_snipe:
		if not is_front_row_target and not front_row_empty:
			print("[PlayerController %d] Must target front row first!" % player_id)
			return
	
	await _animate_attack(_selected_attacker, minion_instance)
	GameManager.execute_combat(_selected_attacker, minion_instance)
	_cancel_targeting()


func target_enemy_hero() -> void:
	if not _selected_attacker:
		return
	
	var allowed_to_attack = _selected_attacker.can_attack()
	if not _selected_attacker.is_front_row and not _selected_attacker.has_snipe:
		allowed_to_attack = false
	
	if not allowed_to_attack:
		print("[PlayerController %d] Minion cannot attack from back row!" % player_id)
		_cancel_targeting()
		return
	
	if not _is_enemy_front_row_empty():
		print("[PlayerController %d] Cannot attack hero - front row not empty!" % player_id)
		_cancel_targeting()
		return
	
	if _selected_attacker.has_rush and _selected_attacker.just_played:
		print("[PlayerController %d] Rush minions cannot attack heroes on first turn!" % player_id)
		_cancel_targeting()
		return
	
	var enemy_id = GameManager.get_opponent_id(player_id)
	await _animate_attack_hero(_selected_attacker)
	GameManager.attack_hero(_selected_attacker, enemy_id)
	_cancel_targeting()


func _is_enemy_front_row_empty() -> bool:
	for lane in enemy_front_lanes:
		if not _is_lane_empty(lane):
			return false
	return true


func _animate_attack(attacker: Node, target: Node) -> void:
	var original_pos: Vector2 = attacker.global_position
	var target_global_pos: Vector2 = target.global_position
	var bump_pos: Vector2 = original_pos.lerp(target_global_pos, 0.7)
	
	var tween = create_tween()
	tween.tween_property(attacker, "global_position", bump_pos, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "global_position", original_pos, 0.15).set_ease(Tween.EASE_OUT)
	
	await tween.finished


func _animate_attack_hero(attacker: Node) -> void:
	var original_pos: Vector2 = attacker.global_position
	var bump_direction = Vector2.UP if player_id == 0 else Vector2.DOWN
	var bump_distance = 100.0 * get_scale_factor()
	var bump_pos: Vector2 = original_pos + bump_direction * bump_distance
	
	var tween = create_tween()
	tween.tween_property(attacker, "global_position", bump_pos, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "global_position", original_pos, 0.15).set_ease(Tween.EASE_OUT)
	
	await tween.finished


func _move_minion_to_row(minion_instance: Node, to_front: bool, lane_index: int) -> void:
	var target_lane: Control
	if to_front:
		target_lane = front_lanes[lane_index] if lane_index < front_lanes.size() else null
	else:
		target_lane = back_lanes[lane_index] if lane_index < back_lanes.size() else null
	
	if not target_lane:
		return
	
	var slot = _get_minion_slot(target_lane)
	if not slot:
		return
	
	minion_instance.get_parent().remove_child(minion_instance)
	slot.add_child(minion_instance)
	minion_instance.lane_index = lane_index
	minion_instance.is_front_row = to_front
	minion_instance.has_moved_this_turn = true
	
	print("[PlayerController %d] Moved minion to %s row in lane %d" % [
		player_id, "front" if to_front else "back", lane_index
	])


func _highlight_valid_targets() -> void:
	if not _selected_attacker:
		return
	
	var allowed_to_attack = _selected_attacker.can_attack()
	if not _selected_attacker.is_front_row and not _selected_attacker.has_snipe:
		allowed_to_attack = false
	
	# Highlight enemy minions
	if allowed_to_attack:
		var front_row_empty = _is_enemy_front_row_empty()
		
		for lane in enemy_front_lanes:
			var slot = _get_minion_slot(lane)
			if slot:
				for child in slot.get_children():
					if child.has_method("set_targetable"):
						var is_valid = GameManager.is_valid_attack_target(_selected_attacker.owner_id, child)
						child.set_targetable(is_valid)
		
		# Highlight back row if Snipe OR front row empty
		if _selected_attacker.has_snipe or front_row_empty:
			for lane in enemy_back_lanes:
				var slot = _get_minion_slot(lane)
				if slot:
					for child in slot.get_children():
						if child.has_method("set_targetable"):
							var is_valid = GameManager.is_valid_attack_target(_selected_attacker.owner_id, child)
							child.set_targetable(is_valid)
	
	# Highlight empty friendly lanes for movement
	if (not _selected_attacker.has_attacked) and (not _selected_attacker.has_moved_this_turn):
		for lane in front_lanes + back_lanes:
			if _is_lane_empty(lane):
				pass  # Optional: Add visual highlight


func _clear_target_highlights() -> void:
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child.has_method("set_targetable"):
					child.set_targetable(false)


func _start_targeting(source: Node) -> void:
	if targeting_arrow_scene and not _targeting_arrow:
		_targeting_arrow = targeting_arrow_scene.instantiate()
		get_tree().root.add_child(_targeting_arrow)
		_targeting_arrow.start_from(source.global_position + source.size / 2)
	
	targeting_started.emit(source)


func _cancel_targeting() -> void:
	if _targeting_arrow:
		_targeting_arrow.queue_free()
		_targeting_arrow = null
	
	_clear_target_highlights()
	_selected_attacker = null


func _check_attack_target(global_pos: Vector2) -> void:
	# Check Enemy Hero
	if enemy_hero_area and enemy_hero_area.get_global_rect().has_point(global_pos):
		target_enemy_hero()
		return
	
	# Check Enemy Minions
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Control and child.get_global_rect().has_point(global_pos):
					_on_minion_targeted(child)
					return
	
	# Check Friendly Lanes (For Movement)
	if _selected_attacker and (not _selected_attacker.has_moved_this_turn) and (not _selected_attacker.has_attacked):
		for lane in front_lanes + back_lanes:
			if lane and lane.get_global_rect().has_point(global_pos):
				if _is_lane_empty(lane):
					var lane_index = lane.get_meta("lane_index", -1)
					var is_front = lane.get_meta("is_front", false)
					
					if lane_index == _selected_attacker.lane_index and is_front == _selected_attacker.is_front_row:
						pass
					else:
						_move_minion_to_row(_selected_attacker, is_front, lane_index)
					
					_cancel_targeting()
					return
	
	_cancel_targeting()


func _input(event: InputEvent) -> void:
	if is_ai:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _selected_attacker and _targeting_arrow:
				_check_attack_target(event.global_position)


func _process(_delta: float) -> void:
	if _targeting_arrow and _selected_attacker:
		_targeting_arrow.update_end_position(get_viewport().get_mouse_position())


func _enable_hand_interaction(enabled: bool) -> void:
	if not hand_container:
		return
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.has_method("set_interactable"):
			card_ui_instance.set_interactable(enabled)


func _refresh_board_minions() -> void:
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child.has_method("refresh_for_turn"):
					child.refresh_for_turn()


func _clear_hand() -> void:
	if not hand_container:
		return
	for child in hand_container.get_children():
		child.queue_free()


func _clear_board() -> void:
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				child.queue_free()


func request_end_turn() -> void:
	if GameManager.is_player_turn(player_id):
		GameManager.end_turn()


func _get_all_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Minion:
					minions.append(child)
	return minions


## ============================================================================
## AI LOGIC
## ============================================================================

func _ai_take_turn() -> void:
	if not is_ai or not GameManager.is_player_turn(player_id):
		return
	
	# Add this null check
	if not hand_container:
		push_warning("[PlayerTwoController %d] AI cannot take turn - no hand_container!" % player_id)
		# Still end turn even if we can't play cards
		await get_tree().create_timer(ai_action_delay).timeout
		if GameManager.is_player_turn(player_id):
			request_end_turn()
		return
	
	await get_tree().create_timer(ai_action_delay).timeout
	
	# Play cards
	var played_card = true
	while played_card and GameManager.is_player_turn(player_id):
		played_card = false
		
		var playable = _ai_get_playable_cards()
		if playable.is_empty():
			break
		
		for card_ui_instance in playable:
			var card: CardData = card_ui_instance.card_data
			
			if GameManager.get_current_mana(player_id) < card.cost:
				continue
			
			if card.card_type == CardData.CardType.MINION:
				var target_lane_info = _ai_find_play_target()
				if target_lane_info.is_empty():
					continue
				
				if await _try_play_card_to_lane(card_ui_instance, target_lane_info.index, target_lane_info.is_front):
					played_card = true
					await get_tree().create_timer(ai_action_delay).timeout
					break
	
	await get_tree().create_timer(ai_action_delay).timeout
	_ai_attack_with_minions()
	
	await get_tree().create_timer(ai_action_delay).timeout
	
	if GameManager.is_player_turn(player_id):
		request_end_turn()


func _ai_get_playable_cards() -> Array:
	var playable: Array = []
	
	# Null check for hand_container
	if not hand_container:
		push_warning("[PlayerController %d] AI has no hand_container!" % player_id)
		return playable
	
	var current_mana = GameManager.get_current_mana(player_id)
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.card_data and card_ui_instance.card_data.cost <= current_mana:
			playable.append(card_ui_instance)
	
	return playable


func _ai_find_play_target() -> Dictionary:
	for i in range(front_lanes.size()):
		if _is_lane_empty(front_lanes[i]):
			return {"index": i, "is_front": true}
	for i in range(back_lanes.size()):
		if _is_lane_empty(back_lanes[i]):
			return {"index": i, "is_front": false}
	return {}


func _ai_attack_with_minions() -> void:
	if not GameManager.is_player_turn(player_id):
		return
	
	var attackers = _get_all_minions()
	
	for attacker in attackers:
		if not GameManager.is_player_turn(player_id):
			break
		
		if not attacker.can_attack():
			continue
		
		if not attacker.is_front_row and not attacker.has_snipe:
			continue
		
		var target = _ai_choose_attack_target(attacker)
		
		if target == null:
			if _is_enemy_front_row_empty():
				if not (attacker.has_rush and attacker.just_played):
					var enemy_id = GameManager.get_opponent_id(player_id)
					await _animate_attack_hero(attacker)
					GameManager.attack_hero(attacker, enemy_id)
					await get_tree().create_timer(ai_action_delay * 0.5).timeout
		else:
			await _animate_attack(attacker, target)
			GameManager.execute_combat(attacker, target)
			await get_tree().create_timer(ai_action_delay * 0.5).timeout


func _ai_choose_attack_target(attacker: Node) -> Node:
	var valid_targets: Array[Node] = []
	
	# Check front row first
	for lane in enemy_front_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Minion and GameManager.is_valid_attack_target(attacker.owner_id, child):
					valid_targets.append(child)
	
	# Check back row if we have Snipe or front is empty
	if attacker.has_snipe or _is_enemy_front_row_empty():
		for lane in enemy_back_lanes:
			var slot = _get_minion_slot(lane)
			if slot:
				for child in slot.get_children():
					if child is Minion and GameManager.is_valid_attack_target(attacker.owner_id, child):
						valid_targets.append(child)
	
	if valid_targets.is_empty():
		return null
	
	# Prioritize taunt minions, then lowest health
	var taunts = valid_targets.filter(func(m): return m.has_taunt)
	if not taunts.is_empty():
		taunts.sort_custom(func(a, b): return a.current_health < b.current_health)
		return taunts[0]
	
	valid_targets.sort_custom(func(a, b): return a.current_health < b.current_health)
	return valid_targets[0]
