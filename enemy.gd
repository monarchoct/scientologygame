extends CharacterBody3D

var player: Node3D = null
var nav_agent: NavigationAgent3D = null
var is_stunned: bool = false
var stun_time_left: float = 0.0

const SPEED: float = 15.0
const ATTACK_RANGE: float = 1.5
const STUN_DURATION: float = 2.0

@export var player_path: NodePath
@export var aggro_range: float = 50.0
@export var min_enemy_distance: float = 2.0

func _ready() -> void:
	add_to_group("enemies")
	# Get player node
	player = get_node(player_path) as Node3D
	# Assuming NavigationAgent3D is a child node; adjust path if necessary
	nav_agent = $NavigationAgent3D as NavigationAgent3D
	# Adjust navigation agent size based on current scale to prevent issues with large scales
	if nav_agent:
		var scale_factor: float = global_transform.basis.get_scale().x  # Assuming uniform scale
		nav_agent.radius = 0.5 * scale_factor
		nav_agent.height = 2.0 * scale_factor

func _physics_process(delta: float) -> void:
	# Update stun timer
	if is_stunned:
		stun_time_left -= delta
		if stun_time_left <= 0.0:
			is_stunned = false
		else:
			_apply_enemy_spacing()
			return  # Don't move while stunned

	# Ensure nav_agent and player are valid
	if nav_agent and player:
		if not _player_in_aggro_range():
			velocity = Vector3.ZERO
			_apply_enemy_spacing()
			return

		# Set target position for the navigation agent
		nav_agent.set_target_position(player.global_transform.origin)

		var current_location: Vector3 = global_transform.origin
		var next_location: Vector3 = nav_agent.get_next_path_position()

		# Calculate velocity
		var new_velocity: Vector3 = (next_location - current_location).normalized() * SPEED
		new_velocity += _get_enemy_spacing_velocity()
		velocity = velocity.move_toward(new_velocity, 0.25)

		# Move the character
		move_and_slide()

		_apply_enemy_spacing()

	if _player_in_aggro_range() and _target_in_range():
		hit_finished()

func _player_in_aggro_range() -> bool:
	return player != null and global_position.distance_to(player.global_position) <= aggro_range

func _get_enemy_spacing_velocity() -> Vector3:
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
			spacing_velocity += offset.normalized() * SPEED * strength
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

func take_damage(damage_amount: float) -> void:
	# Stun the enemy when hit by knife
	is_stunned = true
	stun_time_left = STUN_DURATION
	velocity = Vector3.ZERO  # Stop movement immediately

func take_backstab_damage(damage_amount: float) -> void:
	# Backstab stuns for longer
	is_stunned = true
	stun_time_left = STUN_DURATION * 1.5
	velocity = Vector3.ZERO
