extends CanvasLayer

@onready var generate_btn = $GenerateButton
@onready var spielen_btn = $SpielenButton  # Neuer Button
var island_body = null
var current_size_x = 0.0  # Speichere Insel-Größe
var player = null  # Speichere den Player
var camera = null  # Speichere die Kamera
var gravity = 40.0  # Höhere Gravity an Land
var jump_force = 15.0  # Niedrigere Jump Force für weniger Höhe
var jumps_left = 2  # Start mit 2 Sprüngen (1 normal + 1 extra)
var camera_angle = 0.0  # Für horizontale Kamera-Rotation
var camera_pitch = 0.0  # Für vertikale Kamera-Rotation
var zoom_distance = 15.0  # Zoom-Distanz für Kamera
var smoothing_factor = 10.0  # Für sanfte Geschwindigkeitsänderungen
var attack_range = 5.0  # Angriffsreichweite
var sprint_jump = false  # Für Sprint-Sprung
var original_trees = []  # Ursprüngliche Bäume Daten
var swimming = false  # Neue Variable für Schwimmen
var swim_speed = 8.0  # Geschwindigkeit beim Schwimmen
var inventory_grid = null  # Inventar Grid
var inventory = []  # Inventar Liste, [{"item": "holz", "count": 5}, ...]
var autowalk = false  # Neue Variable für Autowalk
var mouse_forward = false  # Neue Variable für Maustasten-Vorwärts
var controlling_ship = false  # Neue Variable für Schiff-Steuerung
var ship_body = null  # Neue Variable für Schiff-Referenz
var wheel_node = null  # Neue Variable für Steuerrad-Referenz
var on_water_surface = false  # Neue Variable für Wasseroberfläche
var ship_collision_detected = false  # Neue Flag für Schiff-Kollision
var enemies = []  # Neue Liste für Gegner
var target_position = null  # Neue Variable für direkte Ziel-Bewegung

func _ready():
	generate_btn.connect("pressed", Callable(self, "generate_island"))
	spielen_btn.connect("pressed", Callable(self, "spielen"))  # Verbinde Spielen-Button
	# Button nicht fokussierbar machen
	generate_btn.focus_mode = Control.FOCUS_NONE
	spielen_btn.focus_mode = Control.FOCUS_NONE
	
	# Inventar erstellen: 4x4 Grid unten rechts, Slots normal groß
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 4
	inventory_grid.position = Vector2(0, get_viewport().size.y - 320)  # Unten links, Höhe 320 für 4x4 Slots
	inventory_grid.visible = false  # Standardmäßig ausgeblendet
	add_child(inventory_grid)
	
	for i in range(16):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)  # Normal groß
		var style = StyleBoxFlat.new()
		style.border_width_top = 3  # Normal
		style.border_width_left = 3
		style.border_width_bottom = 3
		style.border_width_right = 3
		style.border_color = Color(0, 0, 0)
		style.bg_color = Color(0.3, 0.3, 0.3, 0.5)  # Dunkleres Grau für Sichtbarkeit
		slot.add_theme_stylebox_override("panel", style)
		
		# Icon als TextureRect
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.position = Vector2(10, 10)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		icon.stretch_mode = TextureRect.EXPAND_FIT_WIDTH
		slot.add_child(icon)
		
		# Count Label
		var count_label = Label.new()
		count_label.size = Vector2(10, 10)
		count_label.position = Vector2(23, 16)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var label_settings = LabelSettings.new()
		label_settings.font_size = 12
		count_label.label_settings = label_settings
		count_label.text = "0"  # Initial leer
		slot.add_child(count_label)
		
		# Weise das Drag-and-Drop-Skript zu
		slot.set_script(load("res://InventorySlot.gd"))
		slot.index = i
		slot.inventory_ref = inventory
		slot.update_ui_callback = Callable(self, "update_inventory_ui")
		
		inventory_grid.add_child(slot)

func add_item(item_name, amount):
	var remaining = amount
	for slot in inventory:
		if slot.item == item_name and slot.count < 20:
			var space = 20 - slot.count
			var add = min(remaining, space)
			slot.count += add
			remaining -= add
			if remaining <= 0:
				break
	if remaining > 0 and inventory.size() < 16:
		inventory.append({"item": item_name, "count": min(remaining, 20)})
		remaining -= min(remaining, 20)
	# Wenn noch mehr, ignoriere für jetzt
	update_inventory_ui()

func _on_ship_body_entered(body):
	if body.is_in_group("island") or body.is_in_group("small_island"):
		ship_collision_detected = true

func _on_ship_body_exited(body):
	if body.is_in_group("island") or body.is_in_group("small_island"):
		ship_collision_detected = false

