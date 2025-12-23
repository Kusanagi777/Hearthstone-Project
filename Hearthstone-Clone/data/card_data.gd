# res://data/CardData.gd
class_name CardData
extends Resource

## Enumeration for card types
enum CardType {
	MINION,
	ACTION,
	LOCATION,
	CLASS_POWER
}

## Enumeration for card rarity
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Unique identifier for this card
@export var id: String = ""

## Display name shown on the card
@export var card_name: String = ""

## Mana cost to play this card
@export_range(0, 10) var cost: int = 0

## Base attack value (for minions and locations)
@export_range(0, 20) var attack: int = 0

## Base health value (for minions and locations)
@export_range(0, 20) var health: int = 0

## Card type determines behavior and valid targets
@export var card_type: CardType = CardType.MINION

## Rarity affects visual styling and deck limits
@export var rarity: Rarity = Rarity.COMMON

## Card art displayed in the frame
@export var texture: Texture2D

## Description text - supports BBCode for formatting
@export_multiline var description: String = ""

## Tags/Keywords for special abilities
## YOUR CUSTOM KEYWORDS:
## "Charge"      - Can attack when summoned
## "Taunt"       - Protects other minions in the same row from being targeted
## "Shielded"    - Next damage instance is reduced to 0
## "Aggressive"  - Can attack twice per turn
## "Drain"       - Damage dealt heals your hero
## "Lethal"      - Any damage dealt destroys the target minion
## "On-play"     - Effect triggers when summoned (Battlecry)
## "On-death"    - Effect triggers when destroyed (Deathrattle)
## "Rush"        - Can attack minions (not heroes) when summoned
## "Hidden"      - Cannot be targeted by opponent's cards
## "Persistent"  - Returns with 1 HP when destroyed, then loses this keyword
## "Snipe"       - Can target/attack back row regardless of front row
## "Draft"       - Player chooses from 3 cards, places result on field/hand/deck
@export var tags: Array[String] = []

## Optional: Script path for custom card effects
@export_file("*.gd") var effect_script: String = ""

## Targeting requirement for actions
@export_enum("None", "Minion", "EnemyMinion", "FriendlyMinion", "Character", "Hero") var target_type: String = "None"

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
	copy.texture = texture
	copy.description = description
	copy.tags = tags.duplicate()
	copy.effect_script = effect_script
	copy.target_type = target_type
	return copy

## Get formatted description with keyword highlighting
func get_formatted_description() -> String:
	var formatted := description
	
	# YOUR CUSTOM KEYWORD LIST
	var keywords := [
		"Charge",      # Can attack when summoned
		"Taunt",       # Protects row-mates from targeting
		"Shielded",    # Absorbs first damage
		"Aggressive",  # Attack twice per turn
		"Drain",       # Heal on damage dealt
		"Lethal",      # Instant kill on damage
		"On-play",     # Battlecry effect
		"On-death",    # Deathrattle effect
		"Rush",        # Attack minions on summon
		"Hidden",      # Cannot be targeted
		"Persistent",  # Respawn with 1 HP
		"Snipe",       # Target back row
		"Draft",       # Choose from 3 cards
	]
	
	for keyword in keywords:
		formatted = formatted.replace(keyword, "[b]%s[/b]" % keyword)
	
	return formatted

## Get list of all keywords this card has
func get_keywords() -> Array[String]:
	var found_keywords: Array[String] = []
	var all_keywords := [
		"Charge", "Taunt", "Shielded", "Aggressive", "Drain",
		"Lethal", "On-play", "On-death", "Rush", "Hidden", 
		"Persistent", "Snipe", "Draft"
	]
	
	for keyword in all_keywords:
		if keyword in tags:
			found_keywords.append(keyword)
	
	return found_keywords


## Get keyword tooltip/explanation
static func get_keyword_tooltip(keyword: String) -> String:
	match keyword:
		"Charge":
			return "Can attack like normal when summoned."
		"Taunt":
			return "Opposing minions cannot select another minion who shares a row with this minion as a target."
		"Shielded":
			return "The next instance of damage is reduced to 0."
		"Aggressive":
			return "This minion can attack twice in 1 turn."
		"Drain":
			return "Damage dealt is restored to the player who controls this card."
		"Lethal":
			return "Minions damaged by this card are destroyed."
		"On-play":
			return "When this minion is summoned, an effect takes place."
		"On-death":
			return "When this minion is destroyed, an effect takes place."
		"Rush":
			return "Can attack minions or locations the turn it is summoned, but cannot attack heroes."
		"Hidden":
			return "This card cannot be targeted by opponent's cards."
		"Persistent":
			return "When this card is destroyed, it immediately returns with 1 health and loses the Persistent keyword."
		"Snipe":
			return "This card can target cards in the back row regardless of other minions on the board."
		"Draft":
			return "The player is presented 3 cards from a pool and selects 1. The card may be summoned, added to hand, or shuffled into a deck."
		_:
			return ""
