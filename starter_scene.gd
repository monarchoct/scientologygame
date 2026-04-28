extends Node3D

const TOTAL_TIME : float = 120.0
const SAVE_FILE_PATH : String = "user://survival_time.save"
const RUN_HISTORY_SAVE_FILE_PATH : String = "user://run_times.save"
const PLAYER_PROGRESS_SAVE_FILE_PATH : String = "user://player_progress.save"
const TIMER_LABEL_WIDTH : float = 190.0
const ENEMY_VOICE_MIN_DELAY : float = 12.0
const ENEMY_VOICE_MAX_DELAY : float = 18.0
const COIN_SPAWN_POINT_GROUP : String = "coin_spawn_point"
const COIN_STATE_COUNT : int = 4
const COIN_UI_SIZE : Vector2 = Vector2(138.0, 69.0)
const MENU_BUTTON_SIZE : Vector2 = Vector2(360.0, 70.0)
const END_BUTTON_SIZE : Vector2 = Vector2(360.0, 65.0)
const ROUND_TIMER_START_DELAY : float = 0.0
const USE_EDITOR_COIN_STATE_UI : bool = true
const EXIT_TRIGGER_SIZE : Vector3 = Vector3(8.0, 6.0, 6.0)
const END_PORTAL_SOUND_PATH : String = "res://FPSController/weapon_manager/player_hud/endportal.mp3"
const END_PORTAL_VOLUME_DB : float = 10.0
const EXIT_WIN_ARM_DELAY_SECONDS : float = 0.5
const WINNING_MUSIC_PATH : String = "res://FPSController/weapon_manager/player_hud/winning.mp3"
const WIN_FADE_DURATION : float = 5.0
const START_DAMAGE_GRACE_SECONDS : float = 1.0
const PLAYER_DAMAGE_ENABLED : bool = true
const COIN_POPUP_TEXTURE_PATH : String = "res://scientology_coin_popup.png"
const COIN_POPUP_SIZE : Vector2 = Vector2(272.0, 153.0)

@export var coin_scene: PackedScene = preload("res://coin.tscn")
@export var coin_spawn_count: int = 3
@export var coin_spawn_scale: Vector3 = Vector3(2.0, 2.0, 2.0)
@export var show_main_menu_on_start: bool = true
@export var round_start_animation_player: AnimationPlayer
@export var round_start_animation_player_path: NodePath
@export var round_start_animation_name: StringName = StringName("new_animations")
@export var coin_popup_buy_url: String = "https://www.scientology.org"

var time_left : float = TOTAL_TIME
var is_alive : bool = true
var color_rect : ColorRect
var timer_label : Label
var game_over_label : Label
var final_time_label : RichTextLabel
var death_sound : AudioStreamPlayer
var door_open_sound : AudioStreamPlayer
var enemy_sound : AudioStreamPlayer
var background_music : AudioStreamPlayer
var winning_music : AudioStreamPlayer
var ui_click_sound : AudioStreamPlayer
var main_ui : Control
var ui_root : Control
var enemy_voice_delay_left : float = 0.0
var enemy_voice_rng : RandomNumberGenerator = RandomNumberGenerator.new()
var coin_spawn_rng : RandomNumberGenerator = RandomNumberGenerator.new()
var coins_collected : int = 0
var coin_state_views : Array[TextureRect] = []
var main_menu_ui : Control
var settings_menu_ui : Control
var loading_ui : Control
var loading_fade_rect : ColorRect
var end_round_ui : Control
var end_time_label : Node
var round_started : bool = false
var round_timer_started : bool = false
var finish_exit_areas : Array[Area3D] = []
var exit_portal_sound_players : Array[AudioStreamPlayer3D] = []
var exit_is_open : bool = false
var exit_can_win : bool = false
var exit_portal_sound_played : bool = false
var has_won : bool = false
var player_has_won_once : bool = false
var damage_grace_active : bool = false
var coin_popup_layer : CanvasLayer
var coin_popup_ui : Control
var coin_popup_previous_mouse_mode : int = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	_load_player_progress()
	ui_root = $UI
	main_ui = $"Main UI"
	ui_root.process_mode = Node.PROCESS_MODE_ALWAYS
	main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	main_ui.visible = false
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.offset_left = 0.0
	ui_root.offset_top = 0.0
	ui_root.offset_right = 0.0
	ui_root.offset_bottom = 0.0
	main_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_ui.offset_left = 0.0
	main_ui.offset_top = 0.0
	main_ui.offset_right = 0.0
	main_ui.offset_bottom = 0.0
	if main_ui.has_node("Control"):
		var main_ui_control: Control = main_ui.get_node("Control") as Control
		main_ui_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_ui_control.offset_left = 0.0
		main_ui_control.offset_top = 0.0
		main_ui_control.offset_right = 0.0
		main_ui_control.offset_bottom = 0.0
	color_rect = $UI/ColorRect
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.offset_left = 0.0
	color_rect.offset_top = 0.0
	color_rect.offset_right = 0.0
	color_rect.offset_bottom = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.visible = false
	color_rect.color = Color(1, 0, 0, 0)

	_create_death_sound_player()
	_create_door_open_sound_player()
	_create_enemy_sound_player()
	_create_background_music_player()
	_create_winning_music_player()
	_create_ui_click_sound_player()
	_create_timer_label()
	_create_coin_state_ui()
	_create_menu_screens()
	_create_coin_popup_ui()
	_create_game_over_labels()
	_update_timer_label()
	_update_coin_state_ui()
	_set_game_over_ui_input_enabled(false)
	_set_ending_lights_enabled(false)
	_setup_finish_exit_area()
	_set_exit_open(false)
	enemy_voice_rng.randomize()
	coin_spawn_rng.randomize()
	call_deferred("_setup_random_coins")

	var skip_main_menu: bool = _consume_skip_main_menu_once()
	if show_main_menu_on_start and not skip_main_menu:
		_show_main_menu()
	elif skip_main_menu:
		call_deferred("_start_game_after_reload")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		call_deferred("_start_round_sequence")

