extends Node

## Example: How to use the APIManager singleton
## This demonstrates the complete workflow for generating and validating riddles

# Example usage in your game script:

func _ready() -> void:
	# Connect to API Manager signals
	APIManager.riddle_generated.connect(_on_riddle_generated)
	APIManager.riddle_generation_failed.connect(_on_riddle_failed)
	APIManager.answer_validated.connect(_on_answer_validated)
	APIManager.answer_validation_failed.connect(_on_answer_validation_failed)

func request_new_riddle() -> void:
	"""Request a new riddle from the API."""
	print("Requesting riddle from API...")
	APIManager.generate_riddle()

func _on_riddle_generated(riddle_text: String) -> void:
	"""Called when a riddle is successfully generated."""
	print("Riddle received: ", riddle_text)
	# Display the riddle to the player
	# show_riddle_to_player(riddle_text)

func _on_riddle_failed(error_message: String) -> void:
	"""Called when riddle generation fails."""
	print("Failed to generate riddle: ", error_message)
	# The API manager will automatically use a fallback riddle
	# You can still check the signal to show an error message if needed

func submit_answer(riddle_text: String, player_answer: String) -> void:
	"""Submit a player's answer for validation."""
	print("Validating answer: ", player_answer, " for riddle: ", riddle_text)
	APIManager.validate_answer(riddle_text, player_answer)

func _on_answer_validated(result: String) -> void:
	"""Called when answer validation completes."""
	if result == "CORRECT":
		print("Correct answer! Well done!")
		# handle_correct_answer()
	else:
		# result will be "INCORRECT: [hint]"
		print("Incorrect: ", result)
		# Extract hint if needed
		if result.begins_with("INCORRECT: "):
			var hint = result.substr(12)  # Remove "INCORRECT: " prefix
			print("Hint: ", hint)
		# handle_incorrect_answer(result)

func _on_answer_validation_failed(error_message: String) -> void:
	"""Called when answer validation fails."""
	print("Failed to validate answer: ", error_message)
	# Handle error (API manager may use basic validation as fallback)

# Complete example workflow:
func example_workflow() -> void:
	"""Example of the complete riddle workflow."""
	# Step 1: Request a riddle
	request_new_riddle()
	
	# Step 2: Wait for riddle (handled by signal)
	# Step 3: Player enters answer
	# Step 4: Validate answer
	# submit_answer("What am I?", "tree")
	
	# Step 5: Handle result (handled by signal)
