extends Node2D

const GAME_SCENE_PATH := "res://scenes/levels/papan_labirin_kembar.tscn"
const TUTORIAL_SCENE: PackedScene = preload("res://scenes/ui/tutorial_overlay.tscn")
const LABIRIN_A_SCENE: PackedScene = preload("res://scenes/levels/labirin_a.tscn")
const LABIRIN_B_SCENE: PackedScene = preload("res://scenes/levels/labirin_b.tscn")
const WATER_TEX: Texture2D = preload("res://assets/sprites/tiles/environment/water_tiles.png")
const FONT_TITLE: FontFile = preload("res://assets/fonts/Silkscreen-Bold.ttf")
const FONT_TITLE_REG: FontFile = preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")

const VIEWPORT_SIZE := Vector2(1440.0, 900.0)
const MENU_KEYS: Array[String] = ["menu_play", "menu_tutorial", "menu_quit"]

var _water_layer: Node2D
var _water_offset: float = 0.0
var _glow_sprites: Array[Sprite2D] = []
var _glow_time: float = 0.0
var _title_box: Control
var _title_base_y: float = 0.0
var _menu_buttons: Array[Button] = []
var _button_labels: Array[String] = []
var _hovered_idx: int = -1
var _btn_lang: PixelButton
var _tutorial: Control


func _ready() -> void:
	_build_pixel_diorama_background()
	_build_pixel_menu_ui()

	_tutorial = TUTORIAL_SCENE.instantiate() as Control
	_tutorial.visible = false
	_tutorial.z_index = 50
	add_child(_tutorial)

	Lang.language_changed.connect(_on_language_changed)
	_apply_language()
	_play_entrance_animation()


func _exit_tree() -> void:
	if Lang and Lang.language_changed.is_connected(_on_language_changed):
		Lang.language_changed.disconnect(_on_language_changed)


func _process(delta: float) -> void:
	_glow_time += delta
	if _water_layer:
		_water_offset = fmod(_water_offset + delta * 12.0, 96.0)
		_water_layer.position.x = -_water_offset

	var pulse := 0.88 + 0.18 * sin(_glow_time * 2.8)
	for spr in _glow_sprites:
		if is_instance_valid(spr):
			spr.modulate = Color(pulse, pulse, pulse, 1.0)