func _process(delta : float) -> void:
	if not is_alive:
		return

	if round_timer_started:
		time_left = max(time_left - delta, 0.0)
		_update_timer_label()

	enemy_voice_delay_left = max(enemy_voice_delay_left - delta, 0.0)
	_update_enemy_proximity_audio()

	if round_timer_started and time_left <= 0.0:
		if is_alive:
			_on_timer_expired()
		# else game over already shown

func _on_player_player_hit() -> void:
	if not PLAYER_DAMAGE_ENABLED or not is_alive or has_won or damage_grace_active:
		return

	is_alive = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_stop_enemy_proximity_audio()
	if background_music.playing:
		background_music.stop()
	death_sound.play()
	_show_flash()
	_show_game_over()
	_save_survival_time(TOTAL_TIME - time_left)
	get_tree().paused = true

func _on_character_body_3d_player_hit() -> void:
	_on_player_player_hit()

func _on_timer_expired() -> void:
	if not is_alive or has_won:
		return

	is_alive = false
	round_timer_started = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_stop_enemy_proximity_audio()
	if background_music.playing:
		background_music.stop()
	_show_flash()
	_show_game_over()
	_save_survival_time(TOTAL_TIME)
	get_tree().paused = true

func _create_timer_label() -> void:
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "02:00"
	timer_label.theme = null
	timer_label.horizontal_alignment = 0
	timer_label.vertical_alignment = 0
	timer_label.clip_text = true
	timer_label.custom_minimum_size = Vector2(TIMER_LABEL_WIDTH, 30)
	timer_label.size = Vector2(TIMER_LABEL_WIDTH, 30)
	timer_label.position = Vector2(20, 20)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.add_theme_color_override("font_color", Color(0.68, 0.94, 1.0))
	timer_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.45, 0.62, 0.85))
	timer_label.add_theme_color_override("font_outline_color", Color(0.68, 0.94, 1.0))
	timer_label.add_theme_constant_override("outline_size", 2)
	timer_label.add_theme_constant_override("shadow_offset_x", 1)
	timer_label.add_theme_constant_override("shadow_offset_y", 1)
	timer_label.self_modulate = Color(1, 1, 1, 1)
	ui_root.add_child(timer_label)

func _create_coin_state_ui() -> void:
	coin_state_views.clear()
	if USE_EDITOR_COIN_STATE_UI:
		return

	for state in range(COIN_STATE_COUNT):
		var coin_state_texture: Texture2D = load("res://coin_ui_%d.png" % state) as Texture2D
		var coin_state_view: TextureRect = TextureRect.new()
		coin_state_view.name = "CoinState%d" % state
		coin_state_view.texture = coin_state_texture
		coin_state_view.set_anchors_preset(Control.PRESET_CENTER_TOP)
		coin_state_view.offset_left = -(COIN_UI_SIZE.x * 0.5)
		coin_state_view.offset_top = 12.0
		coin_state_view.offset_right = COIN_UI_SIZE.x * 0.5
		coin_state_view.offset_bottom = 12.0 + COIN_UI_SIZE.y
		coin_state_view.custom_minimum_size = COIN_UI_SIZE
		coin_state_view.size = COIN_UI_SIZE
		coin_state_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_state_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_state_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_state_view.visible = false

		ui_root.add_child(coin_state_view)
		coin_state_views.append(coin_state_view)

func _create_coin_popup_ui() -> void:
	coin_popup_layer = CanvasLayer.new()
	coin_popup_layer.name = "CoinPopupLayer"
	coin_popup_layer.layer = 100
	coin_popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(coin_popup_layer)

	coin_popup_ui = Control.new()
	coin_popup_ui.name = "CoinPopupUI"
	coin_popup_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	coin_popup_ui.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	coin_popup_ui.offset_left = 8.0
	coin_popup_ui.offset_top = -COIN_POPUP_SIZE.y - 8.0
	coin_popup_ui.offset_right = 8.0 + COIN_POPUP_SIZE.x
	coin_popup_ui.offset_bottom = -8.0
	coin_popup_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	coin_popup_ui.visible = false

	var popup_image: TextureRect = TextureRect.new()
	popup_image.name = "PopupImage"
	popup_image.texture = load(COIN_POPUP_TEXTURE_PATH) as Texture2D
	popup_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_image.offset_left = 0.0
	popup_image.offset_top = 0.0
	popup_image.offset_right = 0.0
	popup_image.offset_bottom = 0.0
	popup_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	popup_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_popup_ui.add_child(popup_image)

	var close_button: Button = _create_popup_hit_button("CloseButton", Vector2(0.88, 0.08), Vector2(0.16, 0.22), _on_coin_popup_close_pressed)
	coin_popup_ui.add_child(close_button)

	var buy_button: Button = _create_popup_hit_button("BuyButton", Vector2(0.48, 0.61), Vector2(0.26, 0.16), _on_coin_popup_buy_pressed)
	coin_popup_ui.add_child(buy_button)

	coin_popup_layer.add_child(coin_popup_ui)

