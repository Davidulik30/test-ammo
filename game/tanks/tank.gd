extends VehicleBody3D
@export_group("Nodes")
@export var body: Node3D
@export var turret: Node3D
@export var barrel: Node3D

@onready var left: VehicleWheel3D = $left
@onready var right: VehicleWheel3D = $right


@export var explosion_root: Node3D
@export_group("Audio/FX")
@export var muzzle_audio: AudioStreamPlayer3D
@export_group("Camera")
@export var sight_camera: Camera3D
@export var regular_camera: Camera3D

@export_group("Projectile")
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 25
@export var projectile_type: int = 0
@export var spawn_shell: Marker3D
@export_group("Stats")
@export var max_health: int = 100

var aim: TextureRect
var sightaim: TextureRect
var crosshair: TextureRect
@onready var canvas_layer: CanvasLayer = $TankUI
@export_group("UI")
@export var zoom_label: Label
@export var reload_label: Label

@onready var SHELL = load("res://game/projectiles/shell.tscn")


@export_group("Gun")
@export var shoot_force: float = 100.0
@export var recoil_force: float = 200.0 # Сила отдачи, применяется к корпусу танка при выстреле (в единицах импульса)
@export var turret_rotation_speed: float = 30.0 # Скорость поворота башни в градусах/сек
@export var barrel_pitch_speed: float = 10.0    # Скорость подъема ствола в градусах/сек
@export var max_barrel_angle_up: float = 15.0
@export var max_barrel_angle_down: float = -5.0
@export var reload_time: float = 1.5 # Время перезарядки (сек)
@export_group("Movement")
@export var engine_force_value: float = 15000.0
@export var turn_force_value: float = 12000.0
@export var brake_force_value: float = 400.0

@export_group("Camera")
@export var camera_sensitivity: float = 0.003
@export var camera_pitch_limits: Vector2 = Vector2(-35.0, 25.0)
@export var camera_distance: float = 12.0
@export var camera_focus_height: float = 2.5
@export var camera_height_offset: float = 2.5
@export var aim_ray_length: float = 500.0
@export_group("Sight")
@export var sight_mouse_sensitivity: float = 0.004
@export var sight_yaw_range_deg: float = 30.0
@export var sight_pitch_up_deg: float = 45.0
@export var sight_pitch_down_deg: float = 45.0
@export var sight_invert_y: bool = false
@export var sight_invert_x: bool = false
@export var sight_turret_rotation_speed: float = 20.0
@export var sight_barrel_pitch_speed: float = 8.0

@export var show_zoom_label: bool = true
@export_group("Zoom")
@export var _zoom_label: Label = null
var _reload_label: Label = null
var _network_manager: Node = null
@export var camera_min_distance: float = 6.0
@export var camera_max_distance: float = 20.0
@export var camera_zoom_step: float = 1.0
@export var sight_min_fov: float = 10.0
@export var sight_max_fov: float = 90.0
@export var sight_fov_step: float = 2.0


var dots:GPUParticles3D
var smoke:GPUParticles3D
var fire:GPUParticles3D

var exposive
var _camera_yaw: float = 0.0
var _camera_pitch: float = deg_to_rad(10.0)
var _aim_target_world: Vector3 = Vector3.ZERO
var sight_offset_yaw: float = 0.0
var sight_offset_pitch: float = 0.0
var sight_camera_yaw: float = 0.0
var sight_camera_pitch: float = 0.0
var sight_camera_base_yaw: float = 0.0
var health: int = 0

# Перезарядка
var _is_reloading: bool = false

func _init_sight_camera_orientation() -> void:
	if sight_camera == null:
		return
	var dir = -sight_camera.global_transform.basis.z
	sight_camera_yaw = atan2(dir.x, -dir.z)
	var flat = max(0.001, sqrt(dir.x * dir.x + dir.z * dir.z))
	sight_camera_pitch = atan2(dir.y, flat)
	sight_camera_base_yaw = rotation.y


