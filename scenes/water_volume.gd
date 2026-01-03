extends Area3D

var wave_amplitude = 2.0
var wave_frequency = 1.0

func _physics_process(delta):
	for body in get_overlapping_bodies():
		if body is RigidBody3D:
			var wave_force = Vector3(0, sin(Time.get_ticks_msec() * 0.001 * wave_frequency) * wave_amplitude, 0)
			body.apply_central_force(wave_force)
