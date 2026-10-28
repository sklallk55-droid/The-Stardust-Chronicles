extends RefCounted
## Visual effects built in code: nebula backdrop shader, glow texture, particles, rings, ult cut-ins.

const ELEMENT_COLORS := {
	"fire": Color(1.0, 0.45, 0.2),
	"water": Color(0.3, 0.65, 1.0),
	"nature": Color(0.4, 0.9, 0.4),
	"light": Color(1.0, 0.88, 0.45),
	"dark": Color(0.7, 0.4, 1.0),
}
const ULT_NAMES := {
	"akira": "Клинок рассвета",
	"ryu": "Огненный бастион",
	"yuki": "Ледяная колыбель",
	"kae": "Гнев леса",
	"ren": "Теневой шаг",
	"mira": "Сияние надежды",
	"tetsuo": "Корни горы",
	"isa": "Пепельный вихрь",
}
# Backdrop colours: top, bottom, nebula A, nebula B.
const PALETTES := {
	1: [Color(0.04, 0.03, 0.12), Color(0.17, 0.07, 0.24), Color(0.5, 0.22, 0.75), Color(0.12, 0.35, 0.75)],
	2: [Color(0.02, 0.06, 0.12), Color(0.05, 0.17, 0.25), Color(0.1, 0.55, 0.7), Color(0.3, 0.2, 0.7)],
	3: [Color(0.08, 0.02, 0.05), Color(0.25, 0.06, 0.08), Color(0.85, 0.25, 0.2), Color(0.5, 0.15, 0.55)],
	"tower": [Color(0.06, 0.03, 0.02), Color(0.22, 0.1, 0.04), Color(0.95, 0.45, 0.15), Color(0.6, 0.2, 0.1)],
}

