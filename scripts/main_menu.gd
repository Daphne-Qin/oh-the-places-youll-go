extends Control

## Main Menu Script
## Handles button functionality and menu theme music

@onready var start_button: Button = $ButtonContainer/StartButton
@onready var quit_button: Button = $ButtonContainer/QuitButton
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

# Scene paths
const OPENING_CUTSCENE_SCENE = "res://scenes/OpeningCutscene.tscn"
const LORAX_LEVEL_SCENE = "res://scenes/LoraxLevel.tscn"

func _ready() -> void:
	"""Initialize the main menu."""
	# Connect button signals
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
	else:
		print("Error: StartButton not found!")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
	else:
		print("Error: QuitButton not found!")
	
	# Start background music if available
	_play_menu_theme()
	
	print("Main Menu loaded")

func _play_menu_theme() -> void:
	"""Play the cheerful menu theme music."""
	if background_music.stream:
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
	"""Handle Start Demo button press."""
	print("Starting demo...")
	
	# Option 1: Go directly to opening cutscene
	# get_tree().change_scene_to_file(OPENING_CUTSCENE_SCENE)
	
	# Option 2: Go directly to game level (skip cutscene)
	get_tree().change_scene_to_file(LORAX_LEVEL_SCENE)
	
	# Option 3: Go to opening cutscene, then transition to level
	# (You can handle this in the opening cutscene script)

func _on_quit_button_pressed() -> void:
	"""Handle Quit button press."""
	print("Quitting game...")
	get_tree().quit()
