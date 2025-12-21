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
# These arrays hold the actual Control nodes for the 6 board slots
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

## Currently dragged card
var _dragged_card: Control = null

## Currently selected attacker
var _selected_attacker: Node = null

## Currently dragged minion (for moving between rows)
var _dragged_minion: Node = null

## Is AI controlled?
@export var is_ai: bool = false

## AI delays
@export var ai_think_delay: float = 0.8
@export var ai_action_delay: float = 0.5

## AI thinking state
var _ai_thinking: bool = false

## Constants
const BASE_CARD_SPACING = -30.0
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	if not is_inside_tree():
		await ready
	
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	_connect_signals()
	_apply_responsive_spacing()
	GameManager.register_controller_ready()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Validate lane setup
	if front_lanes.is_empty() or back_lanes.is_empty():
		push_warning("[PlayerController %d] Lane arrays are empty! Check MainGame setup." % player_id)
		
	print("[PlayerController %d] Ready, is_ai: %s" % [player_id, is_ai])


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _apply_responsive_spacing() -> void:
	var scale_factor = get_scale_factor()
	if hand_container and hand_container is HBoxContainer:
		hand_container.add_theme_constant_override("separation", int(BASE_CARD_SPACING * scale_factor))


func _on_viewport_size_changed() -> void:
	_apply_responsive_spacing()


func _connect_signals() -> void:
	# Disconnect first to avoid duplicates if re-initializing
	if GameManager.card_drawn.is_connected(_on_card_drawn):
		GameManager.card_drawn.disconnect(_on_card_drawn)
	if GameManager.turn_started.is_connected(_on_turn_started):
		GameManager.turn_started.disconnect(_on_turn_started)
	if GameManager.turn_ended.is_connected(_on_turn_ended):
		GameManager.turn_ended.disconnect(_on_turn_ended)
	if GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.disconnect(_on_game_started)
	
	GameManager.card_drawn.connect(_on_card_drawn)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.turn_ended.connect(_on_turn_ended)
	GameManager.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	_clear_hand()
	_clear_board()


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == player_id:
		_enable_hand_interaction(true)
		_refresh_board_minions()
		
		if is_ai and not _ai_thinking:
			_start_ai_turn()
	else:
		_enable_hand_interaction(false)


func _on_turn_ended(turn_player_id: int) -> void:
	if turn_player_id == player_id:
		_enable_hand_interaction(false)
		_cancel_targeting()
		_ai_thinking = false


func _on_card_drawn(draw_player_id: int, card: CardData) -> void:
	if draw_player_id != player_id:
		return
	_add_card_to_hand(card)


func _add_card_to_hand(card: CardData) -> void:
	if not card_ui_scene or not hand_container:
		return
	
	var card_ui_instance: Control = card_ui_scene.instantiate()
	hand_container.add_child(card_ui_instance)
	card_ui_instance.initialize(card, player_id)
	
	if card_ui_instance.has_signal("card_clicked"):
		card_ui_instance.card_clicked.connect(_on_card_clicked)
	if card_ui_instance.has_signal("card_drag_started"):
		card_ui_instance.card_drag_started.connect(_on_card_drag_started)
	if card_ui_instance.has_signal("card_drag_ended"):
		card_ui_instance.card_drag_ended.connect(_on_card_drag_ended)
	
	_animate_card_draw(card_ui_instance)


func _animate_card_draw(card_ui_instance: Control) -> void:
	card_ui_instance.modulate.a = 0.0
	card_ui_instance.scale = Vector2(0.5, 0.5)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var end_pos = card_ui_instance.position
	var start_x = 500.0 * get_scale_factor()
	card_ui_instance.position = Vector2(start_x, 0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_ui_instance, "modulate:a", 1.0, 0.3)
	tween.tween_property(card_ui_instance, "scale", Vector2.ONE, 0.4)
	tween.tween_property(card_ui_instance, "position", end_pos, 0.4)


func _on_card_clicked(card_ui_instance: Control) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	card_selected.emit(card_ui_instance)


func _on_card_drag_started(card_ui_instance: Control) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	_dragged_card = card_ui_instance