func _input(event):
	if event is InputEventKey and event.keycode == KEY_I and event.pressed:
		inventory_grid.visible = not inventory_grid.visible
	
	if event is InputEventKey and event.keycode == KEY_NUMLOCK and event.pressed:
		autowalk = not autowalk  # Toggle Autowalk
	
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		controlling_ship = false  # Zurück zur normalen Steuerung
		if player:
			player.collision_mask |= 2  # Aktiviere Kollision mit Schiff
	
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and wheel_node and player:
		if player.position.distance_to(wheel_node.global_position) < 10.0:  # Erhöhte Distanz
			controlling_ship = true
			player.collision_mask &= ~2  # Deaktiviere Kollision mit Schiff
	
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not controlling_ship:
		perform_attack()
	
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if player and not controlling_ship and jumps_left > 0 and (player.is_on_floor() or on_water_surface) and not swimming:
			player.velocity.y = jump_force
			jumps_left -= 1
			on_water_surface = false  # Nach Sprung deaktivieren
		elif swimming:
			player.velocity.y = jump_force / 2  # Auftrieb im Wasser
		get_viewport().set_input_as_handled()  # Verhindere UI-Trigger
	
	# Kameradrehen nur mit Rechtsklick halten
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if camera:
			camera_angle -= event.relative.x * 0.01  # Horizontal
			camera_pitch -= event.relative.y * 0.01  # Vertikal
			camera_pitch = clamp(camera_pitch, -PI/4, PI/4)  # Limitiere Pitch
			get_viewport().set_input_as_handled()
	
	# Linksklick zum Bewegen (direkte Bewegung zum Punkt)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera and player:
			print("Linksklick erkannt für Bewegung")  # Debug
			var mouse_pos = event.position
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * 1000
			var space_state = get_viewport().world_3d.direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			if result and (result.collider == island_body or result.collider.is_in_group("small_island")):
				target_position = result.position
				print("Target set to: ", target_position)  # Debug
				get_viewport().set_input_as_handled()
			else:
				print("Kein gültiger Boden getroffen")  # Debug
	
	# Zoom mit Mausrad
	if event is InputEventMouseButton and camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = max(zoom_distance - 2.0, 5.0)  # Min 5
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = min(zoom_distance + 2.0, 50.0)  # Max 50
	
	# Prüfe linke + rechte Maustaste gleichzeitig
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		mouse_forward = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if mouse_forward:
			autowalk = false  # Deaktiviere Autowalk
	
	# Deaktiviere Autowalk bei Richtungstasten
	if event is InputEventKey and event.pressed and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		autowalk = false

func perform_attack():
	if not player or not camera:
		return
	var space_state = get_viewport().world_3d.direct_space_state
	var from = player.position + Vector3(0, 0.5, 0)  # Näher am Boden
	var forward = -camera.transform.basis.z  # Umgekehrte Richtung für Angriff
	forward = Vector3(forward.x, 0, forward.z).normalized()
	var to = from + forward * attack_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Player ausschließen
	var result = space_state.intersect_ray(query)
	if result and (result.collider.is_in_group("tree") or result.collider.is_in_group("enemy")):
		var target = result.collider
		var hp = target.get_meta("hp", 5) - 1  # HP abhängig von Größe oder 1 für Enemy
		target.set_meta("hp", hp)
		if target.is_in_group("tree"):
			# Wackeln für Bäume
			var tree_mesh = target.get_child(0) as MeshInstance3D
			var bush = target.get_child(2) as MeshInstance3D
			if tree_mesh and is_instance_valid(tree_mesh):
				tree_mesh.scale = Vector3(0.9, 0.9, 0.9)
			if bush and is_instance_valid(bush):
				bush.scale = Vector3(0.9, 0.9, 0.9)
			await get_tree().create_timer(0.08).timeout
			if tree_mesh and is_instance_valid(tree_mesh):
				tree_mesh.scale = Vector3(1, 1, 1)
			if bush and is_instance_valid(bush):
				bush.scale = Vector3(0.9, 0.9, 0.9)
			if bush and is_instance_valid(bush):
				bush.scale = Vector3(1, 1, 1)
			# Holz hinzufügen nur wenn Baum gefällt
			if hp <= 0:
				var bush_radius = bush.mesh.radius
				var wood_amount = clamp(int(bush_radius * 0.5), 1, 5)
				add_item("holz", wood_amount)
				if randf() < 0.1:
					var rarity_wood_amount = clamp(int(bush_radius * 0.3), 1, 3)
					add_item("holz_rarity1", rarity_wood_amount)
		# Schaden-Popup
		var label = Label3D.new()
		label.text = "-1"
		label.font_size = 128
		label.position = result.position + Vector3(0, 3, 0)
		label.billboard = true
		get_parent().add_child(label)
		var tween = get_tree().create_tween()
		tween.tween_property(label, "position:y", label.position.y + 2, 1.0)
		tween.tween_property(label, "modulate:a", 0, 1.0)
		tween.tween_callback(func(): label.queue_free())
		if hp <= 0 and target and is_instance_valid(target):
			target.queue_free()

func update_inventory_ui():
	for i in range(16):
		var slot = inventory_grid.get_child(i) as Panel
		var icon = slot.get_child(0) as TextureRect  # Jetzt TextureRect
		var count_label = slot.get_child(1) as Label
		if i < inventory.size() and inventory[i].item != "":
			var item = inventory[i]
			if item.item == "holz":
				icon.texture = preload("res://assets/icons/holz_icon.png") if ResourceLoader.exists("res://assets/icons/holz_icon.png") else null
				count_label.text = str(item.count)
			elif item.item == "holz_rarity1":
				icon.texture = preload("res://assets/icons/holz_rarity1_icon.png") if ResourceLoader.exists("res://assets/icons/holz_rarity1_icon.png") else null
				count_label.text = str(item.count)
			else:
				icon.texture = null
				count_label.text = ""
		else:
			icon.texture = null
			count_label.text = ""

