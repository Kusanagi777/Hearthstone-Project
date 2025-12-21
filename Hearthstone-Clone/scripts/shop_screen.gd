# res://scripts/shop_screen.gd
extends Control

## Signals
signal purchase_made(item_type: String, item_data: Dictionary)

## Scene references
@export var card_ui_scene: PackedScene

## UI References
@export var booster_container: HBoxContainer
@export var singles_container: HBoxContainer
@export var gold_label: Label
@export var back_button: Button
@export var title_label: Label

## Booster pack definitions
var booster_types: Array[Dictionary] = [
	{
		"id": "basic_pack",
		"name": "Basic Pack",
		"description": "Contains 3 random cards",
		"card_count": 3,
		"price": 50,
		"color": Color(0.4, 0.5, 0.6),
		"icon": "📦",
		"guaranteed_rare": false
	},
	{
		"id": "premium_pack",
		"name": "Premium Pack",
		"description": "Contains 5 cards with 1 guaranteed rare",
		"card_count": 5,
		"price": 100,
		"color": Color(0.3, 0.5, 0.8),
		"icon": "💎",
		"guaranteed_rare": true
	},
	{
		"id": "mega_pack",
		"name": "Mega Pack",
		"description": "Contains 8 cards with 2 guaranteed rares",
		"card_count": 8,
		"price": 175,
		"color": Color(0.6, 0.3, 0.7),
		"icon": "🎁",
		"guaranteed_rare": true,
		"rare_count": 2
	},
	{
		"id": "class_pack",
		"name": "Class Pack",
		"description": "Contains 5 cards for your class",
		"card_count": 5,
		"price": 120,
		"color": Color(0.8, 0.6, 0.2),
		"icon": "⭐",
		"class_specific": true
	},
	{
		"id": "legendary_pack",
		"name": "Legendary Pack",
		"description": "Contains 3 cards with 1 guaranteed legendary",
		"card_count": 3,
		"price": 250,
		"color": Color(1.0, 0.7, 0.2),
		"icon": "👑",
		"guaranteed_legendary": true
	}
]

## Card pool path
const CARDS_PATH = "res://data/Cards/"

## All available cards
var _all_cards: Array[CardData] = []

## Currently displayed boosters
var _current_boosters: Array[Dictionary] = []

## Currently displayed singles
var _current_singles: Array[CardData] = []

## Player's gold (would normally come from a save system)
var player_gold: int = 200

## Reference resolution
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	_load_card_database()
	_setup_ui()
	_connect_signals()
	_apply_styling()
	_generate_shop_inventory()
	_update_gold_display()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _load_card_database() -> void:
	var dir = DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var card_path = CARDS_PATH + file_name
				var card_data = load(card_path) as CardData
				if card_data:
					_all_cards.append(card_data)
			file_name = dir.get_next()
	else:
		push_error("Could not open cards directory: " + CARDS_PATH)
	
	print("[Shop] Loaded %d cards" % _all_cards.size())


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)
	add_child(bg)
	
	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)
	
	# Header row (title + gold)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)
	
	# Title
	title_label = Label.new()
	title_label.text = "🏪 Card Shop"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	# Gold display
	var gold_panel = PanelContainer.new()
	gold_panel.custom_minimum_size = Vector2(150, 40)
	header.add_child(gold_panel)
	
	gold_label = Label.new()
	gold_label.text = "💰 0"
	gold_label.add_theme_font_size_override("font_size", 20)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_panel.add_child(gold_label)
	
	_style_panel(gold_panel, Color(0.2, 0.18, 0.12, 0.9))
	
	# Booster Packs Section
	var booster_section = VBoxContainer.new()
	booster_section.add_theme_constant_override("separation", 15)
	main_vbox.add_child(booster_section)
	
	var booster_title = Label.new()
	booster_title.text = "Booster Packs"
	booster_title.add_theme_font_size_override("font_size", 24)
	booster_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	booster_section.add_child(booster_title)
	
	booster_container = HBoxContainer.new()
	booster_container.add_theme_constant_override("separation", 30)
	booster_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	booster_section.add_child(booster_container)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer)
	
	# Singles Section
	var singles_section = VBoxContainer.new()
	singles_section.add_theme_constant_override("separation", 15)
	main_vbox.add_child(singles_section)
	
	var singles_title = Label.new()
	singles_title.text = "Individual Cards"
	singles_title.add_theme_font_size_override("font_size", 20)
	singles_title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	singles_section.add_child(singles_title)
	
	singles_container = HBoxContainer.new()
	singles_container.add_theme_constant_override("separation", 20)
	singles_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	singles_section.add_child(singles_container)
	
	# Bottom spacer
	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(bottom_spacer)
	
	# Bottom buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 20)
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(button_row)
	
	var refresh_button = Button.new()
	refresh_button.text = "🔄 Refresh Shop (Free)"
	refresh_button.custom_minimum_size = Vector2(180, 45)
	refresh_button.pressed.connect(_on_refresh_pressed)
	button_row.add_child(refresh_button)
	_style_button(refresh_button)
	
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(120, 45)
	button_row.add_child(back_button)
	_style_button(back_button)
	
	_apply_responsive_fonts()


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _apply_styling() -> void:
	pass  # Styling applied during setup


