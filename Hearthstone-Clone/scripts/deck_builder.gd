# res://scripts/deck_builder.gd
extends Control

## Path to card resources
const CARDS_PATH := "res://data/cards/"

## Card UI scene for tooltips
var card_ui_scene: PackedScene = preload("res://scenes/card_ui.tscn")

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0

## Grid settings
const CARDS_PER_ROW := 4
const CARD_SCALE := 0.7

## All available card resources (for lookup)
var _all_cards: Dictionary = {}

## Unique cards list (no duplicates from ID/name mapping)
var _unique_cards: Array[CardData] = []

## Current deck being displayed (card IDs)
var current_deck: Array = []

## UI References - Header
var title_label: Label
var deck_count_label: Label
var back_button: Button
var class_label: Label

## UI References - Deck Panel (Left)
var deck_panel: PanelContainer
var deck_grid: GridContainer
var deck_scroll: ScrollContainer

## UI References - Collection Panel (Right)
var collection_panel: PanelContainer
var collection_list: VBoxContainer
var collection_scroll: ScrollContainer
var collection_title: Label

## Tooltip card preview
var tooltip_popup: PanelContainer
var tooltip_card_instance: Control

## Selected class info
var selected_class: Dictionary = {}


func _ready() -> void:
	# Get selected class and deck from GameManager
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
	
	if GameManager.has_meta("selected_deck"):
		var deck_data: Dictionary = GameManager.get_meta("selected_deck")
		if deck_data.has("cards"):
			current_deck = deck_data["cards"]
	
	_load_all_cards()
	_setup_ui()
	_setup_tooltip()
	_populate_deck_grid()
	_populate_collection_list()
	_apply_styling()
	
	# Connect viewport resize
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _load_all_cards() -> void:
	var seen_ids: Dictionary = {}
	var dir := DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var card_path := CARDS_PATH + file_name
				var card_data := load(card_path) as CardData
				if card_data:
					var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
					_all_cards[card_id] = card_data
					_all_cards[card_data.card_name.to_lower()] = card_data
					# Track unique cards
					if not seen_ids.has(card_id):
						seen_ids[card_id] = true
						_unique_cards.append(card_data)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("[DeckBuilder] Could not access cards path: %s" % CARDS_PATH)
	
	# Sort unique cards by cost then name
	_unique_cards.sort_custom(func(a, b): 
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.card_name < b.card_name
	)


func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	var height_scale := viewport_size.y / REFERENCE_HEIGHT
	return clampf(height_scale, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _setup_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12)
	add_child(bg)
	
	# Main margin container
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	# Main vertical layout
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	# === HEADER SECTION ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(90, 36)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	
	# Title
	title_label = Label.new()
	title_label.text = "Deck Builder"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	header.add_child(title_label)
	
	# Deck count
	deck_count_label = Label.new()
	deck_count_label.custom_minimum_size = Vector2(90, 0)
	deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deck_count_label.add_theme_font_size_override("font_size", 16)
	deck_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	header.add_child(deck_count_label)
	
	# Class indicator
	class_label = Label.new()
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 14)
	if selected_class.has("color"):
		class_label.add_theme_color_override("font_color", selected_class["color"])
	else:
		class_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	class_label.text = "Playing as: %s" % selected_class.get("name", "Unknown")
	main_vbox.add_child(class_label)
	
	# === CONTENT SECTION (Two columns) ===
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(content_hbox)
	
	# === LEFT PANEL: Current Deck ===
	_setup_deck_panel(content_hbox)
	
	# === RIGHT PANEL: Collection ===
	_setup_collection_panel(content_hbox)


func _setup_deck_panel(parent: Control) -> void:
	deck_panel = PanelContainer.new()
	deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_stretch_ratio = 2.0  # Takes 2/3 of space
	parent.add_child(deck_panel)
	
	var deck_vbox := VBoxContainer.new()
	deck_vbox.add_theme_constant_override("separation", 10)
	deck_panel.add_child(deck_vbox)
	
	# Deck panel title
	var deck_title := Label.new()
	deck_title.text = "Current Deck"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 18)
	deck_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	deck_vbox.add_child(deck_title)
	
	# Separator
	var sep := HSeparator.new()
	deck_vbox.add_child(sep)
	
	# Scroll container for deck grid
	deck_scroll = ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_vbox.add_child(deck_scroll)
	
	# Center the grid
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.add_child(center)
	
	# Grid for cards
	deck_grid = GridContainer.new()
	deck_grid.columns = CARDS_PER_ROW
	deck_grid.add_theme_constant_override("h_separation", 12)
	deck_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(deck_grid)


