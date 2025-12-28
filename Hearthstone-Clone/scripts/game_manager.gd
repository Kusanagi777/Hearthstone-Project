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

## Keyword signals
signal ritual_performed(player_id: int, card: CardData, sacrificed: Array)
signal fated_triggered(player_id: int, minion: Node, card: CardData)

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
			"cards_drawn_this_turn": [] as Array[String]
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


## Called by PlayerController when it's ready
func register_controller_ready() -> void:
	if not _controllers_ready:
		call_deferred("_check_controllers_ready")


func _check_controllers_ready() -> void:
	_controllers_ready = true
	_flush_deferred_draws()


func _flush_deferred_draws() -> void:
	for draw_data in _deferred_draws:
		card_drawn.emit(draw_data["player_id"], draw_data["card_data"])
	_deferred_draws.clear()


## =============================================================================
## DECK MANAGEMENT
## =============================================================================

## Setup a player's deck (called before game starts)
func set_player_deck(player_id: int, deck: Array[CardData]) -> void:
	if player_id < 0 or player_id > 1:
		push_error("Invalid player_id: %d" % player_id)
		return
	
	var runtime_deck: Array[CardData] = []
	for card in deck:
		runtime_deck.append(card.duplicate_for_play())
	
	players[player_id]["deck"] = runtime_deck
	_shuffle_deck(player_id)