const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec3 col_top : source_color;
uniform vec3 col_bottom : source_color;
uniform vec3 neb_a : source_color;
uniform vec3 neb_b : source_color;
uniform float aspect = 0.5625;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = vec2(uv.x * aspect, uv.y) * 3.0;
	float t = TIME * 0.02;
	vec3 col = mix(col_top, col_bottom, uv.y);
	float n = fbm(p + vec2(t, -t * 0.6));
	float n2 = fbm(p * 1.7 - vec2(t * 0.8, t));
	col += neb_a * smoothstep(0.45, 0.85, n) * 0.6;
	col += neb_b * smoothstep(0.5, 0.9, n2) * 0.5;
	vec2 sp = vec2(uv.x * aspect, uv.y) * 90.0;
	float h = hash(floor(sp));
	if (h > 0.985) {
		float d = length(fract(sp) - 0.5);
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		col += vec3(1.0, 0.95, 0.85) * smoothstep(0.14, 0.0, d) * tw;
	}
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.9;
	COLOR = vec4(col, 1.0);
}
"""

static var _glow: Texture2D


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


## Soft round sprite used by particles and auras.
static func glow_texture() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_glow = tex
	return _glow


static func make_backdrop() -> ColorRect:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BACKDROP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	set_palette(bg, 1, false)
	return bg


static func set_palette(bg: ColorRect, key, smooth := true) -> void:
	var pal: Array = PALETTES.get(key, PALETTES[1])
	var names := ["col_top", "col_bottom", "neb_a", "neb_b"]
	var mat: ShaderMaterial = bg.material
	for i in 4:
		var c: Color = pal[i]
		if smooth:
			bg.create_tween().tween_method(func(v): mat.set_shader_parameter(names[i], v),
				mat.get_shader_parameter(names[i]), c, 1.2)
		else:
			mat.set_shader_parameter(names[i], c)


## Glowing embers rising from the bottom of the screen.
static func make_embers() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = glow_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	p.amount = 46
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.position = Vector2(540, 1990)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(560, 20)
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 210.0
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.7, 0.3, 0.0))
	ramp.set_color(1, Color(1.0, 0.4, 0.6, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.75, 0.35, 0.9))
	ramp.add_point(0.7, Color(1.0, 0.5, 0.5, 0.5))
	p.color_ramp = ramp
	return p


## One-shot spark burst at a global position.
static func burst(parent: Node, pos: Vector2, color: Color, amount: int, power: float = 1.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = glow_texture()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 180.0 * power
	p.initial_velocity_max = 520.0 * power
	p.damping_min = 300.0
	p.damping_max = 500.0
	p.scale_amount_min = 0.15 * power
	p.scale_amount_max = 0.45 * power
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.25, color)
	p.color_ramp = ramp
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Expanding ring at a global position.
static func ring(parent: Node, pos: Vector2, color: Color, radius: float = 60.0) -> void:
	var line := Line2D.new()
	for i in 41:
		var a := TAU * i / 40.0
		line.add_point(Vector2(cos(a), sin(a)) * radius)
	line.width = 10.0
	line.default_color = color
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = add
	parent.add_child(line)
	line.global_position = pos
	line.scale = Vector2(0.3, 0.3)
	var tw := line.create_tween().set_parallel()
	tw.tween_property(line, "scale", Vector2(3.0, 3.0), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(line, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(line.queue_free)


## Full screen colour flash.
static func flash(parent: Control, color: Color, alpha: float = 0.45) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(color, alpha)
	parent.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)


## Anime-style ultimate cut-in: a skewed stripe with the hero portrait and the move name.
static func cut_in(parent: Control, portrait: Control, hero_name: String, unit_id: String, color: Color) -> Control:
	var stripe := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.darkened(0.55), 0.92)
	style.border_color = color.lightened(0.3)
	style.border_width_top = 6
	style.border_width_bottom = 6
	style.skew = Vector2(0.25, 0)
	style.content_margin_left = 140
	style.shadow_color = Color(color, 0.6)
	style.shadow_size = 24
	stripe.add_theme_stylebox_override("panel", style)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.size = Vector2(1080, 300)
	stripe.position = Vector2(-1200, 760)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 36)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.add_child(h)
	portrait.custom_minimum_size = Vector2(280, 280)
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var title := Label.new()
	title.text = ULT_NAMES.get(unit_id, "Ультимейт")
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", color.darkened(0.6))
	title.add_theme_constant_override("outline_size", 14)
	v.add_child(title)
	var who := Label.new()
	who.text = hero_name
	who.add_theme_font_size_override("font_size", 42)
	who.add_theme_color_override("font_color", color.lightened(0.4))
	v.add_child(who)
	parent.add_child(stripe)
	var tw := stripe.create_tween()
	tw.tween_property(stripe, "position:x", 0.0, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.55)
	tw.tween_property(stripe, "position:x", 1300.0, 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(stripe.queue_free)
	return stripe


static func panel_style(border: Color, alpha: float = 0.9) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.12, alpha)
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(26)
	s.shadow_color = Color(border, 0.35)
	s.shadow_size = 18
	return s


## Glossy button look shared by the whole UI.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 34
	var states := {
		"normal": [Color(0.16, 0.1, 0.3, 0.92), Color(0.55, 0.45, 0.95)],
		"hover": [Color(0.22, 0.14, 0.4, 0.95), Color(0.75, 0.65, 1.0)],
		"pressed": [Color(0.32, 0.2, 0.55, 1.0), Color(1.0, 0.85, 0.5)],
		"disabled": [Color(0.1, 0.08, 0.16, 0.7), Color(0.3, 0.27, 0.4)],
		"focus": [Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
	}
	for st in states:
		var s := StyleBoxFlat.new()
		s.bg_color = states[st][0]
		s.border_color = states[st][1]
		s.set_border_width_all(3)
		s.border_width_bottom = 6
		s.set_corner_radius_all(22)
		s.content_margin_left = 20
		s.content_margin_right = 20
		if st == "normal" or st == "hover":
			s.shadow_color = Color(0.5, 0.35, 1.0, 0.3)
			s.shadow_size = 10
		if st == "focus":
			s.draw_center = false
			s.set_border_width_all(0)
		for type in ["Button", "CheckButton"]:
			t.set_stylebox(st, type, s)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.65))
	t.set_color("font_outline_color", "Label", Color(0.02, 0.01, 0.05))
	t.set_constant("outline_size", "Label", 6)
	return t


## Gold variant for the main action button and ready ultimates.
static func gold_styles(b: Button) -> void:
	var states := {
		"normal": [Color(0.55, 0.32, 0.08, 0.95), Color(1.0, 0.85, 0.4)],
		"hover": [Color(0.65, 0.4, 0.1, 0.95), Color(1.0, 0.92, 0.6)],
		"pressed": [Color(0.8, 0.5, 0.15, 1.0), Color(1.0, 1.0, 0.8)],
	}
	for st in states:
		var s := StyleBoxFlat.new()
		s.bg_color = states[st][0]
		s.border_color = states[st][1]
		s.set_border_width_all(3)
		s.border_width_bottom = 6
		s.set_corner_radius_all(22)
		s.shadow_color = Color(1.0, 0.7, 0.2, 0.45)
		s.shadow_size = 16
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color(1, 0.97, 0.85))
