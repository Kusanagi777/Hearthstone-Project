# res://scripts/hero_power_effects.gd
# This script handles special hero power effects that need to hook into game systems
class_name HeroPowerEffects
extends RefCounted

## Singleton-style access
static var _instance: HeroPowerEffects = null

static func get_instance() -> HeroPowerEffects:
	if _instance == null:
		_instance = HeroPowerEffects.new()
	return _instance


## ============================================================================
## TOKEN SUMMONING SYSTEM
## ============================================================================

## Summon a token minion for a player
## Returns the summoned minion node or null if failed
static func summon_token(player_id: int, token_card: CardData, lane_index: int = -1, is_front: bool = true) -> Node:
	# Find the player controller
	var main_game := _get_main_game()
	if not main_game:
		push_error("[HeroPowerEffects] Could not find main game scene")
		return null
	
	var controller: Node = null
	if player_id == GameManager.PLAYER_ONE:
		controller = main_game.player_one
	else:
		controller = main_game.player_two
	
	if not controller:
		push_error("[HeroPowerEffects] Could not find player controller")
		return null
	
	# Find an empty lane if not specified
	if lane_index < 0:
		lane_index = _find_empty_lane(player_id, is_front, main_game)
		if lane_index < 0:
			# Try back row if front is full
			is_front = false
			lane_index = _find_empty_lane(player_id, is_front, main_game)
			if lane_index < 0:
				print("[HeroPowerEffects] No empty lanes for token")
				return null
	
	# Summon the minion
	if controller.has_method("_summon_minion_to_lane"):
		var minion := controller._summon_minion_to_lane(token_card, lane_index, is_front)
		if minion:
			# Apply token-specific properties
			_apply_token_properties(minion, token_card)
			print("[HeroPowerEffects] Summoned %s for player %d" % [token_card.card_name, player_id])
			return minion
	
	return null


## Apply special properties to token minions based on metadata
static func _apply_token_properties(minion: Node, token_card: CardData) -> void:
	# Check for Huddle effects
	if token_card.has_meta("huddle_effect"):
		var effect: String = token_card.get_meta("huddle_effect")
		minion.set_meta("huddle_effect", effect)
		
		match effect:
			"gain_fans":
				minion.set_meta("huddle_value", token_card.get_meta("huddle_value", 2))
			"buff_idol":
				minion.set_meta("huddle_health_bonus", token_card.get_meta("huddle_health_bonus", 1))
			"buff_front":
				minion.set_meta("huddle_attack_bonus", token_card.get_meta("huddle_attack_bonus", 1))
				minion.set_meta("huddle_health_bonus", token_card.get_meta("huddle_health_bonus", 1))


## Find an empty lane for summoning
static func _find_empty_lane(player_id: int, is_front: bool, main_game: Node) -> int:
	var lanes: Array = []
	
	if player_id == GameManager.PLAYER_ONE:
		lanes = main_game.player_front_lanes if is_front else main_game.player_back_lanes
	else:
		lanes = main_game.enemy_front_lanes if is_front else main_game.enemy_back_lanes
	
	for i in range(lanes.size()):
		var lane: Control = lanes[i]
		if lane.get_child_count() == 0:
			return i
	
	return -1


## Get the main game scene
static func _get_main_game() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var root := tree.current_scene
		if root and root.name == "MainGame":
			return root
		# Try to find it in the tree
		var main_games := tree.get_nodes_in_group("main_game")
		if main_games.size() > 0:
			return main_games[0]
	return null


## ============================================================================
## PRE-COMBAT EFFECTS
## ============================================================================

## Called before combat to apply pre-combat effects like Intimidating Shout's Bully
static func apply_pre_combat_effects(attacker: Node, defender: Node) -> void:
	if not attacker or not is_instance_valid(attacker):
		return
	
	# Check for Intimidating Shout Bully effect
	if attacker.has_meta("intimidating_shout_bully") and attacker.get_meta("intimidating_shout_bully"):
		# Check if Bully condition is met (attacking weaker target)
		if attacker.has_bully and defender.current_attack < attacker.current_attack:
			# Grant Shielded before the attack
			attacker.has_shielded = true
			attacker._update_visuals()
			print("[HeroPowerEffects] Intimidating Shout Bully: %s gained Shielded!" % attacker.card_data.card_name)


