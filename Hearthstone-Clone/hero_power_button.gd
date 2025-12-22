# res://scripts/hero_power_button.gd
extends Button

var power_data: Dictionary = {}
var is_used_this_turn: bool = false
var player_id: int = 0

func _ready() -> void:
	# Listen for turn start to refresh the power
	GameManager.turn_started.connect(_on_turn_started)
	# Listen for mana changes to update availability (enable/disable)
	GameManager.mana_changed.connect(_on_mana_changed)
	
	pressed.connect(_on_pressed)

func setup(data: Dictionary, owner_id: int) -> void:
	power_data = data
	player_id = owner_id
	
	# Visual Setup
	text = "%s\n(%d)" % [data.get("name", "Power"), data.get("cost", 2)]
	tooltip_text = data.get("description", "")
	
	# Initial State
	disabled = true # Default to disabled until turn starts/mana checked

func _on_pressed() -> void:
	if is_used_this_turn:
		return
		
	var cost = power_data.get("cost", 2)
	var current_mana = GameManager.get_current_mana(player_id)
	
	if current_mana >= cost:
		_execute_power(cost)
	else:
		print("Not enough mana!")

func _execute_power(cost: int) -> void:
	# 1. Pay Mana
	# We need a way to spend mana in GameManager. 
	# For now, we manually access the data or add a method in GameManager.
	# Accessing internal dictionary directly for this example (ideal: add spend_mana method to GM)
	GameManager.players[player_id]["current_mana"] -= cost
	GameManager.mana_changed.emit(player_id, GameManager.players[player_id]["current_mana"], GameManager.players[player_id]["max_mana"])
	
	# 2. Mark Used
	is_used_this_turn = true
	disabled = true
	
	# 3. Perform Effect
	# logic depends on the 'id' from hero_power_selection.gd
	var power_id = power_data.get("id", "unknown")
	print("[HeroPower] Player %d used %s!" % [player_id, power_id])
	
	# TODO: Implement actual effects here or emit a signal
	# match power_id:
	# 	"armor_up": ...
	# 	"fireblast": ...

func _on_turn_started(active_player_id: int) -> void:
	if active_player_id == player_id:
		is_used_this_turn = false
		_check_availability()
	else:
		disabled = true

func _on_mana_changed(p_id: int, current: int, _max: int) -> void:
	if p_id == player_id:
		_check_availability()

func _check_availability() -> void:
	# Only active if: It's my turn, haven't used it yet, have enough mana
	var is_my_turn = GameManager.is_player_turn(player_id)
	var cost = power_data.get("cost", 2)
	var current_mana = GameManager.get_current_mana(player_id)
	
	disabled = not (is_my_turn and not is_used_this_turn and current_mana >= cost)

func _exit_tree() -> void:
	# Clean up signals to avoid errors if node is removed
	if GameManager.turn_started.is_connected(_on_turn_started):
		GameManager.turn_started.disconnect(_on_turn_started)
	if GameManager.mana_changed.is_connected(_on_mana_changed):
		GameManager.mana_changed.disconnect(_on_mana_changed)
