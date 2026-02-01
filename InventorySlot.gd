extends Panel

var index: int
var inventory_ref: Array
var update_ui_callback: Callable

func _ready():
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _get_drag_data(at_position):
	if index < inventory_ref.size() and inventory_ref[index] and inventory_ref[index].item != "":
		return {"item_index": index}
	return null

func _can_drop_data(at_position, data):
	return data.has("item_index") and data.item_index != index

func _drop_data(at_position, data):
	var from_index = data.item_index
	var to_index = index
	
	if from_index < inventory_ref.size() and inventory_ref[from_index].item != "":
		var from_item = inventory_ref[from_index]
		if to_index < inventory_ref.size() and inventory_ref[to_index].item != "":
			# Tausch, wenn beide Slots Items haben
			inventory_ref[from_index] = inventory_ref[to_index]
			inventory_ref[to_index] = from_item
		else:
			# Verschiebe zu leerem Slot
			inventory_ref[from_index] = {"item": "", "count": 0}
			# Erweitere Array, wenn nötig
			while inventory_ref.size() <= to_index:
				inventory_ref.append({"item": "", "count": 0})
			inventory_ref[to_index] = from_item
	
	update_ui_callback.call()

func _on_mouse_entered():
	modulate = Color(1.2, 1.2, 1.2)  # Heller machen beim Hover

func _on_mouse_exited():
	modulate = Color(1, 1, 1)  # Normal zurück
