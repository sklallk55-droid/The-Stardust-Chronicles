extends RefCounted
## Hero ascension: stars bought with star dust raise stats, unlock a passive and a personal story.

const MAX_STARS := 5
const STAT_PER_STAR := 0.08
const PASSIVE_STAR := 3
const QUEST_DUST := 5
const PASSIVES := {
	"akira": "Шанс крита +15%",
	"ryu": "Щит ультимейта +50%",
	"yuki": "Лечение ультимейта +50%",
	"kae": "Урон ультимейта +50%",
}

# Personal scene shown when a hero gets the first star.
const STORIES := {
	"akira": [
		["Акира", "Учитель говорил: звезда горит не для себя, а для тех, кто в темноте."],
		["Акира", "Я найду его. И спрошу, почему он ушёл, не попрощавшись."],
	],
	"ryu": [
		["Рю", "Брат опять не узнал меня в письме. Пустотник забрал у него моё лицо."],
		["Рю", "Каждая монета — шаг к лекарю. Только вы, кажется, стали мне дороже денег."],
	],
	"yuki": [
		["Юки", "В детстве Сара пела мне у Лунного озера. Я помню каждую ноту."],
		["Юки", "Если она забудет эту песню, я спою ей снова."],
	],
	"kae": [
		["Каэ", "Мне снятся корни, уходящие глубоко под землю, и тысячи тихих голосов."],
		["Каэ", "Странно... Кажется, звёзды помнят меня лучше, чем я сама."],
	],
}


static func cost(stars: int) -> int:
	return 20 * (stars + 1)


static func stage_dust(stage: int) -> int:
	return 30 if stage % 10 == 0 else 2


static func tower_dust(floor_num: int) -> int:
	return 15 if floor_num % 5 == 0 else 5


## Applies a hero's stars and passive to a fresh Unit.
static func apply(unit, stars: int) -> void:
	var mult := 1.0 + STAT_PER_STAR * stars
	unit.atk *= mult
	unit.max_hp = round(unit.max_hp * mult)
	unit.hp = unit.max_hp
	if stars < PASSIVE_STAR:
		return
	if unit.id == "akira":
		unit.crit_bonus = 0.15
	else:
		unit.ult_mult = 1.5
