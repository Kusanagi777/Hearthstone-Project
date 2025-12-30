# res://scripts/minion.gd
class_name Minion
extends Control

## Signals - using 'm' instead of 'minion' to avoid class name conflict
signal minion_clicked(m: Node)
signal minion_targeted(m: Node)
signal minion_drag_started(m: Node)
signal minion_drag_ended(m: Node, global_pos: Vector2)

## Card data
var card_data: CardData

## Owner player ID
var owner_id: int = 0

## Lane position
var lane_index: int = 0
var is_front_row: bool = true

## Current stats (base values before modifiers)
var current_attack: int = 0
var current_health: int = 0
var max_health: int = 0

## Combat flags
var has_attacked: bool = false
var just_played: bool = true
var has_moved_this_turn: bool = false
var attacks_this_turn: int = 0

## Visual state
var is_targetable: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Keyword flags - Using YOUR custom keyword names
var has_charge: bool = false       # Can attack when summoned
var has_rush: bool = false         # Can attack minions (not heroes) when summoned
var has_taunt: bool = false        # Protects other minions in same row
var has_shielded: bool = false     # Next damage instance is reduced to 0
var has_aggressive: bool = false   # Can attack twice per turn
var has_hidden: bool = false       # Cannot be targeted by opponents
var has_drain: bool = false        # Damage dealt heals your hero
var has_lethal: bool = false       # Any damage destroys the target
var has_persistent: bool = false   # Returns with 1 HP when destroyed
var has_snipe: bool = false        # Can attack from back row / target back row

## NEW KEYWORD FLAGS
var has_bully: bool = false        # Bonus effect when attacking weaker targets
var has_overclock: bool = false    # Spend Battery for bonus effect
var overclock_cost: int = 0        # Battery cost for Overclock
var has_huddle: bool = false       # Can be played in occupied space
var has_ritual: bool = false       # Sacrifice minions for bonus
var ritual_cost: int = 0           # Number of minions to sacrifice
var has_fated: bool = false        # Bonus if played same turn as drawn

## Track if drawn this turn (for Fated)
var drawn_this_turn: bool = false

## Huddle support
var huddled_minion: Node = null

## UI References
@onready var frame: Panel = $Frame
@onready var art_panel: Panel = $Frame/VBox/ArtPanel
@onready var card_art: TextureRect = $Frame/VBox/ArtPanel/CardArt
@onready var name_label: Label = $Frame/VBox/NameLabel
@onready var attack_icon: Panel = $Frame/AttackIcon
@onready var attack_label: Label = $Frame/AttackIcon/AttackLabel
@onready var health_icon: Panel = $Frame/HealthIcon
@onready var health_label: Label = $Frame/HealthIcon/HealthLabel
@onready var taunt_border: Panel = $Frame/TauntBorder
@onready var divine_shield_effect: ColorRect = $Frame/DivineShieldEffect
@onready var highlight: ColorRect = $Frame/Highlight
@onready var sleeping_icon: Label = $Frame/SleepingIcon
@onready var damage_label: Label = $Frame/DamageLabel
@onready var huddle_indicator: Panel = $Frame/HuddleIndicator

## Sizing constants
const BASE_MINION_SIZE := Vector2(80, 100)
const BASE_FONT_SIZES := {
	"name": 10,
	"stats": 14,
	"damage": 18,
	"sleeping": 24
}

const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	
	var scale_factor := get_scale_factor()
	_apply_scaling(scale_factor)
	_apply_default_styling()
	
	_update_visuals()
	
	gui_input.connect(_on_gui_input)


func get_scale_factor() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return clampf(viewport_height / REFERENCE_HEIGHT, 0.8, 2.0)


func _apply_scaling(scale_factor: float) -> void:
	custom_minimum_size = BASE_MINION_SIZE * scale_factor
	
	if name_label:
		name_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["name"] * scale_factor))
	if attack_label:
		attack_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if health_label:
		health_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if damage_label:
		damage_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["damage"] * scale_factor))
	if sleeping_icon:
		sleeping_icon.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["sleeping"] * scale_factor))


