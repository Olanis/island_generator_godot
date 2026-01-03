extends CanvasLayer

@onready var generate_btn = $GenerateButton
var island_body = null
var camera_rotation = Vector2()
var camera_distance = 500.0

func _ready():
	generate_btn.connect("pressed", Callable(self, "generate_island"))
	# Kamera initialisieren, falls nicht vorhanden
	if not get_parent().has_node("Camera3D"):
		var camera = Camera3D.new()
		get_parent().add_child(camera)
	update_camera()

func generate_island():
	if island_body:
		island_body.queue_free()
	
	var size_x = randf_range(100, 500)
	var size_z = size_x
	var size_y = randf_range(100, 200)  # Höhere Höhe für mehr Variation
	
	island_body = StaticBody3D.new()
	island_body.position = Vector3(0, size_y / 4, 0)  # Insel über Wasser
	
	# Einzelnes Terrain-Mesh mit Noise
	var terrain_mesh = generate_terrain_mesh(size_x / 2, size_y, 20, 32)  # Radius, Höhe, Rings, Segments
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.mesh = terrain_mesh
	terrain_instance.material_override = StandardMaterial3D.new()
	terrain_instance.material_override.albedo_color = Color(1, 1, 1)  # Weiß, um Vertex-Farben zu verwenden
	terrain_instance.material_override.vertex_color_use_as_albedo = true
	island_body.add_child(terrain_instance)
	
	# Gespiegeltes Terrain unter Wasser
	var mirrored_terrain = MeshInstance3D.new()
	mirrored_terrain.mesh = terrain_mesh
	mirrored_terrain.material_override = StandardMaterial3D.new()
	mirrored_terrain.material_override.albedo_color = Color(1, 1, 1)
	mirrored_terrain.material_override.vertex_color_use_as_albedo = true
	mirrored_terrain.scale = Vector3(1, -1, 1)  # Spiegeln nach unten
	mirrored_terrain.position = Vector3(0, -size_y / 4, 0)  # Unter Wasser
	island_body.add_child(mirrored_terrain)
	
	# Collider nur für oberes Terrain
	var collider = CollisionShape3D.new()
	collider.shape = terrain_mesh.create_trimesh_shape()
	island_body.add_child(collider)
	
	get_parent().add_child(island_body)  # Hinzufügen, bevor Bäume
	
	# Wasseroberfläche holen
	var water_level = 0.0
	var water_node = get_parent().find_child("Water", true, false)  # Suche nach Node namens "Water"
	if water_node:
		water_level = water_node.position.y
	else:
		print("Kein Water-Node gefunden, verwende y=0")
	
	# Bäume zufällig platzieren, nur auf Insel, über Wasser, auf Oberfläche via Raycast, min Abstand, senkrecht nach oben, Basis 30% in Erde
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
				var terrain_y = result.position.y - island_body.position.y
				var global_y = result.position.y
				if global_y > water_level:  # Über Wasser
					var new_global_pos = result.position
					# Prüfe Abstand zu bestehenden Bäumen
					var too_close = false
					for existing_pos in tree_positions:
						if new_global_pos.distance_to(existing_pos) < min_distance:
							too_close = true
							break
					if not too_close:
						tree_positions.append(new_global_pos)
						pos.y = terrain_y
						break
			attempts += 1
		if attempts < 50:
			var tree = MeshInstance3D.new()
			var tree_mesh = CylinderMesh.new()
			tree_mesh.top_radius = randf_range(0.5, 1.5)
			tree_mesh.bottom_radius = randf_range(1, 3)
			tree_mesh.height = randf_range(15, 30)  # Längere Bäume
			tree.mesh = tree_mesh
			tree.material_override = StandardMaterial3D.new()
			tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
			
			pos.y += tree_mesh.height / 2 - tree_mesh.height * 0.3  # Basis 30% in Erde
			tree.position = pos
			island_body.add_child(tree)
	
	print("Natürliche Insel generiert: Größe ", size_x, "x", size_y, "x", size_z, " mit ", tree_positions.size(), " Bäumen, Wasser bei ", water_level)

func generate_terrain_mesh(radius: float, height: float, rings: int, segments: int) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()  # Für Höhen-Farben
	
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.005
	noise.fractal_octaves = 6
	
	var shape_noise = FastNoiseLite.new()
	shape_noise.seed = randi()
	shape_noise.frequency = 0.1
	
	# Zentrum - jetzt auch höhenbasiert
	var center_y = 0.0
	var center_r = 0.0
	var height_factor = (center_y + height / 2) / height
	var color = Color()
	if center_r / radius > 0.8:
		color = Color(0.8, 0.6, 0.2)
	elif height_factor > 0.7:
		color = Color(0.5, 0.5, 0.5)
	else:
		color.r = 0.1 + height_factor * 0.3
		color.g = 0.4 + height_factor * 0.3
		color.b = 0.1
	vertices.append(Vector3(0, 0, 0))
	uvs.append(Vector2(0.5, 0.5))
	normals.append(Vector3.UP)
	colors.append(color)
	
	for ring in range(1, rings + 1):
		var base_r = (ring / float(rings)) * radius
		for seg in range(segments):
			var theta = (seg / float(segments)) * 2 * PI
			var shape_var = shape_noise.get_noise_2d(cos(theta) * 100, sin(theta) * 100) * 0.3
			var r = base_r + shape_var * radius * 0.5
			r = max(0, r)
			var x = r * cos(theta)
			var z = r * sin(theta)
			var noise_val = noise.get_noise_2d(x, z) * 0.5 + 0.5
			var y = (noise_val - 0.5) * height * (1 - (r / radius) * (r / radius))
			vertices.append(Vector3(x, y, z))
			uvs.append(Vector2((x / radius + 1) / 2, (z / radius + 1) / 2))
			normals.append(Vector3.UP)
			# Höhen-Farbe: Sand am Rand, grün niedrig, grau hoch
			height_factor = (y + height / 2) / height  # 0-1
			color = Color()
			if r / radius > 0.8:
				color = Color(0.8, 0.6, 0.2)  # Sand
			elif height_factor > 0.7:
				color = Color(0.5, 0.5, 0.5)  # Grau für Stein
			else:
				color.r = 0.1 + height_factor * 0.3
				color.g = 0.4 + height_factor * 0.3
				color.b = 0.1
			colors.append(color)
	
	# Triangles
	for ring in range(rings):
		var start_inner = 1 + (ring - 1) * segments if ring > 0 else 0
		var start_outer = 1 + ring * segments
		for seg in range(segments):
			var inner1 = start_inner + seg
			var inner2 = start_inner + (seg + 1) % segments if ring > 0 else 0
			var outer1 = start_outer + seg
			var outer2 = start_outer + (seg + 1) % segments
			
			if ring == 0:
				indices.append(0)
				indices.append(outer1)
				indices.append(outer2)
			else:
				indices.append(inner1)
				indices.append(outer1)
				indices.append(inner2)
				indices.append(inner2)
				indices.append(outer1)
				indices.append(outer2)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			camera_rotation.x -= event.relative.y * 0.01  # Oben/unten
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			camera_rotation.y -= event.relative.x * 0.01  # Links/rechts
		update_camera()

func update_camera():
	var camera = get_parent().get_node_or_null("Camera3D")
	if camera:
		var rotation_matrix = Basis().rotated(Vector3.RIGHT, camera_rotation.x).rotated(Vector3.UP, camera_rotation.y)
		var position = rotation_matrix * Vector3(0, 0, camera_distance)
		position.y = max(position.y, 10)  # Nicht unter Wasser
		camera.position = position
		camera.look_at(Vector3(0, 0, 0))
