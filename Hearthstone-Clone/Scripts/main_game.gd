# res://scripts/main_game.gd
extends Control

## Player controllers
@export var player_one: Player_Controller
@export var player_two: Player_Controller

## UI Elements - these can be connected in editor or found by path
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

## Board zones
@export var player_board_zone: Control
@export var enemy_board_zone: Control
@export var player_hand_container: Control
@export var enemy_hand_container: Control

## Hero areas
@export var player_hero_area: Control
@export var enemy_hero_area: Control

## Test deck (for development)
@export var test_deck: Array[CardData] = []


func _ready() -> void:
	# Ensure this control is visible
	visible = true
	modulate.a = 1.0
	
	# Try to find nodes if not assigned in inspector
	_find_nodes_if_needed()
	
	# Apply visual styling
	_apply_styling()
	
	# Hide game over panel
	if game_over_panel:
		game_over_panel.visible = false
	
	# Wait for tree to be fully ready
	await get_tree().process_frame
	
	_connect_signals()
	
	# Delay game start to ensure all nodes are ready
	await get_tree().create_timer(0.5).timeout
	_setup_test_game()


## Find UI nodes if they weren't assigned in inspector
func _find_nodes_if_needed() -> void:
	# Try to find nodes from our scene structure
	if not turn_button:
		turn_button = find_child("TurnButton", true, false) as Button
	if not mana_label:
		mana_label = find_child("ManaLabel", true, false) as Label
	if not enemy_mana_label:
		enemy_mana_label = find_child("EnemyManaLabel", true, false) as Label
	if not turn_indicator:
		turn_indicator = find_child("TurnIndicator", true, false) as Label
	if not player_health_label:
		player_health_label = find_child("PlayerHealthLabel", true, false) as Label
	if not enemy_health_label:
		enemy_health_label = find_child("EnemyHealthLabel", true, false) as Label
	if not player_deck_label:
		player_deck_label = find_child("PlayerDeckLabel", true, false) as Label
	if not enemy_deck_label:
		enemy_deck_label = find_child("EnemyDeckLabel", true, false) as Label
	if not game_over_panel:
		game_over_panel = find_child("GameOverPanel", true, false) as Panel
	if not winner_label:
		winner_label = find_child("WinnerLabel", true, false) as Label
	
	# Board zones
	if not player_board_zone:
		player_board_zone = find_child("PlayerBoard", true, false) as Control
	if not enemy_board_zone:
		enemy_board_zone = find_child("EnemyBoard", true, false) as Control
	if not player_hand_container:
		player_hand_container = find_child("PlayerHandContainer", true, false) as Control
	if not enemy_hand_container:
		enemy_hand_container = find_child("EnemyHandContainer", true, false) as Control
	
	# Hero areas
	if not player_hero_area:
		player_hero_area = find_child("PlayerHeroArea", true, false) as Control
	if not enemy_hero_area:
		enemy_hero_area = find_child("EnemyHeroArea", true, false) as Control
	
	# Player controllers
	if not player_one:
		player_one = find_child("PlayerOneController", true, false) as Player_Controller
	if not player_two:
		player_two = find_child("PlayerTwoController", true, false) as Player_Controller
	
	# Connect player controllers to their zones
	_setup_player_controllers()


## Setup player controllers with their zones
func _setup_player_controllers() -> void:
	if player_one:
		player_one.player_id = 0
		player_one.hand_container = player_hand_container
		player_one.board_zone = player_board_zone
		player_one.enemy_board_zone = enemy_board_zone
		player_one.enemy_hero_area = enemy_hero_area
		player_one.hero_area = player_hero_area
	
	if player_two:
		player_two.player_id = 1
		player_two.hand_container = enemy_hand_container
		player_two.board_zone = enemy_board_zone
		player_two.enemy_board_zone = player_board_zone
		player_two.enemy_hero_area = player_hero_area
		player_two.hero_area = enemy_hero_area