func _ensure_zoom_label() -> void:
	if _zoom_label or not show_zoom_label:
		return
	if zoom_label:
		_zoom_label = zoom_label
	elif canvas_layer:
		_zoom_label = canvas_layer.get_node_or_null("ZoomLabel") as Label
	if _zoom_label == null:
		_create_zoom_label()


func _ensure_reload_label() -> void:
	if _reload_label:
		return
	if reload_label:
		_reload_label = reload_label
	elif canvas_layer:
		_reload_label = canvas_layer.get_node_or_null("ReloadLabel") as Label
	if _reload_label == null:
		_create_reload_label()


func _configure_remote_view() -> void:
	if aim:
		aim.hide()
	if sightaim:
		sightaim.hide()
	if crosshair:
		crosshair.hide()
	if sight_camera:
		sight_camera.current = false
	if regular_camera:
		regular_camera.current = false


func _configure_local_view() -> void:
	_ensure_zoom_label()
	if regular_camera:
		regular_camera.make_current()
	elif sight_camera:
		sight_camera.make_current()


func _ready() -> void:
	_resolve_required_nodes()
	# Проверяем что turret и barrel найдены
	if turret == null:
		push_error("[Tank] turret не найден по пути $body/turret!")
		return
	if barrel == null:
		push_error("[Tank] barrel не найден по пути $body/turret/barrel!")
		return
	if spawn_shell == null:
		push_error("[Tank] spawn_shell не найден!")
		return
	
	# Базовые значения для свободной камеры
	_camera_yaw = rotation.y
	_camera_pitch = clamp(_camera_pitch, deg_to_rad(camera_pitch_limits.x), deg_to_rad(camera_pitch_limits.y))
	_update_camera_transform()
	_init_sight_camera_orientation()

	# Initialize health for everyone
	health = max_health

	# If this tank is not owned by this peer, disable input/UI and cameras.
	if not _is_locally_controlled():
		_configure_remote_view()
	else:
		_configure_local_view()


func _resolve_required_nodes() -> void:
	if body == null and has_node("body"):
		body = $body
	if turret == null:
		if body and body.has_node("turret"):
			turret = body.get_node("turret") as Node3D
		elif has_node("body/turret"):
			turret = get_node("body/turret") as Node3D
	if barrel == null:
		if turret and turret.has_node("barrel"):
			barrel = turret.get_node("barrel") as Node3D
		elif has_node("body/turret/barrel"):
			barrel = get_node("body/turret/barrel") as Node3D
	if spawn_shell == null and barrel:
		for rel_path in ["kazna/gun/spawn shell", "gun/spawn shell", "spawn shell"]:
			if barrel.has_node(rel_path):
				spawn_shell = barrel.get_node(rel_path) as Marker3D
				break
	if muzzle_audio == null and barrel:
		for rel_path in ["kazna/MuzzleAudio", "MuzzleAudio"]:
			if barrel.has_node(rel_path):
				muzzle_audio = barrel.get_node(rel_path) as AudioStreamPlayer3D
				break
	
	if barrel:
		for rel_path in ["kazna/Explosion", "Explosion"]:
			if barrel.has_node(rel_path):
				explosion_root = barrel.get_node(rel_path) as Node3D
				break
	if explosion_root:
		if explosion_root.has_node("dots"):
			dots = explosion_root.get_node("dots") as GPUParticles3D
		if explosion_root.has_node("smoke"):
			smoke = explosion_root.get_node("smoke") as GPUParticles3D
		if explosion_root.has_node("fire"):
			fire = explosion_root.get_node("fire") as GPUParticles3D
		if explosion_root.has_node("exposive"):
			exposive = explosion_root.get_node("exposive") as AudioStreamPlayer3D
	if sight_camera == null and has_node("body/turret/barrel/SightCamera"):
		sight_camera = get_node("body/turret/barrel/SightCamera") as Camera3D
	if regular_camera == null and has_node("body/turret/barrel/RegularCamera"):
		regular_camera = get_node("body/turret/barrel/RegularCamera") as Camera3D
	# UI nodes from CanvasLayer (prefer scene-assigned nodes)
	if canvas_layer == null and has_node("CanvasLayer"):
		canvas_layer = get_node("CanvasLayer") as CanvasLayer
	if canvas_layer:
		if aim == null and canvas_layer.has_node("aim"):
			aim = canvas_layer.get_node("aim") as TextureRect
		if sightaim == null and canvas_layer.has_node("sightaim"):
			sightaim = canvas_layer.get_node("sightaim") as TextureRect
		if crosshair == null and canvas_layer.has_node("crosshair"):
			crosshair = canvas_layer.get_node("crosshair") as TextureRect
		# If author placed a ZoomLabel in CanvasLayer, use it
		if zoom_label == null and canvas_layer.has_node("ZoomLabel"):
			zoom_label = canvas_layer.get_node("ZoomLabel") as Label
		# If author placed a ReloadLabel in CanvasLayer, use it
		if reload_label == null and canvas_layer.has_node("ReloadLabel"):
			reload_label = canvas_layer.get_node("ReloadLabel") as Label


