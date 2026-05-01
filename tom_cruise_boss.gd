extends "res://enemy.gd"

signal boss_health_changed(current_health, maximum_health)
signal boss_defeated

const MINI_GUARD_SCENE: PackedScene = preload("res://enemy2.tscn")

@export var boss_max_health: float = 9000.0
@export var boss_speed: float = 6.25
@export var slam_range: float = 3.5
@export var slam_damage_hits: int = 1
@export var slam_cooldown_seconds: float = 2.6
@export var melee_cooldown_seconds: float = 0.9
@export var minion_spawn_cooldown_seconds: float = 4.5
@export var max_live_minions: int = 8
@export var minion_speed_multiplier: float = 1.35
@export var minion_speed_growth_per_second: float = 0.025
@export var max_minion_speed_multiplier: float = 3.0
@export var minion_spawn_player_clearance: float = 4.5

var slam_cooldown_left: float = 1.2
var melee_cooldown_left: float = 0.0
var minion_spawn_cooldown_left: float = 3.0
var fight_time_seconds: float = 0.0
var live_minions: Array[Node] = []
var minion_spawn_origin: Vector3 = Vector3.ZERO
var minion_spawn_origin_set: bool = false

func _ready() -> void:
	max_health = boss_max_health
	super._ready()
	health = boss_max_health
	SPEED = boss_speed
	min_enemy_distance = 4.0
	boss_health_changed.emit(health, boss_max_health)

func _physics_process(delta: float) -> void:
	slam_cooldown_left = maxf(slam_cooldown_left - delta, 0.0)
	melee_cooldown_left = maxf(melee_cooldown_left - delta, 0.0)
	minion_spawn_cooldown_left = maxf(minion_spawn_cooldown_left - delta, 0.0)
	fight_time_seconds += delta

	super._physics_process(delta)

	if player == null:
		return

	if global_position.distance_to(player.global_position) <= slam_range and slam_cooldown_left <= 0.0:
		_slam_attack()

	_prune_minions()
	if minion_spawn_cooldown_left <= 0.0 and live_minions.size() < max_live_minions:
		_spawn_mini_guards()

func hit_finished() -> void:
	if player == null or melee_cooldown_left > 0.0:
		return
	if player.has_method("hit"):
		player.call("hit")
	melee_cooldown_left = melee_cooldown_seconds

func take_damage(damage_amount: float, hit_position: Variant = null, hit_normal: Variant = null) -> void:
	_spawn_effect(HIT_EFFECT_SCENE, _get_effect_position(hit_position), hit_normal)
	health = maxf(health - damage_amount, 0.0)
	boss_health_changed.emit(health, boss_max_health)
	if health <= 0.0:
		_spawn_effect(DEATH_EFFECT_SCENE, global_position + Vector3.UP * 1.8, hit_normal)
		boss_defeated.emit()
		died.emit(self)
		queue_free()
		return
	is_stunned = true
	stun_time_left = minf(STUN_DURATION, 0.6)
	velocity = Vector3.ZERO

func take_backstab_damage(damage_amount: float, hit_position: Variant = null, hit_normal: Variant = null) -> void:
	take_damage(damage_amount * 1.5, hit_position, hit_normal)

func _slam_attack() -> void:
	slam_cooldown_left = slam_cooldown_seconds
	_spawn_effect(HIT_EFFECT_SCENE, global_position + Vector3.UP * 1.5, Vector3.UP)
	if player != null and global_position.distance_to(player.global_position) <= slam_range:
		for _hit_index in range(slam_damage_hits):
			if player.has_method("hit"):
				player.call("hit")

func _spawn_mini_guards() -> void:
	minion_spawn_cooldown_left = minion_spawn_cooldown_seconds
	var spawn_count: int = clampi(max_live_minions - live_minions.size(), 2, 4)
	for index in range(spawn_count):
		var minion: Node3D = MINI_GUARD_SCENE.instantiate() as Node3D
		if minion == null:
			continue
		minion.name = "TomCruiseMiniGuard"
		minion.set("player_path", player_path)
		minion.set("stun_on_damage", false)
		minion.scale = Vector3(1.25, 1.25, 1.25)
		get_parent().add_child(minion)
		if minion.get("SPEED") != null:
			minion.set("SPEED", float(minion.get("SPEED")) * _get_current_minion_speed_multiplier())
		var angle: float = (TAU / float(spawn_count)) * float(index) + randf_range(-0.35, 0.35)
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(4.0, 6.0)
		var spawn_position: Vector3 = _get_minion_spawn_center() + offset
		minion.global_position = _push_spawn_position_away_from_player(spawn_position)
		live_minions.append(minion)

func _get_minion_spawn_center() -> Vector3:
	if minion_spawn_origin_set:
		return minion_spawn_origin
	return global_position

func _push_spawn_position_away_from_player(spawn_position: Vector3) -> Vector3:
	if player == null:
		return spawn_position
	var player_position: Vector3 = player.global_position
	var offset_from_player: Vector3 = spawn_position - player_position
	offset_from_player.y = 0.0
	var distance: float = offset_from_player.length()
	if distance >= minion_spawn_player_clearance:
		return spawn_position
	if distance < 0.01:
		offset_from_player = spawn_position - _get_minion_spawn_center()
		offset_from_player.y = 0.0
	if offset_from_player.length_squared() < 0.01:
		offset_from_player = Vector3.FORWARD
	var cleared_position: Vector3 = player_position + offset_from_player.normalized() * minion_spawn_player_clearance
	cleared_position.y = spawn_position.y
	return cleared_position

func _prune_minions() -> void:
	for index in range(live_minions.size() - 1, -1, -1):
		if not is_instance_valid(live_minions[index]):
			live_minions.remove_at(index)

func _get_current_minion_speed_multiplier() -> float:
	return minf(minion_speed_multiplier + fight_time_seconds * minion_speed_growth_per_second, max_minion_speed_multiplier)
