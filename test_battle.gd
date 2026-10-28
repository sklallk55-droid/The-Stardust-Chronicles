extends SceneTree
## Headless balance check: godot --headless --path . --script res://test_battle.gd

const Data = preload("res://data.gd")
const Unit = preload("res://unit.gd")
const Battle = preload("res://battle.gd")
const Equipment = preload("res://equipment.gd")
const Quests = preload("res://quests.gd")


func _init() -> void:
	var failures := 0
	for case in [[1, 1], [5, 3], [10, 5], [10, 1], [20, 9], [30, 14]]:
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
