# res://scripts/deck_selection.gd
extends Control

## The selected class data (passed from class selection)
var selected_class: Dictionary = {}

## Deck options for each class
var deck_options: Dictionary = {
	"brute": [
		{
			"name": "Berserker's Fury",
			"archetype": "Aggro",
			"description": "All-out offense! Flood the board with cheap, high-attack minions and overwhelm your opponent before they can react.",
			"color": Color(0.9, 0.3, 0.2),
			"signature": "Raging Berserker",
			"cards": ["bat", "bat", "wisp", "wisp", "brawler", "brawler", "wolf", "wolf", "warrior", "warrior", 
					  "bat", "wisp", "brawler", "wolf", "warrior", "juggernaut", "juggernaut", "mage", "werewolf", "werewolf",
					  "golem", "golem", "demon", "demon", "dragon", "bat", "brawler", "wolf", "warrior", "juggernaut"]
		},
		{
			"name": "Iron Wall",
			"archetype": "Control",
			"description": "Outlast your enemies with high-health minions and efficient trades. Patience leads to victory.",
			"color": Color(0.5, 0.5, 0.6),
			"signature": "Stone Guardian",
			"cards": ["brawler", "brawler", "wolf", "wolf", "warrior", "warrior", "juggernaut", "juggernaut", "werewolf", "werewolf",
					  "golem", "golem", "golem", "demon", "demon", "dragon", "dragon", "brawler", "wolf", "warrior",
					  "juggernaut", "werewolf", "golem", "demon", "dragon", "warrior", "juggernaut", "werewolf", "golem", "demon"]
		},
		{
			"name": "Blood & Thunder",
			"archetype": "Midrange",
			"description": "A balanced approach with steady minion curve. Adapt to any situation with versatile threats.",
			"color": Color(0.7, 0.2, 0.3),
			"signature": "Thunder Champion",
			"cards": ["wisp", "bat", "bat", "brawler", "brawler", "brawler", "wolf", "wolf", "warrior", "warrior",
					  "juggernaut", "juggernaut", "mage", "mage", "werewolf", "werewolf", "golem", "demon", "dragon", "wisp",
					  "bat", "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon", "bat", "brawler"]
		}
	],
	"technical": [
		{
			"name": "Mind Games",
			"archetype": "Control",
			"description": "Outthink your opponent with card advantage and efficient removal. Every card counts.",
			"color": Color(0.2, 0.5, 0.9),
			"signature": "Arcane Intellect",
			"cards": ["mage", "mage", "mage", "werewolf", "werewolf", "golem", "golem", "demon", "demon", "dragon",
					  "brawler", "brawler", "wolf", "wolf", "warrior", "warrior", "juggernaut", "juggernaut", "mage", "werewolf",
					  "golem", "demon", "dragon", "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon"]
		},
		{
			"name": "Combo Master",
			"archetype": "Combo",
			"description": "Set up devastating combinations! Survive until you can unleash your game-winning plays.",
			"color": Color(0.3, 0.3, 0.7),
			"signature": "Puzzle Box",
			"cards": ["wisp", "wisp", "bat", "bat", "brawler", "brawler", "mage", "mage", "mage", "werewolf",
					  "werewolf", "golem", "golem", "demon", "demon", "dragon", "dragon", "wisp", "bat", "brawler",
					  "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon", "dragon", "wolf", "warrior"]
		},
		{
			"name": "Tempo Tech",
			"archetype": "Midrange",
			"description": "Efficient plays at every mana cost. Always have the right answer at the right time.",
			"color": Color(0.4, 0.6, 0.8),
			"signature": "Gadgeteer",
			"cards": ["bat", "bat", "brawler", "brawler", "wolf", "wolf", "warrior", "warrior", "mage", "mage",
					  "juggernaut", "juggernaut", "werewolf", "werewolf", "golem", "golem", "demon", "bat", "brawler", "wolf",
					  "warrior", "mage", "juggernaut", "werewolf", "golem", "demon", "dragon", "bat", "brawler", "wolf"]
		}
	],
	"cute": [
		{
			"name": "Friendship Power",
			"archetype": "Aggro",
			"description": "Summon a swarm of adorable minions! They may be small, but together they're unstoppable!",
			"color": Color(1.0, 0.5, 0.7),
			"signature": "Best Friends",
			"cards": ["wisp", "wisp", "wisp", "bat", "bat", "bat", "brawler", "brawler", "brawler", "wolf",
					  "wolf", "wolf", "wisp", "bat", "brawler", "wolf", "warrior", "warrior", "wisp", "bat",
					  "brawler", "wolf", "warrior", "juggernaut", "wisp", "bat", "brawler", "wolf", "warrior", "juggernaut"]
		},
		{
			"name": "Cuddle Buddies",
			"archetype": "Midrange",
			"description": "Build an army of cute creatures that grow stronger together. Synergy is key!",
			"color": Color(0.9, 0.7, 0.8),
			"signature": "Cuddle Captain",
			"cards": ["wisp", "wisp", "bat", "bat", "brawler", "brawler", "wolf", "wolf", "warrior", "warrior",
					  "juggernaut", "juggernaut", "mage", "werewolf", "golem", "wisp", "bat", "brawler", "wolf", "warrior",
					  "juggernaut", "mage", "werewolf", "golem", "demon", "wisp", "bat", "brawler", "wolf", "warrior"]
		},
		{
			"name": "Protective Pals",
			"archetype": "Control",
			"description": "Shield your cute companions and outlast your foes. Defense with a smile!",
			"color": Color(0.8, 0.9, 1.0),
			"signature": "Guardian Angel",
			"cards": ["brawler", "brawler", "wolf", "wolf", "warrior", "warrior", "juggernaut", "juggernaut", "werewolf", "werewolf",
					  "golem", "golem", "demon", "demon", "dragon", "brawler", "wolf", "warrior", "juggernaut", "werewolf",
					  "golem", "demon", "dragon", "wolf", "warrior", "juggernaut", "werewolf", "golem", "demon", "dragon"]
		}
	],
	"other": [
		{
			"name": "Chaos Theory",
			"archetype": "Combo",
			"description": "Embrace randomness! Unpredictable effects that can swing the game in your favor... or not.",
			"color": Color(0.6, 0.2, 0.7),
			"signature": "Void Caller",
			"cards": ["wisp", "bat", "brawler", "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon",
					  "dragon", "wisp", "bat", "brawler", "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem",
					  "demon", "dragon", "wisp", "bat", "brawler", "wolf", "warrior", "juggernaut", "mage", "werewolf"]
		},
		{
			"name": "Beyond Reality",
			"archetype": "Control",
			"description": "Warp the rules of the game. Your opponent can never predict what comes next.",
			"color": Color(0.4, 0.1, 0.5),
			"signature": "Reality Bender",
			"cards": ["mage", "mage", "werewolf", "werewolf", "golem", "golem", "demon", "demon", "dragon", "dragon",
					  "warrior", "warrior", "juggernaut", "juggernaut", "mage", "werewolf", "golem", "demon", "dragon", "wolf",
					  "warrior", "juggernaut", "mage", "werewolf", "golem", "demon", "dragon", "warrior", "juggernaut", "mage"]
		},
		{
			"name": "Whispers",
			"archetype": "Aggro",
			"description": "Strike from the shadows with mysterious forces. Fast and unsettling.",
			"color": Color(0.3, 0.15, 0.4),
			"signature": "Shadow Whisperer",
			"cards": ["wisp", "wisp", "bat", "bat", "bat", "brawler", "brawler", "wolf", "wolf", "warrior",
					  "mage", "mage", "juggernaut", "werewolf", "wisp", "bat", "brawler", "wolf", "warrior", "mage",
					  "juggernaut", "werewolf", "golem", "wisp", "bat", "brawler", "wolf", "warrior", "mage", "juggernaut"]
		}
	],
	"ace": [
		{
			"name": "Jack of All Trades",
			"archetype": "Midrange",
			"description": "A perfectly balanced deck for any situation. Adapt and overcome!",
			"color": Color(0.9, 0.8, 0.4),
			"signature": "Versatile Victor",
			"cards": ["wisp", "bat", "bat", "brawler", "brawler", "wolf", "wolf", "warrior", "warrior", "juggernaut",
					  "juggernaut", "mage", "mage", "werewolf", "werewolf", "golem", "demon", "dragon", "bat", "brawler",
					  "wolf", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon", "dragon", "brawler", "wolf"]
		},
		{
			"name": "Golden Standard",
			"archetype": "Control",
			"description": "Premium quality in every card. Expensive but devastatingly effective.",
			"color": Color(1.0, 0.85, 0.3),
			"signature": "Golden Champion",
			"cards": ["warrior", "warrior", "juggernaut", "juggernaut", "mage", "mage", "werewolf", "werewolf", "golem", "golem",
					  "demon", "demon", "dragon", "dragon", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon",
					  "dragon", "warrior", "juggernaut", "mage", "werewolf", "golem", "demon", "dragon", "golem", "demon"]
		},
		{
			"name": "Rising Star",
			"archetype": "Aggro",
			"description": "Fast starts and early pressure. Prove your worth before they know what hit them!",
			"color": Color(0.95, 0.7, 0.2),
			"signature": "Shooting Star",
			"cards": ["wisp", "wisp", "wisp", "bat", "bat", "bat", "brawler", "brawler", "brawler", "wolf",
					  "wolf", "wolf", "warrior", "warrior", "warrior", "juggernaut", "mage", "wisp", "bat", "brawler",
					  "wolf", "warrior", "juggernaut", "mage", "werewolf", "wisp", "bat", "brawler", "wolf", "warrior"]
		}
	]
}

## Currently selected deck index
var selected_index: int = -1

## UI References
var deck_buttons: Array[Control] = []
var description_label: RichTextLabel
var select_button: Button
var back_button: Button
var title_label: Label
var class_label: Label
var deck_container: Control

## Reference resolution
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	# Get selected class from GameManager (set by class selection screen)
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
	else:
		# Default for testing
		selected_class = {"id": "brute", "name": "Brute", "color": Color(0.8, 0.2, 0.2)}
	
	_setup_ui()
	_connect_signals()
	_apply_styling()
	
	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	var height_scale = viewport_size.y / REFERENCE_HEIGHT
	return clampf(height_scale, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)
	add_child(bg)
	
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	margin.add_child(main_vbox)
	
	# Class indicator
	class_label = Label.new()
	class_label.text = "Playing as: %s" % selected_class.get("name", "Unknown")
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 16)
	class_label.add_theme_color_override("font_color", selected_class.get("color", Color.WHITE))
	main_vbox.add_child(class_label)
	
	# Title
	title_label = Label.new()
	title_label.text = "Choose Your Starting Deck"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(title_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer1)
	
	# Deck buttons container (horizontal)
	deck_container = HBoxContainer.new()
	deck_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deck_container.add_theme_constant_override("separation", 30)
	main_vbox.add_child(deck_container)
	
	# Get decks for selected class
	var class_id: String = selected_class.get("id", "brute")
	var decks: Array = deck_options.get(class_id, deck_options["brute"])
	
	# Create deck buttons
	for i in range(decks.size()):
		var deck_data: Dictionary = decks[i]
		var deck_button = _create_deck_button(deck_data, i)
		deck_container.add_child(deck_button)
		deck_buttons.append(deck_button)
	
	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(900, 100)
	desc_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(desc_panel)
	
	var desc_margin = MarginContainer.new()
	desc_margin.add_theme_constant_override("margin_left", 20)
	desc_margin.add_theme_constant_override("margin_right", 20)
	desc_margin.add_theme_constant_override("margin_top", 15)
	desc_margin.add_theme_constant_override("margin_bottom", 15)
	desc_panel.add_child(desc_margin)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))
	description_label.add_theme_font_size_override("normal_font_size", 15)
	description_label.text = "[center]Select a deck to see its description[/center]"
	desc_margin.add_child(description_label)
	
	# Style description panel
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.12, 0.12, 0.15, 0.9)
	desc_style.border_color = Color(0.4, 0.35, 0.3)
	desc_style.set_border_width_all(2)
	desc_style.set_corner_radius_all(10)
	desc_panel.add_theme_stylebox_override("panel", desc_style)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)
	
	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(button_hbox)
	
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 50)
	button_hbox.add_child(back_button)
	
	select_button = Button.new()
	select_button.text = "Start Run"
	select_button.custom_minimum_size = Vector2(200, 50)
	select_button.disabled = true
	button_hbox.add_child(select_button)
	
	_apply_responsive_fonts()