func _process(delta):
	if player and camera:
		var water_level = 0.0
		var water_node = get_parent().find_child("Sea", true, false)
		if water_node:
			water_level = water_node.position.y
		else:
			water_level = 0.0
		
		swimming = player.position.y < water_level
		on_water_surface = player.position.y >= water_level - 0.1 and player.position.y < water_level + 0.1 and player.velocity.y >= -0.1 and not swimming
		
		if not swimming and not controlling_ship:
			if not player.is_on_floor():
				player.velocity.y -= gravity * delta
		
		if player.is_on_floor() or on_water_surface:
			jumps_left = 2
		
		var follow_target = player
		if controlling_ship and ship_body:
			follow_target = ship_body
		var camera_offset = Vector3(0, zoom_distance, zoom_distance).rotated(Vector3.RIGHT, camera_pitch).rotated(Vector3.UP, camera_angle)
		var target_pos = follow_target.position + camera_offset
		
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = follow_target.position
		var ray_dir = (target_pos - follow_target.position).normalized()
		var ray_length = (target_pos - follow_target.position).length()
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * ray_length)
		var result = space_state.intersect_ray(query)
		if result:
			target_pos = result.position - ray_dir * 2
		
		camera.position = camera.position.lerp(target_pos, 0.1)
		camera.look_at(follow_target.position, Vector3.UP)
		
		if controlling_ship and ship_body:
			player.position = ship_body.position + Vector3(0, 2, 0)
			player.velocity = Vector3(0, 0, 0)
			
			var ship_speed = 40.0
			var move_dir = Vector3()
			
			if Input.is_key_pressed(KEY_W) or autowalk or mouse_forward:
				move_dir.z -= 1
			if Input.is_key_pressed(KEY_S):
				move_dir.z += 1
			if Input.is_key_pressed(KEY_A):
				move_dir.x -= 1
			if Input.is_key_pressed(KEY_D):
				move_dir.x += 1
			
			if move_dir.length() > 0 and not ship_collision_detected:
				move_dir = move_dir.normalized()
				var camera_basis = camera.transform.basis
				var forward = (camera_basis.z * move_dir.z + camera_basis.x * move_dir.x)
				forward.y = 0
				forward = forward.normalized()
				
				if forward.length() > 0:
					ship_body.look_at(ship_body.position + forward, Vector3.UP)
				
				var move_vec = forward * ship_speed * delta
				ship_body.position += move_vec
			else:
				pass
			
			ship_body.position.y = water_level
		else:
			if ship_body:
				ship_body.position.y = water_level
		
		var speed = 10.0
		if Input.is_key_pressed(KEY_SHIFT) or sprint_jump:
			speed = 20.0
		
		if swimming:
			speed = swim_speed
		
		if not player.is_on_floor() and not swimming and not sprint_jump:
			speed *= 0.5
		
		var target_velocity_x = 0.0
		var target_velocity_z = 0.0
		
		var input_dir = Vector3()
		if Input.is_key_pressed(KEY_W) or autowalk or mouse_forward:
			input_dir.z -= 1
		if Input.is_key_pressed(KEY_S):
			input_dir.z += 1
		if Input.is_key_pressed(KEY_A):
			input_dir.x -= 1
		if Input.is_key_pressed(KEY_D):
			input_dir.x += 1
		
		# Direkte Bewegung zum Ziel
		if target_position and not controlling_ship:
			var dir = (target_position - player.position).normalized()
			dir.y = 0
			target_velocity_x = dir.x * speed
			target_velocity_z = dir.z * speed
			if player.position.distance_to(target_position) < 0.5:
				target_position = null
				print("Ziel erreicht")  # Debug
			player.look_at(target_position, Vector3.UP)
		
		if input_dir.length() > 0:
			input_dir = input_dir.normalized()
			var camera_basis = camera.transform.basis
			var move_dir = (camera_basis.z * input_dir.z + camera_basis.x * input_dir.x)
			move_dir.y = 0
			move_dir = move_dir.normalized()
			target_velocity_x = move_dir.x * speed
			target_velocity_z = move_dir.z * speed
			target_position = null  # Stoppe Ziel-Bewegung bei manueller Steuerung
		
		if sprint_jump and not swimming:
			player.velocity.x = target_velocity_x
			player.velocity.z = target_velocity_z
		else:
			player.velocity.x = lerp(player.velocity.x, target_velocity_x, delta * smoothing_factor)
			player.velocity.z = lerp(player.velocity.z, target_velocity_z, delta * smoothing_factor)
		
		if swimming:
			var target_velocity_y = sin(camera_pitch) * swim_speed
			if Input.is_key_pressed(KEY_SPACE):
				target_velocity_y += swim_speed
			player.velocity.y = lerp(player.velocity.y, target_velocity_y, delta * smoothing_factor)
		
		player.move_and_slide()
		
		# Gegner Bewegung mit Physik
		for enemy in enemies:
			if enemy and is_instance_valid(enemy):
				# Zufällige Richtung ändern alle ~1 Sekunde
				if not enemy.has_meta("change_time") or Time.get_time_dict_from_system()["second"] - enemy.get_meta("change_time", 0) > 1:
					enemy.set_meta("change_time", Time.get_time_dict_from_system()["second"])
					var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
					enemy.set_meta("direction", random_dir)
				
				var dir = enemy.get_meta("direction", Vector3(0, 0, 1))
				var enemy_speed = 5.0
				enemy.velocity.x = dir.x * enemy_speed
				enemy.velocity.z = dir.z * enemy_speed
				
				# Gravity anwenden
				if not enemy.is_on_floor():
					enemy.velocity.y -= gravity * delta
				
				enemy.move_and_slide()
				
				# Verhindere, dass Gegner ins Wasser gehen
				if enemy.position.y < water_level:
					enemy.position.y = water_level + 1
					# Richtung umkehren oder zufällig ändern
					var new_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
					enemy.set_meta("direction", new_dir)

