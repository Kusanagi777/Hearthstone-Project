# res://autoload/game_manager.gd
extends Node

## =============================================================================
## SIGNALS
## =============================================================================

## Core game signals
signal game_started()
signal game_ended(winner_id: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)

## Card signals
signal card_drawn(player_id: int, card: CardData)
signal card_played(player_id: int, card: CardData)
signal card_discarded(player_id: int, card: CardData)

## Resource signals
signal mana_changed(player_id: int, current: int, maximum: int)
signal health_changed(player_id: int, current: int, maximum: int)

## Combat signals
signal combat_occurred(attacker_data: Dictionary, defender_data: Dictionary)
signal minion_died(player_id: int, minion: Node, board_position: int)
signal minion_summoned(player_id: int, minion: Node)


## =============================================================================
## CONSTANTS
## =============================================================================

## Game phase enumeration
enum GamePhase {
	IDLE,
	STARTING,
	DRAW,
	PLAY,
	COMBAT,
	END_TURN,
	GAME_OVER
}

## Player ID constants
const PLAYER_ONE: int = 0
const PLAYER_TWO: int = 1

## Mana system constants
const MAX_MANA_CAP: int = 10
const STARTING_HAND_SIZE: int = 3
const CARDS_DRAWN_PER_TURN: int = 1
const MAX_BOARD_SIZE: int = 7
const MAX_HAND_SIZE: int = 10
const STARTING_HEALTH: int = 30


## =============================================================================
## STATE VARIABLES
## =============================================================================

## Current game phase
var current_phase: GamePhase = GamePhase.IDLE

## Active player (whose turn it is)
var active_player: int = PLAYER_ONE

## Turn counter
var turn_number: int = 0

## Player data storage
var players: Array[Dictionary] = []

## Track if game is initialized
var _game_initialized: bool = false

## Track first turn for draw skip
var _first_turn: Array[bool] = [true, true]

## Track deferred card draws
var _deferred_draws: Array[Dictionary] = []

## Track controller readiness
var _controllers_ready: bool = false


## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready() -> void:
	_initialize_player_data()


func _initialize_player_data() -> void:
	players.clear()
	for i in range(2):
		players.append({
			"current_mana": 0,
			"max_mana": 0,
			"hero_health": STARTING_HEALTH,
			"hero_max_health": STARTING_HEALTH,
			"hero_armor": 0,
			"deck": [] as Array[CardData],
			"hand": [] as Array[CardData],
			"board": [] as Array[Node],
			"graveyard": [] as Array[CardData],
			"fatigue_counter": 0,
			"cards_drawn_this_turn": [] as Array[String],
			# Class resource (Battery, Hunger, Spirit, etc.)
			"class_resource": 0,
			"max_class_resource": 10,
			"class_resource_type": ""  # Set based on class selection
		})


## Reset game to initial state
func reset_game() -> void:
	_game_initialized = false
	_controllers_ready = false
	_first_turn = [true, true]
	_deferred_draws.clear()
	turn_number = 0
	active_player = PLAYER_ONE
	current_phase = GamePhase.IDLE
	_initialize_player_data()
	
	# Clear modifiers on game reset
	if ModifierManager:
		ModifierManager.clear_all_modifiers()


## Called by PlayerController when it's ready
func register_controller_ready() -> void:
	if not _controllers_ready:
		call_deferred("_check_controllers_ready")


func _check_controllers_ready() -> void:
	_controllers_ready = true
	_flush_deferred_draws()


func _flush_deferred_draws() -> void:
	for draw_data in _deferred_draws:
		card_drawn.emit(draw_data["player_id"], draw_data["card"])
	_deferred_draws.clear()


## =============================================================================
## GAME FLOW
## =============================================================================

func start_game() -> void:
	if _game_initialized:
		return
	
	_game_initialized = true
	current_phase = GamePhase.STARTING
	
	# Shuffle decks
	for i in range(2):
		players[i]["deck"].shuffle()
	
	# Draw starting hands
	for i in range(2):
		for j in range(STARTING_HAND_SIZE):
			_draw_card(i)
	
	game_started.emit()
	
	# Start first turn
	_start_turn(PLAYER_ONE)