func _create_deck_button(deck_data: Dictionary, index: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 300)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(content_vbox)
	
	# Deck name
	var name_label = Label.new()
	name_label.text = deck_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", deck_data["color"])
	content_vbox.add_child(name_label)
	
	# Archetype badge
	var archetype_label = Label.new()
	archetype_label.text = "[ %s ]" % deck_data["archetype"]
	archetype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	archetype_label.add_theme_font_size_override("font_size", 14)
	var archetype_colors = {
		"Aggro": Color(0.9, 0.4, 0.3),
		"Control": Color(0.3, 0.5, 0.8),
		"Midrange": Color(0.5, 0.7, 0.4),
		"Combo": Color(0.7, 0.4, 0.8)
	}
	archetype_label.add_theme_color_override("font_color", archetype_colors.get(deck_data["archetype"], Color.WHITE))
	content_vbox.add_child(archetype_label)
	
	# Separator
	var sep = HSeparator.new()
	content_vbox.add_child(sep)
	
	# Signature card
	var sig_label = Label.new()
	sig_label.text = "Signature Card:"
	sig_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig_label.add_theme_font_size_override("font_size", 12)
	sig_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	content_vbox.add_child(sig_label)
	
	var sig_name = Label.new()
	sig_name.text = deck_data["signature"]
	sig_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sig_name.add_theme_font_size_override("font_size", 16)
	sig_name.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	content_vbox.add_child(sig_name)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(spacer)
	
	# Card count
	var count_label = Label.new()
	count_label.text = "📜 30 Cards"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	content_vbox.add_child(count_label)
	
	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	# Make clickable
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_deck_button_input.bind(index))
	panel.mouse_entered.connect(_on_deck_button_hover.bind(index))
	
	return panel


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)


