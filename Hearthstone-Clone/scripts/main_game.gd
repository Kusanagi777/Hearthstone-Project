# res://scripts/main_game.gd
extends Control

## Player controllers
@export var player_one: player_controller
@export var player_two: player_controller

## UI Elements
@export var turn_button: Button
@export var mana_label: Label
@export var enemy_mana_label: Label
@export var turn_indicator: Label
@export var player_health_label: Label
@export var enemy_health_label: Label
@export var player_deck_label: Label
@export var enemy_deck_label: Label
@export var game_over_panel: Panel
@export var winner_label: Label

## Hand containers
@export var player_hand_container: Control
@export var enemy_hand_container: Control

## Hero areas
@export var player_hero_area: Control
@export var enemy_hero_area: Control

## Test deck (for development)
@export var test_deck: Array[CardData] = []

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0

## Selected deck from deck selection (optional)
var selected_deck: Dictionary = {}

## Lane references - populated in _ready
var player_front_lanes: Array[Control] = []
var player_back_lanes: Array[Control] = []
var enemy_front_lanes: Array[Control] = []
var enemy_back_lanes: Array[Control] = []


func _ready() -> void:
	visible = true
	modulate.a = 1.0
	
	# Get selected deck from GameManager metadata (if coming from deck selection)
	if GameManager.has_meta("selected_deck"):
		selected_deck = GameManager.get_meta("selected_deck")
		print("[MainGame] Using deck: %s" % selected_deck.get("name", "Unknown"))
	
	_find_nodes_if_needed()
	_setup_lanes()
	_apply_styling()
	_apply_responsive_fonts()
	
	if game_over_panel:
		game_over_panel.visible = false
	
	await get_tree().process_frame
	
	_connect_signals()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	await get_tree().create_timer(0.5).timeout
	_setup_game()


func _find_nodes_if_needed() -> void:
	# Find nodes by path if not assigned in editor
	if not turn_button:
		turn_button = find_child("TurnButton", true, false)
	if not mana_label:
		mana_label = find_child("ManaLabel", true, false)
	if not enemy_mana_label:
		enemy_mana_label = find_child("EnemyManaLabel", true, false)
	if not turn_indicator:
		turn_indicator = find_child("TurnIndicator", true, false)
	if not player_health_label:
		player_health_label = find_child("PlayerHealthLabel", true, false)
	if not enemy_health_label:
		enemy_health_label = find_child("EnemyHealthLabel", true, false)
	if not player_deck_label:
		player_deck_label = find_child("PlayerDeckLabel", true, false)
	if not enemy_deck_label:
		enemy_deck_label = find_child("EnemyDeckLabel", true, false)
	if not game_over_panel:
		game_over_panel = find_child("GameOverPanel", true, false)
	if not winner_label:
		winner_label = find_child("WinnerLabel", true, false)
	if not player_hand_container:
		player_hand_container = find_child("PlayerHandContainer", true, false)
	if not enemy_hand_container:
		enemy_hand_container = find_child("EnemyHandContainer", true, false)
	if not player_hero_area:
		player_hero_area = find_child("PlayerHeroPanel", true, false)
	if not enemy_hero_area:
		enemy_hero_area = find_child("EnemyHeroPanel", true, false)
	
	# Find player controllers
	if not player_one:
		player_one = find_child("PlayerOneController", true, false)
	if not player_two:
		player_two = find_child("PlayerTwoController", true, false)


func _setup_lanes() -> void:
	# Find player front lanes
	var player_front_container = find_child("PlayerFrontLanes", true, false)
	if player_front_container:
		for i in range(player_front_container.get_child_count()):
			var lane = player_front_container.get_child(i)
			if lane and lane is PanelContainer:
				player_front_lanes.append(lane)
				_style_lane_panel(lane, true, true, i)
	
	# Find player back lanes
	var player_back_container = find_child("PlayerBackLanes", true, false)
	if player_back_container:
		for i in range(player_back_container.get_child_count()):
			var lane = player_back_container.get_child(i)
			if lane and lane is PanelContainer:
				player_back_lanes.append(lane)
				_style_lane_panel(lane, true, false, i)
	
	# Find enemy front lanes
	var enemy_front_container = find_child("EnemyFrontLanes", true, false)
	if enemy_front_container:
		for i in range(enemy_front_container.get_child_count()):
			var lane = enemy_front_container.get_child(i)
			if lane and lane is PanelContainer:
				enemy_front_lanes.append(lane)
				_style_lane_panel(lane, false, true, i)
	
	# Find enemy back lanes
	var enemy_back_container = find_child("EnemyBackLanes", true, false)
	if enemy_back_container:
		for i in range(enemy_back_container.get_child_count()):
			var lane = enemy_back_container.get_child(i)
			if lane and lane is PanelContainer:
				enemy_back_lanes.append(lane)
				_style_lane_panel(lane, false, false, i)
	
	# Pass lane references to player controllers
	if player_one:
		player_one.front_lanes = player_front_lanes
		player_one.back_lanes = player_back_lanes
		player_one.enemy_front_lanes = enemy_front_lanes
		player_one.enemy_back_lanes = enemy_back_lanes
	
	if player_two:
		player_two.front_lanes = enemy_front_lanes
		player_two.back_lanes = enemy_back_lanes
		player_two.enemy_front_lanes = player_front_lanes
		player_two.enemy_back_lanes = player_back_lanes