func _create_popup_hit_button(button_name: String, anchor_position: Vector2, normalized_size: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.modulate = Color(1, 1, 1, 0)
	button.size = Vector2(COIN_POPUP_SIZE.x * normalized_size.x, COIN_POPUP_SIZE.y * normalized_size.y)
	button.position = Vector2(
		(COIN_POPUP_SIZE.x * anchor_position.x) - (button.size.x * 0.5),
		(COIN_POPUP_SIZE.y * anchor_position.y) - (button.size.y * 0.5)
	)
	button.pressed.connect(callback)
	return button

func _create_menu_screens() -> void:
	var main_menu_scene: PackedScene = load("res://main.tscn") as PackedScene
	main_menu_ui = main_menu_scene.instantiate() as Control
	main_menu_ui.name = "MainMenuUI"
	main_menu_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(main_menu_ui)
	main_menu_ui.visible = false
	_connect_menu_button("Sprite2D/Settings", _on_settings_pressed)
	_connect_menu_button("Sprite2D/Play", _on_play_pressed)
	_connect_menu_button("Sprite2D/Credits", _on_credits_pressed)
	_create_settings_menu_ui()

	var loading_screen_scene: PackedScene = load("res://loading_screen.tscn") as PackedScene
	loading_ui = loading_screen_scene.instantiate() as Control
	loading_ui.name = "LoadingUI"
	loading_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	loading_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(loading_ui)
	loading_ui.visible = false
	loading_fade_rect = ColorRect.new()
	loading_fade_rect.name = "LoadingFade"
	loading_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_fade_rect.offset_left = 0.0
	loading_fade_rect.offset_top = 0.0
	loading_fade_rect.offset_right = 0.0
	loading_fade_rect.offset_bottom = 0.0
	loading_fade_rect.color = Color(0, 0, 0, 1)
	loading_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loading_ui.add_child(loading_fade_rect)

	var end_round_scene: PackedScene = load("res://end.tscn") as PackedScene
	end_round_ui = end_round_scene.instantiate() as Control
	end_round_ui.name = "EndRoundUI"
	end_round_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	end_round_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	main_ui.add_child(end_round_ui)
	if main_ui.has_node("Control"):
		var old_end_control: Control = main_ui.get_node("Control") as Control
		old_end_control.visible = false
	_connect_end_button("retry", _on_end_retry_pressed)
	_connect_end_button("Button", _on_end_retry_pressed)
	_connect_end_button("main", _on_end_main_pressed)
	end_time_label = _find_time_label(end_round_ui)
	_apply_end_time_label_style()
	_set_end_won_sprite_visible(false)

func _connect_menu_button(button_path: NodePath, callback: Callable) -> void:
	var button: Button = main_menu_ui.get_node_or_null(button_path) as Button
	if button == null:
		print("Main menu button missing: %s" % button_path)
		return

	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _create_settings_menu_ui() -> void:
	settings_menu_ui = Control.new()
	settings_menu_ui.name = "SettingsMenuUI"
	settings_menu_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	settings_menu_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_menu_ui.offset_left = 0.0
	settings_menu_ui.offset_top = 0.0
	settings_menu_ui.offset_right = 0.0
	settings_menu_ui.offset_bottom = 0.0
	settings_menu_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_menu_ui.visible = false
	ui_root.add_child(settings_menu_ui)

	var dim_background: ColorRect = ColorRect.new()
	dim_background.name = "DimBackground"
	dim_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_background.offset_left = 0.0
	dim_background.offset_top = 0.0
	dim_background.offset_right = 0.0
	dim_background.offset_bottom = 0.0
	dim_background.color = Color(0, 0, 0, 0.55)
	dim_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_menu_ui.add_child(dim_background)

	var panel: Panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230.0
	panel.offset_top = -120.0
	panel.offset_right = 230.0
	panel.offset_bottom = 120.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_menu_ui.add_child(panel)

	var title_label: Label = Label.new()
	title_label.name = "Title"
	title_label.text = "SETTINGS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	title_label.position = Vector2(0.0, 18.0)
	title_label.size = Vector2(460.0, 45.0)
	panel.add_child(title_label)

	var volume_label: Label = Label.new()
	volume_label.name = "VolumeLabel"
	volume_label.text = "VOLUME"
	volume_label.add_theme_font_size_override("font_size", 22)
	volume_label.add_theme_color_override("font_color", Color(1, 1, 1))
	volume_label.position = Vector2(55.0, 84.0)
	volume_label.size = Vector2(140.0, 34.0)
	panel.add_child(volume_label)

	var volume_slider: HSlider = HSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = _get_master_volume_percent()
	volume_slider.position = Vector2(175.0, 88.0)
	volume_slider.size = Vector2(230.0, 30.0)
	volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	volume_slider.value_changed.connect(_on_settings_volume_changed)
	panel.add_child(volume_slider)

	var back_button: Button = Button.new()
	back_button.name = "Back"
	back_button.text = "BACK"
	back_button.position = Vector2(130.0, 160.0)
	back_button.size = Vector2(200.0, 48.0)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.pressed.connect(_on_settings_back_pressed)
	panel.add_child(back_button)

func _get_master_volume_percent() -> float:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var volume_db: float = AudioServer.get_bus_volume_db(master_bus_index)
	if volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(volume_db) * 100.0, 0.0, 100.0)

func _on_settings_volume_changed(value: float) -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_volume_db(master_bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value / 100.0))

func _on_settings_back_pressed() -> void:
	_play_ui_click_sound()
	settings_menu_ui.visible = false
	if main_menu_ui:
		main_menu_ui.visible = true

func _connect_end_button(button_path: NodePath, callback: Callable) -> void:
	var button: Button = end_round_ui.get_node_or_null(button_path) as Button
	if button == null:
		print("End screen button missing: %s" % button_path)
		return

	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

func _find_time_label(root: Node) -> Node:
	var label_names: Array[StringName] = [
		StringName("time"),
		StringName("Time"),
		StringName("YourTime")
	]
	return _find_label_recursive(root, label_names)

func _find_label_recursive(node: Node, label_names: Array[StringName]) -> Node:
	if (node is Label or node is RichTextLabel) and label_names.has(node.name):
		return node

	for child in node.get_children():
		var found_label: Node = _find_label_recursive(child, label_names)
		if found_label:
			return found_label
	return null

func _set_end_time_text(text: String) -> void:
	if end_time_label == null and end_round_ui:
		end_time_label = _find_time_label(end_round_ui)
		_apply_end_time_label_style()

	if end_time_label is Label:
		var time_label: Label = end_time_label as Label
		time_label.text = text
	elif end_time_label is RichTextLabel:
		var rich_time_label: RichTextLabel = end_time_label as RichTextLabel
		rich_time_label.text = text

func _apply_end_time_label_style() -> void:
	if end_time_label is Label:
		var time_label: Label = end_time_label as Label
		time_label.add_theme_font_size_override("font_size", 48)
		time_label.add_theme_color_override("font_color", Color(1, 1, 1))
		time_label.add_theme_constant_override("outline_size", 0)
	elif end_time_label is RichTextLabel:
		var rich_time_label: RichTextLabel = end_time_label as RichTextLabel
		rich_time_label.add_theme_font_size_override("normal_font_size", 48)
		rich_time_label.add_theme_color_override("default_color", Color(1, 1, 1))
		rich_time_label.add_theme_constant_override("outline_size", 0)