func _apply_styling() -> void:
	_style_button(back_button)
	_style_button(select_button)


func _apply_responsive_fonts() -> void:
	var scale_factor = get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(32 * scale_factor))
	
	if class_label:
		class_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	
	if description_label:
		description_label.add_theme_font_size_override("normal_font_size", int(15 * scale_factor))
	
	if back_button:
		back_button.add_theme_font_size_override("font_size", int(18 * scale_factor))
	
	if select_button:
		select_button.add_theme_font_size_override("font_size", int(18 * scale_factor))


func _style_button(button: Button) -> void:
	if not button:
		return
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.25, 0.35)
	normal_style.border_color = Color(0.5, 0.45, 0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(10)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.35, 0.45)
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.2, 0.3)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.25, 0.25, 0.28)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))


func _on_deck_button_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_deck(index)


func _on_deck_button_hover(index: int) -> void:
	_update_description(index)


func _select_deck(index: int) -> void:
	var class_id: String = selected_class.get("id", "brute")
	var decks: Array = deck_options.get(class_id, deck_options["brute"])
	
	# Deselect previous
	if selected_index >= 0 and selected_index < deck_buttons.size():
		var prev_deck: Dictionary = decks[selected_index]
		_set_button_selected(deck_buttons[selected_index], false, prev_deck["color"])
	
	# Select new
	selected_index = index
	var new_deck: Dictionary = decks[index]
	_set_button_selected(deck_buttons[index], true, new_deck["color"])
	_update_description(index)
	
	# Enable select button
	if select_button:
		select_button.disabled = false


