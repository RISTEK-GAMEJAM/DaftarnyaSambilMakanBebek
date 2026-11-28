extends Node2D

const UI = preload("res://scripts/maze_ui.gd")
const Catalog = preload("res://scripts/stage_catalog.gd")
const Preview = preload("res://scripts/stage_preview.gd")
const Options = preload("res://scripts/options_panel.gd")
const TUTORIAL_SCENE: PackedScene = preload("res://scenes/ui/tutorial_overlay.tscn")
const ELF_A := preload("res://scenes/characters/elf_boy.tscn")
const ELF_B := preload("res://scenes/characters/elf_girl.tscn")
const FONT_TITLE: FontFile = preload("res://assets/fonts/Silkscreen-Bold.ttf")
const FONT_TITLE_REG: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")

const VIEWPORT_SIZE := Vector2(1440.0, 900.0)
const TEAM := "DaftarnyaSambilMakanBebek"
const MENU_KEYS: Array[String] = ["menu_play", "menu_tutorial", "menu_options", "menu_credits", "menu_quit"]
const CONTRIBUTORS := [
	["Azkal Azkiya Arifi Putra", "credits_role_azkal"],
	["Hanif Awiyoso Mahendra", "credits_role_hanif"],
	["Philo Pradipta Adhi Satriya", "credits_role_philo"],
]

var _title_box: Control
var _title_base_y: float = 112.0
var _menu_buttons: Array[PixelButton] = []
var _button_labels: Array[String] = []
var _hovered_idx: int = -1
var _language: PixelButton
var _tutorial: Control
var _options: Control
var _credits: Panel
var _credit_labels: Array[Label] = []
var _credit_roles: Array[Label] = []
var _close_credits: PixelButton


func _ready() -> void:
	_build_azkal_labyrinth_backdrop()
	_build_centered_menu_ui()
	_build_credits()

	_tutorial = TUTORIAL_SCENE.instantiate() as Control
	_tutorial.visible = false
	_tutorial.z_index = 65
	add_child(_tutorial)

	_options = Options.new()
	add_child(_options)

	Lang.language_changed.connect(_localize)
	_localize()
	_play_entrance_animation()


func _exit_tree() -> void:
	if Lang and Lang.language_changed.is_connected(_localize):
		Lang.language_changed.disconnect(_localize)


