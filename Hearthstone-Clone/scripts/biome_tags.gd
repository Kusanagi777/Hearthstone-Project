# res://data/enums/biome_tags.gd
## Biome Tags (Location Types) - Bitflag Constants
## Use these constants when checking location biomes in code
class_name BiomeTags

# Bitflag values (powers of 2 for combining)
const NONE: int = 0
const ARENA: int = 1 << 0      # 1
const LAB: int = 1 << 1        # 2
const STAGE: int = 1 << 2      # 4
const CRYPT: int = 1 << 3      # 8
const SANCTUARY: int = 1 << 4  # 16

# All biomes combined (useful for "any biome" checks)
const ALL: int = ARENA | LAB | STAGE | CRYPT | SANCTUARY  # 31


## Check if a biome set contains a specific biome
static func has_biome(biome_set: int, biome: int) -> bool:
	return (biome_set & biome) != 0


## Check if a biome set contains ALL of the specified biomes
static func has_all_biomes(biome_set: int, required_biomes: int) -> bool:
	return (biome_set & required_biomes) == required_biomes


## Check if a biome set contains ANY of the specified biomes
static func has_any_biome(biome_set: int, check_biomes: int) -> bool:
	return (biome_set & check_biomes) != 0


## Add a biome to a biome set
static func add_biome(biome_set: int, biome: int) -> int:
	return biome_set | biome


## Remove a biome from a biome set
static func remove_biome(biome_set: int, biome: int) -> int:
	return biome_set & ~biome


## Toggle a biome in a biome set
static func toggle_biome(biome_set: int, biome: int) -> int:
	return biome_set ^ biome


## Get a list of biome names from a biome set
static func get_biome_names(biome_set: int) -> Array[String]:
	var names: Array[String] = []
	if has_biome(biome_set, ARENA):
		names.append("Arena")
	if has_biome(biome_set, LAB):
		names.append("Lab")
	if has_biome(biome_set, STAGE):
		names.append("Stage")
	if has_biome(biome_set, CRYPT):
		names.append("Crypt")
	if has_biome(biome_set, SANCTUARY):
		names.append("Sanctuary")
	return names


## Get a formatted string of all biomes (e.g., "Arena, Lab")
static func get_biome_string(biome_set: int) -> String:
	var names := get_biome_names(biome_set)
	if names.is_empty():
		return ""
	return ", ".join(names)


## Get the biome constant from a biome name string
static func get_biome_from_name(biome_name: String) -> int:
	match biome_name.to_lower():
		"arena":
			return ARENA
		"lab":
			return LAB
		"stage":
			return STAGE
		"crypt":
			return CRYPT
		"sanctuary":
			return SANCTUARY
		_:
			return NONE


## Count how many biomes are set
static func count_biomes(biome_set: int) -> int:
	var count := 0
	if has_biome(biome_set, ARENA): count += 1
	if has_biome(biome_set, LAB): count += 1
	if has_biome(biome_set, STAGE): count += 1
	if has_biome(biome_set, CRYPT): count += 1
	if has_biome(biome_set, SANCTUARY): count += 1
	return count


## Get the matching minion tag for this biome (for synergy checks)
static func get_synergy_minion_tag(biome: int) -> int:
	match biome:
		ARENA:
			return MinionTags.BEAST
		LAB:
			return MinionTags.MECH
		STAGE:
			return MinionTags.IDOL
		CRYPT:
			return MinionTags.UNDEAD
		SANCTUARY:
			return MinionTags.DRAGON
		_:
			return MinionTags.NONE
