extends VehicleBody3D

# Экспортируемые переменные появятся в инспекторе,
# что позволит вам настраивать их без изменения кода.
@export var engine_power = 100.0
@export var steer_angle = 0.4
@export var brake_force = 15.0

func _physics_process(delta):
	# Получаем ввод от пользователя
	var vertical_input = Input.get_axis("ui_down", "ui_up")
	var horizontal_input = -Input.get_axis("ui_left", "ui_right")

	# Устанавливаем силу двигателя и тормоза
	if Input.is_action_pressed("ui_up"):
		engine_force = engine_power
		brake = 0.0
	elif Input.is_action_pressed("ui_down"):
		# Можно реализовать задний ход или торможение
		# В данном случае, мы используем торможение
		engine_force = -engine_power
		brake = brake_force
	else:
		engine_force = 0.0
		# Можно добавить постепенное замедление, если не нажата ни одна клавиша
		brake = brake_force / 4

	# Устанавливаем угол поворота
	steering = horizontal_input * steer_angle
