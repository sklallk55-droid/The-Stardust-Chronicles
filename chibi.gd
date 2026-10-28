extends Control
## Procedural anime chibi portrait for heroes, enemies and bosses. Drawn in _draw, no image assets.

const SKIN := Color(1.0, 0.89, 0.8)
const LOOKS := {
	"akira": {"kind": "human", "hair": Color(0.98, 0.78, 0.35), "eyes": Color(0.85, 0.35, 0.2),
		"outfit": Color(0.95, 0.95, 1.0), "trim": Color(1.0, 0.75, 0.3), "style": "spiky", "extra": "star"},
	"ryu": {"kind": "human", "hair": Color(0.25, 0.18, 0.18), "eyes": Color(0.9, 0.3, 0.15),
		"outfit": Color(0.6, 0.2, 0.15), "trim": Color(0.3, 0.3, 0.35), "style": "short", "extra": "headband"},
	"yuki": {"kind": "human", "hair": Color(0.75, 0.88, 1.0), "eyes": Color(0.25, 0.5, 0.95),
		"outfit": Color(0.3, 0.45, 0.8), "trim": Color(0.9, 0.95, 1.0), "style": "long", "extra": "moon"},
	"kae": {"kind": "human", "hair": Color(0.95, 0.55, 0.25), "eyes": Color(0.3, 0.75, 0.35),
		"outfit": Color(0.35, 0.65, 0.35), "trim": Color(1.0, 0.95, 0.85), "style": "bob", "extra": "fox"},
	"sara": {"kind": "human", "hair": Color(0.2, 0.25, 0.5), "eyes": Color(0.55, 0.3, 0.8),
		"outfit": Color(0.2, 0.2, 0.3), "trim": Color(0.5, 0.6, 0.9), "style": "long", "extra": "moon"},
	"valdram": {"kind": "human", "hair": Color(0.85, 0.85, 0.9), "eyes": Color(0.9, 0.15, 0.2),
		"outfit": Color(0.15, 0.1, 0.2), "trim": Color(0.75, 0.6, 0.2), "style": "long", "extra": "crown"},
	"ren": {"kind": "human", "hair": Color(0.25, 0.2, 0.35), "eyes": Color(0.7, 0.3, 0.9),
		"outfit": Color(0.15, 0.12, 0.22), "trim": Color(0.6, 0.4, 0.85), "style": "spiky", "extra": "none"},
	"mira": {"kind": "human", "hair": Color(1.0, 0.95, 0.82), "eyes": Color(0.95, 0.7, 0.2),
		"outfit": Color(1.0, 1.0, 1.0), "trim": Color(1.0, 0.8, 0.4), "style": "long", "extra": "star"},
	"tetsuo": {"kind": "human", "hair": Color(0.35, 0.25, 0.15), "eyes": Color(0.3, 0.6, 0.25),
		"outfit": Color(0.4, 0.55, 0.3), "trim": Color(0.6, 0.45, 0.25), "style": "short", "extra": "headband"},
	"isa": {"kind": "human", "hair": Color(0.85, 0.2, 0.15), "eyes": Color(1.0, 0.6, 0.2),
		"outfit": Color(0.7, 0.25, 0.15), "trim": Color(1.0, 0.8, 0.3), "style": "bob", "extra": "none"},
	"shade": {"kind": "blob", "body": Color(0.35, 0.2, 0.5), "eyes": Color(1.0, 0.3, 0.35)},
	"wisp": {"kind": "flame", "body": Color(1.0, 0.55, 0.2), "eyes": Color(0.3, 0.1, 0.05)},
	"golem": {"kind": "rock", "body": Color(0.45, 0.5, 0.4), "eyes": Color(0.6, 1.0, 0.5)},
	"guardian": {"kind": "rock", "body": Color(0.35, 0.42, 0.32), "eyes": Color(1.0, 0.85, 0.3)},
	"spirit": {"kind": "drop", "body": Color(0.35, 0.6, 0.95), "eyes": Color(0.05, 0.1, 0.3)},
}

var id := ""
var look: Dictionary = {}


func setup(unit_id: String) -> void:
	id = unit_id
	look = LOOKS.get(unit_id, LOOKS["shade"])
	queue_redraw()


