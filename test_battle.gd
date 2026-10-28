extends SceneTree
## Headless balance check: godot --headless --path . --script res://test_battle.gd

const Data = preload("res://data.gd")
const Unit = preload("res://unit.gd")
const Battle = preload("res://battle.gd")
const Equipment = preload("res://equipment.gd")
const Quests = preload("res://quests.gd")
const Ascension = preload("res://ascension.gd")
const Summon = preload("res://summon.gd")
const Levels = preload("res://levels.gd")


func _init() -> void:
	var failures := 0
	for case in [[1, 1], [5, 3], [10, 5], [10, 1], [20, 9], [30, 14], [35, 16], [40, 16], [50, 20], [60, 28]]:
		var stage: int = case[0]
		var level: int = case[1]
		var wins := 0
		var total_time := 0.0
		for i in 100:
			var b := _run(stage, level, i + 1)
			total_time += b.time
			if not b.finished:
				failures += 1
			if b.victory:
				wins += 1
		print("stage %2d, level %2d: win %3d%%, avg %.1fs" % [stage, level, wins, total_time / 100.0])
	print("unfinished battles: %d" % failures)
	failures += _test_equipment()
	failures += _test_tower()
	failures += _test_quests()
	failures += _test_ascension()
	failures += _test_summon()
	failures += _test_levels()
	failures += _test_kits()
	quit(1 if failures > 0 else 0)


func _run(stage: int, level: int, seed_value: int) -> Battle:
	var heroes := []
	for d in Data.heroes():
		heroes.append(Unit.new(d, true, Data.hero_power(level)))
	var enemies := []
	for d in Data.stage_enemies(stage):
		enemies.append(Unit.new(d, false, Data.enemy_power(stage)))
	return _fight(heroes, enemies, seed_value)


func _fight(heroes: Array, enemies: Array, seed_value: int) -> Battle:
	var b := Battle.new(heroes, enemies, seed_value)
	b.auto_ult = true
	while not b.finished:
		b.step()
	return b


## Rolls 200 drops, auto-equips them and checks every hero ends up with all slots filled.
func _test_equipment() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var equipped := {}
	var inventory := []
	for stage in range(1, 201):
		var drop := Equipment.roll_drop(stage, rng)
		if not drop.is_empty():
			inventory.append(drop)
			Equipment.equip_best(equipped, inventory)
	var errors := 0
	for d in Data.heroes():
		var gear: Dictionary = equipped.get(d["id"], {})
		if gear.size() != Equipment.SLOTS.size():
			errors += 1
		var u := Unit.new(d, true)
		Equipment.apply(u, gear)
		if u.atk < d["atk"] or u.max_hp < d["hp"]:
			errors += 1
	if inventory.size() > Equipment.INVENTORY_CAP:
		errors += 1
	print("equipment errors: %d, bag %d" % [errors, inventory.size()])
	return errors


## Tower floors: a squad of level 10 should clear the first floors and stall later.
func _test_tower() -> int:
	var errors := 0
	for floor_num in [1, 5, 10, 20]:
		var wins := 0
		for i in 50:
			var heroes := []
			for d in Data.heroes():
				heroes.append(Unit.new(d, true, Data.hero_power(10)))
			var enemies := []
			for d in Data.tower_enemies(floor_num):
				enemies.append(Unit.new(d, false, Data.tower_power(floor_num)))
			if enemies.size() != 3:
				errors += 1
			if _fight(heroes, enemies, i + 1).victory:
				wins += 1
		print("tower floor %2d, level 10: win %3d%%" % [floor_num, wins * 2])
	return errors


func _test_quests() -> int:
	var errors := 0
	var state := Quests.current({})
	if Quests.unclaimed_count(state) != 0:
		errors += 1
	for i in 5:
		Quests.add(state, "wins")
	var wins_quest: Dictionary = Quests.LIST[0]
	if Quests.claim(state, wins_quest, 10) != 300:
		errors += 1
	if Quests.claim(state, wins_quest, 10) != 0:
		errors += 1
	if Quests.current({"date": "2000-01-01", "progress": {"wins": 9}, "claimed": ["wins"]})["claimed"].size() != 0:
		errors += 1
	print("quest errors: %d" % errors)
	return errors


## Three stars on every hero should noticeably help on stage 20 at level 9.
func _test_ascension() -> int:
	var errors := 0
	var wins := 0
	for i in 100:
		var heroes := []
		for d in Data.heroes():
			var u := Unit.new(d, true, Data.hero_power(9))
			Ascension.apply(u, 3)
			heroes.append(u)
		var enemies := []
		for d in Data.stage_enemies(20):
			enemies.append(Unit.new(d, false, Data.enemy_power(20)))
		if _fight(heroes, enemies, i + 1).victory:
			wins += 1
	print("stage 20, level 9, 3 stars: win %3d%%" % wins)
	var akira := Unit.new(Data.heroes()[0], true)
	Ascension.apply(akira, 5)
	if akira.crit_bonus <= 0.0 or akira.atk <= Data.heroes()[0]["atk"]:
		errors += 1
	for id in Ascension.PASSIVES:
		if not Ascension.STORIES.has(id):
			errors += 1
	print("ascension errors: %d" % errors)
	return errors


