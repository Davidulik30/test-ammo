extends Node3D

@onready var dots: GPUParticles3D = $dots
@onready var fire: GPUParticles3D = $fire
@onready var smoke: GPUParticles3D = $smoke
@onready var exposive: AudioStreamPlayer3D = $exposive

@export var exp_scale: float = 1

func _ready() -> void:
	scale = Vector3(exp_scale,exp_scale,exp_scale)

@rpc("any_peer")
func explosion():
	dots.emitting = true
	smoke.emitting = true
	fire.emitting = true 
	exposive.play()
	await get_tree().create_timer(3).timeout
	queue_free()
