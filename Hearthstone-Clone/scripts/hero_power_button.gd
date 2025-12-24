# res://scripts/hero_power_button.gd
extends Button

signal hero_power_activated(power_data: Dictionary, target: Variant)
signal hero_power_targeting_started(power_data: Dictionary)
signal hero_power_targeting_cancelled()

## The hero power data
var power_data: Dictionary = {}

## Owner player ID
var player_id: int = 0

## Whether we're currently in targeting mode
var is_targeting: bool = false

## Whether the power has been used this turn
var used_this_turn: bool = false

## Target type for this power
enum TargetType {
	NONE,           # No target needed (auto-cast)
	ANY,            # Any valid target (minion or hero)
	FRIENDLY_MINION,
	ENEMY_MINION,
	ANY_MINION,
	FRIENDLY_HERO,
	ENEMY_HERO,
	FRIENDLY_BEAST  # Special for Beast Synergy
}

var target_type: TargetType = TargetType.NONE


func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.mana_changed.connect(_on_mana_changed)


func initialize(data: Dictionary, owner: int) -> void:
	power_data = data
	player_id = owner
	
	# Set up display
	var power_name: String = data.get("name", "Power")
	var cost: int = data.get("cost", 2)
	text = "%s\n(%d)" % [power_name, cost]
	
	# Determine target type from power ID
	_determine_target_type()
	
	_update_button_state()


func _determine_target_type() -> void:
	var power_id: String = power_data.get("id", "")
	
	match power_id:
		"voracious_strike":
			target_type = TargetType.ANY
		"beast_fury":
			target_type = TargetType.FRIENDLY_BEAST
		"intimidating_shout":
			target_type = TargetType.ANY_MINION
		_:
			# Default based on description keywords
			var desc: String = power_data.get("description", "").to_lower()
			if "any target" in desc:
				target_type = TargetType.ANY
			elif "friendly minion" in desc or "friendly beast" in desc:
				target_type = TargetType.FRIENDLY_MINION
			elif "enemy" in desc:
				target_type = TargetType.ENEMY_MINION
			elif "a minion" in desc:
				target_type = TargetType.ANY_MINION
			else:
				target_type = TargetType.NONE


func _on_pressed() -> void:
	if not _can_use_power():
		return
	
	if target_type == TargetType.NONE:
		# No targeting needed, activate immediately
		_activate_power(null)
	else:
		# Start targeting mode
		is_targeting = true
		hero_power_targeting_started.emit(power_data)
		_highlight_valid_targets()


func _can_use_power() -> bool:
	if used_this_turn:
		return false
	
	if not GameManager.is_player_turn(player_id):
		return false
	
	var cost: int = power_data.get("cost", 2)
	if GameManager.get_current_mana(player_id) < cost:
		return false
	
	return true


func select_target(target: Variant) -> void:
	if not is_targeting:
		return
	
	if not _is_valid_target(target):
		print("[HeroPowerButton] Invalid target!")
		return
	
	is_targeting = false
	_clear_target_highlights()
	_activate_power(target)


func cancel_targeting() -> void:
	if is_targeting:
		is_targeting = false
		_clear_target_highlights()
		hero_power_targeting_cancelled.emit()


func _activate_power(target: Variant) -> void:
	var cost: int = power_data.get("cost", 2)
	
	# Deduct mana
	GameManager.players[player_id]["current_mana"] -= cost
	GameManager.mana_changed.emit(
		player_id,
		GameManager.players[player_id]["current_mana"],
		GameManager.players[player_id]["max_mana"]
	)
	
	used_this_turn = true
	_update_button_state()
	
	# Execute the power effect
	_execute_power_effect(target)
	
	hero_power_activated.emit(power_data, target)
	print("[HeroPowerButton] Activated %s" % power_data.get("name", "Power"))


func _execute_power_effect(target: Variant) -> void:
	var power_id: String = power_data.get("id", "")
	
	match power_id:
		"voracious_strike":
			_execute_voracious_strike(target)
		"beast_fury":
			_execute_beast_fury(target)
		"intimidating_shout":
			_execute_intimidating_shout(target)
		_:
			print("[HeroPowerButton] Unknown power: %s" % power_id)


## ============================================================================
## BRUTE HERO POWER IMPLEMENTATIONS
## ============================================================================

## Voracious Strike: Deal 1 damage. Spend 10 Hunger to deal 3 instead.
func _execute_voracious_strike(target: Variant) -> void:
	var hunger: int = GameManager.get_class_resource(player_id)
	var damage: int = 1
	var hunger_cost: int = 10
	
	# Check if player wants to use Hunger kicker
	# For now, auto-use if available
	if hunger >= hunger_cost:
		# Spend Hunger for bonus damage
		GameManager._modify_resource(player_id, -hunger_cost)
		damage = 3
		print("[HeroPowerButton] Voracious Strike: Spent %d Hunger for %d damage!" % [hunger_cost, damage])
	else:
		print("[HeroPowerButton] Voracious Strike: Dealing %d damage" % damage)
	
	# Apply damage to target
	if target is Node and target.has_method("take_damage"):
		# It's a minion
		target.take_damage(damage)
		_play_damage_effect(target, damage)
		
		# Check if minion died
		if target.current_health <= 0:
			var target_owner: int = target.owner_id
			GameManager._check_minion_deaths()
	elif target is int:
		# It's a hero (player ID)
		GameManager.players[target]["hero_health"] -= damage
		print("[HeroPowerButton] Dealt %d damage to Player %d hero" % [damage, target])
		GameManager._check_hero_death(target)


