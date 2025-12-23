# res://data/enums/minion_tags.gd
## Minion Tags (Creature Types) - Bitflag Constants
## Use these constants when checking minion types in code
class_name MinionTags

# Bitflag values (powers of 2 for combining)
const NONE: int = 0
const BEAST: int = 1 << 0   # 1
const MECH: int = 1 << 1    # 2
const IDOL: int = 1 << 2    # 4
const UNDEAD: int = 1 << 3  # 8
const DRAGON: int = 1 << 4  # 16

# All tags combined (useful for "any tag" checks)
const ALL: int = BEAST | MECH | IDOL | UNDEAD | DRAGON  # 31


## Check if a tag set contains a specific tag
static func has_tag(tag_set: int, tag: int) -> bool:
	return (tag_set & tag) != 0


## Check if a tag set contains ALL of the specified tags
static func has_all_tags(tag_set: int, required_tags: int) -> bool:
	return (tag_set & required_tags) == required_tags


## Check if a tag set contains ANY of the specified tags
static func has_any_tag(tag_set: int, check_tags: int) -> bool:
	return (tag_set & check_tags) != 0


## Add a tag to a tag set
static func add_tag(tag_set: int, tag: int) -> int:
	return tag_set | tag


## Remove a tag from a tag set
static func remove_tag(tag_set: int, tag: int) -> int:
	return tag_set & ~tag


## Toggle a tag in a tag set
static func toggle_tag(tag_set: int, tag: int) -> int:
	return tag_set ^ tag


## Get a list of tag names from a tag set
static func get_tag_names(tag_set: int) -> Array[String]:
	var names: Array[String] = []
	if has_tag(tag_set, BEAST):
		names.append("Beast")
	if has_tag(tag_set, MECH):
		names.append("Mech")
	if has_tag(tag_set, IDOL):
		names.append("Idol")
	if has_tag(tag_set, UNDEAD):
		names.append("Undead")
	if has_tag(tag_set, DRAGON):
		names.append("Dragon")
	return names


## Get a formatted string of all tags (e.g., "Beast, Mech")
static func get_tag_string(tag_set: int) -> String:
	var names := get_tag_names(tag_set)
	if names.is_empty():
		return ""
	return ", ".join(names)


## Get the tag constant from a tag name string
static func get_tag_from_name(tag_name: String) -> int:
	match tag_name.to_lower():
		"beast":
			return BEAST
		"mech":
			return MECH
		"idol":
			return IDOL
		"undead":
			return UNDEAD
		"dragon":
			return DRAGON
		_:
			return NONE


## Count how many tags are set
static func count_tags(tag_set: int) -> int:
	var count := 0
	if has_tag(tag_set, BEAST): count += 1
	if has_tag(tag_set, MECH): count += 1
	if has_tag(tag_set, IDOL): count += 1
	if has_tag(tag_set, UNDEAD): count += 1
	if has_tag(tag_set, DRAGON): count += 1
	return count
