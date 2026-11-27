extends Node2D

const UI = preload("res://scripts/maze_ui.gd")
const BRIDGE := preload("res://assets/sprites/tiles/landmarks/safe_bridge.png")


func _ready() -> void:
	rebuild_environment()


func rebuild_environment() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var tilemap := get_parent().get_node_or_null("Lantai") as TileMapLayer
	var markers := get_parent().get_node_or_null("Penanda")
	if tilemap == null or markers == null:
		return

	var tile_size := Vector2(tilemap.tile_set.tile_size)
	var area := tilemap.get_used_rect()
	var backdrop := UI.box(self, Rect2(Vector2(area.position) * tile_size, Vector2(area.size) * tile_size), UI.ABYSS)
	backdrop.z_index = -1
	for marker in markers.get_children():
		if not String(marker.name).begins_with("SafeSpot"):
			continue
		var cell := tilemap.local_to_map(tilemap.to_local(marker.global_position))
		var left := tilemap.get_cell_source_id(cell + Vector2i.LEFT) != -1
		var right := tilemap.get_cell_source_id(cell + Vector2i.RIGHT) != -1
		var up := tilemap.get_cell_source_id(cell + Vector2i.UP) != -1
		var down := tilemap.get_cell_source_id(cell + Vector2i.DOWN) != -1
		var horizontal := left and right and not up and not down
		var vertical := up and down and not left and not right
		marker.get_node("Sprite2D").visible = not (horizontal or vertical)
		if horizontal or vertical:
			var center := to_local(tilemap.to_global(tilemap.map_to_local(cell)))
			var chasm := UI.box(self, Rect2(center - tile_size / 2.0, tile_size), UI.ABYSS)
			chasm.z_index = 1
			var sprite := Sprite2D.new()
			sprite.texture = BRIDGE
			sprite.position = center
			sprite.rotation = PI / 2.0 if vertical else 0.0
			sprite.z_index = 1
			add_child(sprite)