func _unhandled_input(event: InputEvent) -> void:
	# Only the local owner should process input events
	if not _is_locally_controlled():
		return

	if event is InputEventMouseMotion:
		if sight_camera and sight_camera.is_current():
			_rotate_sight(event.relative)
		else:
			_rotate_camera(event.relative)
	elif event.is_action_pressed("aim"):
		toggle_camera()
	elif event is InputEventMouseButton:
		# Mouse wheel (index 4/5) to zoom in/out
		if event.pressed:
			if event.button_index == 4:
				_zoom_wheel(true)
			elif event.button_index == 5:
				_zoom_wheel(false)


func _rotate_camera(relative: Vector2) -> void:
	if regular_camera == null:
		return
	_camera_yaw += relative.x * camera_sensitivity
	_camera_pitch -= relative.y * camera_sensitivity
	_camera_pitch = clamp(_camera_pitch, deg_to_rad(camera_pitch_limits.x), deg_to_rad(camera_pitch_limits.y))
	_update_camera_transform()


func _rotate_sight(relative: Vector2) -> void:
	if sight_camera == null:
		return
	# update internal sight camera yaw/pitch and apply to camera transform
	if sight_invert_x:
		sight_camera_yaw -= relative.x * sight_mouse_sensitivity
	else:
		sight_camera_yaw += relative.x * sight_mouse_sensitivity
	if sight_invert_y:
		sight_camera_pitch += relative.y * sight_mouse_sensitivity
	else:
		sight_camera_pitch -= relative.y * sight_mouse_sensitivity
	var min_yaw = sight_camera_base_yaw - deg_to_rad(sight_yaw_range_deg)
	var max_yaw = sight_camera_base_yaw + deg_to_rad(sight_yaw_range_deg)
	sight_camera_yaw = clamp(sight_camera_yaw, min_yaw, max_yaw)
	sight_camera_pitch = clamp(sight_camera_pitch, deg_to_rad(-sight_pitch_down_deg), deg_to_rad(sight_pitch_up_deg))
	# apply orientation to sight camera (rotate around its origin)
	var origin = sight_camera.global_transform.origin
	var cos_p = cos(sight_camera_pitch)
	var dir = Vector3(sin(sight_camera_yaw) * cos_p, sin(sight_camera_pitch), -cos(sight_camera_yaw) * cos_p).normalized()
	sight_camera.look_at(origin + dir, Vector3.UP)
	# update aim based on new orientation
	_update_aim_target_from_camera(sight_camera)
	# keep regular camera oriented to match sight camera so they don't mismatch
	if regular_camera != null:
		# compute equivalent yaw/pitch for regular camera and apply
		var reg_yaw = atan2(dir.x, -dir.z)
		var reg_flat = max(0.001, sqrt(dir.x * dir.x + dir.z * dir.z))
		var reg_pitch = atan2(dir.y, reg_flat)
		_camera_yaw = reg_yaw
		_camera_pitch = clamp(reg_pitch, deg_to_rad(camera_pitch_limits.x), deg_to_rad(camera_pitch_limits.y))
		_update_camera_transform()


