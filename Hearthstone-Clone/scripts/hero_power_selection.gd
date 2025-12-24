# res://scripts/hero_power_selection.gd
extends Control

## The selected class data (retrieved from GameManager)
var selected_class: Dictionary = {}
## The selected deck data (retrieved from GameManager)
var selected_deck: Dictionary = {}

## Database of Hero Powers for each class
var hero_power_database: Dictionary = {
	"brute": [
		{
			"name": "Voracious Strike",
			"cost": 2,
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
			"description": "Give a friendly Beast +2 Attack this turn. If it kills a minion this turn, generate 5 Hunger.",
			"id": "beast_fury",
			"target_type": "friendly_beast",
			"attack_bonus": 2,
			"hunger_reward": 5
		},
		{
			"name": "Intimidating Shout",
			"cost": 2,
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
			"name": "Static Shock",
			"cost": 2,
			"description": "Deal 1 damage to any target. Gain 2 Battery.",
			"id": "static_shock",
			"target_type": "any"
		},
		{
			"name": "Fabricate",
			"cost": 2,
			"description": "Summon a 0/2 Barrier Bot with Taunt.",
			"id": "fabricate",
			"target_type": "none"
		},
		{
			"name": "Optimize",
			"cost": 2,
			"description": "Look at the top 2 cards of your deck. Draw one; put the other on the bottom.",
			"id": "optimize",
			"target_type": "none"
		}
	],
	"cute": [
		{
			"name": "Open Auditions",
			"cost": 2,
			"description": "Summon a 1/1 Backup Dancer.",
			"id": "open_auditions",
			"target_type": "none"
		},
		{
			"name": "Pep Talk",
			"cost": 2,
			"description": "Give a minion +1/+1. If you have a Stage location active, give it +2/+2 instead.",
			"id": "pep_talk",
			"target_type": "friendly_minion"
		},
		{
			"name": "Merch Cannon",
			"cost": 2,
			"description": "Draw a card. It costs (1) more.",
			"id": "merch_cannon",
			"target_type": "none"
		}
	],
	"other": [
		{
			"name": "Grim Ritual",
			"cost": 2,
			"description": "Destroy a friendly minion. Draw a card.",
			"id": "grim_ritual",
			"target_type": "friendly_minion"
		},
		{
			"name": "Grave Touch",
			"cost": 2,
			"description": "Deal 1 damage to a minion. If it dies, summon a 1/1 Skeleton.",
			"id": "grave_touch",
			"target_type": "any_minion"
		},
		{
			"name": "Haunt",
			"cost": 2,
			"description": "Add a random Undead to your hand.",
			"id": "haunt",
			"target_type": "none"
		}
	],
	"ace": [
		{
			"name": "Blood Oath",
			"cost": 2,
			"description": "Deal 1 damage to your Hero. Gain 1 Mana Crystal this turn only.",
			"id": "blood_oath",
			"target_type": "none"
		},
		{
			"name": "Draconic Armor",
			"cost": 2,
			"description": "Gain 2 Armor.",
			"id": "draconic_armor",
			"target_type": "none"
		},
		{
			"name": "Challenge",
			"cost": 2,
			"description": "Give a minion Taunt and +1 Health.",
			"id": "challenge",
			"target_type": "any_minion"
		}
	],
	"default": [
		{
			"name": "Minor Heal",
			"cost": 2,
			"description": "Restore 2 Health to any target.",
			"id": "generic_heal",
			"target_type": "any"
		},
		{
			"name": "Dagger Mastery",
			"cost": 2,
			"description": "Equip a 1/2 Dagger.",
			"id": "equip_dagger",
			"target_type": "none"
		},
		{
			"name": "Life Tap",
			"cost": 2,
			"description": "Draw a card and take 2 damage.",
			"id": "tap",
			"target_type": "none"
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
	name_label.text = data.get("name", "Unknown Power")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	
	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cost: %d Mana" % data.get("cost", 2)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cost_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)
	
	# Description
	var desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.text = _format_power_description(data.get("description", ""))
	desc_label.add_theme_font_size_override("normal_font_size", 13)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.custom_minimum_size = Vector2(180, 100)
	vbox.add_child(desc_label)
	
	# Fill remaining space
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer2)
	
	# Target type indicator
	var target_type: String = data.get("target_type", "none")
	var target_text: String = _get_target_type_text(target_type)
	if target_text != "":
		var target_label = Label.new()
		target_label.text = target_text
		target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_label.add_theme_font_size_override("font_size", 11)
		target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(target_label)
	
	# Initial styling
	_style_power_button(btn, false)
	
	# Connect signal
	btn.pressed.connect(_on_power_clicked.bind(index))
	
	return btn


func _format_power_description(desc: String) -> String:
	# Bold keywords
	var formatted := desc
	var keywords := ["Hunger Kicker", "Bully", "Shielded", "Taunt", "Beast"]
	for keyword in keywords:
		formatted = formatted.replace(keyword, "[b]%s[/b]" % keyword)
	return "[center]%s[/center]" % formatted


func _get_target_type_text(target_type: String) -> String:
	match target_type:
		"any":
			return "Target: Any"
		"any_minion":
			return "Target: Any Minion"
		"friendly_minion":
			return "Target: Friendly Minion"
		"enemy_minion":
			return "Target: Enemy Minion"
		"friendly_beast":
			return "Target: Friendly Beast"
		"none":
			return ""
		_:
			return ""


func _style_power_button(btn: Button, is_selected: bool) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	
	if is_selected:
		style.bg_color = Color(0.3, 0.35, 0.4)
		style.border_color = Color(1, 0.8, 0.2)  # Gold border for selected
		style.set_border_width_all(4)
	else:
		style.bg_color = Color(0.2, 0.2, 0.25)
		style.border_color = Color(0.4, 0.4, 0.45)
		style.set_border_width_all(2)
	
	# Apply to all button states
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())
	btn.add_theme_stylebox_override("focus", style.duplicate())


func _create_nav_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 50)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.25, 0.35)
	style.border_color = Color(0.5, 0.45, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.3, 0.4)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn


func _on_power_clicked(index: int) -> void:
	# Toggle off others
	for i in range(power_buttons.size()):
		if i != index:
			power_buttons[i].set_pressed_no_signal(false)
			_style_power_button(power_buttons[i], false)
	
	# Toggle this one
	selected_power_index = index
	_style_power_button(power_buttons[index], true)
	
	_update_ui_state()


func _update_ui_state() -> void:
	confirm_button.disabled = (selected_power_index == -1)
	
	if selected_power_index >= 0:
		confirm_button.text = "Continue to Schedule"
	else:
		confirm_button.text = "Continue"


func _on_back_pressed() -> void:
	# Go back to deck selection
	get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")


func _on_confirm_pressed() -> void:
	if selected_power_index == -1:
		return
	
	var chosen_power = current_power_options[selected_power_index]
	print("[HeroPowerSelection] Chosen: %s" % chosen_power["name"])
	
	# Store in GameManager
	GameManager.set_meta("selected_hero_power", chosen_power)
	
	# Proceed to Schedule Builder
	get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()


## --- Responsive Scaling ---

func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var s = get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * s))