## Apply visual styling to UI elements
func _apply_styling() -> void:
	# Style board zones
	_style_panel_container(find_child("PlayerBoardZone", true, false) as Control, Color(0.15, 0.2, 0.15, 0.5))
	_style_panel_container(find_child("EnemyBoardZone", true, false) as Control, Color(0.2, 0.15, 0.15, 0.5))
	
	# Style hand areas
	_style_panel_container(find_child("PlayerHandArea", true, false) as Control, Color(0.1, 0.12, 0.18, 0.7))
	_style_panel_container(find_child("EnemyHandArea", true, false) as Control, Color(0.18, 0.1, 0.1, 0.5))
	
	# Style hero areas
	_style_hero_panel(player_hero_area, true)
	_style_hero_panel(enemy_hero_area, false)
	
	# Style turn button
	if turn_button:
		_style_button(turn_button)
	
	# Style game over panel
	if game_over_panel:
		_style_game_over_panel()


## Style a panel container
func _style_panel_container(container: Control, bg_color: Color) -> void:
	if not container or not container is PanelContainer:
		return
	
	var panel := container as PanelContainer
	if not panel.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_color = Color(0.4, 0.4, 0.3, 0.6)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)


## Style hero panel
func _style_hero_panel(hero: Control, is_player: bool) -> void:
	if not hero or not hero is PanelContainer:
		return
	
	var panel := hero as PanelContainer
	if not panel.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		if is_player:
			style.bg_color = Color(0.15, 0.2, 0.25)
		else:
			style.bg_color = Color(0.25, 0.15, 0.15)
		style.border_color = Color(0.5, 0.45, 0.35)
		style.set_border_width_all(3)
		style.set_corner_radius_all(10)
		panel.add_theme_stylebox_override("panel", style)
	
	# Style the portrait
	var portrait := hero.find_child("Portrait", true, false) as Panel
	if portrait and not portrait.has_theme_stylebox_override("panel"):
		var portrait_style := StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.3, 0.3, 0.35)
		portrait_style.set_corner_radius_all(30)
		portrait.add_theme_stylebox_override("panel", portrait_style)


## Style buttons
func _style_button(button: Button) -> void:
	if button.has_theme_stylebox_override("normal"):
		return
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.3, 0.4)
	normal_style.border_color = Color(0.5, 0.5, 0.6)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.35, 0.4, 0.5)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.25, 0.35)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = Color(0.2, 0.2, 0.2)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	button.add_theme_color_override("font_color", Color.WHITE)


## Style game over panel
func _style_game_over_panel() -> void:
	if not game_over_panel or game_over_panel.has_theme_stylebox_override("panel"):
		return
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = Color(0.8, 0.7, 0.2)
	style.set_border_width_all(4)
	style.set_corner_radius_all(15)
	game_over_panel.add_theme_stylebox_override("panel", style)


func _connect_signals() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.card_drawn.connect(_on_card_drawn)
	GameManager.entity_died.connect(_on_entity_died)
	
	if turn_button:
		if not turn_button.pressed.is_connected(_on_turn_button_pressed):
			turn_button.pressed.connect(_on_turn_button_pressed)
		turn_button.text = "End Turn"
		turn_button.visible = true
		print("[MainGame] Turn button connected")


func _setup_test_game() -> void:
	print("[MainGame] Setting up test game...")
	
	# Create test decks if none provided
	if test_deck.is_empty():
		test_deck = _create_test_deck()
	
	# Set up both players with the test deck
	GameManager.set_player_deck(0, test_deck.duplicate())
	GameManager.set_player_deck(1, test_deck.duplicate())
	
	print("[MainGame] Decks set, starting game...")
	
	# Start the game
	GameManager.start_game()


