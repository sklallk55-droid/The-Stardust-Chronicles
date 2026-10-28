extends Control
## Prototype screen: story, auto-battle, rewards and squad upgrade. UI is built in code.

const Data = preload("res://data.gd")
const Unit = preload("res://unit.gd")
const Battle = preload("res://battle.gd")

const SAVE_PATH := "user://save.cfg"
const IDLE_CAP_SEC := 12 * 3600
const CARD_W := 230.0
const SPRITE := 150.0

var stage := 1
var gold := 0
var level := 1
var story_seen := 0
var battle: Battle
var running := false
var speed := 1.0
var auto_ult := false
var cards := {}  # Unit -> {sprite, hp, en, box}
var ult_buttons := []  # [{unit, button}]
var story_lines: Array = []

var stage_label: Label
var gold_label: Label
var level_label: Label
var enemy_row: HBoxContainer
var hero_row: HBoxContainer
var ult_row: HBoxContainer
var result_label: Label
var start_button: Button
var upgrade_button: Button
var speed_button: Button
var auto_button: CheckButton
var story_panel: PanelContainer
var story_speaker: Label
var story_text: Label


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 34
	_build_ui()
	_load()
	_prepare_battle()


func _process(delta: float) -> void:
	if running and battle:
		battle.auto_ult = auto_ult
		battle.update(delta * speed)
		_refresh_units()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()


# --- UI construction ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	stage_label = _label("", 40)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stage_label)
	gold_label = _label("", 36)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	top.add_child(gold_label)
	level_label = _label("", 30)
	level_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	col.add_child(level_label)

	col.add_child(_spacer(40))
	enemy_row = _row()
	col.add_child(enemy_row)

	var middle := CenterContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(middle)
	result_label = _label("", 72)
	middle.add_child(result_label)

	hero_row = _row()
	col.add_child(hero_row)
	col.add_child(_spacer(16))
	ult_row = _row()
	col.add_child(ult_row)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 24)
	col.add_child(controls)
	auto_button = CheckButton.new()
	auto_button.text = "Авто-ульт"
	auto_button.toggled.connect(func(on): auto_ult = on)
	controls.add_child(auto_button)
	speed_button = _button("Скорость ×1", _toggle_speed)
	controls.add_child(speed_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	col.add_child(actions)
	upgrade_button = _button("", _upgrade)
	upgrade_button.custom_minimum_size = Vector2(440, 110)
	actions.add_child(upgrade_button)
	start_button = _button("В бой!", _on_start)
	start_button.custom_minimum_size = Vector2(440, 110)
	actions.add_child(start_button)

	_build_story_panel()


func _build_story_panel() -> void:
	story_panel = PanelContainer.new()
	story_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	story_panel.offset_top = -560
	story_panel.offset_bottom = -40
	story_panel.offset_left = 32
	story_panel.offset_right = -32
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.1, 0.95)
	style.border_color = Color(1, 0.82, 0.45)
	style.set_border_width_all(4)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(36)
	story_panel.add_theme_stylebox_override("panel", style)
	story_panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_next_story_line())
	add_child(story_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_panel.add_child(v)
	story_speaker = _label("", 40)
	story_speaker.add_theme_color_override("font_color", Color(1, 0.82, 0.45))
	v.add_child(story_speaker)
	story_text = _label("", 36)
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(story_text)
	var hint := _label("Нажмите, чтобы продолжить ▸", 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.6)
	v.add_child(hint)
	for c in v.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_panel.hide()


func _make_card(u: Unit) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CARD_W, 0)
	box.add_theme_constant_override("separation", 6)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W, SPRITE + 40)
	box.add_child(holder)
	var sprite := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = u.color
	style.border_color = Color.WHITE if u.role != "boss" else Color(1, 0.3, 0.3)
	style.set_border_width_all(4)
	style.set_corner_radius_all(int(SPRITE / 2))
	sprite.add_theme_stylebox_override("panel", style)
	var d := SPRITE * (1.25 if u.role == "boss" else 1.0)
	sprite.size = Vector2(d, d)
	sprite.position = Vector2((CARD_W - d) / 2, 20 if u.role != "boss" else 0)
	holder.add_child(sprite)
	var initial := _label(u.name.substr(0, 1), 72)
	initial.add_theme_color_override("font_color", Color(0, 0, 0, 0.55))
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.add_child(initial)

	var name_label := _label("%s · %s" % [u.name, Data.ELEMENT_NAMES[u.element]], 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var hp := _bar(Color(0.35, 0.9, 0.45), 22)
	box.add_child(hp)
	var en := _bar(Color(0.4, 0.7, 1.0), 10)
	box.add_child(en)
	cards[u] = {"box": box, "sprite": sprite, "base_y": sprite.position.y, "hp": hp, "en": en}
	return box


# --- Battle flow ---

func _prepare_battle() -> void:
	for row in [enemy_row, hero_row, ult_row]:
		for c in row.get_children():
			c.queue_free()
	cards.clear()
	ult_buttons.clear()

	var hero_units := []
	for d in Data.heroes():
		hero_units.append(Unit.new(d, true, Data.hero_power(level)))
	var enemy_units := []
	for d in Data.stage_enemies(stage):
		enemy_units.append(Unit.new(d, false, Data.enemy_power(stage)))

	battle = Battle.new(hero_units, enemy_units)
	battle.acted.connect(_on_acted)
	battle.ult_used.connect(_on_ult)
	battle.ended.connect(_on_ended)

	for u in enemy_units:
		enemy_row.add_child(_make_card(u))
	for u in hero_units:
		hero_row.add_child(_make_card(u))
		var b := _button(u.name, func(): battle.use_ult(u))
		b.custom_minimum_size = Vector2(CARD_W, 100)
		ult_row.add_child(b)
		ult_buttons.append({"unit": u, "button": b})

	running = false
	result_label.text = ""
	start_button.text = "В бой!"
	_refresh_top()
	_refresh_units()
	if stage > story_seen and Data.story().has(stage):
		_show_story(Data.story()[stage])
	story_seen = maxi(story_seen, stage)


func _on_start() -> void:
	if battle.finished:
		_prepare_battle()
		if story_panel.visible:
			return
	running = true
	start_button.disabled = true
	upgrade_button.disabled = true


func _on_ended(win: bool) -> void:
	running = false
	_refresh_units()
	if win:
		var reward := Data.victory_gold(stage)
		gold += reward
		result_label.text = "Победа! +%d" % reward
		result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		stage += 1
		start_button.text = "Дальше"
	else:
		result_label.text = "Поражение"
		result_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		start_button.text = "Ещё раз"
	start_button.disabled = false
	upgrade_button.disabled = false
	_refresh_top()
	_save()


func _on_acted(actor: Unit, target: Unit, amount: float, kind: String) -> void:
	_bump(actor)
	match kind:
		"hit":
			_flash(target)
			_float_text(target, str(int(amount)), Color.WHITE)
		"crit":
			_flash(target)
			_float_text(target, "%d!" % int(amount), Color(1, 0.6, 0.2))
		"heal":
			_float_text(target, "+%d" % int(amount), Color(0.4, 1, 0.5))
		"shield":
			_float_text(target, "Щит", Color(0.5, 0.8, 1))


func _on_ult(actor: Unit) -> void:
	if not cards.has(actor):
		return
	var s: Control = cards[actor]["sprite"]
	s.pivot_offset = s.size / 2
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(s, "scale", Vector2.ONE, 0.18)


func _upgrade() -> void:
	var cost := Data.upgrade_cost(level)
	if gold < cost:
		return
	gold -= cost
	level += 1
	_save()
	_prepare_battle()


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	speed_button.text = "Скорость ×%d" % int(speed)


# --- Story ---

func _show_story(lines: Array) -> void:
	story_lines.append_array(lines)
	start_button.disabled = true
	if not story_panel.visible:
		story_panel.show()
		_next_story_line()


func _next_story_line() -> void:
	if story_lines.is_empty():
		story_panel.hide()
		start_button.disabled = false
		return
	var line: Array = story_lines.pop_front()
	story_speaker.text = line[0]
	story_text.text = line[1]


# --- Visual helpers ---

func _refresh_top() -> void:
	stage_label.text = "Глава %d · Этап %d" % [(stage - 1) / 10 + 1, (stage - 1) % 10 + 1]
	gold_label.text = "Золото: %d" % gold
	level_label.text = "Уровень отряда: %d" % level
	upgrade_button.text = "Улучшить (%d)" % Data.upgrade_cost(level)


func _refresh_units() -> void:
	for u in cards:
		var c: Dictionary = cards[u]
		c["hp"].value = u.hp / u.max_hp * 100.0
		c["en"].value = u.energy
		c["box"].modulate.a = 1.0 if u.alive() else 0.3
		c["sprite"].self_modulate = Color(0.7, 0.85, 1.0) if u.shield > 0 else Color.WHITE
	for e in ult_buttons:
		var u: Unit = e["unit"]
		var b: Button = e["button"]
		b.disabled = not (running and u.ult_ready())
		b.text = "УЛЬТ!" if u.ult_ready() else u.name
		b.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if u.ult_ready() else Color.WHITE)


