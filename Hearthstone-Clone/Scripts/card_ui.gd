# res://scripts/card_ui.gd
class_name card_ui
extends Control

## Emitted when card is clicked
signal card_clicked(card_ui: Control)

## Emitted when drag starts
signal card_drag_started(card_ui: Control)

## Emitted when drag ends
signal card_drag_ended(card_ui: Control, global_position: Vector2)

## Card states
enum CardState {
	IN_HAND,
	DRAGGING,
	HOVERING,
	PLAYED
}

## The card data this UI represents
var CardData: CardData

## Owner player ID
var owner_id: int = 0

## Current state
var current_state: CardState = CardState.IN_HAND

## Can this card be interacted with?
var is_interactable: bool = true

## Original position in hand (for returning)
var _hand_position: Vector2 = Vector2.ZERO

## Original index in hand
var _hand_index: int = 0

## Drag offset
var _drag_offset: Vector2 = Vector2.ZERO

## Is currently being dragged
var _is_dragging: bool = false

## Hover scale multiplier
const HOVER_SCALE := 1.15
const NORMAL_SCALE := 1.0
const HOVER_Y_OFFSET := -30.0

## UI References - these match the scene structure
@onready var card_frame: Panel = $CardFrame
@onready var highlight: ColorRect = $CardFrame/Highlight
@onready var art_panel: Panel = $CardFrame/ArtPanel
@onready var card_art: TextureRect = $CardFrame/ArtPanel/CardArt
@onready var mana_gem: Panel = $CardFrame/ManaGem
@onready var cost_label: Label = $CardFrame/ManaGem/CostLabel
@onready var name_label: Label = $CardFrame/NameLabel
@onready var description_label: RichTextLabel = $CardFrame/DescriptionLabel
@onready var attack_icon: Panel = $CardFrame/AttackIcon
@onready var attack_label: Label = $CardFrame/AttackIcon/AttackLabel
@onready var health_icon: Panel = $CardFrame/HealthIcon
@onready var health_label: Label = $CardFrame/HealthIcon/HealthLabel
@onready var type_icon: TextureRect = $CardFrame/TypeIcon


func _ready() -> void:
	# Ensure visibility
	visible = true
	modulate.a = 1.0
	
	# Set up mouse handling
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Apply default styling to panels
	_apply_default_styles()
	
	# Hide highlight initially
	if highlight:
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to mana changes
	if not GameManager.mana_changed.is_connected(_on_mana_changed):
		GameManager.mana_changed.connect(_on_mana_changed)
	if not GameManager.turn_started.is_connected(_on_turn_started):
		GameManager.turn_started.connect(_on_turn_started)


## Apply default styles to panels (can be overridden in editor)
func _apply_default_styles() -> void:
	# Card frame style
	if card_frame and not card_frame.has_theme_stylebox_override("panel"):
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.15, 0.12, 0.1)
		frame_style.border_color = Color(0.6, 0.5, 0.3)
		frame_style.set_border_width_all(3)
		frame_style.set_corner_radius_all(8)
		card_frame.add_theme_stylebox_override("panel", frame_style)
	
	# Art panel style
	if art_panel and not art_panel.has_theme_stylebox_override("panel"):
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.3, 0.35, 0.4)
		art_style.set_border_width_all(1)
		art_style.border_color = Color(0.2, 0.2, 0.2)
		art_panel.add_theme_stylebox_override("panel", art_style)
	
	# Mana gem style
	if mana_gem and not mana_gem.has_theme_stylebox_override("panel"):
		var mana_style := StyleBoxFlat.new()
		mana_style.bg_color = Color(0.1, 0.3, 0.8)
		mana_style.set_corner_radius_all(12)
		mana_gem.add_theme_stylebox_override("panel", mana_style)
	
	# Attack icon style
	if attack_icon and not attack_icon.has_theme_stylebox_override("panel"):
		var attack_style := StyleBoxFlat.new()
		attack_style.bg_color = Color(0.8, 0.6, 0.1)
		attack_style.set_corner_radius_all(4)
		attack_icon.add_theme_stylebox_override("panel", attack_style)
	
	# Health icon style
	if health_icon and not health_icon.has_theme_stylebox_override("panel"):
		var health_style := StyleBoxFlat.new()
		health_style.bg_color = Color(0.8, 0.2, 0.2)
		health_style.set_corner_radius_all(4)
		health_icon.add_theme_stylebox_override("panel", health_style)


## Initialize the card with data
func initialize(data: CardData, player_id: int) -> void:
	CardData = data
	owner_id = player_id
	
	# Ensure ready
	if not is_inside_tree():
		await ready
	
	_update_visuals()
	_update_playability_visual()
	
	print("[CardUI] Initialized card: %s for player %d" % [data.card_name, player_id])


## Update all visual elements from card data
func _update_visuals() -> void:
	# Use local typed variable to help type checker
	var data: CardData = CardData
	if not data:
		return
	
	if name_label:
		name_label.text = data.card_name
	
	if cost_label:
		cost_label.text = str(data.cost)
	
	# Show/hide attack and health based on card type
	match data.card_type:
		CardData.CardType.MINION:
			if attack_label:
				attack_label.text = str(data.attack)
			if health_label:
				health_label.text = str(data.health)
			if attack_icon:
				attack_icon.visible = true
			if health_icon:
				health_icon.visible = true
		
		CardData.CardType.WEAPON:
			if attack_label:
				attack_label.text = str(data.attack)
			if health_label:
				health_label.text = str(data.health)  # Durability
			if attack_icon:
				attack_icon.visible = true
			if health_icon:
				health_icon.visible = true
		
		CardData.CardType.SPELL, CardData.CardType.HERO_POWER:
			if attack_icon:
				attack_icon.visible = false
			if health_icon:
				health_icon.visible = false
	
	if description_label:
		if data.has_method("get_formatted_description"):
			description_label.text = data.get_formatted_description()
		else:
			description_label.text = data.description
	
	if card_art and data.texture:
		card_art.texture = data.texture
	
	# Color-code by rarity
	_apply_rarity_styling()


