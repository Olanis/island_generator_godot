extends MeshInstance3D

@onready var material = material_override

func _process(delta):
	if material:
		material.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)  # Aktuelle Zeit in Sekunden
