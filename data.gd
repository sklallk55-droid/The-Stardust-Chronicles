extends RefCounted
## Static game data: heroes, enemies, bosses, story scenes.

const ELEMENT_NAMES := {
	"fire": "Огонь", "water": "Вода", "nature": "Природа",
	"light": "Свет", "dark": "Тьма",
}

# Attacker element -> element it is strong against.
const STRONG_AGAINST := {"fire": "nature", "nature": "water", "water": "fire"}


static func heroes() -> Array:
	return [
		{"id": "akira", "name": "Акира", "role": "dps", "element": "light",
			"hp": 900, "atk": 120, "def": 40, "spd": 105, "color": Color(1.0, 0.82, 0.45)},
		{"id": "ryu", "name": "Рю", "role": "tank", "element": "fire",
			"hp": 1400, "atk": 80, "def": 70, "spd": 90, "color": Color(0.95, 0.4, 0.3)},
		{"id": "yuki", "name": "Юки", "role": "healer", "element": "water",
			"hp": 800, "atk": 70, "def": 35, "spd": 110, "color": Color(0.45, 0.7, 1.0)},
		{"id": "kae", "name": "Каэ", "role": "mage", "element": "nature",
			"hp": 750, "atk": 130, "def": 30, "spd": 100, "color": Color(0.5, 0.9, 0.5)},
	]


static func enemies() -> Array:
	return [
		{"id": "shade", "name": "Тень", "role": "enemy", "element": "dark",
			"hp": 1400, "atk": 112, "def": 30, "spd": 95, "color": Color(0.45, 0.3, 0.6)},
		{"id": "wisp", "name": "Огонёк", "role": "enemy", "element": "fire",
			"hp": 1100, "atk": 135, "def": 20, "spd": 115, "color": Color(0.9, 0.5, 0.25)},
		{"id": "golem", "name": "Голем", "role": "enemy", "element": "nature",
			"hp": 2200, "atk": 98, "def": 60, "spd": 80, "color": Color(0.4, 0.55, 0.35)},
		{"id": "spirit", "name": "Дух озера", "role": "enemy", "element": "water",
			"hp": 1300, "atk": 120, "def": 30, "spd": 100, "color": Color(0.3, 0.5, 0.75)},
	]


static func bosses() -> Array:
	return [
		{"id": "guardian", "name": "Страж руин", "role": "boss", "element": "nature",
			"hp": 7000, "atk": 150, "def": 60, "spd": 85, "color": Color(0.35, 0.45, 0.3)},
		{"id": "sara", "name": "Генерал Сара", "role": "boss", "element": "water",
			"hp": 8000, "atk": 172, "def": 50, "spd": 105, "color": Color(0.25, 0.3, 0.6)},
		{"id": "valdram", "name": "Вальдрам", "role": "boss", "element": "dark",
			"hp": 6500, "atk": 175, "def": 60, "spd": 100, "color": Color(0.25, 0.15, 0.3)},
	]


static func stage_enemies(stage: int) -> Array:
	var pool := enemies()
	if stage % 10 == 0:
		var chapter := stage / 10
		return [pool[0], bosses()[mini(chapter - 1, bosses().size() - 1)], pool[0]]
	var count := 2 if stage <= 2 else 3
	var out := []
	for i in count:
		out.append(pool[(stage + i * 2) % pool.size()])
	return out


static func element_mult(attacker: String, defender: String) -> float:
	if STRONG_AGAINST.get(attacker, "") == defender:
		return 1.3
	if STRONG_AGAINST.get(defender, "") == attacker:
		return 0.7
	if (attacker == "light" and defender == "dark") or (attacker == "dark" and defender == "light"):
		return 1.3
	return 1.0


## Story scenes shown before a stage starts: stage -> [[speaker, line], ...]
static func story() -> Dictionary:
	return {
		1: [
			["", "Этой ночью звёзды над Астраем начали гаснуть одна за другой."],
			["Акира", "Учитель?.. Храм разрушен. В груди что-то горит, будто звезда."],
			["Рю", "Эй, девочка. За этот осколок дают хорошие деньги. Но тени добрались до него раньше меня."],
			["Юки", "Тени стирают память. Моя сестра ушла за ними и не вернулась. Я иду с вами."],
			["Каэ", "А я не помню, кто я. Зато помню, как бить тени! Вперёд!"],
		],
		10: [
			["Страж руин", "Осколок принадлежит Древу. Отдай его, дитя."],
			["Акира", "Только после того, как зажжём первую звезду."],
		],
		11: [
			["", "Первая звезда снова сияет. Где-то далеко Император Вальдрам поднимает серые знамёна."],
			["Юки", "Сара... ты правда служишь ему?"],
		],
		20: [
			["Генерал Сара", "Уходи, Юки. Император обещал вернуть то, что мы потеряли."],
		],
		30: [
			["Вальдрам", "Древо умирает. Я стану его корнем, даже если мир забудет своё имя."],
			["Акира", "Мы не дадим тебе стереть наши воспоминания!"],
		],
	}


# --- Progression formulas ---

static func hero_power(level: int) -> float:
	return pow(1.10, level - 1)


static func enemy_power(stage: int) -> float:
	return pow(1.07, stage - 1)


static func upgrade_cost(level: int) -> int:
	return int(round(60.0 * pow(level, 1.2)))


static func victory_gold(stage: int) -> int:
	return 50 + 10 * stage


## Idle income per minute while the squad "stands guard" on the last stage.
static func idle_gold_per_min(stage: int) -> float:
	return 5.0 + stage
