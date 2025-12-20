# res://scripts/minion.gd
class_name minions
extends Control

## Emitted when this minion is clicked
signal minion_clicked(minion: Node)

## Emitted when this minion is targeted by an attack
signal minion_targeted(minion: Node)

## The original card data
var card_data: CardData

## Owner player ID
var owner_id: int = 0

## Current stats (can be modified by buffs/debuffs)
var current_attack: int = 0
var current_health: int = 0
var max_health: int = 0

## Combat flags
var has_attacked: bool = false
var just_played: bool = true  # Summoning sickness

## Visual effects
var is_targetable: bool = false

## Keyword flags
var has_charge: bool = false
var has_rush: bool = false
var has_taunt: bool = false
var has_divine_shield: bool = false
var has_windfury: bool = false
var has_stealth: bool = false
var has_lifesteal: bool = false
var has_poisonous: bool = false
var has_reborn: bool = false

## Attack tracking (for Windfury)
var attacks_this_turn: int = 0

## Base minion size (designed for 1280x720)
const BASE_MINION_SIZE := Vector2(80, 100)
const REFERENCE_HEIGHT := 720.0

## Base font sizes for scaling
const BASE_FONT_SIZES := {
	"name": 9,
	"stats": 12,
	"damage": 20,
	"sleeping": 10
}

## UI References - match the scene structure
@onready var taunt_border: Panel = $TauntBorder
@onready var frame: Panel = $Frame
@onready var highlight: ColorRect = $Frame/Highlight
@onready var divine_shield_effect: ColorRect = $Frame/DivineShieldEffect
@onready var art_panel: Panel = $Frame/ArtPanel
@onready var card_art: TextureRect = $Frame/ArtPanel/CardArt
@onready var name_label: Label = $Frame/NameLabel
@onready var sleeping_icon: Label = $Frame/SleepingIcon
@onready var attack_icon: Panel = $Frame/AttackIcon
@onready var attack_label: Label = $Frame/AttackIcon/AttackLabel
@onready var health_icon: Panel = $Frame/HealthIcon
@onready var health_label: Label = $Frame/HealthIcon/HealthLabel
@onready var damage_label: Label = $Frame/DamageLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Apply responsive sizing
	_apply_responsive_size()
	
	# Apply default styling
	_apply_default_styles()
	
	if highlight:
		highlight.visible = false
	if damage_label:
		damage_label.visible = false
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to turn events
	GameManager.turn_started.connect(_on_turn_started)
	
	# Connect to viewport size changes
	get_viewport().size_changed.connect(_on_viewport_size_changed)


## Calculate scale factor based on viewport size
static func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	var height_scale := viewport_size.y / REFERENCE_HEIGHT
	return clampf(height_scale, 1.0, 3.0)


## Apply responsive sizing based on viewport
func _apply_responsive_size() -> void:
	var scale_factor := get_scale_factor()
	var scaled_size := BASE_MINION_SIZE * scale_factor
	custom_minimum_size = scaled_size
	size = scaled_size
	
	# Scale fonts
	_apply_scaled_fonts(scale_factor)


## Apply scaled font sizes
func _apply_scaled_fonts(scale_factor: float) -> void:
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


## Handle viewport resize
func _on_viewport_size_changed() -> void:
	_apply_responsive_size()


## Apply default styles to panels (can be overridden in editor)
func _apply_default_styles() -> void:
	# Taunt border style
	if taunt_border and not taunt_border.has_theme_stylebox_override("panel"):
		var taunt_style := StyleBoxFlat.new()
		taunt_style.bg_color = Color(0.6, 0.6, 0.6, 0.8)
		taunt_style.set_corner_radius_all(10)
		taunt_border.add_theme_stylebox_override("panel", taunt_style)
	
	# Main frame style
	if frame and not frame.has_theme_stylebox_override("panel"):
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.2, 0.18, 0.15)
		frame_style.border_color = Color(0.4, 0.35, 0.25)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(6)
		frame.add_theme_stylebox_override("panel", frame_style)
	
	# Art panel style
	if art_panel and not art_panel.has_theme_stylebox_override("panel"):
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.35, 0.4, 0.45)
		art_style.set_corner_radius_all(4)
		art_panel.add_theme_stylebox_override("panel", art_style)
	
	# Attack icon style
	if attack_icon and not attack_icon.has_theme_stylebox_override("panel"):
		var attack_style := StyleBoxFlat.new()
		attack_style.bg_color = Color(0.8, 0.6, 0.1)
		attack_style.set_corner_radius_all(12)
		attack_icon.add_theme_stylebox_override("panel", attack_style)
	
	# Health icon style
	if health_icon and not health_icon.has_theme_stylebox_override("panel"):
		var health_style := StyleBoxFlat.new()
		health_style.bg_color = Color(0.8, 0.2, 0.2)
		health_style.set_corner_radius_all(12)
		health_icon.add_theme_stylebox_override("panel", health_style)