func _start_turn(player_id: int) -> void:
	active_player = player_id
	turn_number += 1
	current_phase = GamePhase.DRAW
	
	print("[GameManager] === Turn %d - Player %d ===" % [turn_number, player_id])
	
	# Increment max mana (up to cap) - WITH MODIFIER
	var p := players[player_id]
	var base_mana_gain := 1
	var modified_mana_gain := base_mana_gain
	if ModifierManager:
		modified_mana_gain = ModifierManager.apply_mana_gain_modifiers(base_mana_gain, player_id)
	
	p["max_mana"] = mini(p["max_mana"] + modified_mana_gain, MAX_MANA_CAP)
	p["current_mana"] = p["max_mana"]
	
	# Clear cards drawn this turn tracking
	p["cards_drawn_this_turn"].clear()
	
	mana_changed.emit(player_id, p["current_mana"], p["max_mana"])
	
	# Draw card (skip on very first turn for player going first)
	if _first_turn[player_id]:
		_first_turn[player_id] = false
	else:
		_draw_card(player_id)
	
	# Reset minion attacks
	_reset_minion_attacks(player_id)
	
	current_phase = GamePhase.PLAY
	
	# MODIFIER HOOK: Trigger turn start
	if ModifierManager:
		ModifierManager.trigger_turn_start(player_id)
	
	turn_started.emit(player_id)


func end_turn() -> void:
	if current_phase == GamePhase.GAME_OVER:
		return
	
	current_phase = GamePhase.END_TURN
	
	# MODIFIER HOOK: Trigger turn end
	if ModifierManager:
		ModifierManager.trigger_turn_end(active_player)
	
	turn_ended.emit(active_player)
	
	# Switch to other player
	var next_player := PLAYER_TWO if active_player == PLAYER_ONE else PLAYER_ONE
	_start_turn(next_player)


func _reset_minion_attacks(player_id: int) -> void:
	var board: Array = players[player_id]["board"]
	for minion in board:
		if is_instance_valid(minion):
			minion.has_attacked = false
			minion.attacks_this_turn = 0


## =============================================================================
## CARD DRAWING
## =============================================================================

func _draw_card(player_id: int) -> void:
	var p := players[player_id]
	var deck: Array = p["deck"]
	var hand: Array = p["hand"]
	
	if deck.is_empty():
		# Fatigue damage
		p["fatigue_counter"] += 1
		var fatigue_damage: int = p["fatigue_counter"]
		p["hero_health"] -= fatigue_damage
		print("[GameManager] Player %d takes %d fatigue damage!" % [player_id, fatigue_damage])
		health_changed.emit(player_id, p["hero_health"], p["hero_max_health"])
		_check_hero_death(player_id)
		return
	
	if hand.size() >= MAX_HAND_SIZE:
		# Overdraw - burn card
		var burned_card: CardData = deck.pop_back()
		p["graveyard"].append(burned_card)
		print("[GameManager] Player %d hand full, burned: %s" % [player_id, burned_card.card_name])
		
		# MODIFIER HOOK: Card discarded (burned)
		if ModifierManager:
			ModifierManager.trigger_card_discarded(burned_card, player_id)
		
		card_discarded.emit(player_id, burned_card)
		return
	
	var drawn_card: CardData = deck.pop_back()
	
	# Track that this card was drawn this turn (for Fated)
	p["cards_drawn_this_turn"].append(drawn_card.get_runtime_id())
	
	hand.append(drawn_card)
	
	# MODIFIER HOOK: Card drawn
	if ModifierManager:
		ModifierManager.trigger_card_drawn(drawn_card, player_id)
	
	if _controllers_ready:
		card_drawn.emit(player_id, drawn_card)
	else:
		_deferred_draws.append({"player_id": player_id, "card": drawn_card})
	
	print("[GameManager] Player %d drew: %s" % [player_id, drawn_card.card_name])


## =============================================================================
## MANA MANAGEMENT
## =============================================================================

func get_current_mana(player_id: int) -> int:
	return players[player_id]["current_mana"]


