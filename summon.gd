extends RefCounted
## Summon: crystals buy a random hero; a repeat hero turns into star dust.

const COST := 100
const QUEST_CRYSTALS := 10
const DUPLICATE_DUST := 40

# What a new hero says when they join the squad.
const INTRO := {
	"ren": [["Рэн", "Я был Пустотником. Ваш свет вернул мне имя. Теперь мой клинок служит вам."]],
	"mira": [["Мира", "Акира! Я тоже из храма. Учитель просил присмотреть за тобой, если он не вернётся."]],
	"tetsuo": [["Тэцуо", "Кузнец из Корневой долины. Сломаете щит, починю. Сломаете меня, не советую."]],
	"isa": [["Иса", "Огонь не только жжёт, он ещё и греет. Покажу вам оба способа."]],
}


static func stage_crystals(stage: int) -> int:
	return 50 if stage % 10 == 0 else 0


static func tower_crystals(floor_num: int) -> int:
	return 20 if floor_num % 5 == 0 else 0


## Picks a random summonable hero. Returns {"id", "new"}; "new" is false for a repeat.
static func roll(rng: RandomNumberGenerator, owned: Array, pool: Array) -> Dictionary:
	var id: String = pool[rng.randi() % pool.size()]["id"]
	return {"id": id, "new": not owned.has(id)}
