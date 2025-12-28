# res://data/card_data.gd
class_name CardData
extends Resource

## Enumeration for card types (simplified - no locations or class powers)
enum CardType {
	MINION,
	ACTION
}

## Enumeration for card rarity
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

## Minion Tags - Bitflag constants for minion types
class MinionTags:
	const NONE: int = 0
	const BEAST: int = 1 << 0     # 1
	const MECH: int = 1 << 1      # 2
	const IDOL: int = 1 << 2      # 4
	const UNDEAD: int = 1 << 3    # 8
	const DRAGON: int = 1 << 4    # 16
	const ALL: int = BEAST | MECH | IDOL | UNDEAD | DRAGON

## Unique identifier for this card
@export var id: String = ""

## Display name shown on the card
@export var card_name: String = ""

## Mana cost to play this card
@export_range(0, 10) var cost: int = 0

## Base attack value (for minions)
@export_range(0, 20) var attack: int = 0

## Base health value (for minions)
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
## KEYWORDS:
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
## "Bully"       - Bonus effect when attacking weaker target
## "Huddle"      - Can be played in occupied space, buffs front minion
## "Ritual"      - Optionally sacrifice friendly minions for bonus effect
## "Fated"       - Bonus effect if played same turn as drawn
@export var keywords: Array[String] = []

## Minion type tags (Beast, Mech, Idol, Undead, Dragon) - stored as bitflags
@export var minion_tags: int = MinionTags.NONE

## Runtime-only fields (not saved to resource)
var _runtime_id: String = ""


## =============================================================================
## INITIALIZATION
## =============================================================================

func _init() -> void:
	_runtime_id = ""


## Create a duplicate for actual gameplay (preserves original resource)
func duplicate_for_play() -> CardData:
	var copy := self.duplicate(true) as CardData
	copy._runtime_id = _generate_runtime_id()
	return copy


func _generate_runtime_id() -> String:
	return "%s_%d_%d" % [id, Time.get_ticks_msec(), randi()]


## Get the runtime unique ID (for tracking specific card instances)
func get_runtime_id() -> String:
	if _runtime_id.is_empty():
		_runtime_id = _generate_runtime_id()
	return _runtime_id


## =============================================================================
## KEYWORD HELPER FUNCTIONS
## =============================================================================

## Check if card has a specific keyword
func has_keyword(keyword: String) -> bool:
	return keywords.has(keyword.to_lower()) or keywords.has(keyword.capitalize())


## Add a keyword
func add_keyword(keyword: String) -> void:
	var kw := keyword.to_lower()
	if not keywords.has(kw):
		keywords.append(kw)


## Remove a keyword
func remove_keyword(keyword: String) -> void:
	var kw := keyword.to_lower()
	keywords.erase(kw)
	keywords.erase(keyword.capitalize())


## Get keyword tooltip description
func get_keyword_description(keyword: String) -> String:
	match keyword.to_lower():
		"charge":
			return "Can attack when summoned."
		"taunt":
			return "Opposing minions cannot select another minion who shares a row with this minion as a target."
		"shielded":
			return "The next instance of damage is reduced to 0."
		"aggressive":
			return "This minion can attack twice in 1 turn."
		"drain":
			return "Damage dealt is restored to the player who controls this card."
		"lethal":
			return "Minions damaged by this card are destroyed."
		"on-play":
			return "When this minion is summoned, an effect takes place."
		"on-death":
			return "When this minion is destroyed, an effect takes place."
		"rush":
			return "Can attack minions the turn it is summoned, but cannot attack heroes."
		"hidden":
			return "This card cannot be targeted by opponent's cards."
		"persistent":
			return "When destroyed, returns to life with 1 Health (once)."
		"snipe":
			return "Can attack back row minions regardless of front row. Can attack from back row."
		"draft":
			return "Choose one of three randomly selected cards."
		"bully":
			return "Bonus effect triggers when attacking a target with less Attack than this minion."
		"huddle":
			return "Can be played in an occupied space. Buffs the front minion and takes over when it dies."
		"ritual":
			return "Optionally sacrifice friendly minions to trigger a bonus effect."
		"fated":
			return "Bonus effect triggers if played the same turn it was drawn."
		_:
			return ""


## Get ritual sacrifice cost (for cards with Ritual keyword)
func get_ritual_cost() -> int:
	if not has_keyword("ritual"):
		return 0
	# Default ritual cost is 1, can be overridden in description parsing
	return 1


## =============================================================================
## MINION TAG HELPER FUNCTIONS
## =============================================================================

## Check if this card has a specific minion tag
func has_minion_tag(tag: int) -> bool:
	return (minion_tags & tag) != 0


## Add a minion tag
func add_minion_tag(tag: int) -> void:
	minion_tags |= tag


## Remove a minion tag
func remove_minion_tag(tag: int) -> void:
	minion_tags &= ~tag


## Get all minion tags as an array of strings
func get_minion_tag_names() -> Array[String]:
	var names: Array[String] = []
	if has_minion_tag(MinionTags.BEAST):
		names.append("Beast")
	if has_minion_tag(MinionTags.MECH):
		names.append("Mech")
	if has_minion_tag(MinionTags.IDOL):
		names.append("Idol")
	if has_minion_tag(MinionTags.UNDEAD):
		names.append("Undead")
	if has_minion_tag(MinionTags.DRAGON):
		names.append("Dragon")
	return names


## =============================================================================
## CARD TYPE HELPERS
## =============================================================================

## Get display string for card type
func get_type_string() -> String:
	match card_type:
		CardType.MINION:
			var type_parts: Array[String] = get_minion_tag_names()
			if type_parts.is_empty():
				return "Minion"
			return " ".join(type_parts) + " Minion"
		CardType.ACTION:
			return "Action"
		_:
			return "Unknown"


## Check if this is a minion card
func is_minion() -> bool:
	return card_type == CardType.MINION


## Check if this is an action card
func is_action() -> bool:
	return card_type == CardType.ACTION


## =============================================================================
## UTILITY
## =============================================================================

## Get formatted description with keyword highlights
func get_formatted_description() -> String:
	var result := description
	
	# Bold keywords in description
	for kw in keywords:
		var capitalized := kw.capitalize()
		result = result.replace(capitalized, "[b]%s[/b]" % capitalized)
	
	return result


## Debug string representation
func _to_string() -> String:
	return "[CardData: %s (%d/%d) Cost:%d]" % [card_name, attack, health, cost]
