extends CanvasLayer

@onready var generate_btn = $GenerateButton
@onready var spielen_btn = $SpielenButton  # Neuer Button
var island_body = null
var current_size_x = 0.0  # Speichere Insel-Größe
var player = null  # Speichere den Player
var camera = null  # Speichere die Kamera
var gravity = 40.0  # Höhere Gravity an Land
var jump_force = 15.0  # Niedrigere Jump Force für weniger Höhe
var jumps_left = 1  # Start mit 1 Sprung
var camera_angle = 0.0  # Für horizontale Kamera-Rotation
var camera_pitch = 0.0  # Für vertikale Kamera-Rotation
var zoom_distance = 15.0  # Zoom-Distanz für Kamera
var smoothing_factor = 10.0  # Für sanfte Geschwindigkeitsänderungen
var attack_range = 5.0  # Angriffsreichweite
var sprint_jump = false  # Für Sprint-Sprung
var original_trees = []  # Ursprüngliche Bäume Daten
var original_flowers = []  # Ursprüngliche Blumen Daten
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
var control_mode = "wasd"  # Steuerungsmodus: "wasd" oder "click"
var control_mode_label = null  # Label für Anzeige des Modus
var audio_players = []  # Liste von AudioPlayern für Angriffssounds
var ambient_player = null  # AudioPlayer für Ambient-Sound
var swimming_player = null  # AudioPlayer für Schwimm-Sound
var swimming_timer = null  # Timer für verzögerte Swimming-Sound-Änderung
var pending_swimming = false  # Zwischenspeicher für nächsten Swimming-Zustand
var water_level = -5.0  # Globale Wasserhöhe
var total_trees = 0  # Gesamtanzahl der Bäume auf der Insel
var killed_trees = 0  # Anzahl der getöteten Bäume
var tree_ui_panel = null  # Neues UI-Element für Baum-Zähler oben rechts
var tree_ui_icon = null  # Icon für Baum
var tree_ui_label = null  # Label für Anzahl
var attack_hold_time = 0.0  # Zeit, die Angriff gehalten wird
var max_hold_time = 2.0  # 2 Sekunden für Bodenangriff
var short_click_time = 0.2  # 0.2 Sekunden für normale Attack
var is_holding_attack = false  # Ob Angriff gehalten wird
var can_perform_normal_attack = true  # Ob normale Attack noch möglich ist
var attack_progress_bar = null  # Ladebalken über dem Kopf
var digging_player = null  # AudioPlayer für Digging-Sound
var footsteps_player = null  # AudioPlayer für Footsteps-Sound
var jump_landing_player = null  # AudioPlayer für Jump-Landing-Sound
var was_in_air = false  # Tracken, ob Player vorher in der Luft war
var flower_base_color = Color(1, 0, 0)  # Rote Basis als Default