func _build_pixel_diorama_background() -> void:
	_water_layer = Node2D.new()
	_water_layer.name = "WaterBackdrop"
	_water_layer.z_index = 0
	add_child(_water_layer)

	var water_rect := TextureRect.new()
	water_rect.texture = WATER_TEX
	water_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	water_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water_rect.stretch_mode = TextureRect.STRETCH_TILE
	water_rect.scale = Vector2(3.0, 3.0)
	water_rect.position = Vector2(0.0, 0.0)
	water_rect.size = Vector2(ceilf(VIEWPORT_SIZE.x / 3.0) + 32.0, ceilf(VIEWPORT_SIZE.y / 3.0))
	water_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_layer.add_child(water_rect)

	var ruins := Node2D.new()
	ruins.name = "LabyrinthRuinsBackdrop"
	ruins.z_index = 1
	add_child(ruins)

	# Crisp dark shoreline shadow rims under both floating grass labyrinth islands
	for island_pos in [Vector2(38.0, 162.0), Vector2(762.0, 162.0)]:
		var shore := ColorRect.new()
		shore.position = island_pos + Vector2(-4.0, -4.0)
		shore.size = Vector2(648.0, 588.0)
		shore.color = Color(0.08, 0.14, 0.16, 0.90)
		shore.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ruins.add_child(shore)

	var left_ruin := LABIRIN_A_SCENE.instantiate() as Node2D
	_strip_characters(left_ruin)
	left_ruin.position = Vector2(38.0, 162.0)
	left_ruin.scale = Vector2(2.0, 2.0)
	left_ruin.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ruins.add_child(left_ruin)

	var right_ruin := LABIRIN_B_SCENE.instantiate() as Node2D
	_strip_characters(right_ruin)
	right_ruin.position = Vector2(762.0, 162.0)
	right_ruin.scale = Vector2(2.0, 2.0)
	right_ruin.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ruins.add_child(right_ruin)

	var veil := ColorRect.new()
	veil.z_index = 2
	veil.position = Vector2.ZERO
	veil.size = VIEWPORT_SIZE
	veil.color = Color(0.04, 0.07, 0.09, 0.20)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var rad_grad := Gradient.new()
	rad_grad.set_color(0, Color(0.04, 0.07, 0.08, 0.72))
	rad_grad.add_point(0.55, Color(0.04, 0.07, 0.08, 0.42))
	rad_grad.set_color(rad_grad.get_point_count() - 1, Color(0.04, 0.07, 0.08, 0.0))
	var rad_tex := GradientTexture2D.new()
	rad_tex.gradient = rad_grad
	rad_tex.fill = GradientTexture2D.FILL_RADIAL
	rad_tex.fill_from = Vector2(0.5, 0.5)
	rad_tex.fill_to = Vector2(0.5, 0.0)
	rad_tex.width = 256
	rad_tex.height = 256

	var center_glow := TextureRect.new()
	center_glow.z_index = 2
	center_glow.texture = rad_tex
	center_glow.position = Vector2(240.0, 80.0)
	center_glow.size = Vector2(960.0, 740.0)
	center_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_glow)

	for bar_y in [0.0, VIEWPORT_SIZE.y - 28.0]:
		var bar := ColorRect.new()
		bar.z_index = 3
		bar.position = Vector2(0.0, bar_y)
		bar.size = Vector2(VIEWPORT_SIZE.x, 28.0)
		bar.color = Color(0.04, 0.06, 0.07, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

	for trim_y in [28.0, VIEWPORT_SIZE.y - 31.0]:
		var trim := ColorRect.new()
		trim.z_index = 3
		trim.position = Vector2(0.0, trim_y)
		trim.size = Vector2(VIEWPORT_SIZE.x, 3.0)
		trim.color = Color(0.58, 0.48, 0.26, 0.75)
		trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(trim)


func _strip_characters(labirin: Node2D) -> void:
	var karakter := labirin.get_node_or_null("Karakter")
	if karakter != null:
		labirin.remove_child(karakter)
		karakter.queue_free()

	var penanda := labirin.get_node_or_null("Penanda")
	if penanda != null:
		for child in penanda.get_children():
			var spr := child.get_node_or_null("Sprite2D") as Sprite2D
			if spr != null:
				_glow_sprites.append(spr)


func _build_pixel_menu_ui() -> void:
	var ui_root := Control.new()
	ui_root.name = "MenuUI"
	ui_root.z_index = 10
	ui_root.position = Vector2.ZERO
	ui_root.size = VIEWPORT_SIZE
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	# Single Language Toggle Button (IND / EN) at top-right
	_btn_lang = PixelButton.new()
	_btn_lang.position = Vector2(1312.0, 48.0)
	_btn_lang.size = Vector2(92.0, 46.0)
	_btn_lang.configure(PixelButton.Variant.SLATE, 26, 2.0, false)
	_btn_lang.pressed.connect(_on_lang_pressed)
	ui_root.add_child(_btn_lang)

	_title_box = VBoxContainer.new()
	_title_box.position = Vector2(350.0, 212.0)
	_title_box.size = Vector2(740.0, 180.0)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.add_theme_constant_override("separation", 10)
	_title_base_y = _title_box.position.y
	ui_root.add_child(_title_box)

	var title := Label.new()
	title.text = "TWIN-LABYRINTH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.88, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.07, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.04, 0.96))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	_title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "GAMBIT & ESCAPE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", FONT_TITLE_REG)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.98, 0.82, 0.36, 1.0))
	subtitle.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 1.0))
	subtitle.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.04, 0.92))
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_constant_override("shadow_offset_x", 4)
	subtitle.add_theme_constant_override("shadow_offset_y", 4)
	_title_box.add_child(subtitle)

	var div_wrap := CenterContainer.new()
	div_wrap.custom_minimum_size = Vector2(0.0, 16.0)
	_title_box.add_child(div_wrap)

	var div_outer := ColorRect.new()
	div_outer.custom_minimum_size = Vector2(464.0, 8.0)
	div_outer.color = Color(0.04, 0.05, 0.06, 0.92)
	div_wrap.add_child(div_outer)

	var div_line := ColorRect.new()
	div_line.position = Vector2(2.0, 2.0)
	div_line.size = Vector2(460.0, 4.0)
	div_line.color = Color(0.92, 0.76, 0.36, 0.95)
	div_outer.add_child(div_line)

	var defs := [
		{"variant": PixelButton.Variant.GOLD, "cb": Callable(self, "_on_play_pressed")},
		{"variant": PixelButton.Variant.SLATE, "cb": Callable(self, "_on_tutorial_pressed")},
		{"variant": PixelButton.Variant.CRIMSON, "cb": Callable(self, "_on_quit_pressed")},
	]

	var start_y := 432.0
	var gap_y := 76.0
	for i in range(defs.size()):
		var d: Dictionary = defs[i]
		var btn := PixelButton.new()
		btn.position = Vector2(530.0, start_y + float(i) * gap_y)
		btn.size = Vector2(380.0, 62.0)
		btn.pivot_offset = btn.size * 0.5
		btn.configure(d["variant"], 34, 3.0, true)
		btn.pressed.connect(d["cb"])
		btn.mouse_entered.connect(_on_btn_hover.bind(i, true))
		btn.mouse_exited.connect(_on_btn_hover.bind(i, false))
		ui_root.add_child(btn)
		_menu_buttons.append(btn)
		_button_labels.append("")


