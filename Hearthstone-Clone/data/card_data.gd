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

## =============================================================================
## MINION TAGS (Creature Types) - Only applies to MINION card_type
## Select multiple creature types using checkboxes in the Inspector
## Values: NONE=0, BEAST=1, MECH=2, IDOL=4, UNDEAD=8, DRAGON=16
## =============================================================================
@export_flags("Beast:1", "Mech:2", "Idol:4", "Undead:8", "Dragon:16") var minion_tags: int = 0

## =============================================================================
## BIOME TAGS (Location Types) - Only applies to LOCATION card_type
## Select multiple biome types using checkboxes in the Inspector
## Values: NONE=0, ARENA=1, LAB=2, STAGE=4, CRYPT=8, SANCTUARY=16
## =============================================================================
@export_flags("Arena:1", "Lab:2", "Stage:4", "Crypt:8", "Sanctuary:16") var biome_tags: int = 0

## Optional: Script path for custom card effects
@export_file("*.gd") var effect_script: String = ""

## Targeting requirement for actions
@export_enum("None", "Minion", "EnemyMinion", "FriendlyMinion", "Character", "Hero") var target_type: String = "None"


## =============================================================================
## KEYWORD FUNCTIONS
## =============================================================================

## Check if card has a specific keyword
func has_keyword(keyword: String) -> bool:
	return keyword in tags


## =============================================================================
## MINION TAG FUNCTIONS (Creature Types)
## =============================================================================

## Check if this minion has a specific creature tag
func has_minion_tag(tag: int) -> bool:
	return (minion_tags & tag) != 0


## Check if this minion has ALL of the specified tags
func has_all_minion_tags(required_tags: int) -> bool:
	return (minion_tags & required_tags) == required_tags


## Check if this minion has ANY of the specified tags
func has_any_minion_tag(check_tags: int) -> bool:
	return (minion_tags & check_tags) != 0


## Get array of minion tag names for this card
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


## Get formatted string of minion tags (e.g., "Beast, Mech")
func get_minion_tag_string() -> String:
	var names := get_minion_tag_names()
	if names.is_empty():
		return ""
	return ", ".join(names)


## =============================================================================
## BIOME TAG FUNCTIONS (Location Types)
## =============================================================================

## Check if this location has a specific biome tag
func has_biome_tag(biome: int) -> bool:
	return (biome_tags & biome) != 0


## Check if this location has ALL of the specified biomes
func has_all_biome_tags(required_biomes: int) -> bool:
	return (biome_tags & required_biomes) == required_biomes


## Check if this location has ANY of the specified biomes
func has_any_biome_tag(check_biomes: int) -> bool:
	return (biome_tags & check_biomes) != 0


## Get array of biome tag names for this card
func get_biome_tag_names() -> Array[String]:
	var names: Array[String] = []
	if has_biome_tag(BiomeTags.ARENA):
		names.append("Arena")
	if has_biome_tag(BiomeTags.LAB):
		names.append("Lab")
	if has_biome_tag(BiomeTags.STAGE):
		names.append("Stage")
	if has_biome_tag(BiomeTags.CRYPT):
		names.append("Crypt")
	if has_biome_tag(BiomeTags.SANCTUARY):
		names.append("Sanctuary")
	return names


## Get formatted string of biome tags (e.g., "Arena, Crypt")
func get_biome_tag_string() -> String:
	var names := get_biome_tag_names()
	if names.is_empty():
		return ""
	return ", ".join(names)


## =============================================================================
## TYPE LINE GENERATION
## =============================================================================

## Get the full type line for display (e.g., "Minion - Beast, Dragon")
func get_type_line() -> String:
	match card_type:
		CardType.MINION:
			var tag_str := get_minion_tag_string()
			if tag_str.is_empty():
				return "Minion"
			return "Minion - " + tag_str
		CardType.LOCATION:
			var biome_str := get_biome_tag_string()
			if biome_str.is_empty():
				return "Location"
			return "Location - " + biome_str
		CardType.ACTION:
			return "Action"
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


## =============================================================================
## TAG TOOLTIPS
## =============================================================================

## Get minion tag tooltip/explanation
static func get_minion_tag_tooltip(tag_name: String) -> String:
	match tag_name.to_lower():
		"beast":
			return "A creature of the wild. Synergizes with Arena locations."
		"mech":
			return "A mechanical construct. Synergizes with Lab locations."
		"idol":
			return "A performer or celebrity. Synergizes with Stage locations."
		"undead":
			return "A creature risen from death. Synergizes with Crypt locations."
		"dragon":
			return "An ancient and powerful creature. Synergizes with Sanctuary locations."
		_:
			return ""


## Get biome tag tooltip/explanation
static func get_biome_tag_tooltip(biome_name: String) -> String:
	match biome_name.to_lower():
		"arena":
			return "A battleground for combat. Beasts thrive here."
		"lab":
			return "A place of science and technology. Mechs are empowered here."
		"stage":
			return "A venue for performance. Idols shine here."
		"crypt":
			return "A dark resting place for the dead. Undead rise here."
		"sanctuary":
			return "An ancient holy place. Dragons find power here."
		_:
			return ""