func _ready():
	generate_btn.connect("pressed", Callable(self, "generate_start_cluster"))
	spielen_btn.connect("pressed", Callable(self, "spielen"))  # Verbinde Spielen-Button
	# Button nicht fokussierbar machen
	generate_btn.focus_mode = Control.FOCUS_NONE
	spielen_btn.focus_mode = Control.FOCUS_NONE
	
	# Control Mode Label erstellen
	control_mode_label = Label.new()
	control_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_mode_label.size = Vector2(200, 20)
	control_mode_label.position = Vector2(get_viewport().size.x / 2 - 100, 10)
	control_mode_label.text = "Control Mode: WASD"
	control_mode_label.z_index = 1000  # Sicher vorne
	add_child(control_mode_label)
	
	# Baum-Zähler UI oben rechts erstellen
	tree_ui_panel = Panel.new()
	tree_ui_panel.size = Vector2(160, 60)  # Größer gemacht für großes Icon
	tree_ui_panel.position = Vector2(get_viewport().size.x - 160, 0)  # Weiter links und oben
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dunkler Hintergrund
	tree_ui_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(tree_ui_panel)
	
	# Baum-Icon (Label mit Emoji) im Panel
	tree_ui_icon = Label.new()
	tree_ui_icon.text = "🌳"  # Baum-Emoji
	tree_ui_icon.size = Vector2(50, 50)
	tree_ui_icon.position = Vector2(5, 5)
	var icon_settings = LabelSettings.new()
	icon_settings.font_size = 36  # Kleiner gemacht auf 36
	tree_ui_icon.label_settings = icon_settings
	tree_ui_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tree_ui_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tree_ui_panel.add_child(tree_ui_icon)
	
	# Label für Anzahl
	tree_ui_label = Label.new()
	tree_ui_label.size = Vector2(70, 20)
	tree_ui_label.position = Vector2(60, 20)  # Neben dem Icon
	tree_ui_label.text = "0/0"
	var label_settings = LabelSettings.new()
	label_settings.font_size = 16
	tree_ui_label.label_settings = label_settings
	tree_ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tree_ui_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tree_ui_panel.add_child(tree_ui_label)
	
	# Inventar erstellen: 4x4 Grid unten links, Slots normal groß
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
		var label_settings_slot = LabelSettings.new()
		label_settings_slot.font_size = 12
		count_label.label_settings = label_settings_slot
		count_label.text = "0"  # Initial leer
		slot.add_child(count_label)
		
		# Weise das Drag-and-Drop-Skript zu
		slot.set_script(load("res://InventorySlot.gd"))
		slot.index = i
		slot.inventory_ref = inventory
		slot.update_ui_callback = Callable(self, "update_inventory_ui")
		
		inventory_grid.add_child(slot)
	
	# Mehrere AudioPlayer für Angriffssounds erstellen, um schnelle Klicks zu unterstützen
	for i in range(10):  # 10 Player für schnelle Klicks
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = preload("res://assets/sounds/wood_chop.mp3")
		audio_player.volume_db = 0  # Normale Lautstärke
		add_child(audio_player)
		audio_players.append(audio_player)
	
	# Ambient-Sound Player erstellen und abspielen
	ambient_player = AudioStreamPlayer.new()
	var ambient_stream = preload("res://assets/sounds/ambient.mp3") as AudioStreamMP3
	ambient_stream.loop = true  # Looping aktivieren
	ambient_player.stream = ambient_stream
	ambient_player.volume_db = -10  # Leiser für Hintergrund
	add_child(ambient_player)
	ambient_player.play()  # Sofort abspielen
	
	# Swimming-Sound Player erstellen
	swimming_player = AudioStreamPlayer.new()
	var swimming_stream = preload("res://assets/sounds/swimming.mp3") as AudioStreamMP3
	swimming_stream.loop = true  # Looping aktivieren
	swimming_player.stream = swimming_stream
	swimming_player.volume_db = 0  # Normale Lautstärke
	add_child(swimming_player)
	
	# Timer für verzögerte Swimming-Sound-Änderung erstellen
	swimming_timer = Timer.new()
	swimming_timer.wait_time = 0.5  # 0.5 Sekunden Verzögerung
	swimming_timer.one_shot = true
	swimming_timer.connect("timeout", Callable(self, "_on_swimming_timer_timeout"))
	add_child(swimming_timer)
	
	# Digging-Sound Player erstellen
	digging_player = AudioStreamPlayer.new()
	var digging_stream = preload("res://assets/sounds/digging.mp3") as AudioStreamMP3
	digging_stream.loop = true  # Looping aktivieren
	digging_player.stream = digging_stream
	digging_player.volume_db = 0  # Normale Lautstärke
	add_child(digging_player)
	
	# Footsteps-Sound Player erstellen
	footsteps_player = AudioStreamPlayer.new()
	var footsteps_stream = preload("res://assets/sounds/footsteps.mp3") as AudioStreamMP3
	footsteps_stream.loop = true  # Looping aktivieren
	footsteps_player.stream = footsteps_stream
	footsteps_player.volume_db = 0  # Normale Lautstärke
	add_child(footsteps_player)
	
	# Jump-Landing-Sound Player erstellen
	jump_landing_player = AudioStreamPlayer.new()
	var jump_landing_stream = preload("res://assets/sounds/jump_landing.mp3") as AudioStreamMP3
	jump_landing_player.stream = jump_landing_stream
	jump_landing_player.volume_db = 0  # Normale Lautstärke
	add_child(jump_landing_player)
	
	# Ladebalken für Bodenangriff erstellen
	attack_progress_bar = ProgressBar.new()
	attack_progress_bar.size = Vector2(100, 10)
	attack_progress_bar.value = 0
	attack_progress_bar.max_value = 100
	attack_progress_bar.visible = false
	add_child(attack_progress_bar)

func _on_swimming_timer_timeout():
	swimming = pending_swimming
	if swimming and not swimming_player.playing:
		swimming_player.play()
	elif not swimming and swimming_player.playing:
		swimming_player.stop()

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

