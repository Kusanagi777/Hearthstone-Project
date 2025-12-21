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

## Selected class and deck from character selection
var selected_class: Dictionary = {}
var selected_deck: Dictionary = {}

## Lane references - populated in _ready
var player_front_lanes: Array[Control] = []
var player_back_lanes: Array[Control] = []
var enemy_front_lanes: Array[Control] = []
var enemy_back_lanes: Array[Control] = []


func _ready() -> void:
	visible = true
	modulate.a = 1.0
	
	# Get selected class and deck from GameManager metadata
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
		print("[MainGame] Playing as class: %s" % selected_class.get("name", "Unknown"))
	
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
	_setup_test_game()


func _setup_lanes() -> void:
	# Find player front lanes
	var player_front_container = find_child("PlayerFrontLanes", true, false)
	if player_front_container:
		for i in range(3):
			var lane = player_front_container.get_child(i)
			if lane:
				player_front_lanes.append(lane)
				_style_lane_panel(lane, true, true, i)
	
	# Find player back lanes
	var player_back_container = find_child("PlayerBackLanes", true, false)
	if player_back_container:
		for i in range(3):
			var lane = player_back_container.get_child(i)
			if lane:
				player_back_lanes.append(lane)
				_style_lane_panel(lane, true, false, i)
	
	# Find enemy front lanes
	var enemy_front_container = find_child("EnemyFrontLanes", true, false)
	if enemy_front_container:
		for i in range(3):
			var lane = enemy_front_container.get_child(i)
			if lane:
				enemy_front_lanes.append(lane)
				_style_lane_panel(lane, false, true, i)
	
	# Find enemy back lanes
	var enemy_back_container = find_child("EnemyBackLanes", true, false)
	if enemy_back_container:
		for i in range(3):
			var lane = enemy_back_container.get_child(i)
			if lane:
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
	
	print("[MainGame] Lanes setup: Player front=%d, back=%d | Enemy front=%d, back=%d" % [
		player_front_lanes.size(), player_back_lanes.size(),
		enemy_front_lanes.size(), enemy_back_lanes.size()
	])


func _style_lane_panel(lane: Control, is_player: bool, is_front: bool, lane_index: int) -> void:
	if not lane is PanelContainer:
		return
	
	var panel := lane as PanelContainer
	var style := StyleBoxFlat.new()
	
	# Color coding: front rows are brighter, back rows are darker
	if is_player:
		if is_front:
			style.bg_color = Color(0.15, 0.22, 0.18, 0.7)  # Greenish for player front
		else:
			style.bg_color = Color(0.12, 0.16, 0.14, 0.5)  # Darker for player back
	else:
		if is_front:
			style.bg_color = Color(0.22, 0.15, 0.15, 0.7)  # Reddish for enemy front
		else:
			style.bg_color = Color(0.16, 0.12, 0.12, 0.5)  # Darker for enemy back
	
	style.border_color = Color(0.4, 0.4, 0.35, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	# Store lane metadata
	panel.set_meta("lane_index", lane_index)
	panel.set_meta("is_front", is_front)
	panel.set_meta("is_player", is_player)


func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	var height_scale := viewport_size.y / REFERENCE_HEIGHT
	return clampf(height_scale, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale_factor := get_scale_factor()
	
	if turn_indicator:
		turn_indicator.add_theme_font_size_override("font_size", int(16 * scale_factor))
	if player_health_label:
		player_health_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	if enemy_health_label:
		enemy_health_label.add_theme_font_size_override("font_size", int(14 * scale_factor))
	if mana_label:
		mana_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	if enemy_mana_label:
		enemy_mana_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	if player_deck_label:
		player_deck_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	if enemy_deck_label:
		enemy_deck_label.add_theme_font_size_override("font_size", int(12 * scale_factor))
	if winner_label:
		winner_label.add_theme_font_size_override("font_size", int(24 * scale_factor))


func _find_nodes_if_needed() -> void:
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
	if not player_hand_container:
		player_hand_container = find_child("PlayerHandContainer", true, false) as Control
	if not enemy_hand_container:
		enemy_hand_container = find_child("EnemyHandContainer", true, false) as Control
	if not player_hero_area:
		player_hero_area = find_child("PlayerHeroArea", true, false) as Control
	if not enemy_hero_area:
		enemy_hero_area = find_child("EnemyHeroArea", true, false) as Control
	if not player_one:
		player_one = find_child("PlayerOneController", true, false) as player_controller
	if not player_two:
		player_two = find_child("PlayerTwoController", true, false) as player_controller
	
	_setup_player_controllers()


func _setup_player_controllers() -> void:
	if player_one:
		player_one.player_id = 0
		player_one.hand_container = player_hand_container
		player_one.enemy_hero_area = enemy_hero_area
		player_one.hero_area = player_hero_area
	
	if player_two:
		player_two.player_id = 1
		player_two.hand_container = enemy_hand_container
		player_two.enemy_hero_area = player_hero_area
		player_two.hero_area = enemy_hero_area


func _apply_styling() -> void:
	# Style hand areas
	_style_panel_container(find_child("PlayerHandArea", true, false) as Control, Color(0.1, 0.12, 0.18, 0.7))
	_style_panel_container(find_child("EnemyHandArea", true, false) as Control, Color(0.18, 0.1, 0.1, 0.5))
	
	# Style row containers
	_style_panel_container(find_child("PlayerFrontRow", true, false) as Control, Color(0.1, 0.15, 0.12, 0.3))
	_style_panel_container(find_child("PlayerBackRow", true, false) as Control, Color(0.08, 0.1, 0.09, 0.3))
	_style_panel_container(find_child("EnemyFrontRow", true, false) as Control, Color(0.15, 0.1, 0.1, 0.3))
	_style_panel_container(find_child("EnemyBackRow", true, false) as Control, Color(0.1, 0.08, 0.08, 0.3))
	
	# Style hero areas
	_style_hero_panel(player_hero_area, true)
	_style_hero_panel(enemy_hero_area, false)
	
	if turn_button:
		_style_button(turn_button)
	
	if game_over_panel:
		_style_game_over_panel()


func _style_panel_container(container: Control, bg_color: Color) -> void:
	if not container or not container is PanelContainer:
		return
	
	var panel := container as PanelContainer
	if not panel.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_color = Color(0.4, 0.4, 0.3, 0.4)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)


func _style_hero_panel(hero: Control, is_player: bool) -> void:
	if not hero or not hero is PanelContainer:
		return
	
	var panel := hero as PanelContainer
	if not panel.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		if is_player:
			if not selected_class.is_empty():
				var class_color: Color = selected_class.get("color", Color(0.15, 0.2, 0.25))
				style.bg_color = class_color.darkened(0.7)
			else:
				style.bg_color = Color(0.15, 0.2, 0.25)
		else:
			style.bg_color = Color(0.25, 0.15, 0.15)
		style.border_color = Color(0.5, 0.45, 0.35)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)


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


