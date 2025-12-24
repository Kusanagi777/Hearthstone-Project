# res://autoload/game_manager.gd
extends Node

## Emitted when the game begins
signal game_started

## Emitted when a turn begins for a player
signal turn_started(player_id: int)

## Emitted when the draw phase begins
signal draw_phase_started(player_id: int)

## Emitted when the play phase begins (main phase)
signal play_phase_started(player_id: int)

## Emitted when a turn ends
signal turn_ended(player_id: int)

## Emitted when mana changes
signal mana_changed(player_id: int, current: int, maximum: int)

## Emitted when the unique class resource changes
signal resource_changed(player_id: int, current: int, maximum: int)

## Emitted when a card is drawn
signal card_drawn(player_id: int, card: CardData)

## Emitted when a card is played
signal card_played(player_id: int, card: CardData, target: Variant)

## Emitted when combat occurs
signal combat_occurred(attacker_data: Dictionary, defender_data: Dictionary)

## Emitted when an entity dies
signal entity_died(player_id: int, entity_node: Node)

## Emitted when the game ends
signal game_ended(winner_id: int)

## Emitted when a spell is cast
signal spell_cast(player_id: int, card: CardData, target: Variant)

## Emitted when a weapon is equipped
signal weapon_equipped(player_id: int, card: CardData)

## Emitted for battlecry triggers
signal battlecry_triggered(player_id: int, minion: Node, card: CardData)

## Emitted for deathrattle triggers
signal deathrattle_triggered(player_id: int, card: CardData, board_position: int)

## Emitted for minions with persistent
signal persistent_respawn_requested(player_id: int, card: CardData, lane_index: int, is_front: bool)

## NEW KEYWORD SIGNALS
## Emitted when Bully bonus triggers
signal bully_triggered(player_id: int, attacker: Node, defender: Node)

## Emitted when Overclock is activated
signal overclock_triggered(player_id: int, minion: Node, battery_spent: int)

## Emitted when a huddled minion is promoted
signal huddle_promoted(player_id: int, promoted_minion: Node, lane_index: int, is_front: bool)

## Emitted when a Ritual is performed
signal ritual_performed(player_id: int, card: CardData, sacrificed_minions: Array)

## Emitted when Fated bonus triggers
signal fated_triggered(player_id: int, minion: Node, card: CardData)

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


func _ready() -> void:
	_initialize_player_data()


func _initialize_player_data() -> void:
	players.clear()
	for i in range(2):
		players.append({
			"class_id": "neutral",
			"class_resource": 0,
			"class_resource_max": 0,
			"current_mana": 0,
			"max_mana": 0,
			"hero_health": 30,
			"hero_max_health": 30,
			"hero_armor": 0,
			"deck": [] as Array[CardData],
			"hand": [] as Array[CardData],
			"board": [] as Array[Node],
			"graveyard": [] as Array[CardData],
			"weapon": null,
			"weapon_durability": 0,
			"fatigue_counter": 0,
			"cards_drawn_this_turn": [] as Array[String]
		})


## Sets the class identity for a player (Call this before start_game)
func set_player_class(player_id: int, class_name_str: String) -> void:
	var pid = class_name_str.to_lower()
	players[player_id]["class_id"] = pid
	players[player_id]["class_resource"] = 0
	
	# Set resource caps based on class
	match pid:
		"cute": players[player_id]["class_resource_max"] = 999  # No limit
		"technical": players[player_id]["class_resource_max"] = 10  # Battery
		"brute": players[player_id]["class_resource_max"] = 30  # Hunger
		"other": players[player_id]["class_resource_max"] = 3  # Omen
		"ace": players[player_id]["class_resource_max"] = 5  # Spirit
		_: players[player_id]["class_resource_max"] = 0


