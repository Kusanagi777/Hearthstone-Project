# res://scripts/deck_selection.gd
extends Control

const STARTER_DECKS_PATH := "res://data/starter_decks/"

## Currently selected deck index
var selected_index: int = -1

## UI References
var deck_buttons: Array[Control] = []
var description_label: RichTextLabel
var select_button: Button
var back_button: Button
var title_label: Label
var deck_container: Control

## Reference resolution
const REFERENCE_HEIGHT = 720.0

## Available starter decks
var deck_options: Array[Dictionary] = []


func _ready() -> void:
	_load_starter_decks()
	_setup_ui()
	_connect_signals()
	_apply_styling()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _load_starter_decks() -> void:
	deck_options.clear()
	
	# Try to load from starter decks folder
	var dir := DirAccess.open(STARTER_DECKS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := STARTER_DECKS_PATH + file_name
				var deck_data = load(path)
				
				if deck_data and deck_data.has_method("get"):
					deck_options.append({
						"name": deck_data.deck_name if "deck_name" in deck_data else file_name,
						"description": deck_data.description if "description" in deck_data else "",
						"color": deck_data.theme_color if "theme_color" in deck_data else Color.WHITE,
						"cards": Array(deck_data.card_ids) if "card_ids" in deck_data else []
					})
					print("[DeckSelection] Loaded deck: %s" % deck_data.deck_name if "deck_name" in deck_data else file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# If no decks found, create default options
	if deck_options.is_empty():
		_create_default_decks()
	
	print("[DeckSelection] Loaded %d decks" % deck_options.size())


func _create_default_decks() -> void:
	deck_options = [
		{
			"name": "Aggro Rush",
			"description": "Fast and aggressive! Low-cost minions with Charge and Rush to overwhelm your opponent quickly.",
			"color": Color(0.8, 0.2, 0.2),
			"cards": ["wisp", "wisp", "bat", "bat", "wolf", "wolf", "brawler", "brawler", 
					  "warrior", "warrior", "werewolf", "werewolf"]
		},
		{
			"name": "Control",
			"description": "Survive and outlast. High-health minions with Taunt to protect yourself while building advantage.",
			"color": Color(0.2, 0.4, 0.8),
			"cards": ["wisp", "wisp", "brawler", "brawler", "warrior", "warrior",
					  "juggernaut", "juggernaut", "golem", "golem", "mage", "mage"]
		},
		{
			"name": "Balanced",
			"description": "A well-rounded deck with answers to many situations. Adaptable to any matchup.",
			"color": Color(0.3, 0.7, 0.3),
			"cards": ["wisp", "bat", "wolf", "brawler", "warrior", "mage",
					  "werewolf", "juggernaut", "golem", "demon", "dragon"]
		}
	]


func _setup_ui() -> void:
	# Find or create main container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	center.add_child(main_vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Select a Deck"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	main_vbox.add_child(title_label)
	
	# Deck container
	deck_container = HBoxContainer.new()
	deck_container.add_theme_constant_override("separation", 20)
	deck_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(deck_container)
	
	# Create deck buttons
	for i in range(deck_options.size()):
		var deck := deck_options[i]
		var btn := _create_deck_button(deck, i)
		deck_container.add_child(btn)
		deck_buttons.append(btn)
	
	# Description
	description_label = RichTextLabel.new()
	description_label.custom_minimum_size = Vector2(500, 80)
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.add_theme_font_size_override("normal_font_size", 16)
	description_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))
	main_vbox.add_child(description_label)
	
	# Navigation buttons
	var nav_container := HBoxContainer.new()
	nav_container.add_theme_constant_override("separation", 30)
	nav_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(nav_container)
	
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 50)
	nav_container.add_child(back_button)
	
	select_button = Button.new()
	select_button.text = "Start Game"
	select_button.custom_minimum_size = Vector2(150, 50)
	select_button.disabled = true
	nav_container.add_child(select_button)


func _create_deck_button(deck: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_child(vbox)
	panel.add_child(margin)
	
	# Deck name
	var name_label := Label.new()
	name_label.text = deck.get("name", "Deck %d" % (index + 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", deck.get("color", Color.WHITE))
	vbox.add_child(name_label)
	
	# Card count
	var count_label := Label.new()
	var card_count: int = deck.get("cards", []).size()
	count_label.text = "%d cards" % card_count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(count_label)
	
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	# Input handling
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_select_deck(index)
	)
	panel.mouse_entered.connect(func(): _on_deck_hover(index))
	
	return panel


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)


func _apply_styling() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	move_child(bg, 0)
	
	# Style navigation buttons
	for btn in [back_button, select_button]:
		if btn:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.22, 0.28)
			style.border_color = Color(0.35, 0.38, 0.45)
			style.set_border_width_all(2)
			style.set_corner_radius_all(8)
			btn.add_theme_stylebox_override("normal", style)
			
			var hover := style.duplicate()
			hover.bg_color = Color(0.25, 0.28, 0.35)
			btn.add_theme_stylebox_override("hover", hover)


func _get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return float(viewport_size.y) / REFERENCE_HEIGHT


func _on_viewport_size_changed() -> void:
	var scale := _get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale))


func _select_deck(index: int) -> void:
	# Deselect previous
	if selected_index >= 0 and selected_index < deck_buttons.size():
		_set_button_selected(deck_buttons[selected_index], false, deck_options[selected_index].get("color", Color.WHITE))
	
	# Select new
	selected_index = index
	_set_button_selected(deck_buttons[index], true, deck_options[index].get("color", Color.WHITE))
	_update_description(index)
	
	# Enable select button
	if select_button:
		select_button.disabled = false


func _set_button_selected(button: Control, selected: bool, deck_color: Color) -> void:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = deck_color.darkened(0.7)
		style.border_color = deck_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.15, 0.15, 0.18)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("panel", style)


func _on_deck_hover(index: int) -> void:
	_update_description(index)


func _update_description(index: int) -> void:
	if index < 0 or index >= deck_options.size():
		return
	
	var deck := deck_options[index]
	if description_label:
		description_label.text = "[center]%s[/center]" % deck.get("description", "")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_select_pressed() -> void:
	if selected_index < 0 or selected_index >= deck_options.size():
		return
	
	var selected_deck: Dictionary = deck_options[selected_index]
	print("[DeckSelection] Selected deck: %s" % selected_deck.get("name", "Unknown"))
	
	# Store selected deck in GameManager
	GameManager.set_meta("selected_deck", selected_deck)
	
	# Go to game
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
