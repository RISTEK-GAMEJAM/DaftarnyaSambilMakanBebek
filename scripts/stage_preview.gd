extends Node2D

var _rows: Array
var _area: Rect2
var _accent: Color


func setup(rows: Array, area: Rect2, accent: Color) -> void:
	_rows = rows
	_area = area
	_accent = accent
	queue_redraw()


func _draw() -> void:
	if _rows.is_empty():
		return
	var width := 0
	for row: String in _rows:
		width = maxi(width, row.length())
	var cell_size := floorf(minf(_area.size.x / width, _area.size.y / _rows.size()))
	var top_left := (_area.get_center() - Vector2(width, _rows.size()) * cell_size / 2.0).round()
	for y in range(_rows.size()):
		var row: String = _rows[y]
		for x in range(row.length()):
			if row[x] != "#":
				var cell := Rect2(top_left + Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
				draw_rect(cell.grow(-1.0), Color(_accent, 0.36))
				draw_rect(Rect2(cell.position + Vector2(2, 2), Vector2(cell_size - 4, 2)), Color(_accent, 0.46))
