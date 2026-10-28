extends RefCounted
## Equipment: drops after victories, rarity, stat bonuses and auto-equip.

const SLOTS := ["weapon", "armor", "amulet"]
const SLOT_NAMES := {"weapon": "Клинок", "armor": "Доспех", "amulet": "Амулет"}
const SLOT_STAT := {"weapon": "atk", "armor": "hp", "amulet": "spd"}
const STAT_NAMES := {"atk": "АТК", "hp": "HP", "spd": "СКР"}
const RARITY_NAMES := ["Обычный", "Редкий", "Эпический", "Легендарный"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.85), Color(0.4, 0.7, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.7, 0.2)]
const RARITY_BONUS := [0.05, 0.10, 0.18, 0.30]
# Amulets give speed, which is strong, so their bonus is halved.
const AMULET_FACTOR := 0.5
const INVENTORY_CAP := 30

# Which hero gets the best item of each slot first.
const PRIORITY := {
	"weapon": ["akira", "kae", "ryu", "yuki", "ren", "isa", "tetsuo", "mira"],
	"armor": ["ryu", "yuki", "akira", "kae", "tetsuo", "mira", "ren", "isa"],
	"amulet": ["yuki", "akira", "kae", "ryu", "mira", "ren", "isa", "tetsuo"],
}


## Rolls a drop for a won stage. Returns an empty Dictionary when nothing drops.
static func roll_drop(stage: int, rng: RandomNumberGenerator, guaranteed: bool = false) -> Dictionary:
	var is_boss := stage % 10 == 0
	if not is_boss and not guaranteed and rng.randf() > 0.6:
		return {}
	var r := rng.randf()
	var rarity := 0
	if r < 0.03:
		rarity = 3
	elif r < 0.15:
		rarity = 2
	elif r < 0.45:
		rarity = 1
	if is_boss:
		rarity = maxi(rarity, 2)
	var slot: String = SLOTS[rng.randi() % SLOTS.size()]
	var bonus: float = RARITY_BONUS[rarity] * (1.0 + stage * 0.02)
	if slot == "amulet":
		bonus *= AMULET_FACTOR
	return {"slot": slot, "rarity": rarity, "bonus": snappedf(bonus, 0.01)}


static func item_name(item: Dictionary) -> String:
	return "%s %s" % [RARITY_NAMES[item["rarity"]], SLOT_NAMES[item["slot"]].to_lower()]


static func item_label(item: Dictionary) -> String:
	return "%s (+%d%% %s)" % [item_name(item), roundi(item["bonus"] * 100), STAT_NAMES[SLOT_STAT[item["slot"]]]]


## Applies a hero's equipped items ({slot: item}) to a fresh Unit.
static func apply(unit, gear: Dictionary) -> void:
	for slot in gear:
		var item: Dictionary = gear[slot]
		var mult := 1.0 + float(item["bonus"])
		match SLOT_STAT[slot]:
			"atk":
				unit.atk *= mult
			"hp":
				unit.max_hp = round(unit.max_hp * mult)
				unit.hp = unit.max_hp
			"spd":
				unit.spd *= mult


## Redistributes all items so the strongest ones go to the heroes who use them best.
## equipped: {hero_id: {slot: item}}, inventory: Array of items. Both are changed in place.
static func equip_best(equipped: Dictionary, inventory: Array) -> void:
	for slot in SLOTS:
		var pool := []
		for hero_id in equipped:
			if equipped[hero_id].has(slot):
				pool.append(equipped[hero_id][slot])
				equipped[hero_id].erase(slot)
		for item in inventory.duplicate():
			if item["slot"] == slot:
				pool.append(item)
				inventory.erase(item)
		pool.sort_custom(func(a, b): return a["bonus"] > b["bonus"])
		for hero_id in PRIORITY[slot]:
			if pool.is_empty():
				break
			if not equipped.has(hero_id):
				equipped[hero_id] = {}
			equipped[hero_id][slot] = pool.pop_front()
		inventory.append_array(pool)
	# Drop the weakest spare items when the bag is full.
	inventory.sort_custom(func(a, b): return a["bonus"] > b["bonus"])
	while inventory.size() > INVENTORY_CAP:
		inventory.pop_back()
