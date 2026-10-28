extends RefCounted
## One fighter in battle (hero or enemy).

const ENERGY_MAX := 100.0

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
	def = d["def"] * power
	spd = d["spd"]


func alive() -> bool:
	return hp > 0.0


func ult_ready() -> bool:
	return alive() and energy >= ENERGY_MAX


func add_energy(amount: float) -> void:
	energy = minf(ENERGY_MAX, energy + amount)


## Applies damage through the shield first. Returns damage dealt to HP.
func take_damage(amount: float) -> float:
	var absorbed := minf(shield, amount)
	shield -= absorbed
	var dealt := minf(hp, amount - absorbed)
	hp -= dealt
	return dealt


func heal(amount: float) -> float:
	var healed := minf(max_hp - hp, amount)
	hp += healed
	return healed
