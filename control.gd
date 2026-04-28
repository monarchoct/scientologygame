extends Control

var ui_click_sound: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_parent() is Control:
		get_parent().process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui_click_sound_player()

func _on_try_pressed() -> void:
	await _play_ui_click_sound()

	# unpause first
	get_tree().paused = false
	get_tree().set_meta("skip_main_menu_once", true)
	
	# lock mouse again for gameplay
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# hide the game-over UI immediately before the scene reloads
	var ui_root: Control = self
	if get_parent() is Control:
		ui_root = get_parent() as Control
	ui_root.visible = false
	
	# reload scene (new run)
	get_tree().reload_current_scene()


func _on_main_pressed() -> void:
	await _play_ui_click_sound()

	# unpause
	get_tree().paused = false
	
	# show mouse for menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# go to your menu scene, or reload this level back into its built-in menu
	if ResourceLoader.exists("res://scenes/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().reload_current_scene()

func _create_ui_click_sound_player() -> void:
	ui_click_sound = AudioStreamPlayer.new()
	ui_click_sound.name = "UIClickSound"
	ui_click_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	ui_click_sound.stream = load("res://magic-sound-effects.mp3")
	ui_click_sound.volume_db = 0.0
	add_child(ui_click_sound)

func _play_ui_click_sound() -> void:
	if ui_click_sound == null:
		return

	ui_click_sound.stop()
	ui_click_sound.play()
	var click_timer: SceneTreeTimer = get_tree().create_timer(0.2, true)
	await click_timer.timeout
