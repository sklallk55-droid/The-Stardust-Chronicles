extends Control
## Prototype screen: story, auto-battle, rewards, gear and squad upgrade. UI is built in code.

const Data = preload("res://data.gd")
const Unit = preload("res://unit.gd")
const Battle = preload("res://battle.gd")
const Equipment = preload("res://equipment.gd")
const Chibi = preload("res://chibi.gd")
const Quests = preload("res://quests.gd")
const Ascension = preload("res://ascension.gd")
const Summon = preload("res://summon.gd")
const Levels = preload("res://levels.gd")
const Fx = preload("res://fx.gd")

const SAVE_PATH := "user://save.cfg"
const IDLE_CAP_SEC := 12 * 3600
const CARD_W := 230.0
const SPRITE := 185.0
const SQUAD_SIZE := 4
const GAME_VERSION := "1.0"
const SPEAKER_IDS := {"Акира": "akira", "Рю": "ryu", "Юки": "yuki", "Каэ": "kae",
	"Генерал Сара": "sara", "Вальдрам": "valdram", "Страж руин": "guardian",
	"Рэн": "ren", "Мира": "mira", "Тэцуо": "tetsuo", "Иса": "isa"}

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
var equipped := {}  # hero_id -> {slot: item}
var inventory: Array = []
var rng := RandomNumberGenerator.new()
var mode := "story"  # story or tower
var tower_floor := 1
var quest_state := {}
var dust := 0  # star dust for ascension
var stars := {}  # hero_id -> stars
var hero_levels := {}  # hero_id -> personal level
var hero_xp := {}  # hero_id -> experience towards the next level
var crystals := 0
var owned: Array = ["akira", "ryu", "yuki", "kae"]
var squad: Array = ["akira", "ryu", "yuki", "kae"]

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
var story_portrait: Control
var squad_panel: PanelContainer
var squad_list: VBoxContainer
var tower_button: Button
var quests_button: Button
var summon_button: Button
var quests_panel: PanelContainer
var quests_list: VBoxContainer
var backdrop: ColorRect
var palette_key = 0
var shake_root: Control
var shake := 0.0
var fx_layer: Control
var cut_in_active := false
var ult_gold := {}  # Button -> bool, whether the gold style is on
var title_screen: Control
var pending_card: Array = []  # chapter title waiting for the title screen to close


func _ready() -> void:
	theme = Fx.make_theme()
	rng.randomize()
	_build_ui()
	_load()
	quest_state = Quests.current(quest_state)
	_prepare_battle()


func _process(delta: float) -> void:
	if running and battle:
		battle.auto_ult = auto_ult
		battle.update(delta * speed)
		_refresh_units()
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 60.0)
		shake_root.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save()


# --- UI construction ---

