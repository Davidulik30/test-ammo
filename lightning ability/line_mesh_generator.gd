@tool
extends Node3D

## Скрипт для генерации меша линии между двумя точками
## Использование: 
##   var line = LineGenerator.new()
##   line.point_a = Vector3(0, 0, 0)
##   line.point_b = Vector3(10, 0, 0)
##   line.width = 0.5
##   line.color = Color.WHITE
##   var mesh = line.generate_mesh()

class_name LineGenerator

## Точка начала линии
@export var point_a: Vector3 = Vector3.ZERO

## Точка конца линии
@export var point_b: Vector3 = Vector3.ZERO

## Толщина линии
@export var width: float = 0.5

## Цвет линии
@export var color: Color = Color.WHITE

## Количество сегментов для сглаживания (если нужно)
@export var segments: int = 1

## Количество изгибов (извилистость линии) - от 1 до 10 волн
@export var wave_count: int = 1

## Амплитуда изгибов (максимальное отклонение от прямой)
@export var wave_amplitude: float = 0.5

## Материал для меша (если не указан, создается автоматически)
@export var mesh_material: Material = null

## Использовать шейдер молнии
@export var use_lightning_shader: bool = false

var _last_point_a: Vector3 = Vector3.ZERO
var _last_point_b: Vector3 = Vector3.ZERO
var _last_width: float = 0.5
var _last_color: Color = Color.WHITE
var _last_segments: int = 1
var _last_wave_count: int = 1
var _last_wave_amplitude: float = 0.5

func _ready() -> void:
	# Генерируем меш при загрузке (для редактора и игры)
	update_mesh_display()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	
	# Ограничиваем wave_count между 1 и 10
	wave_count = clampi(wave_count, 1, 10)
	
	# Проверяем изменились ли параметры (только в редакторе)
	if (_last_point_a != point_a or _last_point_b != point_b or 
		_last_width != width or _last_color != color or _last_segments != segments or
		_last_wave_count != wave_count or _last_wave_amplitude != wave_amplitude):
		_last_point_a = point_a
		_last_point_b = point_b
		_last_width = width
		_last_color = color
		_last_segments = segments
		_last_wave_count = wave_count
		_last_wave_amplitude = wave_amplitude
		update_mesh_display()

func update_mesh_display() -> void:
	# Ищем существующий MeshInstance3D или создаем новый
	var mesh_instance = find_child("MeshInstance3D", false, false) as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)
		if Engine.is_editor_hint():
			mesh_instance.owner = get_tree().edited_scene_root
	
	# Обновляем меш
	mesh_instance.mesh = generate_mesh()
	
	# Применяем материал
	var material = mesh_material
	if use_lightning_shader and material == null:
		# Загружаем шейдер молнии если не указан материал
		material = load("res://lightning ability/lightning_material.tres")
	
	if material:
		mesh_instance.set_surface_override_material(0, material)

## Генерирует меш линии от точки A к точке B
func generate_mesh() -> Mesh:
	var surface_tool = SurfaceTool.new()
	
	# Направление линии
	var direction = (point_b - point_a).normalized()
	
	# Перпендикулярные направления для создания ширины линии
	var up = Vector3.UP
	if abs(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	
	var right = direction.cross(up).normalized()
	var perpendicular = right.cross(direction).normalized()
	
	# Половина толщины
	var half_width = width * 0.5
	
	# Создание вертексов для квада
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Установка материала с цветом
	var material = mesh_material
	if material == null:
		material = StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface_tool.set_material(material)
	
	# Вертексы для каждого сегмента с изгибами
	for i in range(segments + 1):
		var t = float(i) / segments
		var pos = point_a.lerp(point_b, t)
		
		# Добавляем случайные изгибы
		if wave_count > 0:
			var wave_offset = sin(t * PI * wave_count) * wave_amplitude
			pos += perpendicular * wave_offset
		
		# Два вертекса для текущего положения (слева и справа)
		var v1 = pos + perpendicular * half_width
		var v2 = pos - perpendicular * half_width
		
		# Добавляем UV координаты
		surface_tool.set_uv(Vector2(t, 1.0))  # Верхний край
		surface_tool.add_vertex(v1)
		
		surface_tool.set_uv(Vector2(t, 0.0))  # Нижний край
		surface_tool.add_vertex(v2)
	
	# Создание треугольников
	for i in range(segments):
		var base = i * 2
		
		# Первый треугольник
		surface_tool.add_index(base)
		surface_tool.add_index(base + 2)
		surface_tool.add_index(base + 1)
		
		# Второй треугольник
		surface_tool.add_index(base + 1)
		surface_tool.add_index(base + 2)
		surface_tool.add_index(base + 3)
	
	surface_tool.generate_normals()
	return surface_tool.commit()


## Создает MeshInstance3D сразу с меш-коллайдером
func create_mesh_instance() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = generate_mesh()
	return mesh_instance


## Создает визуальную линию между двумя точками в сцене
static func draw_line_in_scene(from: Vector3, to: Vector3, line_width: float = 0.5, line_color: Color = Color.WHITE, parent: Node3D = null) -> MeshInstance3D:
	var generator = LineGenerator.new()
	generator.point_a = from
	generator.point_b = to
	generator.width = line_width
	generator.color = line_color
	generator.segments = 1
	
	var instance = generator.create_mesh_instance()
	
	if parent:
		parent.add_child(instance)
	
	return instance


## Обновляет существующий меш между новыми точками
func update_line(new_point_a: Vector3, new_point_b: Vector3) -> void:
	point_a = new_point_a
	point_b = new_point_b


## Альтернативный класс для линий с градиентом
class GradientLineGenerator:
	var point_a: Vector3 = Vector3.ZERO
	var point_b: Vector3 = Vector3.ZERO
	var width: float = 0.5
	var color_start: Color = Color.WHITE
	var color_end: Color = Color.BLACK
	var segments: int = 10
	
	func generate_mesh() -> Mesh:
		var surface_tool = SurfaceTool.new()
		
		var direction = (point_b - point_a).normalized()
		var up = Vector3.UP
		if abs(direction.dot(up)) > 0.99:
			up = Vector3.RIGHT
		
		var right = direction.cross(up).normalized()
		var perpendicular = right.cross(direction).normalized()
		var half_width = width * 0.5
		
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		surface_tool.set_material(material)
		
		# Создание вертексов с интерполяцией цвета
		for i in range(segments + 1):
			var t = float(i) / segments
			var pos = point_a.lerp(point_b, t)
			var color = color_start.lerp(color_end, t)
			
			var v1 = pos + perpendicular * half_width
			var v2 = pos - perpendicular * half_width
			
			surface_tool.set_color(color)
			surface_tool.add_vertex(v1)
			surface_tool.set_color(color)
			surface_tool.add_vertex(v2)
		
		# Создание треугольников
		for i in range(segments):
			var base = i * 2
			
			surface_tool.add_index(base)
			surface_tool.add_index(base + 2)
			surface_tool.add_index(base + 1)
			
			surface_tool.add_index(base + 1)
			surface_tool.add_index(base + 2)
			surface_tool.add_index(base + 3)
		
		surface_tool.generate_normals()
		return surface_tool.commit()
