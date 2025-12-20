# res://resources/CardData.gd
@tool
class_name CardData
extends Resource

## Enumeration for card types
enum CardType {
	MINION,
	SPELL,
	WEAPON,
	HERO_POWER
}

## Enumeration for card rarity
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Enumeration for spell schools (for potential synergies)
enum SpellSchool {
	NONE,
	FIRE,
	FROST,
	NATURE,
	ARCANE,
	HOLY,
	SHADOW,
	FEL
}

## Unique identifier for this card
@export var id: String = ""

## Display name shown on the card
@export var card_name: String = ""

## Mana cost to play this card
@export_range(0, 10) var cost: int = 0

## Base attack value (for minions and weapons)
@export_range(0, 20) var attack: int = 0

## Base health value (for minions) or durability (for weapons)
@export_range(0, 20) var health: int = 0

## Card type determines behavior and valid targets
@export var card_type: CardType = CardType.MINION

## Rarity affects visual styling and deck limits
@export var rarity: Rarity = Rarity.COMMON

## Spell school for spell cards
@export var spell_school: SpellSchool = SpellSchool.NONE

## Card art displayed in the frame
@export var texture: Texture2D

## Description text - supports BBCode for formatting
@export_multiline var description: String = ""

## Tags/Keywords for special abilities
## Valid keywords: Charge, Taunt, Divine Shield, Windfury, Lifesteal, Poisonous,
## Battlecry, Deathrattle, Rush, Stealth, Reborn
@export var tags: Array[String] = []

## Optional: Script path for custom card effects
@export_file("*.gd") var effect_script: String = ""

## Targeting requirement for spells
@export_enum("None", "Minion", "EnemyMinion", "FriendlyMinion", "Character", "Hero") var target_type: String = "None"


## Validates the resource data in the editor
func _validate_property(property: Dictionary) -> void:
	if property.name in ["attack", "health"]:
		if card_type == CardType.SPELL:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if property.name == "spell_school":
		if card_type != CardType.SPELL:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	
	if property.name == "target_type":
		if card_type != CardType.SPELL:
			property.usage = PROPERTY_USAGE_NO_EDITOR


## Check if card has a specific keyword
func has_keyword(keyword: String) -> bool:
	return keyword in tags


## Creates a runtime copy of this card data
func duplicate_for_play() -> CardData:
	var copy := CardData.new()
	copy.id = id + "_" + str(randi())  # Unique instance ID
	copy.card_name = card_name
	copy.cost = cost
	copy.attack = attack
	copy.health = health
	copy.card_type = card_type
	copy.rarity = rarity
	copy.spell_school = spell_school
	copy.texture = texture
	copy.description = description
	copy.tags = tags.duplicate()
	copy.effect_script = effect_script
	copy.target_type = target_type
	return copy


## Get formatted description with keyword highlighting
func get_formatted_description() -> String:
	var formatted := description
	var keywords := ["Charge", "Taunt", "Divine Shield", "Windfury", "Lifesteal", 
					 "Poisonous", "Battlecry", "Deathrattle", "Rush", "Stealth", "Reborn"]
	
	for keyword in keywords:
		formatted = formatted.replace(keyword, "[b]%s[/b]" % keyword)
	
	return formatted