func _bump(u: Unit) -> void:
	if not cards.has(u):
		return
	var s: Control = cards[u]["sprite"]
	var base: float = cards[u]["base_y"]
	var tw := create_tween()
	tw.tween_property(s, "position:y", base + (-30.0 if u.is_hero else 30.0), 0.06 / speed)
	tw.tween_property(s, "position:y", base, 0.1 / speed)


func _flash(u: Unit) -> void:
	if not cards.has(u):
		return
	var s: Control = cards[u]["sprite"]
	s.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(s, "modulate", Color.WHITE, 0.2 / speed)


func _float_text(u: Unit, text: String, color: Color) -> void:
	if not cards.has(u):
		return
	var s: Control = cards[u]["sprite"]
	var l := _label(text, 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.global_position = s.global_position + Vector2(s.size.x / 2 - 30 + randf_range(-20, 20), -10)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 110, 0.7 / speed)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7 / speed)
	tw.tween_callback(l.queue_free)


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 90)
	b.pressed.connect(cb)
	return b


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(CARD_W - 30, height)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 16)
	return r


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# --- Save / idle rewards ---

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "stage", stage)
	cfg.set_value("player", "gold", gold)
	cfg.set_value("player", "level", level)
	cfg.set_value("player", "story_seen", story_seen)
	cfg.set_value("player", "last_seen", int(Time.get_unix_time_from_system()))
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stage = cfg.get_value("player", "stage", 1)
	gold = cfg.get_value("player", "gold", 0)
	level = cfg.get_value("player", "level", 1)
	story_seen = cfg.get_value("player", "story_seen", 0)
	var away := int(Time.get_unix_time_from_system()) - int(cfg.get_value("player", "last_seen", 0))
	away = clampi(away, 0, IDLE_CAP_SEC)
	var idle_gold := int(away / 60.0 * Data.idle_gold_per_min(maxi(1, stage - 1)))
	if idle_gold > 0:
		gold += idle_gold
		_show_story([["Дозор", "Пока вас не было, отряд нёс дозор и собрал %d золота." % idle_gold]])