func _build_azkal_labyrinth_backdrop() -> void:
	# Deep abyss base + Azkal's dual blueprint labyrinths + Elf Boy (left) & Elf Girl (right)
	UI.box(self, Rect2(Vector2.ZERO, VIEWPORT_SIZE), UI.ABYSS)

	var left_frame := UI.box(self, Rect2(38, 128, 650, 650), UI.PANEL, UI.LINE)
	var left_inner := UI.box(left_frame, Rect2(14, 14, 622, 622), UI.ABYSS, UI.LINE)
	left_inner.clip_contents = true
	var bp_a := Preview.new()
	left_inner.add_child(bp_a)
	bp_a.setup(Catalog.layouts_for(3)[0], Rect2(8, 22, 606, 578), Color("#587191"))

	var right_frame := UI.box(self, Rect2(752, 128, 650, 650), UI.PANEL, UI.LINE)
	var right_inner := UI.box(right_frame, Rect2(14, 14, 622, 622), UI.ABYSS, UI.LINE)
	right_inner.clip_contents = true
	var bp_b := Preview.new()
	right_inner.add_child(bp_b)
	bp_b.setup(Catalog.layouts_for(3)[1], Rect2(8, 22, 606, 578), Color("#587191"))

	# Place Elf Boy on left blueprint & Elf Girl on right blueprint (clear of centered title/buttons!)
	var plinth_a_center := Vector2(230, 446)
	var plinth_a := UI.box(left_inner, Rect2(plinth_a_center - Vector2(84, 20), Vector2(168, 44)), UI.PANEL, UI.A)
	UI.box(plinth_a, Rect2(0, 0, 168, 4), UI.A)
	var elf_a: Node2D = ELF_A.instantiate()
	elf_a.scale *= 4.4
	elf_a.position = plinth_a_center
	elf_a.set("default_facing_left", false)
	left_inner.add_child(elf_a)

	var plinth_b_center := Vector2(392, 446)
	var plinth_b := UI.box(right_inner, Rect2(plinth_b_center - Vector2(84, 20), Vector2(168, 44)), UI.PANEL, UI.B)
	UI.box(plinth_b, Rect2(0, 0, 168, 4), UI.B)
	var elf_b: Node2D = ELF_B.instantiate()
	elf_b.scale *= 4.4
	elf_b.position = plinth_b_center
	elf_b.set("default_facing_left", true)
	right_inner.add_child(elf_b)

	# Soft radial center vignette so centered title & custom buttons pop cleanly
	var rad_grad := Gradient.new()
	rad_grad.set_color(0, Color(0.03, 0.045, 0.075, 0.80))
	rad_grad.add_point(0.42, Color(0.03, 0.045, 0.075, 0.42))
	rad_grad.set_color(rad_grad.get_point_count() - 1, Color(0.03, 0.045, 0.075, 0.06))
	var rad_tex := GradientTexture2D.new()
	rad_tex.gradient = rad_grad
	rad_tex.fill = GradientTexture2D.FILL_RADIAL
	rad_tex.fill_from = Vector2(0.5, 0.5)
	rad_tex.fill_to = Vector2(0.5, 0.0)
	rad_tex.width = 256
	rad_tex.height = 256

	var veil := TextureRect.new()
	veil.z_index = 2
	veil.position = Vector2.ZERO
	veil.size = VIEWPORT_SIZE
	veil.texture = rad_tex
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)


