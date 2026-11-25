extends RefCounted

const LAYOUTS := [
	[
		"H...#o",
		".#.#..",
		"S.o...",
		"..#..#",
		"#o...E",
	],
	[
		"#..o.E",
		"H.#..#",
		"....o.",
		".#.#..",
		"So....",
	],
]
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]


static func tile(lane: int, cell: Vector2i) -> String:
	var layout: Array = LAYOUTS[lane]
	if cell.y < 0 or cell.y >= layout.size():
		return "#"
	var row: String = layout[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return "#"
	return row[cell.x]


static func find_tile(lane: int, marker: String) -> Vector2i:
	var layout: Array = LAYOUTS[lane]
	for y in range(layout.size()):
		var x: int = layout[y].find(marker)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


# Return the steps after start, including destination. Adjacent tiles use four directions.
static func shortest_path(lane: int, start: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}

	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == destination:
			while cell != start:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in DIRECTIONS:
			var neighbor: Vector2i = cell + direction
			if tile(lane, neighbor) != "#" and not previous.has(neighbor):
				previous[neighbor] = cell
				frontier.append(neighbor)
	return path
