extends CanvasLayer

@onready var generate_btn = $GenerateButton
@onready var spielen_btn = $SpielenButton  # Neuer Button
var island_body = null
var current_size_x = 0  # Speichere Insel-Größe
var player = null  # Speichere den Player
var camera = null  # Speichere die Kamera
var gravity = 15.0  # Niedrigere Gravity
var jump_force = 10  # Jump force
var jumps_left = 1  # Nur ein Sprung in der Luft
var camera_angle = 0.0  # Für horizontale Kamera-Rotation
var camera_pitch = 0.0  # Für vertikale Kamera-Rotation
var zoom_distance = 15.0  # Zoom-Distanz für Kamera
var smoothing_factor = 10.0  # Für sanfte Geschwindigkeitsänderungen

func _ready():
	generate_btn.connect("pressed", Callable(self, "generate_island"))
	spielen_btn.connect("pressed", Callable(self, "spielen"))  # Verbinde Spielen-Button
	# Button nicht fokussierbar machen
	generate_btn.focus_mode = Control.FOCUS_NONE
	spielen_btn.focus_mode = Control.FOCUS_NONE

func _input(event):
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if player and jumps_left > 0:
			player.velocity.y = jump_force
			jumps_left -= 1
		get_viewport().set_input_as_handled()  # Verhindere UI-Trigger
	
	# Kameradrehen mit Rechtsklick oder Linksklick (WoW-Style: immer relativ zur Kamera)
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		if camera:
			camera_angle -= event.relative.x * 0.01  # Horizontal
			camera_pitch -= event.relative.y * 0.01  # Vertikal
			camera_pitch = clamp(camera_pitch, -PI/4, PI/4)  # Limitiere Pitch
			get_viewport().set_input_as_handled()
	
	# Zoom mit Mausrad
	if event is InputEventMouseButton and camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = max(zoom_distance - 2.0, 5.0)  # Min 5
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = min(zoom_distance + 2.0, 50.0)  # Max 50

func _process(delta):
	if player and camera:
		# Gravity anwenden
		if not player.is_on_floor():
			player.velocity.y -= gravity * delta
		
		# Reset jumps wenn auf Boden
		if player.is_on_floor():
			jumps_left = 1
		
		# Kamera folgt schräg von oben, rotiert um Player - mit Zoom (WoW-Style)
		var camera_offset = Vector3(0, zoom_distance, zoom_distance).rotated(Vector3.RIGHT, camera_pitch).rotated(Vector3.UP, camera_angle)
		var target_pos = player.position + camera_offset
		
		# Verhindere, dass Kamera durch Boden fährt - raycast prüfen
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = player.position
		var ray_dir = (target_pos - player.position).normalized()
		var ray_length = (target_pos - player.position).length()
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * ray_length)
		var result = space_state.intersect_ray(query)
		if result:
			# Wenn Hit, bringe Kamera näher
			target_pos = result.position - ray_dir * 2  # Etwas Abstand
		
		camera.position = camera.position.lerp(target_pos, 0.1)  # Smooth follow
		camera.look_at(player.position, Vector3.UP)
		
		# Bewegung (auf Boden oder im Sprung mit langsamer Geschwindigkeit, immer relativ zur Kamera)
		var speed = 10
		if Input.is_key_pressed(KEY_SHIFT):
			speed = 20
		
		if not player.is_on_floor():
			speed *= 0.5  # Langsamere Geschwindigkeit im Sprung
		
		# Zielgeschwindigkeit berechnen
		var target_velocity_x = 0.0
		var target_velocity_z = 0.0
		
		var input_dir = Vector3()
		if Input.is_key_pressed(KEY_W):
			input_dir.z -= 1
		if Input.is_key_pressed(KEY_S):
			input_dir.z += 1
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			var camera_basis = camera.transform.basis
			var move_dir = (camera_basis.z * input_dir.z + camera_basis.x * input_dir.x)
			# Entferne Y-Komponente und normalisiere
			move_dir.y = 0
			move_dir = move_dir.normalized()
			target_velocity_x = move_dir.x * speed
			target_velocity_z = move_dir.z * speed
		
		# Sanfte Interpolation zur Zielgeschwindigkeit
		player.velocity.x = lerp(player.velocity.x, target_velocity_x, delta * smoothing_factor)
		player.velocity.z = lerp(player.velocity.z, target_velocity_z, delta * smoothing_factor)
		
		player.move_and_slide()

