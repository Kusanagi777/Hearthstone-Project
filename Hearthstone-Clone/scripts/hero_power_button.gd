# res://scripts/hero_power_button.gd
extends Button

signal hero_power_activated(power_data: Dictionary, target: Variant)
signal hero_power_targeting_started(power_data: Dictionary)
signal hero_power_targeting_cancelled()
signal ritual_selection_requested(power_data: Dictionary, max_sacrifices: int)
signal card_selection_requested(power_data: Dictionary, cards: Array, selection_type: String)

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
	FRIENDLY_BEAST,  # Special for Beast Synergy
	HAND_MINION,     # Target a minion in hand
	RITUAL           # Special ritual targeting (select sacrifices)
}

var target_type: TargetType = TargetType.NONE


func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.resource_changed.connect(_on_resource_changed)


func initialize(data: Dictionary, owner: int) -> void:
	power_data = data
	player_id = owner
	
	# Set up display
	var power_name: String = data.get("name", "Power")
	var cost: int = data.get("cost", 2)
	var cost_type: String = data.get("cost_type", "mana")
	var cost_icon: String = _get_cost_icon(cost_type)
	text = "%s\n%s%d" % [power_name, cost_icon, cost]
	
	# Determine target type from power data
	_determine_target_type()
	
	_update_button_state()


func _get_cost_icon(cost_type: String) -> String:
	match cost_type:
		"mana": return "💧"
		"battery": return "⚡"
		"spirit": return "✨"
		"hunger": return "🔥"
		_: return "💧"


func _determine_target_type() -> void:
	var power_id: String = power_data.get("id", "")
	var target_str: String = power_data.get("target_type", "none")
	
	match target_str:
		"any":
			target_type = TargetType.ANY
		"friendly_minion":
			target_type = TargetType.FRIENDLY_MINION
		"enemy_minion":
			target_type = TargetType.ENEMY_MINION
		"any_minion":
			target_type = TargetType.ANY_MINION
		"friendly_beast":
			target_type = TargetType.FRIENDLY_BEAST
		"hand_minion":
			target_type = TargetType.HAND_MINION
		"ritual":
			target_type = TargetType.RITUAL
		"none", _:
			target_type = TargetType.NONE


func _on_pressed() -> void:
	if not _can_use_power():
		return
	
	match target_type:
		TargetType.NONE:
			_activate_power(null)
		TargetType.RITUAL:
			_start_ritual_selection()
		TargetType.HAND_MINION:
			_start_hand_selection()
		_:
			is_targeting = true
			hero_power_targeting_started.emit(power_data)
			_highlight_valid_targets()


func _can_use_power() -> bool:
	if used_this_turn:
		return false
	
	if not GameManager.is_player_turn(player_id):
		return false
	
	var cost: int = power_data.get("cost", 2)
	var cost_type: String = power_data.get("cost_type", "mana")
	
	match cost_type:
		"mana":
			if GameManager.get_current_mana(player_id) < cost:
				return false
		"battery":
			if GameManager.get_class_resource(player_id) < cost:
				return false
		"spirit":
			if GameManager.get_class_resource(player_id) < cost:
				return false
		"hunger":
			if GameManager.get_class_resource(player_id) < cost:
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
	var cost_type: String = power_data.get("cost_type", "mana")
	
	# Deduct cost based on type
	match cost_type:
		"mana":
			GameManager.players[player_id]["current_mana"] -= cost
			GameManager.mana_changed.emit(
				player_id,
				GameManager.players[player_id]["current_mana"],
				GameManager.players[player_id]["max_mana"]
			)
		"battery", "spirit", "hunger":
			GameManager._modify_resource(player_id, -cost)
	
	used_this_turn = true
	_update_button_state()
	
	# Execute the power effect
	_execute_power_effect(target)
	
	hero_power_activated.emit(power_data, target)
	print("[HeroPowerButton] Activated %s" % power_data.get("name", "Power"))


