extends CanvasLayer
class_name MobileControls
## Touch controls for Android / iOS.
## Builds 5 big buttons (left, right, gas, brake, handbrake) plus small Reset and Pause buttons.
## They press the SAME Input Actions as the keyboard, so the car code is unchanged.
##
## The buttons are hidden on PC. To test them on PC:
##  1. tick "Show On Desktop" in the Inspector, and
##  2. Project Settings > Input Devices > Pointing > Emulate Touch From Mouse = On.

## Tick to see the buttons on PC (for testing only).
@export var show_on_desktop: bool = false
## Make all buttons bigger or smaller (1.0 = normal).
@export var button_scale: float = 1.0

const BASE_SIZE: float = 150.0

var _buttons: Array[TouchButton] = []
var _btn_left: TouchButton
var _btn_right: TouchButton
var _btn_accel: TouchButton
var _btn_brake: TouchButton
var _btn_handbrake: TouchButton
var _btn_reset: TouchButton
var _btn_pause: TouchButton


func _ready() -> void:
	_btn_left = _make_button(&"steer_left", "<")
	_btn_right = _make_button(&"steer_right", ">")
	_btn_accel = _make_button(&"accelerate", "GAS")
	_btn_brake = _make_button(&"brake", "BRAKE")
	_btn_handbrake = _make_button(&"handbrake", "HAND")
	_btn_reset = _make_button(&"reset_car", "R")
	_btn_pause = _make_button(&"pause_game", "II")

	_layout()
	get_viewport().size_changed.connect(_layout)
	set_active(true)


## Called by the HUD: false while a menu is open, true during the race.
## On PC the buttons stay hidden either way.
func set_active(on: bool) -> void:
	var show_now: bool = on and _should_show()
	visible = show_now
	for b in _buttons:
		b.set_active(show_now)


func _should_show() -> bool:
	return show_on_desktop or OS.has_feature("mobile")


func _make_button(action: StringName, text: String) -> TouchButton:
	var b: TouchButton = TouchButton.new()
	b.action = action
	b.label_text = text
	add_child(b)
	_buttons.append(b)
	return b


## Put every button where it belongs for the current screen size.
func _layout() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var s: float = BASE_SIZE * button_scale
	var gap: float = 20.0 * button_scale
	var margin: float = 40.0 * button_scale
	var bottom: float = view.y - margin

	# Left thumb: steering.
	_place(_btn_left, Vector2(margin, bottom - s), Vector2(s, s))
	_place(_btn_right, Vector2(margin + s + gap, bottom - s), Vector2(s, s))

	# Right thumb: gas (tall), brake, handbrake above brake.
	_place(_btn_accel, Vector2(view.x - margin - s, bottom - s * 1.4), Vector2(s, s * 1.4))
	var brake_x: float = view.x - margin - s * 2.0 - gap
	_place(_btn_brake, Vector2(brake_x, bottom - s), Vector2(s, s))
	_place(_btn_handbrake, Vector2(brake_x, bottom - s - gap - s * 0.7), Vector2(s, s * 0.7))

	# Small buttons in the top right corner.
	var small: float = 80.0 * button_scale
	_place(_btn_pause, Vector2(view.x - margin - small, margin), Vector2(small, small))
	_place(_btn_reset, Vector2(view.x - margin - small * 2.0 - gap, margin), Vector2(small, small))


func _place(b: TouchButton, pos: Vector2, new_size: Vector2) -> void:
	b.position = pos
	b.size = new_size
	b.queue_redraw()