## Helper to modify unique resources
func _modify_resource(player_id: int, amount: int) -> void:
	var p = players[player_id]
	var old_val = p["class_resource"]
	var max_val = p["class_resource_max"]
	
	p["class_resource"] = clampi(old_val + amount, 0, max_val)
	
	if p["class_resource"] != old_val:
		print("[GameManager] Player %d resource (%s) changed: %d -> %d" % [player_id, p["class_id"], old_val, p["class_resource"]])
		resource_changed.emit(player_id, p["class_resource"], max_val)


## Get current class resource for a player
func get_class_resource(player_id: int) -> int:
	return players[player_id]["class_resource"]


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
	
	print("[GameManager] Game starting...")
	game_started.emit()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Draw starting hands
	for player_id in range(2):
		print("[GameManager] Drawing starting hand for player %d" % player_id)
		for i in range(STARTING_HAND_SIZE):
			_draw_card_animated(player_id)
			await get_tree().create_timer(0.15).timeout
		
		# Player 2 gets "The Coin" - extra card
		if player_id == PLAYER_TWO:
			_draw_card_animated(player_id)
	
	await get_tree().create_timer(0.5).timeout
	_start_turn(PLAYER_ONE)


func _draw_card_animated(player_id: int) -> CardData:
	var card := _draw_card(player_id)
	return card


## Start a player's turn
func _start_turn(player_id: int) -> void:
	active_player = player_id
	turn_number += 1
	current_phase = GamePhase.DRAW
	
	print("[GameManager] Starting turn %d for player %d" % [turn_number, player_id])
	
	# Clear Fated tracking for this turn
	players[player_id]["cards_drawn_this_turn"] = []
	
	# Increment max mana (capped at 10)
	var player_data: Dictionary = players[player_id]
	if player_data["max_mana"] < MAX_MANA_CAP:
		player_data["max_mana"] += 1
	
	# Refresh current mana to max
	player_data["current_mana"] = player_data["max_mana"]
	mana_changed.emit(player_id, player_data["current_mana"], player_data["max_mana"])
	
	# Refresh minions for new turn
	for minion in player_data["board"]:
		if is_instance_valid(minion) and minion.has_method("refresh_for_turn"):
			minion.refresh_for_turn()
	
	turn_started.emit(player_id)
	
	await get_tree().process_frame
	_execute_draw_phase(player_id)


func _execute_draw_phase(player_id: int) -> void:
	current_phase = GamePhase.DRAW
	draw_phase_started.emit(player_id)
	
	# Skip draw on very first turn for player one (standard CCG rule)
	if not (_first_turn[player_id] and player_id == PLAYER_ONE):
		for i in range(CARDS_DRAWN_PER_TURN):
			_draw_card(player_id)
	
	_first_turn[player_id] = false
	
	get_tree().create_timer(0.3).timeout.connect(
		func(): _execute_play_phase(player_id),
		CONNECT_ONE_SHOT
	)


func _execute_play_phase(player_id: int) -> void:
	current_phase = GamePhase.PLAY
	play_phase_started.emit(player_id)
	print("[GameManager] Play phase started for player %d" % player_id)


## Draw a card for a player
func _draw_card(player_id: int) -> CardData:
	var player_data: Dictionary = players[player_id]
	var deck: Array = player_data["deck"]
	var hand: Array = player_data["hand"]
	
	if deck.is_empty():
		player_data["fatigue_counter"] += 1
		var fatigue_damage: int = player_data["fatigue_counter"]
		player_data["hero_health"] -= fatigue_damage
		print("[GameManager] Player %d takes %d fatigue damage" % [player_id, fatigue_damage])
		_check_hero_death(player_id)
		return null
	
	if hand.size() >= MAX_HAND_SIZE:
		var burned_card: CardData = deck.pop_front()
		player_data["graveyard"].append(burned_card)
		print("[GameManager] Player %d burned card: %s" % [player_id, burned_card.card_name])
		return null
	
	var drawn_card: CardData = deck.pop_front()
	hand.append(drawn_card)
	
	# Track for Fated keyword
	player_data["cards_drawn_this_turn"].append(drawn_card.id)
	
	print("[GameManager] Player %d drew: %s" % [player_id, drawn_card.card_name])
	
	if _controllers_ready:
		card_drawn.emit(player_id, drawn_card)
	else:
		_deferred_draws.append({"player_id": player_id, "card_data": drawn_card})
	
	return drawn_card


