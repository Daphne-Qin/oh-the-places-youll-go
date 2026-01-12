extends Control

## End Screen Script
## Handles end screen button functionality and stats display

@onready var replay_button: Button = $ReplayButton
@onready var main_menu_button: Button = $MainMenuButton
@onready var quit_button: Button = $QuitButton
@onready var stats_label: Label = $StatsLabel

# Scene paths
const MAIN_MENU_SCENE = "res://scenes/MainMenu.tscn"
const LORAX_LEVEL_SCENE = "res://scenes/LoraxLevel.tscn"
const OPENING_CUTSCENE_SCENE = "res://scenes/OpeningCutscene.tscn"

# Game stats (can be loaded from GameState or saved data)
var trees_saved: int = 1  # Placeholder - replace with actual game stats

func _ready() -> void:
	"""Initialize the end screen."""
	# Connect button signals
	replay_button.pressed.connect(_on_replay_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Update stats display
	_update_stats_display()
	
	print("End Screen loaded")

func _update_stats_display() -> void:
	"""Update the stats label with current game statistics."""
	# Load stats from GameState or saved data
	# For now, using placeholder value
	stats_label.text = "Trees Saved: " + str(trees_saved)
	
	# Example: Load from GameState if available
	# if GameState.has_method("get_trees_saved"):
	#     trees_saved = GameState.get_trees_saved()
	#     stats_label.text = "Trees Saved: " + str(trees_saved)

func _on_replay_button_pressed() -> void:
	"""Handle Replay button press - restart the game."""
	print("Replaying game...")
	
	# Option 1: Go to opening cutscene
	# get_tree().change_scene_to_file(OPENING_CUTSCENE_SCENE)
	
	# Option 2: Go directly to game level
	get_tree().change_scene_to_file(LORAX_LEVEL_SCENE)
	
	# Reset game state if needed
	# GameState.reset_game()

func _on_main_menu_button_pressed() -> void:
	"""Handle Main Menu button press."""
	print("Returning to main menu...")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_quit_button_pressed() -> void:
	"""Handle Quit button press."""
	print("Quitting game...")
	get_tree().quit()