## Apply visual styling based on rarity
func _apply_rarity_styling() -> void:
	if not card_frame:
		return
	
	var data: CardData = CardData
	if not data:
		return
	
	var rarity_colors := {
		CardData.Rarity.COMMON: Color(0.5, 0.5, 0.5),
		CardData.Rarity.RARE: Color(0.0, 0.4, 1.0),
		CardData.Rarity.EPIC: Color(0.6, 0.2, 0.8),
		CardData.Rarity.LEGENDARY: Color(1.0, 0.6, 0.0)
	}
	
	var border_color: Color = rarity_colors.get(data.rarity, Color(0.6, 0.5, 0.3))
	
	var current_style = card_frame.get_theme_stylebox("panel")
	if current_style is StyleBoxFlat:
		var style: StyleBoxFlat = current_style.duplicate()
		style.border_color = border_color
		card_frame.add_theme_stylebox_override("panel", style)


## Update visual feedback for whether card is playable
func _update_playability_visual() -> void:
	if not is_instance_valid(self):
		return
	
	var data: CardData = CardData
	if not data:
		return
	
	var can_afford: bool = GameManager.get_current_mana(owner_id) >= data.cost
	var is_turn: bool = GameManager.is_player_turn(owner_id)
	var is_playable: bool = can_afford and is_turn and is_interactable
	
	# Dim unplayable cards
	modulate.a = 1.0 if is_playable else 0.6
	
	# Highlight playable cards with glow
	if highlight:
		highlight.visible = is_playable
		if is_playable:
			highlight.color = Color(0.2, 1.0, 0.2, 0.3)


func _on_mana_changed(player_id: int, _current: int, _maximum: int) -> void:
	if player_id == owner_id:
		_update_playability_visual()


func _on_turn_started(_player_id: int) -> void:
	_update_playability_visual()


## Handle GUI input events
func _gui_input(event: InputEvent) -> void:
	if not is_interactable:
		return
	
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


## Handle mouse enter
func _on_mouse_entered() -> void:
	if current_state == CardState.IN_HAND and is_interactable and not _is_dragging:
		_enter_hover()


## Handle mouse exit
func _on_mouse_exited() -> void:
	if current_state == CardState.HOVERING and not _is_dragging:
		_exit_hover()


## Enter hover state
func _enter_hover() -> void:
	current_state = CardState.HOVERING
	
	# Store current global position before hovering
	_hand_position = global_position
	
	# Use top_level to render above siblings in container
	top_level = true
	global_position = _hand_position
	z_index = 100
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * HOVER_SCALE, 0.1)
	tween.tween_property(self, "global_position:y", global_position.y + HOVER_Y_OFFSET, 0.1)


## Exit hover state
func _exit_hover() -> void:
	current_state = CardState.IN_HAND
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * NORMAL_SCALE, 0.1)
	tween.tween_property(self, "global_position", _hand_position, 0.1)
	
	# Restore normal rendering after animation
	tween.chain().tween_callback(_restore_from_top_level)


## Restore card from top_level mode
func _restore_from_top_level() -> void:
	if current_state == CardState.IN_HAND:
		top_level = false
		z_index = 0
		# Let the container reposition us
		if get_parent():
			get_parent().queue_sort()


## Start dragging the card
func _start_drag(global_pos: Vector2) -> void:
	if not GameManager.is_player_turn(owner_id):
		return
	
	if not is_interactable:
		return
	
	# If we're hovering, _hand_position is already set correctly
	# If not, store current global position
	if current_state != CardState.HOVERING:
		_hand_position = global_position
		# Enable top_level if not already
		if not top_level:
			top_level = true
			global_position = _hand_position
	
	_hand_index = get_index()
	_drag_offset = global_position - global_pos
	
	current_state = CardState.DRAGGING
	_is_dragging = true
	z_index = 100
	
	# Reset scale during drag
	scale = Vector2.ONE * NORMAL_SCALE
	
	card_drag_started.emit(self)


## Update drag position
func _update_drag(global_pos: Vector2) -> void:
	if not _is_dragging:
		return
	global_position = global_pos + _drag_offset


## End dragging
func _end_drag(global_pos: Vector2) -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	current_state = CardState.IN_HAND
	z_index = 0
	
	card_drag_ended.emit(self, global_pos)


## Return card to hand position (called if play fails)
func return_to_hand() -> void:
	current_state = CardState.IN_HAND
	_is_dragging = false
	z_index = 0
	
	# Animate back to hand position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", _hand_position, 0.2)
	tween.tween_callback(_finish_return_to_hand)


## Called after return animation completes
func _finish_return_to_hand() -> void:
	# Disable top_level so container manages position again
	top_level = false
	# Force container to recalculate layout
	if get_parent():
		get_parent().queue_sort()


## Set whether this card can be interacted with
func set_interactable(interactable: bool) -> void:
	is_interactable = interactable
	_update_playability_visual()


## Store hand position after layout
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSFORM_CHANGED:
		if current_state == CardState.IN_HAND and not _is_dragging and not top_level:
			_hand_position = global_position
