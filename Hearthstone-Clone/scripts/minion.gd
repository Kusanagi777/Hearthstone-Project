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

## Current stats
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
var has_snipe: bool = false  # Can attack from back row

## Base size constants
const BASE_MINION_SIZE := Vector2(70, 85)
const REFERENCE_HEIGHT := 720.0

const BASE_FONT_SIZES := {
	"name": 8,
	"stats": 11,
	"damage": 18,
	"sleeping": 9,
	"row_indicator": 8
}

## UI References
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
	
	_apply_responsive_size()
	_apply_default_styles()
	
	if highlight:
		highlight.visible = false
	if damage_label:
		damage_label.visible = false
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	GameManager.turn_started.connect(_on_turn_started)
	get_viewport().size_changed.connect(_on_viewport_size_changed)


static func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _apply_responsive_size() -> void:
	var scale_factor := get_scale_factor()
	var scaled_size := BASE_MINION_SIZE * scale_factor
	custom_minimum_size = scaled_size
	size = scaled_size
	_apply_scaled_fonts(scale_factor)


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


func _on_viewport_size_changed() -> void:
	_apply_responsive_size()


func _apply_default_styles() -> void:
	if taunt_border and not taunt_border.has_theme_stylebox_override("panel"):
		var taunt_style := StyleBoxFlat.new()
		taunt_style.bg_color = Color(0.6, 0.6, 0.6, 0.8)
		taunt_style.set_corner_radius_all(8)
		taunt_border.add_theme_stylebox_override("panel", taunt_style)
	
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
	
	has_charge = card_data.has_keyword("Charge")
	has_rush = card_data.has_keyword("Rush")
	has_taunt = card_data.has_keyword("Taunt")
	has_divine_shield = card_data.has_keyword("Divine Shield")
	has_windfury = card_data.has_keyword("Windfury")
	has_stealth = card_data.has_keyword("Stealth")
	has_lifesteal = card_data.has_keyword("Lifesteal")
	has_poisonous = card_data.has_keyword("Poisonous")
	has_reborn = card_data.has_keyword("Reborn")
	has_snipe = card_data.has_keyword("Snipe")
	
	if has_charge:
		just_played = false


func _update_visuals() -> void:
	if card_art and card_data and card_data.texture:
		card_art.texture = card_data.texture
	
	if name_label and card_data:
		name_label.text = card_data.card_name
	
	if attack_label:
		attack_label.text = str(current_attack)
		if card_data and current_attack > card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.GREEN)
		elif card_data and current_attack < card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.RED)
		else:
			attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	if health_label:
		health_label.text = str(current_health)
		if card_data and current_health > card_data.health:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif current_health < max_health:
			health_label.add_theme_color_override("font_color", Color.RED)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Taunt border visibility
	if taunt_border:
		taunt_border.visible = has_taunt
	
	# Divine shield effect
	if divine_shield_effect:
		divine_shield_effect.visible = has_divine_shield
	
	# Sleeping icon for just-played minions
	if sleeping_icon:
		sleeping_icon.visible = just_played and not has_charge


func can_attack() -> bool:
	if just_played and not has_charge and not has_rush:
		return false
	if has_attacked and not has_windfury:
		return false
	if has_windfury and attacks_this_turn >= 2:
		return false
	return true


func can_attack_from_row() -> bool:
	# Back row minions can only attack if they have Snipe
	if not is_front_row and not has_snipe:
		return false
	return can_attack()


func take_damage(amount: int) -> void:
	if has_divine_shield and amount > 0:
		has_divine_shield = false
		_update_visuals()
		_play_damage_effect(0)  # Shield absorbed
		return
	
	current_health -= amount
	_update_visuals()
	_play_damage_effect(amount)


func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	_update_visuals()


func buff_stats(attack_bonus: int, health_bonus: int) -> void:
	current_attack += attack_bonus
	current_health += health_bonus
	max_health += health_bonus
	_update_visuals()


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


func refresh_for_turn() -> void:
	has_attacked = false
	has_moved_this_turn = false
	attacks_this_turn = 0
	_update_can_attack_visual()


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == owner_id:
		just_played = false
		if sleeping_icon:
			sleeping_icon.visible = false
		_update_can_attack_visual()


func _update_can_attack_visual() -> void:
	if highlight:
		var can_act := can_attack_from_row() and GameManager.is_player_turn(owner_id)
		highlight.visible = can_act
		if can_act:
			highlight.color = Color(0.2, 1.0, 0.2, 0.3)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position)
			else:
				_end_drag(event.global_position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _is_dragging:
			_update_drag(event.global_position)
			get_viewport().set_input_as_handled()


func _start_drag(_global_pos: Vector2) -> void:
	# If we own this minion and can move it, allow interaction
	if owner_id == GameManager.active_player and not has_attacked and not has_moved_this_turn:
		# We ONLY emit the signal so PlayerController spawns the targeting arrow.
		minion_drag_started.emit(self)
	else:
		# Just a click
		if is_targetable:
			minion_targeted.emit(self)
		else:
			minion_clicked.emit(self)


func _update_drag(_global_pos: Vector2) -> void:
	# Disabled physical movement - minion stays in slot
	pass


func _end_drag(_global_pos: Vector2) -> void:
	# No cleanup needed since we didn't start a physical drag
	pass


func _on_mouse_entered() -> void:
	if not _is_dragging:
		modulate = Color(1.15, 1.15, 1.15)


func _on_mouse_exited() -> void:
	if not _is_dragging:
		modulate = Color.WHITE


func get_card_data() -> CardData:
	return card_data


func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	if highlight:
		highlight.visible = targetable or (can_attack_from_row() and GameManager.is_player_turn(owner_id))
		if targetable:
			highlight.color = Color(1, 0, 0, 0.3)
		elif can_attack_from_row() and GameManager.is_player_turn(owner_id):
			highlight.color = Color(0.2, 1.0, 0.2, 0.3)


func play_death_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(self, "rotation", 0.3, 0.3)
	await tween.finished
	queue_free()