func generate_island():
	# Entferne alte Inseln, kleine Inseln, Schiffe, Gegner
	if island_body:
		island_body.queue_free()
	if player:
		player.queue_free()
		player = null
	if camera:
		camera.queue_free()
		camera = null
	target_position = null  # Reset Ziel
	
	for child in get_parent().get_children():
		if child.is_in_group("small_island"):
			child.queue_free()
		if child.is_in_group("ship"):
			child.queue_free()
		if child.is_in_group("enemy"):
			child.queue_free()
	
	enemies.clear()
	original_trees.clear()
	
	var size_x = randf_range(100, 500)
	var size_z = size_x
	var max_height = size_x * 0.2
	var size_y = randf_range(max_height * 0.5, max_height)
	current_size_x = size_x
	
	island_body = StaticBody3D.new()
	island_body.position = Vector3(0, 0, 0)
	
	var terrain_result = generate_terrain_mesh(size_x / 2, size_y)
	var terrain_mesh = terrain_result[0]
	var terrain_noise = terrain_result[1]
	var terrain_instance = MeshInstance3D.new()
	terrain_instance.mesh = terrain_mesh
	terrain_instance.material_override = StandardMaterial3D.new()
	terrain_instance.material_override.albedo_color = Color(1, 1, 1)
	terrain_instance.material_override.vertex_color_use_as_albedo = true
	terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	island_body.add_child(terrain_instance)
	
	var collider = CollisionShape3D.new()
	collider.shape = terrain_mesh.create_trimesh_shape()
	island_body.add_child(collider)
	
	get_parent().add_child(island_body)
	
	var lights = get_parent().find_children("*", "DirectionalLight3D", true, false)
	for light in lights:
		if light is DirectionalLight3D:
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 2000.0
			light.shadow_bias = 0.01
			light.shadow_normal_bias = 1.0
			light.directional_shadow_blend_splits = true
			light.directional_shadow_mode = 2
			print("Schatten für DirectionalLight aktiviert und konfiguriert")
			break
	
	var sea_body = StaticBody3D.new()
	sea_body.name = "Sea"
	sea_body.position = Vector3(0, -5, 0)
	
	var sea_surface = MeshInstance3D.new()
	sea_surface.name = "Sea Surface"
	var plane = PlaneMesh.new()
	plane.size = Vector2(10000, 10000)
	sea_surface.mesh = plane
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.5, 1.0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea_surface.material_override = material
	sea_body.add_child(sea_surface)
	
	var water_volume = Area3D.new()
	water_volume.name = "Water Volume"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(10000, 110, 10000)
	var volume_collider = CollisionShape3D.new()
	volume_collider.shape = box_shape
	water_volume.add_child(volume_collider)
	sea_body.add_child(water_volume)
	
	get_parent().add_child(sea_body)
	
	var water_level = 0.0
	var water_node = get_parent().find_child("Sea", true, false)
	if water_node:
		water_level = water_node.position.y
	else:
		water_level = 0.0
	
	var num_trees = randi_range(10, 40)
	var space_state = get_viewport().world_3d.direct_space_state
	var tree_positions = []
	var min_distance = 5.0
	
	var num_flat = num_trees * 3 / 4
	var i = 0
	var radius = size_x / 2
	while tree_positions.size() < num_flat and i < num_flat * 100:
		var pos = Vector3()
		var r = randf_range(0.3 * radius, 0.9 * radius)
		var theta = randf() * 2 * PI
		pos.x = r * cos(theta)
		pos.z = r * sin(theta)
		var dist = sqrt(pos.x * pos.x + pos.z * pos.z)
		if dist <= radius:
			var raw_noise = terrain_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
			var noise_val = (raw_noise + 0.3) / 1.3
			var base_y = (noise_val - 0.6) * size_y * 8 * (1 - (dist / radius) * (dist / radius))
			var y = base_y
			if y < 0:
				y *= 0.1
			if dist > radius * 0.8:
				var underwater_noise = FastNoiseLite.new()
				underwater_noise.seed = randi()
				underwater_noise.frequency = 0.01
				underwater_noise.fractal_octaves = 4
				var underwater_var = underwater_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
				y -= (dist - radius * 0.8) / (radius * 0.2) * 50.0 * underwater_var
			if y > -10:
				var new_global_pos = Vector3(pos.x, y, pos.z)
				var too_close = false
				for existing_pos in tree_positions:
					if new_global_pos.distance_to(existing_pos) < min_distance:
						too_close = true
						break
				if not too_close:
					tree_positions.append(new_global_pos)
					pos.y = y
					var tree_body = StaticBody3D.new()
					tree_body.position = pos
					tree_body.add_to_group("tree")
					var rr = randf()
					var bush_radius
					if rr < 0.76:
						bush_radius = randf_range(1, 4)
					elif rr < 0.94:
						bush_radius = randf_range(4, 7)
					else:
						bush_radius = randf_range(7, 10)
					var hp = max(2, int((3 + int((bush_radius - 3) * 2.5)) * 0.6))
					tree_body.set_meta("hp", hp)
					var tree = MeshInstance3D.new()
					var tree_mesh = CylinderMesh.new()
					var tree_scale = bush_radius / 6.0
					var top_radius = randf_range(0.5, 1.5) * tree_scale + 0.1
					var bottom_radius = randf_range(1, 3) * tree_scale + 0.2
					var height = randf_range(15, 30) * tree_scale + 5
					tree_mesh.top_radius = top_radius
					tree_mesh.bottom_radius = bottom_radius
					tree_mesh.height = height
					tree.mesh = tree_mesh
					tree.material_override = StandardMaterial3D.new()
					tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
					tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					tree_body.add_child(tree)
					var tree_collider = CollisionShape3D.new()
					tree_collider.shape = CylinderShape3D.new()
					tree_collider.shape.radius = tree_mesh.bottom_radius * 0.9
					tree_collider.shape.height = tree_mesh.height * 0.9
					tree_body.add_child(tree_collider)
					var sink_factor = clamp((water_level - y) / 10, 0, 0.5)
					pos.y += tree_mesh.height / 2 - tree_mesh.height * (0.3 + sink_factor)
					tree_body.position = pos
					var bush = MeshInstance3D.new()
					var bush_mesh = SphereMesh.new()
					bush_mesh.radius = bush_radius
					bush_mesh.height = bush_mesh.radius * 2
					bush.mesh = bush_mesh
					bush.material_override = StandardMaterial3D.new()
					bush.material_override.albedo_color = Color(randf_range(0.0, 0.2), randf_range(0.2, 0.5), randf_range(0.0, 0.2))
					bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					bush.position = Vector3(0, tree_mesh.height / 2, 0)
					tree_body.add_child(bush)
					if randf() < 0.001:
						tree.material_override.albedo_color = Color(1, 0.8, 0)
						bush.material_override.albedo_color = Color(1, 1, 0)
						tree_body.add_to_group("golden_tree")
						print("Goldener Baum gespawnt!")
					island_body.add_child(tree_body)
					original_trees.append({"position": pos, "hp": hp, "bush_radius": bush_radius, "top_radius": top_radius, "bottom_radius": bottom_radius, "height": height, "is_golden": tree_body.is_in_group("golden_tree")})
		i += 1
	
	var remaining_trees = num_trees - tree_positions.size()
	i = 0
	while tree_positions.size() < num_trees and i < remaining_trees * 100:
		var pos = Vector3()
		var r = randf_range(0, 0.3 * radius)
		var theta = randf() * 2 * PI
		pos.x = r * cos(theta)
		pos.z = r * sin(theta)
		var dist = sqrt(pos.x * pos.x + pos.z * pos.z)
		if dist <= radius:
			var raw_noise = terrain_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
			var noise_val = (raw_noise + 0.3) / 1.3
			var base_y = (noise_val - 0.6) * size_y * 8 * (1 - (dist / radius) * (dist / radius))
			var y = base_y
			if y < 0:
				y *= 0.1
			if dist > radius * 0.8:
				var underwater_noise = FastNoiseLite.new()
				underwater_noise.seed = randi()
				underwater_noise.frequency = 0.01
				underwater_noise.fractal_octaves = 4
				var underwater_var = underwater_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
				y -= (dist - radius * 0.8) / (radius * 0.2) * 50.0 * underwater_var
			if y > water_level:
				var new_global_pos = Vector3(pos.x, y, pos.z)
				var too_close = false
				for existing_pos in tree_positions:
					if new_global_pos.distance_to(existing_pos) < min_distance:
						too_close = true
						break
				if not too_close:
					tree_positions.append(new_global_pos)
					pos.y = y
					var tree_body = StaticBody3D.new()
					tree_body.position = pos
					tree_body.add_to_group("tree")
					var rr = randf()
					var bush_radius
					if rr < 0.76:
						bush_radius = randf_range(1, 4)
					elif rr < 0.94:
						bush_radius = randf_range(4, 7)
					else:
						bush_radius = randf_range(7, 10)
					var hp = max(2, int((3 + int((bush_radius - 3) * 2.5)) * 0.6))
					tree_body.set_meta("hp", hp)
					var tree = MeshInstance3D.new()
					var tree_mesh = CylinderMesh.new()
					var tree_scale = bush_radius / 6.0
					var top_radius = randf_range(0.5, 1.5) * tree_scale + 0.1
					var bottom_radius = randf_range(1, 3) * tree_scale + 0.2
					var height = randf_range(15, 30) * tree_scale + 5
					tree_mesh.top_radius = top_radius
					tree_mesh.bottom_radius = bottom_radius
					tree_mesh.height = height
					tree.mesh = tree_mesh
					tree.material_override = StandardMaterial3D.new()
					tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
					tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					tree_body.add_child(tree)
					var tree_collider = CollisionShape3D.new()
					tree_collider.shape = CylinderShape3D.new()
					tree_collider.shape.radius = tree_mesh.bottom_radius * 0.9
					tree_collider.shape.height = tree_mesh.height * 0.9
					tree_body.add_child(tree_collider)
					var sink_factor = clamp((water_level - y) / 10, 0, 0.5)
					pos.y += tree_mesh.height / 2 - tree_mesh.height * (0.3 + sink_factor)
					tree_body.position = pos
					var bush = MeshInstance3D.new()
					var bush_mesh = SphereMesh.new()
					bush_mesh.radius = bush_radius
					bush_mesh.height = bush_mesh.radius * 2
					bush.mesh = bush_mesh
					bush.material_override = StandardMaterial3D.new()
					bush.material_override.albedo_color = Color(randf_range(0.0, 0.2), randf_range(0.2, 0.5), randf_range(0.0, 0.2))
					bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					bush.position = Vector3(0, tree_mesh.height / 2, 0)
					tree_body.add_child(bush)
					if randf() < 0.001:
						tree.material_override.albedo_color = Color(1, 0.8, 0)
						bush.material_override.albedo_color = Color(1, 1, 0)
						tree_body.add_to_group("golden_tree")
					island_body.add_child(tree_body)
					original_trees.append({"position": pos, "hp": hp, "bush_radius": bush_radius, "top_radius": top_radius, "bottom_radius": bottom_radius, "height": height, "is_golden": tree_body.is_in_group("golden_tree")})
		i += 1
	
	spawn_small_islands(size_x / 2, size_y, terrain_noise)
	
	spawn_ship(size_x / 2)
	
	spawn_enemies()
	
	print("Natürliche Insel generiert: Größe ", size_x, "x", size_y, "x", size_z, " mit ", tree_positions.size(), " Bäumen, Wasser bei ", water_level)