func _get_camera_direction() -> Vector3:
	return _get_direction_from_camera(regular_camera)


func _get_direction_from_camera(camera: Camera3D) -> Vector3:
	if camera == null:
		# fallback to tank-forward
		return -global_transform.basis.z
	if camera == regular_camera:
		var yaw_basis = _camera_yaw
		var pitch_basis = _camera_pitch
		if regular_camera == null:
			yaw_basis = rotation.y
			pitch_basis = 0.0
		var cos_pitch = cos(pitch_basis)
		return Vector3(
			sin(yaw_basis) * cos_pitch,
			sin(pitch_basis),
			-cos(yaw_basis) * cos_pitch
		).normalized()
	# sight camera: use its own forward vector plus offsets
	# sight camera: just use its forward vector (we rotate camera directly in sight mode)
	return (-camera.global_transform.basis.z).normalized()


func _update_camera_transform() -> void:
	if regular_camera:
		var focus_point = global_transform.origin + Vector3(0, camera_focus_height, 0)
		var direction = _get_camera_direction()
		var camera_pos = focus_point - direction * camera_distance + Vector3(0, camera_height_offset, 0)
		regular_camera.global_transform.origin = camera_pos
		regular_camera.look_at(camera_pos + direction, Vector3.UP)
		# keep sight camera oriented to match regular camera while in regular mode
		if sight_camera != null and regular_camera.is_current():
			var reg_dir = _get_direction_from_camera(regular_camera)
			var sight_origin = sight_camera.global_transform.origin
			sight_camera.look_at(sight_origin + reg_dir, Vector3.UP)
			# update sight camera yaw/pitch state so when switching to sight, orientation matches
			var dir := -sight_camera.global_transform.basis.z
			sight_camera_yaw = atan2(dir.x, -dir.z)
			var flat = max(0.001, sqrt(dir.x * dir.x + dir.z * dir.z))
			sight_camera_pitch = atan2(dir.y, flat)
			sight_camera_base_yaw = rotation.y
	_update_aim_target_from_camera(_get_active_camera())
	_update_zoom_label()


func _create_zoom_label() -> void:
	if canvas_layer == null:
		return
	_zoom_label = Label.new()
	_zoom_label.name = "ZoomLabel"
	_zoom_label.text = ""
	_zoom_label.visible = false
		# style and position: top-center
	_zoom_label.anchor_left = 0.5
	_zoom_label.anchor_right = 0.5
	_zoom_label.anchor_top = 0.0
	_zoom_label.anchor_bottom = 0.0
	_zoom_label.position = Vector2(0, 8)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas_layer.add_child(_zoom_label)
	_update_zoom_label()

func _create_reload_label() -> void:
	if canvas_layer == null:
		return
	_reload_label = Label.new()
	_reload_label.name = "ReloadLabel"
	_reload_label.text = ""
	_reload_label.visible = false
	# top-center by default (small offset below top)
	_reload_label.anchor_left = 0.5
	_reload_label.anchor_right = 0.5
	_reload_label.anchor_top = 0.0
	_reload_label.anchor_bottom = 0.0
	_reload_label.position = Vector2(0, 28)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas_layer.add_child(_reload_label)


func _update_zoom_label() -> void:
	var label_node: Label = zoom_label if zoom_label != null else _zoom_label
	if label_node == null:
		return
	if not _is_locally_controlled():
		label_node.visible = false
		return
	var active = _get_active_camera()
	if active == sight_camera:
		var base_fov = regular_camera.fov if regular_camera else 70.0
		var mult = base_fov / max(0.001, sight_camera.fov)
		label_node.text = "Zoom: %.1fx" % [mult]
		label_node.visible = true
	else:
		label_node.visible = false


