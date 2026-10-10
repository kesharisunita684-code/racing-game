extends CanvasLayer
class_name RaceHud
## The on-screen display: speed, timer, laps, position, countdown,
## pause menu and results screen.
##
## This script only SHOWS things. RaceManager tells it what to show.
## It also handles the pause menu itself.

## Sent when the player presses a Restart button.
signal restart_requested

var _pause_allowed: bool = true
var _is_paused: bool = false
var _last_speed_shown: int = -1

@onready var _speed_label: Label = %SpeedLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _lap_label: Label = %LapLabel
@onready var _position_label: Label = %PositionLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _pause_menu: Control = %PauseMenu
@onready var _results_menu: Control = %ResultsMenu
@onready var _result_time_label: Label = %ResultTimeLabel
@onready var _lap_times_label: Label = %LapTimesLabel
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _results_restart_button: Button = %ResultsRestartButton
@onready var _mobile_controls: MobileControls = %MobileControls


func _ready() -> void:
	# The HUD must keep working while the game is paused (so Resume works).
	process_mode = Node.PROCESS_MODE_ALWAYS

	_pause_menu.visible = false
	_results_menu.visible = false
	_countdown_label.text = ""

	_resume_button.pressed.connect(resume_game)
	_restart_button.pressed.connect(_on_restart_pressed)
	_results_restart_button.pressed.connect(_on_restart_pressed)


func _process(_delta: float) -> void:
	# Esc (or the mobile pause button) opens / closes the pause menu.
	if Input.is_action_just_pressed("pause_game"):
		if _is_paused:
			resume_game()
		else:
			pause_game()


# ---------------------------------------------------------------------------
# Functions called by RaceManager
# ---------------------------------------------------------------------------

func set_speed_kmh(kmh: float) -> void:
	var shown: int = int(round(kmh))
	if shown == _last_speed_shown:
		return   # nothing changed, save work
	_last_speed_shown = shown
	_speed_label.text = "%d KM/H" % shown


func set_time(seconds: float) -> void:
	_timer_label.text = format_time(seconds)


func set_lap(current_lap: int, total_laps: int) -> void:
	_lap_label.text = "LAP %d/%d" % [current_lap, total_laps]


func set_position_text(place: int, total_cars: int) -> void:
	_position_label.text = "POS %d/%d" % [place, total_cars]


func show_countdown(text: String) -> void:
	_countdown_label.text = text
	_countdown_label.visible = true


func hide_countdown() -> void:
	_countdown_label.visible = false


func set_pause_allowed(allowed: bool) -> void:
	_pause_allowed = allowed


func show_results(final_time: float, lap_times: Array) -> void:
	_result_time_label.text = "TOTAL TIME  " + format_time(final_time)
	var lines: PackedStringArray = PackedStringArray()
	for i in lap_times.size():
		lines.append("Lap %d   %s" % [i + 1, format_time(lap_times[i])])
	_lap_times_label.text = "\n".join(lines)
	_results_menu.visible = true
	_mobile_controls.set_active(false)


# ---------------------------------------------------------------------------
# Pause menu
# ---------------------------------------------------------------------------

func pause_game() -> void:
	if not _pause_allowed or _is_paused:
		return
	_is_paused = true
	get_tree().paused = true
	_pause_menu.visible = true
	_mobile_controls.set_active(false)


func resume_game() -> void:
	if not _is_paused:
		return
	_is_paused = false
	get_tree().paused = false
	_pause_menu.visible = false
	_mobile_controls.set_active(true)


func _on_restart_pressed() -> void:
	restart_requested.emit()


## Turns seconds into text like 01:23.456
static func format_time(seconds: float) -> String:
	var minutes: int = int(seconds / 60.0)
	var secs: float = fmod(seconds, 60.0)
	return "%02d:%06.3f" % [minutes, secs]