func _set_button_selected(button: Control, selected: bool, deck_color: Color) -> void:
	var style = StyleBoxFlat.new()
	if selected:
		style.bg_color = deck_color.darkened(0.6)
		style.border_color = deck_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.15, 0.15, 0.18)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("panel", style)


func _update_description(index: int) -> void:
	var class_id: String = selected_class.get("id", "brute")
	var decks: Array = deck_options.get(class_id, deck_options["brute"])
	
	if index < 0 or index >= decks.size():
		return
	
	var deck_data: Dictionary = decks[index]
	var color_hex = deck_data["color"].to_html(false)
	
	var text = "[center][color=#%s][b]%s[/b][/color] - [i]%s[/i]\n\n%s[/center]" % [
		color_hex,
		deck_data["name"],
		deck_data["archetype"],
		deck_data["description"]
	]
	
	if description_label:
		description_label.text = text


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/class_selection.tscn")


func _on_select_pressed() -> void:
	if selected_index < 0:
		return
	
	var class_id: String = selected_class.get("id", "brute")
	var decks: Array = deck_options.get(class_id, deck_options["brute"])
	var selected_deck: Dictionary = decks[selected_index]
	
	print("[DeckSelection] Selected deck: %s" % selected_deck["name"])
	print("[DeckSelection] Class: %s" % selected_class["name"])
	
	# Store selection in GameManager
	GameManager.set_meta("selected_class", selected_class)
	GameManager.set_meta("selected_deck", selected_deck)
	
	# CHANGE: Instead of going to main_game, go to hero_power_selection
	# Make sure you create the scene file 'hero_power_selection.tscn' 
	# and attach the new script to the root node!
	get_tree().change_scene_to_file("res://scenes/hero_power_selection.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
