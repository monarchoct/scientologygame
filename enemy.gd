extends CharacterBody3D

signal died(enemy_node)

const HIT_EFFECT_SCENE := preload("res://enemy_hit_effect.tscn")
const DEATH_EFFECT_SCENE := preload("res://enemy_death_effect.tscn")

var player: Node3D = null
var nav_agent: NavigationAgent3D = null
var is_stunned: bool = false
var stun_time_left: float = 0.0
var health: float = 0.0

const BASE_SPEED: float = 15.0
var SPEED: float = BASE_SPEED
const ATTACK_RANGE: float = 1.5
const STUN_DURATION: float = 2.0
const SPACING_FORCE_MULTIPLIER: float = 0.35
const SPACING_MAX_SPEED_RATIO: float = 0.45
const CHASE_ACCELERATION_MULTIPLIER: float = 8.0

@export var player_path: NodePath
@export var aggro_range: float = 50.0
@export var min_enemy_distance: float = 2.0
@export var max_health: float = 100.0
@export var backstab_damage_multiplier: float = 3.0
@export var stun_on_damage: bool = true

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	SPEED = BASE_SPEED * DifficultyManager.get_speed_multiplier()
	_update_nightmare_lights()
	player = get_node(player_path) as Node3D
	nav_agent = $NavigationAgent3D as NavigationAgent3D
	if nav_agent:
		var scale_factor: float = global_transform.basis.get_scale().x
		nav_agent.radius = 0.5 * scale_factor
		nav_agent.height = 2.0 * scale_factor

func _update_nightmare_lights() -> void:
	var nightmare_active: bool = DifficultyManager.current_difficulty == DifficultyManager.Difficulty.NIGHTMARE
	for light_node in find_children("nightmare mode", "Light3D", true, false):
		var light: Light3D = light_node as Light3D
		if light != null:
			light.visible = nightmare_active

func _physics_process(delta: float) -> void:
	if is_stunned:
		stun_time_left -= delta
		if stun_time_left <= 0.0:
			is_stunned = false
		else:
			_apply_enemy_spacing()
			return

	if nav_agent and player:
		if not _player_in_aggro_range():
			velocity = Vector3.ZERO
			_apply_enemy_spacing()
			return

		nav_agent.set_target_position(player.global_transform.origin)

		var current_location: Vector3 = global_transform.origin
		var next_location: Vector3 = nav_agent.get_next_path_position()

		var chase_direction: Vector3 = (next_location - current_location).normalized()
		var new_velocity: Vector3 = chase_direction * SPEED
		new_velocity += _get_enemy_spacing_velocity(chase_direction)
		velocity = velocity.move_toward(new_velocity, SPEED * CHASE_ACCELERATION_MULTIPLIER * delta)

		move_and_slide()

	if _player_in_aggro_range() and _target_in_range():
		hit_finished()

func _player_in_aggro_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= aggro_range

func _get_enemy_spacing_velocity(chase_direction: Vector3 = Vector3.ZERO) -> Vector3:
	var spacing_velocity: Vector3 = Vector3.ZERO
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or not (enemy is Node3D):
			continue
		var enemy_node: Node3D = enemy as Node3D
		var offset: Vector3 = global_position - enemy_node.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance < min_enemy_distance:
			if distance <= 0.001:
				var angle: float = float(get_instance_id() % 628) / 100.0
				offset = Vector3(cos(angle), 0.0, sin(angle))
				distance = 0.001
			var strength: float = (min_enemy_distance - distance) / min_enemy_distance
			spacing_velocity += offset.normalized() * SPEED * strength * SPACING_FORCE_MULTIPLIER
	if chase_direction.length_squared() > 0.001 and spacing_velocity.dot(chase_direction) < 0.0:
		spacing_velocity -= chase_direction * spacing_velocity.dot(chase_direction)
	var max_spacing_speed: float = SPEED * SPACING_MAX_SPEED_RATIO
	if spacing_velocity.length() > max_spacing_speed:
		spacing_velocity = spacing_velocity.normalized() * max_spacing_speed
	return spacing_velocity

func _apply_enemy_spacing() -> void:
	var spacing_velocity: Vector3 = _get_enemy_spacing_velocity()
	if spacing_velocity == Vector3.ZERO:
		return
	velocity = spacing_velocity
	move_and_slide()

func _target_in_range() -> bool:
	return global_position.distance_to(player.global_position) < ATTACK_RANGE

func hit_finished() -> void:
	player.hit()

func take_damage(damage_amount: float, hit_position: Variant = null, hit_normal: Variant = null) -> void:
	_spawn_effect(HIT_EFFECT_SCENE, _get_effect_position(hit_position), hit_normal)
	health -= damage_amount
	if health <= 0.0:
		_die(hit_normal)
		return
	if not stun_on_damage:
		return
	is_stunned = true
	stun_time_left = STUN_DURATION
	velocity = Vector3.ZERO

func take_backstab_damage(damage_amount: float, hit_position: Variant = null, hit_normal: Variant = null) -> void:
	_spawn_effect(HIT_EFFECT_SCENE, _get_effect_position(hit_position), hit_normal)
	health -= damage_amount * backstab_damage_multiplier
	if health <= 0.0:
		_die(hit_normal)
		return
	if not stun_on_damage:
		return
	is_stunned = true
	stun_time_left = STUN_DURATION * 1.5
	velocity = Vector3.ZERO

func _die(hit_normal: Variant = null) -> void:
	_spawn_effect(DEATH_EFFECT_SCENE, global_position + Vector3.UP * 0.7, hit_normal)
	died.emit(self)
	queue_free()

func _get_effect_position(effect_position: Variant) -> Vector3:
	if effect_position is Vector3:
		return effect_position
	return global_position + Vector3.UP * 0.8

func _spawn_effect(effect_scene: PackedScene, effect_position: Vector3, effect_normal: Variant = null) -> void:
	if effect_scene == null:
		return
	var effect := effect_scene.instantiate() as Node3D
	if effect == null:
		return
	if effect_normal is Vector3 and effect.has_method("configure"):
		effect.call("configure", effect_normal)
	var effect_parent := get_parent()
	if effect_parent == null:
		effect_parent = get_tree().current_scene
	if effect_parent == null:
		return
	effect_parent.add_child(effect)
	effect.global_position = effect_position
