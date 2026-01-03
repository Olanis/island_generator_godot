shader_type spatial;
uniform float wave_height = 0.5;
uniform float wave_speed = 1.0;
uniform float time = 0.0;  // Neu: Zeit als Uniform

void vertex() {
	vec3 pos = VERTEX;
	float wave = sin(pos.x * 0.01 + time * wave_speed) * wave_height;
	pos.y += wave;
	VERTEX = pos;
}

void fragment() {
	ALBEDO = vec3(0.0, 0.4, 0.8);
	ALPHA = 0.6;
}