func _apply_default_styling() -> void:
	if frame and not frame.has_theme_stylebox_override("panel"):
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.2, 0.18, 0.15)
		frame_style.border_color = Color(0.4, 0.35, 0.25)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(5)
		frame.add_theme_stylebox_override("panel", frame_style)
	
	if art_panel and not art_panel.has_theme_stylebox_override("panel"):
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.35, 0.4, 0.45)
		art_style.set_corner_radius_all(3)
		art_panel.add_theme_stylebox_override("panel", art_style)
	
	if attack_icon and not attack_icon.has_theme_stylebox_override("panel"):
		var attack_style := StyleBoxFlat.new()
		attack_style.bg_color = Color(0.8, 0.6, 0.1)
		attack_style.set_corner_radius_all(10)
		attack_icon.add_theme_stylebox_override("panel", attack_style)
	
	if health_icon and not health_icon.has_theme_stylebox_override("panel"):
		var health_style := StyleBoxFlat.new()
		health_style.bg_color = Color(0.8, 0.2, 0.2)
		health_style.set_corner_radius_all(10)
		health_icon.add_theme_stylebox_override("panel", health_style)


func initialize(data: CardData, player: int) -> void:
	card_data = data
	owner_id = player
	
	current_attack = data.attack
	current_health = data.health
	max_health = data.health
	
	_parse_keywords()
	_update_visuals()


func _parse_keywords() -> void:
	if not card_data:
		return
	
	# Parse using YOUR custom keyword names
	has_charge = card_data.has_keyword("Charge")
	has_rush = card_data.has_keyword("Rush")
	has_taunt = card_data.has_keyword("Taunt")
	has_shielded = card_data.has_keyword("Shielded")
	has_aggressive = card_data.has_keyword("Aggressive")
	has_hidden = card_data.has_keyword("Hidden")
	has_drain = card_data.has_keyword("Drain")
	has_lethal = card_data.has_keyword("Lethal")
	has_persistent = card_data.has_keyword("Persistent")
	has_snipe = card_data.has_keyword("Snipe")
	has_bully = card_data.has_keyword("Bully")
	has_huddle = card_data.has_keyword("Huddle")
	has_ritual = card_data.has_keyword("Ritual")
	has_fated = card_data.has_keyword("Fated")
	has_overclock = card_data.has_keyword("Overclock")
	
	if has_charge:
		just_played = false


## =============================================================================
## STAT GETTERS (WITH MODIFIER SUPPORT)
## =============================================================================

## Get effective attack value (base + modifiers)
func get_effective_attack() -> int:
	var base := current_attack
	if ModifierManager:
		return ModifierManager.apply_minion_attack_modifiers(self, base)
	return base


## Get effective health value (base + modifiers)
func get_effective_health() -> int:
	var base := current_health
	if ModifierManager:
		return ModifierManager.apply_minion_health_modifiers(self, base)
	return base


## Get effective max health (base + modifiers)
func get_effective_max_health() -> int:
	var base := max_health
	if ModifierManager:
		return ModifierManager.apply_minion_health_modifiers(self, base)
	return base


## =============================================================================
## DAMAGE AND HEALING
## =============================================================================

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	
	# Shielded absorbs the first damage instance
	if has_shielded and amount > 0:
		has_shielded = false
		_update_visuals()
		_play_damage_effect(0)  # Shield absorbed
		
		# MODIFIER HOOK: Keyword triggered
		if ModifierManager:
			ModifierManager.trigger_keyword("Shielded", self, {"blocked": amount})
		return
	
	# Note: Damage modification is handled in GameManager.execute_combat()
	# This function receives already-modified damage
	current_health -= amount
	_update_visuals()
	_play_damage_effect(amount)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	# MODIFIER HOOK: Modify healing amount
	var modified_amount := amount
	if ModifierManager:
		modified_amount = ModifierManager.apply_healing_modifiers(amount, null, self)
	
	var old_health := current_health
	current_health = mini(current_health + modified_amount, max_health)
	var actual_heal := current_health - old_health
	
	_update_visuals()
	
	# MODIFIER HOOK: Healing applied
	if ModifierManager and actual_heal > 0:
		ModifierManager.trigger_healing_applied(actual_heal, null, self)


func buff_stats(attack_bonus: int, health_bonus: int) -> void:
	current_attack += attack_bonus
	current_health += health_bonus
	max_health += health_bonus
	_update_visuals()


func remove_shielded() -> void:
	"""Called when Shielded is consumed by damage"""
	has_shielded = false
	_update_visuals()


func break_hidden() -> void:
	"""Called when Hidden minion attacks - reveals it"""
	has_hidden = false
	_update_visuals()


func remove_persistent() -> void:
	"""Called after Persistent triggers - prevents infinite loop"""
	has_persistent = false
	if card_data:
		card_data.remove_keyword("Persistent")


func get_card_data() -> CardData:
	return card_data


## =============================================================================
## COMBAT HELPERS
## =============================================================================

