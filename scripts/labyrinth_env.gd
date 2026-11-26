extends Node2D

const WATER_TEX: Texture2D = preload("res://assets/sprites/tiles/environment/water_tiles.png")
const TREE_TEX: Texture2D = preload("res://assets/sprites/tiles/environment/tree.png")
const SAFE_BRIDGE_TEX: Texture2D = preload("res://assets/sprites/tiles/landmarks/safe_bridge.png")

const TILE_SIZE := 32.0
const GRID_W := 10
const GRID_H := 9
const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

@export var start_with_water: bool = true

var _water_sprites: Array[Sprite2D] = []
var _water_time: float = 0.0


func _ready() -> void:
	rebuild_environment()


func _process(delta: float) -> void:
	if _water_sprites.is_empty():
		return
	_water_time += delta
	var shimmer := 0.94 + 0.06 * sin(_water_time * 2.2)
	for spr in _water_sprites:
		if is_instance_valid(spr):
			spr.modulate = Color(shimmer, shimmer, minf(1.0, shimmer + 0.03), 1.0)


func rebuild_environment() -> void:
	# Clear any previously generated water/tree children so regenerated labyrinths refresh cleanly
	_water_sprites.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var parent_node := get_parent()
	if parent_node == null:
		return
	var tilemap := parent_node.get_node_or_null("Lantai") as TileMapLayer
	if tilemap == null:
		return

	# Collect all non-walkable (#) cells across the full 10x9 board
	var empty_set := {}
	for y in range(GRID_H):
		for x in range(GRID_W):
			var c := Vector2i(x, y)
			if tilemap.get_cell_source_id(c) == -1:
				empty_set[c] = true

	# Find SafeSpot horizontal bridges (mask == 10: L+R floor, U+D chasm)
	# Water is placed ONLY immediately around SafeSpot bridges; all other # terrain is forest!
	var water_cells_set := {}
	var bridge_cells := {}
	var penanda := parent_node.get_node_or_null("Penanda")
	if penanda != null:
		for child in penanda.get_children():
			if child is Marker2D and String(child.name).begins_with("SafeSpot"):
				var scell := tilemap.local_to_map(tilemap.to_local(child.global_position))
				var has_up := tilemap.get_cell_source_id(scell + Vector2i.UP) != -1
				var has_right := tilemap.get_cell_source_id(scell + Vector2i.RIGHT) != -1
				var has_down := tilemap.get_cell_source_id(scell + Vector2i.DOWN) != -1
				var has_left := tilemap.get_cell_source_id(scell + Vector2i.LEFT) != -1
				var is_h_bridge := has_left and has_right and (not has_up) and (not has_down)
				if is_h_bridge:
					bridge_cells[scell] = true
				var spr := child.get_node_or_null("Sprite2D") as Sprite2D
				if spr != null:
					# safe_bridge.png already has the crescent moon emblem drawn in its center
					spr.visible = not is_h_bridge
				for d in DIRS:
					var side := scell + d
					if empty_set.has(side):
						water_cells_set[side] = true

	var water_layer := Node2D.new()
	water_layer.name = "KolamAir"
	water_layer.z_index = 0
	add_child(water_layer)

	var tree_layer := Node2D.new()
	tree_layer.name = "HutanPohon"
	tree_layer.z_index = 1
	tree_layer.y_sort_enabled = true
	add_child(tree_layer)

	var bridge_layer := Node2D.new()
	bridge_layer.name = "JembatanAman"
	bridge_layer.z_index = 1
	add_child(bridge_layer)

	var water_list: Array[Vector2i] = []
	var forest_list: Array[Vector2i] = []
	for y in range(GRID_H):
		for x in range(GRID_W):
			var c := Vector2i(x, y)
			if not empty_set.has(c):
				continue
			if water_cells_set.has(c):
				water_list.append(c)
			else:
				forest_list.append(c)

	_populate_water_pocket(water_layer, water_list, empty_set, bridge_cells)
	_populate_tree_pocket(tree_layer, forest_list)
	_populate_safe_bridges(bridge_layer, bridge_cells)