func _execute_power_effect(target: Variant) -> void:
	var power_id: String = power_data.get("id", "")
	
	match power_id:
		# === BRUTE POWERS ===
		"voracious_strike":
			_execute_voracious_strike(target)
		"beast_fury":
			_execute_beast_fury(target)
		"intimidating_shout":
			_execute_intimidating_shout(target)
		
		# === TECHNICAL POWERS ===
		"capacitor_discharge":
			_execute_capacitor_discharge(target)
		"drone_assembly":
			_execute_drone_assembly()
		"safety_override":
			_execute_safety_override()
		
		# === CUTE POWERS ===
		"merch_table":
			_execute_merch_table()
		"security_detail":
			_execute_security_detail()
		"understudy":
			_execute_understudy(target)
		
		# === OTHER POWERS ===
		"grim_fate":
			_execute_grim_fate(target)
		"grave_touch":
			_execute_grave_touch(target)
		"dark_ritual":
			_execute_dark_ritual(target)
		
		# === ACE POWERS ===
		"calculated_risk":
			_execute_calculated_risk(target)
		"draconic_herald":
			_execute_draconic_herald()
		"stacked_deck":
			_execute_stacked_deck()
		
		# === DEFAULT POWERS ===
		"generic_heal":
			_execute_generic_heal(target)
		"tap":
			_execute_life_tap()
		
		_:
			print("[HeroPowerButton] Unknown power: %s" % power_id)


## ============================================================================
## BRUTE HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_voracious_strike(target: Variant) -> void:
	var hunger: int = GameManager.get_class_resource(player_id)
	var damage: int = 1
	var hunger_cost: int = 10
	
	if hunger >= hunger_cost:
		GameManager._modify_resource(player_id, -hunger_cost)
		damage = 3
		print("[HeroPowerButton] Voracious Strike: Spent %d Hunger for %d damage!" % [hunger_cost, damage])
	else:
		print("[HeroPowerButton] Voracious Strike: Dealing %d damage" % damage)
	
	_apply_damage_to_target(target, damage)