func _draw() -> void:
	match look.get("kind", "blob"):
		"human":
			_draw_human()
		"flame":
			_draw_flame()
		"rock":
			_draw_rock()
		"drop":
			_draw_drop()
		_:
			_draw_blob()


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * size.x


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(rx, ry))
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _anime_eye(center: Vector2, color: Color, s: float) -> void:
	_ellipse(center, 0.055 * s, 0.075 * s, Color(0.1, 0.07, 0.12))
	_ellipse(center + Vector2(0, 0.006 * s), 0.045 * s, 0.063 * s, color)
	_ellipse(center + Vector2(0, 0.02 * s), 0.03 * s, 0.035 * s, color.darkened(0.45))
	draw_circle(center + Vector2(-0.018, -0.028) * s, 0.017 * s, Color.WHITE)
	draw_circle(center + Vector2(0.02, 0.025) * s, 0.008 * s, Color(1, 1, 1, 0.8))


func _draw_human() -> void:
	var s := size.x
	var hair: Color = look["hair"]
	# Long hair falls behind the shoulders.
	if look["style"] == "long":
		draw_rect(Rect2(_p(0.2, 0.42), _p(0.6, 0.5)), hair.darkened(0.1))
	# Body and collar.
	draw_colored_polygon(PackedVector2Array([_p(0.3, 0.74), _p(0.7, 0.74), _p(0.82, 1.0), _p(0.18, 1.0)]), look["outfit"])
	draw_colored_polygon(PackedVector2Array([_p(0.4, 0.74), _p(0.6, 0.74), _p(0.5, 0.86)]), look["trim"])
	# Back hair, ears for the fox girl, then the face.
	draw_circle(_p(0.5, 0.44), 0.33 * s, hair.darkened(0.1))
	if look["extra"] == "fox":
		for side in [-1, 1]:
			var bx: float = 0.5 + side * 0.2
			draw_colored_polygon(PackedVector2Array([_p(bx - 0.09, 0.22), _p(bx + 0.09, 0.22), _p(bx + side * 0.06, 0.0)]), hair)
			draw_colored_polygon(PackedVector2Array([_p(bx - 0.045, 0.2), _p(bx + 0.045, 0.2), _p(bx + side * 0.05, 0.07)]), Color(1, 0.9, 0.85))
	draw_circle(_p(0.5, 0.5), 0.27 * s, SKIN)
	# Fringe: a cap over the forehead with pointed bangs.
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		cap.append(_p(0.5, 0.46) + Vector2(cos(a), sin(a)) * 0.3 * s)
	var tips := 7 if look["style"] == "spiky" else 5
	var depth := 0.16 if look["style"] == "spiky" else 0.11
	for i in range(tips, -1, -1):
		var x := 0.2 + 0.6 * i / tips
		if i > 0 and i < tips:
			cap.append(_p(x, 0.46))
		if i > 0:
			cap.append(_p(x - 0.3 / tips, 0.46 + depth))
	draw_colored_polygon(cap, hair)
	if look["style"] == "bob" or look["style"] == "long":
		draw_rect(Rect2(_p(0.2, 0.44), _p(0.07, 0.24)), hair)
		draw_rect(Rect2(_p(0.73, 0.44), _p(0.07, 0.24)), hair)
	# Face.
	_anime_eye(_p(0.4, 0.58), look["eyes"], s)
	_anime_eye(_p(0.6, 0.58), look["eyes"], s)
	_ellipse(_p(0.33, 0.66), 0.035 * s, 0.018 * s, Color(1, 0.55, 0.6, 0.45))
	_ellipse(_p(0.67, 0.66), 0.035 * s, 0.018 * s, Color(1, 0.55, 0.6, 0.45))
	draw_arc(_p(0.5, 0.67), 0.03 * s, 0.2, PI - 0.2, 8, Color(0.5, 0.2, 0.2), 0.012 * s)
	# Signature accessory.
	match look["extra"]:
		"star":
			_star(_p(0.72, 0.3), 0.07 * s, Color(1, 0.45, 0.3))
		"moon":
			draw_circle(_p(0.28, 0.3), 0.055 * s, Color(1, 0.95, 0.7))
			draw_circle(_p(0.3, 0.29), 0.05 * s, hair)
		"headband":
			draw_rect(Rect2(_p(0.21, 0.36), _p(0.58, 0.05)), look["outfit"])
			draw_colored_polygon(PackedVector2Array([_p(0.78, 0.37), _p(0.92, 0.33), _p(0.9, 0.45)]), look["outfit"])
		"crown":
			draw_colored_polygon(PackedVector2Array([_p(0.3, 0.2), _p(0.35, 0.06), _p(0.42, 0.16), _p(0.5, 0.02),
				_p(0.58, 0.16), _p(0.65, 0.06), _p(0.7, 0.2)]), look["trim"])


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + PI * i / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, color)


