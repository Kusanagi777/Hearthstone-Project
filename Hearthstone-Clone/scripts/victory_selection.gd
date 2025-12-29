# res://scripts/victory_selection.gd
extends Control

## Path to card resources
const CARDS_PATH = "res://data/cards/"

## Scene for card UI display
@export var card_ui_scene: PackedScene

## Container for the 3 buckets
@export var buckets_container: HBoxContainer

## Title label
@export var title_label: Label

## All available cards loaded from resources
var _all_cards: Array[CardData] = []


func _ready() -> void:
	_load_card_database()
	_generate_loot_buckets()
	_apply_styling()


func _apply_styling() -> void:
	# Style the bucket panels
	for child in buckets_container.get_children():
		if child is PanelContainer:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.14, 0.2)
			style.border_color = Color(0.5, 0.45, 0.3)
			style.set_border_width_all(2)
			style.set_corner_radius_all(10)
			style.set_content_margin_all(15)
			child.add_theme_stylebox_override("panel", style)


## Loads all card resources from the cards folder
func _load_card_database() -> void:
	var dir = DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var card_path = CARDS_PATH + file_name
				var card_data = load(card_path) as CardData
				if card_data:
					# Only add non-token cards (check via tags if needed)
					if not card_data.has_keyword("Token"):
						_all_cards.append(card_data)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("[VictorySelection] Could not open cards path: " + CARDS_PATH)
		# Add some fallback cards for testing
		_generate_fallback_cards()
	
	print("[VictorySelection] Loaded %d cards for rewards" % _all_cards.size())


func _generate_fallback_cards() -> void:
	# If no cards loaded, we still need something to show
	# This shouldn't happen in production but helps during development
	print("[VictorySelection] Using fallback card generation")


## Creates 3 buckets, each containing 3 random cards
func _generate_loot_buckets() -> void:
	# Clear existing children if any
	for child in buckets_container.get_children():
		child.queue_free()
	
	for i in range(3):
		_create_bucket_ui(i)


## Creates the UI for a single bucket
func _create_bucket_ui(index: int) -> void:
	var bucket_panel = PanelContainer.new()
	bucket_panel.custom_minimum_size = Vector2(200, 500)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.2)
	style.border_color = Color(0.5, 0.45, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	bucket_panel.add_theme_stylebox_override("panel", style)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	bucket_panel.add_child(content_vbox)
	
	# Bucket title
	var bucket_title = Label.new()
	bucket_title.text = "Bucket %d" % (index + 1)
	bucket_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bucket_title.add_theme_font_size_override("font_size", 18)
	bucket_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	content_vbox.add_child(bucket_title)
	
	# Pick 3 random cards
	var bucket_cards: Array[CardData] = []
	for k in range(3):
		if _all_cards.is_empty():
			continue
		var random_card = _all_cards.pick_random()
		bucket_cards.append(random_card)
		
		# Create simple card display
		var card_display = _create_card_display(random_card)
		content_vbox.add_child(card_display)
	
	# Add Select Button
	var select_btn = Button.new()
	select_btn.text = "Select"
	select_btn.custom_minimum_size.y = 50
	
	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.4, 0.3)
	btn_style.border_color = Color(0.4, 0.7, 0.5)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	select_btn.add_theme_stylebox_override("normal", btn_style)
	
	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.5, 0.35)
	hover_style.border_color = Color(0.5, 0.8, 0.6)
	select_btn.add_theme_stylebox_override("hover", hover_style)
	
	select_btn.add_theme_font_size_override("font_size", 18)
	select_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9))
	
	# Connect the button - pass the cards for this bucket
	select_btn.pressed.connect(_on_bucket_selected.bind(bucket_cards))
	content_vbox.add_child(select_btn)
	
	buckets_container.add_child(bucket_panel)


## Creates a simple card display panel
func _create_card_display(card: CardData) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 100)
	
	var rarity_color = _get_rarity_color(card.rarity)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.15)
	style.border_color = rarity_color.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Mana cost
	var mana = Label.new()
	mana.text = "🔷 %d" % card.cost
	mana.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana.add_theme_font_size_override("font_size", 16)
	mana.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(mana)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)
	
	# Stats for minions
	if card.card_type == CardData.CardType.MINION:
		var stats = Label.new()
		stats.text = "⚔️ %d  ❤️ %d" % [card.attack, card.health]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 12)
		stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		vbox.add_child(stats)
	
	# Rarity
	var rarity = Label.new()
	rarity.text = CardData.Rarity.keys()[card.rarity]
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_font_size_override("font_size", 10)
	rarity.add_theme_color_override("font_color", rarity_color.darkened(0.2))
	vbox.add_child(rarity)
	
	return panel


func _get_rarity_color(rarity: CardData.Rarity) -> Color:
	match rarity:
		CardData.Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		CardData.Rarity.RARE: return Color(0.3, 0.5, 0.9)
		CardData.Rarity.EPIC: return Color(0.6, 0.3, 0.8)
		CardData.Rarity.LEGENDARY: return Color(1.0, 0.7, 0.2)
		_: return Color.WHITE


## Called when a user chooses a bucket
func _on_bucket_selected(cards_to_add: Array[CardData]) -> void:
	print("[VictorySelection] Selected bucket with %d cards" % cards_to_add.size())
	
	# 1. Retrieve the current run deck from GameManager
	var current_deck_meta = {}
	if GameManager.has_meta("selected_deck"):
		current_deck_meta = GameManager.get_meta("selected_deck")
	
	# Ensure the structure exists
	if not current_deck_meta.has("cards"):
		current_deck_meta["cards"] = []
	
	# 2. Append new card IDs (strings) to the deck list
	for card in cards_to_add:
		var card_id = card.id if not card.id.is_empty() else card.card_name.to_lower()
		current_deck_meta["cards"].append(card_id)
		print("[VictorySelection] Added card: %s" % card_id)
	
	# 3. Save updated deck back to GameManager
	GameManager.set_meta("selected_deck", current_deck_meta)
	
	print("[VictorySelection] Updated Deck now has %d cards" % current_deck_meta["cards"].size())
	
	# 4. Award gold for winning
	var gold_reward: int = 50
	var battle_type: String = GameManager.get_meta("battle_type") if GameManager.has_meta("battle_type") else "normal"
	if battle_type == "elite":
		gold_reward = 100  # More gold for champion battles
	
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	player_gold += gold_reward
	GameManager.set_meta("player_gold", player_gold)
	print("[VictorySelection] Awarded %d gold. Total: %d" % [gold_reward, player_gold])
	
	# 5. Reset game state for next battle
	GameManager.reset_game()
	
	# 6. Check if we should return to week runner
	if GameManager.has_meta("return_to_week_runner") and GameManager.get_meta("return_to_week_runner"):
		# Clear the flag
		GameManager.set_meta("return_to_week_runner", false)
		
		# Advance the day
		var current_day: int = GameManager.get_meta("current_day_index") if GameManager.has_meta("current_day_index") else 0
		current_day += 1
		GameManager.set_meta("current_day_index", current_day)
		
		print("[VictorySelection] Returning to week runner, advancing to day %d" % (current_day + 1))
		
		get_tree().change_scene_to_file("res://scenes/week_runner.tscn")
	else:
		# Default behavior - go back to main menu or main game
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Allow skipping reward selection (go with no reward)
			var empty_cards: Array[CardData] = []
			_on_bucket_selected(empty_cards)