func _build_ui() -> void:
	backdrop = Fx.make_backdrop()
	add_child(backdrop)
	add_child(Fx.make_embers())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	shake_root = margin

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	var top_panel := PanelContainer.new()
	var top_style := Fx.panel_style(Color(0.55, 0.45, 0.95, 0.5), 0.55)
	top_style.set_content_margin_all(18)
	top_style.content_margin_left = 28
	top_style.content_margin_right = 28
	top_panel.add_theme_stylebox_override("panel", top_style)
	col.add_child(top_panel)
	var top_col := VBoxContainer.new()
	top_panel.add_child(top_col)
	var top := HBoxContainer.new()
	top_col.add_child(top)
	stage_label = _label("", 40)
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(stage_label)
	gold_label = _label("", 36)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	top.add_child(gold_label)
	level_label = _label("", 30)
	level_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	top_col.add_child(level_label)

	col.add_child(_spacer(20))
	enemy_row = _row()
	col.add_child(enemy_row)

	var middle := CenterContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(middle)
	result_label = _label("", 56)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size.x = 960
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
	var squad_button := _button("Отряд", _show_squad)
	squad_button.custom_minimum_size.x = 200
	controls.add_child(squad_button)

	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 24)
	col.add_child(modes)
	tower_button = _button("Башня Пепла", _toggle_tower)
	tower_button.custom_minimum_size.x = 320
	modes.add_child(tower_button)
	quests_button = _button("Задания", _show_quests)
	quests_button.custom_minimum_size.x = 320
	modes.add_child(quests_button)
	summon_button = _button("Призыв", _summon)
	summon_button.custom_minimum_size.x = 320
	modes.add_child(summon_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	col.add_child(actions)
	upgrade_button = _button("", _upgrade)
	upgrade_button.custom_minimum_size = Vector2(440, 110)
	actions.add_child(upgrade_button)
	start_button = _button("В бой!", _on_start)
	start_button.custom_minimum_size = Vector2(440, 110)
	start_button.add_theme_font_size_override("font_size", 42)
	Fx.gold_styles(start_button)
	actions.add_child(start_button)

	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	_build_story_panel()
	_build_squad_panel()
	_build_quests_panel()
	_build_title()


func _build_story_panel() -> void:
	story_panel = PanelContainer.new()
	story_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	story_panel.offset_top = -560
	story_panel.offset_bottom = -40
	story_panel.offset_left = 32
	story_panel.offset_right = -32
	var style := Fx.panel_style(Color(1, 0.82, 0.45), 0.96)
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
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	v.add_child(head)
	story_portrait = Chibi.new()
	story_portrait.custom_minimum_size = Vector2(150, 150)
	head.add_child(story_portrait)
	story_speaker = _label("", 40)
	story_speaker.add_theme_color_override("font_color", Color(1, 0.82, 0.45))
	head.add_child(story_speaker)
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


## Title screen over the living backdrop; a tap anywhere starts the game.
func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)
	var sky := Fx.make_backdrop()
	Fx.set_palette(sky, 3, false)
	title_screen.add_child(sky)
	title_screen.add_child(Fx.make_embers())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(v)
	for t in [["ХРОНИКИ", 64, Color(0.85, 0.8, 1.0)], ["Звёздного Пепла", 104, Color(1, 0.85, 0.45)]]:
		var l := _label(t[0], t[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", t[2])
		l.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.45))
		l.add_theme_constant_override("outline_size", 20)
		v.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for id in ["akira", "ryu", "yuki", "kae"]:
		var c := Chibi.new()
		c.setup(id)
		c.custom_minimum_size = Vector2(230, 230)
		row.add_child(c)
	v.add_child(_spacer(80))
	var tap := _label("Нажмите, чтобы начать", 44)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tap)
	var pulse := tap.create_tween().set_loops()
	pulse.tween_property(tap, "modulate:a", 0.25, 0.9)
	pulse.tween_property(tap, "modulate:a", 1.0, 0.9)
	var ver := _label("Аниме-RPG с автобоем · версия " + GAME_VERSION, 26)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.modulate.a = 0.6
	v.add_child(ver)
	title_screen.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and title_screen.mouse_filter == Control.MOUSE_FILTER_STOP:
			title_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not pending_card.is_empty():
				Fx.title_card(fx_layer, pending_card[0], pending_card[1])
				pending_card = []
			var tw := title_screen.create_tween()
			tw.tween_property(title_screen, "modulate:a", 0.0, 0.5)
			tw.tween_callback(title_screen.queue_free))


