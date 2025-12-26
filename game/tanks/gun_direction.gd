extends SpringArm3D

var sight_ray = self
@export var aim: TextureRect
@export var sightaim: TextureRect
@export var crosshair: TextureRect
@export var marker_3d: Marker3D



@export var hide_ui: bool = false


func _ready() -> void:
	if not is_multiplayer_authority():
		# Если это чужой игрок (кукла), то его интерфейс нам не нужен.
		# Самый правильный способ - полностью удалить его CanvasLayer,
		# чтобы он не тратил ресурсы.
		queue_free()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _process(delta: float) -> void:
	if hide_ui:
		# hide UI elements when requested
		if is_instance_valid(aim):
			aim.visible = false
		if is_instance_valid(crosshair):
			crosshair.visible = false
		return
	_update_aim_position()
	_update_crosshair_to_mouse_position()

func _update_crosshair_to_mouse_position() -> void:
	# Получаем текущую позицию мыши в окне игры
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Устанавливаем позицию нашего 2D-прицела.
	# Вычитаем половину его размера, чтобы центр прицела был в точке курсора.
	if is_instance_valid(crosshair):
		crosshair.position = mouse_pos - crosshair.size / 2.0
	
func _update_aim_position() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return

	# Глобальная позиция маркера - это наша универсальная 3D-цель.
	# Она работает и при столкновении, и при стрельбе в пустоту.
	var target_point_3d: Vector3 = marker_3d.global_position

	# Прячем прицел, если точка цели оказалась за камерой.
	# Это предотвращает его появление в странных местах при взгляде в землю под собой.
	if camera.is_position_behind(target_point_3d):
		aim.visible = false
		return
	else:
		# В остальных случаях прицел должен быть видим.
		aim.visible = true

	# Проецируем 3D-точку (точку столкновения или дальнюю точку) в 2D-координату
	var screen_pos: Vector2 = camera.unproject_position(target_point_3d)

	# Устанавливаем позицию прицела
	aim.position = screen_pos - aim.size / 2.0