func get_max_mana(player_id: int) -> int:
	return players[player_id]["max_mana"]


func spend_mana(player_id: int, amount: int) -> bool:
	var p := players[player_id]
	if p["current_mana"] >= amount:
		p["current_mana"] -= amount
		mana_changed.emit(player_id, p["current_mana"], p["max_mana"])
		return true
	return false


func add_mana(player_id: int, amount: int) -> void:
	var p := players[player_id]
	p["current_mana"] = mini(p["current_mana"] + amount, p["max_mana"])
	mana_changed.emit(player_id, p["current_mana"], p["max_mana"])


## Get the effective cost of a card (with modifiers applied)
func get_card_cost(card: CardData, player_id: int) -> int:
	var base_cost := card.cost
	if ModifierManager:
		return ModifierManager.apply_card_cost_modifiers(card, base_cost, player_id)
	return base_cost


## =============================================================================
## CLASS RESOURCE MANAGEMENT
## =============================================================================

func get_class_resource(player_id: int) -> int:
	return players[player_id]["class_resource"]


func get_max_class_resource(player_id: int) -> int:
	return players[player_id]["max_class_resource"]


func get_class_resource_type(player_id: int) -> String:
	return players[player_id]["class_resource_type"]


func add_class_resource(player_id: int, amount: int) -> void:
	var p := players[player_id]
	var resource_type: String = p["class_resource_type"]
	
	# MODIFIER HOOK: Modify class resource gain
	var modified_amount := amount
	if ModifierManager and not resource_type.is_empty():
		modified_amount = ModifierManager.apply_class_resource_gain_modifiers(resource_type, amount, player_id)
	
	p["class_resource"] = mini(p["class_resource"] + modified_amount, p["max_class_resource"])


func spend_class_resource(player_id: int, amount: int) -> bool:
	var p := players[player_id]
	var resource_type: String = p["class_resource_type"]
	
	# MODIFIER HOOK: Modify class resource cost
	var modified_amount := amount
	if ModifierManager and not resource_type.is_empty():
		modified_amount = ModifierManager.apply_class_resource_cost_modifiers(resource_type, amount, player_id)
	
	if p["class_resource"] >= modified_amount:
		p["class_resource"] -= modified_amount
		return true
	return false


func set_class_resource_type(player_id: int, resource_type: String) -> void:
	players[player_id]["class_resource_type"] = resource_type


## =============================================================================
## CARD PLAYING
## =============================================================================

func can_play_card(player_id: int, card: CardData) -> bool:
	if not is_player_turn(player_id):
		return false
	
	# Check mana cost (with modifiers)
	var effective_cost := get_card_cost(card, player_id)
	if players[player_id]["current_mana"] < effective_cost:
		return false
	
	# MODIFIER HOOK: Check if modifiers prevent playing this card
	if ModifierManager:
		if not ModifierManager.can_play_card(card, player_id):
			return false
	
	return true


func play_card(player_id: int, card: CardData, target: Variant = null) -> bool:
	if not can_play_card(player_id, card):
		return false
	
	var p := players[player_id]
	
	# Get modified cost
	var effective_cost := get_card_cost(card, player_id)
	
	# Spend mana
	if not spend_mana(player_id, effective_cost):
		return false
	
	# Remove from hand
	var hand: Array = p["hand"]
	var index := hand.find(card)
	if index != -1:
		hand.remove_at(index)
	
	# MODIFIER HOOK: Card played (before effects)
	if ModifierManager:
		ModifierManager.trigger_card_played(card, player_id, target)
	
	# Check Fated keyword
	if card.has_keyword("Fated"):
		if card.get_runtime_id() in p["cards_drawn_this_turn"]:
			print("[GameManager] Fated triggered for %s!" % card.card_name)
			# Fated effect will be handled by minion/effect system
	
	card_played.emit(player_id, card)
	print("[GameManager] Player %d played %s (cost: %d)" % [player_id, card.card_name, effective_cost])
	
	# MODIFIER HOOK: Card resolved (after effects would be processed)
	# Note: For async effects, you'd call this after effects complete
	if ModifierManager:
		ModifierManager.trigger_card_resolved(card, player_id)
	
	return true


