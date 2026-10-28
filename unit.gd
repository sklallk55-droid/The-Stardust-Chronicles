extends RefCounted
## One fighter in battle (hero or enemy).

const ENERGY_MAX := 100.0
const DEF_POWER_CAP := 7.2

var id: String
var name: String
var role: String
var element: String
var color: Color
var is_hero: bool
var max_hp: float
var hp: float
var atk: float
var def: float
var spd: float
var shield := 0.0
var gauge := 0.0
var energy := 0.0
var crit_bonus := 0.0  # from ascension passives
var ult_mult := 1.0
# Deeper combat: statuses and passives.
var effects: Array = []  # [{type, time, power, stacks, acc}]
var lifesteal := 0.0  # share of dealt damage healed back
var reflect := 0.0  # share of taken damage returned to the attacker
var dmg_taken := 1.0  # incoming damage multiplier
var enraged := false  # bosses below half HP
var acted_count := 0


func _init(d: Dictionary, hero: bool, power: float = 1.0) -> void:
	id = d["id"]
	name = d["name"]
	role = d["role"]
	element = d["element"]
	color = d["color"]
	is_hero = hero
	max_hp = round(d["hp"] * power)
	hp = max_hp
	atk = d["atk"] * power
	# Defence stops growing after Act I, otherwise late fights stall on the time limit.
	def = d["def"] * minf(power, DEF_POWER_CAP)
	spd = d["spd"]


func alive() -> bool:
	return hp > 0.0


func ult_ready() -> bool:
	return alive() and energy >= ENERGY_MAX


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, ENERGY_MAX)


## Applies damage through the shield first. Returns damage dealt to HP.
func take_damage(amount: float, pierce_shield := false) -> float:
	var absorbed := 0.0 if pierce_shield else minf(shield, amount)
	shield -= absorbed
	var dealt := minf(hp, amount - absorbed)
	hp -= dealt
	return dealt


func heal(amount: float) -> float:
	if not alive():
		return 0.0
	var healed := minf(max_hp - hp, amount)
	hp += healed
	return healed


# --- Statuses ---

func has_effect(type: String) -> bool:
	for e in effects:
		if e["type"] == type:
			return true
	return false


func get_effect(type: String) -> Dictionary:
	for e in effects:
		if e["type"] == type:
			return e
	return {}


## Adds or refreshes a status. Stacking statuses (poison) grow up to max_stacks.
func add_effect(type: String, time: float, power := 0.0, max_stacks := 1) -> void:
	var e := get_effect(type)
	if e.is_empty():
		effects.append({"type": type, "time": time, "power": power, "stacks": 1, "acc": 0.0})
	else:
		e["time"] = maxf(e["time"], time)
		e["power"] = maxf(e["power"], power)
		e["stacks"] = mini(e["stacks"] + 1, max_stacks)


## Removes harmful statuses; returns how many were removed.
func cleanse() -> int:
	var before := effects.size()
	effects = effects.filter(func(e): return not e["type"] in ["burn", "poison", "freeze", "def_down"])
	return before - effects.size()


func stunned() -> bool:
	return has_effect("freeze")


func atk_now() -> float:
	var a := atk
	if has_effect("atk_up"):
		a *= 1.25
	if enraged:
		a *= 1.15
	return a


func def_now() -> float:
	return def * (0.6 if has_effect("def_down") else 1.0)


func reflect_now() -> float:
	return reflect + (0.25 if has_effect("thorns") else 0.0)
