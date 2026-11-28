class_name SnatcherJumpscare
extends Control

const SNATCHER_SCENE: PackedScene = preload("res://scenes/characters/snatcher.tscn")
const FONT_TITLE: FontFile = preload("res://assets/fonts/Silkscreen-Bold.ttf")
const SCREEN := Vector2(1440.0, 900.0)
# Snatcher's origin is at her feet; offset downward so her face, horns & wings fill dead center!
const CENTER_POS := Vector2(720.0, 980.0)
const LUNGE_SCALE := Vector2(14.5, 14.5)

enum Stage { IDLE, BLACKOUT, LUNGE }

var _flash_bg: ColorRect
var _vignette: TextureRect
var _holder: Node2D
var _snatcher: Node2D
var _behind_lbl: Label
var _behind_base_pos := Vector2(0.0, 404.0)
var _stage: int = Stage.IDLE
var _elapsed: float = 0.0
var _lunge_duration: float = 0.72
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 95
	position = Vector2.ZERO
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.randomize()

	_flash_bg = ColorRect.new()
	_flash_bg.position = Vector2.ZERO
	_flash_bg.size = SCREEN
	_flash_bg.color = Color(0.012, 0.008, 0.018, 1.0)
	_flash_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_bg)

	_holder = Node2D.new()
	_holder.position = CENTER_POS
	_holder.visible = false
	_holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_holder)

	_snatcher = SNATCHER_SCENE.instantiate() as Node2D
	_snatcher.set("control_enabled", false)
	_snatcher.position = Vector2.ZERO
	_holder.add_child(_snatcher)

	# Crimson horror edge vignette (shown during lunge!)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.55, Color(0.18, 0.0, 0.03, 0.42))
	grad.set_color(grad.get_point_count() - 1, Color(0.45, 0.0, 0.06, 0.94))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256

	_vignette = TextureRect.new()
	_vignette.position = Vector2.ZERO
	_vignette.size = SCREEN
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	add_child(_vignette)

	# Creepy "BEHIND YOU..." text shown in dead silence on pitch black before the lunge!
	_behind_lbl = Label.new()
	_behind_lbl.position = _behind_base_pos
	_behind_lbl.size = Vector2(SCREEN.x, 92.0)
	_behind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_behind_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_behind_lbl.add_theme_font_override("font", FONT_TITLE)
	_behind_lbl.add_theme_font_size_override("font_size", 54)
	_behind_lbl.add_theme_color_override("font_color", Color(0.95, 0.24, 0.30, 1.0))
	_behind_lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.0, 0.03, 1.0))
	_behind_lbl.add_theme_constant_override("outline_size", 8)
	_behind_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_behind_lbl.visible = false
	add_child(_behind_lbl)


func trigger() -> void:
	# PHASE 1: Instant blackout + eerie silence + trembling "BEHIND YOU..." text!
	GameSettings.set_music_paused(true)
	_behind_lbl.text = Lang.t("snatcher_behind")
	visible = true
	modulate.a = 1.0
	_holder.visible = false
	_vignette.visible = false
	_flash_bg.color = Color(0.012, 0.008, 0.018, 1.0)
	_behind_lbl.visible = true
	_behind_lbl.modulate.a = 0.0
	_behind_lbl.position = _behind_base_pos
	_stage = Stage.BLACKOUT
	_elapsed = 0.0

	var text_in := create_tween()
	text_in.tween_property(_behind_lbl, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.82).timeout

	# Brief pitch-black beat right before the scare explodes!
	_behind_lbl.visible = false
	await get_tree().create_timer(0.12).timeout

	# PHASE 2: BOOM! Play jumpscare.mp3 + fullscreen Snatcher lunge with violent screen shake!
	_stage = Stage.LUNGE
	_elapsed = 0.0
	_holder.visible = true
	_vignette.visible = true
	_holder.position = CENTER_POS
	_holder.scale = Vector2(2.4, 2.4)
	_holder.rotation = 0.0
	_snatcher.modulate = Color(1.38, 0.90, 0.95, 1.0)
	_flash_bg.color = Color(0.84, 0.04, 0.14, 0.98)

	GameSettings.play_sound("jumpscare")

	var lunge := create_tween()
	lunge.tween_property(_holder, "scale", LUNGE_SCALE, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(_lunge_duration).timeout

	# PHASE 3: Crisp fade straight into Game 24 while the reverb tail echoes!
	_stage = Stage.IDLE
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.16).set_ease(Tween.EASE_IN)
	await fade.finished
	visible = false
	_holder.visible = false
	_vignette.visible = false
	_behind_lbl.visible = false
	modulate.a = 1.0
	GameSettings.set_music_paused(false)


func _process(delta: float) -> void:
	if _stage == Stage.IDLE:
		return
	_elapsed += delta

	if _stage == Stage.BLACKOUT:
		# Subtle eerie horizontal/vertical tremor on "BEHIND YOU..."
		_behind_lbl.position = _behind_base_pos + Vector2(
			_rng.randf_range(-2.5, 2.5),
			_rng.randf_range(-2.0, 2.0)
		)
		return

	# Violent high-frequency screen shake + rapid crimson/black horror strobe
	var intensity := lerpf(44.0, 14.0, clampf(_elapsed / _lunge_duration, 0.0, 1.0))
	var jitter := Vector2(
		_rng.randf_range(-intensity, intensity),
		_rng.randf_range(-intensity, intensity)
	)
	_holder.position = CENTER_POS + jitter
	_holder.rotation = deg_to_rad(_rng.randf_range(-7.5, 7.5))

	var frame_idx := int(floorf(_elapsed * 28.0))
	if frame_idx % 3 == 0:
		_flash_bg.color = Color(0.45, 0.02, 0.07, 0.98)
		_snatcher.modulate = Color(1.45, 0.85, 0.90, 1.0)
	elif frame_idx % 3 == 1:
		_flash_bg.color = Color(0.02, 0.0, 0.03, 0.98)
		_snatcher.modulate = Color(1.18, 0.25, 0.32, 1.0)
	else:
		_flash_bg.color = Color(0.14, 0.0, 0.04, 0.98)
		_snatcher.modulate = Color(1.25, 1.05, 1.10, 1.0)
