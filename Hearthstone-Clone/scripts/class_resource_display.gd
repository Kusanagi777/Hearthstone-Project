class_name ClassResourceDisplay
extends PanelContainer

## References to internal nodes
@onready var icon_rect: TextureRect = $HBoxContainer/Icon
@onready var label: Label = $HBoxContainer/Label

## Color definitions for each class theme
const CLASS_COLORS = {
	"cute": Color("ff77a8"),      # Pink
	"technical": Color("00e436"), # Cyber Green
	"primal": Color("ff4400"),    # Beastly Orange/Red
	"other": Color("bd93f9"),     # Void Purple
	"ace": Color("f1fa8c"),       # Spirit Yellow
	"neutral": Color("6272a4")    # Grey
}

## Icon placeholders (You can replace these with real texture loads later)
## For now, we will just tint the placeholder icon
func _ready() -> void:
	visible = false # Hide by default until updated

## Updates the display based on the class and values
func update_display(class_id: String, current: int, max_val: int) -> void:
	if class_id == "" or class_id == "neutral":
		visible = false
		return
	
	visible = true
	var pid = class_id.to_lower()
	
	# 1. Set Color Theme
	var theme_color = CLASS_COLORS.get(pid, Color.WHITE)
	self_modulate = theme_color
	
	# 2. Set Text
	var resource_name = _get_resource_name(pid)
	
	if max_val > 900:
		# Unlimited resources (like Fans)
		label.text = "%s: %d" % [resource_name, current]
	else:
		# Capped resources (like Battery 5/10)
		label.text = "%s: %d/%d" % [resource_name, current, max_val]

## Helper to get display name
func _get_resource_name(id: String) -> String:
	match id:
		"cute": return "Fans"
		"technical": return "Battery"
		"primal": return "Hunger"
		"other": return "Omen"
		"ace": return "Spirit"
		_: return "Resource"