## Validates the drop position for playing cards
func _on_card_drag_ended(card_ui_instance: Control, global_pos: Vector2) -> void:
	if not _dragged_card:
		return
	
	var dragged = _dragged_card
	_dragged_card = null
	
	# Check which lane was dropped on
	var target_lane = _get_lane_at_position(global_pos)
	
	if target_lane != null:
		# Retrieve metadata set by main_game.gd to determine lane properties
		var lane_index: int = target_lane.get_meta("lane_index", -1)
		var is_front: bool = target_lane.get_meta("is_front", true)
		var is_player_lane: bool = target_lane.get_meta("is_player", true)
		
		# Validate ownership: Player 0 uses "player" lanes, Player 1 uses "enemy" lanes
		# (In the MainGame setup, is_player=true corresponds to Player 0's side)
		if is_player_lane == (player_id == 0):
			# Attempt to play the card to the specific lane (Front OR Back)
			var success = await _try_play_card_to_lane(dragged, lane_index, is_front)
			if not success and is_instance_valid(dragged):
				dragged.return_to_hand()
		else:
			dragged.return_to_hand()
	else:
		dragged.return_to_hand()


## Iterates through both Front and Back lanes to find one under the mouse
func _get_lane_at_position(global_pos: Vector2) -> Control:
	# Check all player lanes (3 Front + 3 Back = 6 valid targets)
	for lane in front_lanes + back_lanes:
		if lane and lane.get_global_rect().has_point(global_pos):
			return lane
	return null


func _get_minion_slot(lane: Control) -> Control:
	# Get the MinionSlot child of a lane panel
	return lane.find_child("MinionSlot", false, false) as Control


func _is_lane_empty(lane: Control) -> bool:
	var slot = _get_minion_slot(lane)
	if slot:
		return slot.get_child_count() == 0
	return true


func _try_play_card_to_lane(card_ui_instance: Control, lane_index: int, is_front: bool) -> bool:
	var card: CardData = card_ui_instance.card_data
	
	# Get the target lane based on row and index
	var target_lane: Control
	if is_front:
		if lane_index < front_lanes.size():
			target_lane = front_lanes[lane_index]
	else:
		if lane_index < back_lanes.size():
			target_lane = back_lanes[lane_index]
	
	if not target_lane:
		return false
	
	# Check if lane is empty (Game Rule: 1 Minion per Slot)
	if not _is_lane_empty(target_lane):
		print("[PlayerController %d] Lane %d %s is occupied" % [player_id, lane_index, "front" if is_front else "back"])
		return false
	
	if GameManager.try_play_card(player_id, card, null):
		_animate_card_play(card_ui_instance)
		
		if card.card_type == CardData.CardType.MINION:
			# Small delay for visual impact
			await get_tree().create_timer(0.2).timeout
			_spawn_minion_in_lane(card, lane_index, is_front)
		
		return true
	
	return false


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


func _spawn_minion_in_lane(card: CardData, lane_index: int, is_front: bool) -> Node:
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
	slot.add_child(minion_instance)
	minion_instance.initialize(card, player_id)
	
	# Set lane info on minion
	minion_instance.lane_index = lane_index
	minion_instance.is_front_row = is_front
	
	# Connect signals
	if minion_instance.has_signal("minion_clicked"):
		minion_instance.minion_clicked.connect(_on_minion_clicked)
	if minion_instance.has_signal("minion_targeted"):
		minion_instance.minion_targeted.connect(_on_minion_targeted)
	if minion_instance.has_signal("minion_drag_started"):
		minion_instance.minion_drag_started.connect(_on_minion_drag_started)
	if minion_instance.has_signal("minion_drag_ended"):
		minion_instance.minion_drag_ended.connect(_on_minion_drag_ended)
	
	GameManager.register_minion_on_board(player_id, minion_instance)
	
	if card.has_keyword("Battlecry"):
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


func _on_minion_clicked(minion_instance: Node) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	# Clicking enemy minion while targeting
	if minion_instance.owner_id != player_id:
		if _selected_attacker:
			_on_minion_targeted(minion_instance)
		return
	
	# Check if can attack
	if not minion_instance.can_attack():
		return
	
	# Back row minions can only attack if they have Snipe
	if not minion_instance.is_front_row and not minion_instance.has_snipe:
		print("[PlayerController %d] Back row minion without Snipe cannot attack" % player_id)
		return
	
	_selected_attacker = minion_instance
	_start_targeting(minion_instance)
	_highlight_valid_targets()


func _on_minion_drag_started(minion_instance: Node) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	if minion_instance.owner_id != player_id:
		return
	
	# Can only move if hasn't attacked this turn
	if minion_instance.has_attacked:
		print("[PlayerController %d] Minion already attacked, cannot move" % player_id)
		return
	
	_dragged_minion = minion_instance