func _monster_eyes(y: float, color: Color, angry: bool) -> void:
	var s := size.x
	for x in [0.38, 0.62]:
		_ellipse(_p(x, y), 0.06 * s, 0.07 * s, Color.WHITE if not angry else color)
		draw_circle(_p(x, y + 0.01), 0.032 * s, Color(0.05, 0.02, 0.08) if not angry else Color(1, 1, 0.8))
		draw_circle(_p(x - 0.015, y - 0.02), 0.012 * s, Color.WHITE)
	if angry:
		draw_line(_p(0.3, y - 0.1), _p(0.45, y - 0.06), Color(0.05, 0.02, 0.08), 0.025 * s)
		draw_line(_p(0.7, y - 0.1), _p(0.55, y - 0.06), Color(0.05, 0.02, 0.08), 0.025 * s)


func _draw_blob() -> void:
	var body: Color = look["body"]
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(_p(0.5, 0.55) + Vector2(cos(a), sin(a)) * 0.38 * size.x)
	for i in range(8, -1, -1):
		pts.append(_p(0.12 + 0.76 * i / 8.0, 0.92 - (0.06 if i % 2 == 0 else 0.0)))
	draw_colored_polygon(pts, body)
	draw_circle(_p(0.4, 0.4), 0.08 * size.x, body.lightened(0.2))
	_monster_eyes(0.58, look["eyes"], true)


func _draw_flame() -> void:
	var body: Color = look["body"]
	draw_colored_polygon(PackedVector2Array([_p(0.5, 0.02), _p(0.66, 0.3), _p(0.62, 0.18), _p(0.82, 0.55),
		_p(0.78, 0.82), _p(0.5, 0.96), _p(0.22, 0.82), _p(0.18, 0.55), _p(0.36, 0.22), _p(0.38, 0.36)]), body)
	draw_colored_polygon(PackedVector2Array([_p(0.5, 0.35), _p(0.68, 0.65), _p(0.5, 0.88), _p(0.32, 0.65)]), Color(1, 0.9, 0.4))
	_monster_eyes(0.62, look["eyes"], false)


func _draw_rock() -> void:
	var body: Color = look["body"]
	draw_colored_polygon(PackedVector2Array([_p(0.2, 0.3), _p(0.45, 0.12), _p(0.78, 0.22), _p(0.9, 0.6),
		_p(0.78, 0.95), _p(0.22, 0.95), _p(0.1, 0.6)]), body)
	draw_colored_polygon(PackedVector2Array([_p(0.25, 0.32), _p(0.45, 0.18), _p(0.5, 0.35), _p(0.3, 0.45)]), body.lightened(0.2))
	draw_line(_p(0.6, 0.25), _p(0.68, 0.45), body.darkened(0.3), 0.02 * size.x)
	draw_line(_p(0.3, 0.75), _p(0.42, 0.85), body.darkened(0.3), 0.02 * size.x)
	if id == "guardian":
		for x in [0.3, 0.5, 0.7]:
			draw_circle(_p(x, 0.17), 0.06 * size.x, Color(0.4, 0.75, 0.35))
	_monster_eyes(0.55, look["eyes"], true)


func _draw_drop() -> void:
	var body: Color = look["body"]
	var pts := PackedVector2Array([_p(0.5, 0.05)])
	for i in 17:
		var a := -0.25 * PI + 1.5 * PI * i / 16.0
		pts.append(_p(0.5, 0.62) + Vector2(cos(a), sin(a)) * 0.32 * size.x)
	draw_colored_polygon(pts, body)
	draw_circle(_p(0.38, 0.5), 0.06 * size.x, Color(1, 1, 1, 0.5))
	_monster_eyes(0.65, look["eyes"], false)