func _build_centered_menu_ui() -> void:
	var ui := Control.new()
	ui.name = "PixelMenuUI"
	ui.z_index = 10
	ui.position = Vector2.ZERO
	ui.size = VIEWPORT_SIZE
	add_child(ui)

	_language = PixelButton.new()
	_language.position = Vector2(VIEWPORT_SIZE.x - 118.0, 24.0)
	_language.size = Vector2(88.0, 44.0)
	_language.configure(PixelButton.Variant.SLATE, 22, 2.0, false)
	_language.pressed.connect(Lang.toggle)
	ui.add_child(_language)

	# Centered Floating Title Block (Hanif's Main Menu design)
	_title_box = Control.new()
	_title_box.position = Vector2(0.0, _title_base_y)
	_title_box.size = Vector2(VIEWPORT_SIZE.x, 184.0)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_title_box)

	var main_sh := Label.new()
	main_sh.text = "TWIN-LABYRINTH"
	main_sh.position = Vector2(6.0, 14.0)
	main_sh.size = Vector2(VIEWPORT_SIZE.x, 84.0)
	main_sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_sh.add_theme_font_override("font", FONT_TITLE)
	main_sh.add_theme_font_size_override("font_size", 64)
	main_sh.add_theme_color_override("font_color", Color(0.02, 0.04, 0.06, 0.96))
	_title_box.add_child(main_sh)

	var main_title := Label.new()
	main_title.text = "TWIN-LABYRINTH"
	main_title.position = Vector2(0.0, 8.0)
	main_title.size = Vector2(VIEWPORT_SIZE.x, 84.0)
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.add_theme_font_override("font", FONT_TITLE)
	main_title.add_theme_font_size_override("font_size", 64)
	main_title.add_theme_color_override("font_color", Color(0.99, 0.89, 0.44, 1.0))
	main_title.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.02, 1.0))
	main_title.add_theme_constant_override("outline_size", 10)
	_title_box.add_child(main_title)

	var sub_sh := Label.new()
	sub_sh.text = "GAMBIT & ESCAPE"
	sub_sh.position = Vector2(4.0, 96.0)
	sub_sh.size = Vector2(VIEWPORT_SIZE.x, 40.0)
	sub_sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_sh.add_theme_font_override("font", FONT_TITLE_REG)
	sub_sh.add_theme_font_size_override("font_size", 27)
	sub_sh.add_theme_color_override("font_color", Color(0.02, 0.05, 0.07, 0.95))
	_title_box.add_child(sub_sh)

	var subtitle := Label.new()
	subtitle.text = "GAMBIT & ESCAPE"
	subtitle.position = Vector2(0.0, 92.0)
	subtitle.size = Vector2(VIEWPORT_SIZE.x, 40.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", FONT_TITLE_REG)
	subtitle.add_theme_font_size_override("font_size", 27)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.94, 0.98, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.07, 0.10, 1.0))
	subtitle.add_theme_constant_override("outline_size", 7)
	_title_box.add_child(subtitle)

	var rule := ColorRect.new()
	rule.position = Vector2((VIEWPORT_SIZE.x - 390.0) * 0.5, 140.0)
	rule.size = Vector2(390.0, 4.0)
	rule.color = Color(0.95, 0.80, 0.36, 0.92)
	_title_box.add_child(rule)

	# Centered Uniform Custom Button Stack (all 5 buttons matched to MULAI MAIN size!)
	var specs := [
		{"variant": PixelButton.Variant.CYAN, "w": 272.0, "h": 58.0, "fs": 27, "cb": _start},
		{"variant": PixelButton.Variant.BRIGHT_GOLD, "w": 272.0, "h": 58.0, "fs": 27, "cb": _open_tutorial},
		{"variant": PixelButton.Variant.BRIGHT_GOLD, "w": 272.0, "h": 58.0, "fs": 27, "cb": _open_options},
		{"variant": PixelButton.Variant.GOLD, "w": 272.0, "h": 58.0, "fs": 27, "cb": _open_credits},
		{"variant": PixelButton.Variant.CRIMSON, "w": 272.0, "h": 58.0, "fs": 27, "cb": get_tree().quit},
	]

	var cur_y := 330.0
	for i in range(specs.size()):
		var sp: Dictionary = specs[i]
		var w: float = float(sp["w"])
		var h: float = float(sp["h"])
		var btn := PixelButton.new()
		btn.position = Vector2((VIEWPORT_SIZE.x - w) * 0.5, cur_y)
		btn.size = Vector2(w, h)
		btn.configure(sp["variant"], int(sp["fs"]), 2.0, false)
		btn.pressed.connect(sp["cb"])
		var idx := i
		btn.mouse_entered.connect(func(): _set_hovered(idx))
		btn.mouse_exited.connect(func():
			if _hovered_idx == idx:
				_set_hovered(-1)
		)
		ui.add_child(btn)
		_menu_buttons.append(btn)
		_button_labels.append("")
		cur_y += h + 15.0

	var footer := Label.new()
	footer.text = "RISTEK GAME JAM  •  DAFTARNYASAMBILMAKANBEBEK"
	footer.position = Vector2(0.0, VIEWPORT_SIZE.y - 42.0)
	footer.size = Vector2(VIEWPORT_SIZE.x, 28.0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_override("font", FONT_BODY)
	footer.add_theme_font_size_override("font_size", 21)
	footer.add_theme_color_override("font_color", Color(0.68, 0.78, 0.84, 0.88))
	ui.add_child(footer)


func _build_credits() -> void:
	# Azkal's clean editorial Credits popup + user's custom GOLD button
	var layer := Control.new()
	layer.z_index = 70
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_credits = UI.modal(layer, Rect2(318, 116, 804, 668))
	_credits.get_parent().hide()

	var heading := UI.label(_credits, "", 32, UI.GOLD, true)
	UI.place(heading, Rect2(38, 24, 728, 47))
	UI.box(_credits, Rect2(38, 84, 728, 1), UI.LINE)

	var team_label := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(team_label, Rect2(38, 102, 728, 24))
	var team_name := UI.label(_credits, TEAM, 32)
	UI.place(team_name, Rect2(38, 130, 728, 37))
	var jam := UI.label(_credits, "", 23, UI.MUTED)
	UI.place(jam, Rect2(38, 170, 728, 28))

	var contributor_label := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(contributor_label, Rect2(38, 218, 728, 26))
	for index in range(CONTRIBUTORS.size()):
		var y := 248.0 + index * 66.0
		var name_label := UI.label(_credits, CONTRIBUTORS[index][0], 27)
		UI.place(name_label, Rect2(38, y, 728, 31))
		var role := UI.label(_credits, "", 21, UI.MUTED)
		UI.place(role, Rect2(38, y + 31, 728, 28))
		_credit_roles.append(role)

	var engine := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(engine, Rect2(38, 454, 728, 26))
	var engine_detail := UI.label(_credits, "Godot Engine 4.7.2, Aseprite\nSilkscreen & VT323 (Google Fonts, SIL OFL)\nBGM: Short Mystical Orchestral Loop — NR-Music (Pixabay)\nSFX: Jump Scare Sound 2 — freesound_community (Pixabay)", 21)
	UI.place(engine_detail, Rect2(38, 480, 728, 108))
	_credit_labels = [heading, team_label, jam, contributor_label, engine]

	_close_credits = UI.button(_credits, "", func() -> void: _credits.get_parent().hide(), PixelButton.Variant.GOLD, 24)
	UI.place(_close_credits, Rect2(586, 592, 180, 48))


func _localize(_code: String = "") -> void:
	_language.text = Lang.button_label()
	_language.tooltip_text = Lang.t("lang_tooltip")
	for i in range(mini(_menu_buttons.size(), MENU_KEYS.size())):
		_button_labels[i] = Lang.t(MENU_KEYS[i])
	_set_hovered(_hovered_idx)

	var credit_keys := ["menu_credits", "credits_team", "credits_jam", "credits_contributors", "credits_tools"]
	for index in range(credit_keys.size()):
		_credit_labels[index].text = Lang.t(credit_keys[index])
	for index in range(CONTRIBUTORS.size()):
		_credit_roles[index].text = Lang.t(CONTRIBUTORS[index][1])
	_close_credits.text = Lang.t("action_close")


func _set_hovered(idx: int) -> void:
	_hovered_idx = idx
	for i in range(_menu_buttons.size()):
		var base := _button_labels[i]
		_menu_buttons[i].text = ("> " + base + " <") if i == _hovered_idx else base


func _play_entrance_animation() -> void:
	_title_box.modulate.a = 0.0
	_title_box.position.y = _title_base_y - 20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.42).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title_box, "position:y", _title_base_y, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in range(_menu_buttons.size()):
		var b := _menu_buttons[i]
		b.modulate.a = 0.0
		var btw := create_tween()
		btw.tween_interval(0.08 + float(i) * 0.06)
		btw.tween_property(b, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)

	var bob := create_tween().set_loops()
	bob.tween_property(_title_box, "position:y", _title_base_y - 4.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_title_box, "position:y", _title_base_y + 3.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start() -> void:
	get_tree().change_scene_to_file(Catalog.SELECT_SCENE)


func _open_tutorial() -> void:
	_tutorial.visible = true


func _open_options() -> void:
	_options.show()


func _open_credits() -> void:
	_credits.get_parent().show()


func _unhandled_key_input(event: InputEvent) -> void:
	if _credits.get_parent().visible and event.is_action_pressed("ui_cancel"):
		_credits.get_parent().hide()
		get_viewport().set_input_as_handled()
		return
	if (_tutorial and _tutorial.visible) or (_options and _options.visible) or _credits.get_parent().visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ENTER or kev.keycode == KEY_SPACE:
			_start()