## =============================================================================
## BOARD MANAGEMENT
## =============================================================================

## Register a minion on the board
func register_minion_on_board(player_id: int, minion_node: Node, lane: int = -1, row: int = -1) -> void:
	players[player_id]["board"].append(minion_node)
	print("[GameManager] Registered minion on board for player %d" % player_id)
	
	# MODIFIER HOOK: Minion summoned
	if ModifierManager:
		var row_int := 0 if minion_node.is_front_row else 1
		ModifierManager.trigger_minion_summoned(minion_node, player_id, minion_node.lane_index, row_int)
	
	minion_summoned.emit(player_id, minion_node)


## Remove a minion from the board
func remove_minion_from_board(player_id: int, minion_node: Node) -> void:
	var board: Array = players[player_id]["board"]
	var index := board.find(minion_node)
	if index != -1:
		board.remove_at(index)


## Get board for a player
func get_board(player_id: int) -> Array:
	return players[player_id]["board"]


## =============================================================================
## COMBAT SYSTEM
## =============================================================================

## Check if a target minion is valid for attack (respects Taunt)
func is_valid_attack_target(attacker_player_id: int, target: Node) -> bool:
	if not target or not is_instance_valid(target):
		return false
	
	# Can't attack your own minions
	if target.owner_id == attacker_player_id:
		return false
	
	# Can't target Hidden minions
	if target.has_hidden:
		return false
	
	# MODIFIER HOOK: Check if modifiers allow targeting
	if ModifierManager:
		# We'd need the attacker node here for full implementation
		# For now, just check the target
		pass
	
	# Check if there's a Taunt minion in the same row that must be targeted first
	var defender_player_id: int = target.owner_id
	var board: Array = players[defender_player_id]["board"]
	
	# Find all Taunt minions in the same row as the target
	var same_row_taunts: Array = []
	for minion in board:
		if minion and is_instance_valid(minion):
			if minion.is_front_row == target.is_front_row and minion.has_taunt:
				same_row_taunts.append(minion)
	
	# If there are Taunt minions in this row, target must be one of them
	if same_row_taunts.size() > 0 and not target.has_taunt:
		return false
	
	return true


