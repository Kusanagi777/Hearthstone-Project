# res://scripts/hero_power_selection.gd
extends Control

## The selected class data (retrieved from GameManager)
var selected_class: Dictionary = {}
## The selected deck data (retrieved from GameManager)
var selected_deck: Dictionary = {}

## Database of Hero Powers for each class
## Updated with new powers from Hero_Powers.xlsx
var hero_power_database: Dictionary = {
	"brute": [
		{
			"name": "Voracious Strike",
			"cost": 2,
			"cost_type": "mana",
			"description": "Deal 1 damage to any target. Hunger Kicker: Spend 10 Hunger to deal 3 damage instead.",
			"id": "voracious_strike",
			"target_type": "any",
			"hunger_kicker": 10,
			"base_damage": 1,
			"kicker_damage": 3
		},
		{
			"name": "Beast Fury",
			"cost": 2,
			"cost_type": "mana",
			"description": "Give a friendly Beast +2 Attack this turn. If it kills a minion this turn, generate 5 Hunger.",
			"id": "beast_fury",
			"target_type": "friendly_beast",
			"attack_bonus": 2,
			"hunger_reward": 5
		},
		{
			"name": "Intimidating Shout",
			"cost": 2,
			"cost_type": "mana",
			"description": "Give a minion +1 Attack and Bully: \"Gain Shielded before attacking.\"",
			"id": "intimidating_shout",
			"target_type": "any_minion",
			"attack_bonus": 1,
			"grants_bully": true,
			"bully_effect": "shielded_on_attack"
		}
	],
	"technical": [
		{
			"name": "Capacitor Discharge",
			"cost": 2,
			"cost_type": "mana",
			"description": "Deal 1 damage to any target. Gain 1 Battery.",
			"id": "capacitor_discharge",
			"target_type": "any",
			"base_damage": 1,
			"battery_gain": 1
		},
		{
			"name": "Drone Assembly",
			"cost": 2,
			"cost_type": "mana",
			"description": "Summon a 0/2 Barrier Bot with Taunt.",
			"id": "drone_assembly",
			"target_type": "none",
			"summon_name": "Barrier Bot",
			"summon_attack": 0,
			"summon_health": 2,
			"summon_keywords": ["Taunt"],
			"summon_tags": ["Mech"]
		},
		{
			"name": "Safety Override",
			"cost": 2,
			"cost_type": "battery",
			"description": "Look at the top 2 cards of your deck. Draw one; put the other on the bottom.",
			"id": "safety_override",
			"target_type": "none",
			"cards_to_look": 2
		}
	],
	"cute": [
		{
			"name": "Merch Table",
			"cost": 2,
			"cost_type": "mana",
			"description": "Summon a 0/2 Vendor. The Vendor has Huddle: \"Gain 2 Fans.\"",
			"id": "merch_table",
			"target_type": "none",
			"summon_name": "Vendor",
			"summon_attack": 0,
			"summon_health": 2,
			"summon_keywords": ["Huddle"],
			"summon_tags": ["Idol"],
			"huddle_effect": "gain_fans",
			"huddle_value": 2
		},
		{
			"name": "Security Detail",
			"cost": 2,
			"cost_type": "mana",
			"description": "Summon a 1/1 Bouncer. The Bouncer has Huddle: \"If the other minion is an Idol, give it Shielded and +1 Health.\"",
			"id": "security_detail",
			"target_type": "none",
			"summon_name": "Bouncer",
			"summon_attack": 1,
			"summon_health": 1,
			"summon_keywords": ["Huddle"],
			"summon_tags": [],
			"huddle_effect": "buff_idol",
			"huddle_health_bonus": 1
		},
		{
			"name": "Understudy",
			"cost": 2,
			"cost_type": "mana",
			"description": "Target a minion in your hand. Give it Huddle: \"Give the front minion +1/+1.\"",
			"id": "understudy",
			"target_type": "hand_minion",
			"grants_huddle": true,
			"huddle_effect": "buff_front",
			"huddle_attack_bonus": 1,
			"huddle_health_bonus": 1
		}
	],
	"other": [
		{
			"name": "Grim Fate",
			"cost": 2,
			"cost_type": "mana",
			"description": "Destroy a friendly minion. Draw a card.",
			"id": "grim_fate",
			"target_type": "friendly_minion",
			"draws_card": true
		},
		{
			"name": "Grave Touch",
			"cost": 2,
			"cost_type": "mana",
			"description": "Deal 1 damage to a minion. If it dies, summon a 1/1 Skeleton.",
			"id": "grave_touch",
			"target_type": "any_minion",
			"base_damage": 1,
			"summon_on_kill": true,
			"summon_name": "Skeleton",
			"summon_attack": 1,
			"summon_health": 1,
			"summon_tags": ["Undead"]
		},
		{
			"name": "Dark Ritual",
			"cost": 2,
			"cost_type": "mana",
			"description": "Ritual: Sacrifice 1 → 2/2 Horror. Sacrifice 2 → 4/4 Abomination with Taunt. Sacrifice 3+ → 8/8 Behemoth with Taunt and Rush.",
			"id": "dark_ritual",
			"target_type": "ritual",
			"is_ritual": true,
			"ritual_tiers": [
				{
					"sacrifices": 1,
					"summon_name": "Horror",
					"summon_attack": 2,
					"summon_health": 2,
					"summon_keywords": [],
					"summon_tags": ["Undead"]
				},
				{
					"sacrifices": 2,
					"summon_name": "Abomination",
					"summon_attack": 4,
					"summon_health": 4,
					"summon_keywords": ["Taunt"],
					"summon_tags": ["Undead"]
				},
				{
					"sacrifices": 3,
					"summon_name": "Behemoth",
					"summon_attack": 8,
					"summon_health": 8,
					"summon_keywords": ["Taunt", "Rush"],
					"summon_tags": ["Undead"]
				}
			]
		}
	],
	"ace": [
		{
			"name": "Calculated Risk",
			"cost": 2,
			"cost_type": "mana",
			"description": "Deal 1 damage to your Hero. Deal 2 damage to a target minion.",
			"id": "calculated_risk",
			"target_type": "any_minion",
			"self_damage": 1,
			"target_damage": 2
		},
		{
			"name": "Draconic Herald",
			"cost": 2,
			"cost_type": "mana",
			"description": "Draw a Dragon. Reduce its cost by (1). If no Dragons, draw a card instead (without reduction).",
			"id": "draconic_herald",
			"target_type": "none",
			"draw_tribe": "Dragon",
			"cost_reduction": 1,
			"fallback_draw": true
		},
		{
			"name": "Stacked Deck",
			"cost": 1,
			"cost_type": "spirit",
			"description": "Discover a card from your deck. Place it on top of your deck. It costs (2) less next turn.",
			"id": "stacked_deck",
			"target_type": "none",
			"discover_from_deck": true,
			"cost_reduction": 2,
			"reduction_duration": 1
		}
	],
	"default": [
		{
			"name": "Minor Heal",
			"cost": 2,
			"cost_type": "mana",
			"description": "Restore 2 Health to any target.",
			"id": "generic_heal",
			"target_type": "any",
			"heal_amount": 2
		},
		{
			"name": "Dagger Mastery",
			"cost": 2,
			"cost_type": "mana",
			"description": "Equip a 1/2 Dagger.",
			"id": "equip_dagger",
			"target_type": "none"
		},
		{
			"name": "Life Tap",
			"cost": 2,
			"cost_type": "mana",
			"description": "Draw a card and take 2 damage.",
			"id": "tap",
			"target_type": "none",
			"self_damage": 2,
			"draws_card": true
		}
	]
}