func _on_minion_drag_ended(minion_instance: Node, global_pos: Vector2) -> void:
	if not _dragged_minion or _dragged_minion != minion_instance:
		return
	
	_dragged_minion = null
	
	# Check if dropped on a valid lane
	var target_lane = _get_lane_at_position(global_pos)
	
	if target_lane != null:
		var lane_index: int = target_lane.get_meta("lane_index", -1)
		var is_front: bool = target_lane.get_meta("is_front", true)
		var is_player_lane: bool = target_lane.get_meta("is_player", true)
		
		# Can only move to own lanes
		if is_player_lane == (player_id == 0):
			# Check if it's a different row (same lane, different row)
			# We allow moving forward or backward in the same lane index
			if lane_index == minion_instance.lane_index and is_front != minion_instance.is_front_row:
				if _is_lane_empty(target_lane):
					_move_minion_to_row(minion_instance, is_front)
				else:
					_return_minion_to_slot(minion_instance)
			else:
				_return_minion_to_slot(minion_instance)
		else:
			_return_minion_to_slot(minion_instance)
	else:
		_return_minion_to_slot(minion_instance)


func _move_minion_to_row(minion_instance: Node, to_front: bool) -> void:
	var lane_index: int = minion_instance.lane_index
	
	# Get target lane
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
	
	# Reparent minion
	minion_instance.get_parent().remove_child(minion_instance)
	slot.add_child(minion_instance)
	minion_instance.is_front_row = to_front
	minion_instance.has_moved_this_turn = true
	
	print("[PlayerController %d] Moved minion to %s row in lane %d" % [
		player_id, "front" if to_front else "back", lane_index
	])


func _return_minion_to_slot(minion_instance: Node) -> void:
	# Reset position - minion should stay where it is since it's in a CenterContainer
	pass


func _highlight_valid_targets() -> void:
	if not _selected_attacker:
		return
	
	var enemy_id = GameManager.get_opponent_id(player_id)
	
	# Check if enemy front row is empty
	var front_row_empty = true
	for lane in enemy_front_lanes:
		if not _is_lane_empty(lane):
			front_row_empty = false
			break
	
	# Highlight enemy minions
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child.has_method("set_targetable"):
					# Front row always targetable, back row only if front is empty
					var is_front_lane = lane in enemy_front_lanes
					var can_target = is_front_lane or front_row_empty
					child.set_targetable(can_target)


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


func _on_minion_targeted(minion_instance: Node) -> void:
	if not _selected_attacker:
		return
	
	if minion_instance.owner_id == player_id:
		_cancel_targeting()
		return
	
	# Check if this is a valid target (front row check)
	var is_front_row_target = minion_instance.is_front_row
	var front_row_empty = _is_enemy_front_row_empty()
	
	if not is_front_row_target and not front_row_empty:
		print("[PlayerController %d] Must target front row first!" % player_id)
		return
	
	await _animate_attack(_selected_attacker, minion_instance)
	GameManager.execute_combat(_selected_attacker, minion_instance)
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


func target_enemy_hero() -> void:
	if not _selected_attacker:
		return
	
	# Can only attack hero if front row is empty
	if not _is_enemy_front_row_empty():
		print("[PlayerController %d] Cannot attack hero - front row not empty!" % player_id)
		_cancel_targeting()
		return
	
	# Rush minions can't attack hero on first turn
	if _selected_attacker.has_rush and _selected_attacker.just_played:
		print("[PlayerController %d] Rush minions cannot attack heroes on first turn!" % player_id)
		_cancel_targeting()
		return
	
	var enemy_id = GameManager.get_opponent_id(player_id)
	await _animate_attack_hero(_selected_attacker)
	GameManager.attack_hero(_selected_attacker, enemy_id)
	_cancel_targeting()


func _animate_attack_hero(attacker: Node) -> void:
	var original_pos: Vector2 = attacker.global_position
	var bump_direction = Vector2.UP if player_id == 0 else Vector2.DOWN
	var bump_distance = 100.0 * get_scale_factor()
	var bump_pos: Vector2 = original_pos + bump_direction * bump_distance
	
	var tween = create_tween()
	tween.tween_property(attacker, "global_position", bump_pos, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "global_position", original_pos, 0.15).set_ease(Tween.EASE_OUT)
	
	await tween.finished


