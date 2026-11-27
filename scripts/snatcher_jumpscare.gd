class_name SnatcherJumpscare
extends Control

const SNATCHER_SCENE: PackedScene = preload("res://scenes/characters/snatcher.tscn")
const SCREEN := Vector2(1440.0, 900.0)
# Snatcher's origin is at her feet; offset downward so her face, horns & wings fill dead center!
const CENTER_POS := Vector2(720.0, 980.0)
const LUNGE_SCALE := Vector2(14.0, 14.0)

var _flash_bg: ColorRect
var _vignette: TextureRect
var _holder: Node2D
var _snatcher: Node2D
var _active: bool = false
var _elapsed: float = 0.0
var _duration: float = 0.56
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
	_flash_bg.color = Color(0.02, 0.0, 0.02, 0.96)
	_flash_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_bg)

	_holder = Node2D.new()
	_holder.position = CENTER_POS
	_holder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_holder)

	_snatcher = SNATCHER_SCENE.instantiate() as Node2D
	_snatcher.set("control_enabled", false)
	_snatcher.position = Vector2.ZERO
	_holder.add_child(_snatcher)

	# Crimson horror edge vignette
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
	grad.add_point(0.55, Color(0.18, 0.0, 0.03, 0.42))
	grad.set_color(grad.get_point_count() - 1, Color(0.45, 0.0, 0.06, 0.92))
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
	add_child(_vignette)


func trigger() -> void:
	visible = true
	modulate.a = 1.0
	_active = true
	_elapsed = 0.0
	_holder.position = CENTER_POS
	_holder.scale = Vector2(2.2, 2.2)
	_holder.rotation = 0.0
	_snatcher.modulate = Color(1.35, 0.92, 0.96, 1.0)
	_flash_bg.color = Color(0.82, 0.05, 0.14, 0.98)

	GameSettings.play_sound("jumpscare")

	# Explosive lunge straight toward the camera so face, horns & wings fill the 1440x900 screen!
	var lunge := create_tween()
	lunge.tween_property(_holder, "scale", LUNGE_SCALE, 0.085).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(_duration).timeout

	_active = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.14).set_ease(Tween.EASE_IN)
	await fade.finished
	visible = false
	modulate.a = 1.0


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	# Violent high-frequency screen shake + rapid horror strobe
	var intensity := lerpf(42.0, 14.0, clampf(_elapsed / _duration, 0.0, 1.0))
	var jitter := Vector2(
		_rng.randf_range(-intensity, intensity),
		_rng.randf_range(-intensity, intensity)
	)
	_holder.position = CENTER_POS + jitter
	_holder.rotation = deg_to_rad(_rng.randf_range(-7.5, 7.5))

	var frame_idx := int(floorf(_elapsed * 28.0))
	if frame_idx % 3 == 0:
		_flash_bg.color = Color(0.42, 0.02, 0.07, 0.98)
		_snatcher.modulate = Color(1.45, 0.85, 0.90, 1.0)
	elif frame_idx % 3 == 1:
		_flash_bg.color = Color(0.02, 0.0, 0.03, 0.98)
		_snatcher.modulate = Color(1.15, 0.25, 0.32, 1.0)
	else:
		_flash_bg.color = Color(0.14, 0.0, 0.04, 0.98)
		_snatcher.modulate = Color(1.25, 1.05, 1.10, 1.0)