func _setup_collection_panel(parent: Control) -> void:
	collection_panel = PanelContainer.new()
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_stretch_ratio = 1.0  # Takes 1/3 of space
	collection_panel.custom_minimum_size.x = 250
	parent.add_child(collection_panel)
	
	var coll_vbox := VBoxContainer.new()
	coll_vbox.add_theme_constant_override("separation", 10)
	collection_panel.add_child(coll_vbox)
	
	# Collection panel title
	collection_title = Label.new()
	collection_title.text = "Collection"
	collection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_title.add_theme_font_size_override("font_size", 18)
	collection_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.7))
	coll_vbox.add_child(collection_title)
	
	# Separator
	var sep := HSeparator.new()
	coll_vbox.add_child(sep)
	
	# Scroll container for collection list
	collection_scroll = ScrollContainer.new()
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coll_vbox.add_child(collection_scroll)
	
	# VBox for card entries
	collection_list = VBoxContainer.new()
	collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_list.add_theme_constant_override("separation", 4)
	collection_scroll.add_child(collection_list)


func _setup_tooltip() -> void:
	# Create tooltip popup (card preview on hover)
	tooltip_popup = PanelContainer.new()
	tooltip_popup.visible = false
	tooltip_popup.z_index = 100
	tooltip_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip_popup)
	
	# Style the tooltip panel
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	tooltip_style.border_color = Color(0.5, 0.45, 0.3)
	tooltip_style.set_border_width_all(2)
	tooltip_style.set_corner_radius_all(8)
	tooltip_style.set_content_margin_all(8)
	tooltip_popup.add_theme_stylebox_override("panel", tooltip_style)


func _populate_deck_grid() -> void:
	# Clear existing cards
	for child in deck_grid.get_children():
		child.queue_free()
	
	# Update deck count
	deck_count_label.text = "%d cards" % current_deck.size()
	
	# Show empty message if no deck
	if current_deck.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in deck"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		deck_grid.add_child(empty_label)
		return
	
	# Count card occurrences
	var card_counts: Dictionary = {}
	for card_id in current_deck:
		var lookup_id: String = str(card_id).to_lower()
		if card_counts.has(lookup_id):
			card_counts[lookup_id] += 1
		else:
			card_counts[lookup_id] = 1
	
	# Sort cards by mana cost
	var sorted_ids: Array = card_counts.keys()
	sorted_ids.sort_custom(_sort_by_mana_cost)
	
	# Create card displays
	for card_id in sorted_ids:
		var card_data: CardData = _all_cards.get(card_id)
		if not card_data:
			push_warning("[DeckBuilder] Card not found: %s" % card_id)
			continue
		
		var card_container := _create_deck_card_display(card_data, card_counts[card_id])
		deck_grid.add_child(card_container)


func _populate_collection_list() -> void:
	# Clear existing entries
	for child in collection_list.get_children():
		child.queue_free()
	
	# Count cards in deck
	var deck_counts: Dictionary = {}
	for card_id in current_deck:
		var lookup_id: String = str(card_id).to_lower()
		if deck_counts.has(lookup_id):
			deck_counts[lookup_id] += 1
		else:
			deck_counts[lookup_id] = 1
	
	# Create entries for cards not in deck (or not at max copies)
	var has_available := false
	for card_data in _unique_cards:
		var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
		var in_deck: int = deck_counts.get(card_id, 0)
		
		# For now, show all cards - you can filter based on ownership later
		# Cards already at 2 copies are shown dimmed
		var card_entry := _create_collection_entry(card_data, in_deck)
		collection_list.add_child(card_entry)
		has_available = true
	
	if not has_available:
		var empty_label := Label.new()
		empty_label.text = "No cards available"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		collection_list.add_child(empty_label)


func _sort_by_mana_cost(a: String, b: String) -> bool:
	var card_a: CardData = _all_cards.get(a)
	var card_b: CardData = _all_cards.get(b)
	
	if not card_a or not card_b:
		return a < b
	
	if card_a.cost != card_b.cost:
		return card_a.cost < card_b.cost
	
	return card_a.card_name < card_b.card_name


func _create_deck_card_display(card_data: CardData, count: int) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	
	# Card UI instance
	if card_ui_scene:
		var card_instance = card_ui_scene.instantiate()
		container.add_child(card_instance)
		
		card_instance.initialize(card_data, 0)
		card_instance.set_interactable(false)
		card_instance.scale = Vector2(CARD_SCALE, CARD_SCALE)
		card_instance.custom_minimum_size = Vector2(120, 170) * CARD_SCALE
	
	# Count label
	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	
	if count >= 2:
		count_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	else:
		count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	
	container.add_child(count_label)
	
	return container


