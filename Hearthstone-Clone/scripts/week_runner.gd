# res://scripts/week_runner.gd
extends Control

## This screen manages the weekly schedule execution
## It shows the current day and transitions to the appropriate scene

const REFERENCE_HEIGHT: float = 720.0
const SIDE_JOB_GOLD: int = 150

## Activity definitions (same as schedule builder)
var activities: Dictionary = {
	"duel": {
		"id": "duel",
		"name": "Duel",
		"description": "Fight a standard opponent",
		"icon": "⚔️",
		"color": Color(0.9, 0.3, 0.3),
		"scene": "res://scenes/main_game.tscn",
		"battle_type": "normal"
	},
	"champion": {
		"id": "champion",
		"name": "Champion",
		"description": "Challenge an Elite opponent",
		"icon": "🏆",
		"color": Color(1.0, 0.8, 0.2),
		"scene": "res://scenes/main_game.tscn",
		"battle_type": "elite"
	},
	"side_job": {
		"id": "side_job",
		"name": "Side Job",
		"description": "Work for gold",
		"icon": "💰",
		"color": Color(0.4, 0.8, 0.4),
		"scene": "",  # Handled inline
		"gold_reward": SIDE_JOB_GOLD
	},
	"shop": {
		"id": "shop",
		"name": "Shop",
		"description": "Visit the merchant",
		"icon": "🛒",
		"color": Color(0.3, 0.6, 0.9),
		"scene": "res://scenes/shop_screen.tscn"
	}
}

## Current schedule from GameManager
var weekly_schedule: Array = []
var current_day_index: int = 0

## UI References
var day_label: Label
var activity_icon: Label
var activity_name: Label
var activity_desc: Label
var gold_label: Label
var continue_button: Button
var progress_container: HBoxContainer

## Animation state
var _is_transitioning: bool = false


func _ready() -> void:
	# Load schedule from GameManager
	if GameManager.has_meta("weekly_schedule"):
		weekly_schedule = GameManager.get_meta("weekly_schedule")
	
	if GameManager.has_meta("current_day_index"):
		current_day_index = GameManager.get_meta("current_day_index")
	
	# Initialize gold if not set
	if not GameManager.has_meta("player_gold"):
		GameManager.set_meta("player_gold", 200)
	
	_setup_ui()
	_update_display()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Auto-start after a brief moment
	await get_tree().create_timer(0.5).timeout
	_check_auto_execute()


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12)
	add_child(bg)
	
	# Main container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 30)
	margin.add_child(main_vbox)
	
	# Gold display (top right)
	var gold_container = HBoxContainer.new()
	gold_container.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(gold_container)
	
	var gold_icon = Label.new()
	gold_icon.text = "💰"
	gold_icon.add_theme_font_size_override("font_size", 24)
	gold_container.add_child(gold_icon)
	
	gold_label = Label.new()
	gold_label.text = "0"
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_container.add_child(gold_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer1)
	
	# Day header
	day_label = Label.new()
	day_label.text = "Day 1 of 5"
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 36)
	day_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(day_label)
	
	# Activity card
	var activity_panel = PanelContainer.new()
	activity_panel.custom_minimum_size = Vector2(400, 250)
	activity_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(activity_panel)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.14, 0.2)
	panel_style.border_color = Color(0.5, 0.45, 0.3)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(15)
	panel_style.set_content_margin_all(30)
	activity_panel.add_theme_stylebox_override("panel", panel_style)
	
	var activity_vbox = VBoxContainer.new()
	activity_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	activity_vbox.add_theme_constant_override("separation", 15)
	activity_panel.add_child(activity_vbox)
	
	# Activity icon
	activity_icon = Label.new()
	activity_icon.text = "⚔️"
	activity_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_icon.add_theme_font_size_override("font_size", 64)
	activity_vbox.add_child(activity_icon)
	
	# Activity name
	activity_name = Label.new()
	activity_name.text = "Duel"
	activity_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_name.add_theme_font_size_override("font_size", 28)
	activity_name.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	activity_vbox.add_child(activity_name)
	
	# Activity description
	activity_desc = Label.new()
	activity_desc.text = "Fight a standard opponent"
	activity_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_desc.add_theme_font_size_override("font_size", 16)
	activity_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	activity_vbox.add_child(activity_desc)
	
	# Progress indicator
	var progress_label = Label.new()
	progress_label.text = "Week Progress"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	main_vbox.add_child(progress_label)
	
	progress_container = HBoxContainer.new()
	progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(progress_container)
	
	# Create 5 progress dots
	for i in range(5):
		var dot = _create_progress_dot(i)
		progress_container.add_child(dot)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)
	
	# Continue button
	continue_button = Button.new()
	continue_button.text = "Begin Activity"
	continue_button.custom_minimum_size = Vector2(250, 60)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue_pressed)
	main_vbox.add_child(continue_button)
	
	_style_button(continue_button)


