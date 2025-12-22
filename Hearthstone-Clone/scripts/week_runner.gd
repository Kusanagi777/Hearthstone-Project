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
	print("[WeekRunner] _ready() called")
	
	# Load schedule from GameManager with validation
	if GameManager.has_meta("weekly_schedule"):
		var raw_schedule = GameManager.get_meta("weekly_schedule")
		print("[WeekRunner] Raw schedule from meta: ", raw_schedule, " type: ", typeof(raw_schedule))
		
		# Convert to regular array to avoid type issues
		weekly_schedule = []
		if raw_schedule is Array:
			for item in raw_schedule:
				weekly_schedule.append(str(item))  # Ensure strings
		print("[WeekRunner] Processed schedule: ", weekly_schedule)
	else:
		print("[WeekRunner] WARNING: No weekly_schedule in meta!")
		weekly_schedule = []
	
	if GameManager.has_meta("current_day_index"):
		current_day_index = GameManager.get_meta("current_day_index")
		print("[WeekRunner] Loaded current_day_index: ", current_day_index)
	else:
		print("[WeekRunner] WARNING: No current_day_index in meta, defaulting to 0")
		current_day_index = 0
	
	# Initialize gold if not set
	if not GameManager.has_meta("player_gold"):
		GameManager.set_meta("player_gold", 200)
	
	print("[WeekRunner] Schedule size: %d, Current day: %d" % [weekly_schedule.size(), current_day_index])
	
	# Safety check - if no schedule, redirect to schedule builder
	if weekly_schedule.is_empty():
		print("[WeekRunner] ERROR: Empty schedule! Redirecting to schedule builder...")
		await get_tree().process_frame
		get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		return
	
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
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.16)
	panel_style.border_color = Color(0.4, 0.35, 0.25)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	activity_panel.add_theme_stylebox_override("panel", panel_style)
	main_vbox.add_child(activity_panel)
	
	var activity_vbox = VBoxContainer.new()
	activity_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	activity_vbox.add_theme_constant_override("separation", 15)
	activity_panel.add_child(activity_vbox)
	
	# Center the content
	var center_margin = MarginContainer.new()
	center_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_margin.add_theme_constant_override("margin_left", 30)
	center_margin.add_theme_constant_override("margin_right", 30)
	center_margin.add_theme_constant_override("margin_top", 30)
	center_margin.add_theme_constant_override("margin_bottom", 30)
	activity_panel.add_child(center_margin)
	
	var centered_vbox = VBoxContainer.new()
	centered_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	centered_vbox.add_theme_constant_override("separation", 15)
	center_margin.add_child(centered_vbox)
	
	activity_icon = Label.new()
	activity_icon.text = "⚔️"
	activity_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_icon.add_theme_font_size_override("font_size", 64)
	centered_vbox.add_child(activity_icon)
	
	activity_name = Label.new()
	activity_name.text = "Duel"
	activity_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_name.add_theme_font_size_override("font_size", 28)
	activity_name.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	centered_vbox.add_child(activity_name)
	
	activity_desc = Label.new()
	activity_desc.text = "Fight a standard opponent"
	activity_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_desc.add_theme_font_size_override("font_size", 16)
	activity_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	centered_vbox.add_child(activity_desc)
	
	# Progress dots
	progress_container = HBoxContainer.new()
	progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(progress_container)
	
	# Create progress dots based on schedule size (or 5 if empty)
	var num_dots = weekly_schedule.size() if weekly_schedule.size() > 0 else 5
	for i in range(num_dots):
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
	print("[WeekRunner] _update_display() - day_index: %d, schedule_size: %d" % [current_day_index, weekly_schedule.size()])
	
	# Update gold
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	gold_label.text = str(player_gold)
	
	if current_day_index >= weekly_schedule.size():
		# Week complete!
		print("[WeekRunner] Week complete!")
		day_label.text = "Week Complete!"
		activity_icon.text = "🎉"
		activity_name.text = "All activities finished!"
		activity_desc.text = "Return to schedule builder to plan next week"
		continue_button.text = "Plan Next Week"
		return
	
	# Update day label
	day_label.text = "Day %d of %d" % [current_day_index + 1, weekly_schedule.size()]
	
	# Get current activity with safety check
	var activity_id: String = weekly_schedule[current_day_index]
	print("[WeekRunner] Current activity_id: ", activity_id)
	
	if not activities.has(activity_id):
		print("[WeekRunner] WARNING: Unknown activity_id '%s', defaulting to duel" % activity_id)
		activity_id = "duel"
	
	var activity_data: Dictionary = activities[activity_id]
	
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
		# Reset day index for next week
		GameManager.set_meta("current_day_index", 0)
		get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		return
	
	var activity_id: String = weekly_schedule[current_day_index]
	print("[WeekRunner] Executing activity: ", activity_id)
	
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
	
	print("[WeekRunner] Going to shop, will return to day %d" % current_day_index)
	
	# Go to shop
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")


func _execute_battle(battle_type: String) -> void:
	# Store battle info
	GameManager.set_meta("battle_type", battle_type)
	GameManager.set_meta("return_to_week_runner", true)
	GameManager.set_meta("current_day_index", current_day_index)
	
	print("[WeekRunner] Starting %s battle, will return to day %d" % [battle_type, current_day_index])
	
	# Go to battle
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _advance_day() -> void:
	current_day_index += 1
	GameManager.set_meta("current_day_index", current_day_index)
	
	print("[WeekRunner] Advanced to day %d" % (current_day_index + 1))
	
	_is_transitioning = false
	_update_display()
	
	if current_day_index >= weekly_schedule.size():
		print("[WeekRunner] Week complete!")


func _style_button(button: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.3, 0.4)
	normal_style.border_color = Color(0.5, 0.5, 0.6)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.35, 0.4, 0.5)
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.25, 0.35)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	button.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))


func _on_viewport_size_changed() -> void:
	# Could add responsive scaling here if needed
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Return to start screen
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			# Quick continue
			_on_continue_pressed()
