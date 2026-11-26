class_name PixelDie
extends Control

const DICE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/ui/dice/dice_face_1.png"),
	preload("res://assets/sprites/ui/dice/dice_face_2.png"),
	preload("res://assets/sprites/ui/dice/dice_face_3.png"),
	preload("res://assets/sprites/ui/dice/dice_face_4.png"),
	preload("res://assets/sprites/ui/dice/dice_face_5.png"),
	preload("res://assets/sprites/ui/dice/dice_face_6.png"),
]

@export var value: int = 0:
	set(v):
		value = clampi(v, 0, 6)
		_refresh_visual()

@export var accent_color: Color = Color(0.55, 0.78, 1.0, 1.0)

@export var dimmed: bool = false:
	set(d):
		dimmed = d
		_refresh_visual()

var _tex_rect: TextureRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(64.0, 64.0)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	pivot_offset = size * 0.5

	_tex_rect = TextureRect.new()
	_tex_rect.name = "DieSprite"
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)

	resized.connect(func() -> void:
		pivot_offset = size * 0.5
	)
	_refresh_visual()


func _refresh_visual() -> void:
	if _tex_rect == null:
		return
	var face_idx := clampi(value - 1, 0, 5) if value > 0 else 0
	_tex_rect.texture = DICE_TEXTURES[face_idx]
	if value == 0:
		_tex_rect.modulate = Color(0.52, 0.56, 0.58, 0.65)
	elif dimmed:
		_tex_rect.modulate = Color(0.56, 0.60, 0.62, 0.80)
	else:
		_tex_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)


func play_roll_animation(final_value: int) -> void:
	var base_y := position.y
	var cycles := 8
	for i in range(cycles):
		value = randi_range(1, 6)
		var hop := -10.0 if (i % 2 == 0) else -4.0
		var tilt := deg_to_rad(-9.0 if (i % 2 == 0) else 9.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "position:y", base_y + hop, 0.048).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "rotation", tilt, 0.048)
		await tw.finished

	value = final_value
	var land := create_tween().set_parallel(true)
	land.tween_property(self, "position:y", base_y, 0.10).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	land.tween_property(self, "rotation", 0.0, 0.09)
	land.tween_property(self, "scale", Vector2(1.14, 0.88), 0.07)
	await land.finished

	var settle := create_tween()
	settle.tween_property(self, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await settle.finished
