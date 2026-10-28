extends RefCounted
## Auto-battle simulation. Has no nodes, so it runs the same in the game and in tests.

const Data = preload("res://data.gd")
const Unit = preload("res://unit.gd")

signal acted(actor: Unit, target: Unit, amount: float, kind: String)  # kind: hit, crit, heal, shield, dot, revive, drain
signal ult_used(actor: Unit)
signal status(target: Unit, type: String)  # a status was applied, or "enrage"
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
var resonance := {}  # element -> attack bonus of the hero squad
var revive_used := false
var _acc := 0.0


func _init(hero_list: Array, enemy_list: Array, seed_value: int = 0) -> void:
	heroes = hero_list
	enemies = enemy_list
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	_apply_resonance()
	for u in heroes + enemies:
		_apply_passive(u)


## Elemental resonance: two heroes of one element give +10% attack, three +20%, four +30%.
func _apply_resonance() -> void:
	var counts := {}
	for h in heroes:
		counts[h.element] = counts.get(h.element, 0) + 1
	for el in counts:
		if counts[el] >= 2:
			resonance[el] = 0.1 * (counts[el] - 1)
	for h in heroes:
		h.atk *= 1.0 + resonance.get(h.element, 0.0)


func _apply_passive(u: Unit) -> void:
	match u.id:
		"ren":
			u.lifesteal = 0.25 if u.is_hero else 0.15
		"tetsuo":
			u.dmg_taken = 0.9
		"shade", "voidling":
			u.lifesteal = 0.12
		"golem":
			u.dmg_taken = 0.85
		"thorn":
			u.reflect = 0.15


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
		_tick_effects(u)
		if not u.alive():
			if _check_end():
				return
			continue
		if not u.stunned():
			u.gauge += u.spd
		if u.gauge >= GAUGE_MAX:
			u.gauge -= GAUGE_MAX
			_act(u)
		if u.ult_ready() and not u.stunned() and (auto_ult or not u.is_hero):
			use_ult(u)
		if _check_end():
			return
	if time >= TIME_LIMIT:
		_finish(false)


## Statuses tick once per second: burn and poison hurt, regen heals; expired ones drop off.
func _tick_effects(u: Unit) -> void:
	for e in u.effects:
		e["time"] -= TICK_TIME
		e["acc"] += TICK_TIME
		if e["acc"] >= 1.0:
			e["acc"] -= 1.0
			match e["type"]:
				"burn", "poison":
					var dmg: float = round(e["power"] * e["stacks"])
					u.take_damage(dmg, true)
					acted.emit(u, u, dmg, "dot_" + e["type"])
					_on_hp_lost(u)
				"regen":
					acted.emit(u, u, u.heal(e["power"]), "heal")
	u.effects = u.effects.filter(func(e): return e["time"] > 0.0)


func _status(target: Unit, type: String, time: float, power := 0.0, stacks := 1) -> void:
	if not target.alive():
		return
	target.add_effect(type, time, power, stacks)
	status.emit(target, type)