func _make_card(u: Unit) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CARD_W, 0)
	box.add_theme_constant_override("separation", 6)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(CARD_W, SPRITE + 40)
	box.add_child(holder)
	# Glowing element-coloured platform under the fighter.
	var aura := TextureRect.new()
	aura.texture = Fx.glow_texture()
	aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aura.stretch_mode = TextureRect.STRETCH_SCALE
	aura.size = Vector2(CARD_W - 10, 70)
	aura.position = Vector2(5, SPRITE + 40 - 52)
	aura.modulate = Color(Fx.element_color(u.element), 0.75)
	holder.add_child(aura)
	var sprite := Chibi.new()
	sprite.setup(u.id)
	var d := SPRITE * (1.25 if u.role == "boss" else 1.0)
	sprite.size = Vector2(d, d)
	sprite.position = Vector2((CARD_W - d) / 2, 20 if u.role != "boss" else 0)
	holder.add_child(sprite)

	var name_label := _label("%s · %s" % [u.name, Data.ELEMENT_NAMES[u.element]], 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	var hp := _bar(Color(0.35, 0.9, 0.45), 22)
	box.add_child(hp)
	if u.role == "boss":
		hp.custom_minimum_size.x = CARD_W
	var en := _bar(Color(0.4, 0.7, 1.0), 10)
	box.add_child(en)
	cards[u] = {"box": box, "sprite": sprite, "base_y": sprite.position.y, "hp": hp, "en": en,
		"fill": hp.get_theme_stylebox("fill")}
	return box


# --- Battle flow ---

func _prepare_battle() -> void:
	for row in [enemy_row, hero_row, ult_row]:
		for c in row.get_children():
			c.queue_free()
	cards.clear()
	ult_buttons.clear()

	var hero_units := []
	for d in Data.heroes_by_ids(squad):
		var hero := Unit.new(d, true, Data.hero_power(level))
		Equipment.apply(hero, equipped.get(hero.id, {}))
		Ascension.apply(hero, stars.get(hero.id, 0))
		Levels.apply(hero, hero_levels.get(hero.id, 1))
		hero_units.append(hero)
	var enemy_units := []
	var enemy_list := Data.tower_enemies(tower_floor) if mode == "tower" else Data.stage_enemies(stage)
	var power := Data.tower_power(tower_floor) if mode == "tower" else Data.enemy_power(stage)
	for d in enemy_list:
		enemy_units.append(Unit.new(d, false, power))

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
	if mode == "story" and stage == 1:
		result_label.text = "Нажмите «В бой!». Когда шкала энергии героя полна,\nнажмите его имя внизу — это ультимейт."
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	var key = "tower" if mode == "tower" else clampi((stage - 1) / 10 + 1, 1, 3)
	if key != palette_key:
		Fx.set_palette(backdrop, key, palette_key != 0)
		palette_key = key
	_refresh_top()
	_refresh_units()
	if mode == "story" and stage > story_seen and stage % 10 == 1 and Data.CHAPTERS.has(stage / 10 + 1):
		var ch: Array = Data.CHAPTERS[stage / 10 + 1]
		if is_instance_valid(title_screen):
			pending_card = ch
		else:
			Fx.title_card(fx_layer, ch[0], ch[1])
	if mode == "story" and stage > story_seen and Data.story().has(stage):
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
	tower_button.disabled = true
	summon_button.disabled = true


func _on_ended(win: bool) -> void:
	running = false
	var after: Array = []
	_refresh_units()
	if win and mode == "tower":
		_on_tower_win()
	elif win:
		Quests.add(quest_state, "wins")
		var reward := Data.victory_gold(stage)
		gold += reward
		result_label.text = "Победа! +%d" % reward
		var drop := Equipment.roll_drop(stage, rng)
		if not drop.is_empty():
			inventory.append(drop)
			Equipment.equip_best(equipped, inventory)
			result_label.text += "\nВыпало: " + Equipment.item_label(drop)
		dust += Ascension.stage_dust(stage)
		result_label.text += "\nЗвёздная пыль +%d" % Ascension.stage_dust(stage)
		_give_xp(Levels.stage_xp(stage))
		if Summon.stage_crystals(stage) > 0:
			crystals += Summon.stage_crystals(stage)
			result_label.text += "\nКристаллы +%d" % Summon.stage_crystals(stage)
		result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		_victory_fx()
		after = Data.story_after().get(stage, [])
		stage += 1
		start_button.text = "Дальше"
	else:
		result_label.text = "Поражение"
		result_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		Fx.flash(fx_layer, Color(0.8, 0.1, 0.15), 0.4)
		shake = 18.0
		start_button.text = "Ещё раз"
	start_button.disabled = false
	upgrade_button.disabled = false
	tower_button.disabled = false
	summon_button.disabled = false
	_refresh_top()
	_save()
	if not after.is_empty():
		_show_story(after)


func _on_tower_win() -> void:
	Quests.add(quest_state, "wins")
	Quests.add(quest_state, "tower")
	var reward := Data.victory_gold(9 + tower_floor) * 2
	gold += reward
	result_label.text = "Этаж %d пройден! +%d" % [tower_floor, reward]
	var drop := Equipment.roll_drop(tower_floor + 10, rng, true)
	inventory.append(drop)
	Equipment.equip_best(equipped, inventory)
	result_label.text += "\nВыпало: " + Equipment.item_label(drop)
	dust += Ascension.tower_dust(tower_floor)
	result_label.text += "\nЗвёздная пыль +%d" % Ascension.tower_dust(tower_floor)
	_give_xp(Levels.tower_xp(tower_floor))
	if Summon.tower_crystals(tower_floor) > 0:
		crystals += Summon.tower_crystals(tower_floor)
		result_label.text += "\nКристаллы +%d" % Summon.tower_crystals(tower_floor)
	result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_victory_fx()
	tower_floor += 1
	start_button.text = "Выше"


func _give_xp(amount: int) -> void:
	result_label.text += " · Опыт +%d" % amount
	var grown := []
	for id in squad:
		if Levels.add_xp(hero_levels, hero_xp, id, amount, stars.get(id, 0)) > 0:
			grown.append(Data.heroes_by_ids([id])[0]["name"])
	if not grown.is_empty():
		result_label.text += "\nНовый уровень: " + ", ".join(grown)


func _toggle_tower() -> void:
	if running:
		return
	if mode == "story" and stage < Data.TOWER_UNLOCK_STAGE:
		result_label.text = "Башня откроется\nпосле босса главы 1"
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
		return
	mode = "tower" if mode == "story" else "story"
	_prepare_battle()


func _on_acted(actor: Unit, target: Unit, amount: float, kind: String) -> void:
	_bump(actor)
	match kind:
		"hit":
			_flash(target)
			_float_text(target, str(int(amount)), Color.WHITE)
			_spark(target, Fx.element_color(actor.element), 10, 1.0)
		"crit":
			_flash(target)
			_float_text(target, "%d!" % int(amount), Color(1, 0.6, 0.2))
			_spark(target, Fx.element_color(actor.element), 26, 1.4)
			_ring(target, Color(1, 0.75, 0.3))
			shake = maxf(shake, 14.0)
		"heal":
			_float_text(target, "+%d" % int(amount), Color(0.4, 1, 0.5))
			_spark(target, Color(0.4, 1, 0.55), 12, 0.7)
		"shield":
			_float_text(target, "Щит", Color(0.5, 0.8, 1))
			_ring(target, Color(0.5, 0.8, 1))


func _on_ult(actor: Unit) -> void:
	if actor.is_hero:
		Quests.add(quest_state, "ults")
	if not cards.has(actor):
		return
	var s: Control = cards[actor]["sprite"]
	s.pivot_offset = s.size / 2
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(s, "scale", Vector2.ONE, 0.18)
	var color := Fx.element_color(actor.element)
	_ring(actor, color)
	_spark(actor, color, 30, 1.2)
	Fx.flash(fx_layer, color, 0.3)
	shake = maxf(shake, 10.0)
	if actor.is_hero and not cut_in_active:
		cut_in_active = true
		var portrait := Chibi.new()
		portrait.setup(actor.id)
		var stripe := Fx.cut_in(fx_layer, portrait, actor.name, actor.id, color)
		stripe.tree_exited.connect(func(): cut_in_active = false)


func _upgrade() -> void:
	var cost := Data.upgrade_cost(level)
	if gold < cost:
		return
	gold -= cost
	level += 1
	Quests.add(quest_state, "upgrade")
	_save()
	_prepare_battle()


func _toggle_speed() -> void:
	speed = 2.0 if speed == 1.0 else 1.0
	speed_button.text = "Скорость ×%d" % int(speed)


# --- Squad screen ---

func _build_squad_panel() -> void:
	squad_panel = PanelContainer.new()
	squad_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	squad_panel.offset_left = 32
	squad_panel.offset_right = -32
	squad_panel.offset_top = 140
	squad_panel.offset_bottom = -140
	var style := Fx.panel_style(Color(0.5, 0.7, 1.0), 0.96)
	style.set_content_margin_all(36)
	squad_panel.add_theme_stylebox_override("panel", style)
	add_child(squad_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	squad_panel.add_child(v)
	v.add_child(_label("Отряд", 52))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	squad_list = VBoxContainer.new()
	squad_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	squad_list.add_theme_constant_override("separation", 28)
	scroll.add_child(squad_list)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	v.add_child(buttons)
	var best := _button("Надеть лучшее", func():
		Equipment.equip_best(equipped, inventory)
		_save()
		_fill_squad())
	best.custom_minimum_size.x = 420
	buttons.add_child(best)
	var close := _button("Закрыть", func():
		squad_panel.hide()
		if not running:
			_prepare_battle())
	close.custom_minimum_size.x = 420
	buttons.add_child(close)
	squad_panel.hide()


func _show_squad() -> void:
	if running:
		return
	_fill_squad()
	squad_panel.show()


func _fill_squad() -> void:
	for c in squad_list.get_children():
		c.queue_free()
	for d in Data.heroes_by_ids(owned):
		var u := Unit.new(d, true, Data.hero_power(level))
		var id := u.id
		var in_squad := squad.has(id)
		var gear: Dictionary = equipped.get(u.id, {})
		Equipment.apply(u, gear)
		var hero_stars: int = stars.get(u.id, 0)
		Ascension.apply(u, hero_stars)
		var hero_level: int = hero_levels.get(u.id, 1)
		Levels.apply(u, hero_level)
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)
		var title := _label("%s · %s · звёзды %d/%d%s" % [u.name, Data.ELEMENT_NAMES[u.element], hero_stars, Ascension.MAX_STARS, " · в отряде" if in_squad else ""], 38)
		title.add_theme_color_override("font_color", u.color)
		block.add_child(title)
		var level_text := "Ур. %d/%d · опыт %d/%d" % [hero_level, Levels.cap(hero_stars), hero_xp.get(u.id, 0), Levels.xp_to_next(hero_level)]
		if hero_level >= Levels.cap(hero_stars):
			level_text = "Ур. %d/%d · предел, нужно возвышение" % [hero_level, Levels.cap(hero_stars)]
			if hero_stars >= Ascension.MAX_STARS:
				level_text = "Ур. %d · максимум" % hero_level
		var lvl_label := _label(level_text, 30)
		lvl_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		block.add_child(lvl_label)
		block.add_child(_label("HP %d   АТК %d   ЗАЩ %d   СКР %d" % [u.max_hp, u.atk, u.def, u.spd], 30))
		for slot in Equipment.SLOTS:
			var text := "%s: —" % Equipment.SLOT_NAMES[slot]
			var color := Color(0.6, 0.6, 0.7)
			if gear.has(slot):
				text = Equipment.item_label(gear[slot])
				color = Equipment.RARITY_COLORS[gear[slot]["rarity"]]
			var l := _label("   " + text, 28)
			l.add_theme_color_override("font_color", color)
			block.add_child(l)
		var passive := _label("   Пассивка (%d зв.): %s" % [Ascension.PASSIVE_STAR, Ascension.PASSIVES[u.id]], 28)
		var passive_on := hero_stars >= Ascension.PASSIVE_STAR
		passive.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if passive_on else Color(0.6, 0.6, 0.7))
		block.add_child(passive)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 16)
		block.add_child(buttons)
		if hero_stars < Ascension.MAX_STARS:
			var price := Ascension.cost(hero_stars)
			var asc := _button("Возвысить (%d пыли)" % price, func(): _ascend(id))
			asc.custom_minimum_size.x = 440
			asc.disabled = dust < price
			buttons.add_child(asc)
		var pick := _button("Убрать из отряда" if in_squad else "Взять в отряд", func(): _toggle_squad(id))
		pick.custom_minimum_size.x = 400
		pick.disabled = (in_squad and squad.size() <= 1) or (not in_squad and squad.size() >= SQUAD_SIZE)
		buttons.add_child(pick)
		squad_list.add_child(block)
	var bag := _label("В сумке: %d / %d" % [inventory.size(), Equipment.INVENTORY_CAP], 28)
	bag.modulate = Color(1, 1, 1, 0.7)
	squad_list.add_child(bag)


