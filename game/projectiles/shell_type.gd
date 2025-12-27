class_name ShellType
extends Resource

@export_group("Visuals")
@export var display_name: String = "Standard"
@export var icon: Texture2D # Иконка для UI

@export_group("Stats")
@export var damage: float = 50.0
@export var penetration: float = 10.0
@export var speed: float = 600.0
@export var life_time: float = 5.0
@export_enum("AP", "HE") var projectile_type: int = 0
