extends Area3D
class_name Checkpoint
## An invisible gate. When the car drives through it, it sends a signal.
## RaceManager listens to all checkpoints and decides what it means.
##
## index = 0 and is_finish_line = true  -> the start/finish line
## index = 1, 2, 3 ...                  -> normal checkpoints, in driving order
##
## IMPORTANT: the gate's FRONT is its local -Z direction. Rotate the gate so that
## -Z points the way the cars should drive (see test_track.tscn).

signal car_passed(checkpoint: Checkpoint)

@export var index: int = 0
@export var is_finish_line: bool = false
## If true, driving through backwards does NOT count (stops cheating).
@export var require_forward_direction: bool = true


func _ready() -> void:
	add_to_group("checkpoints")
	collision_layer = 0   # the gate itself is not a solid object
	collision_mask = 2    # it only looks for Layer 2 = Car
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("car"):
		return

	if require_forward_direction:
		var rb: RigidBody3D = body as RigidBody3D
		if rb != null:
			var gate_forward: Vector3 = -global_transform.basis.z
			if rb.linear_velocity.dot(gate_forward) <= 0.0:
				return

	car_passed.emit(self)