func generate_island():
	if island_body:
		island_body.queue_free()
	if player:
		player.queue_free()
		player = null
	if camera:
		camera.queue_free()
		camera = null
	
	var size_x = randf_range(100, 500)
	var size_z = size_x
	var max_height = size_x * 0.2  # Abhängig von Inselgröße
	var size_y = randf_range(max_height * 0.5, max_height)  # Variation
	current_size_x = size_x  # Speichere für Spielen
	
	island_body = StaticBody3D.new()
	island_body.position = Vector3(0, 0, 0)  # Insel bei y=0
	
	# Einzelnes Terrain-Mesh mit subdividiertem PlaneMesh für organische Form ohne Sternmuster
	var terrain_mesh = generate_terrain_mesh(size_x / 2, size_y)  # Radius, Höhe
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.mesh = terrain_mesh
	terrain_instance.material_override = StandardMaterial3D.new()
	terrain_instance.material_override.albedo_color = Color(1, 1, 1)  # Weiß, um Vertex-Farben zu verwenden
	terrain_instance.material_override.vertex_color_use_as_albedo = true
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED  # Schatten werfen
	island_body.add_child(terrain_instance)
	
	# Collider für das Terrain
	var collider = CollisionShape3D.new()
	collider.shape = terrain_mesh.create_trimesh_shape()
	island_body.add_child(collider)
	
	get_parent().add_child(island_body)  # Hinzufügen, bevor Bäume
	
	# Schatten für Licht aktivieren und konfigurieren
	var lights = get_parent().find_children("*", "DirectionalLight3D", true, false)
	for light in lights:
		if light is DirectionalLight3D:
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 2000  # Schatten von weiter weg sichtbar
			light.shadow_bias = 0.01  # Anpassen
			light.shadow_normal_bias = 1.0  # Anpassen
			light.directional_shadow_blend_splits = true  # Bessere Blends
			light.directional_shadow_mode = 2  # PARALLEL_4_SPLITS für bessere Qualität
			print("Schatten für DirectionalLight aktiviert und konfiguriert")
			break
	
	# Wasseroberfläche holen
	var water_level = 0.0
	var water_node = get_parent().find_child("Water", true, false)  # Suche nach Node namens "Water"
	if water_node:
		water_level = water_node.position.y
	else:
		print("Kein Water-Node gefunden, verwende y=0")
	
	# Bäume zufällig platzieren, nur auf Insel, über Wasser, auf Oberfläche via Raycast, min Abstand, senkrecht nach oben, Basis 30% in Erde, nicht auf steilen Hängen
	var num_trees = randi_range(20, 100)
	var space_state = get_viewport().world_3d.direct_space_state
	var tree_positions = []  # Globale Positionen
	var min_distance = 15.0  # Min Abstand zwischen Bäumen
	for i in range(num_trees):
		var pos = Vector3()
		var attempts = 0
		while attempts < 50:  # Mehr Versuche
			var r = randf() * (size_x / 2 * 0.9)  # Innerhalb Insel
			var theta = randf() * 2 * PI
			pos.x = r * cos(theta)
			pos.z = r * sin(theta)
			var global_pos = island_body.position + pos
			# Raycast von oben
			var ray_origin = global_pos + Vector3(0, 1000, 0)
			var ray_end = global_pos + Vector3(0, -1000, 0)
			var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
			var result = space_state.intersect_ray(query)
			if result and result.collider == island_body:
				var global_y = result.position.y
				if global_y > water_level and result.normal.dot(Vector3.UP) > 0.8:  # Über Wasser und nicht steil
					var new_global_pos = result.position
					# Prüfe Abstand zu bestehenden Bäumen
					var too_close = false
					for existing_pos in tree_positions:
						if new_global_pos.distance_to(existing_pos) < min_distance:
							too_close = true
							break
					if not too_close:
						tree_positions.append(new_global_pos)
						pos.y = result.position.y - island_body.position.y
						break
			attempts += 1
		if attempts < 50:
			# Baum als StaticBody3D mit Kollision
			var tree_body = StaticBody3D.new()
			tree_body.position = pos
			
			var tree = MeshInstance3D.new()
			var tree_mesh = CylinderMesh.new()
			var bush_radius = randf_range(1, 6)  # Bush radius first
			var tree_scale = bush_radius / 6.0  # Scale factor
			tree_mesh.top_radius = randf_range(0.5, 1.5) * tree_scale + 0.1  # Min 0.1
			tree_mesh.bottom_radius = randf_range(1, 3) * tree_scale + 0.2  # Min 0.2
			tree_mesh.height = randf_range(15, 30) * tree_scale + 5  # Min 5
			tree.mesh = tree_mesh
			tree.material_override = StandardMaterial3D.new()
			tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
			tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED  # Schatten werfen
			tree_body.add_child(tree)
			
			# Kollision für Baum - genau mit Mesh
			var tree_collider = CollisionShape3D.new()
			tree_collider.shape = CylinderShape3D.new()
			tree_collider.shape.radius = tree_mesh.bottom_radius * 0.9  # Etwas kleiner für genauere Passung
			tree_collider.shape.height = tree_mesh.height * 0.9  # Etwas kleiner
			tree_body.add_child(tree_collider)
			
			pos.y += tree_mesh.height / 2 - tree_mesh.height * 0.3  # Basis 30% in Erde
			tree_body.position = pos
			
			# Busch oben auf dem Baum
			var bush = MeshInstance3D.new()
			var bush_mesh = SphereMesh.new()
			bush_mesh.radius = bush_radius
			bush_mesh.height = bush_mesh.radius * 2
			bush.mesh = bush_mesh
			bush.material_override = StandardMaterial3D.new()
			# Dunkle, blätterartige Grün-Töne
			bush.material_override.albedo_color = Color(randf_range(0.0, 0.2), randf_range(0.2, 0.5), randf_range(0.0, 0.2))
			bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED  # Schatten werfen
			bush.position = Vector3(0, tree_mesh.height / 2, 0)  # Oben auf dem Baum
			tree_body.add_child(bush)
			
			island_body.add_child(tree_body)
	
	print("Natürliche Insel generiert: Größe ", size_x, "x", size_y, "x", size_z, " mit ", tree_positions.size(), " Bäumen, Wasser bei ", water_level)

