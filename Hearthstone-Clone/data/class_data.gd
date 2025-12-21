# res://data/class_data.gd
class_name ClassData
extends Resource

## Class identifier
@export var id: String = ""

## Display name
@export var class_name: String = ""

## Class description/flavor text
@export_multiline var description: String = ""

## Class color theme
@export var theme_color: Color = Color.WHITE

## Icon texture (optional)
@export var icon: Texture2D

## Starting health modifier (base is 30)
@export var starting_health: int = 30

## Starting cards in hand modifier
@export var starting_hand_size: int = 3

## Hero power name (for future implementation)
@export var hero_power_name: String = ""

## Hero power description
@export_multiline var hero_power_description: String = ""

## Hero power cost
@export var hero_power_cost: int = 2
