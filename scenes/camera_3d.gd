extends Camera3D

var zoom_speed = 5.0
var rotate_speed = 0.01  # Dreh-Geschwindigkeit
var right_mouse_down = false
var last_mouse_pos = Vector2()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			right_mouse_down = event.pressed
			if event.pressed:
				last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			translate(Vector3(0, 0, -zoom_speed))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			translate(Vector3(0, 0, zoom_speed))
	
	if event is InputEventMouseMotion and right_mouse_down:
		var delta = event.position - last_mouse_pos
		rotate_y(-delta.x * rotate_speed)  # Horizontal drehen
		rotate_x(-delta.y * rotate_speed)  # Vertikal drehen (aber begrenze, um nicht umzukippen)
		last_mouse_pos = event.position
