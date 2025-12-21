# res://scripts/victory_selection.gd
extends Control

## Reference to the CardUI scene to instantiate cards visually
@export var card_ui_scene: PackedScene

## Container to hold the 3 bucket columns
@export var buckets_container: HBoxContainer

## Button to proceed (optional, or we can click the bucket itself)
@export var title_label: Label

## Path to the folder containing all CardData resources
const CARDS_PATH = "res://data/Cards/"

## Pool of all potential cards to draft from
var _all_cards: Array[CardData] = []

func _ready() -> void:
	# 1. Load all available cards from the filesystem
	_load_card_database()
	
	# 2. Generate the 3 choices
	if _all_cards.size() > 0:
		_generate_loot_buckets()
	else:
		push_error("No cards found in " + CARDS_PATH)

## Scans the data directory for .tres files to build the draft pool
func _load_card_database() -> void:
	var dir = DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var card_path = CARDS_PATH + "/" + file_name
				var card_data = load(card_path) as CardData
				if card_data:
					# Filter out non-collectible cards here if needed (e.g. Tokens)
					_all_cards.append(card_data)
			file_name = dir.get_next()
	else:
		push_error("An error occurred when trying to access the path: " + CARDS_PATH)

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
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	bucket_panel.add_child(content_vbox)
	
	# Pick 3 random cards
	var bucket_cards: Array[CardData] = []
	for k in range(3):
		var random_card = _all_cards.pick_random()
		bucket_cards.append(random_card)
		
		# Instantiate visual card
		if card_ui_scene:
			var card_instance = card_ui_scene.instantiate()
			content_vbox.add_child(card_instance)
			# We pass owner_id -1 or 0 just for visual initialization
			card_instance.initialize(random_card, 0)
			# Make it non-interactable so you don't try to drag it
			card_instance.set_interactable(false)
			# Scale it down slightly to fit UI
			card_instance.scale = Vector2(0.8, 0.8)
			card_instance.custom_minimum_size = Vector2(120, 170) * 0.8
	
	# Add Select Button
	var select_btn = Button.new()
	select_btn.text = "Select Bucket %d" % (index + 1)
	select_btn.custom_minimum_size.y = 50
	
	# Connect signal to handle selection
	# We bind the specific cards in this bucket to the signal
	select_btn.pressed.connect(_on_bucket_selected.bind(bucket_cards))
	
	content_vbox.add_child(select_btn)
	buckets_container.add_child(bucket_panel)

## Called when a user chooses a bucket
func _on_bucket_selected(cards_to_add: Array[CardData]) -> void:
	print("Selected bucket with cards: ", cards_to_add)
	
	# 1. Retrieve the current run deck from GameManager
	var current_deck_meta = {}
	if GameManager.has_meta("selected_deck"):
		current_deck_meta = GameManager.get_meta("selected_deck")
	
	# Ensure the structure exists
	if not current_deck_meta.has("cards"):
		current_deck_meta["cards"] = []
	
	# 2. Append new card IDs (strings) to the deck list
	# Note: main_game.gd expects 'cards' to be an Array of Strings (IDs/names)
	for card in cards_to_add:
		# Use the ID from CardData, or fallback to name if ID is missing
		var card_id = card.id if not card.id.is_empty() else card.card_name.to_lower()
		current_deck_meta["cards"].append(card_id)
	
	# 3. Save updated deck back to GameManager
	GameManager.set_meta("selected_deck", current_deck_meta)
	
	print("Updated Deck: ", current_deck_meta["cards"])
	
	# 4. Transition to next scene (e.g., Start next battle)
	# For now, we reload the main game to start the next match with the larger deck
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