func _shuffle_deck(player_id: int) -> void:
	var deck: Array = players[player_id]["deck"]
	for i in range(deck.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp


## =============================================================================
## GAME FLOW
## =============================================================================

## Start a new game - should be called after scene is fully loaded
func start_game() -> void:
	if _game_initialized:
		push_warning("Game already initialized")
		return
	
	_game_initialized = true
	turn_number = 0
	active_player = PLAYER_ONE
	current_phase = GamePhase.STARTING
	_first_turn = [true, true]
	
	print("[GameManager] Starting game...")
	
	# Draw starting hands
	for player_id in range(2):
		for i in range(STARTING_HAND_SIZE):
			_draw_card(player_id)
	
	game_started.emit()
	
	# Start first turn
	await get_tree().process_frame
	_start_turn(PLAYER_ONE)


func _start_turn(player_id: int) -> void:
	active_player = player_id
	turn_number += 1
	current_phase = GamePhase.DRAW
	
	print("[GameManager] === Turn %d - Player %d ===" % [turn_number, player_id])
	
	# Increment max mana (up to cap)
	var p := players[player_id]
	p["max_mana"] = mini(p["max_mana"] + 1, MAX_MANA_CAP)
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
	turn_started.emit(player_id)


func end_turn() -> void:
	if current_phase == GamePhase.GAME_OVER:
		return
	
	current_phase = GamePhase.END_TURN
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
		# Hand is full - burn the card
		var burned_card: CardData = deck.pop_front()
		print("[GameManager] Player %d hand full - burned %s" % [player_id, burned_card.card_name])
		card_discarded.emit(player_id, burned_card)
		return
	
	var card: CardData = deck.pop_front()
	hand.append(card)
	
	# Track for Fated keyword
	p["cards_drawn_this_turn"].append(card.get_runtime_id())
	
	print("[GameManager] Player %d drew %s" % [player_id, card.card_name])
	
	if _controllers_ready:
		card_drawn.emit(player_id, card)
	else:
		_deferred_draws.append({"player_id": player_id, "card_data": card})


## =============================================================================
## CARD PLAYING
## =============================================================================

## Check if a card can be played
func can_play_card(player_id: int, card: CardData) -> bool:
	if player_id != active_player:
		return false
	if current_phase != GamePhase.PLAY:
		return false
	if players[player_id]["current_mana"] < card.cost:
		return false
	return true


## Play a card from hand
func play_card(player_id: int, card: CardData) -> bool:
	if not can_play_card(player_id, card):
		return false
	
	var p := players[player_id]
	var hand: Array = p["hand"]
	
	# Find and remove from hand
	var card_index := -1
	for i in range(hand.size()):
		if hand[i].get_runtime_id() == card.get_runtime_id():
			card_index = i
			break
	
	if card_index == -1:
		push_error("Card not found in hand")
		return false
	
	hand.remove_at(card_index)
	
	# Spend mana
	p["current_mana"] -= card.cost
	mana_changed.emit(player_id, p["current_mana"], p["max_mana"])
	
	# Check Fated trigger
	if card.has_keyword("fated"):
		if p["cards_drawn_this_turn"].has(card.get_runtime_id()):
			print("[GameManager] Fated triggered for %s!" % card.card_name)
			# Fated effect will be handled by minion/effect system
	
	card_played.emit(player_id, card)
	print("[GameManager] Player %d played %s" % [player_id, card.card_name])
	
	return true


## =============================================================================
## BOARD MANAGEMENT
## =============================================================================

## Register a minion on the board
func register_minion_on_board(player_id: int, minion_node: Node) -> void:
	players[player_id]["board"].append(minion_node)
	print("[GameManager] Registered minion on board for player %d" % player_id)
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

## Execute combat between two minions
func execute_combat(attacker: Node, defender: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	current_phase = GamePhase.COMBAT
	
	var attacker_attack: int = attacker.current_attack
	var defender_attack: int = defender.current_attack
	
	var attacker_shielded: bool = attacker.has_shielded
	var defender_shielded: bool = defender.has_shielded
	
	# Calculate damage
	var damage_to_attacker: int = defender_attack
	var damage_to_defender: int = attacker_attack
	
	# Check Bully bonus
	var bully_active: bool = false
	if attacker.has_bully and attacker_attack > defender_attack:
		bully_active = true
		print("[GameManager] Bully active! Attacker has higher attack")
	
	# Handle Shielded
	if attacker_shielded and damage_to_attacker > 0:
		attacker.break_shield()
		damage_to_attacker = 0
		print("[GameManager] Attacker's Shield absorbed damage")
	
	if defender_shielded and damage_to_defender > 0:
		defender.break_shield()
		damage_to_defender = 0
		print("[GameManager] Defender's Shield absorbed damage")
	
	# Apply damage
	if damage_to_defender > 0:
		defender.take_damage(damage_to_defender)
	
	if damage_to_attacker > 0:
		attacker.take_damage(damage_to_attacker)
	
	# Check Lethal
	if attacker.has_lethal and defender.current_health > 0 and damage_to_defender > 0:
		defender.current_health = 0
		print("[GameManager] Lethal triggered - defender destroyed")
	
	if defender.has_lethal and attacker.current_health > 0 and damage_to_attacker > 0:
		attacker.current_health = 0
		print("[GameManager] Lethal triggered - attacker destroyed")
	
	# Drain healing
	if attacker.has_drain and damage_to_defender > 0:
		_heal_hero(attacker.owner_id, damage_to_defender)
		print("[GameManager] Drain: Healed %d" % damage_to_defender)
	
	# Hidden breaks on attack
	if attacker.has_hidden:
		attacker.break_hidden()
	
	# Update attack tracking
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	var attacker_data := {
		"node": attacker,
		"damage_dealt": attacker_attack,
		"damage_taken": damage_to_attacker,
		"shield_popped": attacker_shielded,
		"bully_active": bully_active
	}
	var defender_data := {
		"node": defender,
		"damage_dealt": defender_attack,
		"damage_taken": damage_to_defender,
		"shield_popped": defender_shielded
	}
	
	combat_occurred.emit(attacker_data, defender_data)
	
	await get_tree().process_frame
	_check_minion_deaths()
	
	current_phase = GamePhase.PLAY


## Attack the enemy hero
func attack_hero(attacker: Node, target_player_id: int) -> void:
	if not is_instance_valid(attacker):
		return
	
	var attacker_attack: int = attacker.current_attack
	var player_data: Dictionary = players[target_player_id]
	var damage_dealt = 0
	
	# Damage armor first
	if player_data["hero_armor"] > 0:
		var armor_damage := mini(attacker_attack, player_data["hero_armor"])
		player_data["hero_armor"] -= armor_damage
		attacker_attack -= armor_damage
		damage_dealt += armor_damage
	
	if attacker_attack > 0:
		player_data["hero_health"] -= attacker_attack
		damage_dealt += attacker_attack
	
	# Drain when attacking hero
	if attacker.has_drain and damage_dealt > 0:
		_heal_hero(attacker.owner_id, damage_dealt)
		print("[GameManager] Drain: Healed %d from hero attack" % damage_dealt)
	
	# Hidden breaks when attacking
	if attacker.has_hidden:
		attacker.break_hidden()
	
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	print("[GameManager] Player %d hero took %d damage, now at %d HP" % [
		target_player_id, damage_dealt, player_data["hero_health"]
	])
	
	health_changed.emit(target_player_id, player_data["hero_health"], player_data["hero_max_health"])
	_check_hero_death(target_player_id)


func _heal_hero(player_id: int, amount: int) -> void:
	var player_data: Dictionary = players[player_id]
	var old_health: int = player_data["hero_health"]
	player_data["hero_health"] = mini(
		player_data["hero_health"] + amount,
		player_data["hero_max_health"]
	)
	if player_data["hero_health"] != old_health:
		health_changed.emit(player_id, player_data["hero_health"], player_data["hero_max_health"])


## =============================================================================
## DEATH CHECKING
## =============================================================================

func _check_minion_deaths() -> void:
	for player_id in range(2):
		var board: Array = players[player_id]["board"]
		var dead_minions: Array[Node] = []
		
		for minion in board:
			if is_instance_valid(minion) and minion.current_health <= 0:
				dead_minions.append(minion)
		
		for minion in dead_minions:
			await _destroy_minion(player_id, minion)


func _destroy_minion(player_id: int, minion: Node) -> void:
	var board: Array = players[player_id]["board"]
	var board_pos := board.find(minion)
	
	if board_pos == -1:
		return
	
	# Check Persistent keyword
	if minion.has_persistent:
		minion.trigger_persistent()
		print("[GameManager] Persistent triggered - minion revived with 1 HP")
		return
	
	# Remove from board
	board.remove_at(board_pos)
	
	# Add to graveyard
	if minion.card_data:
		players[player_id]["graveyard"].append(minion.card_data)
	
	print("[GameManager] Minion destroyed: %s" % minion.card_data.card_name if minion.card_data else "Unknown")
	
	minion_died.emit(player_id, minion, board_pos)
	
	# Trigger on-death effects
	if minion.has_method("trigger_on_death"):
		await minion.trigger_on_death()
	
	# Clean up the node
	if is_instance_valid(minion):
		minion.queue_free()


func _kill_minion(player_id: int, minion: Node, board_pos: int) -> void:
	# Direct kill without Persistent check (for Ritual sacrifice, etc.)
	var board: Array = players[player_id]["board"]
	
	if board_pos >= 0 and board_pos < board.size():
		board.remove_at(board_pos)
	
	if minion.card_data:
		players[player_id]["graveyard"].append(minion.card_data)
	
	minion_died.emit(player_id, minion, board_pos)
	
	if is_instance_valid(minion):
		minion.queue_free()


func _check_hero_death(player_id: int) -> void:
	if players[player_id]["hero_health"] <= 0:
		var winner := PLAYER_TWO if player_id == PLAYER_ONE else PLAYER_ONE
		_end_game(winner)


func _end_game(winner_id: int) -> void:
	current_phase = GamePhase.GAME_OVER
	print("[GameManager] === GAME OVER === Winner: Player %d" % winner_id)
	game_ended.emit(winner_id)


## =============================================================================
## RITUAL SYSTEM
## =============================================================================

## Perform a Ritual sacrifice
func perform_ritual(player_id: int, card: CardData, sacrifices: Array[Node]) -> bool:
	if sacrifices.is_empty():
		return false
	
	var required_sacrifices: int = card.get_ritual_cost()
	if sacrifices.size() < required_sacrifices:
		print("[GameManager] Ritual needs %d sacrifices, only %d provided" % [required_sacrifices, sacrifices.size()])
		return false
	
	var sacrificed_cards: Array = []
	
	for minion in sacrifices:
		if not is_instance_valid(minion):
			continue
		if minion.owner_id != player_id:
			continue
		
		sacrificed_cards.append(minion.card_data)
		
		if minion.has_method("play_ritual_sacrifice_effect"):
			await minion.play_ritual_sacrifice_effect()
		
		var board_pos: int = players[player_id]["board"].find(minion)
		await _kill_minion(player_id, minion, board_pos)
	
	if sacrificed_cards.size() > 0:
		ritual_performed.emit(player_id, card, sacrificed_cards)
		print("[GameManager] Ritual performed! Sacrificed %d minions" % sacrificed_cards.size())
		return true
	
	return false


## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

## Check if it's a player's turn
func is_player_turn(player_id: int) -> bool:
	return active_player == player_id and current_phase == GamePhase.PLAY


## Get current mana for a player
func get_current_mana(player_id: int) -> int:
	return players[player_id]["current_mana"]


## Get max mana for a player
func get_max_mana(player_id: int) -> int:
	return players[player_id]["max_mana"]


## Get hero health for a player
func get_hero_health(player_id: int) -> int:
	return players[player_id]["hero_health"]


## Get hand for a player
func get_hand(player_id: int) -> Array:
	return players[player_id]["hand"]


## Get deck count for a player
func get_deck_count(player_id: int) -> int:
	return players[player_id]["deck"].size()