func _execute_beast_fury(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	
	if not minion.card_data or not minion.card_data.has_minion_tag(CardData.MinionTags.BEAST):
		print("[HeroPowerButton] Target is not a Beast!")
		return
	
	minion.current_attack += 2
	minion._update_visuals()
	
	minion.set_meta("beast_fury_active", true)
	minion.set_meta("beast_fury_owner", player_id)
	
	_play_buff_effect(minion)
	print("[HeroPowerButton] Beast Fury: Gave %s +2 Attack" % minion.card_data.card_name)


func _execute_intimidating_shout(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	minion.current_attack += 1
	minion.has_bully = true
	minion._update_visuals()
	
	minion.set_meta("intimidating_shout_bully", true)
	
	_play_buff_effect(minion)
	print("[HeroPowerButton] Intimidating Shout: Gave %s +1 Attack and Bully" % minion.card_data.card_name)


## ============================================================================
## TECHNICAL HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_capacitor_discharge(target: Variant) -> void:
	# Deal 1 damage
	_apply_damage_to_target(target, 1)
	
	# Gain 1 Battery
	GameManager._modify_resource(player_id, 1)
	print("[HeroPowerButton] Capacitor Discharge: Dealt 1 damage, gained 1 Battery")


func _execute_drone_assembly() -> void:
	# Summon a 0/2 Barrier Bot with Taunt
	var token_data := _create_token_card("Barrier Bot", 0, 2, ["Taunt"], ["Mech"])
	HeroPowerEffects.summon_token(player_id, token_data)
	print("[HeroPowerButton] Drone Assembly: Summoned Barrier Bot")


func _execute_safety_override() -> void:
	# Look at top 2 cards, draw one, put other on bottom
	var deck: Array = GameManager.players[player_id]["deck"]
	
	if deck.size() < 2:
		# Just draw normally if less than 2 cards
		if deck.size() >= 1:
			GameManager._draw_card(player_id)
		return
	
	# Get top 2 cards
	var top_cards: Array = [deck[0], deck[1]]
	
	# For now, automatically pick the first card (TODO: implement choice UI)
	# Remove chosen card and draw it
	deck.remove_at(0)
	var chosen_card: CardData = top_cards[0]
	GameManager.players[player_id]["hand"].append(chosen_card)
	GameManager.card_drawn.emit(player_id, chosen_card)
	
	# Put the other on bottom (it's now at index 0 after removal)
	var bottom_card: CardData = deck[0]
	deck.remove_at(0)
	deck.append(bottom_card)
	
	print("[HeroPowerButton] Safety Override: Drew %s, put %s on bottom" % [chosen_card.card_name, bottom_card.card_name])


## ============================================================================
## CUTE HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_merch_table() -> void:
	# Summon 0/2 Vendor with Huddle: "Gain 2 Fans"
	var token_data := _create_token_card("Vendor", 0, 2, ["Huddle"], ["Idol"])
	token_data.set_meta("huddle_effect", "gain_fans")
	token_data.set_meta("huddle_value", 2)
	HeroPowerEffects.summon_token(player_id, token_data)
	print("[HeroPowerButton] Merch Table: Summoned Vendor")


func _execute_security_detail() -> void:
	# Summon 1/1 Bouncer with Huddle: buff Idol
	var token_data := _create_token_card("Bouncer", 1, 1, ["Huddle"], [])
	token_data.set_meta("huddle_effect", "buff_idol")
	token_data.set_meta("huddle_health_bonus", 1)
	HeroPowerEffects.summon_token(player_id, token_data)
	print("[HeroPowerButton] Security Detail: Summoned Bouncer")


func _execute_understudy(target: Variant) -> void:
	# Target is a card in hand - give it Huddle
	if target is CardData:
		if not target.has_keyword("Huddle"):
			target.tags.append("Huddle")
		target.set_meta("huddle_effect", "buff_front")
		target.set_meta("huddle_attack_bonus", 1)
		target.set_meta("huddle_health_bonus", 1)
		print("[HeroPowerButton] Understudy: Gave %s Huddle" % target.card_name)


## ============================================================================
## OTHER HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_grim_fate(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	
	# Destroy the minion
	minion.current_health = 0
	GameManager._check_minion_deaths()
	
	# Draw a card
	GameManager._draw_card(player_id)
	print("[HeroPowerButton] Grim Fate: Destroyed minion, drew a card")


func _execute_grave_touch(target: Variant) -> void:
	if not target is Node:
		return
	
	var minion: Node = target
	var killed: bool = false
	
	# Deal 1 damage
	minion.take_damage(1)
	_play_damage_effect(minion, 1)
	
	# Check if it died
	if minion.current_health <= 0:
		killed = true
		GameManager._check_minion_deaths()
		
		# Summon 1/1 Skeleton
		var token_data := _create_token_card("Skeleton", 1, 1, [], ["Undead"])
		HeroPowerEffects.summon_token(player_id, token_data)
		print("[HeroPowerButton] Grave Touch: Killed minion, summoned Skeleton")
	else:
		print("[HeroPowerButton] Grave Touch: Dealt 1 damage")


func _execute_dark_ritual(target: Variant) -> void:
	# Target should be an array of sacrificed minions
	if not target is Array:
		print("[HeroPowerButton] Dark Ritual: No sacrifices provided")
		return
	
	var sacrifices: Array = target
	var sacrifice_count: int = sacrifices.size()
	
	# Kill all sacrificed minions
	for minion in sacrifices:
		if minion is Node and is_instance_valid(minion):
			minion.current_health = 0
	GameManager._check_minion_deaths()
	
	# Determine which tier to summon based on sacrifice count
	var ritual_tiers: Array = power_data.get("ritual_tiers", [])
	var tier_to_use: Dictionary = {}
	
	for tier in ritual_tiers:
		var required: int = tier.get("sacrifices", 99)
		if sacrifice_count >= required:
			tier_to_use = tier
	
	if tier_to_use.is_empty():
		print("[HeroPowerButton] Dark Ritual: Not enough sacrifices")
		return
	
	# Summon the appropriate creature
	var summon_name: String = tier_to_use.get("summon_name", "Horror")
	var summon_attack: int = tier_to_use.get("summon_attack", 2)
	var summon_health: int = tier_to_use.get("summon_health", 2)
	var summon_keywords: Array = tier_to_use.get("summon_keywords", [])
	var summon_tags: Array = tier_to_use.get("summon_tags", ["Undead"])
	
	var token_data := _create_token_card(summon_name, summon_attack, summon_health, summon_keywords, summon_tags)
	HeroPowerEffects.summon_token(player_id, token_data)
	
	print("[HeroPowerButton] Dark Ritual: Sacrificed %d, summoned %s" % [sacrifice_count, summon_name])


## ============================================================================
## ACE HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_calculated_risk(target: Variant) -> void:
	# Deal 1 damage to self
	GameManager.players[player_id]["hero_health"] -= 1
	print("[HeroPowerButton] Calculated Risk: Dealt 1 damage to self")
	
	# Deal 2 damage to target minion
	if target is Node:
		target.take_damage(2)
		_play_damage_effect(target, 2)
		
		if target.current_health <= 0:
			GameManager._check_minion_deaths()
		
		print("[HeroPowerButton] Calculated Risk: Dealt 2 damage to %s" % target.card_data.card_name)


func _execute_draconic_herald() -> void:
	var deck: Array = GameManager.players[player_id]["deck"]
	var dragon_found: bool = false
	var dragon_index: int = -1
	
	# Search deck for a Dragon
	for i in range(deck.size()):
		var card: CardData = deck[i]
		if card.has_minion_tag(CardData.MinionTags.DRAGON):
			dragon_index = i
			dragon_found = true
			break
	
	if dragon_found:
		# Remove dragon from deck position and draw it
		var dragon_card: CardData = deck[dragon_index]
		deck.remove_at(dragon_index)
		
		# Reduce cost by 1
		dragon_card.cost = max(0, dragon_card.cost - 1)
		
		GameManager.players[player_id]["hand"].append(dragon_card)
		GameManager.card_drawn.emit(player_id, dragon_card)
		
		print("[HeroPowerButton] Draconic Herald: Drew %s (cost reduced)" % dragon_card.card_name)
	else:
		# Fallback: draw a normal card without reduction
		GameManager._draw_card(player_id)
		print("[HeroPowerButton] Draconic Herald: No Dragons, drew normal card")


func _execute_stacked_deck() -> void:
	var deck: Array = GameManager.players[player_id]["deck"]
	
	if deck.is_empty():
		print("[HeroPowerButton] Stacked Deck: Deck is empty")
		return
	
	# TODO: Implement discover UI - for now, pick a random card
	var random_index: int = randi() % deck.size()
	var chosen_card: CardData = deck[random_index]
	
	# Remove from current position and put on top
	deck.remove_at(random_index)
	deck.insert(0, chosen_card)
	
	# Mark for cost reduction next turn
	chosen_card.set_meta("stacked_deck_reduction", 2)
	chosen_card.set_meta("stacked_deck_turn", GameManager.turn_number + 1)
	
	print("[HeroPowerButton] Stacked Deck: Put %s on top (will cost 2 less)" % chosen_card.card_name)


## ============================================================================
## DEFAULT HERO POWER IMPLEMENTATIONS
## ============================================================================

func _execute_generic_heal(target: Variant) -> void:
	var heal_amount: int = 2
	
	if target is Node and target.has_method("heal"):
		target.heal(heal_amount)
		_play_heal_effect(target)
	elif target is int:
		# Healing a hero
		var max_hp: int = GameManager.players[target]["hero_max_health"]
		GameManager.players[target]["hero_health"] = min(
			GameManager.players[target]["hero_health"] + heal_amount,
			max_hp
		)
	
	print("[HeroPowerButton] Minor Heal: Restored %d health" % heal_amount)


func _execute_life_tap() -> void:
	# Take 2 damage
	GameManager.players[player_id]["hero_health"] -= 2
	
	# Draw a card
	GameManager._draw_card(player_id)
	
	print("[HeroPowerButton] Life Tap: Took 2 damage, drew a card")


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _create_token_card(token_name: String, atk: int, hp: int, keywords: Array, tags: Array) -> CardData:
	var token := CardData.new()
	token.id = "token_%s_%d" % [token_name.to_lower().replace(" ", "_"), randi()]
	token.card_name = token_name
	token.cost = 0
	token.attack = atk
	token.health = hp
	token.card_type = CardData.CardType.MINION
	token.rarity = CardData.Rarity.COMMON
	token.tags = keywords.duplicate()
	token.tags.append("Token")
	
	# Set minion tags as bitflags
	for tag in tags:
		match tag:
			"Mech":
				token.minion_tags |= CardData.MinionTags.MECH
			"Undead":
				token.minion_tags |= CardData.MinionTags.UNDEAD
			"Beast":
				token.minion_tags |= CardData.MinionTags.BEAST
			"Idol":
				token.minion_tags |= CardData.MinionTags.IDOL
			"Dragon":
				token.minion_tags |= CardData.MinionTags.DRAGON
	
	return token


func _apply_damage_to_target(target: Variant, damage: int) -> void:
	if target is Node and target.has_method("take_damage"):
		target.take_damage(damage)
		_play_damage_effect(target, damage)
		if target.current_health <= 0:
			GameManager._check_minion_deaths()
	elif target is int:
		GameManager.players[target]["hero_health"] -= damage
		GameManager._check_hero_death(target)


func _start_ritual_selection() -> void:
	# Request UI to let player select minions to sacrifice
	var max_sacrifices: int = 3  # Dark Ritual can accept up to 3
	ritual_selection_requested.emit(power_data, max_sacrifices)


func _start_hand_selection() -> void:
	# Get minion cards in hand
	var hand: Array = GameManager.players[player_id]["hand"]
	var minion_cards: Array = []
	
	for card in hand:
		if card is CardData and card.card_type == CardData.CardType.MINION:
			minion_cards.append(card)
	
	if minion_cards.is_empty():
		print("[HeroPowerButton] No minions in hand to target")
		return
	
	card_selection_requested.emit(power_data, minion_cards, "hand_minion")


## ============================================================================
## TARGETING HELPERS
## ============================================================================

func _is_valid_target(target: Variant) -> bool:
	match target_type:
		TargetType.NONE:
			return true
		TargetType.ANY:
			return true
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
	print("[HeroPowerButton] Highlighting valid targets for %s" % power_data.get("name", "Power"))


func _clear_target_highlights() -> void:
	print("[HeroPowerButton] Clearing target highlights")


## ============================================================================
## VISUAL EFFECTS
## ============================================================================

func _play_damage_effect(target: Node, amount: int) -> void:
	if target.has_method("_play_damage_effect"):
		target._play_damage_effect(amount)
	else:
		var tween := create_tween()
		tween.tween_property(target, "modulate", Color(1.0, 0.3, 0.3), 0.1)
		tween.tween_property(target, "modulate", Color.WHITE, 0.1)


func _play_buff_effect(target: Node) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(0.5, 1.0, 0.5), 0.15)
	tween.tween_property(target, "modulate", Color.WHITE, 0.15)


func _play_heal_effect(target: Node) -> void:
	var tween := create_tween()
	tween.tween_property(target, "modulate", Color(0.5, 1.0, 0.8), 0.15)
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


func _on_resource_changed(changed_player_id: int, _current: int, _maximum: int) -> void:
	if changed_player_id == player_id:
		_update_button_state()


func _update_button_state() -> void:
	var can_use := _can_use_power()
	disabled = not can_use
	
	if used_this_turn:
		modulate = Color(0.5, 0.5, 0.5)
	elif can_use:
		modulate = Color.WHITE
	else:
		modulate = Color(0.7, 0.7, 0.7)