func spielen():
	if not island_body:
		print("Keine Insel generiert!")
		return
	if player:
		player.queue_free()
	if camera:
		camera.queue_free()
	
	var attempts = 0
	var max_attempts = 300  # Mehr Versuche
	while attempts < max_attempts:
		var r = current_size_x / 2 * randf_range(0.7, 0.95)  # Näher am Rand für bessere Verteilung
		var theta = randf() * 2 * PI  # Ganzer Kreis
		var pos = Vector3(r * cos(theta), 0, r * sin(theta))
		var global_pos = island_body.position + pos
		
		# Raycast, um genaue y-Position auf der Insel zu finden
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = global_pos + Vector3(0, 1000, 0)
		var ray_end = global_pos + Vector3(0, -1000, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == island_body:
			var global_y = result.position.y
			# Prüfe flach (normal nahe UP) und über Wasser
			if result.normal.dot(Vector3.UP) > 0.9 and global_y > 0.0:
				var spawn_pos = result.position + Vector3(0, 1, 0)  # Etwas über dem Boden
				
				# Spawn Capsule-Figur als CharacterBody3D
				player = CharacterBody3D.new()
				player.position = spawn_pos
				jumps_left = 1  # Reset jumps
				player.floor_max_angle = deg_to_rad(70)  # Höherer Winkel für steilere Abhänge
				player.floor_snap_length = 0.2  # Besserer Snap auf Boden
				
				var capsule_mesh = CapsuleMesh.new()
				capsule_mesh.radius = 1
				capsule_mesh.height = 2
				
				var mesh_inst = MeshInstance3D.new()
				mesh_inst.mesh = capsule_mesh
				mesh_inst.material_override = StandardMaterial3D.new()
				mesh_inst.material_override.albedo_color = Color(1, 0, 0)  # Rot für Sichtbarkeit
				mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				player.add_child(mesh_inst)
				
				var collider = CollisionShape3D.new()
				collider.shape = CapsuleShape3D.new()
				collider.shape.radius = 1
				collider.shape.height = 2
				player.add_child(collider)
				
				get_parent().add_child(player)
				
				# Kamera erstellen und hinzufügen
				camera = Camera3D.new()
				get_parent().add_child(camera)
				camera.current = true  # Aktiviere die Kamera
				print("Player und Kamera gespawnt bei: ", spawn_pos)
				return  # Erfolgreich gespawnt
		attempts += 1
	print("Kein geeigneter Spawn-Punkt gefunden!")

func generate_terrain_mesh(radius: float, height: float) -> ArrayMesh:
	var plane = PlaneMesh.new()
	plane.size = Vector2(radius * 2, radius * 2)
	plane.subdivide_depth = 64  # Hohe Subdivision für Detail
	plane.subdivide_width = 64
	
	var mesh = ArrayMesh.new()
	var arrays = plane.get_mesh_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.005
	noise.fractal_octaves = 6
	
	var shape_noise = FastNoiseLite.new()
	shape_noise.seed = randi()
	shape_noise.frequency = 0.1
	
	var underwater_noise = FastNoiseLite.new()
	underwater_noise.seed = randi()
	underwater_noise.frequency = 0.01
	underwater_noise.fractal_octaves = 4
	
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var x = v.x
		var z = v.z
		var dist = sqrt(x * x + z * z)
		if dist > radius:
			vertices[i] = Vector3(0, -50, 0)  # Außerhalb auf Meeresboden
			normals.append(Vector3.UP)
			colors.append(Color(0.8, 0.6, 0.2))
			continue
		
		var raw_noise = noise.get_noise_2d(x, z) * 0.5 + 0.5
		var noise_val = (raw_noise + 0.3) / 1.3
		var base_y = (noise_val - 0.6) * height * 8 * (1 - (dist / radius) * (dist / radius))
		var y = base_y
		if y < 0:
			y *= 0.1
		var underwater_depth = 50.0
		if dist > radius * 0.8:
			var slope_factor = (dist - radius * 0.8) / (radius * 0.2)
			var underwater_var = underwater_noise.get_noise_2d(x, z) * 0.5 + 0.5
			y -= slope_factor * underwater_depth * underwater_var
		
		vertices[i].y = y
		normals.append(Vector3.UP)
		var height_factor = (y + height * 4) / (height * 8)
		var color = Color()
		if dist / radius > 0.8:
			color = Color(0.8, 0.6, 0.2)
		elif height_factor > 0.7:
			color = Color(0.5, 0.5, 0.5)
		else:
			color.r = 0.1 + height_factor * 0.3
			color.g = 0.4 + height_factor * 0.3
			color.b = 0.1
		colors.append(color)
	
	var new_arrays = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = vertices
	new_arrays[Mesh.ARRAY_INDEX] = indices
	new_arrays[Mesh.ARRAY_TEX_UV] = uvs
	new_arrays[Mesh.ARRAY_NORMAL] = normals
	new_arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	return mesh