func _populate_safe_bridges(layer: Node2D, bridge_cells: Dictionary) -> void:
	for key in bridge_cells.keys():
		var c: Vector2i = key
		var origin := Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)

		# Water tile underneath hides the opaque lantai slab so water flows cleanly under the arch
		var water_under := Sprite2D.new()
		water_under.texture = WATER_TEX
		water_under.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		water_under.centered = false
		water_under.position = origin
		layer.add_child(water_under)
		_water_sprites.append(water_under)

		# Subtle left/right bank drop shadows where adjacent stone corridors meet the water canal
		var left_lip := ColorRect.new()
		left_lip.position = origin
		left_lip.size = Vector2(2.0, TILE_SIZE)
		left_lip.color = Color(0.06, 0.11, 0.14, 0.45)
		left_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(left_lip)

		var right_lip := ColorRect.new()
		right_lip.position = Vector2(origin.x + TILE_SIZE - 2.0, origin.y)
		right_lip.size = Vector2(2.0, TILE_SIZE)
		right_lip.color = Color(0.06, 0.11, 0.14, 0.45)
		right_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(right_lip)

		# Arched sacred safe bridge sprite on top
		var bridge := Sprite2D.new()
		bridge.texture = SAFE_BRIDGE_TEX
		bridge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bridge.centered = false
		bridge.position = origin
		layer.add_child(bridge)


func _populate_water_pocket(layer: Node2D, pocket: Array[Vector2i], empty_set: Dictionary, bridge_cells: Dictionary) -> void:
	var pocket_set := {}
	for c in pocket:
		pocket_set[c] = true

	for c in pocket:
		var spr := Sprite2D.new()
		spr.texture = WATER_TEX
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		spr.position = Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
		layer.add_child(spr)
		_water_sprites.append(spr)

		var shade := Color(0.06, 0.11, 0.14, 0.65)
		if not pocket_set.has(c + Vector2i.UP) and not bridge_cells.has(c + Vector2i.UP):
			var top_lip := ColorRect.new()
			top_lip.position = Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
			top_lip.size = Vector2(TILE_SIZE, 3.0)
			top_lip.color = shade
			top_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(top_lip)
		if not pocket_set.has(c + Vector2i.LEFT):
			var left_lip := ColorRect.new()
			left_lip.position = Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
			left_lip.size = Vector2(2.0, TILE_SIZE)
			left_lip.color = Color(0.06, 0.11, 0.14, 0.45)
			left_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(left_lip)
		if not pocket_set.has(c + Vector2i.RIGHT):
			var right_lip := ColorRect.new()
			right_lip.position = Vector2((c.x + 1) * TILE_SIZE - 2.0, c.y * TILE_SIZE)
			right_lip.size = Vector2(2.0, TILE_SIZE)
			right_lip.color = Color(0.06, 0.11, 0.14, 0.45)
			right_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(right_lip)
		if not pocket_set.has(c + Vector2i.DOWN) and not bridge_cells.has(c + Vector2i.DOWN) and empty_set.has(c):
			var bot_lip := ColorRect.new()
			bot_lip.position = Vector2(c.x * TILE_SIZE, (c.y + 1) * TILE_SIZE - 2.0)
			bot_lip.size = Vector2(TILE_SIZE, 2.0)
			bot_lip.color = Color(0.42, 0.66, 0.72, 0.35)
			bot_lip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(bot_lip)


func _populate_tree_pocket(layer: Node2D, pocket: Array[Vector2i]) -> void:
	for c in pocket:
		var h: int = absi((c.x * 73 + c.y * 151) % 100)
		var jitter_x := float((h % 5) - 2)
		var jitter_y := float(((h / 5) % 5) - 2)
		var sc := 1.10 + float(h % 3) * 0.06
		var tint := 0.78 + float(h % 4) * 0.04

		var tree := Sprite2D.new()
		tree.texture = TREE_TEX
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.position = Vector2((c.x + 0.5) * TILE_SIZE + 2.0 + jitter_x, (c.y + 0.5) * TILE_SIZE - 2.0 + jitter_y)
		tree.scale = Vector2(sc, sc)
		tree.flip_h = (h % 2 == 1)
		tree.modulate = Color(tint, tint + 0.08, tint + 0.02, 1.0)
		layer.add_child(tree)
