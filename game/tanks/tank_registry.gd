extends Node

# Global registry of available tanks (reads from res://game/tanks/ready_tanks)
@export var tanks_dir: String = "res://game/tanks/ready_tanks"
var tanks: Array = [] # array of String names (basename without extension)
var tank_paths: Dictionary = {} # name -> path

func _ready() -> void:
	refresh()

func refresh() -> void:
	tanks.clear()
	tank_paths.clear()
	var dir = DirAccess.open(tanks_dir)
	if dir == null:
		push_warning("TankRegistry: cannot open folder %s" % tanks_dir)
		return

	# iterate files in the directory
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tscn"):
			var tank_name = fname.get_basename()
			var path = "%s/%s" % [tanks_dir.rstrip("/"), fname]
			tanks.append(tank_name)
			tank_paths[tank_name] = path
		fname = dir.get_next()
	dir.list_dir_end()
	tanks.sort()

func get_tank_names() -> Array:
	return tanks.duplicate()

func get_tank_path(tank_name: String) -> String:
	return tank_paths.get(tank_name, "")

func get_tank_scene(tank_name: String) -> PackedScene:
	var path = get_tank_path(tank_name)
	if path == "":
		return null
	var s = ResourceLoader.load(path)
	if s is PackedScene:
		return s
	return null
