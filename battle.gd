extends RefCounted
## Auto-battle simulation. Has no nodes, so it runs the same in the game and in tests.

const Data = preload("res://scripts/data.gd")
const Unit = preload("res://scripts/unit.gd")

signal acted(actor: Unit, target: Unit, amount: float, kind: String)  # kind: hit, crit, heal, shield
signal ult_used(actor: Unit)
signal ended(victory: bool)

const GAUGE_MAX := 1000.0
const TICK_TIME := 0.1
const TIME_LIMIT := 90.0
const CRIT_CHANCE := 0.1
const CRIT_MULT := 1.5
const HEAL_THRESHOLD := 0.6

var heroes: Array = []
var enemies: Array = []
var auto_ult := false
var time := 0.0
var finished := false
var victory := false
var rng := RandomNumberGenerator.new()
var _acc := 0.0


func _init(hero_list: Array, enemy_list: Array, seed_value: int = 0) -> void:
	heroes = hero_list
	enemies = enemy_list
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func update(delta: float) -> void:
	_acc += delta
	while _acc >= TICK_TIME and not finished:
		_acc -= TICK_TIME
		step()


func step() -> void:
	if finished:
		return
	time += TICK_TIME
	for u in heroes + enemies:
		if not u.alive():
			continue
		u.gauge += u.spd
		if u.gauge >= GAUGE_MAX:
			u.gauge -= GAUGE_MAX
			_act(u)
		if u.ult_ready() and (auto_ult or not u.is_hero):
			use_ult(u)
		if _check_end():
			return
	if time >= TIME_LIMIT:
		_finish(false)


## Fires a unit's ultimate. Called by the player (portrait tap) or by auto-ult.
func use_ult(u: Unit) -> bool:
	if finished or not u.ult_ready():
		return false
	u.energy = 0.0
	ult_used.emit(u)
	match u.role:
		"dps":
			var t := _lowest_hp(_foes(u))
			if t:
				_attack(u, t, 3.0)
		"tank":
			for a in _allies(u):
				var amount := u.max_hp * 0.2
				a.shield += amount
				acted.emit(u, a, amount, "shield")
		"healer":
			for a in _allies(u):
				acted.emit(u, a, a.heal(u.atk * 2.5), "heal")
		"mage":
			for t in _foes(u):
				_attack(u, t, 1.5)
		_:
			var t := _pick_enemy_target()
			if t:
				_attack(u, t, 2.0)
	_check_end()
	return true


func _act(u: Unit) -> void:
	u.add_energy(25.0)
	if u.role == "healer":
		var ally := _lowest_hp_ratio(_allies(u))
		if ally and ally.hp / ally.max_hp < HEAL_THRESHOLD:
			acted.emit(u, ally, ally.heal(u.atk * 1.5), "heal")
			return
	var target: Unit
	if not u.is_hero:
		target = _pick_enemy_target()
	elif u.role == "dps":
		target = _lowest_hp(_foes(u))
	else:
		var foes := _foes(u)
		target = foes[0] if foes.size() > 0 else null
	if target:
		_attack(u, target, 1.0)


func _attack(attacker: Unit, target: Unit, mult: float) -> void:
	var dmg := attacker.atk * mult * 100.0 / (100.0 + target.def)
	dmg *= Data.element_mult(attacker.element, target.element)
	dmg *= rng.randf_range(0.95, 1.05)
	var kind := "hit"
	if rng.randf() < CRIT_CHANCE:
		dmg *= CRIT_MULT
		kind = "crit"
	dmg = round(dmg)
	target.take_damage(dmg)
	target.add_energy(10.0)
	acted.emit(attacker, target, dmg, kind)


## Enemies hit the tank half the time, otherwise a random hero.
func _pick_enemy_target() -> Unit:
	var alive := _alive(heroes)
	if alive.is_empty():
		return null
	for h in alive:
		if h.role == "tank" and rng.randf() < 0.5:
			return h
	return alive[rng.randi() % alive.size()]


func _check_end() -> bool:
	if finished:
		return true
	if _alive(enemies).is_empty():
		_finish(true)
	elif _alive(heroes).is_empty():
		_finish(false)
	return finished


func _finish(win: bool) -> void:
	finished = true
	victory = win
	ended.emit(win)


func _alive(list: Array) -> Array:
	return list.filter(func(x): return x.alive())


func _allies(u: Unit) -> Array:
	return _alive(heroes if u.is_hero else enemies)


func _foes(u: Unit) -> Array:
	return _alive(enemies if u.is_hero else heroes)


func _lowest_hp(list: Array) -> Unit:
	var best: Unit = null
	for x in list:
		if best == null or x.hp < best.hp:
			best = x
	return best


func _lowest_hp_ratio(list: Array) -> Unit:
	var best: Unit = null
	for x in list:
		if best == null or x.hp / x.max_hp < best.hp / best.max_hp:
			best = x
	return best