func _create_collection_entry(card_data: CardData, copies_in_deck: int) -> Control:
	var entry := PanelContainer.new()
	entry.custom_minimum_size = Vector2(0, 36)
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store card data for tooltip
	entry.set_meta("card_data", card_data)
	entry.set_meta("copies_in_deck", copies_in_deck)
	
	# Connect hover signals
	entry.mouse_entered.connect(_on_collection_entry_hover.bind(entry, card_data))
	entry.mouse_exited.connect(_on_collection_entry_exit)
	
	# Style based on copies in deck
	var is_maxed := copies_in_deck >= 2
	var style := StyleBoxFlat.new()
	if is_maxed:
		style.bg_color = Color(0.12, 0.12, 0.15)
		style.border_color = Color(0.25, 0.25, 0.3)
	else:
		style.bg_color = Color(0.15, 0.18, 0.25)
		style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	entry.add_theme_stylebox_override("panel", style)
	
	# Content HBox
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	entry.add_child(hbox)
	
	# Mana cost gem
	var mana_container := PanelContainer.new()
	mana_container.custom_minimum_size = Vector2(28, 28)
	var mana_style := StyleBoxFlat.new()
	mana_style.bg_color = Color(0.1, 0.3, 0.6)
	mana_style.set_corner_radius_all(14)
	mana_container.add_theme_stylebox_override("panel", mana_style)
	hbox.add_child(mana_container)
	
	var mana_label := Label.new()
	mana_label.text = str(card_data.cost)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_label.add_theme_font_size_override("font_size", 14)
	mana_label.add_theme_color_override("font_color", Color.WHITE)
	mana_container.add_child(mana_label)
	
	# Card name
	var name_label := Label.new()
	name_label.text = card_data.card_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	if is_maxed:
		name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	name_label.clip_text = true
	hbox.add_child(name_label)
	
	# Copies indicator
	if copies_in_deck > 0:
		var copies_label := Label.new()
		copies_label.text = "(%d)" % copies_in_deck
		copies_label.add_theme_font_size_override("font_size", 12)
		copies_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4))
		hbox.add_child(copies_label)
	
	return entry


func _on_collection_entry_hover(entry: Control, card_data: CardData) -> void:
	# Remove old tooltip card if exists
	if tooltip_card_instance and is_instance_valid(tooltip_card_instance):
		tooltip_card_instance.queue_free()
		tooltip_card_instance = null
	
	# Create new card preview
	if card_ui_scene:
		tooltip_card_instance = card_ui_scene.instantiate()
		tooltip_popup.add_child(tooltip_card_instance)
		tooltip_card_instance.initialize(card_data, 0)
		tooltip_card_instance.set_interactable(false)
	
	# Position tooltip to the left of the collection panel
	var entry_rect := entry.get_global_rect()
	var tooltip_size := Vector2(130, 185)  # Approximate card size
	
	# Position to the left of the entry
	var tooltip_x := entry_rect.position.x - tooltip_size.x - 15
	var tooltip_y := entry_rect.position.y - 30
	
	# Keep on screen
	tooltip_y = clampf(tooltip_y, 10, get_viewport_rect().size.y - tooltip_size.y - 10)
	if tooltip_x < 10:
		# If not enough space on left, show on right
		tooltip_x = entry_rect.position.x + entry_rect.size.x + 15
	
	tooltip_popup.global_position = Vector2(tooltip_x, tooltip_y)
	tooltip_popup.visible = true


func _on_collection_entry_exit() -> void:
	tooltip_popup.visible = false


func _apply_styling() -> void:
	_style_button(back_button)
	_style_panel(deck_panel, Color(0.1, 0.12, 0.16))
	_style_panel(collection_panel, Color(0.08, 0.1, 0.14))
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale_factor := get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(28 * scale_factor))
	
	if deck_count_label:
		deck_count_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	
	if class_label:
		class_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	
	if back_button:
		back_button.add_theme_font_size_override("font_size", int(14 * scale_factor))


func _style_button(button: Button) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.25, 0.35)
	normal_style.border_color = Color(0.5, 0.45, 0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.35, 0.45)
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.2, 0.3)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))


func _style_panel(panel: PanelContainer, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.3, 0.28, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)


func _on_back_pressed() -> void:
	var return_scene: String = GameManager.get_meta("deck_builder_return_scene") if GameManager.has_meta("deck_builder_return_scene") else "res://scenes/start_screen.tscn"
	get_tree().change_scene_to_file(return_scene)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			_on_back_pressed()
