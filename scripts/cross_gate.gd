extends Node2D

const UI = preload("res://scripts/maze_ui.gd")
const FRAME := preload("res://assets/sprites/tiles/landmarks/gate_frame.png")
const BARS := preload("res://assets/sprites/tiles/landmarks/gate_bars.png")

var _number: String
var _accent: Color
var _open := false
var _animation: Tween
var _lift := 0.0:
	set(value):
		_lift = value
		queue_redraw()


func setup(number: String, accent: Color) -> void:
	_number = number
	_accent = accent
	z_index = 1


func set_open(value: bool) -> Tween:
	if value == _open:
		return null
	_open = value
	if _animation and _animation.is_valid():
		_animation.kill()
	_animation = create_tween()
	var height := float(BARS.get_height()) if _open else 0.0
	_animation.tween_property(self, "_lift", height, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _animation


func _draw() -> void:
	var offset := roundf(_lift)
	var visible_size := BARS.get_size() - Vector2(0, offset)
	if visible_size.y > 0:
		draw_texture_rect_region(BARS, Rect2(Vector2.ZERO, visible_size), Rect2(Vector2(0, offset), visible_size))
	draw_texture(FRAME, Vector2.ZERO)
	draw_rect(Rect2(3, 2, 8, 9), UI.ABYSS)
	draw_string(UI.BODY_FONT, Vector2(5, 10), _number, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _accent)
