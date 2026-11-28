class_name PixelButton
extends Button

enum Variant { GOLD, EMERALD, SLATE, CRIMSON, CARD, CARD_SELECTED, CYAN, BRIGHT_GOLD }

const FONT_BODY: FontFile = preload("res://assets/fonts/VT323-Regular.ttf")

const TEX_CYAN: Texture2D = preload("res://assets/sprites/ui/buttons/start_button.png")
const TEX_BRIGHT_GOLD: Texture2D = preload("res://assets/sprites/ui/buttons/tutorial_and_options_button.png")
const TEX_GOLD: Texture2D = preload("res://assets/sprites/ui/buttons/credit_button.png")
const TEX_CRIMSON: Texture2D = preload("res://assets/sprites/ui/buttons/exit_button.png")
const TEX_SLATE: Texture2D = preload("res://assets/sprites/ui/buttons/hud_or_utility_button.png")

@export var variant: Variant = Variant.SLATE:
	set(v):
		variant = v
		_apply_text_colors()
		_refresh_patch()

@export var pixel_unit: float = 2.0:
	set(v):
		pixel_unit = maxf(v, 1.0)
		_apply_content_margins()
		_refresh_patch()

@export var show_rivets: bool = true:
	set(v):
		show_rivets = v

var _is_hovered: bool = false
var _is_down: bool = false
var _patch: NinePatchRect = null


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = false


func _ready() -> void:
	add_theme_font_override("font", FONT_BODY)
	_ensure_patch()
	_apply_empty_styles()
	_apply_text_colors()
	_apply_content_margins()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_refresh_patch)
	_refresh_patch()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW or what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh_patch()


func _ensure_patch() -> void:
	if _patch != null:
		return
	_patch = NinePatchRect.new()
	_patch.name = "CustomButtonPatch"
	_patch.show_behind_parent = true
	_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_patch.patch_margin_left = 7
	_patch.patch_margin_top = 7
	_patch.patch_margin_right = 6
	_patch.patch_margin_bottom = 6
	_patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	_patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	add_child(_patch)


func _texture_for_variant() -> Texture2D:
	match variant:
		Variant.CYAN, Variant.EMERALD, Variant.CARD_SELECTED:
			return TEX_CYAN
		Variant.BRIGHT_GOLD:
			return TEX_BRIGHT_GOLD
		Variant.GOLD:
			return TEX_GOLD
		Variant.CRIMSON:
			return TEX_CRIMSON
		_:
			return TEX_SLATE


func _refresh_patch() -> void:
	if _patch == null:
		return
	_patch.texture = _texture_for_variant()
	var sc := 2.0 if (size.x >= 32.0 and size.y >= 28.0) else 1.0
	_patch.scale = Vector2(sc, sc)
	_patch.size = Vector2(maxf(14.0, size.x / sc), maxf(14.0, size.y / sc))
	_patch.position = Vector2(0.0, 2.0 if (_is_down and not disabled) else 0.0)

	if disabled:
		_patch.modulate = Color(0.54, 0.57, 0.60, 0.72)
	elif _is_down:
		_patch.modulate = Color(0.88, 0.88, 0.88, 1.0)
	elif _is_hovered:
		_patch.modulate = Color(1.13, 1.13, 1.13, 1.0)
	else:
		_patch.modulate = Color(1.0, 1.0, 1.0, 1.0)


func configure(p_variant: Variant, font_size: int = 24, p_pixel_unit: float = 2.0, p_rivets: bool = true) -> void:
	variant = p_variant
	pixel_unit = p_pixel_unit
	show_rivets = p_rivets
	add_theme_font_override("font", FONT_BODY)
	add_theme_font_size_override("font_size", font_size)
	_apply_empty_styles()
	_apply_text_colors()
	_apply_content_margins()
	_refresh_patch()


func _apply_empty_styles() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 14.0
		empty.content_margin_right = 14.0
		empty.content_margin_top = 4.0
		empty.content_margin_bottom = 6.0
		add_theme_stylebox_override(state, empty)


func _apply_content_margins() -> void:
	var pad_x := 12.0
	var press_shift := 2.0 if (_is_down and not disabled) else 0.0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := get_theme_stylebox(state)
		if sb is StyleBoxEmpty:
			var e := sb as StyleBoxEmpty
			e.content_margin_left = pad_x
			e.content_margin_right = pad_x
			e.content_margin_top = 4.0 + press_shift
			e.content_margin_bottom = 6.0 - press_shift


func _apply_text_colors() -> void:
	var normal_col := Color(0.97, 0.96, 0.90, 1.0)
	var hover_col := Color(1.0, 0.99, 0.86, 1.0)
	var outline_col := Color(0.04, 0.06, 0.08, 0.96)
	if variant == Variant.BRIGHT_GOLD:
		normal_col = Color(1.0, 0.99, 0.92, 1.0)
		outline_col = Color(0.18, 0.10, 0.02, 0.98)
	elif variant == Variant.CYAN or variant == Variant.EMERALD:
		normal_col = Color(0.98, 1.0, 1.0, 1.0)
		outline_col = Color(0.03, 0.12, 0.16, 0.98)
	add_theme_color_override("font_color", normal_col)
	add_theme_color_override("font_hover_color", hover_col)
	add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.68, 1.0))
	add_theme_color_override("font_disabled_color", Color(0.56, 0.62, 0.64, 0.82))
	add_theme_color_override("font_outline_color", outline_col)
	add_theme_constant_override("outline_size", 4)


func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_patch()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_is_down = false
	_apply_content_margins()
	_refresh_patch()


func _on_button_down() -> void:
	if disabled:
		return
	_is_down = true
	_apply_content_margins()
	_refresh_patch()


func _on_button_up() -> void:
	_is_down = false
	_apply_content_margins()
	_refresh_patch()