## UI References
var power_container: HBoxContainer
var confirm_button: Button
var back_button: Button
var title_label: Label
var power_buttons: Array[Button] = []

## State
var selected_power_index: int = -1
var current_power_options: Array = []

## Responsive scaling
const REFERENCE_HEIGHT: float = 720.0


func _ready() -> void:
	# Retrieve data passed from previous screens
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
	
	if GameManager.has_meta("selected_deck"):
		selected_deck = GameManager.get_meta("selected_deck")
	
	_setup_ui()
	_load_power_options()
	_update_ui_state()
	
	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# 1. Background (Dark overlay)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)
	add_child(bg)
	
	# 2. Main Layout Container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 30)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 50)
	margin.add_theme_constant_override("margin_bottom", 50)
	margin.add_child(main_vbox)
	add_child(margin)
	
	# 3. Title
	title_label = Label.new()
	title_label.text = "Select Hero Power"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	main_vbox.add_child(title_label)
	
	# 4. Class Info Subtitle
	var class_name_str = selected_class.get("name", "Unknown")
	var subtitle = Label.new()
	subtitle.text = "Class: %s" % class_name_str
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main_vbox.add_child(subtitle)
	
	# 5. Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)
	
	# 6. Hero Power Button Container
	power_container = HBoxContainer.new()
	power_container.alignment = BoxContainer.ALIGNMENT_CENTER
	power_container.add_theme_constant_override("separation", 40)
	power_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(power_container)
	
	# 7. Bottom Navigation Bar
	var nav_hbox = HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 50)
	main_vbox.add_child(nav_hbox)
	
	back_button = _create_nav_button("Back to Decks")
	back_button.pressed.connect(_on_back_pressed)
	nav_hbox.add_child(back_button)
	
	confirm_button = _create_nav_button("Continue")
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true  # Start disabled until selection made
	nav_hbox.add_child(confirm_button)
	
	_apply_responsive_fonts()