func _input(event: InputEvent) -> void:
	if is_ai:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _selected_attacker and _targeting_arrow:
				_check_attack_target(event.global_position)


func _check_attack_target(global_pos: Vector2) -> void:
	# Check enemy hero area
	if enemy_hero_area and enemy_hero_area.get_global_rect().has_point(global_pos):
		target_enemy_hero()
		return
	
	# Check enemy minions
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Control and child.get_global_rect().has_point(global_pos):
					_on_minion_targeted(child)
					return
	
	_cancel_targeting()


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


## Get all minions on our board
func _get_all_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				minions.append(child)
	return minions


## Get all enemy minions
func _get_all_enemy_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				minions.append(child)
	return minions


# =============================================================================
# AI LOGIC
# =============================================================================

func _start_ai_turn() -> void:
	if not is_ai:
		return
	
	_ai_thinking = true
	await get_tree().create_timer(ai_think_delay).timeout
	await _ai_execute_turn()


func _ai_execute_turn() -> void:
	if not GameManager.is_player_turn(player_id):
		_ai_thinking = false
		return
	
	await _ai_play_cards()
	await _ai_attack_with_minions()
	await get_tree().create_timer(ai_action_delay).timeout
	
	if GameManager.is_player_turn(player_id):
		request_end_turn()
	
	_ai_thinking = false


func _ai_play_cards() -> void:
	var played_card = true
	
	while played_card and GameManager.is_player_turn(player_id):
		played_card = false
		
		var playable_cards = _ai_get_playable_cards()
		if playable_cards.is_empty():
			break
		
		# AI Strategy: Play expensive cards first
		playable_cards.sort_custom(func(a, b): return a.card_data.cost > b.card_data.cost)
		
		for card_ui_instance in playable_cards:
			if not GameManager.is_player_turn(player_id):
				break
			
			var card: CardData = card_ui_instance.card_data
			
			if GameManager.get_current_mana(player_id) < card.cost:
				continue
			
			if card.card_type == CardData.CardType.MINION:
				# Find a SPECIFIC empty lane with its row information
				var target_lane_info = _ai_find_play_target()
				
				# If no space is available, skip this minion
				if target_lane_info.is_empty():
					continue
				
				# Play to the found index and row
				if await _try_play_card_to_lane(card_ui_instance, target_lane_info.index, target_lane_info.is_front):
					played_card = true
					await get_tree().create_timer(ai_action_delay).timeout
					break


func _ai_get_playable_cards() -> Array:
	var playable: Array = []
	var current_mana = GameManager.get_current_mana(player_id)
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.card_data and card_ui_instance.card_data.cost <= current_mana:
			playable.append(card_ui_instance)
	
	return playable


## Helper to find a valid slot for the AI
## Returns a Dictionary with { "index": int, "is_front": bool } or empty if full
func _ai_find_play_target() -> Dictionary:
	# Prefer front lanes first
	for i in range(front_lanes.size()):
		if _is_lane_empty(front_lanes[i]):
			return {"index": i, "is_front": true}
	
	# Fallback to back lanes
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
		
		# Back row without Snipe can't attack
		if not attacker.is_front_row and not attacker.has_snipe:
			continue
		
		var target = _ai_choose_attack_target(attacker)
		
		if target == null:
			# Attack hero if front row is empty
			if _is_enemy_front_row_empty():
				if not (attacker.has_rush and attacker.just_played):
					var enemy_id = GameManager.get_opponent_id(player_id)
					await _animate_attack_hero(attacker)
					GameManager.attack_hero(attacker, enemy_id)
					await get_tree().create_timer(ai_action_delay).timeout
		else:
			await _animate_attack(attacker, target)
			GameManager.execute_combat(attacker, target)
			await get_tree().create_timer(ai_action_delay).timeout


func _ai_choose_attack_target(attacker: Node) -> Node:
	var front_row_empty = _is_enemy_front_row_empty()
	
	# Must attack front row if not empty
	if not front_row_empty:
		for lane in enemy_front_lanes:
			var slot = _get_minion_slot(lane)
			if slot and slot.get_child_count() > 0:
				return slot.get_child(0)
	else:
		# Can attack back row or hero
		for lane in enemy_back_lanes:
			var slot = _get_minion_slot(lane)
			if slot and slot.get_child_count() > 0:
				return slot.get_child(0)
	
	return null
