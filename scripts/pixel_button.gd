class_name PixelButton
extends Button

enum Variant { GOLD, EMERALD, SLATE, CRIMSON, CARD, CARD_SELECTED }

const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")

@export var variant: Variant = Variant.SLATE:
	set(v):
		variant = v
		_apply_text_colors()
		_redraw_bg()

@export var pixel_unit: float = 2.0:
	set(v):
		pixel_unit = maxf(v, 1.0)
		_apply_content_margins()
		_redraw_bg()

@export var show_rivets: bool = true:
	set(v):
		show_rivets = v
		_redraw_bg()

var _is_hovered: bool = false
var _is_down: bool = false
var _bg: Control = null


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = false


func _ready() -> void:
	add_theme_font_override("font", FONT_BODY)
	_ensure_bg()
	_apply_empty_styles()
	_apply_text_colors()
	_apply_content_margins()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_redraw_bg)
	_redraw_bg()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW or what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_redraw_bg()


func _ensure_bg() -> void:
	if _bg != null:
		return
	_bg = Control.new()
	_bg.name = "PixelBevelBg"
	_bg.show_behind_parent = true
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.draw.connect(_draw_bevel)
	add_child(_bg)


func _redraw_bg() -> void:
	if _bg != null:
		_bg.queue_redraw()


func configure(p_variant: Variant, font_size: int = 24, p_pixel_unit: float = 2.0, p_rivets: bool = true) -> void:
	variant = p_variant
	pixel_unit = p_pixel_unit
	show_rivets = p_rivets
	add_theme_font_override("font", FONT_BODY)
	add_theme_font_size_override("font_size", font_size)
	_apply_empty_styles()
	_apply_text_colors()
	_apply_content_margins()
	_redraw_bg()


func _apply_empty_styles() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 14.0
		empty.content_margin_right = 14.0
		empty.content_margin_top = 4.0
		empty.content_margin_bottom = 4.0 + pixel_unit * 2.0
		add_theme_stylebox_override(state, empty)


func _apply_content_margins() -> void:
	var pad_x := 14.0 if show_rivets else 8.0
	var press_shift := pixel_unit if _is_down else 0.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := get_theme_stylebox(state)
		if sb is StyleBoxEmpty:
			var e := sb as StyleBoxEmpty
			e.content_margin_left = pad_x
			e.content_margin_right = pad_x
			e.content_margin_top = 4.0 + press_shift
			e.content_margin_bottom = 4.0 + pixel_unit * 2.0 - press_shift


func _apply_text_colors() -> void:
	var normal_col := Color(0.96, 0.94, 0.86, 1.0)
	var hover_col := Color(1.0, 0.97, 0.78, 1.0)
	if variant == Variant.GOLD:
		normal_col = Color(1.0, 0.98, 0.88, 1.0)
		hover_col = Color(1.0, 1.0, 0.94, 1.0)
	add_theme_color_override("font_color", normal_col)
	add_theme_color_override("font_hover_color", hover_col)
	add_theme_color_override("font_pressed_color", Color(0.98, 0.88, 0.54, 1.0))
	add_theme_color_override("font_disabled_color", Color(0.48, 0.54, 0.54, 0.85))
	add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.07, 0.95))
	add_theme_constant_override("outline_size", 3)


func _get_palette() -> Dictionary:
	if disabled:
		return {
			"outline": Color(0.05, 0.06, 0.07, 0.85),
			"face": Color(0.12, 0.15, 0.16, 0.85),
			"highlight": Color(0.18, 0.22, 0.23, 0.85),
			"shade": Color(0.08, 0.10, 0.11, 0.85),
			"lip": Color(0.07, 0.09, 0.10, 0.85),
			"rivet": Color(0.24, 0.29, 0.30, 0.75),
		}

	var pal := {}
	match variant:
		Variant.GOLD:
			pal = {
				"outline": Color(0.06, 0.04, 0.02, 1.0),
				"face": Color(0.58, 0.41, 0.14, 1.0),
				"highlight": Color(0.92, 0.76, 0.36, 1.0),
				"shade": Color(0.40, 0.27, 0.09, 1.0),
				"lip": Color(0.30, 0.19, 0.06, 1.0),
				"rivet": Color(1.0, 0.92, 0.62, 1.0),
			}
		Variant.EMERALD:
			pal = {
				"outline": Color(0.04, 0.07, 0.06, 1.0),
				"face": Color(0.14, 0.34, 0.28, 1.0),
				"highlight": Color(0.32, 0.64, 0.52, 1.0),
				"shade": Color(0.09, 0.23, 0.19, 1.0),
				"lip": Color(0.07, 0.17, 0.14, 1.0),
				"rivet": Color(0.62, 0.92, 0.78, 1.0),
			}
		Variant.CRIMSON:
			pal = {
				"outline": Color(0.07, 0.03, 0.04, 1.0),
				"face": Color(0.38, 0.12, 0.18, 1.0),
				"highlight": Color(0.68, 0.26, 0.34, 1.0),
				"shade": Color(0.25, 0.07, 0.12, 1.0),
				"lip": Color(0.18, 0.05, 0.08, 1.0),
				"rivet": Color(0.94, 0.52, 0.58, 1.0),
			}
		Variant.CARD:
			pal = {
				"outline": Color(0.05, 0.07, 0.08, 1.0),
				"face": Color(0.17, 0.22, 0.25, 1.0),
				"highlight": Color(0.38, 0.48, 0.52, 1.0),
				"shade": Color(0.11, 0.15, 0.17, 1.0),
				"lip": Color(0.08, 0.11, 0.13, 1.0),
				"rivet": Color(0.76, 0.84, 0.84, 0.85),
			}
		Variant.CARD_SELECTED:
			pal = {
				"outline": Color(0.05, 0.08, 0.10, 1.0),
				"face": Color(0.20, 0.42, 0.52, 1.0),
				"highlight": Color(0.55, 0.88, 0.96, 1.0),
				"shade": Color(0.13, 0.29, 0.37, 1.0),
				"lip": Color(0.09, 0.21, 0.27, 1.0),
				"rivet": Color(0.92, 0.98, 1.0, 1.0),
			}
		_:
			pal = {
				"outline": Color(0.05, 0.07, 0.08, 1.0),
				"face": Color(0.18, 0.25, 0.27, 1.0),
				"highlight": Color(0.36, 0.48, 0.50, 1.0),
				"shade": Color(0.12, 0.17, 0.19, 1.0),
				"lip": Color(0.09, 0.13, 0.14, 1.0),
				"rivet": Color(0.66, 0.78, 0.78, 0.95),
			}

	if _is_hovered and not _is_down:
		pal["face"] = (pal["face"] as Color).lightened(0.14)
		pal["highlight"] = (pal["highlight"] as Color).lightened(0.18)
		pal["rivet"] = Color(1.0, 0.92, 0.56, 1.0)
	elif _is_down:
		pal["face"] = (pal["face"] as Color).darkened(0.10)

	return pal