## Check if a card was drawn this turn (for Fated keyword)
## Check if a card was drawn this turn (for Fated keyword)
func was_card_drawn_this_turn(player_id: int, card: CardData) -> bool:
	var drawn_ids: Array = players[player_id].get("cards_drawn_this_turn", [])
	# Check both the exact ID and the base ID (before the random suffix)
	var base_id: String = card.id.split("_")[0] if "_" in card.id else card.id
	for drawn_id in drawn_ids:
		if drawn_id == card.id or drawn_id == base_id:
			return true
		var drawn_base: String = drawn_id.split("_")[0] if "_" in drawn_id else drawn_id
		if drawn_base == base_id:
			return true
	return false


## Check if Fated bonus should trigger and emit signal
func check_fated_bonus(player_id: int, card: CardData, minion: Node = null) -> bool:
	if not card.has_keyword("Fated"):
		return false
	
	if was_card_drawn_this_turn(player_id, card):
		print("[GameManager] Fated triggered for %s!" % card.card_name)
		fated_triggered.emit(player_id, minion, card)
		return true
	
	return false


## Attempt to play a card from hand
func try_play_card(player_id: int, card: CardData, target: Variant = null) -> bool:
	if player_id != active_player:
		push_warning("Not this player's turn")
		return false
	
	if current_phase != GamePhase.PLAY:
		push_warning("Not in play phase")
		return false
	
	var player_data: Dictionary = players[player_id]
	
	if player_data["current_mana"] < card.cost:
		push_warning("Not enough mana: have %d, need %d" % [player_data["current_mana"], card.cost])
		return false
	
	match card.card_type:
		CardData.CardType.MINION:
			if player_data["board"].size() >= MAX_BOARD_SIZE:
				push_warning("Board is full")
				return false
		CardData.CardType.ACTION:
			pass
		CardData.CardType.LOCATION:
			pass
	
	# Remove from hand
	var hand_index := -1
	for i in range(player_data["hand"].size()):
		if player_data["hand"][i].id == card.id:
			hand_index = i
			break
	
	if hand_index == -1:
		push_error("Card not found in hand: %s (id: %s)" % [card.card_name, card.id])
		return false
	
	player_data["hand"].remove_at(hand_index)
	
	player_data["current_mana"] -= card.cost
	mana_changed.emit(player_id, player_data["current_mana"], player_data["max_mana"])
	
	match card.card_type:
		CardData.CardType.ACTION:
			spell_cast.emit(player_id, card, target)
			_execute_card_effect(player_id, card, target, "on_play")
			player_data["graveyard"].append(card)
		CardData.CardType.LOCATION:
			_equip_weapon(player_id, card)
		CardData.CardType.MINION:
			pass
	
	card_played.emit(player_id, card, target)
	print("[GameManager] Player %d played: %s" % [player_id, card.card_name])
	return true


func _equip_weapon(player_id: int, card: CardData) -> void:
	var player_data: Dictionary = players[player_id]
	
	if player_data["weapon"] != null:
		player_data["graveyard"].append(player_data["weapon"])
	
	player_data["weapon"] = card
	player_data["weapon_durability"] = card.health
	
	weapon_equipped.emit(player_id, card)


func _execute_card_effect(player_id: int, card: CardData, target: Variant, trigger: String) -> void:
	if card.effect_script.is_empty():
		return
	
	var effect_script = load(card.effect_script)
	if effect_script == null:
		push_error("Failed to load effect script: %s" % card.effect_script)
		return
	
	var effect_instance = effect_script.new()
	if effect_instance.has_method(trigger):
		effect_instance.call(trigger, self, player_id, card, target)
	
	if effect_instance is RefCounted:
		effect_instance = null