func spawn_enemies():
	var enemy_count = 0
	var prob = 0.8
	while randf() < prob and enemy_count < 10:
		var enemy = CharacterBody3D.new()
		enemy.add_to_group("enemy")
		enemy.set_meta("hp", 1)
		enemy.floor_max_angle = deg_to_rad(70)
		enemy.floor_snap_length = 0.2
		
		var capsule_mesh = CapsuleMesh.new()
		capsule_mesh.radius = 1
		capsule_mesh.height = 2
		
		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = capsule_mesh
		mesh_inst.material_override = StandardMaterial3D.new()
		mesh_inst.material_override.albedo_color = Color(1, 0, 0)
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		enemy.add_child(mesh_inst)
		
		var collider = CollisionShape3D.new()
		collider.shape = CapsuleShape3D.new()
		collider.shape.radius = 1
		collider.shape.height = 2
		enemy.add_child(collider)
		
		var r = current_size_x / 2 * randf_range(0.1, 0.9)
		var theta = randf() * 2 * PI
		var pos = Vector3(r * cos(theta), 0, r * sin(theta))
		var global_pos = island_body.position + pos
		
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = global_pos + Vector3(0, 1000, 0)
		var ray_end = global_pos + Vector3(0, -1000, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if result and result.collider == island_body:
			enemy.position = result.position + Vector3(0, 1, 0)
			get_parent().add_child(enemy)
			enemies.append(enemy)
		
		enemy_count += 1
		prob -= 0.1

func spawn_small_islands(main_radius: float, main_height: float, main_noise: FastNoiseLite):
	var num_small = randi_range(0, 12)
	var small_positions = []
	for i in range(num_small):
		var attempts = 0
		while attempts < 100:
			var angle = randf() * 2 * PI
			var distance = randf_range(main_radius + 50, main_radius + 200)
			var pos = Vector3(distance * cos(angle), 0, distance * sin(angle))
			var too_close = false
			for existing in small_positions:
				if pos.distance_to(existing) < 50:
					too_close = true
					break
			if not too_close:
				small_positions.append(pos)
				var small_size_x = randf_range(20, 80)
				var small_size_y = randf_range(5, 20)
				var small_island_body = StaticBody3D.new()
				small_island_body.position = pos
				small_island_body.add_to_group("small_island")
				var small_terrain_result = generate_terrain_mesh(small_size_x / 2, small_size_y)
				var small_terrain_mesh = small_terrain_result[0]
				var small_terrain_instance = MeshInstance3D.new()
				small_terrain_instance.mesh = small_terrain_mesh
				small_terrain_instance.material_override = StandardMaterial3D.new()
				small_terrain_instance.material_override.albedo_color = Color(1, 1, 1)
				small_terrain_instance.material_override.vertex_color_use_as_albedo = true
				small_terrain_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				small_island_body.add_child(small_terrain_instance)
				var small_collider = CollisionShape3D.new()
				small_collider.shape = small_terrain_mesh.create_trimesh_shape()
				small_island_body.add_child(small_collider)
				get_parent().add_child(small_island_body)
				var num_small_trees = randi_range(1, 5)
				for j in range(num_small_trees):
					var tree_pos = Vector3(randf_range(-small_size_x/4, small_size_x/4), 0, randf_range(-small_size_x/4, small_size_x/4))
					var tree_body = StaticBody3D.new()
					tree_body.position = tree_pos
					tree_body.add_to_group("tree")
					var rr = randf()
					var bush_radius
					if rr < 0.76:
						bush_radius = randf_range(1, 4)
					elif rr < 0.94:
						bush_radius = randf_range(4, 7)
					else:
						bush_radius = randf_range(7, 10)
					var hp = max(2, int((3 + int((bush_radius - 3) * 2.5)) * 0.6))
					tree_body.set_meta("hp", hp)
					var tree = MeshInstance3D.new()
					var tree_mesh = CylinderMesh.new()
					var tree_scale = bush_radius / 6.0
					var top_radius = randf_range(0.5, 1.5) * tree_scale + 0.1
					var bottom_radius = randf_range(1, 3) * tree_scale + 0.2
					var height = randf_range(15, 30) * tree_scale + 5
					tree_mesh.top_radius = top_radius
					tree_mesh.bottom_radius = bottom_radius
					tree_mesh.height = height
					tree.mesh = tree_mesh
					tree.material_override = StandardMaterial3D.new()
					tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
					tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					tree_body.add_child(tree)
					var tree_collider = CollisionShape3D.new()
					tree_collider.shape = CylinderShape3D.new()
					tree_collider.shape.radius = tree_mesh.bottom_radius * 0.9
					tree_collider.shape.height = tree_mesh.height * 0.9
					tree_body.add_child(tree_collider)
					tree_pos.y = tree_mesh.height / 2 - tree_mesh.height * 0.3
					tree_body.position = tree_pos
					var bush = MeshInstance3D.new()
					var bush_mesh = SphereMesh.new()
					bush_mesh.radius = bush_radius
					bush_mesh.height = bush_mesh.radius * 2
					bush.mesh = bush_mesh
					bush.material_override = StandardMaterial3D.new()
					bush.material_override.albedo_color = Color(randf_range(0.0, 0.2), randf_range(0.2, 0.5), randf_range(0.0, 0.2))
					bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					bush.position = Vector3(0, tree_mesh.height / 2, 0)
					tree_body.add_child(bush)
					if randf() < 0.001:
						tree.material_override.albedo_color = Color(1, 0.8, 0)
						bush.material_override.albedo_color = Color(1, 1, 0)
						tree_body.add_to_group("golden_tree")
					small_island_body.add_child(tree_body)
				break
			attempts += 1

func spawn_ship(island_radius: float):
	ship_body = StaticBody3D.new()
	ship_body.position = Vector3(island_radius + 20, -5, 0)
	ship_body.add_to_group("ship")
	
	var hull = MeshInstance3D.new()
	var hull_box = BoxMesh.new()
	hull_box.size = Vector3(6, 3, 15)
	hull.mesh = hull_box
	hull.material_override = StandardMaterial3D.new()
	hull.material_override.albedo_color = Color(0.6, 0.4, 0.2)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	ship_body.add_child(hull)
	
	var mast = MeshInstance3D.new()
	var mast_cylinder = CylinderMesh.new()
	mast_cylinder.top_radius = 0.2
	mast_cylinder.bottom_radius = 0.2
	mast_cylinder.height = 10
	mast.mesh = mast_cylinder
	mast.material_override = StandardMaterial3D.new()
	mast.material_override.albedo_color = Color(0.5, 0.3, 0.1)
	mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	mast.position = Vector3(0, 5, 0)
	ship_body.add_child(mast)
	
	var sail = MeshInstance3D.new()
	var sail_plane = PlaneMesh.new()
	sail_plane.size = Vector2(8, 6)
	sail.mesh = sail_plane
	sail.material_override = StandardMaterial3D.new()
	sail.material_override.albedo_color = Color(0.9, 0.9, 0.9)
	sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	sail.position = Vector3(0, 8, 0)
	ship_body.add_child(sail)
	
	var wheel = MeshInstance3D.new()
	var wheel_cylinder = CylinderMesh.new()
	wheel_cylinder.top_radius = 0.5
	wheel_cylinder.bottom_radius = 0.5
	wheel_cylinder.height = 0.2
	wheel.mesh = wheel_cylinder
	wheel.material_override = StandardMaterial3D.new()
	wheel.material_override.albedo_color = Color(0.4, 0.2, 0.0)
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	wheel.position = Vector3(0, 1.5, -7)
	ship_body.add_child(wheel)
	wheel_node = wheel
	
	var ship_area = Area3D.new()
	ship_area.name = "ShipArea"
	var area_collider = CollisionShape3D.new()
	area_collider.shape = BoxShape3D.new()
	area_collider.shape.size = Vector3(8, 5, 17)
	ship_area.add_child(area_collider)
	ship_area.connect("body_entered", Callable(self, "_on_ship_body_entered"))
	ship_area.connect("body_exited", Callable(self, "_on_ship_body_exited"))
	ship_body.add_child(ship_area)
	
	get_parent().add_child(ship_body)

func spawn_trees():
	if not island_body:
		return
	
	for child in island_body.get_children():
		if child.is_in_group("tree"):
			child.queue_free()
	
	for tree_data in original_trees:
		var pos = tree_data.position
		var hp = tree_data.hp
		var bush_radius = tree_data.bush_radius
		var top_radius = tree_data.top_radius
		var bottom_radius = tree_data.bottom_radius
		var height = tree_data.height
		var is_golden = tree_data.is_golden
		
		var tree_body = StaticBody3D.new()
		tree_body.position = pos
		tree_body.add_to_group("tree")
		tree_body.set_meta("hp", hp)
		var tree = MeshInstance3D.new()
		var tree_mesh = CylinderMesh.new()
		tree_mesh.top_radius = top_radius
		tree_mesh.bottom_radius = bottom_radius
		tree_mesh.height = height
		tree.mesh = tree_mesh
		tree.material_override = StandardMaterial3D.new()
		tree.material_override.albedo_color = Color(0.4, 0.2, 0.0)
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		tree_body.add_child(tree)
		
		var tree_collider = CollisionShape3D.new()
		tree_collider.shape = CylinderShape3D.new()
		tree_collider.shape.radius = tree_mesh.bottom_radius * 0.9
		tree_collider.shape.height = tree_mesh.height * 0.9
		tree_body.add_child(tree_collider)
		
		var bush = MeshInstance3D.new()
		var bush_mesh = SphereMesh.new()
		bush_mesh.radius = bush_radius
		bush_mesh.height = bush_mesh.radius * 2
		bush.mesh = bush_mesh
		bush.material_override = StandardMaterial3D.new()
		bush.material_override.albedo_color = Color(randf_range(0.0, 0.2), randf_range(0.2, 0.5), randf_range(0.0, 0.2))
		bush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		bush.position = Vector3(0, tree_mesh.height / 2, 0)
		tree_body.add_child(bush)
		
		if is_golden:
			tree.material_override.albedo_color = Color(1, 0.8, 0)
			bush.material_override.albedo_color = Color(1, 1, 0)
			tree_body.add_to_group("golden_tree")
		
		island_body.add_child(tree_body)

func spielen():
	if not island_body:
		print("Keine Insel generiert!")
		return
	if player:
		player.queue_free()
	if camera:
		camera.queue_free()
	target_position = null  # Reset Ziel
	
	spawn_trees()
	
	var attempts = 0
	var max_attempts = 300
	while attempts < max_attempts:
		var r = current_size_x / 2 * randf_range(0.7, 0.95)
		var theta = randf() * 2 * PI
		var pos = Vector3(r * cos(theta), 0, r * sin(theta))
		var global_pos = island_body.position + pos
		
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = global_pos + Vector3(0, 1000, 0)
		var ray_end = global_pos + Vector3(0, -1000, 0)
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == island_body:
			var global_y = result.position.y
			if result.normal.dot(Vector3.UP) > 0.9 and global_y > 0.0:
				var spawn_pos = result.position + Vector3(0, 1, 0)
				
				player = CharacterBody3D.new()
				player.position = spawn_pos
				player.collision_layer = 3
				player.collision_mask &= ~2
				jumps_left = 2
				player.floor_max_angle = deg_to_rad(70)
				player.floor_snap_length = 0.2
				
				var capsule_mesh = CapsuleMesh.new()
				capsule_mesh.radius = 1
				capsule_mesh.height = 2
				
				var mesh_inst = MeshInstance3D.new()
				mesh_inst.mesh = capsule_mesh
				mesh_inst.material_override = StandardMaterial3D.new()
				mesh_inst.material_override.albedo_color = Color(1, 0, 0)
				mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				player.add_child(mesh_inst)
				
				var collider = CollisionShape3D.new()
				collider.shape = CapsuleShape3D.new()
				collider.shape.radius = 1
				collider.shape.height = 2
				player.add_child(collider)
				
				get_parent().add_child(player)
				
				camera = Camera3D.new()
				get_parent().add_child(camera)
				camera.current = true
				print("Player und Kamera gespawnt bei: ", spawn_pos)
				return
		attempts += 1
	print("Kein geeigneter Spawn-Punkt gefunden!")

func generate_terrain_mesh(radius: float, height: float) -> Array:
	var plane = PlaneMesh.new()
	plane.size = Vector2(radius * 2, radius * 2)
	plane.subdivide_depth = 64
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
			vertices[i] = Vector3(0, -50, 0)
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
			y -= (dist - radius * 0.8) / (radius * 0.2) * 50.0 * underwater_var
		
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
	return [mesh, noise]
