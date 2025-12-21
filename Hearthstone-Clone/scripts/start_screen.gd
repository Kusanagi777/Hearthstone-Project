# res://scripts/start_screen.gd
extends Control

## UI References
@onready var start_button: Button = $CenterContainer/VBoxContainer/MenuButtons/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/MenuButtons/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ExitButton
@onready var store_button: Button = $"CenterContainer/VBoxContainer/MenuButtons/Shop Test"
@onready var options_panel: Panel = $OptionsPanel
@onready var back_button: Button = $OptionsPanel/VBoxContainer/BackButton
@onready var master_volume_slider: HSlider = $OptionsPanel/VBoxContainer/MasterVolume/MasterVolumeSlider
@onready var sfx_volume_slider: HSlider = $OptionsPanel/VBoxContainer/SFXVolume/SFXVolumeSlider
@onready var fullscreen_check: CheckButton = $OptionsPanel/VBoxContainer/FullscreenCheck

## Reference resolution
const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	# Hide options panel initially
	if options_panel:
		options_panel.visible = false
	
	# Connect button signals
	_connect_signals()
	
	# Apply styling
	_apply_styling()
	
	# Apply responsive sizing
	_apply_responsive_fonts()
	
	# Connect to viewport resize
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Load saved settings
	_load_settings()


func _connect_signals() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	if store_button:
		store_button.pressed.connect(_on_shop_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)


func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	var height_scale := viewport_size.y / REFERENCE_HEIGHT
	return clampf(height_scale, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale_factor := get_scale_factor()
	
	# Scale title
	var title_label = find_child("TitleLabel", true, false) as Label
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(48 * scale_factor))
	
	# Scale subtitle
	var subtitle_label = find_child("SubtitleLabel", true, false) as Label
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	
	# Scale buttons
	for button in [start_button, options_button, exit_button, back_button]:
		if button:
			button.add_theme_font_size_override("font_size", int(20 * scale_factor))
	
	# Scale options labels
	var options_title = $OptionsPanel/VBoxContainer/OptionsTitleLabel if has_node("OptionsPanel/VBoxContainer/OptionsTitleLabel") else null
	if options_title:
		options_title.add_theme_font_size_override("font_size", int(28 * scale_factor))


func _apply_styling() -> void:
	# Style main menu buttons
	for button in [start_button, options_button, exit_button]:
		if button:
			_style_menu_button(button)
	
	# Style back button
	if back_button:
		_style_menu_button(back_button)
	
	# Style options panel
	if options_panel and not options_panel.has_theme_stylebox_override("panel"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
		style.border_color = Color(0.5, 0.4, 0.3)
		style.set_border_width_all(3)
		style.set_corner_radius_all(15)
		options_panel.add_theme_stylebox_override("panel", style)


func _style_menu_button(button: Button) -> void:
	if button.has_theme_stylebox_override("normal"):
		return
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.25, 0.35)
	normal_style.border_color = Color(0.5, 0.45, 0.3)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(15)
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


func _on_start_pressed() -> void:
	# Go to class selection screen instead of directly to game
	print("[StartScreen] Going to class selection...")
	get_tree().change_scene_to_file("res://scenes/class_selection.tscn")


func _on_options_pressed() -> void:
	print("[StartScreen] Opening options...")
	if options_panel:
		options_panel.visible = true


func _on_back_pressed() -> void:
	if options_panel:
		options_panel.visible = false
	_save_settings()


func _on_exit_pressed() -> void:
	print("[StartScreen] Exiting game...")
	_save_settings()
	get_tree().quit()

func _on_shop_pressed() -> void:
	print("[StartScreen] Opening shop")
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")

func _on_master_volume_changed(value: float) -> void:
	# Convert slider value (0-100) to dB (-80 to 0)
	var db := linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)


func _on_sfx_volume_changed(value: float) -> void:
	# If you have an SFX bus, adjust it here
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		var db := linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus, db)


func _on_fullscreen_toggled(toggled: bool) -> void:
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _save_settings() -> void:
	var config := ConfigFile.new()
	
	if master_volume_slider:
		config.set_value("audio", "master_volume", master_volume_slider.value)
	if sfx_volume_slider:
		config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	if fullscreen_check:
		config.set_value("video", "fullscreen", fullscreen_check.button_pressed)
	
	var err := config.save("user://settings.cfg")
	if err != OK:
		push_warning("Failed to save settings")


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	
	if err != OK:
		# Use defaults
		return
	
	if master_volume_slider:
		master_volume_slider.value = config.get_value("audio", "master_volume", 80.0)
		_on_master_volume_changed(master_volume_slider.value)
	
	if sfx_volume_slider:
		sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 80.0)
		_on_sfx_volume_changed(sfx_volume_slider.value)
	
	if fullscreen_check:
		var is_fullscreen: bool = config.get_value("video", "fullscreen", false)
		fullscreen_check.button_pressed = is_fullscreen
		_on_fullscreen_toggled(is_fullscreen)


func _input(event: InputEvent) -> void:
	# Close options with Escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if options_panel and options_panel.visible:
				_on_back_pressed()