func update_tree_ui():
	if tree_ui_label:
		tree_ui_label.text = str(killed_trees) + "/" + str(total_trees)

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
	
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed:
		if control_mode == "wasd":
			control_mode = "click"
			control_mode_label.text = "Control Mode: Click-to-Move"
			print("Switched to Click-to-Move control")
		else:
			control_mode = "wasd"
			control_mode_label.text = "Control Mode: WASD"
			print("Switched to WASD control")
	
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		controlling_ship = false  # Zurück zur normalen Steuerung
		if player:
			player.collision_mask |= 2  # Aktiviere Kollision mit Schiff
	
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and wheel_node and player:
		if player.position.distance_to(wheel_node.global_position) < 50.0:  # Erhöhte Distanz für Zuverlässigkeit
			controlling_ship = true
			player.collision_mask &= ~2  # Deaktiviere Kollision mit Schiff
	
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if player and not controlling_ship and jumps_left > 0 and not swimming:
			player.velocity.y = jump_force
			jumps_left -= 1
			on_water_surface = false  # Nach Sprung deaktivieren
			# Spring-Sound rückwärts abspielen
			if jump_landing_player:
				jump_landing_player.pitch_scale = -1.0
				jump_landing_player.play()
		get_viewport().set_input_as_handled()  # Verhindere UI-Trigger
	
	# Kameradrehen nur mit Linksklick oder Rechtsklick halten
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		if camera:
			camera_angle -= event.relative.x * 0.01  # Horizontal
			camera_pitch -= event.relative.y * 0.01  # Vertikal
			camera_pitch = clamp(camera_pitch, -PI/4, PI/4)  # Limitiere Pitch
			get_viewport().set_input_as_handled()
	
	# Rechtsklick zum Bewegen (direkte Bewegung zum Punkt) - nur im Click-Modus
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and control_mode == "click":
		if camera and player:
			print("Rechtsklick erkannt für Bewegung")  # Debug
			var mouse_pos = event.position
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * 1000
			var space_state = get_viewport().world_3d.direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			if result and (result.collider.is_in_group("island_cluster") or result.collider.is_in_group("small_island")):
				target_position = result.position
				print("Target set to: ", target_position)  # Debug
				get_viewport().set_input_as_handled()
			else:
				print("Kein gültiger Boden getroffen")  # Debug
	
	# Angriff mit Linksklick halten für Bodenangriff oder normale Attack
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not controlling_ship and not is_holding_attack:
			is_holding_attack = true
			attack_hold_time = 0.0
			can_perform_normal_attack = true
		elif not event.pressed:
			is_holding_attack = false
			if attack_hold_time < short_click_time:
				perform_attack()  # Kurzer Klick: normale Attack
			attack_hold_time = 0.0
			attack_progress_bar.visible = false
			digging_player.stop()  # Stoppe Digging-Sound
			can_perform_normal_attack = true  # Reset
	
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
	
	# Deaktiviere Autowalk bei Richtungstasten - nur im WASD-Modus
	if event is InputEventKey and event.pressed and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D] and control_mode == "wasd":
		autowalk = false

func perform_attack():
	if not player or not camera:
		return
	var space_state = get_viewport().world_3d.direct_space_state
	var from = player.position + Vector3(0, 0.5, 0)  # Näher am Boden
	var forward = -camera.transform.basis.z  # Umgekehrte Richtung für Angriff (mit Pitch)
	forward = forward.normalized()
	var to = from + forward * attack_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Player ausschließen
	var result = space_state.intersect_ray(query)
	if result and (result.collider.is_in_group("tree") or result.collider.is_in_group("enemy") or result.collider.is_in_group("flower")):
		var target = result.collider
		var hp = target.get_meta("hp", 5) - 1  # HP abhängig von Größe oder 1 für Enemy
		target.set_meta("hp", hp)
		if target.is_in_group("tree"):
			# Sound abspielen mit einem freien Player aus der Liste
			if audio_players.size() > 0:
				var audio_player = audio_players.pop_front()
				audio_player.stop()
				audio_player.play()
				audio_players.append(audio_player)  # Zurück an die Liste für zyklische Verwendung
			
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
				killed_trees += 1  # Inkrementiere getötete Bäume
				var bush_radius = bush.mesh.radius
				var wood_amount = clamp(int(bush_radius * 0.5), 1, 5)
				add_item("holz", wood_amount)
				if randf() < 0.1:
					var rarity_wood_amount = clamp(int(bush_radius * 0.3), 1, 3)
					add_item("holz_rarity1", rarity_wood_amount)
				update_tree_ui()  # UI aktualisieren
		# Keine Schaden-Popup mehr
		
		if hp <= 0 and target and is_instance_valid(target):
			target.queue_free()

