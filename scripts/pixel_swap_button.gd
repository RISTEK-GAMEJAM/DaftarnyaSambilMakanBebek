class_name PixelSwapButton
extends PixelButton

# Draws two crisp chunky pixel arrows (<- on top, -> on bottom) directly on top of PixelButton!
var _arrow_fg: Control = null


func _ready() -> void:
	super._ready()
	text = ""
	_arrow_fg = Control.new()
	_arrow_fg.name = "SwapArrowsFg"
	_arrow_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_fg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_fg.draw.connect(_draw_arrows)
	add_child(_arrow_fg)
	resized.connect(func() -> void:
		if _arrow_fg:
			_arrow_fg.queue_redraw()
	)


func _notification(what: int) -> void:
	super._notification(what)
	if (what == NOTIFICATION_DRAW or what == NOTIFICATION_RESIZED) and _arrow_fg:
		_arrow_fg.queue_redraw()


func _redraw_bg() -> void:
	super._redraw_bg()
	if _arrow_fg:
		_arrow_fg.queue_redraw()


func _draw_arrows() -> void:
	if _arrow_fg == null:
		return
	var p := pixel_unit
	var w := _arrow_fg.size.x
	var h := _arrow_fg.size.y
	var shift_y := p if _is_down else 0.0
	var cx := roundf(w * 0.5)
	var cy := roundf((h - p * 3.0) * 0.5) + shift_y

	var col := Color(0.46, 0.52, 0.52, 0.78) if disabled else (Color(1.0, 0.94, 0.62, 1.0) if _is_hovered else Color(0.96, 0.94, 0.86, 1.0))
	var shadow := Color(0.05, 0.06, 0.07, 0.90)

	# Top arrow pointing LEFT: <-
	_draw_left_arrow(cx, cy - p * 3.5 + p * 0.7, p, shadow)
	_draw_left_arrow(cx, cy - p * 3.5, p, col)

	# Bottom arrow pointing RIGHT: ->
	_draw_right_arrow(cx, cy + p * 3.5 + p * 0.7, p, shadow)
	_draw_right_arrow(cx, cy + p * 3.5, p, col)


func _draw_left_arrow(cx: float, ay: float, p: float, col: Color) -> void:
	# Shaft
	_arrow_fg.draw_rect(Rect2(cx - p * 4.0, ay - p * 0.5, p * 9.0, p), col)
	# Arrowhead pointing left
	_arrow_fg.draw_rect(Rect2(cx - p * 5.0, ay - p * 0.5, p, p), col)
	_arrow_fg.draw_rect(Rect2(cx - p * 4.0, ay - p * 1.5, p, p * 3.0), col)
	_arrow_fg.draw_rect(Rect2(cx - p * 3.0, ay - p * 2.5, p, p * 5.0), col)


func _draw_right_arrow(cx: float, ay: float, p: float, col: Color) -> void:
	# Shaft
	_arrow_fg.draw_rect(Rect2(cx - p * 5.0, ay - p * 0.5, p * 9.0, p), col)
	# Arrowhead pointing right
	_arrow_fg.draw_rect(Rect2(cx + p * 4.0, ay - p * 0.5, p, p), col)
	_arrow_fg.draw_rect(Rect2(cx + p * 3.0, ay - p * 1.5, p, p * 3.0), col)
	_arrow_fg.draw_rect(Rect2(cx + p * 2.0, ay - p * 2.5, p, p * 5.0), col)