## Trigger battlecry for a minion
func trigger_battlecry(player_id: int, minion: Node, card: CardData, target: Variant = null) -> void:
	battlecry_triggered.emit(player_id, minion, card)
	_execute_card_effect(player_id, card, target, "on_battlecry")


## Trigger deathrattle for a minion
func trigger_deathrattle(player_id: int, card: CardData, board_position: int) -> void:
	deathrattle_triggered.emit(player_id, card, board_position)
	_execute_card_effect(player_id, card, board_position, "on_deathrattle")


## Register a minion on the board
func register_minion_on_board(player_id: int, minion_node: Node) -> void:
	players[player_id]["board"].append(minion_node)
	print("[GameManager] Registered minion on board for player %d" % player_id)
	
	# Mechanic: CUTE - gains fan when summoning
	if players[player_id]["class_id"] == "cute":
		_modify_resource(player_id, 1)


## Remove a minion from the board
func remove_minion_from_board(player_id: int, minion_node: Node) -> void:
	var board: Array = players[player_id]["board"]
	var index := board.find(minion_node)
	if index != -1:
		board.remove_at(index)


## ============================================================================
## OVERCLOCK SYSTEM (Technical Class)
## ============================================================================

## Try to activate Overclock for a minion
func try_overclock(player_id: int, minion: Node) -> bool:
	if not minion.has_overclock:
		return false
	
	var battery_cost: int = minion.overclock_cost
	var current_battery: int = players[player_id].get("class_resource", 0)
	
	# Only Technical class uses Battery
	if players[player_id]["class_id"] != "technical":
		print("[GameManager] Overclock failed - not Technical class")
		return false
	
	if current_battery < battery_cost:
		print("[GameManager] Not enough Battery for Overclock (%d/%d)" % [current_battery, battery_cost])
		return false
	
	# Spend the battery
	_modify_resource(player_id, -battery_cost)
	overclock_triggered.emit(player_id, minion, battery_cost)
	print("[GameManager] Overclock activated! Spent %d Battery" % battery_cost)
	
	if minion.has_method("play_overclock_effect"):
		minion.play_overclock_effect()
	
	return true


## ============================================================================
## RITUAL SYSTEM
## ============================================================================

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


## ============================================================================
## COMBAT SYSTEM
## ============================================================================

