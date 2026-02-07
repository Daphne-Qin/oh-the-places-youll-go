extends Control

## Level Selector - Clickable map to navigate between levels
## Dynamically creates level buttons based on GameState.levels

@onready var map_container: Control = $Map
var level_buttons: Dictionary = {}  # level_id -> Button node

func _ready() -> void:
	$Map.hide()
	# Create level buttons when ready
	_create_level_buttons()
	# Connect to level unlock signals to update button states
	GameState.level_unlocked.connect(_on_level_unlocked)
	GameState.level_completed.connect(_on_level_completed)

func _create_level_buttons() -> void:
	"""Dynamically create clickable buttons for each level on the map."""
	for level_id in GameState.levels:
		var level_data = GameState.levels[level_id]
		var button = _create_level_button(level_id, level_data)
		level_buttons[level_id] = button
		map_container.add_child(button)

	# Update all button states
	_update_all_button_states()

func _create_level_button(level_id: String, level_data: Dictionary) -> Button:
	"""Create a styled button for a level."""
	var button = Button.new()
	button.name = "Level_" + level_id
	button.text = level_data.name
	button.position = level_data.map_position
	button.custom_minimum_size = Vector2(120, 50)

	# Style the button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.5, 0.3, 0.9)  # Forest green
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.border_width_left = 3
	style_normal.border_width_top = 3
	style_normal.border_width_right = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(0.1, 0.3, 0.1)

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.3, 0.6, 0.4, 1.0)

	var style_locked = style_normal.duplicate()
	style_locked.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	style_locked.border_color = Color(0.2, 0.2, 0.2)

	var style_completed = style_normal.duplicate()
	style_completed.bg_color = Color(0.6, 0.8, 0.3, 0.9)  # Bright green for completed
	style_completed.border_color = Color(0.4, 0.6, 0.2)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_hover)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color.WHITE)

	# Store styles for later state updates
	button.set_meta("style_normal", style_normal)
	button.set_meta("style_locked", style_locked)
	button.set_meta("style_completed", style_completed)
	button.set_meta("style_hover", style_hover)
	button.set_meta("level_id", level_id)

	# Connect button press
	button.pressed.connect(_on_level_button_pressed.bind(level_id))

	return button

func _update_all_button_states() -> void:
	"""Update visual state of all level buttons."""
	for level_id in level_buttons:
		_update_button_state(level_id)

func _update_button_state(level_id: String) -> void:
	"""Update a single button's visual state based on unlock/completion status."""
	if not level_buttons.has(level_id):
		return

	var button = level_buttons[level_id]
	var level_data = GameState.levels[level_id]
	var is_unlocked = level_data.unlocked
	var is_completed = level_data.completed

	if is_completed:
		button.add_theme_stylebox_override("normal", button.get_meta("style_completed"))
		button.add_theme_stylebox_override("hover", button.get_meta("style_completed"))
		button.text = level_data.name + " ✓"
		button.disabled = false
	elif is_unlocked:
		button.add_theme_stylebox_override("normal", button.get_meta("style_normal"))
		button.add_theme_stylebox_override("hover", button.get_meta("style_hover"))
		button.text = level_data.name
		button.disabled = false
	else:
		button.add_theme_stylebox_override("normal", button.get_meta("style_locked"))
		button.add_theme_stylebox_override("hover", button.get_meta("style_locked"))
		button.text = level_data.name + " 🔒"
		button.disabled = true

func _on_level_button_pressed(level_id: String) -> void:
	"""Handle level button click."""
	print("[LevelSelector] Level clicked: ", level_id)
	if GameState.is_level_unlocked(level_id):
		# Close the map first
		$Map.hide()
		# Small delay for visual feedback
		await get_tree().create_timer(0.2).timeout
		# Navigate to level
		GameState.go_to_level(level_id)
	else:
		print("[LevelSelector] Level is locked!")
		# Could add a "locked" sound effect or shake animation here

func _on_level_unlocked(level_id: String) -> void:
	"""Called when a level is unlocked."""
	_update_button_state(level_id)
	# Could add unlock animation/sound here

func _on_level_completed(level_id: String) -> void:
	"""Called when a level is completed."""
	_update_button_state(level_id)

func _on_open_selector_button_pressed() -> void:
	"""Toggle map visibility."""
	if $Map.visible:
		$Map.hide()
	else:
		# Refresh button states when opening
		_update_all_button_states()
		$Map.show()
