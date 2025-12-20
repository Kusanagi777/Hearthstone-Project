# res://scripts/player_controller.gd
class_name player_controller
extends Node

## Emitted when a card in hand is clicked
signal card_selected(card_ui: Control)

## Emitted when a card is dropped on a valid zone
signal card_dropped_on_board(card_ui: Control)

## Emitted when targeting mode begins
signal targeting_started(source: Node)

## Emitted when targeting mode ends
signal targeting_ended(source: Node, target: Node)

## This player's ID (0 or 1)
@export var player_id: int = 0

## Reference to the hand container
@export var hand_container: Control

## Reference to the board zone
@export var board_zone: Control

## Reference to the enemy board zone (for targeting)
@export var enemy_board_zone: Control

## Reference to enemy hero (for targeting)
@export var enemy_hero_area: Control

## Reference to own hero area
@export var hero_area: Control

## Card UI scene to instantiate
@export var card_ui_scene: PackedScene

## Minion scene to instantiate
@export var minion_scene: PackedScene

## Targeting arrow scene
@export var targeting_arrow_scene: PackedScene

## Current targeting arrow instance
var _targeting_arrow: Node = null

## Currently dragged card
var _dragged_card: Control = null

## Currently selected attacker (for combat targeting)
var _selected_attacker: Node = null

## Is this an AI controlled player?
@export var is_ai: bool = false

## AI thinking delay (seconds)
@export var ai_think_delay: float = 0.8

## AI action delay between actions
@export var ai_action_delay: float = 0.5

## Is AI currently taking its turn?
var _ai_thinking: bool = false


func _ready() -> void:
	# Wait for tree to be ready before connecting signals
	if not is_inside_tree():
		await ready
	
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	_connect_signals()
	
	# Notify GameManager that this controller is ready
	GameManager.register_controller_ready()
	
	print("[PlayerController %d] Ready, is_ai: %s" % [player_id, is_ai])


func _connect_signals() -> void:
	# Disconnect first to avoid duplicates
	if GameManager.card_drawn.is_connected(_on_card_drawn):
		GameManager.card_drawn.disconnect(_on_card_drawn)
	if GameManager.turn_started.is_connected(_on_turn_started):
		GameManager.turn_started.disconnect(_on_turn_started)
	if GameManager.turn_ended.is_connected(_on_turn_ended):
		GameManager.turn_ended.disconnect(_on_turn_ended)
	if GameManager.game_started.is_connected(_on_game_started):
		GameManager.game_started.disconnect(_on_game_started)
	
	# Connect signals
	GameManager.card_drawn.connect(_on_card_drawn)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.turn_ended.connect(_on_turn_ended)
	GameManager.game_started.connect(_on_game_started)


func _on_game_started() -> void:
	print("[PlayerController %d] Game started signal received" % player_id)
	_clear_hand()
	_clear_board()


func _on_turn_started(turn_player_id: int) -> void:
	print("[PlayerController %d] Turn started for player %d" % [player_id, turn_player_id])
	
	if turn_player_id == player_id:
		_enable_hand_interaction(true)
		_refresh_board_minions()
		
		# Trigger AI turn
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
	
	print("[PlayerController %d] Card drawn: %s" % [player_id, card.card_name])
	_add_card_to_hand(card)


## Add a card to the visual hand with animation
func _add_card_to_hand(card: CardData) -> void:
	if not card_ui_scene:
		push_error("[PlayerController %d] Card UI scene not set!" % player_id)
		return
	
	if not hand_container:
		push_error("[PlayerController %d] Hand container not set!" % player_id)
		return
	
	var card_ui_instance: Control = card_ui_scene.instantiate()
	
	# For AI/opponent, cards might be hidden
	if is_ai and player_id == GameManager.PLAYER_TWO:
		# Could implement face-down cards here
		pass
	
	hand_container.add_child(card_ui_instance)
	card_ui_instance.initialize(card, player_id)
	
	# Connect card signals
	if card_ui_instance.has_signal("card_clicked"):
		card_ui_instance.card_clicked.connect(_on_card_clicked)
	if card_ui_instance.has_signal("card_drag_started"):
		card_ui_instance.card_drag_started.connect(_on_card_drag_started)
	if card_ui_instance.has_signal("card_drag_ended"):
		card_ui_instance.card_drag_ended.connect(_on_card_drag_ended)
	
	# Play draw animation
	_animate_card_draw(card_ui_instance)
	
	print("[PlayerController %d] Card added to hand, hand size: %d" % [player_id, hand_container.get_child_count()])