func _apply_responsive_fonts() -> void:
	var scale_factor = get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale_factor))
	if gold_label:
		gold_label.add_theme_font_size_override("font_size", int(20 * scale_factor))


func _generate_shop_inventory() -> void:
	_generate_boosters()
	_generate_singles()


func _generate_boosters() -> void:
	# Clear existing
	for child in booster_container.get_children():
		child.queue_free()
	
	_current_boosters.clear()
	
	# Pick 3 random booster types
	var available = booster_types.duplicate()
	available.shuffle()
	
	for i in range(mini(3, available.size())):
		var booster = available[i]
		_current_boosters.append(booster)
		_create_booster_ui(booster, i)


func _create_booster_ui(booster: Dictionary, index: int) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)
	booster_container.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = booster["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = booster["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", booster["color"])
	vbox.add_child(name_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = booster["description"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Price
	var price_label = Label.new()
	price_label.text = "💰 %d" % booster["price"]
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(price_label)
	
	# Buy button
	var buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(100, 35)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.pressed.connect(_on_booster_purchased.bind(index))
	vbox.add_child(buy_button)
	_style_button(buy_button)
	
	# Update button state
	if player_gold < booster["price"]:
		buy_button.disabled = true
	
	# Style panel
	_style_panel(panel, booster["color"].darkened(0.7))


func _generate_singles() -> void:
	# Clear existing
	for child in singles_container.get_children():
		child.queue_free()
	
	_current_singles.clear()
	
	if _all_cards.is_empty():
		return
	
	# Pick 3 random cards
	var shuffled = _all_cards.duplicate()
	shuffled.shuffle()
	
	for i in range(mini(3, shuffled.size())):
		var card = shuffled[i]
		_current_singles.append(card)
		_create_single_card_ui(card, i)


func _create_single_card_ui(card: CardData, index: int) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 220)
	singles_container.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Card preview (simplified)
	var card_preview = PanelContainer.new()
	card_preview.custom_minimum_size = Vector2(100, 80)
	card_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(card_preview)
	
	var preview_vbox = VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 2)
	card_preview.add_child(preview_vbox)
	
	# Cost badge
	var cost_label = Label.new()
	cost_label.text = "💧%d" % card.cost
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	preview_vbox.add_child(cost_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "⚔️%d  ❤️%d" % [card.attack, card.health]
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	preview_vbox.add_child(stats_label)
	
	_style_panel(card_preview, Color(0.2, 0.2, 0.25))
	
	# Card name
	var name_label = Label.new()
	name_label.text = card.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", _get_rarity_color(card.rarity))
	name_label.clip_text = true
	vbox.add_child(name_label)
	
	# Price (based on rarity and stats)
	var price = _calculate_card_price(card)
	
	var price_label = Label.new()
	price_label.text = "💰 %d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(price_label)
	
	# Buy button
	var buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(80, 30)
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.pressed.connect(_on_single_purchased.bind(index, price))
	vbox.add_child(buy_button)
	_style_button(buy_button)
	
	if player_gold < price:
		buy_button.disabled = true
	
	# Style based on rarity
	var rarity_color = _get_rarity_color(card.rarity)
	_style_panel(panel, rarity_color.darkened(0.75))


func _calculate_card_price(card: CardData) -> int:
	var base_price = 10
	
	# Add cost-based pricing
	base_price += card.cost * 5
	
	# Add stat-based pricing
	base_price += (card.attack + card.health) * 2
	
	# Rarity multiplier
	match card.rarity:
		CardData.Rarity.COMMON:
			pass  # No change
		CardData.Rarity.RARE:
			base_price = int(base_price * 1.5)
		CardData.Rarity.EPIC:
			base_price = int(base_price * 2.5)
		CardData.Rarity.LEGENDARY:
			base_price = int(base_price * 4.0)
	
	return base_price


func _get_rarity_color(rarity: CardData.Rarity) -> Color:
	match rarity:
		CardData.Rarity.COMMON:
			return Color(0.7, 0.7, 0.7)
		CardData.Rarity.RARE:
			return Color(0.3, 0.5, 1.0)
		CardData.Rarity.EPIC:
			return Color(0.7, 0.3, 0.9)
		CardData.Rarity.LEGENDARY:
			return Color(1.0, 0.7, 0.2)
		_:
			return Color.WHITE


func _on_booster_purchased(index: int) -> void:
	if index < 0 or index >= _current_boosters.size():
		return
	
	var booster = _current_boosters[index]
	
	if player_gold < booster["price"]:
		print("[Shop] Not enough gold!")
		return
	
	# Deduct gold
	player_gold -= booster["price"]
	_update_gold_display()
	
	# Generate cards from booster
	var cards = _open_booster(booster)
	
	print("[Shop] Purchased %s, received %d cards" % [booster["name"], cards.size()])
	
	# Add cards to player's collection (via GameManager meta)
	_add_cards_to_collection(cards)
	
	# Show reward popup
	_show_booster_rewards(booster["name"], cards)
	
	purchase_made.emit("booster", booster)
	
	# Refresh shop
	_generate_shop_inventory()


func _open_booster(booster: Dictionary) -> Array[CardData]:
	var cards: Array[CardData] = []
	var card_count: int = booster.get("card_count", 3)
	
	if _all_cards.is_empty():
		return cards
	
	# Handle guaranteed rares/legendaries
	var rare_count = booster.get("rare_count", 1) if booster.get("guaranteed_rare", false) else 0
	var legendary_count = 1 if booster.get("guaranteed_legendary", false) else 0
	
	# Get rare cards
	var rare_cards = _all_cards.filter(func(c): return c.rarity == CardData.Rarity.RARE or c.rarity == CardData.Rarity.EPIC)
	var legendary_cards = _all_cards.filter(func(c): return c.rarity == CardData.Rarity.LEGENDARY)
	
	# Add guaranteed legendaries
	for i in range(legendary_count):
		if not legendary_cards.is_empty() and cards.size() < card_count:
			var card = legendary_cards.pick_random()
			cards.append(card.duplicate_for_play())
	
	# Add guaranteed rares
	for i in range(rare_count):
		if not rare_cards.is_empty() and cards.size() < card_count:
			var card = rare_cards.pick_random()
			cards.append(card.duplicate_for_play())
	
	# Fill remaining with random cards
	while cards.size() < card_count:
		var card = _all_cards.pick_random()
		cards.append(card.duplicate_for_play())
	
	return cards


func _on_single_purchased(index: int, price: int) -> void:
	if index < 0 or index >= _current_singles.size():
		return
	
	var card = _current_singles[index]
	
	if player_gold < price:
		print("[Shop] Not enough gold!")
		return
	
	# Deduct gold
	player_gold -= price
	_update_gold_display()
	
	print("[Shop] Purchased single card: %s for %d gold" % [card.card_name, price])
	
	# Add to collection
	_add_cards_to_collection([card])
	
	purchase_made.emit("single", {"card": card, "price": price})
	
	# Refresh singles
	_generate_singles()


func _add_cards_to_collection(cards: Array) -> void:
	# Get or create collection in GameManager
	var collection: Array = []
	if GameManager.has_meta("card_collection"):
		collection = GameManager.get_meta("card_collection")
	
	for card in cards:
		if card is CardData:
			collection.append(card.id if not card.id.is_empty() else card.card_name.to_lower())
	
	GameManager.set_meta("card_collection", collection)
	print("[Shop] Collection now has %d cards" % collection.size())


func _show_booster_rewards(booster_name: String, cards: Array[CardData]) -> void:
	# Create a popup to show rewards
	var popup = PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(500, 350)
	popup.z_index = 100
	add_child(popup)
	
	_style_panel(popup, Color(0.12, 0.12, 0.15, 0.98))
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🎉 %s Opened!" % booster_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(title)
	
	# Cards container
	var cards_hbox = HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	cards_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(cards_hbox)
	
	for card in cards:
		var card_panel = PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(80, 100)
		cards_hbox.add_child(card_panel)
		
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card_panel.add_child(card_vbox)
		
		var card_name = Label.new()
		card_name.text = card.card_name
		card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_name.add_theme_font_size_override("font_size", 10)
		card_name.add_theme_color_override("font_color", _get_rarity_color(card.rarity))
		card_name.clip_text = true
		card_vbox.add_child(card_name)
		
		var stats = Label.new()
		stats.text = "%d/%d" % [card.attack, card.health]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 14)
		card_vbox.add_child(stats)
		
		var cost = Label.new()
		cost.text = "💧%d" % card.cost
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost.add_theme_font_size_override("font_size", 11)
		cost.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		card_vbox.add_child(cost)
		
		_style_panel(card_panel, _get_rarity_color(card.rarity).darkened(0.7))
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Awesome!"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_button)
	_style_button(close_button)
	
	# Center the popup
	await get_tree().process_frame
	popup.position = (get_viewport_rect().size - popup.size) / 2


func _update_gold_display() -> void:
	if gold_label:
		gold_label.text = "💰 %d" % player_gold
	
	# Update all buy buttons
	_refresh_button_states()


func _refresh_button_states() -> void:
	# Refresh booster buttons
	for i in range(booster_container.get_child_count()):
		var panel = booster_container.get_child(i)
		if i < _current_boosters.size():
			var booster = _current_boosters[i]
			var buy_button = _find_buy_button(panel)
			if buy_button:
				buy_button.disabled = player_gold < booster["price"]
	
	# Refresh single card buttons
	for i in range(singles_container.get_child_count()):
		var panel = singles_container.get_child(i)
		if i < _current_singles.size():
			var price = _calculate_card_price(_current_singles[i])
			var buy_button = _find_buy_button(panel)
			if buy_button:
				buy_button.disabled = player_gold < price


func _find_buy_button(node: Node) -> Button:
	if node is Button and node.text == "Buy":
		return node
	for child in node.get_children():
		var result = _find_buy_button(child)
		if result:
			return result
	return null


func _on_refresh_pressed() -> void:
	_generate_shop_inventory()
	print("[Shop] Shop inventory refreshed")


func _on_back_pressed() -> void:
	# Return to previous scene (could be main menu or map)
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _style_panel(panel: PanelContainer, bg_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = bg_color.lightened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)


func _style_button(button: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.3, 0.4)
	normal_style.border_color = Color(0.5, 0.5, 0.6)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.35, 0.4, 0.5)
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.25, 0.35)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.25, 0.25, 0.3)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_G:
			# Debug: Add gold
			player_gold += 100
			_update_gold_display()
			print("[Shop] DEBUG: Added 100 gold")
