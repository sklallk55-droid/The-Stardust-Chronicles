extends RefCounted
## Daily quests: progress counters that reset every calendar day.

const LIST := [
	{"id": "wins", "text": "Победить в 5 боях", "goal": 5, "reward": 150},
	{"id": "ults", "text": "Использовать 10 ультимейтов", "goal": 10, "reward": 120},
	{"id": "upgrade", "text": "Улучшить отряд", "goal": 1, "reward": 100},
	{"id": "tower", "text": "Пройти этаж Башни Пепла", "goal": 1, "reward": 200},
]


static func today() -> String:
	return Time.get_date_string_from_system()


## Returns the saved state, or a clean one when the day has changed.
static func current(state: Dictionary) -> Dictionary:
	if state.get("date", "") != today():
		return {"date": today(), "progress": {}, "claimed": []}
	return state


static func add(state: Dictionary, quest_id: String, amount: int = 1) -> void:
	state["progress"][quest_id] = int(state["progress"].get(quest_id, 0)) + amount


static func progress(state: Dictionary, quest: Dictionary) -> int:
	return mini(int(state["progress"].get(quest["id"], 0)), quest["goal"])


static func can_claim(state: Dictionary, quest: Dictionary) -> bool:
	return progress(state, quest) >= quest["goal"] and not state["claimed"].has(quest["id"])


## Gold for a quest grows with story progress so it stays useful later.
static func reward(quest: Dictionary, stage: int) -> int:
	return int(quest["reward"] * (1.0 + stage / 10.0))


static func claim(state: Dictionary, quest: Dictionary, stage: int) -> int:
	if not can_claim(state, quest):
		return 0
	state["claimed"].append(quest["id"])
	return reward(quest, stage)


static func unclaimed_count(state: Dictionary) -> int:
	var n := 0
	for q in LIST:
		if can_claim(state, q):
			n += 1
	return n