func _toggle_squad(hero_id: String) -> void:
	if squad.has(hero_id):
		if squad.size() > 1:
			squad.erase(hero_id)
	elif squad.size() < SQUAD_SIZE:
		squad.append(hero_id)
	_save()
	_fill_squad()


func _ascend(hero_id: String) -> void:
	var have: int = stars.get(hero_id, 0)
	var price := Ascension.cost(have)
	if have >= Ascension.MAX_STARS or dust < price:
		return
	dust -= price
	stars[hero_id] = have + 1
	_save()
	_refresh_top()
	if have == 0:
		squad_panel.hide()
		_prepare_battle()
		_show_story(Ascension.STORIES[hero_id])
	else:
		_fill_squad()


# --- Summon ---

func _summon() -> void:
	if running:
		return
	if crystals < Summon.COST:
		result_label.text = "Нужно %d кристаллов.\nОни даются за боссов,\nбашню и задания" % Summon.COST
		result_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
		return
	crystals -= Summon.COST
	var got := Summon.roll(rng, owned, Data.summon_heroes())
	var hero: Dictionary = Data.heroes_by_ids([got["id"]])[0]
	if got["new"]:
		owned.append(got["id"])
		var lines := [["Призыв", "К отряду присоединяется %s!" % hero["name"]]]
		lines.append_array(Summon.INTRO[got["id"]])
		lines.append(["", "Взять героя в бой можно на экране «Отряд»."])
		_show_story(lines)
	else:
		dust += Summon.DUPLICATE_DUST
		_show_story([["Призыв", "%s уже с вами. Звёздная пыль +%d" % [hero["name"], Summon.DUPLICATE_DUST]]])
	_save()
	_refresh_top()


