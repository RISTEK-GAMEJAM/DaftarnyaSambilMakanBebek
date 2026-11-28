extends Control

signal closed

const FONT_TITLE: FontFile = preload("res://assets/fonts/Silkscreen-Bold.ttf")
const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")
const UI = preload("res://scripts/maze_ui.gd")
const CrossGate = preload("res://scripts/cross_gate.gd")
const PressurePlate = preload("res://scripts/pressure_plate.gd")
const TEX_EXIT: Texture2D = preload("res://assets/sprites/tiles/landmarks/exit_gate.png")
const TEX_SAFE: Texture2D = preload("res://assets/sprites/tiles/landmarks/safe_bridge.png")
const TEX_LAIR: Texture2D = preload("res://assets/sprites/tiles/landmarks/snatcher_lair.png")
const ICON_SIZE := Vector2(44, 40)

var _btn_close: Button
var _bound_labels: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(1440.0, 900.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	Lang.language_changed.connect(_on_language_changed)
	_apply_language()


func _exit_tree() -> void:
	if Lang and Lang.language_changed.is_connected(_on_language_changed):
		Lang.language_changed.disconnect(_on_language_changed)


func _bind_label(lbl: Label, key: String) -> void:
	_bound_labels.append({"label": lbl, "key": key})


func _apply_language() -> void:
	for entry in _bound_labels:
		var lbl: Label = entry["label"]
		if is_instance_valid(lbl):
			lbl.text = Lang.t(String(entry["key"]))
	if is_instance_valid(_btn_close):
		_btn_close.text = Lang.t("tut_close")


func _on_language_changed(_code: String) -> void:
	_apply_language()


func _make_pixel_box(bg: Color, border: Color, bw: int = 3, shadow_px: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw
	sb.border_width_top = bw
	sb.border_width_right = bw
	sb.border_width_bottom = bw
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_radius_bottom_left = 0
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if shadow_px > 0:
		sb.shadow_color = Color(0.02, 0.03, 0.04, 0.85)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(shadow_px, shadow_px)
	return sb


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(1440.0, 900.0)
	dim.color = Color(0.03, 0.05, 0.06, 0.86)
	add_child(dim)

	var modal := Panel.new()
	modal.position = Vector2(160.0, 64.0)
	modal.size = Vector2(1120.0, 772.0)
	modal.add_theme_stylebox_override(
		"panel",
		_make_pixel_box(Color(0.09, 0.125, 0.13, 0.98), Color(0.46, 0.56, 0.52, 1.0), 4, 8)
	)
	add_child(modal)

	var title := Label.new()
	title.position = Vector2(32.0, 18.0)
	title.size = Vector2(1056.0, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TITLE)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84, 1.0))
	modal.add_child(title)
	_bind_label(title, "tut_title")

	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(32.0, 72.0)
	grid.size = Vector2(1056.0, 514.0)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	modal.add_child(grid)

	grid.add_child(_create_text_card("tut_c1_title", Color(0.55, 0.78, 1.0, 1.0), "tut_c1_body"))
	grid.add_child(_create_landmarks_card())
	grid.add_child(_create_text_card("tut_c3_title", Color(0.98, 0.62, 0.66, 1.0), "tut_c3_body"))
	grid.add_child(_create_text_card("tut_c4_title", Color(0.67, 0.89, 0.64, 1.0), "tut_c4_body"))

	_btn_close = PixelButton.new()
	_btn_close.position = Vector2(390.0, 698.0)
	_btn_close.size = Vector2(340.0, 54.0)
	(_btn_close as PixelButton).configure(PixelButton.Variant.EMERALD, 30, 3.0, true)
	_btn_close.pressed.connect(_close_self)
	modal.add_child(_btn_close)


func _create_text_card(heading_key: String, accent: Color, body_key: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(518.0, 244.0)
	card.add_theme_stylebox_override(
		"panel",
		_make_pixel_box(Color(0.125, 0.168, 0.17, 1.0), Color(0.28, 0.36, 0.35, 1.0), 2, 0)
	)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	var h := Label.new()
	h.add_theme_font_override("font", FONT_TITLE)
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", accent)
	vb.add_child(h)
	_bind_label(h, heading_key)

	var b := Label.new()
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", FONT_BODY)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(0.90, 0.92, 0.90, 1.0))
	vb.add_child(b)
	_bind_label(b, body_key)
	return card


func _create_landmarks_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(518.0, 244.0)
	card.add_theme_stylebox_override(
		"panel",
		_make_pixel_box(Color(0.125, 0.168, 0.17, 1.0), Color(0.28, 0.36, 0.35, 1.0), 2, 0)
	)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)

	var h := Label.new()
	h.add_theme_font_override("font", FONT_TITLE)
	h.add_theme_font_size_override("font_size", 15)
	h.add_theme_color_override("font_color", Color(0.98, 0.84, 0.44, 1.0))
	vb.add_child(h)
	_bind_label(h, "tut_c2_title")

	var gate := CrossGate.new()
	gate.setup("1", UI.A)
	var plate := PressurePlate.new()
	plate.setup("1", UI.A)
	vb.add_child(_create_landmark_row(_drawn_icon(gate), "tut_gate_title", "tut_gate_desc"))
	vb.add_child(_create_landmark_row(_texture_icon(TEX_EXIT), "tut_exit_title", "tut_exit_desc"))
	vb.add_child(_create_landmark_row(_texture_icon(TEX_SAFE), "tut_safe_title", "tut_safe_desc"))
	vb.add_child(_create_landmark_row(_texture_icon(TEX_LAIR), "tut_lair_title", "tut_lair_desc"))
	vb.add_child(_create_landmark_row(_drawn_icon(plate), "tut_plate_title", "tut_plate_desc"))
	return card


func _drawn_icon(art: Node2D) -> Control:
	var icon := Control.new()
	art.scale = Vector2.ONE * 1.25
	art.position.x = 2.0
	icon.add_child(art)
	return icon


func _texture_icon(texture: Texture2D) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon


func _create_landmark_row(icon: Control, title_key: String, desc_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = ICON_SIZE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var txt_col := VBoxContainer.new()
	txt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_col.add_theme_constant_override("separation", 0)
	row.add_child(txt_col)

	var t := Label.new()
	t.add_theme_font_override("font", FONT_BODY)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.98, 0.95, 0.86, 1.0))
	txt_col.add_child(t)
	_bind_label(t, title_key)

	var d := Label.new()
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_override("font", FONT_BODY)
	d.add_theme_font_size_override("font_size", 19)
	d.add_theme_color_override("font_color", Color(0.76, 0.82, 0.80, 1.0))
	txt_col.add_child(d)
	_bind_label(d, desc_key)

	return row


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ESCAPE or kev.keycode == KEY_ENTER or kev.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			_close_self()


func _close_self() -> void:
	visible = false
	closed.emit()