func _style_lane_panel(panel: PanelContainer, is_player: bool, is_front: bool, index: int) -> void:
	var style := StyleBoxFlat.new()
	
	# Base color varies by row
	if is_front:
		style.bg_color = Color(0.15, 0.18, 0.22, 0.8)
	else:
		style.bg_color = Color(0.12, 0.14, 0.18, 0.6)
	
	# Border
	style.border_color = Color(0.3, 0.35, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	
	panel.add_theme_stylebox_override("panel", style)


func _apply_styling() -> void:
	# Style turn button
	if turn_button:
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.5, 0.3)
		btn_style.set_corner_radius_all(8)
		btn_style.set_border_width_all(2)
		btn_style.border_color = Color(0.3, 0.6, 0.4)
		turn_button.add_theme_stylebox_override("normal", btn_style)
		
		var hover_style := btn_style.duplicate()
		hover_style.bg_color = Color(0.25, 0.6, 0.35)
		turn_button.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := btn_style.duplicate()
		pressed_style.bg_color = Color(0.15, 0.4, 0.25)
		turn_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Style game over panel
	if game_over_panel:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		panel_style.set_corner_radius_all(16)
		panel_style.set_border_width_all(3)
		panel_style.border_color = Color(0.8, 0.7, 0.3)
		game_over_panel.add_theme_stylebox_override("panel", panel_style)


func _apply_responsive_fonts() -> void:
	var scale_factor := _get_scale_factor()
	
	if mana_label:
		mana_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	if enemy_mana_label:
		enemy_mana_label.add_theme_font_size_override("font_size", int(16 * scale_factor))
	if player_health_label:
		player_health_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	if enemy_health_label:
		enemy_health_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	if player_deck_label:
		player_deck_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	if enemy_deck_label:
		enemy_deck_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	if turn_indicator:
		turn_indicator.add_theme_font_size_override("font_size", int(20 * scale_factor))
	if turn_button:
		turn_button.add_theme_font_size_override("font_size", int(16 * scale_factor))
	if winner_label:
		winner_label.add_theme_font_size_override("font_size", int(32 * scale_factor))


func _get_scale_factor() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.y / REFERENCE_HEIGHT


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _connect_signals() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.card_drawn.connect(_on_card_drawn)
	
	if turn_button and not turn_button.pressed.is_connected(_on_turn_button_pressed):
		turn_button.pressed.connect(_on_turn_button_pressed)
	
	turn_button.text = "End Turn"
	turn_button.visible = true


func _setup_game() -> void:
	print("[MainGame] Setting up game...")
	
	var player_deck: Array[CardData] = []
	
	if not selected_deck.is_empty() and selected_deck.has("cards"):
		player_deck = _build_deck_from_selection(selected_deck["cards"])
	else:
		if test_deck.is_empty():
			test_deck = _create_test_deck()
		player_deck = test_deck.duplicate()
	
	var enemy_deck: Array[CardData] = _create_test_deck()
	
	GameManager.set_player_deck(0, player_deck)
	GameManager.set_player_deck(1, enemy_deck)
	
	GameManager.start_game()


func _build_deck_from_selection(card_ids: Array) -> Array[CardData]:
	var deck: Array[CardData] = []
	
	# Map of card IDs to resource paths
	var card_paths := {
		"wisp": "res://data/Cards/wisp.tres",
		"bat": "res://data/Cards/Bat.tres",
		"brawler": "res://data/Cards/Brawler.tres",
		"wolf": "res://data/Cards/Wolf.tres",
		"warrior": "res://data/Cards/warrior.tres",
		"juggernaut": "res://data/Cards/juggernaut.tres",
		"mage": "res://data/Cards/mage.tres",
		"werewolf": "res://data/Cards/werewolf.tres",
		"golem": "res://data/Cards/golem.tres",
		"demon": "res://data/Cards/demon.tres",
		"dragon": "res://data/Cards/dragon.tres",
	}
	
	for card_id in card_ids:
		var path: String = card_paths.get(card_id, "")
		if path.is_empty():
			continue
		
		if ResourceLoader.exists(path):
			var card: CardData = load(path)
			if card:
				deck.append(card.duplicate_for_play())
	
	return deck