func _create_progress_dot(index: int) -> PanelContainer:
	var dot = PanelContainer.new()
	dot.custom_minimum_size = Vector2(50, 50)
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(25)
	style.set_content_margin_all(5)
	
	if index < current_day_index:
		# Completed
		style.bg_color = Color(0.3, 0.7, 0.3)
		style.border_color = Color(0.4, 0.8, 0.4)
	elif index == current_day_index:
		# Current
		style.bg_color = Color(0.8, 0.6, 0.2)
		style.border_color = Color(1.0, 0.8, 0.3)
	else:
		# Future
		style.bg_color = Color(0.2, 0.2, 0.25)
		style.border_color = Color(0.3, 0.3, 0.35)
	
	style.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", style)
	
	# Day number
	var label = Label.new()
	label.text = str(index + 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	dot.add_child(label)
	
	return dot


func _update_display() -> void:
	# Update gold
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	gold_label.text = str(player_gold)
	
	if current_day_index >= weekly_schedule.size():
		# Week complete!
		day_label.text = "Week Complete!"
		activity_icon.text = "🎉"
		activity_name.text = "All activities finished!"
		activity_desc.text = "Return to schedule builder to plan next week"
		continue_button.text = "Plan Next Week"
		return
	
	# Update day label
	day_label.text = "Day %d of %d" % [current_day_index + 1, weekly_schedule.size()]
	
	# Get current activity
	var activity_id: String = weekly_schedule[current_day_index]
	var activity_data: Dictionary = activities.get(activity_id, activities["duel"])
	
	activity_icon.text = activity_data["icon"]
	activity_name.text = activity_data["name"]
	activity_desc.text = activity_data["description"]
	activity_name.add_theme_color_override("font_color", activity_data["color"])
	
	# Update button text based on activity
	match activity_id:
		"duel":
			continue_button.text = "Start Battle!"
		"champion":
			continue_button.text = "Challenge Champion!"
		"shop":
			continue_button.text = "Enter Shop"
		"side_job":
			continue_button.text = "Work Shift (+%d Gold)" % SIDE_JOB_GOLD
	
	# Update progress dots
	_refresh_progress_dots()


func _refresh_progress_dots() -> void:
	for i in range(progress_container.get_child_count()):
		var dot = progress_container.get_child(i) as PanelContainer
		if not dot:
			continue
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(25)
		style.set_content_margin_all(5)
		style.set_border_width_all(2)
		
		if i < current_day_index:
			style.bg_color = Color(0.3, 0.7, 0.3)
			style.border_color = Color(0.4, 0.8, 0.4)
		elif i == current_day_index:
			style.bg_color = Color(0.8, 0.6, 0.2)
			style.border_color = Color(1.0, 0.8, 0.3)
		else:
			style.bg_color = Color(0.2, 0.2, 0.25)
			style.border_color = Color(0.3, 0.3, 0.35)
		
		dot.add_theme_stylebox_override("panel", style)


func _check_auto_execute() -> void:
	# For side_job, we can auto-execute without user input
	# But for now, let the user click to proceed
	pass


func _on_continue_pressed() -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	
	if current_day_index >= weekly_schedule.size():
		# Week complete - go back to schedule builder
		get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		return
	
	var activity_id: String = weekly_schedule[current_day_index]
	
	match activity_id:
		"side_job":
			_execute_side_job()
		"shop":
			_execute_shop()
		"duel":
			_execute_battle("normal")
		"champion":
			_execute_battle("elite")
		_:
			print("[WeekRunner] Unknown activity: %s" % activity_id)
			_advance_day()


func _execute_side_job() -> void:
	# Add gold
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	player_gold += SIDE_JOB_GOLD
	GameManager.set_meta("player_gold", player_gold)
	
	print("[WeekRunner] Side job completed! Earned %d gold. Total: %d" % [SIDE_JOB_GOLD, player_gold])
	
	# Show gold earned animation
	_show_gold_popup(SIDE_JOB_GOLD)
	
	# Wait then advance
	await get_tree().create_timer(1.5).timeout
	_advance_day()


func _show_gold_popup(amount: int) -> void:
	var popup = Label.new()
	popup.text = "+%d 💰" % amount
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 48)
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.z_index = 100
	add_child(popup)
	
	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 100, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)
	
	# Update gold display immediately
	gold_label.text = str(GameManager.get_meta("player_gold"))


func _execute_shop() -> void:
	# Store return info
	GameManager.set_meta("return_to_week_runner", true)
	GameManager.set_meta("current_day_index", current_day_index)
	
	# Go to shop
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")


func _execute_battle(battle_type: String) -> void:
	# Store battle info
	GameManager.set_meta("battle_type", battle_type)
	GameManager.set_meta("return_to_week_runner", true)
	GameManager.set_meta("current_day_index", current_day_index)
	
	print("[WeekRunner] Starting %s battle" % battle_type)
	
	# Go to battle
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _advance_day() -> void:
	current_day_index += 1
	GameManager.set_meta("current_day_index", current_day_index)
	
	_is_transitioning = false
	_update_display()
	
	if current_day_index >= weekly_schedule.size():
		print("[WeekRunner] Week complete!")


func _style_button(button: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.4, 0.3)
	normal_style.border_color = Color(0.4, 0.7, 0.5)
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(10)
	normal_style.set_content_margin_all(15)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.5, 0.35)
	hover_style.border_color = Color(0.5, 0.8, 0.6)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.3, 0.2)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	var s = get_scale_factor()
	if day_label:
		day_label.add_theme_font_size_override("font_size", int(36 * s))
	if activity_name:
		activity_name.add_theme_font_size_override("font_size", int(28 * s))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Allow going back to schedule builder
			get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_continue_pressed()
