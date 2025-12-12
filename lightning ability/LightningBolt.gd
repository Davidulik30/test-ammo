extends Node3D

## Менеджер эффекта молнии - готовый ассет для использования в других проектах
## 
## Использование:
##   var lightning = load("res://lightning ability/Lightning.tscn").instantiate()
##   add_child(lightning)
##   lightning.strike(Vector3(0, 0, 0), Vector3(10, 0, 0))
##
## Или через редактор:
##   1. Добавьте сцену Lightning.tscn в вашу игровую сцену
##   2. Привяжите этот скрипт к корневому узлу
##   3. Вызовите функции strike() или update_positions() из кода

class_name LightningBolt

## Ссылка на LineGenerator для управления меш-генератором
@onready var line_generator: LineGenerator = $LineGenerator if has_node("LineGenerator") else null

## Автоматический спавн молнии при загрузке (для демонстрации)
@export var auto_spawn: bool = false

## Начальная позиция молнии для auto_spawn
@export var start_position: Vector3 = Vector3.ZERO

## Конечная позиция молнии для auto_spawn
@export var end_position: Vector3 = Vector3(10, 0, 0)

## Анимировать wave_count при ударе молнии
@export var animate_wave_on_strike: bool = true

## Постоянно пульсировать wave_count (1->10->1 в цикле)
@export var continuous_wave_pulse: bool = true

## Скорость пульсирования wave_count (циклы в секунду)
@export var pulse_speed: float = 2.0

var _animation_tween: Tween = null
var _continuous_pulse_tween: Tween = null

func _ready() -> void:
	if auto_spawn and line_generator:
		strike(start_position, end_position)
	
	# Стартуем постоянное пульсирование wave_count
	if continuous_wave_pulse and line_generator:
		_start_continuous_pulse()

## Вызвать молнию между двумя точками
## @param from_pos: начальная позиция молнии
## @param to_pos: конечная позиция молнии
func strike(from_pos: Vector3, to_pos: Vector3) -> void:
	if not line_generator:
		push_error("LineGenerator not found! Make sure Lightning.tscn is properly set up.")
		return
	
	# Устанавливаем позиции в координатной системе LineGenerator
	line_generator.point_a = from_pos - global_position
	line_generator.point_b = to_pos - global_position
	
	# Убиваем старую анимацию если она есть
	if _animation_tween:
		_animation_tween.kill()
	
	# Анимируем wave_count от 1 до 10 и обратно к текущему значению
	if animate_wave_on_strike:
		var current_wave_count = line_generator.wave_count
		
		# Твин для волны: 1 -> 10 -> текущее значение за 0.6 секунд
		_animation_tween = create_tween()
		_animation_tween.set_trans(Tween.TRANS_QUAD)
		_animation_tween.set_ease(Tween.EASE_IN_OUT)
		
		# Первая фаза: 1 до 10
		_animation_tween.tween_method(
			func(value: float) -> void:
				line_generator.wave_count = roundi(value)
				line_generator.update_mesh_display(),
			1.0, 10.0, 0.3
		)
		
		# Вторая фаза: 10 до текущего значения
		_animation_tween.tween_method(
			func(value: float) -> void:
				line_generator.wave_count = roundi(value)
				line_generator.update_mesh_display(),
			10.0, float(current_wave_count), 0.3
		)
	else:
		# Без анимации просто обновляем меш
		line_generator.update_mesh_display()
	
	print("[LightningBolt] Молния вызвана от ", from_pos, " к ", to_pos)

## Обновить позиции молнии (если молния уже создана)
## @param from_pos: новая начальная позиция
## @param to_pos: новая конечная позиция
func update_positions(from_pos: Vector3, to_pos: Vector3) -> void:
	strike(from_pos, to_pos)

## Установить ширину молнии
## @param width: толщина линии молнии
func set_width(width: float) -> void:
	if line_generator:
		line_generator.width = width
		line_generator.update_mesh_display()

## Установить цвет молнии
## @param color: цвет молнии
func set_color(color: Color) -> void:
	if line_generator:
		line_generator.color = color
		line_generator.update_mesh_display()

## Установить количество волн/извилистости
## @param waves: количество волн
func set_wave_count(waves: int) -> void:
	if line_generator:
		line_generator.wave_count = waves
		line_generator.update_mesh_display()

## Установить амплитуду волн
## @param amplitude: амплитуда отклонения
func set_wave_amplitude(amplitude: float) -> void:
	if line_generator:
		line_generator.wave_amplitude = amplitude
		line_generator.update_mesh_display()

## Установить количество сегментов (плавность)
## @param segs: количество сегментов
func set_segments(segs: int) -> void:
	if line_generator:
		line_generator.segments = segs
		line_generator.update_mesh_display()

## Получить текущую начальную позицию молнии
func get_start_position() -> Vector3:
	if line_generator:
		return line_generator.point_a + global_position
	return global_position

## Получить текущую конечную позицию молнии
func get_end_position() -> Vector3:
	if line_generator:
		return line_generator.point_b + global_position
	return global_position

## Показать/скрыть молнию
## @param should_display: видимость молнии
func set_bolt_visible(should_display: bool) -> void:
	var mesh_instance = find_child("MeshInstance3D", false, false)
	if mesh_instance:
		mesh_instance.visible = should_display

## Приватная функция для запуска постоянного пульсирования wave_count
func _start_continuous_pulse() -> void:
	if not line_generator:
		return
	
	# Убиваем старый твин если он был
	if _continuous_pulse_tween:
		_continuous_pulse_tween.kill()
	
	# Создаём бесконечный твин
	_continuous_pulse_tween = create_tween()
	_continuous_pulse_tween.set_loops()  # Бесконечный цикл
	_continuous_pulse_tween.set_trans(Tween.TRANS_SINE)
	_continuous_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Фаза 1: от 1 до 10
	_continuous_pulse_tween.tween_method(
		func(value: float) -> void:
			if line_generator:
				line_generator.wave_count = roundi(value)
				line_generator.update_mesh_display(),
		1.0, 10.0, 1.0 / pulse_speed
	)
	
	# Фаза 2: от 10 до 1
	_continuous_pulse_tween.tween_method(
		func(value: float) -> void:
			if line_generator:
				line_generator.wave_count = roundi(value)
				line_generator.update_mesh_display(),
		10.0, 1.0, 1.0 / pulse_speed
	)