func _set_end_won_sprite_visible(visible: bool) -> void:
	if end_round_ui == null:
		return

	var won_sprite_names: Array[String] = ["won", "Won", "WonSprite", "win", "Win", "WinSprite"]
	for won_sprite_name in won_sprite_names:
		var won_sprite: CanvasItem = _find_canvas_item_by_name(end_round_ui, won_sprite_name)
		if won_sprite:
			won_sprite.visible = visible

func _on_end_retry_pressed() -> void:
	_play_ui_click_sound()
	var click_timer: SceneTreeTimer = get_tree().create_timer(0.2, true)
	await click_timer.timeout
	get_tree().paused = false
	get_tree().set_meta("skip_main_menu_once", true)
	main_ui.visible = false
	_set_game_over_ui_input_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().call_deferred("reload_current_scene")

func _on_end_main_pressed() -> void:
	_play_ui_click_sound()
	var click_timer: SceneTreeTimer = get_tree().create_timer(0.2, true)
	await click_timer.timeout
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().reload_current_scene()

func _create_image_screen(screen_name: String, texture_path: String, parent: Control) -> Control:
	var screen: Control = Control.new()
	screen.name = screen_name
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.offset_left = 0.0
	screen.offset_top = 0.0
	screen.offset_right = 0.0
	screen.offset_bottom = 0.0
	screen.mouse_filter = Control.MOUSE_FILTER_STOP

	var image: TextureRect = TextureRect.new()
	image.name = "Image"
	image.texture = load(texture_path) as Texture2D
	image.set_anchors_preset(Control.PRESET_FULL_RECT)
	image.offset_left = 0.0
	image.offset_top = 0.0
	image.offset_right = 0.0
	image.offset_bottom = 0.0
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(image)

	parent.add_child(screen)
	return screen