func _create_test_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	var card_resources: Array[CardData] = []
	
	var card_paths := [
		"res://data/Cards/wisp.tres",
		"res://data/Cards/Bat.tres",
		"res://data/Cards/Brawler.tres",
		"res://data/Cards/Wolf.tres",
		"res://data/Cards/warrior.tres",
		"res://data/Cards/juggernaut.tres",
		"res://data/Cards/mage.tres",
		"res://data/Cards/werewolf.tres",
		"res://data/Cards/golem.tres",
		"res://data/Cards/demon.tres",
		"res://data/Cards/dragon.tres",
	]
	
	for path in card_paths:
		if ResourceLoader.exists(path):
			var card: CardData = load(path)
			if card:
				card_resources.append(card)
	
	if card_resources.is_empty():
		push_warning("[MainGame] No card resources found - creating basic test cards")
		card_resources = _create_basic_test_cards()
	
	# Build a 30-card deck
	while deck.size() < 30 and not card_resources.is_empty():
		for card in card_resources:
			if deck.size() >= 30:
				break
			deck.append(card.duplicate_for_play())
			# Add second copy for non-legendaries
			if deck.size() < 30 and card.rarity != CardData.Rarity.LEGENDARY:
				deck.append(card.duplicate_for_play())
	
	return deck


func _create_basic_test_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	
	# Create some basic test cards programmatically
	var wisp := CardData.new()
	wisp.id = "test_wisp"
	wisp.card_name = "Wisp"
	wisp.cost = 0
	wisp.attack = 1
	wisp.health = 1
	wisp.card_type = CardData.CardType.MINION
	cards.append(wisp)
	
	var soldier := CardData.new()
	soldier.id = "test_soldier"
	soldier.card_name = "Soldier"
	soldier.cost = 2
	soldier.attack = 2
	soldier.health = 3
	soldier.card_type = CardData.CardType.MINION
	cards.append(soldier)
	
	var knight := CardData.new()
	knight.id = "test_knight"
	knight.card_name = "Knight"
	knight.cost = 4
	knight.attack = 4
	knight.health = 5
	knight.card_type = CardData.CardType.MINION
	knight.keywords = ["taunt"]
	cards.append(knight)
	
	var champion := CardData.new()
	champion.id = "test_champion"
	champion.card_name = "Champion"
	champion.cost = 6
	champion.attack = 6
	champion.health = 6
	champion.card_type = CardData.CardType.MINION
	champion.keywords = ["charge"]
	cards.append(champion)
	
	return cards


## =============================================================================
## SIGNAL HANDLERS
## =============================================================================

func _on_turn_started(player_id: int) -> void:
	_update_turn_indicator(player_id)
	_update_deck_counts()
	
	# Enable/disable turn button based on whose turn it is
	if turn_button:
		turn_button.disabled = (player_id != 0)  # Only player 1 can click


func _on_mana_changed(player_id: int, current: int, maximum: int) -> void:
	if player_id == 0 and mana_label:
		mana_label.text = "Mana: %d/%d" % [current, maximum]
	elif player_id == 1 and enemy_mana_label:
		enemy_mana_label.text = "Mana: %d/%d" % [current, maximum]


func _on_health_changed(player_id: int, current: int, maximum: int) -> void:
	if player_id == 0 and player_health_label:
		player_health_label.text = "HP: %d/%d" % [current, maximum]
	elif player_id == 1 and enemy_health_label:
		enemy_health_label.text = "HP: %d/%d" % [current, maximum]


func _on_card_drawn(_player_id: int, _card: CardData) -> void:
	_update_deck_counts()


func _on_game_ended(winner_id: int) -> void:
	if game_over_panel:
		game_over_panel.visible = true
	if winner_label:
		if winner_id == 0:
			winner_label.text = "Victory!"
		else:
			winner_label.text = "Defeat!"


func _on_turn_button_pressed() -> void:
	if GameManager.is_player_turn(0):
		GameManager.end_turn()


func _update_turn_indicator(player_id: int) -> void:
	if turn_indicator:
		if player_id == 0:
			turn_indicator.text = "Your Turn"
			turn_indicator.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
		else:
			turn_indicator.text = "Enemy Turn"
			turn_indicator.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))


func _update_deck_counts() -> void:
	if player_deck_label:
		player_deck_label.text = "Deck: %d" % GameManager.get_deck_count(0)
	if enemy_deck_label:
		enemy_deck_label.text = "Deck: %d" % GameManager.get_deck_count(1)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
