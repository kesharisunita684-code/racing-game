extends Node3D
class_name ChaseCamera
## Third-person chase camera.
##
## Node layout (see main.tscn):
##   ChaseCamera (this script)
##     SpringArm3D   <- pushes the camera closer if a wall is in the way
##       Camera3D
##
## This node is NOT a child of the car. It follows the car smoothly instead,
## which feels nicer than being glued to it.

## The car to follow (assigned in main.tscn).
@export var target: Node3D
## Bigger number = camera catches up faster.
@export var follow_speed: float = 5.0
## How high above the car's origin the camera looks at.
@export var height_offset: float = 1.5

@onready var _spring_arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	# Ignore any parent movement. This node moves on its own.
	top_level = true

	if target == null:
		push_warning("ChaseCamera: 'target' is empty. Assign the car in the Inspector.")
		return

	# The arm must not hit the car itself.
	if target is CollisionObject3D:
		_spring_arm.add_excluded_object((target as CollisionObject3D).get_rid())

	# Start exactly behind the car (no sliding in at the beginning).
	global_position = target.global_position + Vector3.UP * height_offset
	rotation.y = _get_target_yaw()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# lerp = "move a part of the way each frame". Clamp keeps it stable on slow frames.
	var weight: float = clampf(follow_speed * delta, 0.0, 1.0)

	var goal: Vector3 = target.global_position + Vector3.UP * height_offset
	global_position = global_position.lerp(goal, weight)
	rotation.y = lerp_angle(rotation.y, _get_target_yaw(), weight)


## Y rotation of the car, taken from where its nose points.
## (Safer than reading rotation.y directly when the car is tilted or flipped.)
func _get_target_yaw() -> float:
	var fwd: Vector3 = -target.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		return rotation.y
	return atan2(-fwd.x, -fwd.z)