## Every summon hero has a look, a passive and lines; a squad of summon heroes can fight.
func _test_summon() -> int:
	var errors := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var owned := []
	for i in 40:
		var got := Summon.roll(rng, owned, Data.summon_heroes())
		if got["new"]:
			owned.append(got["id"])
	if owned.size() != Data.summon_heroes().size():
		errors += 1
	for d in Data.summon_heroes():
		var id: String = d["id"]
		if not (Summon.INTRO.has(id) and Ascension.PASSIVES.has(id) and Ascension.STORIES.has(id)):
			errors += 1
	var wins := 0
	for i in 100:
		var heroes := []
		for d in Data.heroes_by_ids(["ren", "tetsuo", "mira", "isa"]):
			heroes.append(Unit.new(d, true, Data.hero_power(5)))
		var enemies := []
		for d in Data.stage_enemies(10):
			enemies.append(Unit.new(d, false, Data.enemy_power(10)))
		if _fight(heroes, enemies, i + 1).victory:
			wins += 1
	print("stage 10, level 5, summon squad: win %3d%%" % wins)
	print("summon errors: %d" % errors)
	return errors


## Checks experience, the level cap and that personal levels make a hard stage winnable.
func _test_levels() -> int:
	var errors := 0
	var levels := {}
	var xp := {}
	var total := 0
	for stage in range(1, 31):
		total += Levels.add_xp(levels, xp, "akira", Levels.stage_xp(stage), 0)
	if levels["akira"] != Levels.cap(0) or xp["akira"] != 0:
		print("FAIL: level should stop at cap %d, got %d (xp %d)" % [Levels.cap(0), levels["akira"], xp["akira"]])
		errors += 1
	var after := Levels.add_xp(levels, xp, "akira", 10000, 1)
	if levels["akira"] != Levels.cap(1) or after != Levels.cap(1) - Levels.cap(0):
		print("FAIL: a star should raise the cap to %d, got %d" % [Levels.cap(1), levels["akira"]])
		errors += 1
	var wins := [0, 0]
	for i in 100:
		for k in 2:
			var heroes := []
			for d in Data.heroes():
				var u := Unit.new(d, true, Data.hero_power(14))
				Levels.apply(u, 1 if k == 0 else 20)
				heroes.append(u)
			var enemies := []
			for d in Data.stage_enemies(35):
				enemies.append(Unit.new(d, false, Data.enemy_power(35)))
			if _fight(heroes, enemies, i + 1).victory:
				wins[k] += 1
	print("levels: 30 stages give %d levels (cap %d); stage 35: level 1 win %d%%, level 20 win %d%%" % [total, Levels.cap(0), wins[0], wins[1]])
	if wins[1] <= wins[0]:
		print("FAIL: personal levels should help")
		errors += 1
	return errors


## Every hero kit and boss ability runs without errors and statuses really get applied.
func _test_kits() -> int:
	var errors := 0
	var seen := {}
	var squads := [["akira", "ryu", "yuki", "kae"], ["sara", "ren", "mira", "isa"], ["tetsuo", "isa", "mira", "kae"]]
	for squad in squads:
		for stage in [10, 20, 30, 40, 50, 60]:
			var heroes := []
			for d in Data.heroes_by_ids(squad):
				heroes.append(Unit.new(d, true, Data.hero_power(stage / 2)))
			var enemies := []
			for d in Data.stage_enemies(stage):
				enemies.append(Unit.new(d, false, Data.enemy_power(stage)))
			var b := Battle.new(heroes, enemies, stage)
			b.status.connect(func(_u, type): seen[type] = true)
			b.acted.connect(func(_a, _t, _n, kind): seen[kind] = true)
			b.auto_ult = true
			while not b.finished:
				b.step()
	for need in ["burn", "poison", "freeze", "def_down", "atk_up", "regen", "taunt", "thorns", "enrage", "dot_burn", "dot_poison", "drain", "shield", "heal"]:
		if not seen.has(need):
			print("kit never triggered: ", need)
			errors += 1
	var res := Battle.new([Unit.new(Data.heroes()[0], true), Unit.new(Data.summon_heroes()[1], true)], [Unit.new(Data.enemies()[0], false)], 1).resonance
	if res.get("light", 0.0) != 0.1:
		errors += 1
	print("kit errors: %d, revive seen: %s" % [errors, seen.has("revive")])
	return errors