## Fires a unit's ultimate. Called by the player (portrait tap) or by auto-ult.
func use_ult(u: Unit) -> bool:
	if finished or not u.ult_ready():
		return false
	u.energy = 0.0
	ult_used.emit(u)
	var k := u.ult_mult
	var kit := u.id if u.is_hero or u.role == "boss" else ""
	if u.id == "sara" and not u.is_hero:
		kit = ""
	match kit:
		"akira":  # Звёздный разрез: добивание возвращает половину энергии
			var t := _lowest_hp(_foes(u))
			if t:
				_attack(u, t, 3.0 * k)
				if not t.alive():
					u.add_energy(50.0)
		"ryu":  # Стена пламени: щит всем и провокация
			for a in _allies(u):
				_give_shield(u, a, u.max_hp * (0.3 if a == u else 0.2) * k)
			_status(u, "taunt", 3.0)
		"yuki":  # Лунная волна: лечит, снимает дебаффы, даёт регенерацию
			for a in _allies(u):
				acted.emit(u, a, a.heal(u.atk_now() * 2.3 * k), "heal")
				if a.cleanse() > 0:
					status.emit(a, "cleanse")
				_status(a, "regen", 5.0, u.atk_now() * 0.25 * k)
		"kae":  # Гнев леса: удар по всем и два слоя яда
			for t in _foes(u):
				_attack(u, t, 1.4 * k)
				_status(t, "poison", 6.0, u.atk_now() * 0.15, 3)
				_status(t, "poison", 6.0, u.atk_now() * 0.15, 3)
		"sara":  # Песнь пустоты: мощный удар и заморозка
			var t := _strongest(_foes(u))
			if t:
				_attack(u, t, 2.6 * k)
				_status(t, "freeze", 2.0)
		"ren":  # Теневой клинок: сквозь щит и половину защиты
			var t := _lowest_hp(_foes(u))
			if t:
				_attack(u, t, 3.1 * k, true)
		"mira":  # Благословение: лечение и ярость всем
			for a in _allies(u):
				acted.emit(u, a, a.heal(u.atk_now() * 2.0 * k), "heal")
				_status(a, "atk_up", 8.0)
		"tetsuo":  # Каменная кожа: щит и шипы всем
			for a in _allies(u):
				_give_shield(u, a, u.max_hp * 0.16 * k)
				_status(a, "thorns", 6.0)
		"isa":  # Огненный дождь: удар по всем и горение
			for t in _foes(u):
				_attack(u, t, 1.5 * k)
				_status(t, "burn", 4.0, u.atk_now() * 0.22)
		"guardian":
			for t in _foes(u):
				_attack(u, t, 0.8)
			_give_shield(u, u, u.max_hp * 0.05)
		"valdram":
			for t in _foes(u):
				_attack(u, t, 0.7)
				_status(t, "def_down", 4.0)
		"eater":
			for t in _foes(u):
				_attack(u, t, 0.55)
				t.add_energy(-20.0)
			status.emit(u, "drain")
		"noct":
			for t in _foes(u):
				_attack(u, t, 0.6)
				_status(t, "poison", 5.0, u.atk_now() * 0.08, 3)
		"blackstar":
			for t in _foes(u):
				_attack(u, t, 0.75)
				_status(t, "burn", 3.0, u.atk_now() * 0.1)
		_:
			_role_ult(u)
	_check_end()
	return true


func _role_ult(u: Unit) -> void:
	var k := u.ult_mult
	match u.role:
		"dps":
			var t := _lowest_hp(_foes(u))
			if t:
				_attack(u, t, 3.0 * k)
		"tank":
			for a in _allies(u):
				_give_shield(u, a, u.max_hp * 0.2 * k)
		"healer":
			for a in _allies(u):
				acted.emit(u, a, a.heal(u.atk_now() * 2.5 * k), "heal")
		"mage":
			for t in _foes(u):
				_attack(u, t, 1.5 * k)
		"boss":
			if u.id == "sara":  # генерал Сара замораживает двоих
				var t := _pick_enemy_target()
				if t:
					_attack(u, t, 2.0)
				var foes := _foes(u)
				if not foes.is_empty():
					_status(foes[rng.randi() % foes.size()], "freeze", 1.2)
			else:
				var t := _pick_enemy_target()
				if t:
					_attack(u, t, 2.0)
		_:
			var t := _pick_enemy_target()
			if t:
				_attack(u, t, 2.0)


func _give_shield(from: Unit, to: Unit, amount: float) -> void:
	to.shield += amount
	acted.emit(from, to, amount, "shield")


func _act(u: Unit) -> void:
	u.add_energy(25.0)
	u.acted_count += 1
	if u.role == "healer":
		var ally := _lowest_hp_ratio(_allies(u))
		if ally and ally.hp / ally.max_hp < HEAL_THRESHOLD:
			acted.emit(u, ally, ally.heal(u.atk_now() * 1.5), "heal")
			# Юки снимает дебафф с того, кого лечит
			if u.id == "yuki" and ally.cleanse() > 0:
				status.emit(ally, "cleanse")
			return
	var target: Unit
	if not u.is_hero:
		target = _pick_enemy_target()
	elif u.role == "dps":
		target = _lowest_hp(_foes(u))
	else:
		var foes := _foes(u)
		target = foes[0] if foes.size() > 0 else null
	if not target:
		return
	_attack(u, target, 1.0)
	_on_hit_passive(u, target)


