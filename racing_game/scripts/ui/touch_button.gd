extends Control
class_name TouchButton
## A big on-screen button for phones.
##
## When a finger touches it, it "presses" an Input Action (for example "accelerate").
## The car does not know the difference between this and a keyboard key.
##
## Why not a normal Button? A normal Button only handles ONE finger at a time.
## This one tracks its own finger, so you can steer and press gas together.

## Name of the Input Action to press (must exist in the Input Map).
@export var action: StringName = &""
## Text drawn on the button.
@export var label_text: String = ""
@export var font_size: int = 28

## MobileControls turns this off when menus are open.
var active: bool = true

var _finger: int = -1   # which finger is holding us (-1 = nobody)
var _style_normal: StyleBoxFlat = StyleBoxFlat.new()
var _style_pressed: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	# Do not block normal mouse clicks (menus need them).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	_style_normal.bg_color = Color(1, 1, 1, 0.18)
	_style_normal.border_color = Color(1, 1, 1, 0.55)
	_style_normal.set_border_width_all(3)
	_style_normal.set_corner_radius_all(28)

	_style_pressed.bg_color = Color(1, 1, 1, 0.45)
	_style_pressed.border_color = Color(1, 1, 1, 0.9)
	_style_pressed.set_border_width_all(3)
	_style_pressed.set_corner_radius_all(28)


func _draw() -> void:
	var style: StyleBoxFlat = _style_pressed if _finger != -1 else _style_normal
	draw_style_box(style, Rect2(Vector2.ZERO, size))

	var font: Font = ThemeDB.fallback_font
	var text_pos: Vector2 = Vector2(0.0, size.y * 0.5 + font_size * 0.35)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color(1, 1, 1, 0.95))


func _input(event: InputEvent) -> void:
	if not active or action == &"":
		return

	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if _finger == -1 and _contains(touch.position):
				_press(touch.index)
		elif touch.index == _finger:
			_release()
		return

	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null:
		if drag.index == _finger:
			# Finger slid off the button.
			if not _contains(drag.position):
				_release()
		elif _finger == -1 and _contains(drag.position):
			# Finger slid onto the button (for example from LEFT to RIGHT).
			_press(drag.index)


## Turn the button on or off. Turning off lets go of the action.
func set_active(on: bool) -> void:
	active = on
	if not on and _finger != -1:
		_release()


func _exit_tree() -> void:
	# Never leave an action stuck when this button disappears (scene restart).
	if _finger != -1:
		_release()


func _contains(screen_pos: Vector2) -> bool:
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_pos
	return Rect2(Vector2.ZERO, size).has_point(local_pos)


func _press(finger_index: int) -> void:
	_finger = finger_index
	Input.action_press(action)
	queue_redraw()


func _release() -> void:
	_finger = -1
	Input.action_release(action)
	queue_redraw()