## Execute combat between two minions
func execute_combat(attacker: Node, defender: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	current_phase = GamePhase.COMBAT
	
	# MODIFIER HOOK: Combat start
	if ModifierManager:
		ModifierManager.trigger_combat_start()
	
	var attacker_attack: int = attacker.get_effective_attack()
	var defender_attack: int = defender.get_effective_attack()
	
	var attacker_shielded: bool = attacker.has_shielded
	var defender_shielded: bool = defender.has_shielded
	
	# Calculate base damage
	var damage_to_attacker: int = defender_attack
	var damage_to_defender: int = attacker_attack
	
	# MODIFIER HOOK: Modify damage dealt by attacker
	if ModifierManager:
		damage_to_defender = ModifierManager.apply_damage_dealt_modifiers(
			damage_to_defender, attacker, defender, "combat"
		)
	
	# MODIFIER HOOK: Modify damage taken by defender
	if ModifierManager:
		damage_to_defender = ModifierManager.apply_damage_taken_modifiers(
			damage_to_defender, attacker, defender, "combat"
		)
	
	# MODIFIER HOOK: Modify damage dealt by defender (counter-attack)
	if ModifierManager:
		damage_to_attacker = ModifierManager.apply_damage_dealt_modifiers(
			damage_to_attacker, defender, attacker, "combat"
		)
	
	# MODIFIER HOOK: Modify damage taken by attacker
	if ModifierManager:
		damage_to_attacker = ModifierManager.apply_damage_taken_modifiers(
			damage_to_attacker, defender, attacker, "combat"
		)
	
	# Check Bully bonus
	var bully_active: bool = false
	if attacker.has_bully and attacker_attack > defender_attack:
		bully_active = true
		print("[GameManager] Bully active! %s attacking weaker target" % attacker.card_data.card_name)
		# Bully bonus effect would be processed here or by the minion
		if ModifierManager:
			ModifierManager.trigger_keyword("Bully", attacker, {"defender": defender})
	
	# Apply damage
	defender.take_damage(damage_to_defender)
	attacker.take_damage(damage_to_attacker)
	
	# MODIFIER HOOK: Trigger damage dealt/taken events
	if ModifierManager:
		if damage_to_defender > 0:
			ModifierManager.trigger_damage_dealt(damage_to_defender, attacker, defender)
			ModifierManager.trigger_damage_taken(damage_to_defender, attacker, defender)
		if damage_to_attacker > 0:
			ModifierManager.trigger_damage_dealt(damage_to_attacker, defender, attacker)
			ModifierManager.trigger_damage_taken(damage_to_attacker, defender, attacker)
	
	# MODIFIER HOOK: Minion attack event
	if ModifierManager:
		ModifierManager.trigger_minion_attack(attacker, defender)
	
	# Handle Drain keyword
	if attacker.has_drain and damage_to_defender > 0 and not defender_shielded:
		var drain_amount := damage_to_defender
		if ModifierManager:
			drain_amount = ModifierManager.apply_keyword_value_modifiers("Drain", drain_amount, attacker)
			ModifierManager.trigger_keyword("Drain", attacker, {"amount": drain_amount})
		_heal_hero(attacker.owner_id, drain_amount)
		print("[GameManager] Drain: Healed %d" % drain_amount)
	
	# Handle Lethal keyword
	if attacker.has_lethal and damage_to_defender > 0 and not defender_shielded:
		defender.current_health = 0
		print("[GameManager] Lethal triggered!")
		if ModifierManager:
			ModifierManager.trigger_keyword("Lethal", attacker, {"victim": defender})
	
	if defender.has_lethal and damage_to_attacker > 0 and not attacker_shielded:
		attacker.current_health = 0
		print("[GameManager] Lethal counter-triggered!")
		if ModifierManager:
			ModifierManager.trigger_keyword("Lethal", defender, {"victim": attacker})
	
	# Hidden breaks when attacking
	if attacker.has_hidden:
		attacker.break_hidden()
	
	# Mark attacker as having attacked
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	# Emit combat data
	var attacker_data := {
		"node": attacker,
		"damage_dealt": damage_to_defender,
		"damage_taken": damage_to_attacker
	}
	var defender_data := {
		"node": defender,
		"damage_dealt": damage_to_attacker,
		"damage_taken": damage_to_defender
	}
	combat_occurred.emit(attacker_data, defender_data)
	
	# MODIFIER HOOK: Combat end
	if ModifierManager:
		ModifierManager.trigger_combat_end()
	
	await get_tree().process_frame
	_check_minion_deaths()
	
	current_phase = GamePhase.PLAY


## Attack the enemy hero
func attack_hero(attacker: Node, target_player_id: int) -> void:
	if not is_instance_valid(attacker):
		return
	
	var attacker_attack: int = attacker.get_effective_attack()
	var player_data: Dictionary = players[target_player_id]
	var damage_dealt := 0
	
	# MODIFIER HOOK: Modify damage dealt to hero
	var modified_damage := attacker_attack
	if ModifierManager:
		modified_damage = ModifierManager.apply_damage_dealt_modifiers(
			modified_damage, attacker, null, "hero_attack"
		)
	
	# Damage armor first
	if player_data["hero_armor"] > 0:
		var armor_damage := mini(modified_damage, player_data["hero_armor"])
		player_data["hero_armor"] -= armor_damage
		modified_damage -= armor_damage
		damage_dealt += armor_damage
	
	if modified_damage > 0:
		player_data["hero_health"] -= modified_damage
		damage_dealt += modified_damage
	
	# Drain when attacking hero
	if attacker.has_drain and damage_dealt > 0:
		var drain_amount := damage_dealt
		if ModifierManager:
			drain_amount = ModifierManager.apply_keyword_value_modifiers("Drain", drain_amount, attacker)
			ModifierManager.trigger_keyword("Drain", attacker, {"amount": drain_amount, "target": "hero"})
		_heal_hero(attacker.owner_id, drain_amount)
		print("[GameManager] Drain: Healed %d from hero attack" % drain_amount)
	
	# Hidden breaks when attacking
	if attacker.has_hidden:
		attacker.break_hidden()
	
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	# MODIFIER HOOK: Trigger damage events
	if ModifierManager and damage_dealt > 0:
		ModifierManager.trigger_damage_dealt(damage_dealt, attacker, null)
	
	print("[GameManager] Player %d hero took %d damage, now at %d HP" % [
		target_player_id, damage_dealt, player_data["hero_health"]
	])
	
	health_changed.emit(target_player_id, player_data["hero_health"], player_data["hero_max_health"])
	_check_hero_death(target_player_id)


func _heal_hero(player_id: int, amount: int) -> void:
	var player_data: Dictionary = players[player_id]
	var old_health: int = player_data["hero_health"]
	
	# MODIFIER HOOK: Modify healing
	var modified_amount := amount
	if ModifierManager:
		modified_amount = ModifierManager.apply_healing_modifiers(amount, null, null)
	
	player_data["hero_health"] = mini(
		player_data["hero_health"] + modified_amount,
		player_data["hero_max_health"]
	)
	
	if player_data["hero_health"] != old_health:
		health_changed.emit(player_id, player_data["hero_health"], player_data["hero_max_health"])
		
		# MODIFIER HOOK: Healing applied
		if ModifierManager:
			ModifierManager.trigger_healing_applied(modified_amount, null, null)


## =============================================================================
## DEATH CHECKING
## =============================================================================

func _check_minion_deaths() -> void:
	for player_id in range(2):
		var board: Array = players[player_id]["board"]
		var dead_minions: Array = []
		
		for minion in board:
			if is_instance_valid(minion) and minion.current_health <= 0:
				dead_minions.append(minion)
		
		for minion in dead_minions:
			_handle_minion_death(player_id, minion)


func _handle_minion_death(player_id: int, minion: Node) -> void:
	var board_position = players[player_id]["board"].find(minion)
	
	# Handle Persistent keyword
	if minion.has_persistent:
		minion.current_health = 1
		minion.remove_persistent()
		print("[GameManager] Persistent triggered for %s" % minion.card_data.card_name)
		if ModifierManager:
			ModifierManager.trigger_keyword("Persistent", minion, {})
		return
	
	# Remove from board
	remove_minion_from_board(player_id, minion)
	
	# Add to graveyard
	if minion.card_data:
		players[player_id]["graveyard"].append(minion.card_data)
	
	# MODIFIER HOOK: Minion death
	if ModifierManager:
		ModifierManager.trigger_minion_death(minion, player_id, null)
	
	minion_died.emit(player_id, minion, board_position)
	
	# Queue free the minion node
	minion.queue_free()


func _check_hero_death(player_id: int) -> void:
	if players[player_id]["hero_health"] <= 0:
		var winner := PLAYER_TWO if player_id == PLAYER_ONE else PLAYER_ONE
		_end_game(winner)


func _end_game(winner_id: int) -> void:
	current_phase = GamePhase.GAME_OVER
	print("[GameManager] Game Over! Player %d wins!" % winner_id)
	game_ended.emit(winner_id)


## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

func is_player_turn(player_id: int) -> bool:
	return active_player == player_id and current_phase == GamePhase.PLAY


func get_player_health(player_id: int) -> int:
	return players[player_id]["hero_health"]


func get_hand_size(player_id: int) -> int:
	return players[player_id]["hand"].size()


func get_deck_size(player_id: int) -> int:
	return players[player_id]["deck"].size()


func set_player_deck(player_id: int, deck: Array[CardData]) -> void:
	players[player_id]["deck"] = deck.duplicate()


## =============================================================================
## TARGETING HELPERS (with modifier support)
## =============================================================================

## Get valid targets for an effect, filtered by modifiers
func get_valid_targets(source: Node, available_targets: Array) -> Array:
	if ModifierManager:
		return ModifierManager.filter_targets(source, available_targets)
	return available_targets


## Check if a specific target is valid (with modifier check)
func can_target(source: Node, target: Node) -> bool:
	if ModifierManager:
		return ModifierManager.can_target(source, target)
	return true