func _zoom_wheel(zoom_in: bool) -> void:
	# Zoom regular camera by changing distance
	if regular_camera and regular_camera.is_current():
		if zoom_in:
			camera_distance = max(camera_min_distance, camera_distance - camera_zoom_step)
		else:
			camera_distance = min(camera_max_distance, camera_distance + camera_zoom_step)
		_update_camera_transform()
		return

	# Zoom sight camera by changing FOV
	if sight_camera and sight_camera.is_current():
		var current_fov = sight_camera.fov
		if zoom_in:
			current_fov = max(sight_min_fov, current_fov - sight_fov_step)
		else:
			current_fov = min(sight_max_fov, current_fov + sight_fov_step)
		sight_camera.fov = current_fov
		# update aim after changing view
		_update_aim_target_from_camera(sight_camera)
		return


func _get_active_camera() -> Camera3D:
	if sight_camera and sight_camera.is_current():
		return sight_camera
	return regular_camera


func _update_aim_target_from_camera(camera: Camera3D) -> void:
	if camera == null:
		return
	var ray_origin: Vector3
	var ray_direction: Vector3
	if camera == sight_camera:
		ray_origin = camera.global_transform.origin
		ray_direction = _get_direction_from_camera(camera)
	else:
		var camera_transform = camera.global_transform
		ray_origin = camera_transform.origin
		ray_direction = -camera_transform.basis.z
		if ray_direction.length_squared() == 0.0:
			ray_direction = -Vector3.FORWARD
	ray_direction = ray_direction.normalized()
	_aim_target_world = _cast_camera_ray(ray_origin, ray_direction)


func _cast_camera_ray(origin: Vector3, direction: Vector3) -> Vector3:
	var world := get_world_3d()
	if world == null:
		return origin + direction * aim_ray_length
	var space_state := world.direct_space_state
	if space_state == null:
		return origin + direction * aim_ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * aim_ray_length)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"]
	return origin + direction * aim_ray_length


func _update_turret_tracking(delta: float) -> void:
	if turret == null or barrel == null:
		return
	var turret_origin = turret.global_transform.origin
	# If sight camera is active, follow its forward direction (with sight offsets)
	# but still apply smoothing (we compute a far target point along that direction).
	var active_cam = _get_active_camera()
	var direction_world: Vector3
	if active_cam == sight_camera and sight_camera != null:
		# Use the sight camera direction (already accounts for sight offsets)
		direction_world = _get_direction_from_camera(sight_camera)
	else:
		# Use the ray-cast target if available, otherwise fall back to regular camera direction
		var target_vector = _aim_target_world - turret_origin
		if target_vector.length_squared() < 0.0001:
			target_vector = _get_camera_direction()
		direction_world = target_vector.normalized()
	var reference_basis: Basis
	if body:
		reference_basis = body.global_transform.basis
	else:
		reference_basis = global_transform.basis
	var local_dir = (reference_basis.inverse() * direction_world).normalized()
	if local_dir.length() < 0.001:
		return
	var desired_yaw = atan2(local_dir.x, local_dir.z)
	var flat_len = max(0.001, Vector2(local_dir.x, local_dir.z).length())
	var desired_pitch = atan2(-local_dir.y, flat_len)
	var yaw_speed = turret_rotation_speed
	var pitch_speed = barrel_pitch_speed
	if active_cam == sight_camera:
		yaw_speed = sight_turret_rotation_speed
		pitch_speed = sight_barrel_pitch_speed
	# move turret yaw at a constant angular speed toward desired_yaw
	var current_yaw = turret.rotation.y
	var diff_yaw = _wrap_angle(desired_yaw - current_yaw)
	var max_yaw_step = deg_to_rad(yaw_speed) * delta
	var yaw_delta = clamp(diff_yaw, -max_yaw_step, max_yaw_step)
	turret.rotation.y = current_yaw + yaw_delta
	# move barrel pitch at constant angular speed toward clamped desired pitch
	var pitch_min = deg_to_rad(max_barrel_angle_down)
	var pitch_max = deg_to_rad(max_barrel_angle_up)
	var clamped_pitch = clamp(desired_pitch, pitch_min, pitch_max)
	var current_pitch = barrel.rotation.x
	var diff_pitch = clamped_pitch - current_pitch
	var max_pitch_step = deg_to_rad(pitch_speed) * delta
	var pitch_delta = clamp(diff_pitch, -max_pitch_step, max_pitch_step)
	barrel.rotation.x = clamp(current_pitch + pitch_delta, pitch_min, pitch_max)


