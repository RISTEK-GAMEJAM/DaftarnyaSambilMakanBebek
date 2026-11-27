extends Node2D

const UI = preload("res://scripts/maze_ui.gd")
const Catalog = preload("res://scripts/stage_catalog.gd")
const Preview = preload("res://scripts/stage_preview.gd")
const ELF_A := preload("res://scenes/characters/elf_boy.tscn")
const ELF_B := preload("res://scenes/characters/elf_girl.tscn")
const TEAM := "DaftarnyaSambilMakanBebek"
const CONTRIBUTORS := [
	["Azkal Azkiya Arifi Putra", "credits_role_azkal"],
	["Hanif Awiyoso Mahendra", "credits_role_hanif"],
	["Philo Pradipta Adhi Satriya", "credits_role_philo"],
]

var _menu: Array[Button] = []
var _language: Button
var _options: Control
var _credits: Panel
var _credit_labels: Array[Label] = []
var _credit_roles: Array[Label] = []
var _close_credits: Button


func _ready() -> void:
	UI.box(self, Rect2(Vector2.ZERO, UI.SCREEN), UI.ABYSS)
	_build_hero()
	UI.box(self, Rect2(56, 129, 1328, 1), UI.LINE)
	UI.box(self, Rect2(56, 797, 1328, 1), UI.LINE)
	var team := UI.label(self, TEAM, 23, UI.MUTED)
	UI.place(team, Rect2(56, 820, 720, 35))
	var jam := UI.label(self, "RISTEK GAME JAM", 17, UI.GOLD, true)
	jam.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.place(jam, Rect2(1042, 820, 342, 36))

	_language = UI.button(self, "", Lang.toggle)
	UI.place(_language, Rect2(1273, 48, 111, 51))
	var title := UI.label(self, "TWIN-LABYRINTH", 46, UI.INK, true)
	UI.place(title, Rect2(56, 197, 685, 72))
	var subtitle := UI.label(self, "GAMBIT & ESCAPE", 28, UI.GOLD, true)
	UI.place(subtitle, Rect2(59, 275, 620, 40))

	var start := UI.button(self, "", _start, PixelButton.Variant.GOLD, 32)
	var options := UI.button(self, "", func() -> void: _options.show())
	var credits := UI.button(self, "", func() -> void: _credits.get_parent().show())
	var quit := UI.button(self, "", get_tree().quit, PixelButton.Variant.CRIMSON)
	_menu = [start, options, credits, quit]
	for index in range(_menu.size()):
		var button := _menu[index]
		var y := 377.0 + 78.0 * index
		UI.place(button, Rect2(59, y, 395, 60))
		button.modulate.a = 0.0
		button.position.y += 12.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.28).set_delay(index * 0.06)
		tween.tween_property(button, "position:y", y, 0.31).set_delay(index * 0.06).set_trans(Tween.TRANS_SINE)

	_build_credits()
	_options = preload("res://scripts/options_panel.gd").new()
	add_child(_options)
	Lang.language_changed.connect(_localize)
	_localize()


func _build_hero() -> void:
	var frame := UI.box(self, Rect2(671, 177, 713, 575), UI.PANEL, UI.LINE)
	var inner := UI.box(frame, Rect2(18, 18, 677, 539), UI.ABYSS, UI.LINE)
	inner.clip_contents = true
	var blueprint := Preview.new()
	inner.add_child(blueprint)
	blueprint.setup(Catalog.layouts_for(3)[0], Rect2(-4, 9, 685, 523), Color("#677f9f"))
	for index in range(2):
		var accent := UI.A if index == 0 else UI.B
		var center := Vector2(190, 362) if index == 0 else Vector2(479, 222)
		var plinth := UI.box(inner, Rect2(center - Vector2(89, 21), Vector2(178, 48)), UI.PANEL, accent)
		UI.box(plinth, Rect2(0, 0, 178, 4), accent)
		var elf: Node2D = [ELF_A, ELF_B][index].instantiate()
		elf.scale *= 4.8
		elf.position = center
		elf.set("default_facing_left", index != 0)
		inner.add_child(elf)


func _start() -> void:
	get_tree().change_scene_to_file(Catalog.SELECT_SCENE)


func _build_credits() -> void:
	var layer := Control.new()
	layer.z_index = 70
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_credits = UI.modal(layer, Rect2(328, 136, 784, 628))
	_credits.get_parent().hide()
	var heading := UI.label(_credits, "", 32, UI.GOLD, true)
	UI.place(heading, Rect2(38, 24, 708, 47))
	UI.box(_credits, Rect2(38, 84, 708, 1), UI.LINE)
	var team_label := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(team_label, Rect2(38, 104, 708, 24))
	var team_name := UI.label(_credits, TEAM, 32)
	UI.place(team_name, Rect2(38, 132, 708, 37))
	var jam := UI.label(_credits, "", 23, UI.MUTED)
	UI.place(jam, Rect2(38, 172, 708, 29))

	var contributor_label := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(contributor_label, Rect2(38, 224, 708, 26))
	for index in range(CONTRIBUTORS.size()):
		var y := 254.0 + index * 64.0
		var name_label := UI.label(_credits, CONTRIBUTORS[index][0], 27)
		UI.place(name_label, Rect2(38, y, 708, 31))
		var role := UI.label(_credits, "", 22, UI.MUTED)
		UI.place(role, Rect2(38, y + 31, 708, 26))
		_credit_roles.append(role)

	var engine := UI.label(_credits, "", 21, UI.MUTED)
	UI.place(engine, Rect2(38, 455, 708, 26))
	var engine_detail := UI.label(_credits, "Godot Engine 4.7.2, Aseprite\nSilkscreen & VT323 (Google Fonts, SIL OFL)", 24)
	UI.place(engine_detail, Rect2(38, 483, 708, 62))
	_credit_labels = [heading, team_label, jam, contributor_label, engine]
	_close_credits = UI.button(_credits, "", func() -> void: _credits.get_parent().hide(), PixelButton.Variant.GOLD)
	UI.place(_close_credits, Rect2(570, 554, 176, 48))


func _localize(_code: String = "") -> void:
	var keys := ["menu_play", "menu_options", "menu_credits", "menu_quit"]
	for index in range(keys.size()):
		_menu[index].text = Lang.t(keys[index])
	_language.text = Lang.button_label()
	_language.tooltip_text = Lang.t("lang_tooltip")
	var credit_keys := ["menu_credits", "credits_team", "credits_jam", "credits_contributors", "credits_tools"]
	for index in range(credit_keys.size()):
		_credit_labels[index].text = Lang.t(credit_keys[index])
	for index in range(CONTRIBUTORS.size()):
		_credit_roles[index].text = Lang.t(CONTRIBUTORS[index][1])
	_close_credits.text = Lang.t("action_close")


func _unhandled_key_input(event: InputEvent) -> void:
	if _credits.get_parent().visible and event.is_action_pressed("ui_cancel"):
		_credits.get_parent().hide()
		get_viewport().set_input_as_handled()