func _setup_test_game() -> void:
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
	
	if not selected_class.is_empty():
		var class_health: int = selected_class.get("health", 30)
		GameManager.players[0]["hero_health"] = class_health
		GameManager.players[0]["hero_max_health"] = class_health
	
	GameManager.start_game()


func _build_deck_from_selection(card_ids: Array) -> Array[CardData]:
	var deck: Array[CardData] = []
	
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
		return deck
	
	for i in range(30):
		var base_card: CardData = card_resources[i % card_resources.size()]
		deck.append(base_card.duplicate_for_play())
	
	return deck


func _on_turn_started(player_id: int) -> void:
	if turn_indicator:
		if player_id == 0:
			turn_indicator.text = "Your Turn"
			turn_indicator.add_theme_color_override("font_color", Color.GREEN)
		else:
			turn_indicator.text = "Enemy Turn"
			turn_indicator.add_theme_color_override("font_color", Color.RED)
	
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


func _on_card_drawn(_player_id: int, _card: CardData) -> void:
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
	if player_one:
		player_one.request_end_turn()


# In scripts/main_game.gd

func _on_game_ended(winner_id: int) -> void:
	if game_over_panel:
		game_over_panel.visible = true
		if winner_label:
			if winner_id == 0:
				winner_label.text = "Victory!"
				winner_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
				
				# Wait 2 seconds so the player sees "Victory!", then go to loot screen
				var timer = get_tree().create_timer(2.0)
				await timer.timeout
				get_tree().change_scene_to_file("res://scenes/victory_selection.tscn")
				
			else:
				winner_label.text = "Defeat!"
				winner_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				# Optional: Return to main menu on defeat


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			if GameManager.is_player_turn(0):
				_on_turn_button_pressed()
		elif event.keycode == KEY_D:
			if GameManager.is_player_turn(0):
				GameManager._draw_card(0)
		elif event.keycode == KEY_ESCAPE:
			GameManager.reset_game()
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
		# --- NEW DEBUG KEY ---
		elif event.keycode == KEY_K:
			_debug_kill_enemy()

## Debug function to instantly win the game
func _debug_kill_enemy() -> void:
	print("[MainGame] DEBUG: Insta-kill triggered!")
	
	# 1. Directly set the enemy (Player 1) health to 0 in the GameManager data
	GameManager.players[1]["hero_health"] = 0
	
	# 2. Update the visual labels immediately so we see "HP: 0"
	_update_health_display()
	
	# 3. Force the GameManager to check for death
	# This will trigger the _end_game logic and emit the game_ended signal
	# which our _on_game_ended function is already listening for.
	GameManager._check_hero_death(1)