func play_muzzle_fx():
	if dots:
		dots.restart()
		dots.emitting = true
	if smoke:
		smoke.restart()
		smoke.emitting = true
	if fire:
		fire.restart()
		fire.emitting = true
	if exposive:
		exposive.stop()
		exposive.play()
	if muzzle_audio:
		muzzle_audio.stop()
		muzzle_audio.play()


# Reload helpers
func is_reloading() -> bool:
	return _is_reloading

func _start_reload() -> void:
	# Non-blocking reload with visible countdown for local owner
	if reload_time <= 0.0:
		return
	if _is_reloading:
		return
	_is_reloading = true

	_ensure_reload_label()

	# Non-owners should not show the countdown but we still honor reload time
	if not _is_locally_controlled():
		await get_tree().create_timer(reload_time).timeout
		_is_reloading = false
		return

	# Show countdown and update every 0.1s
	if _reload_label:
		_reload_label.visible = true
	var remaining := reload_time
	var step := 0.1
	while remaining > 0.0:
		if _reload_label:
			_reload_label.text = "Reload: %.1fs" % [max(0.0, remaining)]
			# yield a small step
			await get_tree().create_timer(step).timeout
			remaining -= step
		else:
			# if no label, just wait the full duration
			await get_tree().create_timer(remaining).timeout
			break

	if _reload_label:
		_reload_label.visible = false
		_reload_label.text = ""
	_is_reloading = false

# Helper to normalize angle difference into [-PI, PI]
func _wrap_angle(x: float) -> float:
	var two_pi = PI * 2.0
	var y = fmod(x + PI, two_pi)
	if y < 0.0:
		y += two_pi
	return y - PI


func _set_model_visible(visible: bool) -> void:
	# Recursively toggle visibility of all VisualInstance3D under the body node
	if body == null:
		return
	_recursive_set_visible(body, visible)


func _recursive_set_visible(node: Node, visible: bool) -> void:
	if node is VisualInstance3D:
		node.visible = visible
	for child in node.get_children():
		if child is Node:
			_recursive_set_visible(child, visible)


func explosion():
	play_muzzle_fx()


func toggle_camera() -> void:
	if regular_camera == null or sight_camera == null:
		return
	if regular_camera.is_current():
		sight_camera.make_current()
		if sightaim:
			sightaim.show()
		# reset sight offsets when entering sight mode
		sight_offset_yaw = 0.0
		sight_offset_pitch = 0.0
		# initialize sight base yaw for limited free rotation relative to hull
		_init_sight_camera_orientation()
		# hide local model for sight view on the owning client
		if _is_locally_controlled():
			_set_model_visible(false)
	else:
		if sightaim:
			sightaim.hide()
		regular_camera.make_current()
		if _is_locally_controlled():
			_set_model_visible(true)