func _load_power_options() -> void:
	var class_id = selected_class.get("id", "default")
	
	# Fetch options based on class ID, fallback to 'default' if not found
	if hero_power_database.has(class_id):
		current_power_options = hero_power_database[class_id]
	else:
		current_power_options = hero_power_database["default"]
	
	# Create a button/card for each option
	for i in range(current_power_options.size()):
		var power_data = current_power_options[i]
		var btn = _create_power_card(power_data, i)
		power_container.add_child(btn)
		power_buttons.append(btn)


func _create_power_card(data: Dictionary, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 320)
	btn.toggle_mode = true
	
	# Container for card content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 12)
	
	# Inner Margin
	var inner_margin = MarginContainer.new()
	inner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_margin.add_theme_constant_override("margin_left", 15)
	inner_margin.add_theme_constant_override("margin_right", 15)
	inner_margin.add_theme_constant_override("margin_top", 20)
	inner_margin.add_theme_constant_override("margin_bottom", 15)
	inner_margin.add_child(vbox)
	btn.add_child(inner_margin)
	
	# Power Name
	var name_label = Label.new()
	name_label.text = data.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	# Cost display with type indicator
	var cost_label = Label.new()
	var cost_type: String = data.get("cost_type", "mana")
	var cost_value: int = data.get("cost", 2)
	var cost_icon: String = _get_cost_icon(cost_type)
	cost_label.text = "%s %d" % [cost_icon, cost_value]
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	cost_label.add_theme_color_override("font_color", _get_cost_color(cost_type))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	
	# Description
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.text = "[center]%s[/center]" % data.get("description", "")
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.custom_minimum_size = Vector2(180, 120)
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_label)
	
	# Style the button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.17, 0.22)
	normal_style.border_color = Color(0.4, 0.38, 0.35)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.25, 0.3, 0.4)
	pressed_style.border_color = Color(1.0, 0.85, 0.4)
	pressed_style.set_border_width_all(3)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.pressed.connect(_on_power_selected.bind(index))
	
	return btn


func _get_cost_icon(cost_type: String) -> String:
	match cost_type:
		"mana":
			return "💧"
		"battery":
			return "⚡"
		"spirit":
			return "✨"
		"hunger":
			return "🔥"
		_:
			return "💧"


func _get_cost_color(cost_type: String) -> Color:
	match cost_type:
		"mana":
			return Color(0.3, 0.6, 1.0)
		"battery":
			return Color(0.2, 0.9, 0.4)
		"spirit":
			return Color(1.0, 0.9, 0.4)
		"hunger":
			return Color(1.0, 0.4, 0.2)
		_:
			return Color(0.3, 0.6, 1.0)


func _on_power_selected(index: int) -> void:
	# Deselect previous
	if selected_power_index >= 0 and selected_power_index < power_buttons.size():
		power_buttons[selected_power_index].button_pressed = false
	
	selected_power_index = index
	power_buttons[index].button_pressed = true
	
	_update_ui_state()


func _update_ui_state() -> void:
	confirm_button.disabled = (selected_power_index < 0)


func _create_nav_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 45)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.28)
	style.border_color = Color(0.5, 0.45, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.28, 0.3, 0.38)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.12, 0.12, 0.15)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")


func _on_confirm_pressed() -> void:
	if selected_power_index < 0:
		return
	
	var selected_power = current_power_options[selected_power_index]
	
	# Store selection in GameManager
	GameManager.set_meta("selected_hero_power", selected_power)
	
	print("[HeroPowerSelection] Selected: %s" % selected_power.get("name", "Unknown"))
	
	# Proceed to next screen (schedule builder)
	get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale_factor := get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale_factor))


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
