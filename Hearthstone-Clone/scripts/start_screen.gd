# res://scripts/start_screen.gd
extends Control

## UI References
@onready var start_button: Button = $CenterContainer/VBoxContainer/MenuButtons/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/MenuButtons/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ExitButton

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	# Reset game state when returning to menu
	GameManager.reset_game()
	
	_connect_signals()
	_apply_responsive_fonts()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _connect_signals() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect any additional buttons that might exist
	var deck_build_button = find_child("DeckBuildButton", true, false)
	if deck_build_button and deck_build_button is Button:
		deck_build_button.pressed.connect(_on_deck_build_pressed)
	
	var shop_button = find_child("Shop Test", true, false)
	if shop_button and shop_button is Button:
		shop_button.pressed.connect(_on_shop_pressed)


func _apply_responsive_fonts() -> void:
	var scale_factor := _get_scale_factor()
	
	var title_label = find_child("TitleLabel", true, false)
	if title_label and title_label is Label:
		title_label.add_theme_font_size_override("font_size", int(48 * scale_factor))
	
	var subtitle_label = find_child("SubtitleLabel", true, false)
	if subtitle_label and subtitle_label is Label:
		subtitle_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	
	# Scale button fonts
	var buttons = [start_button, options_button, exit_button]
	for btn in buttons:
		if btn:
			btn.add_theme_font_size_override("font_size", int(20 * scale_factor))


func _get_scale_factor() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.y / REFERENCE_HEIGHT


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _on_start_pressed() -> void:
	# Go directly to game (or deck selection if you have it)
	# Option 1: Go straight to game
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	
	# Option 2: Go to deck selection (uncomment if you have simplified deck selection)
	# get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")


func _on_deck_build_pressed() -> void:
	# Go to deck builder if you have one
	if ResourceLoader.exists("res://scenes/deck_builder.tscn"):
		get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")
	else:
		print("[StartScreen] Deck builder scene not found")


func _on_options_pressed() -> void:
	# TODO: Implement options menu
	print("[StartScreen] Options not yet implemented")


func _on_shop_pressed() -> void:
	if ResourceLoader.exists("res://scenes/shop.tscn"):
		get_tree().change_scene_to_file("res://scenes/shop.tscn")
	else:
		print("[StartScreen] Shop scene not found")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_start_pressed()