## Initialize the minion with card data
func initialize(data: CardData, player_id: int) -> void:
	card_data = data
	owner_id = player_id
	
	current_attack = data.attack
	current_health = data.health
	max_health = data.health
	
	# Parse and apply keywords
	_parse_keywords()
	
	_update_visuals()


## Parse keywords from card data
func _parse_keywords() -> void:
	if not card_data:
		return
	
	has_charge = card_data.has_keyword("Charge")
	has_rush = card_data.has_keyword("Rush")
	has_taunt = card_data.has_keyword("Taunt")
	has_divine_shield = card_data.has_keyword("Divine Shield")
	has_windfury = card_data.has_keyword("Windfury")
	has_stealth = card_data.has_keyword("Stealth")
	has_lifesteal = card_data.has_keyword("Lifesteal")
	has_poisonous = card_data.has_keyword("Poisonous")
	has_reborn = card_data.has_keyword("Reborn")
	
	# Charge lets you attack immediately
	if has_charge:
		just_played = false


## Update visual display
func _update_visuals() -> void:
	if card_art and card_data and card_data.texture:
		card_art.texture = card_data.texture
	
	if name_label and card_data:
		name_label.text = card_data.card_name
	
	if attack_label:
		attack_label.text = str(current_attack)
		# Color code if different from base
		if card_data and current_attack > card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.GREEN)
		elif card_data and current_attack < card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.RED)
		else:
			attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	if health_label:
		health_label.text = str(current_health)
		# Color code health
		if current_health > max_health:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif current_health < max_health:
			health_label.add_theme_color_override("font_color", Color.RED)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Update taunt border visibility
	if taunt_border:
		taunt_border.visible = has_taunt
	
	# Update divine shield effect
	if divine_shield_effect:
		divine_shield_effect.visible = has_divine_shield
	
	# Update sleeping icon
	if sleeping_icon:
		sleeping_icon.visible = just_played and not has_charge and not has_rush
	
	_update_can_attack_visual()


## Check if this minion can attack
func can_attack() -> bool:
	if has_attacked:
		return false
	if just_played:
		# Charge allows immediate attack
		if has_charge:
			return true
		# Rush allows attacking minions (but not hero) - handled elsewhere
		if has_rush:
			return true
		return false
	if current_attack <= 0:
		return false
	return true


## Take damage
func take_damage(amount: int) -> void:
	# Divine shield blocks damage
	if has_divine_shield:
		remove_divine_shield()
		_play_damage_effect(0)  # Show blocked
		return
	
	current_health -= amount
	_update_visuals()
	_play_damage_effect(amount)


## Remove divine shield (when popped)
func remove_divine_shield() -> void:
	has_divine_shield = false
	if divine_shield_effect:
		divine_shield_effect.visible = false


## Heal this minion
func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	_update_visuals()


## Buff this minion's stats
func buff_stats(attack_bonus: int, health_bonus: int) -> void:
	current_attack += attack_bonus
	current_health += health_bonus
	max_health += health_bonus
	_update_visuals()


## Play damage number effect
func _play_damage_effect(amount: int) -> void:
	if damage_label:
		damage_label.text = "-%d" % amount if amount > 0 else "⛨"  # Shield symbol
		damage_label.visible = true
		damage_label.modulate.a = 1.0
		damage_label.position = Vector2(25, 35)  # Reset position
		
		var tween := create_tween()
		tween.tween_property(damage_label, "position:y", damage_label.position.y - 30, 0.6)
		tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.6)
		tween.tween_callback(func(): damage_label.visible = false)


## Refresh for new turn
func refresh_for_turn() -> void:
	has_attacked = false
	attacks_this_turn = 0
	_update_can_attack_visual()


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == owner_id:
		just_played = false
		if sleeping_icon:
			sleeping_icon.visible = false
		_update_can_attack_visual()


## Update visual indicator for attack availability
func _update_can_attack_visual() -> void:
	if highlight:
		var can_act := can_attack() and GameManager.is_player_turn(owner_id)
		highlight.visible = can_act
		if can_act:
			highlight.color = Color(0.2, 1.0, 0.2, 0.3)  # Green glow


## Handle GUI input
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_targetable:
				minion_targeted.emit(self)
			else:
				minion_clicked.emit(self)


func _on_mouse_entered() -> void:
	# Show hover effect
	modulate = Color(1.2, 1.2, 1.2)


func _on_mouse_exited() -> void:
	modulate = Color.WHITE


## Get the card data for graveyard
func get_card_data() -> CardData:
	return card_data


## Set whether this minion is a valid attack target
func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	if highlight:
		highlight.visible = targetable
		if targetable:
			highlight.color = Color(1, 0, 0, 0.3)  # Red for enemy targetable


## Play death animation
func play_death_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(self, "rotation", 0.3, 0.3)
	await tween.finished
	queue_free()
