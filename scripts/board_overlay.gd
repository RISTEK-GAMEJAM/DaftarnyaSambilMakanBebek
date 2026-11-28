extends Node2D

const TILE_SIZE := Vector2(32.0, 32.0)

var accent_color: Color = Color(0.55, 0.77, 1.0, 1.0)
var safe_cells: Array[Vector2i] = []
var exit_cell: Vector2i = Vector2i(-1, -1)
var lair_cell: Vector2i = Vector2i(-1, -1)
var runner_cell: Vector2i = Vector2i(-1, -1)
var route_cells: Array[Vector2i] = []
var next_cells: Array[Vector2i] = []
var active_selection: bool = false

var _pulse_time: float = 0.0


func _process(delta: float) -> void:
	if active_selection:
		_pulse_time += delta
		queue_redraw()


func configure_static(accent: Color, safes: Array[Vector2i], exit_pos: Vector2i, lair_pos: Vector2i = Vector2i(-1, -1)) -> void:
	accent_color = accent
	safe_cells = safes
	exit_cell = exit_pos
	lair_cell = lair_pos
	queue_redraw()


func update_dynamic(runner: Vector2i, route: Array[Vector2i], next_valid: Array[Vector2i], is_selecting: bool) -> void:
	runner_cell = runner
	route_cells = route.duplicate()
	next_cells = next_valid.duplicate()
	active_selection = is_selecting
	queue_redraw()


func _cell_rect(cell: Vector2i, inset: float = 2.0) -> Rect2:
	var origin := Vector2(cell.x * TILE_SIZE.x + inset, cell.y * TILE_SIZE.y + inset)
	return Rect2(origin, TILE_SIZE - Vector2(inset * 2.0, inset * 2.0))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * TILE_SIZE.x, (cell.y + 0.5) * TILE_SIZE.y)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_pulse_time * 4.5)

	# Planned route cells + polyline (drawn cleanly above floor & landmark sprites)
	if not route_cells.is_empty():
		var line_pts := PackedVector2Array()
		if runner_cell != Vector2i(-1, -1):
			line_pts.append(_cell_center(runner_cell))
		for i in range(route_cells.size()):
			var c := route_cells[i]
			var rr := _cell_rect(c, 3.0)
			var is_tip := (i == route_cells.size() - 1)
			draw_rect(rr, Color(accent_color.r, accent_color.g, accent_color.b, 0.34 if is_tip else 0.22), true)
			draw_rect(rr, Color(accent_color.r, accent_color.g, accent_color.b, 0.90 if is_tip else 0.60), false, 1.2)
			line_pts.append(_cell_center(c))
		if line_pts.size() >= 2:
			draw_polyline(line_pts, Color(accent_color.r, accent_color.g, accent_color.b, 0.80), 2.0, true)
		for pt_idx in range(1, line_pts.size()):
			var is_last := (pt_idx == line_pts.size() - 1)
			draw_circle(line_pts[pt_idx], 3.2 if is_last else 2.2, Color(accent_color.r, accent_color.g, accent_color.b, 0.95))

	# Adjacent clickable next cells during MOVE phase
	if active_selection:
		for c in next_cells:
			var nr := _cell_rect(c, 2.5)
			draw_rect(nr, Color(accent_color.r, accent_color.g, accent_color.b, 0.10 + 0.12 * pulse), true)
			draw_rect(nr, Color(accent_color.r, accent_color.g, accent_color.b, 0.45 + 0.35 * pulse), false, 1.2)
