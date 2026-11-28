extends CharacterBody2D

signal captured_target(target: Node2D)
signal released_target(target: Node2D)

@export_group("Player & Multi-Map Setup")
@export var control_enabled: bool = true
@export_range(1, 2) var player_index: int = 1
@export var allow_shared_keys: bool = true

@export_group("Movement")
@export var move_speed: float = 135.0
@export var carry_speed_multiplier: float = 0.78
@export var max_tilt_degrees: float = 12.0
@export var tilt_smoothness: float = 10.0
@export var default_facing_right: bool = true

@export_group("Tail Capture")
@export var grab_range: float = 64.0
@export var carry_waist_offset: Vector2 = Vector2(0.0, -10.0)
@export var capture_group: StringName = &"capturable"

@onready var visuals: Node2D = $Visuals
@onready var tail_physics: Node2D = $TailPhysics
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var facing_right: bool = true
var carried_target: Node2D = null
var _is_striking: bool = false
var _grab_key_was_down: bool = false
var _prev_global_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	facing_right = default_facing_right
	_prev_global_pos = global_position
	_apply_facing()
	anim_player.play("idle")
	if tail_physics and tail_physics.has_method("set_motion_state"):
		tail_physics.set_motion_state(facing_right, Vector2.ZERO)


func set_facing_right(is_right: bool) -> void:
	facing_right = is_right
	if is_node_ready():
		_apply_facing()


func teleport_to_local(pos: Vector2) -> void:
	position = pos
	_prev_global_pos = global_position
	velocity = Vector2.ZERO
	if tail_physics and tail_physics.has_method("reset_chain"):
		tail_physics.reset_chain()


func _apply_facing() -> void:
	# Original art faces left (tail on right), so scale.x = -1 faces right.
	visuals.scale.x = -1.0 if facing_right else 1.0


func _get_move_input() -> Vector2:
	if not control_enabled:
		return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	if player_index == 1:
		x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		if allow_shared_keys and x == 0.0 and y == 0.0:
			x = Input.get_axis("ui_left", "ui_right")
			y = Input.get_axis("ui_up", "ui_down")
	else:
		x = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
		y = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))

	var dir := Vector2(x, y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


func _is_grab_pressed() -> bool:
	if not control_enabled:
		return false
	if player_index == 1:
		return Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE)
	return Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_CTRL)


func toggle_grab() -> void:
	if _is_striking:
		return
	if is_instance_valid(carried_target):
		release_target()
	else:
		try_grab_nearest()


func try_grab_nearest() -> bool:
	if _is_striking or is_instance_valid(carried_target):
		return false

	var best_target: Node2D = null
	var best_dist := grab_range
	var my_world := get_world_2d()

	for node in get_tree().get_nodes_in_group(capture_group):
		if not (node is Node2D):
			continue
		var candidate := node as Node2D
		if candidate == self or candidate.get_world_2d() != my_world:
			continue
		if candidate.has_method("is_captured") and candidate.is_captured():
			continue
		var d := global_position.distance_to(candidate.global_position)
		if d <= best_dist:
			best_dist = d
			best_target = candidate

	if best_target:
		grab_target(best_target)
		return true
	return false


func grab_target(target: Node2D) -> void:
	if not is_instance_valid(target) or _is_striking or is_instance_valid(carried_target):
		return
	_is_striking = true
	if tail_physics and tail_physics.has_method("start_strike"):
		tail_physics.start_strike(target, carry_waist_offset, Callable(self, "_on_tail_strike_hit").bind(target))
	else:
		_on_tail_strike_hit(target)


func _on_tail_strike_hit(target: Node2D) -> void:
	_is_striking = false
	if not is_instance_valid(target):
		if tail_physics and tail_physics.has_method("release_carry"):
			tail_physics.release_carry()
		return

	carried_target = target
	if carried_target.has_method("set_captured"):
		carried_target.set_captured(true)
	captured_target.emit(carried_target)


func release_target() -> void:
	if is_instance_valid(carried_target):
		var released := carried_target
		carried_target = null
		if released.has_method("set_captured"):
			released.set_captured(false)
		released_target.emit(released)
	_is_striking = false
	if tail_physics and tail_physics.has_method("release_carry"):
		tail_physics.release_carry()


func _physics_process(delta: float) -> void:
	var is_carrying := is_instance_valid(carried_target)
	var motion_vel := Vector2.ZERO
	var move_dir := Vector2.ZERO

	if control_enabled:
		# Edge-triggered grab/release input
		var grab_down := _is_grab_pressed()
		if grab_down and not _grab_key_was_down:
			toggle_grab()
		_grab_key_was_down = grab_down

		var input_dir := _get_move_input()
		var active_speed := move_speed * (carry_speed_multiplier if is_carrying else 1.0)
		velocity = input_dir * active_speed
		move_and_slide()
		motion_vel = velocity
		move_dir = input_dir
	else:
		# Board/Tween-driven mode: derive velocity from actual global displacement
		var dt := maxf(delta, 0.001)
		motion_vel = (global_position - _prev_global_pos) / dt
		var speed := motion_vel.length()
		if speed > 8.0:
			move_dir = motion_vel / maxf(speed, 1.0)
		else:
			motion_vel = Vector2.ZERO
			move_dir = Vector2.ZERO

	_prev_global_pos = global_position

	# Update facing direction when moving horizontally
	if move_dir.x > 0.05:
		facing_right = true
		_apply_facing()
	elif move_dir.x < -0.05:
		facing_right = false
		_apply_facing()

	# Switch between idle and move animations (+ faster wingbeat when carrying an Elf)
	anim_player.speed_scale = 1.25 if is_carrying else 1.0
	if move_dir.length() > 0.05:
		if anim_player.current_animation != "move":
			anim_player.play("move", 0.12)
	else:
		if anim_player.current_animation != "idle":
			anim_player.play("idle", 0.18)

	# Smoothly tilt body toward flight direction
	var t := clampf(tilt_smoothness * delta, 0.0, 1.0)
	var target_tilt := deg_to_rad(move_dir.x * max_tilt_degrees)
	visuals.rotation = lerp_angle(visuals.rotation, target_tilt, t)

	# Feed facing & velocity into tail physics
	if tail_physics and tail_physics.has_method("set_motion_state"):
		tail_physics.set_motion_state(facing_right, motion_vel)

	# Keep captured target tied neatly to the tail tip with natural pendulum sway
	if is_carrying and tail_physics and tail_physics.has_method("get_tip_position"):
		var tip_pos: Vector2 = tail_physics.get_tip_position()
		var target_scale := carried_target.global_scale.abs()
		var scaled_offset := Vector2(carry_waist_offset.x * target_scale.x, carry_waist_offset.y * target_scale.y)
		carried_target.global_position = carried_target.global_position.lerp(
			tip_pos - scaled_offset,
			clampf(22.0 * delta, 0.0, 1.0)
		)
		var sway: float = tail_physics.get_carry_sway_angle()
		carried_target.rotation = lerp_angle(carried_target.rotation, sway, clampf(14.0 * delta, 0.0, 1.0))