func _physics_process(delta: float) -> void:
	if not _is_locally_controlled():
		return

	_update_camera_transform()
	_update_turret_tracking(delta)

	var forward_pressed := Input.is_action_pressed("w")
	var backward_pressed := Input.is_action_pressed("s")
	var left_pressed := Input.is_action_pressed("a")
	var right_pressed := Input.is_action_pressed("d")

	var left_force := 0.0
	var right_force := 0.0

	if forward_pressed:
		left_force += engine_force_value
		right_force += engine_force_value
	if backward_pressed:
		left_force -= engine_force_value
		right_force -= engine_force_value
	if left_pressed:
		right_force += engine_force_value
	if right_pressed:
		left_force += engine_force_value

	var turning := left_pressed != right_pressed
	if turning:
		var turning_left := left_pressed
		if forward_pressed or backward_pressed:
			if turning_left:
				left_force -= turn_force_value
				right_force += turn_force_value
			else:
				left_force += turn_force_value
				right_force -= turn_force_value
		else:
			if turning_left:
				left_force = -turn_force_value
				right_force = turn_force_value
			else:
				left_force = turn_force_value
				right_force = -turn_force_value

	left.engine_force = left_force
	right.engine_force = right_force

	var should_brake := not (forward_pressed or backward_pressed or left_pressed or right_pressed)
	left.brake = brake_force_value if should_brake else 0.0
	right.brake = brake_force_value if should_brake else 0.0
	
	if Input.is_action_just_pressed("shot"):
		# Block firing while reloading
		if _is_reloading:
			# TODO: play 'empty' click or UI hint
			return
		# Only the owner triggers firing: request server to spawn authoritative projectile
		var scene_path := projectile_scene.resource_path if projectile_scene and projectile_scene.resource_path != "" else "res://game/projectiles/shell.tscn"
		# compute spawn transform and firing direction (forward from spawn marker)
		var spawn_xform = spawn_shell.global_transform
		var direction = spawn_xform.basis.y
		var network_manager := NetworkManager
		if network_manager:
			var server_id = network_manager.get_server_id()
			network_manager.rpc_id(server_id, "server_spawn_projectile", scene_path, get_tree().get_multiplayer().get_unique_id(), spawn_xform, projectile_type, shoot_force, projectile_damage)
			# immediate local feedback: muzzle fx + recoil; server will spawn authoritative projectile
			play_muzzle_fx()
			_apply_recoil(direction)
			_start_reload()
		else:
			# fallback: spawn locally for singleplayer/testing
			play_muzzle_fx()
			var ammo = SHELL.instantiate()
			get_tree().root.add_child(ammo)
			ammo.global_transform = spawn_shell.global_transform
			ammo._set_speed(direction * shoot_force)
			# apply recoil locally and start reload after local spawn
			_apply_recoil(direction)
			_start_reload()


func _is_locally_controlled() -> bool:
	# Determine if this node is controlled by this peer
	var mp = get_tree().get_multiplayer()
	var my_id = mp.get_unique_id()
	# try modern API
	if has_method("get_multiplayer_authority"):
		# prefer direct call to avoid stringly-typed call()
		var auth = int(get_multiplayer_authority())
		# debug helper (can be removed later)
		#print("[Tank] my_id=", my_id, " auth=", auth)
		return auth == int(my_id)
	# fallback to older API if present
	if has_method("get_network_master"):
		return int(get_multiplayer_authority()) == int(my_id)
	# if no networking API available, treat as local-controlled (singleplayer)
	return true


func _apply_recoil(direction: Vector3) -> void:
	# Apply impulse opposite to firing direction for recoil feedback.
	# Uses `recoil_force` (exported) as impulse magnitude.
	if direction == Vector3.ZERO:
		return
	var impulse = -direction.normalized() * recoil_force
	# apply_impulse is available on RigidBody-derived nodes (VehicleBody3D inherits physical body behavior)
	# Apply at center (offset = Vector3.ZERO)
	apply_central_impulse(impulse)

@rpc("call_local")
func rpc_apply_damage(amount: int, from_id: int) -> void:
	# Apply damage locally (called by server broadcast)
	health -= int(amount)
	if health <= 0:
		print("[Tank] destroyed")
		explosion()
		queue_free()
