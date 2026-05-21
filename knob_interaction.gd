@tool
class_name KnobInteraction extends Area3D

signal value_changed(value: float)

@export var knob_sensitivity: float = 0.01
@export var knob_min_val: float = 0.0
@export var knob_max_val: float = 11.0


var knob_angle_limits: bool = false:
	set(v):
		knob_angle_limits = v
		notify_property_list_changed()
var toggle_snapping: bool = false:
	set(v):
		toggle_snapping = v
		notify_property_list_changed()

var is_dragging: bool = false
var value: float
var last_mouse_pos_y: float
var knob: Node3D
var current_rotation: float = 0.0
var current_snap_rotation: float
var knob_min_angle: float = 0.0
var knob_max_angle: float = 0.0
var snap_points: Array[float]

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({
		"name": "Angle Limits",
		"type": TYPE_NIL,
		"hint_string": "knob_",
		"usage": PROPERTY_USAGE_GROUP
	})
	props.append({
		"name": "knob_angle_limits",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	if knob_angle_limits:
		props.append({
			"name": "Angle Limits",
			"type": TYPE_NIL,
			"hint_string": "knob_",
			"usage": PROPERTY_USAGE_GROUP
		})
		props.append({
			"name": "knob_min_angle",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-720,720,0.1,radians_as_degrees",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		props.append({
			"name": "knob_max_angle",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-720,720,0.1,radians_as_degrees",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	props.append({
		"name": "Snapping",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_CATEGORY
	})
	props.append({
		"name": "toggle_snapping",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	if toggle_snapping:
		props.append({
			"name": "snap_points",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_ARRAY_TYPE,
			"hint_string": "float",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	return props


func _ready() -> void:
	knob = get_parent()
	if knob is not Node3D:
		push_error("KnobInteraction: parent node is not of type Node3D")
		return
	if toggle_snapping:
		if snap_points.is_empty():
			push_error("KnobInteraction: toggle_snapping is enabled but snap_points is empty")
			return
		# Snapping handles it's own angles
		knob_angle_limits = false
		snap_points = convert_snap_points_to_radians()
		knob_min_angle = snap_points.min()
		knob_max_angle = snap_points.max()
		current_snap_rotation = snap_points[0]


func _input(event: InputEvent) -> void:
	if event.is_action_released("click") and is_dragging:
		is_dragging = false
	
	if is_dragging and event is InputEventMouseMotion:
		var mouse_y_delta: float = last_mouse_pos_y - event.position.y
		last_mouse_pos_y = event.position.y
		rotate_knob(mouse_y_delta)


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		is_dragging = true
		last_mouse_pos_y = event.position.y


func rotate_knob(mouse_y_delta: float) -> void:
	var rotation_delta: float = mouse_y_delta * knob_sensitivity
	
	if knob_angle_limits: # Knob has min and max angle limits
		apply_clamped_rotation(rotation_delta, knob_min_angle, knob_max_angle)
		calculate_value()
	elif toggle_snapping: # Knob has fixed positions
		current_rotation = clamp(current_rotation + rotation_delta, knob_min_angle, knob_max_angle)
		var closest_snapping_point: float = find_closest_snap_point(current_rotation)
		if not is_equal_approx(closest_snapping_point , current_snap_rotation):
			var actual_delta = current_snap_rotation - closest_snapping_point
			current_snap_rotation = closest_snapping_point
			knob.rotate_object_local(Vector3.UP, actual_delta)
			calculate_value()
	else: # Knob is free spinning
		current_rotation += rotation_delta
		knob.rotate_object_local(Vector3.UP, rotation_delta)
		calculate_value()


func apply_clamped_rotation(rotation_delta: float, min_angle: float, max_angle: float) -> void:
	var new_rotation: float = clamp(current_rotation + rotation_delta, min_angle, max_angle)
	var actual_delta: float = new_rotation - current_rotation
	current_rotation = new_rotation
	knob.rotate_object_local(Vector3.UP, actual_delta)


func find_closest_snap_point(actual_rotation: float) -> float:
	var min_dif: float = INF
	var closest_point: float = 0
	for point in snap_points:
		var dif: float = abs(actual_rotation - point)
		if dif < min_dif:
			min_dif = dif
			closest_point = point
	
	return closest_point

func calculate_value() -> void:
	if knob_angle_limits:
		value = remap(current_rotation, knob_min_angle, knob_max_angle, knob_min_val, knob_max_val)
	elif toggle_snapping:
		value = snap_points.find(current_snap_rotation)
	else:
		value = clamp(current_rotation, knob_min_val, knob_max_val)

	value_changed.emit(value)

func convert_snap_points_to_radians() -> Array[float]:
	var new_array: Array[float]
	for point in snap_points:
		new_array.append(deg_to_rad(point))
	return new_array