## Passive effects of basic attacks.
func _on_hit_passive(u: Unit, t: Unit) -> void:
	match u.id:
		"akira":  # Двойной удар
			if rng.randf() < 0.2 and t.alive():
				_attack(u, t, 0.6)
		"ryu", "wisp":
			if rng.randf() < 0.3:
				_status(t, "burn", 4.0, u.atk_now() * 0.18)
		"ember":
			if rng.randf() < 0.35:
				_status(t, "burn", 4.0, u.atk_now() * 0.18)
		"kae":
			_status(t, "poison", 6.0, u.atk_now() * 0.1, 3)
		"sara":
			if rng.randf() < 0.15:
				_status(t, "freeze", 1.0)
		"frost":
			if rng.randf() < 0.15:
				_status(t, "freeze", 1.0)
		"spirit":
			if rng.randf() < 0.2:
				_status(t, "def_down", 5.0)
		"isa":
			if rng.randf() < 0.25:
				_status(t, "burn", 4.0, u.atk_now() * 0.15)


func _attack(attacker: Unit, target: Unit, mult: float, pierce := false) -> void:
	if not target.alive():
		return
	var defence := target.def_now() * (0.5 if pierce else 1.0)
	var dmg := attacker.atk_now() * mult * 100.0 / (100.0 + defence)
	dmg *= Data.element_mult(attacker.element, target.element)
	dmg *= target.dmg_taken
	# Иса бьёт горящих сильнее
	if attacker.id == "isa" and target.has_effect("burn"):
		dmg *= 1.2
	dmg *= rng.randf_range(0.95, 1.05)
	var kind := "hit"
	if rng.randf() < CRIT_CHANCE + attacker.crit_bonus:
		dmg *= CRIT_MULT
		kind = "crit"
	dmg = round(dmg)
	var dealt := target.take_damage(dmg, pierce)
	target.add_energy(10.0 if target.role != "boss" else 4.0)
	acted.emit(attacker, target, dmg, kind)
	if attacker.lifesteal > 0.0 and dealt > 0.0:
		var healed := attacker.heal(dealt * attacker.lifesteal)
		if healed >= 1.0:
			acted.emit(attacker, attacker, healed, "drain")
	var refl := target.reflect_now()
	if refl > 0.0 and attacker.alive():
		var back: float = round(dmg * refl)
		attacker.take_damage(back)
		acted.emit(target, attacker, back, "hit")
		_on_hp_lost(attacker)
	_on_hp_lost(target)


## Boss enrage at half HP and Mira's one-time revive of a fallen hero.
func _on_hp_lost(u: Unit) -> void:
	if u.role == "boss" and not u.enraged and u.alive() and u.hp < u.max_hp * 0.5:
		u.enraged = true
		u.spd *= 1.1
		status.emit(u, "enrage")
	if not u.alive() and u.is_hero and not revive_used:
		for m in _alive(heroes):
			if m.id == "mira":
				revive_used = true
				u.hp = round(u.max_hp * 0.3)
				u.effects.clear()
				acted.emit(m, u, u.hp, "revive")
				break


## Enemies hit a taunting hero first, otherwise the tank half the time, otherwise a random hero.
func _pick_enemy_target() -> Unit:
	var alive := _alive(heroes)
	if alive.is_empty():
		return null
	for h in alive:
		if h.has_effect("taunt") and rng.randf() < 0.6:
			return h
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


func _strongest(list: Array) -> Unit:
	var best: Unit = null
	for x in list:
		if best == null or x.hp > best.hp:
			best = x
	return best


func _lowest_hp_ratio(list: Array) -> Unit:
	var best: Unit = null
	for x in list:
		if best == null or x.hp / x.max_hp < best.hp / best.max_hp:
			best = x
	return best
