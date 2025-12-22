# res://scripts/shop_screen.gd
extends Control

## Shop screen where players can buy cards and upgrades
## Accessed during the weekly schedule

const REFERENCE_HEIGHT: float = 720.0

## Shop inventory categories
enum ShopTab { CARDS, UPGRADES, PACKS }

## Current player gold (loaded from GameManager)
var player_gold: int = 0

## Currently selected tab
var current_tab: ShopTab = ShopTab.CARDS

## Shop items - cards available for purchase
var card_shop_items: Array[Dictionary] = []

## Shop items - upgrades available for purchase  
var upgrade_shop_items: Array[Dictionary] = [
	{
		"id": "max_hand_size",
		"name": "Bigger Hands",
		"description": "Increase max hand size by 1",
		"cost": 200,
		"icon": "✋"
	},
	{
		"id": "starting_mana",
		"name": "Mana Crystal",
		"description": "Start battles with +1 mana",
		"cost": 300,
		"icon": "💎"
	},
	{
		"id": "card_draw",
		"name": "Card Draw",
		"description": "Draw +1 card at start of battle",
		"cost": 250,
		"icon": "🃏"
	}
]

## Pack items
var pack_shop_items: Array[Dictionary] = [
	{
		"id": "basic_pack",
		"name": "Basic Pack",
		"description": "Contains 3 random cards",
		"cost": 100,
		"icon": "📦"
	},
	{
		"id": "rare_pack",
		"name": "Rare Pack",
		"description": "Contains 3 cards (1 guaranteed rare)",
		"cost": 200,
		"icon": "🎁"
	}
]

## UI References
var title_label: Label
var gold_label: Label
var tab_container: HBoxContainer
var items_container: GridContainer
var description_label: RichTextLabel
var back_button: Button
var buy_button: Button

## Currently selected item
var selected_item: Dictionary = {}
var selected_item_panel: PanelContainer = null


func _ready() -> void:
	# Load player gold
	if GameManager.has_meta("player_gold"):
		player_gold = GameManager.get_meta("player_gold")
	else:
		player_gold = 200
		GameManager.set_meta("player_gold", player_gold)
	
	# Load cards from the database
	_load_card_database()
	
	_setup_ui()
	_apply_styling()
	_populate_items()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("[ShopScreen] Opened with %d gold" % player_gold)


func _load_card_database() -> void:
	## Load cards from res://data/cards/ directory
	var cards_dir := "res://data/cards/"
	var dir := DirAccess.open(cards_dir)
	
	if dir == null:
		print("[ShopScreen] Warning: Could not open cards directory, using fallback cards")
		_generate_fallback_cards()
		return
	
	var all_cards: Array[Dictionary] = []
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card_path := cards_dir + file_name
			var card_resource = load(card_path)
			
			if card_resource and card_resource is CardData:
				var card_data: CardData = card_resource
				
				# Determine price based on stats and rarity
				var base_price := (card_data.cost * 15) + (card_data.attack * 10) + (card_data.health * 8)
				
				# Adjust for rarity
				match card_data.rarity:
					CardData.Rarity.RARE:
						base_price = int(base_price * 1.5)
					CardData.Rarity.EPIC:
						base_price = int(base_price * 2.0)
					CardData.Rarity.LEGENDARY:
						base_price = int(base_price * 3.0)
				
				# Minimum price
				base_price = maxi(base_price, 30)
				
				# Determine icon based on card type
				var icon := "🃏"
				match card_data.card_type:
					CardData.CardType.MINION:
						icon = "👤"
					CardData.CardType.ACTION:
						icon = "✨"
					CardData.CardType.LOCATION:
						icon = "⚔️"
				
				all_cards.append({
					"card_data": card_data,
					"name": card_data.card_name,
					"cost": card_data.cost,
					"attack": card_data.attack,
					"health": card_data.health,
					"price": base_price,
					"icon": icon,
					"description": card_data.description if card_data.description != "" else "A %s card." % card_data.card_name,
					"is_spell": card_data.card_type == CardData.CardType.ACTION
				})
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if all_cards.is_empty():
		print("[ShopScreen] No cards found in database, using fallback")
		_generate_fallback_cards()
		return
	
	# Shuffle and pick up to 6 random cards for the shop
	all_cards.shuffle()
	for i in range(mini(6, all_cards.size())):
		card_shop_items.append(all_cards[i])
	
	print("[ShopScreen] Loaded %d cards for shop" % card_shop_items.size())


