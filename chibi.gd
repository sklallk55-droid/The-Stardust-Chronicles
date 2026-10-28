extends Control
## Fighter sprite rendered in Blender (3D toon models with anime faces), taken from the art_* atlases.
## Idle: breathing and floating; attack pose on demand; portrait mode for dialogues and cut-ins.

const HEROES := preload("res://art_heroes.png")
const MONSTERS := preload("res://art_monsters.png")
const PORTRAITS := preload("res://art_portraits.png")
const CELL := 320.0
const PCELL := 384.0
const COLS := 6
const PCOLS := 4
const HERO_IDS := ["akira", "ryu", "yuki", "kae", "sara", "valdram", "ren", "mira", "tetsuo", "isa", "noct"]
const MONSTER_IDS := ["shade", "voidling", "eater", "wisp", "ember", "blackstar", "golem", "guardian", "thorn", "spirit", "frost"]
# Monsters that hover instead of standing.
const FLOATING := ["shade", "voidling", "eater", "wisp", "ember", "blackstar", "spirit", "frost"]

var id := ""
var portrait := false  # bust for dialogues and the ultimate cut-in
var animate := true
var flip := false
var _t := randf() * 10.0
var _attack_left := 0.0


func _process(delta: float) -> void:
	if animate and is_visible_in_tree():
		_t += delta
		_attack_left = maxf(0.0, _attack_left - delta)
		queue_redraw()


func setup(unit_id: String, as_portrait := false) -> void:
	id = unit_id
	portrait = as_portrait
	queue_redraw()


## Shows the attack pose for a moment.
func play_attack(time := 0.35) -> void:
	_attack_left = time


func _region() -> Array:
	var pose := 1 if _attack_left > 0.0 else 0
	if portrait and HERO_IDS.has(id):
		var i := HERO_IDS.find(id)
		return [PORTRAITS, Rect2((i % PCOLS) * PCELL, (i / PCOLS) * PCELL, PCELL, PCELL)]
	var tex: Texture2D = HEROES
	var idx := HERO_IDS.find(id)
	if idx < 0:
		tex = MONSTERS
		idx = maxi(0, MONSTER_IDS.find(id))
	var k := idx * 2 + pose
	return [tex, Rect2((k % COLS) * CELL, (k / COLS) * CELL, CELL, CELL)]


func _draw() -> void:
	var r := _region()
	var w := minf(size.x, size.y)
	var rect := Rect2((size.x - w) / 2, size.y - w, w, w)
	if portrait:
		draw_texture_rect_region(r[0], rect, r[1])
		return
	var floating := FLOATING.has(id)
	# Shadow on the ground.
	var sh_w := w * (0.42 if floating else 0.5)
	var sh_y := size.y - w * 0.05
	var lift := (sin(_t * 2.4) * 0.5 + 0.5) * w * 0.05 if floating else 0.0
	draw_set_transform(Vector2(size.x / 2, sh_y), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, sh_w * 0.5 * (1.0 - lift / w * 2.0), Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Breathing: a gentle squash anchored at the feet.
	var breath := sin(_t * 2.2) * 0.012
	var sx := 1.0 - breath * 0.6
	var sy := 1.0 + breath
	var feet := Vector2(size.x / 2, size.y - w * 0.045)
	draw_set_transform(feet - Vector2(0, lift), 0.0, Vector2(-sx if flip else sx, sy))
	draw_texture_rect_region(r[0], Rect2(rect.position - feet, rect.size), r[1])
	draw_set_transform(Vector2.ZERO)
