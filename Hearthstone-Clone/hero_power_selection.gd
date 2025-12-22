# res://scripts/hero_power_selection.gd
extends Control

## The selected class data (retrieved from GameManager)
var selected_class: Dictionary = {}
## The selected deck data (retrieved from GameManager)
var selected_deck: Dictionary = {}

## Database of Hero Powers for each class
## In a full production game, these might be separate Resources
var hero_power_database: Dictionary = {
	"brute": [
		{"name": "Iron Hide", "cost": 2, "description": "Gain 2 Armor.", "id": "armor_up"},
		{"name": "Reckless Strike", "cost": 2, "description": "Deal 1 damage to all minions.", "id": "whirlwind"},
		{"name": "Battle Shout", "cost": 2, "description": "Give a friendly minion +2 Attack this turn.", "id": "shout"}
	],
	"technical": [
		{"name": "Zap", "cost": 2, "description": "Deal 1 damage to any target.", "id": "fireblast"},
		{"name": "Research", "cost": 2, "description": "Look at the top card of your deck.", "id": "scry"},
		{"name": "Mana Surge", "cost": 1, "description": "Reduce the cost of a random spell in hand by (1).", "id": "reduce"}
	],
	"cute": [
		{"name": "Recruit Friend", "cost": 2, "description": "Summon a 1/1 Tiny Pal.", "id": "recruit"},
		{"name": "Group Hug", "cost": 2, "description": "Restore 2 Health to your Hero.", "id": "heal"},
		{"name": "Snack Time", "cost": 2, "description": "Give a minion +1 Health.", "id": "buff_hp"}
	],
	# Fallback generic powers if class ID doesn't match
	"default": [
		{"name": "Minor Heal", "cost": 2, "description": "Restore 2 Health to any target.", "id": "generic_heal"},
		{"name": "Dagger Mastery", "cost": 2, "description": "Equip a 1/2 Dagger.", "id": "equip_dagger"},
		{"name": "Life Tap", "cost": 2, "description": "Draw a card and take 2 damage.", "id": "tap"}
	]
}

## UI References
var power_container: HBoxContainer
var confirm_button: Button
var back_button: Button
var description_label: Label
var title_label: Label
var power_buttons: Array[Button] = []

## State
var selected_power_index: int = -1
var current_power_options: Array = []

func _ready() -> void:
	# Retrieve data passed from previous screens
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
	
	if GameManager.has_meta("selected_deck"):
		selected_deck = GameManager.get_meta("selected_deck")
	
	_setup_ui()
	_load_power_options()
	_update_ui_state()

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
	
	# 4. Hero Power Button Container
	power_container = HBoxContainer.new()
	power_container.alignment = BoxContainer.ALIGNMENT_CENTER
	power_container.add_theme_constant_override("separation", 40)
	power_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(power_container)
	
	# 5. Bottom Navigation Bar
	var nav_hbox = HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 50)
	main_vbox.add_child(nav_hbox)
	
	back_button = _create_nav_button("Back to Decks")
	back_button.pressed.connect(_on_back_pressed)
	nav_hbox.add_child(back_button)
	
	confirm_button = _create_nav_button("Start Game")
	confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_button.disabled = true # Start disabled until selection made
	nav_hbox.add_child(confirm_button)

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
	btn.custom_minimum_size = Vector2(220, 300)
	btn.toggle_mode = true
	
	# Visuals handled by internal VBox
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let button handle input
	vbox.add_theme_constant_override("separation", 15)
	
	# Inner Margin
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_child(vbox)
	btn.add_child(margin)
	
	# -- Card Content --
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_lbl)
	
	# Cost Coin
	var cost_lbl = Label.new()
	cost_lbl.text = "(%d Mana)" % data["cost"]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	vbox.add_child(cost_lbl)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = data["description"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size.y = 80
	vbox.add_child(desc_lbl)
	
	# Style the button manually for standard/hover/pressed states
	_style_power_button(btn, false)
	
	# Connect click signal
	btn.pressed.connect(_on_power_clicked.bind(index))
	
	return btn

func _style_power_button(btn: Button, is_selected: bool) -> void:
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	
	if is_selected:
		style.bg_color = Color(0.3, 0.35, 0.4)
		style.border_color = Color(1, 0.8, 0.2) # Gold border for selected
		style.set_border_width_all(4)
	else:
		style.bg_color = Color(0.2, 0.2, 0.25)
		style.border_color = Color(0.4, 0.4, 0.45)
		
	# Apply to all relevant states for simplicity in this example
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)

func _create_nav_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 50)
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

func _on_back_pressed() -> void:
	# Go back to deck selection
	get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")

func _on_confirm_pressed() -> void:
	if selected_power_index == -1:
		return
		
	var chosen_power = current_power_options[selected_power_index]
	print("[HeroPowerSelect] Chosen: %s" % chosen_power["name"])
	
	# Store in GameManager
	GameManager.set_meta("selected_hero_power", chosen_power)
	
	# Start Game
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
