@tool
class_name KnobInteraction extends Area3D

signal value_changed(value: float)
signal snap_changed(value: float)

@export var knob_sensitivity: float = 0.01
@export var knob_min_val: float = 0.0
@export var knob_max_val: float = 11.0
@export var invert_direction: bool = false

@export_group("Angle Limits")
@export var angle_limits: KnobAngleLimitsConfig

@export_group("Snapping")
@export var snapping: KnobSnappingConfig

var is_dragging: bool = false
var value: float
var last_mouse_pos_y: float
var knob: Node3D
var current_rotation: float = 0.0
var current_snap_rotation: float
var snap_points_radians: Array[float]


func _ready() -> void:
	knob = get_parent()
	if knob is not Node3D:
		push_error("KnobInteraction: parent node is not of type Node3D")
		return
	if snapping:
		if snapping.snap_points.is_empty():
			push_error("KnobInteraction: snapping config assigned but snap_points is empty")
			return
		for point in snapping.snap_points:
			snap_points_radians.append(deg_to_rad(point))
		current_snap_rotation = snap_points_radians[0]


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
	if invert_direction:
		rotation_delta = -rotation_delta

	if angle_limits:
		if invert_direction:
			apply_clamped_rotation(rotation_delta, -angle_limits.max_angle, angle_limits.min_angle)
		else:
			apply_clamped_rotation(rotation_delta, angle_limits.min_angle, angle_limits.max_angle)
		calculate_value()
	elif snapping:
		var min_angle: float = snap_points_radians.min()
		var max_angle: float = snap_points_radians.max()
		current_rotation = clamp(current_rotation + rotation_delta, min_angle, max_angle)
		var closest: float = find_closest_snap_point(current_rotation)
		if not is_equal_approx(closest, current_snap_rotation):
			var actual_delta: float = current_snap_rotation - closest
			current_snap_rotation = closest
			knob.rotate_object_local(Vector3.UP, actual_delta)
			calculate_value()
	else:
		if invert_direction:
			current_rotation -= rotation_delta
		else:
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
	var closest_point: float = 0.0
	for point in snap_points_radians:
		var dif: float = abs(actual_rotation - point)
		if dif < min_dif:
			min_dif = dif
			closest_point = point
	return closest_point


func calculate_value() -> void:
	if angle_limits:
		if invert_direction:
			value = remap(current_rotation, angle_limits.min_angle, angle_limits.max_angle, knob_min_val, -knob_max_val)
		else:
			value = remap(current_rotation, angle_limits.min_angle, angle_limits.max_angle, knob_min_val, knob_max_val)
	elif snapping:
		value = snap_points_radians.find(current_snap_rotation)
		snap_changed.emit(value)
	else:
		value = clamp(current_rotation, knob_min_val, knob_max_val)

	value_changed.emit(value)
	print("Value: ", value)