func _create_test_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	
	# Load card resources from .tres files
	var card_resources: Array[CardData] = []
	
	# Load all available card resources
	var card_paths := [
		"res://Resources/Cards/wisp.tres",
		"res://Resources/Cards/Cards/Bat.tres",
		"res://Resources/Cards/Brawler.tres",
		"res://Resources/Cards/Wolf.tres",
		"res://Resources/Cards/warrior.tres",
		"res://Resources/Cards/juggernaut.tres",
		"res://Resources/Cards/mage.tres",
		"res://Resources/Cards/werewolf.tres",
		"res://Resources/Cards/golem.tres",
		"res://Resources/Cards/demon.tres",
		"res://Resources/Cards/dragon.tres",
	]
	
	for path in card_paths:
		if ResourceLoader.exists(path):
			var card: CardData = load(path)
			if card:
				card_resources.append(card)
				print("[MainGame] Loaded card: %s" % card.card_name)
			else:
				push_warning("[MainGame] Failed to load card at: %s" % path)
		else:
			push_warning("[MainGame] Card resource not found: %s" % path)
	
	if card_resources.is_empty():
		push_error("[MainGame] No card resources found! Check your Resources folder.")
		return deck
	
	# Fill deck with 30 cards (multiple copies of each card)
	var copies_per_card := ceili(30.0 / card_resources.size())
	var card_index := 0
	
	for i in range(30):
		var base_card: CardData = card_resources[i % card_resources.size()]
		deck.append(base_card.duplicate_for_play())
	
	print("[MainGame] Created deck with %d cards from %d unique cards" % [deck.size(), card_resources.size()])
	return deck


func _on_turn_started(player_id: int) -> void:
	print("[MainGame] Turn started for player %d" % player_id)
	
	if turn_indicator:
		if player_id == 0:
			turn_indicator.text = "Your Turn"
			turn_indicator.add_theme_color_override("font_color", Color.GREEN)
		else:
			turn_indicator.text = "Enemy Turn"
			turn_indicator.add_theme_color_override("font_color", Color.RED)
	
	# Only enable turn button for player one (human player)
	if turn_button:
		turn_button.disabled = (player_id != 0)
	
	_update_health_display()
	_update_deck_counts()


func _on_mana_changed(player_id: int, current: int, maximum: int) -> void:
	var mana_text := "%d / %d" % [current, maximum]
	
	if player_id == 0 and mana_label:
		mana_label.text = mana_text
	elif player_id == 1 and enemy_mana_label:
		enemy_mana_label.text = mana_text


func _on_card_drawn(_player_id: int, _card_data: CardData) -> void:
	_update_deck_counts()


func _on_entity_died(_player_id: int, _entity: Node) -> void:
	_update_health_display()


func _update_health_display() -> void:
	if player_health_label:
		player_health_label.text = "HP: %d" % GameManager.get_hero_health(0)
	if enemy_health_label:
		enemy_health_label.text = "HP: %d" % GameManager.get_hero_health(1)


func _update_deck_counts() -> void:
	if player_deck_label:
		player_deck_label.text = "Deck: %d" % GameManager.get_deck_size(0)
	if enemy_deck_label:
		enemy_deck_label.text = "Deck: %d" % GameManager.get_deck_size(1)


func _on_turn_button_pressed() -> void:
	print("[MainGame] End turn button pressed")
	if player_one:
		player_one.request_end_turn()


func _on_game_ended(winner_id: int) -> void:
	print("[MainGame] Game Over! Player %d wins!" % winner_id)
	
	if game_over_panel:
		game_over_panel.visible = true
		if winner_label:
			winner_label.text = "Player %d Wins!" % (winner_id + 1)


func _input(event: InputEvent) -> void:
	# Debug shortcut: Press Space to end turn
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if GameManager.is_player_turn(0):
				_on_turn_button_pressed()
		elif event.keycode == KEY_D:
			# Debug: Draw a card
			if GameManager.is_player_turn(0):
				GameManager._draw_card(0)
