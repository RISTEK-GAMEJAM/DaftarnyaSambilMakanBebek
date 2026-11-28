extends Node2D

const UI = preload("res://scripts/maze_ui.gd")

var _number: String
var _accent: Color
var pressed := false:
	set(value):
		pressed = value
		queue_redraw()


func setup(number: String, accent: Color) -> void:
	_number = number
	_accent = accent
	z_index = 1


func _draw() -> void:
	var top := Vector2(8, 11 if pressed else 9)
	var plate_size := Vector2(16, 12)
	var face := _accent.darkened(0.35 if pressed else 0.68)
	draw_rect(Rect2(6, 10, 20, 15), UI.ABYSS)
	if not pressed:
		draw_rect(Rect2(top + Vector2(0, 11), Vector2(16, 3)), _accent.darkened(0.84))
	draw_rect(Rect2(top, plate_size), face)
	draw_rect(Rect2(top + Vector2(1, 1), Vector2(14, 1)), _accent.lightened(0.25 if pressed else 0.15))
	draw_rect(Rect2(top, plate_size), _accent, false, 1.0)
	draw_string(UI.BODY_FONT, top + Vector2(5, 10), _number, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.INK)