## Beast Fury: Give a friendly Beast +2 Attack. If it kills, gain 5 Hunger.
func _execute_beast_fury(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	
	# Check if it's a Beast
	if not minion.card_data or not minion.card_data.has_minion_tag(CardData.MinionTags.BEAST):
		print("[HeroPowerButton] Target is not a Beast!")
		return
	
	# Give +2 Attack this turn
	var original_attack: int = minion.current_attack
	minion.current_attack += 2
	minion._update_visuals()
	
	# Store callback for when this minion kills something
	minion.set_meta("beast_fury_active", true)
	minion.set_meta("beast_fury_owner", player_id)
	
	print("[HeroPowerButton] Beast Fury: Gave %s +2 Attack (%d -> %d)" % [
		minion.card_data.card_name, original_attack, minion.current_attack
	])
	
	# Connect to combat signal to check for kills
	if not GameManager.combat_occurred.is_connected(_on_beast_fury_combat):
		GameManager.combat_occurred.connect(_on_beast_fury_combat)
	
	# Visual effect
	_play_buff_effect(minion)


func _on_beast_fury_combat(attacker_data: Dictionary, defender_data: Dictionary) -> void:
	var attacker: Node = attacker_data.get("node")
	var defender: Node = defender_data.get("node")
	
	if not attacker or not is_instance_valid(attacker):
		return
	
	# Check if attacker has Beast Fury buff
	if attacker.has_meta("beast_fury_active") and attacker.get_meta("beast_fury_active"):
		# Check if defender died
		if defender and is_instance_valid(defender) and defender.current_health <= 0:
			var fury_owner: int = attacker.get_meta("beast_fury_owner", 0)
			GameManager._modify_resource(fury_owner, 5)
			print("[HeroPowerButton] Beast Fury kill! Gained 5 Hunger")
		
		# Remove the buff tracking (one-time use per activation)
		attacker.remove_meta("beast_fury_active")
		attacker.remove_meta("beast_fury_owner")


## Intimidating Shout: Give a minion +1 Attack and Bully with Shielded bonus
func _execute_intimidating_shout(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	
	# Give +1 Attack
	minion.current_attack += 1
	minion._update_visuals()
	
	# Add Bully keyword
	minion.has_bully = true
	if minion.card_data and not minion.card_data.has_keyword("Bully"):
		minion.card_data.add_keyword("Bully")
	
	# Store special Bully effect: Gain Shielded before attacking
	minion.set_meta("intimidating_shout_bully", true)
	
	print("[HeroPowerButton] Intimidating Shout: Gave %s +1 Attack and Bully" % minion.card_data.card_name)
	
	# Connect to track when this minion attacks
	if not GameManager.combat_occurred.is_connected(_on_intimidating_shout_attack):
		GameManager.combat_occurred.connect(_on_intimidating_shout_attack, CONNECT_ONE_SHOT)
	
	_play_buff_effect(minion)


func _on_intimidating_shout_attack(attacker_data: Dictionary, _defender_data: Dictionary) -> void:
	# This is called AFTER combat, but we need to apply Shielded BEFORE
	# This requires hooking into combat earlier - for now, this is a placeholder
	# The actual implementation would need to modify execute_combat in game_manager
	pass


## ============================================================================
## TARGETING HELPERS
## ============================================================================

func _is_valid_target(target: Variant) -> bool:
	match target_type:
		TargetType.NONE:
			return true
		TargetType.ANY:
			return true  # Minion or hero
		TargetType.FRIENDLY_MINION:
			if target is Node:
				return target.owner_id == player_id
			return false
		TargetType.ENEMY_MINION:
			if target is Node:
				return target.owner_id != player_id
			return false
		TargetType.ANY_MINION:
			return target is Node
		TargetType.FRIENDLY_BEAST:
			if target is Node and target.owner_id == player_id:
				if target.card_data:
					return target.card_data.has_minion_tag(CardData.MinionTags.BEAST)
			return false
		_:
			return true


func _highlight_valid_targets() -> void:
	# This would communicate with player_controller to highlight targets
	# For now, just print
	print("[HeroPowerButton] Highlighting valid targets for %s" % power_data.get("name", "Power"))


func _clear_target_highlights() -> void:
	print("[HeroPowerButton] Clearing target highlights")


## ============================================================================
## VISUAL EFFECTS
## ============================================================================

func _play_damage_effect(target: Node, amount: int) -> void:
	if target.has_method("_play_damage_effect"):
		target._play_damage_effect(amount)


func _play_buff_effect(target: Node) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(0.5, 1.0, 0.5), 0.15)
	tween.tween_property(target, "modulate", Color.WHITE, 0.15)


## ============================================================================
## STATE MANAGEMENT
## ============================================================================

func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == player_id:
		used_this_turn = false
		_update_button_state()


func _on_mana_changed(changed_player_id: int, _current: int, _maximum: int) -> void:
	if changed_player_id == player_id:
		_update_button_state()


func _update_button_state() -> void:
	var can_use := _can_use_power()
	disabled = not can_use
	
	# Update visual style
	if used_this_turn:
		modulate = Color(0.5, 0.5, 0.5)
	elif can_use:
		modulate = Color.WHITE
	else:
		modulate = Color(0.7, 0.7, 0.7)
