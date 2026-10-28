extends RefCounted
## Personal hero levels: heroes in the squad earn experience in battle, the cap grows with stars.

const BASE_CAP := 10
const CAP_PER_STAR := 10
const STAT_PER_LEVEL := 0.02


static func cap(stars: int) -> int:
	return BASE_CAP + CAP_PER_STAR * stars


static func xp_to_next(level: int) -> int:
	return 50 + 25 * level


static func stage_xp(stage: int) -> int:
	return 20 + 5 * stage


static func tower_xp(floor_num: int) -> int:
	return stage_xp(10 + floor_num)


## Adds experience to one hero. Returns how many levels were gained.
static func add_xp(levels: Dictionary, xp: Dictionary, id: String, amount: int, stars: int) -> int:
	var lvl: int = levels.get(id, 1)
	var cur: int = xp.get(id, 0) + amount
	var gained := 0
	while lvl < cap(stars) and cur >= xp_to_next(lvl):
		cur -= xp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= cap(stars):
		cur = 0
	levels[id] = lvl
	xp[id] = cur
	return gained


## Applies a hero's personal level to a fresh Unit.
static func apply(unit, level: int) -> void:
	var mult := 1.0 + STAT_PER_LEVEL * (level - 1)
	unit.atk *= mult
	unit.max_hp = round(unit.max_hp * mult)
	unit.hp = unit.max_hp