# --- Daily quests ---

func _build_quests_panel() -> void:
	quests_panel = PanelContainer.new()
	quests_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	quests_panel.offset_left = 32
	quests_panel.offset_right = -32
	quests_panel.offset_top = 300
	quests_panel.offset_bottom = -300
	var style := Fx.panel_style(Color(1, 0.82, 0.45), 0.96)
	style.set_content_margin_all(36)
	quests_panel.add_theme_stylebox_override("panel", style)
	add_child(quests_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	quests_panel.add_child(v)
	v.add_child(_label("Задания на сегодня", 48))
	quests_list = VBoxContainer.new()
	quests_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quests_list.add_theme_constant_override("separation", 20)
	v.add_child(quests_list)
	var close := _button("Закрыть", func(): quests_panel.hide())
	close.custom_minimum_size.x = 420
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	quests_panel.hide()


func _show_quests() -> void:
	if running:
		return
	quest_state = Quests.current(quest_state)
	_fill_quests()
	quests_panel.show()


func _fill_quests() -> void:
	for c in quests_list.get_children():
		c.queue_free()
	for q in Quests.LIST:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var info := _label("%s  %d/%d" % [q["text"], Quests.progress(quest_state, q), q["goal"]], 30)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		var claimed: bool = quest_state["claimed"].has(q["id"])
		var b := _button("Получено" if claimed else "+%d" % Quests.reward(q, stage), func():
			var got := Quests.claim(quest_state, q, stage)
			gold += got
			if got > 0:
				dust += Ascension.QUEST_DUST
				crystals += Summon.QUEST_CRYSTALS
			_save()
			_refresh_top()
			_fill_quests())
		b.custom_minimum_size.x = 220
		b.disabled = not Quests.can_claim(quest_state, q)
		row.add_child(b)
		quests_list.add_child(row)


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
	story_portrait.visible = SPEAKER_IDS.has(line[0])
	if story_portrait.visible:
		story_portrait.setup(SPEAKER_IDS[line[0]])


# --- Visual helpers ---

func _refresh_top() -> void:
	stage_label.text = "Глава %d · Этап %d" % [(stage - 1) / 10 + 1, (stage - 1) % 10 + 1]
	if mode == "tower":
		stage_label.text = "Башня Пепла · этаж %d" % tower_floor
	tower_button.text = "К сюжету" if mode == "tower" else "Башня Пепла"
	var ready_quests := Quests.unclaimed_count(quest_state)
	quests_button.text = "Задания (%d!)" % ready_quests if ready_quests > 0 else "Задания"
	gold_label.text = "Золото: %d · Пыль: %d" % [gold, dust]
	level_label.text = "Уровень отряда: %d · Кристаллы: %d" % [level, crystals]
	summon_button.text = "Призыв (%d)" % Summon.COST
	upgrade_button.text = "Улучшить (%d)" % Data.upgrade_cost(level)


func _refresh_units() -> void:
	for u in cards:
		var c: Dictionary = cards[u]
		c["hp"].value = u.hp / u.max_hp * 100.0
		var ratio: float = u.hp / u.max_hp
		c["fill"].bg_color = Color(0.95, 0.3, 0.3).lerp(Color(1, 0.8, 0.3), clampf(ratio * 2.0, 0, 1)).lerp(Color(0.35, 0.9, 0.45), clampf(ratio * 2.0 - 1.0, 0, 1))
		c["en"].value = u.energy
		c["box"].modulate.a = 1.0 if u.alive() else 0.3
		c["sprite"].self_modulate = Color(0.7, 0.85, 1.0) if u.shield > 0 else Color.WHITE
	for e in ult_buttons:
		var u: Unit = e["unit"]
		var b: Button = e["button"]
		b.disabled = not (running and u.ult_ready())
		b.text = "УЛЬТ!" if u.ult_ready() else u.name
		var gold := u.ult_ready() and running
		if ult_gold.get(b, false) != gold:
			ult_gold[b] = gold
			if gold:
				Fx.gold_styles(b)
			else:
				for st in ["normal", "hover", "pressed"]:
					b.remove_theme_stylebox_override(st)
				b.remove_theme_color_override("font_color")


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


func _center(u: Unit) -> Vector2:
	var s: Control = cards[u]["sprite"]
	return s.global_position + s.size / 2


func _spark(u: Unit, color: Color, amount: int, power: float) -> void:
	if cards.has(u):
		Fx.burst(fx_layer, _center(u), color, amount, power)


func _ring(u: Unit, color: Color) -> void:
	if cards.has(u):
		Fx.ring(fx_layer, _center(u), color)


func _victory_fx() -> void:
	var center := result_label.global_position + result_label.size / 2
	Fx.burst(fx_layer, center, Color(1, 0.85, 0.35), 70, 2.0)
	Fx.ring(fx_layer, center, Color(1, 0.85, 0.35), 90)
	result_label.pivot_offset = result_label.size / 2
	result_label.scale = Vector2(0.4, 0.4)
	create_tween().tween_property(result_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _float_text(u: Unit, text: String, color: Color) -> void:
	if not cards.has(u):
		return
	var s: Control = cards[u]["sprite"]
	var l := _label(text, 44)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	fx_layer.add_child(l)
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
	cfg.set_value("gear", "equipped", equipped)
	cfg.set_value("gear", "inventory", inventory)
	cfg.set_value("tower", "floor", tower_floor)
	cfg.set_value("quests", "state", quest_state)
	cfg.set_value("ascension", "dust", dust)
	cfg.set_value("ascension", "stars", stars)
	cfg.set_value("summon", "crystals", crystals)
	cfg.set_value("summon", "owned", owned)
	cfg.set_value("summon", "squad", squad)
	cfg.set_value("levels", "level", hero_levels)
	cfg.set_value("levels", "xp", hero_xp)
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
	equipped = cfg.get_value("gear", "equipped", {})
	inventory = cfg.get_value("gear", "inventory", [])
	tower_floor = cfg.get_value("tower", "floor", 1)
	quest_state = cfg.get_value("quests", "state", {})
	dust = cfg.get_value("ascension", "dust", 0)
	stars = cfg.get_value("ascension", "stars", {})
	crystals = cfg.get_value("summon", "crystals", 0)
	owned = cfg.get_value("summon", "owned", owned)
	squad = cfg.get_value("summon", "squad", squad)
	hero_levels = cfg.get_value("levels", "level", {})
	hero_xp = cfg.get_value("levels", "xp", {})
	var away := int(Time.get_unix_time_from_system()) - int(cfg.get_value("player", "last_seen", 0))
	away = clampi(away, 0, IDLE_CAP_SEC)
	var idle_gold := int(away / 60.0 * Data.idle_gold_per_min(maxi(1, stage - 1)))
	if idle_gold > 0:
		gold += idle_gold
		_show_story([["Дозор", "Пока вас не было, отряд нёс дозор и собрал %d золота." % idle_gold]])