## Execute combat between two minions
func execute_combat(attacker: Node, defender: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	current_phase = GamePhase.COMBAT
	
	var attacker_attack: int = attacker.current_attack
	var defender_attack: int = defender.current_attack
	
	var attacker_shielded: bool = attacker.has_shielded
	var defender_shielded: bool = defender.has_shielded
	
	var damage_to_attacker: int = 0
	var damage_to_defender: int = 0
	
	# --- BULLY CHECK ---
	var bully_active := false
	if attacker.has_bully and defender.current_attack < attacker.current_attack:
		bully_active = true
		bully_triggered.emit(attacker.owner_id, attacker, defender)
		print("[GameManager] Bully triggered! %s attacking weaker target" % attacker.card_data.card_name)
		if attacker.has_method("play_bully_effect"):
			attacker.play_bully_effect()
	
	# --- APPLY DAMAGE TO ATTACKER ---
	if attacker_shielded:
		attacker.remove_shielded()
	else:
		damage_to_attacker = defender_attack
		attacker.take_damage(defender_attack)
		
		if defender.has_lethal and defender_attack > 0:
			attacker.current_health = 0
			attacker._update_visuals()
		
		if defender_attack > 0:
			_check_primal_damage_trigger()
	
	# --- APPLY DAMAGE TO DEFENDER ---
	if defender_shielded:
		defender.remove_shielded()
	else:
		damage_to_defender = attacker_attack
		defender.take_damage(attacker_attack)
		
		if attacker.has_lethal and attacker_attack > 0:
			defender.current_health = 0
			defender._update_visuals()
		
		if attacker_attack > 0:
			_check_primal_damage_trigger()
	
	# --- DRAIN (Lifesteal) ---
	if attacker.has_drain and damage_to_defender > 0:
		_heal_hero(attacker.owner_id, damage_to_defender)
		print("[GameManager] Drain: Player %d healed for %d" % [attacker.owner_id, damage_to_defender])
	
	if defender.has_drain and damage_to_attacker > 0:
		_heal_hero(defender.owner_id, damage_to_attacker)
		print("[GameManager] Drain: Player %d healed for %d" % [defender.owner_id, damage_to_attacker])
	
	# --- HIDDEN breaks when attacking ---
	if attacker.has_hidden:
		attacker.break_hidden()
		print("[GameManager] Hidden broken - minion revealed")
	
	# --- UPDATE ATTACK TRACKING ---
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
	
	# --- DRAIN when attacking hero ---
	if attacker.has_drain and damage_dealt > 0:
		_heal_hero(attacker.owner_id, damage_dealt)
		print("[GameManager] Drain: Player %d healed for %d from hero attack" % [attacker.owner_id, damage_dealt])
	
	# --- HIDDEN breaks when attacking ---
	if attacker.has_hidden:
		attacker.break_hidden()
	
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	print("[GameManager] Player %d hero took %d damage, now at %d HP" % [
		target_player_id, damage_dealt, player_data["hero_health"]
	])
	
	if damage_dealt > 0:
		# Mechanic: THE ACE - gains spirit when taking damage
		if players[target_player_id]["class_id"] == "ace":
			_modify_resource(target_player_id, 1)
	
	_check_hero_death(target_player_id)


func _check_primal_damage_trigger() -> void:
	for i in range(2):
		if players[i]["class_id"] == "brute":
			_modify_resource(i, 1)


func _heal_hero(player_id: int, amount: int) -> void:
	var player_data: Dictionary = players[player_id]
	player_data["hero_health"] = mini(
		player_data["hero_health"] + amount,
		player_data["hero_max_health"]
	)


func _check_minion_deaths() -> void:
	for player_id in range(2):
		var board: Array = players[player_id]["board"]
		var dead_minions: Array[Node] = []
		
		for minion in board:
			if is_instance_valid(minion) and minion.current_health <= 0:
				dead_minions.append(minion)
		
		for minion in dead_minions:
			await _destroy_minion(player_id, minion)


## Kill a specific minion (for Ritual, effects, etc.)
func _kill_minion(player_id: int, minion: Node, board_position: int) -> void:
	await _destroy_minion(player_id, minion)


## Destroy a minion - handles Persistent, Huddle, On-death
func _destroy_minion(player_id: int, minion: Node) -> void:
	var board_position: int = players[player_id]["board"].find(minion)
	
	var had_persistent: bool = minion.has_persistent
	var minion_card: CardData = minion.get_card_data() if minion.has_method("get_card_data") else null
	var lane_index: int = minion.lane_index
	var is_front: bool = minion.is_front_row
	
	# --- HUDDLE PROMOTION ---
	var huddled: Node = null
	if minion.has_method("get_huddled_minion"):
		huddled = minion.get_huddled_minion()
	
	if huddled and is_instance_valid(huddled):
		print("[GameManager] Promoting huddled minion!")
		if minion.has_method("promote_huddled_minion"):
			var promoted: Node = minion.promote_huddled_minion()
			if promoted:
				huddle_promoted.emit(player_id, promoted, lane_index, is_front)
	
	remove_minion_from_board(player_id, minion)
	
	# Trigger deathrattle / On-death
	if minion_card:
		if minion_card.has_keyword("Deathrattle") or minion_card.has_keyword("On-death"):
			trigger_deathrattle(player_id, minion_card, board_position)
		players[player_id]["graveyard"].append(minion_card)
	
	# Mechanic: THE OTHER - gains omen when minion dies
	if players[player_id]["class_id"] == "other":
		_modify_resource(player_id, 1)
	
	entity_died.emit(player_id, minion)
	
	# --- PERSISTENT (Reborn) ---
	if had_persistent and minion_card:
		print("[GameManager] Persistent triggered for %s" % minion_card.card_name)
		
		var respawn_card := minion_card.duplicate_for_play()
		respawn_card.tags.erase("Persistent")
		
		persistent_respawn_requested.emit(player_id, respawn_card, lane_index, is_front)
	
	if minion.has_method("play_death_animation"):
		await minion.play_death_animation()
	else:
		minion.queue_free()


## Get taunt minions in a specific row
func get_taunt_minions_in_row(player_id: int, is_front_row: bool) -> Array[Node]:
	var taunts: Array[Node] = []
	for minion in players[player_id]["board"]:
		if is_instance_valid(minion) and minion.has_taunt:
			if minion.is_front_row == is_front_row:
				taunts.append(minion)
	return taunts


func get_taunt_minions(player_id: int) -> Array[Node]:
	var taunts: Array[Node] = []
	for minion in players[player_id]["board"]:
		if is_instance_valid(minion) and minion.has_taunt:
			taunts.append(minion)
	return taunts


## End the current turn
func end_turn() -> void:
	if current_phase != GamePhase.PLAY:
		return
	
	# Mechanic: TECHNICAL - gains Battery for unused mana
	if players[active_player]["class_id"] == "technical":
		var unused = players[active_player]["current_mana"]
		if unused > 0:
			_modify_resource(active_player, unused)
	
	print("[GameManager] Ending turn for player %d" % active_player)
	current_phase = GamePhase.END_TURN
	
	for minion in players[active_player]["board"]:
		if is_instance_valid(minion):
			minion.has_attacked = false
			minion.just_played = false
	
	turn_ended.emit(active_player)
	
	var next_player := 1 - active_player
	get_tree().create_timer(0.5).timeout.connect(
		func(): _start_turn(next_player),
		CONNECT_ONE_SHOT
	)


func _check_hero_death(player_id: int) -> void:
	if players[player_id]["hero_health"] <= 0:
		var winner_id := 1 - player_id
		_end_game(winner_id)


func _end_game(winner_id: int) -> void:
	current_phase = GamePhase.GAME_OVER
	print("[GameManager] Game Over! Player %d wins!" % winner_id)
	game_ended.emit(winner_id)


func reset_game() -> void:
	current_phase = GamePhase.IDLE
	_game_initialized = false
	_initialize_player_data()


## Check if attacking this target is valid
func is_valid_attack_target(attacker_owner: int, target: Variant) -> bool:
	if target is Node:
		var target_owner: int = target.owner_id
		if target_owner == attacker_owner:
			return false
		
		# Check Taunt in same row
		var target_row: bool = target.is_front_row
		var taunts := get_taunt_minions_in_row(target_owner, target_row)
		
		if not taunts.is_empty() and target not in taunts:
			return false
		
		# Check Hidden
		if target.has_hidden:
			return false
		
		return true
	
	return true


func get_current_mana(player_id: int) -> int:
	return players[player_id]["current_mana"]


func get_max_mana(player_id: int) -> int:
	return players[player_id]["max_mana"]


func get_hero_health(player_id: int) -> int:
	return players[player_id]["hero_health"]


func get_hand(player_id: int) -> Array:
	return players[player_id]["hand"]


func get_board(player_id: int) -> Array:
	return players[player_id]["board"]


func get_deck_size(player_id: int) -> int:
	return players[player_id]["deck"].size()


func is_player_turn(player_id: int) -> bool:
	return active_player == player_id and current_phase == GamePhase.PLAY


func get_opponent_id(player_id: int) -> int:
	return 1 - player_id