func _generate_fallback_cards() -> void:
	## Fallback cards if database loading fails
	var sample_cards: Array[Dictionary] = [
		{"name": "Flame Imp", "cost": 1, "attack": 3, "health": 2, "price": 50, "icon": "🔥", "description": "A fiery demon."},
		{"name": "Shield Bearer", "cost": 1, "attack": 0, "health": 4, "price": 40, "icon": "🛡️", "description": "Taunt."},
		{"name": "River Croc", "cost": 2, "attack": 2, "health": 3, "price": 60, "icon": "🐊", "description": "A hungry croc."},
		{"name": "Arcane Intellect", "cost": 3, "attack": 0, "health": 0, "price": 80, "icon": "📚", "description": "Draw 2 cards.", "is_spell": true},
		{"name": "Fireball", "cost": 4, "attack": 6, "health": 0, "price": 100, "icon": "☄️", "description": "Deal 6 damage.", "is_spell": true},
		{"name": "Boulderfist Ogre", "cost": 6, "attack": 6, "health": 7, "price": 120, "icon": "👹", "description": "ME SMASH!"},
	]
	
	sample_cards.shuffle()
	for i in range(mini(4, sample_cards.size())):
		card_shop_items.append(sample_cards[i])


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
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	# Header row (title + gold)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "🛒 Shop"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	gold_label = Label.new()
	gold_label.text = "💰 %d Gold" % player_gold
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(gold_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Tab buttons
	tab_container = HBoxContainer.new()
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_container)
	
	_create_tab_button("Cards", ShopTab.CARDS)
	_create_tab_button("Upgrades", ShopTab.UPGRADES)
	_create_tab_button("Packs", ShopTab.PACKS)
	
	# Items grid
	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(items_scroll)
	
	items_container = GridContainer.new()
	items_container.columns = 4
	items_container.add_theme_constant_override("h_separation", 15)
	items_container.add_theme_constant_override("v_separation", 15)
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.add_child(items_container)
	
	# Description area
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.custom_minimum_size = Vector2(0, 60)
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.8))
	main_vbox.add_child(description_label)
	
	# Bottom buttons
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(button_row)
	
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(120, 45)
	back_button.pressed.connect(_on_back_pressed)
	button_row.add_child(back_button)
	
	buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(150, 45)
	buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_pressed)
	button_row.add_child(buy_button)


func _create_tab_button(text: String, tab: ShopTab) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 35)
	btn.toggle_mode = true
	btn.button_pressed = (tab == current_tab)
	btn.pressed.connect(func(): _on_tab_selected(tab))
	tab_container.add_child(btn)


func _on_tab_selected(tab: ShopTab) -> void:
	current_tab = tab
	selected_item = {}
	selected_item_panel = null
	
	# Update tab button states
	var tabs = tab_container.get_children()
	for i in range(tabs.size()):
		if tabs[i] is Button:
			tabs[i].button_pressed = (i == tab)
	
	_populate_items()
	_update_buy_button()


func _populate_items() -> void:
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	var items: Array[Dictionary] = []
	match current_tab:
		ShopTab.CARDS:
			items.assign(card_shop_items)
		ShopTab.UPGRADES:
			items.assign(upgrade_shop_items)
		ShopTab.PACKS:
			items.assign(pack_shop_items)
	
	for item in items:
		var panel = _create_item_panel(item)
		items_container.add_child(panel)