## Animate card drawing from deck to hand
func _animate_card_draw(card_ui_instance: Control) -> void:
	# Store the target position before modifying
	var end_pos := card_ui_instance.position
	
	# Start from right side of screen (local coordinates)
	var start_x := 500.0  # Start off to the right
	card_ui_instance.position = Vector2(start_x, 0)
	
	card_ui_instance.modulate.a = 0.0
	card_ui_instance.scale = Vector2(0.5, 0.5)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(card_ui_instance, "modulate:a", 1.0, 0.3)
	tween.tween_property(card_ui_instance, "scale", Vector2.ONE, 0.4)
	tween.tween_property(card_ui_instance, "position", end_pos, 0.4)


## Handle card click
func _on_card_clicked(card_ui_instance: Control) -> void:
	if is_ai:
		return
	
	if not GameManager.is_player_turn(player_id):
		return
	
	card_selected.emit(card_ui_instance)


## Handle drag start
func _on_card_drag_started(card_ui_instance: Control) -> void:
	if is_ai:
		return
	
	if not GameManager.is_player_turn(player_id):
		return
	
	_dragged_card = card_ui_instance


## Handle drag end
func _on_card_drag_ended(card_ui_instance: Control, global_pos: Vector2) -> void:
	if not _dragged_card:
		return
	
	var dragged := _dragged_card
	_dragged_card = null
	
	# Check if dropped over board zone
	if _is_position_over_board(global_pos):
		# Try to play the card (async)
		var success := await _try_play_card_to_board(dragged)
		if not success and is_instance_valid(dragged):
			dragged.return_to_hand()
	else:
		# Return card to hand position
		dragged.return_to_hand()


## Check if a position is over the board zone
func _is_position_over_board(global_pos: Vector2) -> bool:
	if not board_zone:
		print("[PlayerController %d] No board zone set!" % player_id)
		return false
	
	# Check against parent container if it exists (PanelContainer wrapper has larger area)
	var check_node: Control = board_zone
	if board_zone.get_parent() is PanelContainer:
		check_node = board_zone.get_parent() as Control
	
	var board_rect := check_node.get_global_rect()
	var is_over := board_rect.has_point(global_pos)
	
	if is_over:
		print("[PlayerController %d] Card dropped over board zone" % player_id)
	
	return is_over


## Attempt to play a card to the board
func _try_play_card_to_board(card_ui_instance: Control, target: Variant = null) -> bool:
	var card: CardData = card_ui_instance.card_data
	
	print("[PlayerController %d] Attempting to play: %s (cost: %d, mana: %d)" % [
		player_id, 
		card.card_name, 
		card.cost,
		GameManager.get_current_mana(player_id)
	])
	
	if GameManager.try_play_card(player_id, card, target):
		print("[PlayerController %d] Card play successful!" % player_id)
		# Remove from hand visually with animation
		_animate_card_play(card_ui_instance)
		
		# Spawn minion if it's a minion card
		if card.card_type == CardData.CardType.MINION:
			# Wait for card to reach board
			await get_tree().create_timer(0.2).timeout
			_spawn_minion(card, target)
		
		return true
	else:
		print("[PlayerController %d] Card play failed!" % player_id)
		# Failed to play - return to hand
		card_ui_instance.return_to_hand()
		return false


