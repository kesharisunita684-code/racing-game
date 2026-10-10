extends Node
class_name RaceManager
## The "referee" of the race. It:
##   1. runs the 3-2-1-GO countdown (car is locked until GO),
##   2. runs the race timer,
##   3. counts laps using the checkpoints,
##   4. shows the results screen after the last lap.
##
## It does not drive the car and does not draw anything itself:
## it only gives orders to the car (CarController) and the HUD (RaceHud).
##
## FUTURE: AI cars can register themselves here later, and the "position" can be
## calculated by comparing laps + checkpoints of every car.

signal race_started
signal lap_completed(lap_number: int, lap_time: float)
signal race_finished(total_time: float)

enum State { COUNTDOWN, RACING, FINISHED }

## The player's car (assigned in main.tscn).
@export var car: CarController
## The HUD (assigned in main.tscn).
@export var hud: RaceHud
@export var total_laps: int = 3
@export var countdown_seconds: float = 3.0
## How long the "GO!" text stays on screen.
@export var go_display_seconds: float = 1.0

var state: State = State.COUNTDOWN
var race_time: float = 0.0
var current_lap: int = 1

var _countdown_left: float = 0.0
var _go_left: float = 0.0
var _lap_start_time: float = 0.0
var _lap_times: Array[float] = []
var _checkpoints: Array[Checkpoint] = []   # normal checkpoints, sorted by index
var _next_checkpoint: int = 0              # position in _checkpoints we must pass next

# Backup keys: used only if an action is missing from project.godot.
const DEFAULT_KEYS: Dictionary = {
	"accelerate": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"handbrake": [KEY_SPACE],
	"reset_car": [KEY_R],
	"pause_game": [KEY_ESCAPE],
}


func _ready() -> void:
	_ensure_input_actions()

	if car == null or hud == null:
		push_error("RaceManager: please assign 'car' and 'hud' in the Inspector.")
		set_physics_process(false)
		return

	_collect_checkpoints()
	hud.restart_requested.connect(restart_race)
	_start_countdown()


func _physics_process(delta: float) -> void:
	hud.set_speed_kmh(car.get_speed_kmh())

	match state:
		State.COUNTDOWN:
			_countdown_left -= delta
			if _countdown_left <= 0.0:
				_begin_race()
			else:
				hud.show_countdown(str(ceili(_countdown_left)))
		State.RACING:
			race_time += delta
			hud.set_time(race_time)
			if _go_left > 0.0:
				_go_left -= delta
				if _go_left <= 0.0:
					hud.hide_countdown()
		State.FINISHED:
			pass


## Reload the whole scene (works from the pause menu and the results screen).
func restart_race() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# ---------------------------------------------------------------------------
# Race flow
# ---------------------------------------------------------------------------

func _start_countdown() -> void:
	state = State.COUNTDOWN
	race_time = 0.0
	current_lap = 1
	_next_checkpoint = 0
	_lap_times.clear()
	_countdown_left = countdown_seconds

	car.set_controls_enabled(false)   # car is locked during the countdown
	hud.set_time(0.0)
	hud.set_lap(current_lap, total_laps)
	hud.set_position_text(1, 1)       # always 1/1 until we have AI opponents
	hud.show_countdown(str(ceili(_countdown_left)))


func _begin_race() -> void:
	state = State.RACING
	race_time = 0.0
	_lap_start_time = 0.0
	_go_left = go_display_seconds
	car.set_controls_enabled(true)
	hud.show_countdown("GO!")
	race_started.emit()


func _finish_race() -> void:
	state = State.FINISHED
	car.set_controls_enabled(false)   # the car brakes to a stop by itself
	hud.set_pause_allowed(false)
	hud.hide_countdown()
	hud.set_time(race_time)
	hud.show_results(race_time, _lap_times)
	race_finished.emit(race_time)


# ---------------------------------------------------------------------------
# Checkpoints and laps
# ---------------------------------------------------------------------------

func _collect_checkpoints() -> void:
	for node in get_tree().get_nodes_in_group("checkpoints"):
		var cp: Checkpoint = node as Checkpoint
		if cp == null:
			continue
		cp.car_passed.connect(_on_checkpoint_passed)
		if not cp.is_finish_line:
			_checkpoints.append(cp)
	_checkpoints.sort_custom(func(a: Checkpoint, b: Checkpoint) -> bool: return a.index < b.index)


func _on_checkpoint_passed(cp: Checkpoint) -> void:
	if state != State.RACING:
		return

	if cp.is_finish_line:
		# A lap only counts if ALL checkpoints were passed, in order.
		if _next_checkpoint >= _checkpoints.size():
			_complete_lap()
		return

	# Normal checkpoint: it only counts if it is the one we expect next.
	if _next_checkpoint < _checkpoints.size() and cp == _checkpoints[_next_checkpoint]:
		_next_checkpoint += 1


func _complete_lap() -> void:
	var lap_time: float = race_time - _lap_start_time
	_lap_times.append(lap_time)
	_lap_start_time = race_time
	_next_checkpoint = 0
	lap_completed.emit(current_lap, lap_time)

	if current_lap >= total_laps:
		_finish_race()
	else:
		current_lap += 1
		hud.set_lap(current_lap, total_laps)


# ---------------------------------------------------------------------------
# Safety net for the Input Map
# ---------------------------------------------------------------------------

func _ensure_input_actions() -> void:
	for action in DEFAULT_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in DEFAULT_KEYS[action]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
