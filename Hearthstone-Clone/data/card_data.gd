# res://data/card_data.gd
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
## NEW KEYWORDS:
## "Bully"       - Bonus effect when attacking targets with less Attack
## "Overclock"   - Spend Battery charges for bonus effect (Technical class)
## "Huddle"      - Can be played in occupied space, buffs front minion
## "Ritual"      - Sacrifice friendly minions for bonus effect
## "Fated"       - Bonus effect if played the turn it was drawn
@export var tags: Array[String] = []

## =============================================================================
## MINION TAGS (Creature Types) - Only applies to MINION card_type
## Select multiple creature types using checkboxes in the Inspector
## Values: NONE=0, BEAST=1, MECH=2, IDOL=4, UNDEAD=8, DRAGON=16
## =============================================================================
enum MinionTags {
	NONE = 0,
	BEAST = 1,
	MECH = 2,
	IDOL = 4,
	UNDEAD = 8,
	DRAGON = 16
}

@export_flags("Beast:1", "Mech:2", "Idol:4", "Undead:8", "Dragon:16") var minion_tags: int = 0

## =============================================================================
## BIOME TAGS - For location cards or biome-specific effects
## Values: NONE=0, FOREST=1, MOUNTAIN=2, DESERT=4, SWAMP=8, URBAN=16
## =============================================================================
enum BiomeTags {
	NONE = 0,
	FOREST = 1,
	MOUNTAIN = 2,
	DESERT = 4,
	SWAMP = 8,
	URBAN = 16
}

@export_flags("Forest:1", "Mountain:2", "Desert:4", "Swamp:8", "Urban:16") var biome_tags: int = 0

## Optional: Path to a custom effect script for complex card behaviors
@export var effect_script: String = ""

## Target type for spells/abilities
enum TargetType {
	NONE,
	FRIENDLY_MINION,
	ENEMY_MINION,
	ANY_MINION,
	HERO,
	ANY
}

@export var target_type: TargetType = TargetType.NONE


## =============================================================================
## KEYWORD HELPER FUNCTIONS
## =============================================================================

## Check if this card has a specific keyword (case-insensitive)
func has_keyword(keyword: String) -> bool:
	for tag in tags:
		if tag.to_lower() == keyword.to_lower():
			return true
		# Also check for keywords with parameters like "Overclock (3)"
		if tag.to_lower().begins_with(keyword.to_lower()):
			return true
	return false


## Add a keyword tag
func add_keyword(keyword: String) -> void:
	if not has_keyword(keyword):
		tags.append(keyword)


## Remove a keyword tag
func remove_keyword(keyword: String) -> void:
	for i in range(tags.size() - 1, -1, -1):
		if tags[i].to_lower() == keyword.to_lower():
			tags.remove_at(i)
		elif tags[i].to_lower().begins_with(keyword.to_lower()):
			tags.remove_at(i)


## Get Overclock cost from tag (e.g., "Overclock (3)" returns 3)
func get_overclock_cost() -> int:
	for tag in tags:
		if tag.to_lower().begins_with("overclock"):
			var regex := RegEx.new()
			regex.compile("\\((\\d+)\\)")
			var result := regex.search(tag)
			if result:
				return int(result.get_string(1))
	return 0


## Get Ritual cost from tag (e.g., "Ritual (2)" returns 2)
func get_ritual_cost() -> int:
	for tag in tags:
		if tag.to_lower().begins_with("ritual"):
			var regex := RegEx.new()
			regex.compile("\\((\\d+)\\)")
			var result := regex.search(tag)
			if result:
				return int(result.get_string(1))
	# Default to 1 if no number specified
	if has_keyword("Ritual"):
		return 1
	return 0

## =============================================================================
## MINION TAG HELPER FUNCTIONS
## =============================================================================

## Check if this minion has a specific creature type
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
## BIOME TAG HELPER FUNCTIONS
## =============================================================================

## Check if this card has a specific biome tag
func has_biome_tag(tag: int) -> bool:
	return (biome_tags & tag) != 0


## Add a biome tag
func add_biome_tag(tag: int) -> void:
	biome_tags |= tag


## Remove a biome tag
func remove_biome_tag(tag: int) -> void:
	biome_tags &= ~tag


## Get all biome tags as an array of strings
func get_biome_tag_names() -> Array[String]:
	var names: Array[String] = []
	if has_biome_tag(BiomeTags.FOREST):
		names.append("Forest")
	if has_biome_tag(BiomeTags.MOUNTAIN):
		names.append("Mountain")
	if has_biome_tag(BiomeTags.DESERT):
		names.append("Desert")
	if has_biome_tag(BiomeTags.SWAMP):
		names.append("Swamp")
	if has_biome_tag(BiomeTags.URBAN):
		names.append("Urban")
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
		CardType.LOCATION:
			return "Location"
		CardType.CLASS_POWER:
			return "Class Power"
		_:
			return "Card"


## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

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
	copy.minion_tags = minion_tags
	copy.biome_tags = biome_tags
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
		# NEW KEYWORDS
		"Bully",       # Bonus vs weaker targets
		"Overclock",   # Spend Battery for bonus
		"Huddle",      # Play in occupied space
		"Ritual",      # Sacrifice minions for bonus
		"Fated",       # Bonus if played when drawn
	]
	
	for keyword in keywords:
		# Handle keywords with parameters like "Overclock (3)" or "Ritual (2)"
		var regex := RegEx.new()
		regex.compile("(?i)(" + keyword + "\\s*(?:\\(\\d+\\))?)")
		var results := regex.search_all(formatted)
		for result in results:
			var matched_text := result.get_string(1)
			formatted = formatted.replace(matched_text, "[b]%s[/b]" % matched_text)
	
	return formatted


## Get list of all keywords this card has
func get_keywords() -> Array[String]:
	var found_keywords: Array[String] = []
	var all_keywords := [
		"Charge", "Taunt", "Shielded", "Aggressive", "Drain",
		"Lethal", "On-play", "On-death", "Rush", "Hidden", 
		"Persistent", "Snipe", "Draft",
		"Bully", "Overclock", "Huddle", "Ritual", "Fated"
	]
	
	for keyword in all_keywords:
		if has_keyword(keyword):
			found_keywords.append(keyword)
	
	return found_keywords


## Get keyword tooltip/explanation
static func get_keyword_tooltip(keyword: String) -> String:
	match keyword.to_lower():
		"charge":
			return "Can attack like normal when summoned."
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
			return "Can attack minions or locations the turn it is summoned, but cannot attack heroes."
		"hidden":
			return "This card cannot be targeted by opponent's cards."
		"persistent":
			return "When destroyed, returns to life with 1 Health (once)."
		"snipe":
			return "Can attack back row minions regardless of front row. Can attack from back row."
		"draft":
			return "Choose one of three randomly selected cards."
		# NEW KEYWORDS
		"bully":
			return "Bonus effect triggers when attacking a target with less Attack than this minion."
		"overclock":
			return "Spend Battery charges to trigger an additional effect. (Technical class)"
		"huddle":
			return "Can be played in an occupied space. Buffs the front minion and takes over when it dies."
		"ritual":
			return "Optionally sacrifice friendly minions to trigger a bonus effect."
		"fated":
			return "Bonus effect triggers if played the same turn it was drawn."
		_:
			return ""
