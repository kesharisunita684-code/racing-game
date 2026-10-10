extends VehicleBody3D
class_name CarController
## Sports car controller (Phase 1).
##
## HOW IT WORKS (simple version):
##  - VehicleBody3D is a special Godot node that already knows how to behave like a car.
##  - Every physics frame we only tell it three things:
##      engine_force -> how hard the rear wheels push the car
##      brake        -> how hard the wheels slow the car down
##      steering     -> how far the front wheels are turned (in radians)
##
## PHASE 2 NOTE:
##  Later we will replace VehicleBody3D with our own "RaycastVehicle"
##  (a RigidBody3D + 4 RayCast3D nodes). That gives us full control over tyre grip,
##  which we need for proper drifting. The public functions of this script
##  (set_controls_enabled, reset_car, get_speed_kmh) are kept simple on purpose,
##  so the HUD and RaceManager will not need to change when we swap the physics.
##
## FUTURE IDEAS (not built yet): AI driver (feed it fake inputs), engine/tyre sounds,
## upgrades (change the numbers below), different cars (just change the numbers).

## Emitted after the car was put back on the track.
signal car_reset

@export_group("Engine and Brakes")
## Push force of each rear wheel.
@export var max_engine_force: float = 1200.0
## Brake strength of each wheel.
@export var max_brake: float = 120.0
## The handbrake uses this many times the normal brake, on the REAR wheels only.
@export var handbrake_multiplier: float = 3.0
## Reverse is weaker than going forward (0.6 = 60 percent).
@export var reverse_force_ratio: float = 0.6
## Below this forward speed (m/s) the brake button becomes "reverse".
@export var reverse_speed_threshold: float = 2.0
## Engine is cut above this speed.
@export var max_speed_kmh: float = 220.0

@export_group("Steering")
## Maximum wheel turn in radians (0.35 is about 20 degrees).
@export var max_steer: float = 0.35
## How fast the wheels turn toward the wanted angle (radians per second).
@export var steer_speed: float = 3.0
## At high speed the steering is reduced so the car is not twitchy (0 = off, 1 = very strong).
@export var high_speed_steer_reduction: float = 0.6
## Speed (m/s) at which the steering reduction is at its maximum.
@export var steer_reduction_speed: float = 40.0

@export_group("Safety and Reset")
## If the car's "up" direction points up less than this, we count it as flipped.
@export var flip_up_dot_limit: float = 0.2
## Seconds the car must stay flipped before it is reset automatically.
@export var flip_time_limit: float = 2.0
## Below this height the car has fallen off the world.
@export var fall_y_limit: float = -10.0
## How many meters the car is lifted when reset.
@export var reset_lift: float = 2.0

## RaceManager turns this on at "GO" and off at the finish.
var controls_enabled: bool = false

var _flip_timer: float = 0.0
var _last_safe_position: Vector3 = Vector3.ZERO
var _last_safe_yaw: float = 0.0

@onready var _wheel_rear_left: VehicleWheel3D = $WheelRL
@onready var _wheel_rear_right: VehicleWheel3D = $WheelRR


func _ready() -> void:
	# Other scripts (checkpoints) find the car through this group.
	add_to_group("car")
	# A sleeping body would ignore us during the countdown. Keep it awake.
	can_sleep = false
	_last_safe_position = global_position
	_last_safe_yaw = _get_yaw()


# ---------------------------------------------------------------------------
# Public functions (used by RaceManager and the HUD)
# ---------------------------------------------------------------------------

func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


## Speed along the nose of the car in m/s (negative = rolling backwards).
## Godot cars drive toward their local -Z axis, so "forward" is -basis.z.
func get_forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)


## Put the car back upright, stop it, and lift it 2 meters.
func reset_car() -> void:
	var pos: Vector3 = global_position
	var yaw: float = _get_yaw()
	if pos.y < -1.0:
		# We fell off the world: go back to the last good place.
		pos = _last_safe_position
		yaw = _last_safe_yaw
	pos.y = maxf(pos.y, 0.0) + reset_lift

	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	engine_force = 0.0
	steering = 0.0
	_flip_timer = 0.0
	car_reset.emit()


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_drive(delta)
	_check_safety(delta)


func _drive(delta: float) -> void:
	var accel_in: float = 0.0
	var brake_in: float = 0.0
	var steer_in: float = 0.0
	var handbrake_on: bool = false

	if controls_enabled:
		accel_in = Input.get_action_strength("accelerate")
		brake_in = Input.get_action_strength("brake")
		# Positive steering = turn LEFT in Godot.
		steer_in = Input.get_axis("steer_right", "steer_left")
		handbrake_on = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("reset_car"):
			reset_car()

	var forward_speed: float = get_forward_speed()
	var engine: float = 0.0
	var brake_force: float = 0.0

	if not controls_enabled:
		# Countdown / finished: hold the car still with the brakes.
		brake_force = max_brake
	else:
		if accel_in > 0.0:
			engine = accel_in * max_engine_force
		if brake_in > 0.0:
			if forward_speed > reverse_speed_threshold:
				# Moving forward fast: brake pedal = real brakes.
				brake_force = brake_in * max_brake
				engine = 0.0
			elif accel_in <= 0.0:
				# Almost stopped: brake pedal = reverse gear.
				engine = -brake_in * max_engine_force * reverse_force_ratio

	# Simple speed limiter.
	if get_speed_kmh() > max_speed_kmh and engine > 0.0:
		engine = 0.0

	engine_force = engine   # goes to wheels with "Use As Traction" (rear)
	brake = brake_force     # normal brake on all wheels

	# Handbrake: locks the rear wheels with 3x brake force.
	var rear_brake: float = brake_force
	if handbrake_on:
		rear_brake = max_brake * handbrake_multiplier
	_wheel_rear_left.brake = rear_brake
	_wheel_rear_right.brake = rear_brake

	# Steering: smoothly move toward the wanted angle. Less steering at high speed.
	var speed_ratio: float = clampf(linear_velocity.length() / steer_reduction_speed, 0.0, 1.0)
	var steer_limit: float = max_steer * (1.0 - high_speed_steer_reduction * speed_ratio)
	var target_steer: float = steer_in * steer_limit
	steering = move_toward(steering, target_steer, steer_speed * delta)


func _check_safety(delta: float) -> void:
	var up_dot: float = global_transform.basis.y.dot(Vector3.UP)

	# Flipped for too long -> reset.
	if up_dot < flip_up_dot_limit:
		_flip_timer += delta
	else:
		_flip_timer = 0.0

	if _flip_timer >= flip_time_limit:
		reset_car()
	elif global_position.y < fall_y_limit:
		reset_car()
	elif up_dot > 0.7 and global_position.y > 0.2:
		# Car is upright on the ground: remember this place.
		_last_safe_position = global_position
		_last_safe_yaw = _get_yaw()


## Direction the car is facing, as an angle around the Y axis.
func _get_yaw() -> float:
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.2:
		return _last_safe_yaw
	return atan2(-fwd.x, -fwd.z)