## Animate card being played
func _animate_card_play(card_ui_instance: Control) -> void:
	# Make sure card is in top_level for smooth animation
	if not card_ui_instance.top_level:
		var gpos := card_ui_instance.global_position
		card_ui_instance.top_level = true
		card_ui_instance.global_position = gpos
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_ui_instance, "modulate:a", 0.0, 0.2)
	tween.tween_property(card_ui_instance, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_callback(card_ui_instance.queue_free).set_delay(0.2)


## Spawn a minion on the board
func _spawn_minion(card: CardData, target: Variant = null) -> Node:
	if not minion_scene:
		push_error("[PlayerController %d] Minion scene not set!" % player_id)
		return null
	
	var minion_instance: Node = minion_scene.instantiate()
	board_zone.add_child(minion_instance)
	minion_instance.initialize(card, player_id)
	
	# Apply keywords
	_apply_minion_keywords(minion_instance, card)
	
	# Connect minion signals
	if minion_instance.has_signal("minion_clicked"):
		minion_instance.minion_clicked.connect(_on_minion_clicked)
	if minion_instance.has_signal("minion_targeted"):
		minion_instance.minion_targeted.connect(_on_minion_targeted)
	
	# Register with GameManager
	GameManager.register_minion_on_board(player_id, minion_instance)
	
	# Trigger battlecry if applicable
	if card.has_keyword("Battlecry"):
		GameManager.trigger_battlecry(player_id, minion_instance, card, target)
	
	# Play summon animation
	_animate_minion_summon(minion_instance)
	
	print("[PlayerController %d] Spawned minion: %s" % [player_id, card.card_name])
	return minion_instance


## Apply keyword effects to minion
func _apply_minion_keywords(minion_instance: Node, card: CardData) -> void:
	if card.has_keyword("Charge"):
		minion_instance.just_played = false  # Can attack immediately
		minion_instance.has_charge = true
	
	if card.has_keyword("Rush"):
		minion_instance.just_played = false  # Can attack minions immediately
		minion_instance.has_rush = true
	
	if card.has_keyword("Taunt"):
		minion_instance.has_taunt = true
	
	if card.has_keyword("Divine Shield"):
		minion_instance.has_divine_shield = true
	
	if card.has_keyword("Windfury"):
		minion_instance.has_windfury = true
	
	if card.has_keyword("Stealth"):
		minion_instance.has_stealth = true
	
	if card.has_keyword("Lifesteal"):
		minion_instance.has_lifesteal = true
	
	if card.has_keyword("Poisonous"):
		minion_instance.has_poisonous = true
	
	if card.has_keyword("Reborn"):
		minion_instance.has_reborn = true


## Animate minion summoning
func _animate_minion_summon(minion_instance: Node) -> void:
	minion_instance.modulate.a = 0.0
	minion_instance.scale = Vector2(0.1, 0.1)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	
	tween.tween_property(minion_instance, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(minion_instance, "scale", Vector2.ONE, 0.4)


## Handle minion click (for attacking)
func _on_minion_clicked(minion_instance: Node) -> void:
	if is_ai:
		return
	
	if not GameManager.is_player_turn(player_id):
		return
	
	if minion_instance.owner_id != player_id:
		# Clicking enemy minion while targeting
		if _selected_attacker:
			_on_minion_targeted(minion_instance)
		return
	
	if not minion_instance.can_attack():
		return
	
	# Start targeting mode
	_selected_attacker = minion_instance
	_start_targeting(minion_instance)
	_highlight_valid_targets()


## Highlight valid attack targets
func _highlight_valid_targets() -> void:
	if not _selected_attacker:
		return
	
	var enemy_id := GameManager.get_opponent_id(player_id)
	var taunts := GameManager.get_taunt_minions(enemy_id)
	
	# Highlight enemy minions
	for minion_instance in enemy_board_zone.get_children():
		if minion_instance.has_method("set_targetable"):
			var is_valid := taunts.is_empty() or minion_instance in taunts
			minion_instance.set_targetable(is_valid)
	
	# Highlight hero if no taunts (and attacker doesn't have Rush)
	if enemy_hero_area and taunts.is_empty():
		if not (_selected_attacker.has_rush and _selected_attacker.just_played):
			# Hero can be targeted
			pass


## Clear target highlights
func _clear_target_highlights() -> void:
	if enemy_board_zone:
		for minion_instance in enemy_board_zone.get_children():
			if minion_instance.has_method("set_targetable"):
				minion_instance.set_targetable(false)


## Start targeting mode with an arrow
func _start_targeting(source: Node) -> void:
	if targeting_arrow_scene and not _targeting_arrow:
		_targeting_arrow = targeting_arrow_scene.instantiate()
		get_tree().root.add_child(_targeting_arrow)
		_targeting_arrow.start_from(source.global_position + source.size / 2)
	
	targeting_started.emit(source)


## Cancel targeting mode
func _cancel_targeting() -> void:
	if _targeting_arrow:
		_targeting_arrow.queue_free()
		_targeting_arrow = null
	
	_clear_target_highlights()
	_selected_attacker = null


## Handle minion being targeted
func _on_minion_targeted(minion_instance: Node) -> void:
	if not _selected_attacker:
		return
	
	# Can only target enemy minions
	if minion_instance.owner_id == player_id:
		_cancel_targeting()
		return
	
	# Check taunt rules
	if not GameManager.is_valid_attack_target(player_id, minion_instance):
		print("[PlayerController %d] Invalid target - must attack taunt!" % player_id)
		return
	
	# Execute combat with animation
	await _animate_attack(_selected_attacker, minion_instance)
	GameManager.execute_combat(_selected_attacker, minion_instance)
	_cancel_targeting()


## Animate attack
func _animate_attack(attacker: Node, target: Node) -> void:
	var original_pos: Vector2 = attacker.global_position
	var target_global_pos: Vector2 = target.global_position
	var bump_pos: Vector2 = original_pos.lerp(target_global_pos, 0.7)
	
	var tween := create_tween()
	tween.tween_property(attacker, "global_position", bump_pos, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_property(attacker, "global_position", original_pos, 0.15).set_ease(Tween.EASE_OUT)
	
	await tween.finished


## Handle targeting the enemy hero
func target_enemy_hero() -> void:
	if not _selected_attacker:
		return
	
	# Check if hero can be targeted (taunt check)
	if not GameManager.is_valid_attack_target(player_id, null):
		print("[PlayerController %d] Cannot attack hero - taunts in the way!" % player_id)
		_cancel_targeting()
		return
	
	# Check for Rush limitation
	if _selected_attacker.has_rush and _selected_attacker.just_played:
		print("[PlayerController %d] Rush minions cannot attack heroes on first turn!" % player_id)
		_cancel_targeting()
		return
	
	var enemy_id := GameManager.get_opponent_id(player_id)
	await _animate_attack_hero(_selected_attacker)
	GameManager.attack_hero(_selected_attacker, enemy_id)
	_cancel_targeting()


## Animate attacking hero
func _animate_attack_hero(attacker: Node) -> void:
	var original_pos: Vector2 = attacker.global_position
	var bump_direction := Vector2.UP if player_id == 0 else Vector2.DOWN
	var bump_pos: Vector2 = original_pos + bump_direction * 100
	
	var tween := create_tween()
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


## Check what we're attacking
func _check_attack_target(global_pos: Vector2) -> void:
	# Check enemy hero area
	if enemy_hero_area and enemy_hero_area.get_global_rect().has_point(global_pos):
		target_enemy_hero()
		return
	
	# Check enemy minions
	if enemy_board_zone:
		for minion_instance in enemy_board_zone.get_children():
			if minion_instance is Control and minion_instance.get_global_rect().has_point(global_pos):
				_on_minion_targeted(minion_instance)
				return
	
	# Clicked nothing valid
	_cancel_targeting()


func _process(_delta: float) -> void:
	# Update targeting arrow position
	if _targeting_arrow and _selected_attacker:
		_targeting_arrow.update_end_position(get_viewport().get_mouse_position())


## Enable/disable hand interaction
func _enable_hand_interaction(enabled: bool) -> void:
	if not hand_container:
		return
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.has_method("set_interactable"):
			card_ui_instance.set_interactable(enabled)


## Refresh board minions (reset attack availability)
func _refresh_board_minions() -> void:
	if not board_zone:
		return
	
	for minion_instance in board_zone.get_children():
		if minion_instance.has_method("refresh_for_turn"):
			minion_instance.refresh_for_turn()


## Clear the hand visually
func _clear_hand() -> void:
	if not hand_container:
		return
	
	for child in hand_container.get_children():
		child.queue_free()


## Clear the board visually
func _clear_board() -> void:
	if not board_zone:
		return
	
	for child in board_zone.get_children():
		child.queue_free()


## Request end turn
func request_end_turn() -> void:
	if GameManager.is_player_turn(player_id):
		GameManager.end_turn()


# =============================================================================
# AI LOGIC
# =============================================================================

## Start the AI turn
func _start_ai_turn() -> void:
	if not is_ai:
		return
	
	_ai_thinking = true
	print("[AI Player %d] Starting AI turn" % player_id)
	
	# Wait before acting
	await get_tree().create_timer(ai_think_delay).timeout
	
	# Execute AI actions
	await _ai_execute_turn()


## Execute the AI's turn logic
func _ai_execute_turn() -> void:
	if not GameManager.is_player_turn(player_id):
		_ai_thinking = false
		return
	
	# Phase 1: Play cards
	await _ai_play_cards()
	
	# Phase 2: Attack with minions
	await _ai_attack_with_minions()
	
	# Phase 3: End turn
	await get_tree().create_timer(ai_action_delay).timeout
	
	if GameManager.is_player_turn(player_id):
		request_end_turn()
	
	_ai_thinking = false


## AI: Play playable cards
func _ai_play_cards() -> void:
	var played_card := true
	
	while played_card and GameManager.is_player_turn(player_id):
		played_card = false
		
		# Get playable cards sorted by cost (play expensive cards first for tempo)
		var playable_cards := _ai_get_playable_cards()
		
		if playable_cards.is_empty():
			break
		
		# Sort by cost descending
		playable_cards.sort_custom(func(a, b): return a.card_data.cost > b.card_data.cost)
		
		for card_ui_instance in playable_cards:
			if not GameManager.is_player_turn(player_id):
				break
			
			var card: CardData = card_ui_instance.card_data
			
			# Check if we can afford it
			if GameManager.get_current_mana(player_id) < card.cost:
				continue
			
			# Check board space for minions
			if card.card_type == CardData.CardType.MINION:
				if board_zone.get_child_count() >= GameManager.MAX_BOARD_SIZE:
					continue
			
			# Determine target for spells
			var target: Variant = null
			if card.card_type == CardData.CardType.SPELL:
				target = _ai_choose_spell_target(card)
				if card.target_type != "None" and target == null:
					continue  # Spell requires target but none valid
			
			# Play the card
			print("[AI Player %d] Playing: %s" % [player_id, card.card_name])
			
			if await _try_play_card_to_board(card_ui_instance, target):
				played_card = true
				await get_tree().create_timer(ai_action_delay).timeout
				break  # Re-evaluate after playing


## AI: Get list of playable card UIs
func _ai_get_playable_cards() -> Array:
	var playable: Array = []
	var current_mana := GameManager.get_current_mana(player_id)
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.has_method("get") and card_ui_instance.card_data:
			if card_ui_instance.card_data.cost <= current_mana:
				playable.append(card_ui_instance)
	
	return playable


## AI: Choose target for a spell
func _ai_choose_spell_target(card: CardData) -> Variant:
	var enemy_id := GameManager.get_opponent_id(player_id)
	var enemy_minions := GameManager.get_board(enemy_id)
	var friendly_minions := GameManager.get_board(player_id)
	
	match card.target_type:
		"EnemyMinion":
			if not enemy_minions.is_empty():
				return enemy_minions[randi() % enemy_minions.size()]
		"FriendlyMinion":
			if not friendly_minions.is_empty():
				return friendly_minions[randi() % friendly_minions.size()]
		"Minion":
			var all_minions: Array = enemy_minions + friendly_minions
			if not all_minions.is_empty():
				return all_minions[randi() % all_minions.size()]
		"Hero":
			return enemy_id  # Target enemy hero
		"Character":
			# Prefer enemy targets
			if not enemy_minions.is_empty() and randf() > 0.3:
				return enemy_minions[randi() % enemy_minions.size()]
			return enemy_id
	
	return null


## AI: Attack with available minions
func _ai_attack_with_minions() -> void:
	if not GameManager.is_player_turn(player_id):
		return
	
	var enemy_id := GameManager.get_opponent_id(player_id)
	
	# Get minions that can attack
	var attackers: Array = []
	for minion_instance in board_zone.get_children():
		if minion_instance.has_method("can_attack") and minion_instance.can_attack():
			attackers.append(minion_instance)
	
	for attacker in attackers:
		if not GameManager.is_player_turn(player_id):
			break
		
		if not attacker.can_attack():
			continue
		
		# Choose target
		var target = _ai_choose_attack_target(attacker, enemy_id)
		
		if target == null:
			# Attack hero
			if GameManager.is_valid_attack_target(player_id, null):
				# Check Rush limitation
				if not (attacker.has_rush and attacker.just_played):
					print("[AI Player %d] Attacking enemy hero" % player_id)
					await _animate_attack_hero(attacker)
					GameManager.attack_hero(attacker, enemy_id)
					await get_tree().create_timer(ai_action_delay).timeout
		else:
			# Attack minion
			print("[AI Player %d] Attacking enemy minion" % player_id)
			await _animate_attack(attacker, target)
			GameManager.execute_combat(attacker, target)
			await get_tree().create_timer(ai_action_delay).timeout
		
		# Check for windfury second attack
		if is_instance_valid(attacker) and attacker.has_windfury and attacker.attacks_this_turn < 2:
			attacker.has_attacked = false
			# Will be picked up in next iteration


## AI: Choose an attack target
func _ai_choose_attack_target(attacker: Node, enemy_id: int) -> Variant:
	var enemy_minions := GameManager.get_board(enemy_id)
	var taunts := GameManager.get_taunt_minions(enemy_id)
	
	# Must attack taunts first
	if not taunts.is_empty():
		# Prioritize killing taunts we can actually kill
		for taunt in taunts:
			if taunt.current_health <= attacker.current_attack:
				return taunt
		# Otherwise attack any taunt
		return taunts[0]
	
	# Rush minions must attack minions on first turn
	if attacker.has_rush and attacker.just_played:
		if not enemy_minions.is_empty():
			return _ai_choose_best_trade(attacker, enemy_minions)
		return null  # Can't attack hero with Rush on first turn
	
	# Strategic target selection
	if not enemy_minions.is_empty():
		# 70% chance to go face if no good trades
		if randf() < 0.3:
			return _ai_choose_best_trade(attacker, enemy_minions)
	
	return null  # Attack hero


## AI: Choose the best trade
func _ai_choose_best_trade(attacker: Node, enemy_minions: Array) -> Node:
	var best_target: Node = null
	var best_score: float = -999.0
	
	for enemy in enemy_minions:
		if not is_instance_valid(enemy):
			continue
		
		var score: float = 0.0
		
		# Can we kill it?
		var can_kill: bool = enemy.current_health <= attacker.current_attack
		# Will it kill us?
		var will_die: bool = attacker.current_health <= enemy.current_attack
		
		if can_kill and not will_die:
			score += 10.0  # Good trade
		elif can_kill and will_die:
			# Value trade: compare stats
			score += (enemy.current_attack + enemy.current_health) - (attacker.current_attack + attacker.current_health)
		elif not can_kill:
			score -= 5.0  # Bad trade
		
		# Bonus for killing high-attack minions
		score += enemy.current_attack * 0.5
		
		# Bonus for killing special minions
		if enemy.has_taunt:
			score += 3.0
		if enemy.has_divine_shield:
			score += 2.0
		
		if score > best_score:
			best_score = score
			best_target = enemy
	
	return best_target
