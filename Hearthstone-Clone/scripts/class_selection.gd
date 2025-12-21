# res://scripts/class_selection.gd
extends Control

## Emitted when a class is selected
signal class_selected(class_data: Dictionary)

## Class data definitions
var classes: Array[Dictionary] = [
	{
		"id": "brute",
		"name": "Brute",
		"description": "Raw power and overwhelming force. The Brute crushes enemies with high-attack minions and direct damage. Favors aggressive strategies and trading health for power.",
		"color": Color(0.8, 0.2, 0.2),  # Red
		"icon": "⚔️",
		"health": 35,
		"hero_power": "Rage Strike",
		"hero_power_desc": "Deal 1 damage to a random enemy."
	},
	{
		"id": "technical",
		"name": "Technical",
		"description": "Precision and planning. The Technical class manipulates the battlefield with card draw, removal spells, and clever combinations. Knowledge is power.",
		"color": Color(0.2, 0.4, 0.8),  # Blue
		"icon": "🔧",
		"health": 28,
		"hero_power": "Analyze",
		"hero_power_desc": "Draw a card. It costs (1) less."
	},
	{
		"id": "cute",
		"name": "Cute",
		"description": "Swarm and synergy. The Cute class summons adorable minions that buff each other. Underestimate them at your peril - they grow stronger together!",
		"color": Color(1.0, 0.6, 0.8),  # Pink
		"icon": "🌸",
		"health": 30,
		"hero_power": "Friend Summon",
		"hero_power_desc": "Summon a 1/1 Buddy."
	},
	{
		"id": "other",
		"name": "The Other",
		"description": "Mystery and chaos. The Other defies categorization with unpredictable effects and reality-bending abilities. Embrace the unknown.",
		"color": Color(0.5, 0.2, 0.6),  # Purple
		"icon": "👁️",
		"health": 30,
		"hero_power": "???",
		"hero_power_desc": "Do something unexpected."
	},
	{
		"id": "ace",
		"name": "The Ace",
		"description": "Balance and mastery. The Ace excels at everything but specializes in nothing. A versatile class for players who adapt to any situation.",
		"color": Color(0.9, 0.75, 0.3),  # Gold
		"icon": "⭐",
		"health": 30,
		"hero_power": "Adapt",
		"hero_power_desc": "Choose a bonus for this turn."
	}
]

## Currently selected class index
var selected_index: int = -1

## UI References
var class_buttons: Array[Control] = []
var description_label: RichTextLabel
var select_button: Button
var back_button: Button
var title_label: Label
var class_container: Control

## Reference resolution
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
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
	# Main container
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Choose Your Class"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(title_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer1)
	
	# Class buttons container (horizontal)
	class_container = HBoxContainer.new()
	class_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	class_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(class_container)
	
	# Create class buttons
	for i in range(classes.size()):
		var class_data: Dictionary = classes[i]
		var class_button = _create_class_button(class_data, i)
		class_container.add_child(class_button)
		class_buttons.append(class_button)
	
	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(800, 120)
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
	description_label.add_theme_font_size_override("normal_font_size", 16)
	description_label.text = "[center]Select a class to see its description[/center]"
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
	select_button.text = "Select Class"
	select_button.custom_minimum_size = Vector2(200, 50)
	select_button.disabled = true
	button_hbox.add_child(select_button)
	
	# Bottom spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(spacer3)
	
	_apply_responsive_fonts()


func _create_class_button(class_data: Dictionary, index: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(content_vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = class_data["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	content_vbox.add_child(icon_label)
	
	# Class name
	var name_label = Label.new()
	name_label.text = class_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", class_data["color"])
	content_vbox.add_child(name_label)
	
	# Hero power
	var power_label = Label.new()
	power_label.text = class_data["hero_power"]
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_font_size_override("font_size", 12)
	power_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	content_vbox.add_child(power_label)
	
	# Health indicator
	var health_label = Label.new()
	health_label.text = "❤️ %d HP" % class_data["health"]
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 14)
	health_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	content_vbox.add_child(health_label)
	
	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	
	# Make clickable
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_class_button_input.bind(index))
	panel.mouse_entered.connect(_on_class_button_hover.bind(index))
	
	return panel


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)


func _apply_styling() -> void:
	# Style buttons
	_style_button(back_button)
	_style_button(select_button)


func _apply_responsive_fonts() -> void:
	var scale_factor = get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale_factor))
	
	if description_label:
		description_label.add_theme_font_size_override("normal_font_size", int(16 * scale_factor))
	
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


func _on_class_button_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_class(index)


func _on_class_button_hover(index: int) -> void:
	_update_description(index)


func _select_class(index: int) -> void:
	# Deselect previous
	if selected_index >= 0 and selected_index < class_buttons.size():
		_set_button_selected(class_buttons[selected_index], false, classes[selected_index]["color"])
	
	# Select new
	selected_index = index
	_set_button_selected(class_buttons[index], true, classes[index]["color"])
	_update_description(index)
	
	# Enable select button
	if select_button:
		select_button.disabled = false


func _set_button_selected(button: Control, selected: bool, class_color: Color) -> void:
	var style = StyleBoxFlat.new()
	if selected:
		style.bg_color = class_color.darkened(0.6)
		style.border_color = class_color
		style.set_border_width_all(3)
	else:
		style.bg_color = Color(0.15, 0.15, 0.18)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("panel", style)


func _update_description(index: int) -> void:
	if index < 0 or index >= classes.size():
		return
	
	var class_data: Dictionary = classes[index]
	var color_hex = class_data["color"].to_html(false)
	
	var text = "[center][color=#%s][b]%s[/b][/color]\n\n%s\n\n[color=#888888]Hero Power: [/color][color=#%s]%s[/color] - %s[/center]" % [
		color_hex,
		class_data["name"],
		class_data["description"],
		color_hex,
		class_data["hero_power"],
		class_data["hero_power_desc"]
	]
	
	if description_label:
		description_label.text = text


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_select_pressed() -> void:
	if selected_index < 0 or selected_index >= classes.size():
		return
	
	var selected_class: Dictionary = classes[selected_index]
	print("[ClassSelection] Selected class: %s" % selected_class["name"])
	
	# Store selected class in GameManager (autoload persists between scenes)
	GameManager.set_meta("selected_class", selected_class)
	
	# Use proper scene transition
	get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
