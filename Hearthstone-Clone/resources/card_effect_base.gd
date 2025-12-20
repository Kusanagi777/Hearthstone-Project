# res://scripts/effects/card_effect_base.gd
class_name card_effect_base
extends RefCounted

## Reference to game manager for accessing game state
var game_manager: Node

## The player who owns/played this card
var owner_id: int

## The card data
var card_data: CardData


## Called when the card is played (for all card types)
func on_play(gm: Node, player_id: int, data: CardData, target: Variant) -> void:
	game_manager = gm
	owner_id = player_id
	card_data = data
	_execute_play_effect(target)


## Called when a minion's battlecry triggers
func on_battlecry(gm: Node, player_id: int, data: CardData, target: Variant) -> void:
	game_manager = gm
	owner_id = player_id
	card_data = data
	_execute_battlecry(target)


## Called when a minion with deathrattle dies
func on_deathrattle(gm: Node, player_id: int, data: CardData, board_position: int) -> void:
	game_manager = gm
	owner_id = player_id
	card_data = data
	_execute_deathrattle(board_position)


## Override in subclasses
func _execute_play_effect(_target: Variant) -> void:
	pass


## Override in subclasses
func _execute_battlecry(_target: Variant) -> void:
	pass


## Override in subclasses
func _execute_deathrattle(_board_position: int) -> void:
	pass


# =============================================================================
# HELPER METHODS FOR EFFECT IMPLEMENTATION
# =============================================================================

## Deal damage to a target
func deal_damage(target: Variant, amount: int) -> void:
	if target is Node and target.has_method("take_damage"):
		target.take_damage(amount)
		
		# Check for lifesteal on source minion
		# Note: Would need reference to source minion for this
		
	elif target is int:  # Player ID for hero
		game_manager.players[target]["hero_health"] -= amount


## Heal a target
func heal_target(target: Variant, amount: int) -> void:
	if target is Node and target.has_method("heal"):
		target.heal(amount)
	elif target is int:
		var player_data: Dictionary = game_manager.players[target]
		player_data["hero_health"] = mini(
			player_data["hero_health"] + amount,
			player_data["hero_max_health"]
		)

## Buff a minion
func buff_minion(minion: Node, attack_bonus: int, health_bonus: int) -> void:
	if minion.has_method("buff_stats"):
		minion.buff_stats(attack_bonus, health_bonus)

## Draw cards
func draw_cards(player_id: int, count: int) -> void:
	for i in range(count):
		game_manager._draw_card(player_id)

## Get all minions on a player's board
func get_board(player_id: int) -> Array:
	return game_manager.players[player_id]["board"]

## Get all minions (both boards)
func get_all_minions() -> Array:
	return get_board(0) + get_board(1)

## Get enemy player ID
func get_enemy_id() -> int:
	return 1 - owner_id

## Summon a minion
func summon_minion(player_id: int, card_to_summon: CardData) -> void:
	# This would need access to the player controller
	# For now, emit a signal that can be handled
	print("[Effect] Would summon: %s for player %d" % [card_to_summon.card_name, player_id])