func _add_screen_button(parent: Control, button_name: String, anchor_position: Vector2, button_size: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size = button_size
	button.position = _get_centered_ui_position(anchor_position, button_size)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _setup_end_round_buttons() -> void:
	var control_root: Control = main_ui
	if main_ui.has_node("Control"):
		control_root = main_ui.get_node("Control") as Control

	var try_button: Button = control_root.get_node_or_null("Try") as Button
	if try_button:
		try_button.text = ""
		try_button.flat = true
		try_button.focus_mode = Control.FOCUS_NONE
		try_button.size = END_BUTTON_SIZE
		try_button.position = _get_centered_ui_position(Vector2(0.5, 0.31), END_BUTTON_SIZE)

	var main_button: Button = control_root.get_node_or_null("Main") as Button
	if main_button:
		main_button.text = ""
		main_button.flat = true
		main_button.focus_mode = Control.FOCUS_NONE
		main_button.size = END_BUTTON_SIZE
		main_button.position = _get_centered_ui_position(Vector2(0.5, 0.42), END_BUTTON_SIZE)

	if control_root.has_node("SettingUpForaOs(14)"):
		var old_sprite: CanvasItem = control_root.get_node("SettingUpForaOs(14)") as CanvasItem
		old_sprite.visible = false

func _get_centered_ui_position(anchor_position: Vector2, element_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
		(viewport_size.x * anchor_position.x) - (element_size.x * 0.5),
		(viewport_size.y * anchor_position.y) - (element_size.y * 0.5)
	)

func _show_main_menu() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	main_ui.visible = false
	loading_ui.visible = false
	if settings_menu_ui:
		settings_menu_ui.visible = false
	main_menu_ui.visible = true
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_coin_popup()

func _consume_skip_main_menu_once() -> bool:
	if not get_tree().has_meta("skip_main_menu_once"):
		return false

	get_tree().remove_meta("skip_main_menu_once")
	return true

func _start_game_after_reload() -> void:
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _play_loading_transition()
	loading_ui.visible = false
	_hide_coin_popup()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_start_round_sequence()

func _on_play_pressed() -> void:
	_play_ui_click_sound()
	await _play_loading_transition()
	main_menu_ui.visible = false
	if settings_menu_ui:
		settings_menu_ui.visible = false
	loading_ui.visible = false
	_hide_coin_popup()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_start_round_sequence()

func _on_settings_pressed() -> void:
	_play_ui_click_sound()
	if settings_menu_ui:
		settings_menu_ui.visible = true
	_show_coin_popup()

func _on_credits_pressed() -> void:
	_play_ui_click_sound()
	OS.shell_open("https://x.com/monarchofct")

func _play_loading_transition() -> void:
	main_menu_ui.visible = false
	loading_ui.visible = true
	_show_coin_popup()
	loading_fade_rect.color = Color(0, 0, 0, 1)

	var fade_in_tween: Tween = create_tween()
	fade_in_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in_tween.tween_property(loading_fade_rect, "color:a", 0.0, 0.45)
	await fade_in_tween.finished

	var loading_timer: SceneTreeTimer = get_tree().create_timer(0.75, true)
	await loading_timer.timeout

	var fade_out_tween: Tween = create_tween()
	fade_out_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out_tween.tween_property(loading_fade_rect, "color:a", 1.0, 0.35)
	await fade_out_tween.finished

func _update_coin_state_ui() -> void:
	var visible_state: int = clampi(coins_collected, 0, COIN_STATE_COUNT - 1)
	if _update_editor_coin_state_ui(visible_state):
		return

	for state in range(coin_state_views.size()):
		var coin_state_view: TextureRect = coin_state_views[state]
		coin_state_view.visible = state == visible_state

func _update_editor_coin_state_ui(visible_state: int) -> bool:
	var found_any: bool = false
	for state in range(COIN_STATE_COUNT):
		var coin_state_node: CanvasItem = _find_canvas_item_by_name(self, "coin %d" % state)
		if coin_state_node == null:
			coin_state_node = _find_canvas_item_by_name(self, "Coin %d" % state)
		if coin_state_node == null:
			coin_state_node = _find_canvas_item_by_name(self, "coin%d" % state)
		if coin_state_node == null:
			coin_state_node = _find_canvas_item_by_name(self, "Coin%d" % state)
		if coin_state_node == null:
			continue

		coin_state_node.visible = state == visible_state
		found_any = true

	return found_any

func _find_canvas_item_by_name(root: Node, target_name: String) -> CanvasItem:
	if String(root.name).to_lower() == target_name.to_lower() and root is CanvasItem:
		return root as CanvasItem

	for child in root.get_children():
		var found_item: CanvasItem = _find_canvas_item_by_name(child, target_name)
		if found_item:
			return found_item
	return null

func _create_game_over_labels() -> void:
	var game_over_parent: Control = main_ui
	if main_ui.has_node("Control"):
		game_over_parent = main_ui.get_node("Control") as Control
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var game_over_width: float = clampf(viewport_size.x * 0.8, 200.0, 500.0)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.text = "Game Over"
	game_over_label.add_theme_color_override("font_color", Color(1, 1, 1))
	game_over_label.horizontal_alignment = 1
	game_over_label.vertical_alignment = 1
	game_over_label.size = Vector2(360, 42)
	game_over_label.position = Vector2(54, 112)
	game_over_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_label.visible = false
	game_over_parent.add_child(game_over_label)

	final_time_label = RichTextLabel.new()
	final_time_label.name = "FinalTimeLabel"
	final_time_label.text = "Survived: 0:00"
	final_time_label.add_theme_color_override("default_color", Color(1, 1, 1))
	final_time_label.horizontal_alignment = 0
	final_time_label.vertical_alignment = 1
	final_time_label.size = Vector2(360, 42)
	final_time_label.position = Vector2(56, 156)
	final_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	final_time_label.bbcode_enabled = true
	final_time_label.visible = false
	game_over_parent.add_child(final_time_label)

func _update_timer_label() -> void:
	timer_label.text = _format_time(time_left)

func _get_elapsed_time() -> float:
	return clampf(TOTAL_TIME - time_left, 0.0, TOTAL_TIME)

func _format_time(time_seconds: float) -> String:
	var whole_seconds: int = maxi(0, int(ceil(time_seconds)))
	var minutes: int = int(whole_seconds / 60)
	var seconds: int = whole_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _show_flash() -> void:
	color_rect.visible = true
	color_rect.color = Color(1, 0, 0, 0.5)
	var flash_timer: SceneTreeTimer = get_tree().create_timer(0.2, true)
	await flash_timer.timeout
	color_rect.color = Color(1, 0, 0, 0.25)
	flash_timer = get_tree().create_timer(0.2, true)
	await flash_timer.timeout
	color_rect.visible = false

func _show_game_over() -> void:
	timer_label.visible = false
	main_ui.visible = true
	_set_game_over_ui_input_enabled(true)
	_set_end_won_sprite_visible(false)
	game_over_label.visible = false
	final_time_label.visible = false
	_set_end_time_text("Survived: %s" % _format_time(_get_elapsed_time()))
	_show_coin_popup()

func _show_game_won() -> void:
	if has_won:
		return

	has_won = true
	is_alive = false
	round_timer_started = false
	var run_time: float = _get_elapsed_time()
	_update_timer_label()
	_save_winning_run_time(run_time)
	player_has_won_once = true
	_save_player_progress()
	timer_label.visible = false
	_stop_enemy_proximity_audio()
	if background_music.playing:
		background_music.stop()
	for portal_sound in exit_portal_sound_players:
		if portal_sound.playing:
			portal_sound.stop()
	if winning_music:
		winning_music.play()

	color_rect.visible = true
	color_rect.color = Color(0, 0, 0, 0)
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(color_rect, "color:a", 1.0, WIN_FADE_DURATION)
	await fade_tween.finished

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	main_ui.visible = true
	if end_round_ui:
		end_round_ui.visible = true
	_set_game_over_ui_input_enabled(true)
	_set_end_won_sprite_visible(true)
	game_over_label.visible = false
	final_time_label.visible = false
	_set_end_time_text(_format_time(run_time))
	color_rect.visible = false
	color_rect.color = Color(0, 0, 0, 0)
	_show_coin_popup()
	get_tree().paused = true

func _create_death_sound_player() -> void:
	death_sound = AudioStreamPlayer.new()
	death_sound.name = "DeathSound"
	death_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	death_sound.stream = load("res://pump-shotgun-fortnite-loud.mp3")
	death_sound.volume_db = -24.0
	add_child(death_sound)

func _create_door_open_sound_player() -> void:
	door_open_sound = AudioStreamPlayer.new()
	door_open_sound.name = "DoorOpenSound"
	door_open_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	door_open_sound.stream = load("res://dooropen.mp3")
	door_open_sound.volume_db = 0.0
	add_child(door_open_sound)

func _create_enemy_sound_player() -> void:
	enemy_sound = AudioStreamPlayer.new()
	enemy_sound.name = "EnemySound"
	enemy_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_sound.stream = load("res://goaway.mp3")
	if enemy_sound.stream is AudioStreamMP3:
		enemy_sound.stream.loop = false
	enemy_sound.volume_db = -6.0
	add_child(enemy_sound)

func _create_background_music_player() -> void:
	background_music = AudioStreamPlayer.new()
	background_music.name = "BackgroundMusic"
	background_music.process_mode = Node.PROCESS_MODE_ALWAYS
	background_music.stream = load("res://track.mp3")
	if background_music.stream is AudioStreamMP3:
		background_music.stream.loop = true
	background_music.volume_db = -12.0
	add_child(background_music)
	background_music.play()

func _create_winning_music_player() -> void:
	winning_music = AudioStreamPlayer.new()
	winning_music.name = "WinningMusic"
	winning_music.process_mode = Node.PROCESS_MODE_ALWAYS
	winning_music.stream = load(WINNING_MUSIC_PATH)
	if winning_music.stream is AudioStreamMP3:
		winning_music.stream.loop = false
	winning_music.volume_db = 0.0
	add_child(winning_music)

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

func _get_player() -> Node3D:
	var player: Node3D = get_node_or_null("WorldEnvironment/CharacterBody3D") as Node3D
	if player == null:
		player = get_node_or_null("FPSController") as Node3D
	return player

func _update_enemy_proximity_audio() -> void:
	var player: Node3D = _get_player()
	if player == null:
		_stop_enemy_proximity_audio()
		return

	var closest_enemy_dist: float = INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D:
			var enemy_node: Node3D = enemy as Node3D
			var enemy_dist: float = player.global_position.distance_to(enemy_node.global_position)
			closest_enemy_dist = min(closest_enemy_dist, enemy_dist)

	if closest_enemy_dist <= 10.0:
		if not enemy_sound.playing and enemy_voice_delay_left <= 0.0:
			enemy_sound.play()
			enemy_voice_delay_left = enemy_voice_rng.randf_range(ENEMY_VOICE_MIN_DELAY, ENEMY_VOICE_MAX_DELAY)
	else:
		_stop_enemy_proximity_audio()

func _stop_enemy_proximity_audio() -> void:
	if enemy_sound and enemy_sound.playing:
		enemy_sound.stop()

func _start_round_sequence() -> void:
	if round_started:
		return

	round_started = true
	_start_damage_grace()
	round_timer_started = false
	_update_timer_label()
	_play_round_start_door_animation()
	if door_open_sound:
		door_open_sound.play()

	if ROUND_TIMER_START_DELAY > 0.0:
		var timer_delay: SceneTreeTimer = get_tree().create_timer(ROUND_TIMER_START_DELAY)
		await timer_delay.timeout
	round_timer_started = true
	_update_timer_label()

func _start_damage_grace() -> void:
	damage_grace_active = true
	var grace_timer: SceneTreeTimer = get_tree().create_timer(START_DAMAGE_GRACE_SECONDS)
	await grace_timer.timeout
	damage_grace_active = false

func _show_coin_popup() -> void:
	if coin_popup_ui == null:
		print("Coin popup missing.")
		return

	coin_popup_previous_mouse_mode = Input.get_mouse_mode()
	coin_popup_ui.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("Coin popup shown.")

func _hide_coin_popup() -> void:
	if coin_popup_ui:
		coin_popup_ui.visible = false

	if is_alive and not has_won and not main_ui.visible and not main_menu_ui.visible:
		Input.set_mouse_mode(coin_popup_previous_mouse_mode)

func _on_coin_popup_close_pressed() -> void:
	_hide_coin_popup()

func _on_coin_popup_buy_pressed() -> void:
	if coin_popup_buy_url != "":
		OS.shell_open(coin_popup_buy_url)
	_hide_coin_popup()

func _play_round_start_door_animation() -> void:
	var assigned_animation_player: AnimationPlayer = _get_assigned_round_start_animation_player()
	if assigned_animation_player:
		if _play_animation_player(assigned_animation_player, round_start_animation_name):
			return
		print("Assigned round start AnimationPlayer does not have animation: %s. Available: %s" % [round_start_animation_name, _get_animation_names_text(assigned_animation_player)])

	if _play_door_double_animations():
		return

	var door_animation_player: AnimationPlayer = _find_round_start_animation_player()
	if door_animation_player == null:
		print("No round start door AnimationPlayer found. Tried Door_Double nodes, then: new_animations, new animation, open")
		return

	var animation_name: StringName = _find_round_start_animation_name(door_animation_player)
	if animation_name == StringName():
		print("Door AnimationPlayer found, but it has no matching animation.")
		return

	_play_animation_player(door_animation_player, animation_name)

func _get_assigned_round_start_animation_player() -> AnimationPlayer:
	if round_start_animation_player:
		return round_start_animation_player

	if round_start_animation_player_path != NodePath(""):
		var path_animation_player: AnimationPlayer = get_node_or_null(round_start_animation_player_path) as AnimationPlayer
		if path_animation_player:
			return path_animation_player
		print("Round start AnimationPlayer path is set, but not found: %s" % round_start_animation_player_path)

	return null

func _play_animation_player(animation_player: AnimationPlayer, animation_name: StringName) -> bool:
	if not animation_player.has_animation(animation_name):
		return false

	animation_player.set_active(true)
	animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	animation_player.stop()
	animation_player.play(animation_name)
	print("Playing round start animation on %s: %s" % [animation_player.get_path(), animation_name])
	return true

func _get_animation_names_text(animation_player: AnimationPlayer) -> String:
	var animation_list: PackedStringArray = animation_player.get_animation_list()
	if animation_list.is_empty():
		return "<none>"
	return ", ".join(animation_list)

func _play_door_double_animations() -> bool:
	var played_any: bool = false
	var door_nodes: Array[Node] = []
	_collect_nodes_with_name_prefix(self, "Door_Double", door_nodes)

	for door_node in door_nodes:
		var animation_player: AnimationPlayer = _find_animation_player_recursive(door_node)
		if animation_player:
			var animation_name: StringName = _find_round_start_animation_name(animation_player)
			if animation_name != StringName():
				_play_animation_player(animation_player, animation_name)
				played_any = true
				print("Playing Door_Double animation on %s: %s" % [door_node.name, animation_name])
				continue

		if door_node.has_method("toggle_open"):
			door_node.call("toggle_open")
			played_any = true
			print("Toggled Door_Double open: %s" % door_node.name)
		elif door_node.has_method("update_door"):
			door_node.set("open", true)
			door_node.call("update_door")
			played_any = true
			print("Set Door_Double open: %s" % door_node.name)

	return played_any

func _collect_nodes_with_name_prefix(root: Node, prefix: String, results: Array[Node]) -> void:
	if String(root.name).begins_with(prefix):
		results.append(root)

	for child in root.get_children():
		_collect_nodes_with_name_prefix(child, prefix, results)

func _find_round_start_animation_player() -> AnimationPlayer:
	for node in get_tree().get_nodes_in_group("round_start_door_animation"):
		if node is AnimationPlayer:
			var grouped_animation_player: AnimationPlayer = node as AnimationPlayer
			if _find_round_start_animation_name(grouped_animation_player) != StringName():
				return grouped_animation_player

	for node in get_tree().get_nodes_in_group("door_animation"):
		if node is AnimationPlayer:
			var door_animation_player: AnimationPlayer = node as AnimationPlayer
			if _find_round_start_animation_name(door_animation_player) != StringName():
				return door_animation_player

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self
	return _find_animation_player_recursive(scene_root)

func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		var animation_player: AnimationPlayer = node as AnimationPlayer
		if _find_round_start_animation_name(animation_player) != StringName():
			return animation_player

	for child in node.get_children():
		var found_animation_player: AnimationPlayer = _find_animation_player_recursive(child)
		if found_animation_player:
			return found_animation_player
	return null

func _find_round_start_animation_name(animation_player: AnimationPlayer) -> StringName:
	var animation_names: Array[StringName] = [
		StringName("new_animations"),
		StringName("New_Animations"),
		StringName("new animation"),
		StringName("New Animation"),
		StringName("open")
	]
	for animation_name in animation_names:
		if animation_player.has_animation(animation_name):
			return animation_name

	var animation_list: PackedStringArray = animation_player.get_animation_list()
	for fallback_animation_name in animation_list:
		if String(fallback_animation_name) != "RESET":
			return StringName(fallback_animation_name)
	return StringName()

func _setup_random_coins() -> void:
	if not _spawn_random_coins():
		_connect_existing_coins()

func _spawn_random_coins() -> bool:
	var spawn_points: Array = get_tree().get_nodes_in_group(COIN_SPAWN_POINT_GROUP)
	if spawn_points.is_empty():
		print("No coin spawn points found. Add Marker3D nodes to group: %s" % COIN_SPAWN_POINT_GROUP)
		return false

	coin_spawn_rng.randomize()
	_remove_existing_coins()
	_shuffle_spawn_points(spawn_points)

	var spawn_count: int = mini(coin_spawn_count, spawn_points.size())
	var coin_parent: Node = get_node_or_null("WorldEnvironment")
	if coin_parent == null:
		coin_parent = self

	for index in range(spawn_count):
		var spawn_point: Node3D = spawn_points[index] as Node3D
		if spawn_point == null:
			continue

		var coin: Node3D = coin_scene.instantiate() as Node3D
		if coin == null:
			continue

		coin_parent.add_child(coin)
		coin.global_position = spawn_point.global_position
		coin.global_rotation = spawn_point.global_rotation
		coin.scale = coin_spawn_scale
		_connect_coin(coin)
		print("Coin spawned at %s" % spawn_point.name)
	print("Spawned %d coins from %d coin spawn points." % [spawn_count, spawn_points.size()])
	return true

func _connect_existing_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin is Node:
			var coin_node: Node = coin as Node
			_connect_coin(coin_node)

func _connect_coin(coin: Node) -> void:
	if not coin.has_signal("picked_up"):
		return

	var pickup_callable: Callable = Callable(self, "_on_coin_picked_up")
	if not coin.is_connected("picked_up", pickup_callable):
		coin.connect("picked_up", pickup_callable)

func _on_coin_picked_up() -> void:
	coins_collected = clampi(coins_collected + 1, 0, COIN_STATE_COUNT - 1)
	_update_coin_state_ui()
	if coins_collected >= coin_spawn_count:
		_set_ending_lights_enabled(true)
		_set_exit_open(true)

func _setup_finish_exit_area() -> void:
	_create_finish_exit_area(_get_ending_light_exit_position())

func _create_finish_exit_area(exit_center: Vector3) -> void:
	var finish_exit_area: Area3D = Area3D.new()
	finish_exit_area.name = "FinishExitArea"
	finish_exit_area.monitoring = false
	finish_exit_area.monitorable = false
	finish_exit_area.collision_layer = 0
	finish_exit_area.collision_mask = 2

	var finish_shape: CollisionShape3D = CollisionShape3D.new()
	finish_shape.name = "FinishExitShape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = EXIT_TRIGGER_SIZE
	finish_shape.shape = box_shape
	finish_exit_area.add_child(finish_shape)

	add_child(finish_exit_area)
	finish_exit_area.global_position = exit_center
	finish_exit_area.body_entered.connect(_on_finish_exit_body_entered)
	finish_exit_areas.append(finish_exit_area)
	_create_exit_portal_sound(exit_center)
	print("Finish exit trigger placed at %s" % exit_center)

func _create_exit_portal_sound(exit_center: Vector3) -> void:
	var portal_sound: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	portal_sound.name = "EndPortalSound"
	portal_sound.stream = load(END_PORTAL_SOUND_PATH)
	if portal_sound.stream is AudioStreamMP3:
		portal_sound.stream.loop = false
	portal_sound.volume_db = END_PORTAL_VOLUME_DB
	portal_sound.max_distance = 80.0
	portal_sound.unit_size = 8.0
	portal_sound.autoplay = false
	add_child(portal_sound)
	portal_sound.global_position = exit_center
	exit_portal_sound_players.append(portal_sound)

func _get_exit_center_position() -> Vector3:
	var exit_nodes: Array[Node] = _get_exit_blocker_nodes()
	if exit_nodes.is_empty():
		return global_position

	var total_position: Vector3 = Vector3.ZERO
	var position_count: int = 0
	for exit_node in exit_nodes:
		if exit_node is Node3D:
			var exit_node_3d: Node3D = exit_node as Node3D
			total_position += exit_node_3d.global_position
			position_count += 1

	if position_count == 0:
		return global_position

	return total_position / float(position_count)

func _get_ending_light_exit_position() -> Vector3:
	var ending_light_node: Node = _find_node_by_name(self, "endinglight")
	if ending_light_node == null:
		ending_light_node = _find_node_by_name(self, "ending light")
	if ending_light_node == null:
		ending_light_node = _find_node_by_name(self, "ending light 2")
	if ending_light_node == null:
		ending_light_node = _find_node_by_name(self, "ending light 3")

	if ending_light_node is Node3D:
		var ending_light_3d: Node3D = ending_light_node as Node3D
		return ending_light_3d.global_position

	print("No endinglight node found for finish trigger. Using scene root position.")
	return global_position

func _set_exit_open(open: bool) -> void:
	if exit_is_open == open:
		return

	exit_is_open = open
	exit_can_win = false
	if not open:
		exit_portal_sound_played = false
	var exit_nodes: Array[Node] = _get_exit_blocker_nodes()
	for exit_node in exit_nodes:
		if exit_node is Node3D:
			var exit_node_3d: Node3D = exit_node as Node3D
			exit_node_3d.visible = not open
		_set_node_collision_enabled(exit_node, not open)

	for finish_exit_area in finish_exit_areas:
		finish_exit_area.monitoring = open
		finish_exit_area.monitorable = open

	for portal_sound in exit_portal_sound_players:
		if open:
			if not exit_portal_sound_played:
				portal_sound.stop()
				portal_sound.play()
		elif portal_sound.playing:
			portal_sound.stop()
	if open:
		exit_portal_sound_played = true

	if open:
		_arm_exit_win_after_delay()

func _arm_exit_win_after_delay() -> void:
	var arm_timer: SceneTreeTimer = get_tree().create_timer(EXIT_WIN_ARM_DELAY_SECONDS)
	await arm_timer.timeout
	exit_can_win = exit_is_open

func _get_exit_blocker_nodes() -> Array[Node]:
	var exit_nodes: Array[Node] = []
	_collect_nodes_with_name_prefix(self, "Door_Double", exit_nodes)
	_collect_door_wall_nodes(self, exit_nodes)
	return exit_nodes

func _collect_door_wall_nodes(root: Node, results: Array[Node]) -> void:
	var lower_name: String = String(root.name).to_lower()
	if lower_name == "doorwall" or lower_name == "door wall" or lower_name == "door_wall":
		if not results.has(root):
			results.append(root)

	for child in root.get_children():
		_collect_door_wall_nodes(child, results)

func _set_node_collision_enabled(root: Node, enabled: bool) -> void:
	if root is CollisionObject3D:
		var collision_object: CollisionObject3D = root as CollisionObject3D
		if enabled:
			collision_object.collision_layer = 1
			collision_object.collision_mask = 1
		else:
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
	elif root is CollisionShape3D:
		var collision_shape: CollisionShape3D = root as CollisionShape3D
		collision_shape.disabled = not enabled

	for child in root.get_children():
		_set_node_collision_enabled(child, enabled)

func _on_finish_exit_body_entered(body: Node3D) -> void:
	if not exit_is_open or not exit_can_win or not is_alive:
		return

	if _is_player_body(body):
		_show_game_won()

func _is_player_body(body: Node) -> bool:
	if body == _get_player():
		return true
	if body is CharacterBody3D:
		return true
	if body is CollisionObject3D:
		var collision_body: CollisionObject3D = body as CollisionObject3D
		return collision_body.get_collision_layer_value(2)
	return false

func _set_ending_lights_enabled(enabled: bool) -> void:
	var ending_light_names: Array[String] = ["ending light", "ending light 2", "ending light 3"]
	for ending_light_name in ending_light_names:
		var ending_light_node: Node = _find_node_by_name(self, ending_light_name)
		if ending_light_node == null:
			continue

		if ending_light_node is Light3D:
			var ending_light: Light3D = ending_light_node as Light3D
			ending_light.visible = enabled
		elif ending_light_node is Node3D:
			var ending_light_3d: Node3D = ending_light_node as Node3D
			ending_light_3d.visible = enabled
		elif ending_light_node is CanvasItem:
			var ending_light_canvas: CanvasItem = ending_light_node as CanvasItem
			ending_light_canvas.visible = enabled

func _find_node_by_name(root: Node, target_name: String) -> Node:
	if String(root.name).to_lower() == target_name.to_lower():
		return root

	for child in root.get_children():
		var found_node: Node = _find_node_by_name(child, target_name)
		if found_node:
			return found_node
	return null

func _remove_existing_coins() -> void:
	for coin in get_tree().get_nodes_in_group("coins"):
		if coin is Node:
			var coin_node: Node = coin as Node
			coin_node.queue_free()

func _shuffle_spawn_points(spawn_points: Array) -> void:
	for index in range(spawn_points.size() - 1, 0, -1):
		var swap_index: int = coin_spawn_rng.randi_range(0, index)
		var original_spawn_point: Variant = spawn_points[index]
		spawn_points[index] = spawn_points[swap_index]
		spawn_points[swap_index] = original_spawn_point

func _set_game_over_ui_input_enabled(enabled: bool) -> void:
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if enabled:
		main_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		if end_round_ui:
			end_round_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		main_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if end_round_ui:
			end_round_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if main_ui.has_node("Control"):
		var main_ui_control: Control = main_ui.get_node("Control") as Control
		if enabled:
			main_ui_control.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			main_ui_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _load_player_progress() -> void:
	player_has_won_once = false
	if not FileAccess.file_exists(PLAYER_PROGRESS_SAVE_FILE_PATH):
		return

	var file: FileAccess = FileAccess.open(PLAYER_PROGRESS_SAVE_FILE_PATH, FileAccess.ModeFlags.READ)
	if file == null:
		return

	var save_text: String = file.get_as_text()
	file.close()
	player_has_won_once = save_text.find("won_once=true") != -1

func _save_player_progress() -> void:
	var file: FileAccess = FileAccess.open(PLAYER_PROGRESS_SAVE_FILE_PATH, FileAccess.ModeFlags.WRITE)
	if file:
		if player_has_won_once:
			file.store_line("won_once=true")
		else:
			file.store_line("won_once=false")
		file.close()

func _save_winning_run_time(run_time_seconds: float) -> void:
	var previous_text: String = ""
	if FileAccess.file_exists(RUN_HISTORY_SAVE_FILE_PATH):
		var read_file: FileAccess = FileAccess.open(RUN_HISTORY_SAVE_FILE_PATH, FileAccess.ModeFlags.READ)
		if read_file:
			previous_text = read_file.get_as_text()
			read_file.close()

	var write_file: FileAccess = FileAccess.open(RUN_HISTORY_SAVE_FILE_PATH, FileAccess.ModeFlags.WRITE)
	if write_file:
		if previous_text != "":
			write_file.store_string(previous_text)
			if not previous_text.ends_with("\n"):
				write_file.store_line("")
		write_file.store_line(str(run_time_seconds))
		write_file.close()

func _save_survival_time(survived_seconds : float) -> void:
	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.ModeFlags.WRITE)
	if file:
		file.store_line(str(survived_seconds))
		file.close()

func _on_try_pressed() -> void:
	get_tree().paused = false
	main_ui.visible = false
	_set_game_over_ui_input_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()
