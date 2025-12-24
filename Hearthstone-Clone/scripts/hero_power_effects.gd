# res://scripts/hero_power_effects.gd
# This script handles special hero power effects that need to hook into game systems
class_name HeroPowerEffects
extends RefCounted

## Singleton-style access (call these from anywhere)
static var _instance: HeroPowerEffects = null

static func get_instance() -> HeroPowerEffects:
	if _instance == null:
		_instance = HeroPowerEffects.new()
	return _instance


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


## Voracious Strike effect with Hunger kicker
static func execute_voracious_strike(player_id: int, target: Variant, auto_use_kicker: bool = true) -> int:
	var hunger: int = GameManager.get_class_resource(player_id)
	var damage: int = 1
	var hunger_cost: int = 10
	
	# Check if player wants to use Hunger kicker
	if auto_use_kicker and hunger >= hunger_cost:
		GameManager._modify_resource(player_id, -hunger_cost)
		damage = 3
		print("[HeroPowerEffects] Voracious Strike: Spent %d Hunger for %d damage!" % [hunger_cost, damage])
	else:
		print("[HeroPowerEffects] Voracious Strike: Dealing %d damage" % damage)
	
	# Apply damage to target
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
	
	# Check if it's a Beast
	if not target_minion.card_data:
		return false
	
	if not target_minion.card_data.has_minion_tag(CardData.MinionTags.BEAST):
		print("[HeroPowerEffects] Target is not a Beast!")
		return false
	
	# Give +2 Attack
	target_minion.current_attack += 2
	target_minion._update_visuals()
	
	# Mark for kill tracking
	target_minion.set_meta("beast_fury_active", true)
	target_minion.set_meta("beast_fury_owner", player_id)
	
	print("[HeroPowerEffects] Beast Fury: Gave %s +2 Attack" % target_minion.card_data.card_name)
	return true


## Intimidating Shout effect
static func execute_intimidating_shout(player_id: int, target_minion: Node) -> bool:
	if not target_minion or not is_instance_valid(target_minion):
		return false
	
	# Give +1 Attack
	target_minion.current_attack += 1
	target_minion._update_visuals()
	
	# Add Bully keyword
	target_minion.has_bully = true
	if target_minion.card_data and not target_minion.card_data.has_keyword("Bully"):
		target_minion.card_data.add_keyword("Bully")
	
	# Mark for special Bully effect
	target_minion.set_meta("intimidating_shout_bully", true)
	
	print("[HeroPowerEffects] Intimidating Shout: Gave %s +1 Attack and Bully" % target_minion.card_data.card_name)
	return true
