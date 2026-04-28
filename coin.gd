extends Area3D

signal picked_up

@export var pickup_sound_stream: AudioStream = preload("res://coinsound.mp3")
@export var pickup_sound_volume_db: float = 12.0

var has_been_picked_up: bool = false

func _ready() -> void:
	add_to_group("coins")
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if has_been_picked_up:
		return
	if not _is_player_body(body):
		return

	has_been_picked_up = true
	emit_signal("picked_up")
	set_deferred("monitoring", false)

	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false

	var pickup_sound: AudioStreamPlayer = AudioStreamPlayer.new()
	pickup_sound.name = "PickupSound"
	pickup_sound.stream = pickup_sound_stream
	pickup_sound.volume_db = pickup_sound_volume_db
	add_child(pickup_sound)
	pickup_sound.play()
	await pickup_sound.finished
	queue_free()

func _is_player_body(body: Node3D) -> bool:
	if body is CharacterBody3D:
		return true
	if body is CollisionObject3D:
		var collision_body: CollisionObject3D = body as CollisionObject3D
		return (collision_body.collision_layer & 2) != 0
	return false