## ============================================================================
## POST-COMBAT EFFECTS
## ============================================================================

## Track minions with Beast Fury for kill rewards
static func check_beast_fury_kill(attacker: Node, defender: Node, attacker_owner: int) -> void:
	if not attacker or not is_instance_valid(attacker):
		return
	
	if attacker.has_meta("beast_fury_active") and attacker.get_meta("beast_fury_active"):
		if defender and is_instance_valid(defender) and defender.current_health <= 0:
			var fury_owner: int = attacker.get_meta("beast_fury_owner", attacker_owner)
			GameManager._modify_resource(fury_owner, 5)
			print("[HeroPowerEffects] Beast Fury kill! Player %d gained 5 Hunger" % fury_owner)
		
		# Clear the buff after combat
		attacker.remove_meta("beast_fury_active")
		attacker.remove_meta("beast_fury_owner")


## ============================================================================
## HUDDLE EFFECT PROCESSING
## ============================================================================

## Process Huddle effects when a minion is played on an occupied space
static func process_huddle_effect(huddling_minion: Node, front_minion: Node, player_id: int) -> void:
	if not huddling_minion or not is_instance_valid(huddling_minion):
		return
	
	if not huddling_minion.has_meta("huddle_effect"):
		return
	
	var effect: String = huddling_minion.get_meta("huddle_effect")
	
	match effect:
		"gain_fans":
			# Vendor: Gain X Fans when Huddling
			var fan_gain: int = huddling_minion.get_meta("huddle_value", 2)
			GameManager._modify_resource(player_id, fan_gain)
			print("[HeroPowerEffects] Huddle: %s gained %d Fans" % [huddling_minion.card_data.card_name, fan_gain])
		
		"buff_idol":
			# Bouncer: If front minion is an Idol, give it Shielded and +1 Health
			if front_minion and is_instance_valid(front_minion):
				if front_minion.card_data and front_minion.card_data.has_minion_tag(CardData.MinionTags.IDOL):
					front_minion.has_shielded = true
					var health_bonus: int = huddling_minion.get_meta("huddle_health_bonus", 1)
					front_minion.current_health += health_bonus
					front_minion.max_health += health_bonus
					front_minion._update_visuals()
					print("[HeroPowerEffects] Huddle: Bouncer buffed Idol %s" % front_minion.card_data.card_name)
		
		"buff_front":
			# Understudy effect: Give front minion +1/+1
			if front_minion and is_instance_valid(front_minion):
				var atk_bonus: int = huddling_minion.get_meta("huddle_attack_bonus", 1)
				var hp_bonus: int = huddling_minion.get_meta("huddle_health_bonus", 1)
				front_minion.current_attack += atk_bonus
				front_minion.current_health += hp_bonus
				front_minion.max_health += hp_bonus
				front_minion._update_visuals()
				print("[HeroPowerEffects] Huddle: Gave %s +%d/+%d" % [front_minion.card_data.card_name, atk_bonus, hp_bonus])


## ============================================================================
## STACKED DECK COST REDUCTION
## ============================================================================

## Check if a card has Stacked Deck cost reduction active
static func get_stacked_deck_reduction(card: CardData) -> int:
	if not card.has_meta("stacked_deck_reduction"):
		return 0
	
	var reduction_turn: int = card.get_meta("stacked_deck_turn", -1)
	if reduction_turn == GameManager.turn_number:
		return card.get_meta("stacked_deck_reduction", 0)
	
	# Clear expired reduction
	card.remove_meta("stacked_deck_reduction")
	card.remove_meta("stacked_deck_turn")
	return 0