func can_attack() -> bool:
	# MODIFIER HOOK: Check if modifiers prevent attacking
	if ModifierManager:
		# We'll check with a dummy target - the actual target check happens elsewhere
		if not ModifierManager.can_minion_attack(self, null):
			return false
	
	if just_played and not has_charge and not has_rush:
		return false
	
	# Already attacked check (Aggressive allows 2 attacks)
	if has_aggressive:
		if attacks_this_turn >= 2:
			return false
	else:
		if has_attacked:
			return false
	
	return true


func can_attack_target(target: Node) -> bool:
	if not can_attack():
		return false
	
	# Rush can only attack minions on the turn played
	if just_played and has_rush and not has_charge:
		if target == null or not target is Minion:
			return false
	
	# MODIFIER HOOK: Check if modifiers prevent attacking this specific target
	if ModifierManager:
		if not ModifierManager.can_minion_attack(self, target):
			return false
	
	return true


func can_attack_from_row() -> bool:
	# Can always attack from front row
	if is_front_row:
		return true
	# Can attack from back row with Snipe
	if has_snipe:
		return true
	return false


## =============================================================================
## VISUAL UPDATES
## =============================================================================

func _update_visuals() -> void:
	if card_art and card_data and card_data.texture:
		card_art.texture = card_data.texture
	
	if name_label and card_data:
		name_label.text = card_data.card_name
	
	# Get effective stats (with modifiers)
	var display_attack := get_effective_attack()
	var display_health := get_effective_health()
	
	if attack_label:
		attack_label.text = str(display_attack)
		# Color based on comparison to base
		if card_data and display_attack > card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.GREEN)
		elif card_data and display_attack < card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.RED)
		else:
			attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	if health_label:
		health_label.text = str(display_health)
		# Color based on damage taken
		if card_data and display_health > card_data.health:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif current_health < max_health:
			health_label.add_theme_color_override("font_color", Color.RED)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Taunt border visibility
	if taunt_border:
		taunt_border.visible = has_taunt
	
	# Shielded effect (golden glow)
	if divine_shield_effect:
		divine_shield_effect.visible = has_shielded
	
	# Sleeping icon for just-played minions
	if sleeping_icon:
		sleeping_icon.visible = just_played and not has_charge
	
	# Hidden visual indicator (semi-transparent)
	if has_hidden:
		modulate.a = 0.6
	else:
		modulate.a = 1.0
	
	# Huddle indicator
	if huddle_indicator:
		huddle_indicator.visible = huddled_minion != null
	
	_update_can_attack_visual()


func _update_can_attack_visual() -> void:
	if highlight:
		var can_act := can_attack_from_row() and can_attack() and GameManager.is_player_turn(owner_id)
		highlight.visible = can_act


func _play_damage_effect(amount: int) -> void:
	if damage_label:
		damage_label.text = "-%d" % amount if amount > 0 else "⛨"
		damage_label.visible = true
		damage_label.modulate.a = 1.0
		damage_label.position = Vector2(20, 30)
		
		var tween := create_tween()
		tween.tween_property(damage_label, "position:y", damage_label.position.y - 25, 0.5)
		tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): damage_label.visible = false)


## =============================================================================
## TURN MANAGEMENT
## =============================================================================

func refresh_for_turn() -> void:
	has_attacked = false
	has_moved_this_turn = false
	attacks_this_turn = 0
	drawn_this_turn = false  # Reset Fated tracking each turn
	_update_can_attack_visual()


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == owner_id:
		just_played = false
		if sleeping_icon:
			sleeping_icon.visible = false
		_update_can_attack_visual()


## =============================================================================
## INPUT HANDLING
## =============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			minion_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _is_dragging:
				_is_dragging = false
				minion_drag_ended.emit(self, get_global_mouse_position())


func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	# Visual feedback for targetable state
	if highlight:
		if targetable:
			highlight.modulate = Color(1.0, 0.3, 0.3, 0.5)  # Red tint for enemy targets
		else:
			highlight.modulate = Color(0.3, 1.0, 0.3, 0.5)  # Green for friendly


## =============================================================================
## HUDDLE SUPPORT
## =============================================================================

func set_huddled_minion(m: Node) -> void:
	huddled_minion = m
	_update_visuals()


func promote_huddled_minion() -> Node:
	"""When this minion dies, promote the huddled minion to take its place"""
	if huddled_minion and is_instance_valid(huddled_minion):
		var promoted := huddled_minion
		huddled_minion = null
		promoted.is_front_row = is_front_row
		promoted.lane_index = lane_index
		print("[Minion] Promoted huddled minion: %s" % promoted.card_data.card_name)
		return promoted
	return null


## =============================================================================
## HELPER FOR MINION IDENTIFICATION
## =============================================================================

func is_minion() -> bool:
	return true
