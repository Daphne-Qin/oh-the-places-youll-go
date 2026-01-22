extends Control

## Main Menu Script
## Placeholder-based system with wobble physics, parallax scrolling, and smooth transitions
## Replace placeholder shapes with real art later

@onready var start_button: Button = $MenuLayer/ButtonContainer/StartButton
@onready var quit_button: Button = $MenuLayer/ButtonContainer/QuitButton
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

# Parallax system
@onready var parallax_background: ParallaxBackground = $ParallaxBackground
@onready var sky_layer: ParallaxLayer = $ParallaxBackground/SkyLayer
@onready var cloud_layer: ParallaxLayer = $ParallaxBackground/CloudLayer
@onready var tree_layer: ParallaxLayer = $ParallaxBackground/TreeLayer
@onready var foreground_layer: ParallaxLayer = $ParallaxBackground/ForegroundLayer

# Wobble physics system - automatically finds all wobble nodes
var wobble_elements: Array[Node2D] = []
var wobble_data: Dictionary = {}  # Stores original positions and physics properties

# Animation parameters
var parallax_scroll_speed: float = 20.0
var wobble_strength: float = 2.0
var wobble_damping: float = 0.95
var wobble_spring: float = 0.1

# Scene paths
const OPENING_CUTSCENE_SCENE = "res://scenes/OpeningCutscene.tscn"
const LORAX_LEVEL_SCENE = "res://scenes/LoraxLevel.tscn"

func _ready() -> void:
	"""Initialize the main menu systems."""
	_setup_parallax()
	_setup_wobble_physics()
	_setup_buttons()
	_start_animations()
	
	# Start background music if available
	_play_menu_theme()
	
	print("Main Menu loaded - Placeholder system ready")

func _setup_parallax() -> void:
	"""Configure parallax scrolling layers."""
	if sky_layer:
		sky_layer.motion_scale = Vector2(0.1, 0.1)
	if cloud_layer:
		cloud_layer.motion_scale = Vector2(0.3, 0.3)
	if tree_layer:
		tree_layer.motion_scale = Vector2(0.6, 0.6)
	if foreground_layer:
		foreground_layer.motion_scale = Vector2(1.0, 1.0)

func _setup_wobble_physics() -> void:
	"""Find and initialize all wobble elements."""
	_find_wobble_nodes(self)
	
	# Initialize physics data for each wobble element
	for element in wobble_elements:
		if element:
			wobble_data[element] = {
				"base_position": element.position,
				"velocity": Vector2.ZERO,
				"target_offset": Vector2.ZERO
			}
			# Add slight random initial offset for variety
			element.position += Vector2(randf_range(-1, 1), randf_range(-1, 1))

func _find_wobble_nodes(node: Node) -> void:
	"""Recursively find all nodes with 'Wobble' in their name."""
	if node.name.contains("Wobble") and node is Node2D:
		wobble_elements.append(node)
	
	for child in node.get_children():
		_find_wobble_nodes(child)

func _setup_buttons() -> void:
	"""Setup interactive buttons with smooth hover effects."""
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		start_button.mouse_entered.connect(func(): _on_button_hover(start_button, true))
		start_button.mouse_exited.connect(func(): _on_button_hover(start_button, false))
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		quit_button.mouse_entered.connect(func(): _on_button_hover(quit_button, true))
		quit_button.mouse_exited.connect(func(): _on_button_hover(quit_button, false))

func _on_button_hover(button: Button, is_hovering: bool) -> void:
	"""Smooth button hover animation."""
	if not button:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	button.pivot_offset = button.size/2
	if is_hovering:
		tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.2)
	else:
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate", Color.WHITE, 0.2)

func _start_animations() -> void:
	"""Start continuous animations."""
	# Wobble physics will be handled in _process
	# Parallax scrolling will be handled in _process

func _process(delta: float) -> void:
	"""Update continuous animations: parallax scrolling and wobble physics."""
	_update_parallax(delta)
	_update_wobble_physics(delta)

func _update_parallax(delta: float) -> void:
	"""Update parallax scrolling."""
	if parallax_background:
		parallax_background.scroll_offset.x += parallax_scroll_speed * delta
		# Loop parallax when it goes too far
		if parallax_background.scroll_offset.x > 1280:
			parallax_background.scroll_offset.x -= 1280

func _update_wobble_physics(delta: float) -> void:
	"""Update wobble physics for all wobble elements."""
	for element in wobble_elements:
		if not element or not wobble_data.has(element):
			continue
		
		var data = wobble_data[element]
		var base_pos = data["base_position"]
		var velocity = data["velocity"]
		
		# Calculate spring force towards base position
		var current_offset = element.position - base_pos
		var spring_force = -current_offset * wobble_spring
		
		# Add some random gentle force for continuous motion
		var random_force = Vector2(
			sin(Time.get_ticks_msec() * 0.001 + element.position.x * 0.01) * wobble_strength * 0.1,
			cos(Time.get_ticks_msec() * 0.0015 + element.position.y * 0.01) * wobble_strength * 0.1
		)
		
		# Update velocity with forces and damping
		velocity += (spring_force + random_force) * delta
		velocity *= wobble_damping
		
		# Update position
		element.position += velocity * delta
		
		# Update rotation based on horizontal velocity for teetering effect
		element.rotation_degrees = velocity.x * 0.5
		
		# Store updated velocity
		data["velocity"] = velocity

func _play_menu_theme() -> void:
	"""Play the cheerful menu theme music."""
	if background_music and background_music.stream:
		background_music.play()
	else:
		# Try to load menu theme from assets
		var music_path = "res://assets/audio/music/menu_theme.ogg"
		if ResourceLoader.exists(music_path):
			background_music.stream = load(music_path)
			background_music.play()
		else:
			print("Menu theme not found. Add music to: assets/audio/music/menu_theme.ogg")

func _on_start_button_pressed() -> void:
	"""Handle Start Demo button press with smooth transition."""
	print("Starting demo...")
	
	# Smooth button press animation
	if start_button:
		var tween = create_tween()
		tween.tween_property(start_button, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.1)
		await tween.finished
	
	# Smooth scene transition
	_transition_to_scene(LORAX_LEVEL_SCENE)

func _on_quit_button_pressed() -> void:
	"""Handle Quit button press with smooth transition."""
	print("Quitting game...")
	
	# Smooth button press animation
	if quit_button:
		var tween = create_tween()
		tween.tween_property(quit_button, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(quit_button, "scale", Vector2(1.0, 1.0), 0.1)
		await tween.finished
	
	get_tree().quit()

func _transition_to_scene(scene_path: String) -> void:
	"""Smooth fade transition to another scene."""
	# Create fade overlay
	var fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.color.a = 0.0
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_overlay)
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 0.3)
	await fade_tween.finished
	
	# Change scene
	get_tree().change_scene_to_file(scene_path)