## Apply Stacked Deck cost reduction when calculating card cost
static func apply_cost_modifiers(card: CardData) -> int:
	var base_cost: int = card.cost
	var reduction: int = get_stacked_deck_reduction(card)
	return max(0, base_cost - reduction)


## ============================================================================
## DRACONIC HERALD DRAGON SEARCH
## ============================================================================

## Find all Dragons in a player's deck
static func find_dragons_in_deck(player_id: int) -> Array[CardData]:
	var dragons: Array[CardData] = []
	var deck: Array = GameManager.players[player_id]["deck"]
	
	for card in deck:
		if card is CardData and card.has_minion_tag(CardData.MinionTags.DRAGON):
			dragons.append(card)
	
	return dragons


## ============================================================================
## RITUAL HELPERS
## ============================================================================

## Get the appropriate ritual tier based on sacrifice count
static func get_ritual_tier(power_data: Dictionary, sacrifice_count: int) -> Dictionary:
	var ritual_tiers: Array = power_data.get("ritual_tiers", [])
	var best_tier: Dictionary = {}
	
	for tier in ritual_tiers:
		var required: int = tier.get("sacrifices", 99)
		if sacrifice_count >= required:
			best_tier = tier
	
	return best_tier


## Validate if a ritual can be performed
static func can_perform_ritual(player_id: int, min_sacrifices: int) -> bool:
	var board: Array = GameManager.players[player_id]["board"]
	var valid_sacrifices: int = 0
	
	for minion in board:
		if is_instance_valid(minion):
			valid_sacrifices += 1
	
	return valid_sacrifices >= min_sacrifices


## ============================================================================
## LEGACY STATIC EFFECTS (for backwards compatibility)
## ============================================================================

## Voracious Strike effect with Hunger kicker
static func execute_voracious_strike(player_id: int, target: Variant, auto_use_kicker: bool = true) -> int:
	var hunger: int = GameManager.get_class_resource(player_id)
	var damage: int = 1
	var hunger_cost: int = 10
	
	if auto_use_kicker and hunger >= hunger_cost:
		GameManager._modify_resource(player_id, -hunger_cost)
		damage = 3
		print("[HeroPowerEffects] Voracious Strike: Spent %d Hunger for %d damage!" % [hunger_cost, damage])
	else:
		print("[HeroPowerEffects] Voracious Strike: Dealing %d damage" % damage)
	
	if target is Node and target.has_method("take_damage"):
		target.take_damage(damage)
		if target.current_health <= 0:
			GameManager._check_minion_deaths()
	elif target is int:
		GameManager.players[target]["hero_health"] -= damage
		GameManager._check_hero_death(target)
	
	return damage


## Beast Fury effect
static func execute_beast_fury(player_id: int, target_minion: Node) -> bool:
	if not target_minion or not is_instance_valid(target_minion):
		return false
	
	if not target_minion.card_data:
		return false
	
	if not target_minion.card_data.has_minion_tag(CardData.MinionTags.BEAST):
		print("[HeroPowerEffects] Target is not a Beast!")
		return false
	
	target_minion.current_attack += 2
	target_minion._update_visuals()
	
	target_minion.set_meta("beast_fury_active", true)
	target_minion.set_meta("beast_fury_owner", player_id)
	
	print("[HeroPowerEffects] Beast Fury: Gave %s +2 Attack" % target_minion.card_data.card_name)
	return true


## Intimidating Shout effect
static func execute_intimidating_shout(player_id: int, target_minion: Node) -> bool:
	if not target_minion or not is_instance_valid(target_minion):
		return false
	
	target_minion.current_attack += 1
	target_minion._update_visuals()
	
	target_minion.has_bully = true
	if target_minion.card_data and not target_minion.card_data.has_keyword("Bully"):
		target_minion.card_data.add_keyword("Bully")
	
	target_minion.set_meta("intimidating_shout_bully", true)
	
	print("[HeroPowerEffects] Intimidating Shout: Gave %s +1 Attack and Bully" % target_minion.card_data.card_name)
	return true