func _apply_language() -> void:
	if _btn_lang:
		_btn_lang.text = Lang.button_label()
		_btn_lang.tooltip_text = Lang.t("lang_tooltip")
	for i in range(_menu_buttons.size()):
		var lbl := Lang.t(MENU_KEYS[i])
		_button_labels[i] = lbl
		_menu_buttons[i].text = ("> " + lbl + " <") if (_hovered_idx == i) else lbl


func _on_language_changed(_code: String) -> void:
	_apply_language()


func _on_lang_pressed() -> void:
	Lang.toggle()


func _play_entrance_animation() -> void:
	_title_box.modulate.a = 0.0
	_title_box.position.y = _title_base_y - 28.0
	var title_tw := create_tween().set_parallel(true)
	title_tw.tween_property(_title_box, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	title_tw.tween_property(_title_box, "position:y", _title_base_y, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tw.chain().tween_callback(_start_title_idle_bob)

	for i in range(_menu_buttons.size()):
		var btn := _menu_buttons[i]
		var final_y := btn.position.y
		btn.disabled = true
		btn.modulate.a = 0.0
		btn.position.y = final_y + 34.0
		btn.scale = Vector2(0.88, 0.88)

		var delay := 0.24 + float(i) * 0.13
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(btn, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "position:y", final_y, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func() -> void:
			btn.disabled = false
		)


func _start_title_idle_bob() -> void:
	var bob := create_tween().set_loops()
	bob.tween_property(_title_box, "position:y", _title_base_y - 4.0, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_title_box, "position:y", _title_base_y + 2.0, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_btn_hover(idx: int, hovered: bool) -> void:
	if idx < 0 or idx >= _menu_buttons.size():
		return
	var btn := _menu_buttons[idx]
	if btn.disabled:
		return
	_hovered_idx = idx if hovered else -1
	var base_lbl := _button_labels[idx]
	btn.text = ("> " + base_lbl + " <") if hovered else base_lbl
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.04, 1.04) if hovered else Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_tutorial_pressed() -> void:
	_tutorial.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