func _draw_bevel() -> void:
	if _bg == null:
		return
	var p := pixel_unit
	var w := _bg.size.x
	var h := _bg.size.y
	if w < p * 6.0 or h < p * 6.0:
		return

	var pal := _get_palette()
	var col_outline: Color = pal["outline"]
	var col_face: Color = pal["face"]
	var col_hi: Color = pal["highlight"]
	var col_shade: Color = pal["shade"]
	var col_lip: Color = pal["lip"]
	var col_rivet: Color = pal["rivet"]

	# Hard unblurred pixel drop shadow below the button
	var shadow_col := Color(0.02, 0.03, 0.04, 0.70)
	_bg.draw_rect(Rect2(p * 2.0, h - p, w - p * 3.0, p), shadow_col)

	var top_y := p if _is_down else 0.0
	var lip_h := p if _is_down else p * 2.0
	var bot_y := h - p
	var body_h := bot_y - top_y
	if body_h < p * 4.0:
		return

	# 1. Outer notched pixel silhouette (outline)
	_bg.draw_rect(Rect2(p, top_y, w - p * 2.0, body_h), col_outline)
	_bg.draw_rect(Rect2(0.0, top_y + p, w, body_h - p * 2.0), col_outline)

	# 2. 3D raised bottom lip (extrusion inside outline)
	var inner_x := p
	var inner_w := w - p * 2.0
	var lip_y := bot_y - p - lip_h
	_bg.draw_rect(Rect2(inner_x, lip_y, inner_w, lip_h), col_lip)

	# 3. Main button face above the 3D lip
	var face_y := top_y + p
	var face_h := lip_y - face_y
	if face_h > 0.0:
		_bg.draw_rect(Rect2(inner_x, face_y, inner_w, face_h), col_face)

		# Top bright pixel highlight bar
		_bg.draw_rect(Rect2(inner_x + p, face_y, inner_w - p * 2.0, p), col_hi)
		# Left subtle highlight edge
		_bg.draw_rect(Rect2(inner_x, face_y + p, p, maxf(0.0, face_h - p * 2.0)), col_hi.darkened(0.22))
		# Bottom inner shade strip just above the 3D lip
		if face_h >= p * 3.0:
			_bg.draw_rect(Rect2(inner_x, lip_y - p, inner_w, p), col_shade)
		# Right inner shade edge
		_bg.draw_rect(Rect2(inner_x + inner_w - p, face_y + p, p, maxf(0.0, face_h - p)), col_shade)

		# 4 crisp pixel corner rivets on wide buttons
		if show_rivets and inner_w >= p * 14.0 and face_h >= p * 6.0:
			var rx_l := inner_x + p * 2.0
			var rx_r := inner_x + inner_w - p * 3.0
			var ry_t := face_y + p * 2.0
			var ry_b := lip_y - p * 3.0
			_bg.draw_rect(Rect2(rx_l, ry_t, p, p), col_rivet)
			_bg.draw_rect(Rect2(rx_r, ry_t, p, p), col_rivet)
			if ry_b > ry_t + p:
				_bg.draw_rect(Rect2(rx_l, ry_b, p, p), col_rivet)
				_bg.draw_rect(Rect2(rx_r, ry_b, p, p), col_rivet)

	# Subtle golden hover rim glint along top edge
	if _is_hovered and not disabled and not _is_down:
		_bg.draw_rect(Rect2(p * 2.0, top_y, w - p * 4.0, p), Color(1.0, 0.90, 0.50, 0.55))


func _on_mouse_entered() -> void:
	_is_hovered = true
	_redraw_bg()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_is_down = false
	_apply_content_margins()
	_redraw_bg()


func _on_button_down() -> void:
	if disabled:
		return
	_is_down = true
	_apply_content_margins()
	_redraw_bg()


func _on_button_up() -> void:
	_is_down = false
	_apply_content_margins()
	_redraw_bg()