func perform_ground_attack():
	if not player or not camera:
		return
	var space_state = get_viewport().world_3d.direct_space_state
	var from = player.position + Vector3(0, 0.5, 0)  # Näher am Boden
	var forward = -camera.transform.basis.z  # Umgekehrte Richtung für Angriff (mit Pitch)
	forward = forward.normalized()
	var to = from + forward * attack_range
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player]  # Player ausschließen
	var result = space_state.intersect_ray(query)
	if result and (result.collider.is_in_group("island_cluster") or result.collider.is_in_group("small_island")):
		# Boden einfärben anstatt Mesh zu spawnen
		var terrain_body = result.collider
		var terrain_instance = null
		for child in terrain_body.get_children():
			if child is MeshInstance3D:
				terrain_instance = child
				break
		if terrain_instance and terrain_instance.mesh is ArrayMesh:
			var array_mesh = terrain_instance.mesh as ArrayMesh
			var arrays = array_mesh.surface_get_arrays(0)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var colors = arrays[Mesh.ARRAY_COLOR]
			var hit_pos = result.position - terrain_body.position  # Lokale Position
			var radius = 10.0  # Doppel so groß (von 5.0 auf 10.0)
			for i in range(vertices.size()):
				var v = vertices[i]
				var dist = hit_pos.distance_to(v)
				if dist <= radius:
					# Stärker einfärben: komplett zu Braun setzen
					colors[i] = Color(0.4, 0.2, 0.0)
			var new_arrays = []
			new_arrays.resize(Mesh.ARRAY_MAX)
			new_arrays[Mesh.ARRAY_VERTEX] = arrays[Mesh.ARRAY_VERTEX]
			new_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
			new_arrays[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV]
			new_arrays[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
			new_arrays[Mesh.ARRAY_COLOR] = colors
			var new_mesh = ArrayMesh.new()
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
			terrain_instance.mesh = new_mesh

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
		var current_water_level = 0.0
		var water_node = get_parent().find_child("Sea", true, false)
		if water_node:
			current_water_level = water_node.position.y
		else:
			current_water_level = -5.0
		
		var current_swimming = player.position.y < current_water_level
		if current_swimming != pending_swimming:
			pending_swimming = current_swimming
			swimming_timer.start()  # Timer starten für verzögerte Änderung
		
		swimming = player.position.y < current_water_level
		on_water_surface = player.position.y >= current_water_level - 0.1 and player.position.y < current_water_level + 0.1 and player.velocity.y >= -0.1 and not swimming
		
		if not swimming and not controlling_ship:
			if not player.is_on_floor():
				player.velocity.y -= gravity * delta
		
		if player.is_on_floor() or on_water_surface:
			jumps_left = 1
		
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
			var ship_move_dir = Vector3()
			
			if Input.is_key_pressed(KEY_W) or autowalk or mouse_forward:
				ship_move_dir.z -= 1
			if Input.is_key_pressed(KEY_S):
				ship_move_dir.z += 1
			if Input.is_key_pressed(KEY_A):
				ship_move_dir.x -= 1
			if Input.is_key_pressed(KEY_D):
				ship_move_dir.x += 1
			
			if ship_move_dir.length() > 0:
				ship_move_dir = ship_move_dir.normalized()
				var camera_basis = camera.transform.basis
				var forward = (camera_basis.z * ship_move_dir.z + camera_basis.x * ship_move_dir.x)
				forward.y = 0
				forward = forward.normalized()
				
				if forward.length() > 0:
					ship_body.look_at(ship_body.position + forward, Vector3.UP)
				
				var move_vec = forward * ship_speed * delta
				ship_body.velocity = move_vec / delta  # Setze Geschwindigkeit für CharacterBody3D
			else:
				ship_body.velocity = Vector3(0, 0, 0)
			
			# Simuliere Abprall, wenn Kollision detektiert
			if ship_collision_detected:
				ship_body.velocity = -ship_body.velocity * 0.8  # Abprall mit Dämpfung
			
			ship_body.move_and_slide()  # Bewege mit Kollision
			
			ship_body.position.y = current_water_level
		else:
			if ship_body:
				ship_body.position.y = current_water_level
		
		var speed = 20.0
		if swimming:
			speed = swim_speed
		
		if not player.is_on_floor() and not swimming and not sprint_jump:
			speed *= 0.5
		
		var target_velocity_x = 0.0
		var target_velocity_z = 0.0
		
		var input_dir = Vector3()
		if control_mode == "wasd":
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
			var move_dir_vec = (camera_basis.z * input_dir.z + camera_basis.x * input_dir.x)
			move_dir_vec.y = 0
			move_dir_vec = move_dir_vec.normalized()
			target_velocity_x = move_dir_vec.x * speed
			target_velocity_z = move_dir_vec.z * speed
			target_position = null  # Stoppe Ziel-Bewegung bei manueller Steuerung
		
		# Verhindere Bewegung während Bodenangriff
		if is_holding_attack and attack_hold_time >= short_click_time:
			target_velocity_x = 0.0
			target_velocity_z = 0.0
		
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
		
		# Landung-Sound: Wenn Player landet (war in Luft, jetzt auf Boden)
		var is_in_air = not player.is_on_floor()
		if not is_in_air and was_in_air and not swimming and not on_water_surface:
			if jump_landing_player:
				jump_landing_player.pitch_scale = 1.0  # Normal abspielen
				jump_landing_player.play()
		was_in_air = is_in_air
		
		# Footsteps-Sound: Spiele ab, wenn sich bewegt, an Land (is_on_floor), nicht im Wasser
		var is_moving = abs(target_velocity_x) > 0.1 or abs(target_velocity_z) > 0.1
		if is_moving and player.is_on_floor() and not swimming and not controlling_ship:
			if not footsteps_player.playing:
				footsteps_player.play()
		else:
			if footsteps_player.playing:
				footsteps_player.stop()
		
		# Angriff halten für Bodenangriff oder normale Attack
		if is_holding_attack:
			attack_hold_time += delta
			if attack_hold_time >= short_click_time and can_perform_normal_attack:
				perform_attack()  # Normale Attack nach 0.5 Sekunden
				can_perform_normal_attack = false
				attack_progress_bar.visible = true  # Zeige Balken nach kurzem Halten
				if not digging_player.playing:
					digging_player.play()  # Starte Digging-Sound
			if attack_hold_time >= max_hold_time:
				perform_ground_attack()
				is_holding_attack = false
				attack_hold_time = 0.0
				attack_progress_bar.visible = false
				digging_player.stop()  # Stoppe Digging-Sound
				can_perform_normal_attack = true  # Reset
			elif attack_hold_time >= short_click_time:
				var progress = ((attack_hold_time - short_click_time) / (max_hold_time - short_click_time)) * 100
				attack_progress_bar.value = progress
		
		# Positioniere Ladebalken über dem Kopf des Players
		if player and camera and attack_progress_bar.visible:
			var player_head_pos = player.position + Vector3(0, 2.5, 0)  # Über dem Kopf
			var screen_pos = camera.unproject_position(player_head_pos)
			attack_progress_bar.position = screen_pos - Vector2(attack_progress_bar.size.x / 2, attack_progress_bar.size.y + 10)  # Zentriert und etwas höher
		
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
				
				# Verhindere, dass Gegner ins Wasser gehen oder darin spawnen
				if enemy.position.y < current_water_level:
					# Raycast nach oben, um die Insel-Oberfläche zu finden
					var enemy_space_state = get_viewport().world_3d.direct_space_state
					var enemy_ray_origin = enemy.position + Vector3(0, 100, 0)
					var enemy_ray_end = enemy.position + Vector3(0, -200, 0)  # Tiefer, um sicherzugehen
					var enemy_query = PhysicsRayQueryParameters3D.create(enemy_ray_origin, enemy_ray_end)
					var enemy_result = enemy_space_state.intersect_ray(enemy_query)
					if enemy_result and (enemy_result.collider.is_in_group("island_cluster") or enemy_result.collider.is_in_group("small_island")):
						enemy.position = enemy_result.position + Vector3(0, 0.1, 0)  # Setze leicht über der Insel
						enemy.velocity = Vector3(0, 0, 0)  # Stoppe Bewegung
						# Neue Richtung setzen, weg vom Wasser
						var new_dir = (enemy_result.position - enemy.position).normalized()
						new_dir.y = 0
						if new_dir.length() > 0:
							enemy.set_meta("direction", new_dir)
						else:
							enemy.set_meta("direction", Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())

func generate_start_cluster():
	# Entferne alte Inseln, kleine Inseln, Schiffe, Gegner
	for node in get_tree().get_nodes_in_group("island_cluster"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("small_island"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("ship"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	
	enemies.clear()
	original_trees.clear()
	original_flowers.clear()
	killed_trees = 0  # Reset getötete Bäume
	update_tree_ui()  # UI zurücksetzen
	
	# Entferne Player und Kamera, um Spielmodus zu beenden
	if player:
		player.queue_free()
		player = null
	if camera:
		camera.queue_free()
		camera = null
	target_position = null
	controlling_ship = false
	if ship_body:
		ship_body.queue_free()
		ship_body = null
	
	generate_island_cluster(Vector3(0, 0, 0))

func generate_island_cluster(cluster_pos: Vector3):
	# Entferne alte Inseln, kleine Inseln, Schiffe, Gegner für diesen Cluster? Nein, da mehrere Cluster
	# Für jetzt, generiere nur hinzu, aber um Kollisionen zu vermeiden, passe an
	
	var size_x = randf_range(100, 500)
	var size_z = size_x
	var max_height = size_x * 0.2
	var size_y = randf_range(max_height * 0.5, max_height)
	current_size_x = size_x
	
	island_body = StaticBody3D.new()
	island_body.position = cluster_pos
	island_body.add_to_group("island")  # Ändere zu "island" für Kollision
	island_body.add_to_group("island_cluster")
	
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
	sea_body.position = Vector3(0, water_level, 0)  # Verwende globale water_level
	
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
	
	var current_water_level = 0.0
	var water_node = get_parent().find_child("Sea", true, false)
	if water_node:
		current_water_level = water_node.position.y
		water_level = current_water_level  # Aktualisiere globale Variable
	else:
		current_water_level = -5.0
		water_level = -5.0
	
	var num_trees = randi_range(10, 40)
	var space_state = get_viewport().world_3d.direct_space_state
	var tree_positions = []
	var min_distance = 5.0
	
	var underwater_noise = FastNoiseLite.new()
	underwater_noise.seed = randi()
	underwater_noise.frequency = 0.01
	underwater_noise.fractal_octaves = 4
	
	var num_flat = num_trees * 3 / 4
	var i = 0
	var radius = size_x / 2
	while tree_positions.size() < num_flat and i < num_flat * 100:
		var pos = Vector3()
		var r = randf_range(0.3 * radius, 0.75 * radius)  # Bäume nicht am Strand (gelber Ring)
		var theta = randf() * 2 * PI
		pos.x = r * cos(theta)
		pos.z = r * sin(theta)
		var dist = sqrt(pos.x * pos.x + pos.z * pos.z)
		if dist <= radius:
			var raw_noise = terrain_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
			var noise_val = (raw_noise + 0.3) / 1.3
			var base_y = (noise_val - 0.6) * size_y * 4 * (1 - (dist / radius) * (dist / radius))  # Reduziert von 8 auf 4 für flachere Inseln
			var y = base_y
			if y < 0:
				y *= 0.1
			if dist > radius * 0.5:  # Früherer Start für flacheren Slope
				var slope_factor = (dist - radius * 0.5) / (radius * 0.5)
				var underwater_var = underwater_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
				y -= slope_factor * 0.5 * underwater_var  # Noch flacher
			if y > current_water_level + 0.5:  # Geändert von 5.0 zu 0.5
				var new_global_pos = cluster_pos + Vector3(pos.x, y, pos.z)
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
					var sink_factor = clamp((current_water_level - y) / 10, 0, 0.5)
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
		var r = randf_range(0, 0.75 * radius)  # Auch hier nicht am Strand
		var theta = randf() * 2 * PI
		pos.x = r * cos(theta)
		pos.z = r * sin(theta)
		var dist = sqrt(pos.x * pos.x + pos.z * pos.z)
		if dist <= radius:
			var raw_noise = terrain_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
			var noise_val = (raw_noise + 0.3) / 1.3
			var base_y = (noise_val - 0.6) * size_y * 4 * (1 - (dist / radius) * (dist / radius))  # Reduziert von 8 auf 4 für flachere Inseln
			var y = base_y
			if y < 0:
				y *= 0.1
			if dist > radius * 0.5:  # Früherer Start für flacheren Slope
				var slope_factor = (dist - radius * 0.5) / (radius * 0.5)
				var underwater_var = underwater_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
				y -= slope_factor * 0.5 * underwater_var  # Noch flacher
			if y > current_water_level + 0.5:  # Geändert von 5.0 zu 0.5
				var new_global_pos = cluster_pos + Vector3(pos.x, y, pos.z)
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
					var sink_factor = clamp((current_water_level - y) / 10, 0, 0.5)
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
	
	total_trees = tree_positions.size()  # Setze Gesamtanzahl der Bäume
	update_tree_ui()  # UI aktualisieren
	
	# Blumen spawnen - Basis-Farbe pro Insel wählen
	var base_colors = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1), Color(1, 1, 0), Color(1, 0, 1)]
	flower_base_color = base_colors[randi() % base_colors.size()]
	
	var num_flowers = randi_range(20, 50)
	var flower_positions = []
	i = 0
	while flower_positions.size() < num_flowers and i < num_flowers * 200:
		var pos = Vector3()
		var r = randf_range(0.1 * radius, 0.8 * radius)  # Blumen überall
		var theta = randf() * 2 * PI
		pos.x = r * cos(theta)
		pos.z = r * sin(theta)
		var dist = sqrt(pos.x * pos.x + pos.z * pos.z)
		if dist <= radius:
			var raw_noise = terrain_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
			var noise_val = (raw_noise + 0.3) / 1.3
			var base_y = (noise_val - 0.6) * size_y * 4 * (1 - (dist / radius) * (dist / radius))
			var y = base_y
			if y < 0:
				y *= 0.1
			if dist > radius * 0.5:
				var slope_factor = (dist - radius * 0.5) / (radius * 0.5)
				var underwater_var = underwater_noise.get_noise_2d(pos.x, pos.z) * 0.5 + 0.5
				y -= slope_factor * 0.5 * underwater_var
			if y > current_water_level + 0.1:
				var new_global_pos = cluster_pos + Vector3(pos.x, y, pos.z)
				var too_close = false
				for existing_pos in tree_positions + flower_positions:
					if new_global_pos.distance_to(existing_pos) < min_distance:
						too_close = true
						break
				if not too_close:
					flower_positions.append(new_global_pos)
					pos.y = y
					var flower_body = StaticBody3D.new()
					flower_body.position = pos
					flower_body.add_to_group("flower")
					flower_body.set_meta("hp", 1)  # Blumen haben 1 HP
					# Stamm: Größerer grüner Zylinder
					var stem = MeshInstance3D.new()
					var stem_mesh = CylinderMesh.new()
					stem_mesh.top_radius = 0.08
					stem_mesh.bottom_radius = 0.08
					stem_mesh.height = 1.0  # Größer
					stem.mesh = stem_mesh
					stem.material_override = StandardMaterial3D.new()
					stem.material_override.albedo_color = Color(0.0, 0.5, 0.0)  # Grün
					stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					flower_body.add_child(stem)
					pos.y += stem_mesh.height / 2
					flower_body.position = pos
					# Blätter: Größere Kugel in Abwandlungen der Basis-Farbe
					var petal = MeshInstance3D.new()
					var petal_mesh = SphereMesh.new()
					petal_mesh.radius = 0.4  # Größer
					petal_mesh.height = 0.8
					petal.mesh = petal_mesh
					petal.material_override = StandardMaterial3D.new()
					# Abwandlung der Basis-Farbe mit RGB-Variation
					var varied_color = flower_base_color + Color(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
					varied_color = varied_color.clamp(Color(0, 0, 0), Color(1, 1, 1))
					petal.material_override.albedo_color = varied_color
					petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					petal.position = Vector3(0, stem_mesh.height / 2, 0)
					flower_body.add_child(petal)
					island_body.add_child(flower_body)
					original_flowers.append({"position": pos, "color": petal.material_override.albedo_color})
		i += 1
	
	spawn_small_islands(size_x / 2, size_y, terrain_noise, cluster_pos)
	
	spawn_ship(size_x / 2, cluster_pos)
	
	spawn_enemies(cluster_pos)
	
	print("Natürliche Insel generiert: Größe ", size_x, "x", size_y, "x", size_z, " mit ", tree_positions.size(), " Bäumen und ", flower_positions.size(), " Blumen, Wasser bei ", current_water_level)

func generate_underbuild_mesh(radius: float, island_height: float) -> Mesh:
	# Verwende ein CylinderMesh als Basis, aber modifiziere es für unregelmäßige Form
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius * 0.3  # Verjüngend
	cylinder.height = island_height * 2  # Höhe des Unterbaus
	
	# Für steinige, unregelmäßige Form, deformiere die Vertices mit Noise
	var arrays = cylinder.get_mesh_arrays()
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var indices = arrays[Mesh.ARRAY_INDEX]
	
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	
	for i in range(vertices.size()):
		var v = vertices[i]
		var x = v.x
		var z = v.z
		var y = v.y
		
		# Unregelmäßige Deformation für steinige Form
		var noise_x = noise.get_noise_3d(x, y, z) * 5
		var noise_z = noise.get_noise_3d(x + 100, y, z) * 5
		var noise_y = noise.get_noise_3d(x, y + 100, z) * 2
		
		vertices[i].x += noise_x
		vertices[i].z += noise_z
		vertices[i].y += noise_y
		
		normals.append(Vector3.UP)
		colors.append(Color(0.4, 0.4, 0.4))
	
	var new_arrays = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = vertices
	new_arrays[Mesh.ARRAY_INDEX] = indices
	new_arrays[Mesh.ARRAY_TEX_UV] = uvs
	new_arrays[Mesh.ARRAY_NORMAL] = normals
	new_arrays[Mesh.ARRAY_COLOR] = colors
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	return mesh

func spawn_enemies(cluster_pos: Vector3):
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
		var global_pos = cluster_pos + pos
		
		var space_state = get_viewport().world_3d.direct_space_state
		var ray_origin = global_pos + Vector3(0, 5000, 0)  # Höherer Start für bessere Ray
		var ray_end = global_pos + Vector3(0, -5000, 0)  # Tieferes Ende
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if result and result.collider and (result.collider.is_in_group("island_cluster") or result.collider.is_in_group("small_island")) and result.position.y > water_level + 1.0:
			enemy.position = result.position + Vector3(0, 2, 0)  # Leicht über dem Boden setzen
			enemy.velocity.y = -100.0  # Starke fallende Geschwindigkeit, um sicherzustellen, dass sie fallen und auf dem Boden landen
			get_parent().add_child(enemy)
			enemies.append(enemy)
		
		enemy_count += 1
		prob -= 0.1

func spawn_small_islands(main_radius: float, main_height: float, main_noise: FastNoiseLite, cluster_pos: Vector3):
	var num_small = randi_range(0, 12)
	var small_positions = []
	for i in range(num_small):
		var attempts = 0
		while attempts < 100:
			var angle = randf() * 2 * PI
			var distance = randf_range(main_radius * 1.5, main_radius * 2.5)  # Erhöhte Distanz von 1.5 bis 2.5 mal Radius
			var pos = Vector3(distance * cos(angle), 0, distance * sin(angle))
			var too_close = false
			for existing in small_positions:
				if pos.distance_to(existing) < 100:  # Erhöhte min Distanz zwischen kleinen Inseln
					too_close = true
					break
			if not too_close:
				small_positions.append(pos)
				var small_size_x = randf_range(20, 80)
				var small_size_y = randf_range(5, 20)
				var small_island_body = StaticBody3D.new()
				small_island_body.position = cluster_pos + pos
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
				var underwater_noise = FastNoiseLite.new()
				underwater_noise.seed = randi()
				underwater_noise.frequency = 0.01
				underwater_noise.fractal_octaves = 4
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
				# Blumen auf kleinen Inseln spawnen - Verwende die Insel-Basis-Farbe
				var num_small_flowers = randi_range(5, 15)
				for k in range(num_small_flowers):
					var flower_pos = Vector3(randf_range(-small_size_x/4, small_size_x/4), 0, randf_range(-small_size_x/4, small_size_x/4))
					var flower_body = StaticBody3D.new()
					flower_body.position = flower_pos
					flower_body.add_to_group("flower")
					flower_body.set_meta("hp", 1)
					var stem = MeshInstance3D.new()
					var stem_mesh = CylinderMesh.new()
					stem_mesh.top_radius = 0.08
					stem_mesh.bottom_radius = 0.08
					stem_mesh.height = 1.0
					stem.mesh = stem_mesh
					stem.material_override = StandardMaterial3D.new()
					stem.material_override.albedo_color = Color(0.0, 0.5, 0.0)
					stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					flower_body.add_child(stem)
					flower_pos.y = stem_mesh.height / 2
					flower_body.position = flower_pos
					var petal = MeshInstance3D.new()
					var petal_mesh = SphereMesh.new()
					petal_mesh.radius = 0.4
					petal_mesh.height = 0.8
					petal.mesh = petal_mesh
					petal.material_override = StandardMaterial3D.new()
					# Abwandlung der Insel-Basis-Farbe mit RGB-Variation
					var varied_color = flower_base_color + Color(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
					varied_color = varied_color.clamp(Color(0, 0, 0), Color(1, 1, 1))
					petal.material_override.albedo_color = varied_color
					petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
					petal.position = Vector3(0, stem_mesh.height / 2, 0)
					flower_body.add_child(petal)
					small_island_body.add_child(flower_body)
				break
			attempts += 1

func spawn_ship(island_radius: float, cluster_pos: Vector3):
	ship_body = CharacterBody3D.new()  # Ändere zu CharacterBody3D für Kollision
	ship_body.position = cluster_pos + Vector3(island_radius + 20, water_level, 0)  # Verwende globale water_level
	
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
	
	# Kollisions-Shape für das Schiff hinzufügen
	var ship_collider = CollisionShape3D.new()
	ship_collider.shape = BoxShape3D.new()
	ship_collider.shape.size = Vector3(6, 3, 15)
	ship_body.add_child(ship_collider)
	
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

func spawn_flowers():
	if not island_body:
		return
	
	for child in island_body.get_children():
		if child.is_in_group("flower"):
			child.queue_free()
	
	for flower_data in original_flowers:
		var pos = flower_data.position
		var color = flower_data.color
		
		var flower_body = StaticBody3D.new()
		flower_body.position = pos
		flower_body.add_to_group("flower")
		flower_body.set_meta("hp", 1)
		# Stamm
		var stem = MeshInstance3D.new()
		var stem_mesh = CylinderMesh.new()
		stem_mesh.top_radius = 0.08
		stem_mesh.bottom_radius = 0.08
		stem_mesh.height = 1.0
		stem.mesh = stem_mesh
		stem.material_override = StandardMaterial3D.new()
		stem.material_override.albedo_color = Color(0.0, 0.5, 0.0)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		flower_body.add_child(stem)
		# Keine Kollision
		# Blätter
		var petal = MeshInstance3D.new()
		var petal_mesh = SphereMesh.new()
		petal_mesh.radius = 0.4
		petal_mesh.height = 0.8
		petal.mesh = petal_mesh
		petal.material_override = StandardMaterial3D.new()
		petal.material_override.albedo_color = color
		petal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		petal.position = Vector3(0, stem_mesh.height / 2, 0)
		flower_body.add_child(petal)
		island_body.add_child(flower_body)

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
	spawn_flowers()
	
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
				jumps_left = 1
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
		var base_y = (noise_val - 0.6) * height * 4 * (1 - (dist / radius) * (dist / radius))  # Reduziert für flachere Inseln
		var y = base_y
		if y < 0:
			y *= 0.1
		
		# Flache Küste auf Wasserhöhe für kleine Inseln
		if radius < 50 and dist > radius * 0.8:
			y = 0.0
		
		var underwater_depth = 50.0
		if radius < 50:  # Für kleine Inseln flacheren Strand
			underwater_depth = 10.0  # Noch flacher machen
		if dist > radius * 0.8:
			var slope_factor = (dist - radius * 0.8) / (radius * 0.2)
			var underwater_var = underwater_noise.get_noise_2d(x, z) * 0.5 + 0.5
			y -= slope_factor * underwater_depth * underwater_var
		
		vertices[i].y = y
		normals.append(Vector3.UP)
		var height_factor = (y + height * 4) / (height * 8)  # Anpassen an neuen Multiplikator
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
