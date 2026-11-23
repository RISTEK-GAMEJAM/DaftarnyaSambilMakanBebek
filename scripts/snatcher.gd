extends CharacterBody2D

@export var move_speed: float = 135.0
@export var max_tilt_degrees: float = 12.0
@export var tilt_smoothness: float = 10.0
@export var default_facing_right: bool = true

@onready var visuals: Node2D = $Visuals
@onready var tail_physics: Node2D = $TailPhysics
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var facing_right: bool = true


func _ready() -> void:
	facing_right = default_facing_right
	_apply_facing()
	anim_player.play("idle")
	if tail_physics and tail_physics.has_method("set_motion_state"):
		tail_physics.set_motion_state(facing_right, Vector2.ZERO)


func _apply_facing() -> void:
	# Original art faces left (tail on right), so scale.x = -1 faces right.
	visuals.scale.x = -1.0 if facing_right else 1.0


func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	# Support WASD even if not mapped in InputMap
	if input_dir == Vector2.ZERO:
		var x := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		var y := float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		input_dir = Vector2(x, y)

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * move_speed
	move_and_slide()

	# Update facing direction when moving horizontally (never flies backward)
	if input_dir.x > 0.05:
		facing_right = true
		_apply_facing()
	elif input_dir.x < -0.05:
		facing_right = false
		_apply_facing()

	# Switch between idle and move animations
	if input_dir.length() > 0.05:
		if anim_player.current_animation != "move":
			anim_player.play("move", 0.12)
	else:
		if anim_player.current_animation != "idle":
			anim_player.play("idle", 0.18)

	# Smoothly tilt whole body + stationary legs toward horizontal flight direction
	var t := clampf(tilt_smoothness * delta, 0.0, 1.0)
	var target_tilt := deg_to_rad(input_dir.x * max_tilt_degrees)
	visuals.rotation = lerp_angle(visuals.rotation, target_tilt, t)

	# Feed facing direction & velocity into real-time tail physics
	if tail_physics and tail_physics.has_method("set_motion_state"):
		tail_physics.set_motion_state(facing_right, velocity)
