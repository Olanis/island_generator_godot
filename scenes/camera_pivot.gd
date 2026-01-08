extends Node3D

var zoom_speed = 5.0
var rotate_speed = 0.01
var right_mouse_down = false
var left_mouse_down = false
var pitch = 0.0  # Vertikale Rotation

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_down = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			left_mouse_down = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera3D.translate(Vector3(0, 0, -zoom_speed))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera3D.translate(Vector3(0, 0, zoom_speed))
	
	if event is InputEventMouseMotion:
		if right_mouse_down:
			rotate_y(-event.relative.x * rotate_speed)  # Links/rechts
		if left_mouse_down:
			pitch = clamp(pitch - event.relative.y * rotate_speed, -PI / 2, PI / 2)  # Oben/unten, clamped
			rotation.x = pitch  # Setze direkt, um Kippen zu vermeiden
