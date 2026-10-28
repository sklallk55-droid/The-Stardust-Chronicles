extends SceneTree
## Headless balance check: godot --headless --path . --script res://tests/test_battle.gd

const Data = preload("res://scripts/data.gd")
const Unit = preload("res://scripts/unit.gd")
const Battle = preload("res://scripts/battle.gd")


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
	quit(1 if failures > 0 else 0)


func _run(stage: int, level: int, seed_value: int) -> Battle:
	var heroes := []
	for d in Data.heroes():
		heroes.append(Unit.new(d, true, Data.hero_power(level)))
	var enemies := []
	for d in Data.stage_enemies(stage):
		enemies.append(Unit.new(d, false, Data.enemy_power(stage)))
	var b := Battle.new(heroes, enemies, seed_value)
	b.auto_ult = true
	while not b.finished:
		b.step()
	return b
