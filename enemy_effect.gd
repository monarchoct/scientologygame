extends Node3D

@export var lifetime: float = 0.3
@export var start_scale: Vector3 = Vector3(0.2, 0.2, 0.2)
@export var end_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var start_color: Color = Color(1.0, 0.12, 0.04, 0.9)
@export var end_color: Color = Color(1.0, 0.78, 0.12, 0.0)
@export var burst_particle_count: int = 0
@export var burst_particle_size: float = 0.045
@export var burst_particle_speed: float = 3.0
@export var burst_particle_spread: float = 0.65
@export var light_energy_start: float = 0.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D as MeshInstance3D
@onready var light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D

var _age: float = 0.0
var _material: BaseMaterial3D
var _hit_normal: Vector3 = Vector3.UP
var _particles: Array[MeshInstance3D] = []
var _particle_velocities: Array[Vector3] = []
var _particle_materials: Array[BaseMaterial3D] = []

func configure(surface_normal: Vector3) -> void:
	if surface_normal.length_squared() > 0.001:
		_hit_normal = surface_normal.normalized()

func _ready() -> void:
	scale = start_scale
	if mesh_instance != null and mesh_instance.material_override is BaseMaterial3D:
		_material = (mesh_instance.material_override as BaseMaterial3D).duplicate()
		mesh_instance.material_override = _material
		_material.albedo_color = start_color
	if light != null:
		light.light_color = start_color
		light.light_energy = light_energy_start
	_spawn_burst_particles()

func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	scale = start_scale.lerp(end_scale, t)
	if _material != null:
		_material.albedo_color = start_color.lerp(end_color, t)
	if light != null:
		light.light_energy = lerpf(light_energy_start, 0.0, t)
	_update_burst_particles(delta, t)
	if t >= 1.0:
		queue_free()

func _spawn_burst_particles() -> void:
	if burst_particle_count <= 0:
		return

	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = burst_particle_size
	particle_mesh.height = burst_particle_size * 2.0
	particle_mesh.radial_segments = 8
	particle_mesh.rings = 4

	var tangent := _hit_normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.001:
		tangent = _hit_normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := _hit_normal.cross(tangent).normalized()

	for i in range(burst_particle_count):
		var angle := TAU * float(i) / float(burst_particle_count)
		var side_dir := (tangent * cos(angle) + bitangent * sin(angle)) * burst_particle_spread
		var particle_dir := (_hit_normal + side_dir).normalized()

		var particle := MeshInstance3D.new()
		var particle_material := StandardMaterial3D.new()
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particle_material.albedo_color = start_color
		particle.material_override = particle_material
		particle.mesh = particle_mesh
		add_child(particle)

		_particles.append(particle)
		_particle_velocities.append(particle_dir * burst_particle_speed * randf_range(0.65, 1.2))
		_particle_materials.append(particle_material)

func _update_burst_particles(delta: float, t: float) -> void:
	for i in range(_particles.size()):
		var particle := _particles[i]
		if particle == null or not is_instance_valid(particle):
			continue
		particle.position += _particle_velocities[i] * delta
		particle.scale = Vector3.ONE * lerpf(1.0, 0.25, t)
		var particle_material := _particle_materials[i]
		if particle_material != null:
			particle_material.albedo_color = start_color.lerp(end_color, t)
