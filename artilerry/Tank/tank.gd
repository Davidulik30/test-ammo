extends VehicleBody3D

@export var body: MeshInstance3D
@export var turret: MeshInstance3D
@export var barrel: MeshInstance3D

@onready var left: VehicleWheel3D = $left
@onready var right: VehicleWheel3D = $right
@export var spawn_shell: Marker3D

@export var dots: GPUParticles3D
@export var fire: GPUParticles3D
@export var smoke: GPUParticles3D
@export var exposive: AudioStreamPlayer3D

@export var sight_camera: Camera3D
@export var regular_camera: Camera3D

@export var projectile_scene: PackedScene
@export var projectile_damage: int = 25
@export var projectile_type: int = 0
@export var max_health: int = 100

@onready var aim: TextureRect = $CanvasLayer/aim
@onready var sightaim: TextureRect = $CanvasLayer/sightaim
@onready var crosshair: TextureRect = $CanvasLayer/crosshair

const SHELL = preload("uid://dqbf3y40evl66")

@export var shoot_force: float = 100.0
@export var turret_rotation_speed: float = 30.0 # Скорость поворота башни в градусах/сек
@export var barrel_pitch_speed: float = 10.0    # Скорость подъема ствола в градусах/сек
@export var max_barrel_angle_up: float = 15.0
@export var max_barrel_angle_down: float = -5.0
@export var engine_force_value: float = 200.0
@export var brake_force_value: float = 20.0
@export var steer_angle: float = 15.0

@export var mouse_sensitivity: float = 0.1

# Переменные для хранения целевых углов
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var health: int = 0


func _ready() -> void:
	# Устанавливаем начальные целевые углы равными текущим, чтобы избежать рывка при старте
	_target_yaw = turret.rotation_degrees.y
	_target_pitch = barrel.rotation_degrees.x

	# Initialize health for everyone
	health = max_health

	# If this tank is not owned by this peer, disable input/UI and cameras.
	if not _is_locally_controlled():
		# ensure UI elements don't receive input
		if aim:
			aim.hide()
		if sightaim:
			sightaim.hide()
		if crosshair:
			crosshair.hide()
		# disable cameras on non-owners (ensure they are not current)
		if sight_camera:
			sight_camera.current = false
		if regular_camera:
			regular_camera.current = false
	else:
		# Owner: ensure a camera is active for local control
		if sight_camera:
			# prefer regular camera by default
			regular_camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	# Only the local owner should process input events
	if not _is_locally_controlled():
		return

	if event is InputEventMouseMotion:
		# Движение мыши изменяет ЦЕЛЕВЫЕ углы, к которым башня будет стремиться.
		# Камеру мы не трогаем, она движется сама вместе с башней.
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_pitch += event.relative.y * mouse_sensitivity
		
		# Сразу ограничиваем целевой угол ствола
		_target_pitch = clamp(_target_pitch, max_barrel_angle_down, max_barrel_angle_up)
		crosshair.position = event.position
		
	if event.is_action_pressed("aim"):
		toggle_camera()

func toggle_camera() -> void:
	if regular_camera.is_current():
		sight_camera.make_current()
		sightaim.show()
	else:
		sightaim.hide()
		regular_camera.make_current()
		
func explosion():
	dots.emitting = true
	smoke.emitting = true
	fire.emitting = true 
	exposive.play()


func _physics_process(delta: float) -> void:
	# =========================
	#   ДВИЖЕНИЕ ТАНКА (не трогал)
	# =========================
	# Only process movement input on the owning peer
	if not _is_locally_controlled():
		return

	if Input.is_action_pressed("d"):
		left.engine_force = engine_force_value
	else:
		left.engine_force = 0
	if Input.is_action_pressed("a"):
		right.engine_force = engine_force_value
	else:
		right.engine_force = 0
	if Input.is_action_pressed("w"):
		engine_force = engine_force_value

	if Input.is_action_pressed("s"):
		engine_force = -engine_force_value

	turret.rotation_degrees.y = move_toward(
		turret.rotation_degrees.y,
		_target_yaw,
		turret_rotation_speed * delta
	)
	barrel.rotation_degrees.x = move_toward(
		barrel.rotation_degrees.x,
		_target_pitch,
		barrel_pitch_speed * delta
	)
	
	if Input.is_action_just_pressed("shot"):
		# Only the owner triggers firing: request server to spawn authoritative projectile
		var scene_path := ""
		if projectile_scene and projectile_scene.resource_path != "":
			scene_path = projectile_scene.resource_path
		else:
			# fallback to default shell path if not set
			scene_path = "res://artilerry/Shell/shell.tscn"
		# compute spawn transform and direction
		var spawn_xform = spawn_shell.global_transform
		var server_id = 1
		if Engine.get_main_loop().get_root().has_node("NetworkManager"):
			server_id = NetworkManager.get_server_id()
		# call NetworkManager on the server to spawn projectile
		if Engine.get_main_loop().get_root().has_node("NetworkManager"):
			print("[Tank] requesting server spawn projectile: %s" % scene_path)
			NetworkManager.rpc_id(server_id, "server_spawn_projectile", scene_path, get_tree().get_multiplayer().get_unique_id(), spawn_xform, projectile_type, shoot_force, projectile_damage)
		else:
			# fallback: spawn locally for singleplayer/testing
			explosion()
			var ammo = SHELL.instantiate()
			get_tree().root.add_child(ammo)
			ammo.global_transform = spawn_shell.global_transform
			var direction = spawn_shell.global_transform.basis.y
			ammo._set_speed(direction * shoot_force)
			


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


@rpc("call_local")
func rpc_apply_damage(amount: int, from_id: int) -> void:
	# Apply damage locally (called by server broadcast)
	print("[Tank] rpc_apply_damage: %d from %d" % [amount, from_id])
	health -= int(amount)
	if health <= 0:
		print("[Tank] destroyed")
		explosion()
		queue_free()