func _create_item_panel(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 180)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25)
	style.border_color = Color(0.4, 0.35, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = item.get("icon", "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(icon_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)
	
	# Mana cost (for cards)
	if current_tab == ShopTab.CARDS:
		var mana_label = Label.new()
		mana_label.text = "🔷 %d" % item.get("cost", 0)
		mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mana_label.add_theme_font_size_override("font_size", 12)
		mana_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		vbox.add_child(mana_label)
		
		# Stats (for minions, not spells)
		if not item.get("is_spell", false):
			var stats_label = Label.new()
			stats_label.text = "⚔️%d / ❤️%d" % [item.get("attack", 0), item.get("health", 0)]
			stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats_label.add_theme_font_size_override("font_size", 12)
			stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			vbox.add_child(stats_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Price
	var price = item.get("price", item.get("cost", 0))
	var price_label = Label.new()
	price_label.text = "💰 %d" % price
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.add_theme_font_size_override("font_size", 16)
	
	if price > player_gold:
		price_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	else:
		price_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	vbox.add_child(price_label)
	
	# Make clickable
	panel.gui_input.connect(func(event): _on_item_clicked(event, panel, item))
	panel.mouse_entered.connect(func(): _on_item_hover(item))
	
	return panel


func _on_item_clicked(event: InputEvent, panel: PanelContainer, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Deselect previous
		if selected_item_panel and is_instance_valid(selected_item_panel):
			var old_style = selected_item_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if old_style:
				old_style.border_color = Color(0.4, 0.35, 0.3)
		
		# Select new
		selected_item = item
		selected_item_panel = panel
		
		var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.border_color = Color(0.9, 0.75, 0.3)
		
		_update_buy_button()
		_show_description(item)


func _on_item_hover(item: Dictionary) -> void:
	if selected_item.is_empty():
		_show_description(item)


func _show_description(item: Dictionary) -> void:
	var desc = item.get("description", "No description available.")
	description_label.text = "[center]%s[/center]" % desc


func _update_buy_button() -> void:
	if selected_item.is_empty():
		buy_button.disabled = true
		buy_button.text = "Buy"
		return
	
	var price = selected_item.get("price", selected_item.get("cost", 0))
	buy_button.text = "Buy (%d 💰)" % price
	buy_button.disabled = (price > player_gold)


func _on_buy_pressed() -> void:
	if selected_item.is_empty():
		return
	
	var price = selected_item.get("price", selected_item.get("cost", 0))
	if price > player_gold:
		return
	
	# Deduct gold
	player_gold -= price
	GameManager.set_meta("player_gold", player_gold)
	gold_label.text = "💰 %d Gold" % player_gold
	
	# Handle the purchase based on type
	var item_name = selected_item.get("name", "item")
	print("[ShopScreen] Purchased: %s for %d gold" % [item_name, price])
	
	# TODO: Add item to player inventory/deck
	# For now, just show feedback
	_show_purchase_feedback(item_name)
	
	# Remove from shop (one-time purchase for cards)
	if current_tab == ShopTab.CARDS:
		card_shop_items.erase(selected_item)
	
	# Reset selection and refresh
	selected_item = {}
	selected_item_panel = null
	_populate_items()
	_update_buy_button()


func _show_purchase_feedback(item_name: String) -> void:
	description_label.text = "[center][color=#55ff55]Purchased %s![/color][/center]" % item_name


func _on_back_pressed() -> void:
	# Check if we should return to week runner and advance the day
	if GameManager.has_meta("return_to_week_runner") and GameManager.get_meta("return_to_week_runner"):
		# Clear the flag
		GameManager.set_meta("return_to_week_runner", false)
		
		# Advance the day
		var current_day: int = GameManager.get_meta("current_day_index") if GameManager.has_meta("current_day_index") else 0
		current_day += 1
		GameManager.set_meta("current_day_index", current_day)
		
		print("[ShopScreen] Returning to week runner, advancing to day %d" % (current_day + 1))
		get_tree().change_scene_to_file("res://scenes/week_runner.tscn")
	else:
		# Return to start screen if not from week runner
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()


## --- Styling ---

func _apply_styling() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35)
	btn_style.border_color = Color(0.5, 0.45, 0.3)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	
	if back_button:
		back_button.add_theme_stylebox_override("normal", btn_style)
	
	if buy_button:
		buy_button.add_theme_stylebox_override("normal", btn_style)
		buy_button.add_theme_stylebox_override("disabled", disabled_style)


func _get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var s = _get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * s))
	if gold_label:
		gold_label.add_theme_font_size_override("font_size", int(24 * s))
