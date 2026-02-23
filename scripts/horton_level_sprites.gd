extends Node2D

## Sprite / animation controller for the Horton level.
## Handles entrances and story-driven animation states for both Horton and Baron.

func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# Horton entrance
# ---------------------------------------------------------------------------
func horton_enter() -> void:
	"""Horton walks in from the left side of the screen."""
	$Horton.position.x = -400
	$Horton/AnimatedSprite2D.play("walk")
	var tween = create_tween()
	tween.tween_property($Horton, "position:x", 300.0, 3.0)
	tween.finished.connect(func():
		$Horton/AnimatedSprite2D.stop()
	)

# ---------------------------------------------------------------------------
# Baron entrance — walks in from off-screen right, then patrols
# ---------------------------------------------------------------------------
func baron_enter() -> void:
	"""Baron strolls in from the right side of the screen, then starts patrolling."""
	$Baron.visible = true
	$Baron.position = Vector2(1400.0, 520.0)
	$Baron.move()          # start walk animation via baron.gd
	$Baron.sprite.flip_h = true  # face left on entry

	var tween = create_tween()
	tween.tween_property($Baron, "position:x", 850.0, 3.5).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		$Baron.sprite.flip_h = false
		$Baron.start_patrol(650.0, 1000.0, 55.0)
	)

# ---------------------------------------------------------------------------
# Baron story-beat methods (called by horton_chat.gd via sprites_node)
# ---------------------------------------------------------------------------
func baron_make_move_for_clover() -> void:
	"""Baron charges toward Horton's clover — fail state 1 animation."""
	if not is_instance_valid($Baron):
		return
	$Baron.make_move_for_clover(320.0)

func baron_defeat_retreat() -> void:
	"""Baron is defeated by Whoville noise and flees off-screen — win state animation."""
	if not is_instance_valid($Baron):
		return
	$Baron.defeat_retreat()

# ---------------------------------------------------------------------------
# Horton story-beat methods
# ---------------------------------------------------------------------------
func horton_react_happy() -> void:
	"""Horton does a quick celebratory bounce."""
	if not is_instance_valid($Horton):
		return
	$Horton/AnimatedSprite2D.speed_scale = 2.0
	$Horton/AnimatedSprite2D.play("walk")
	await get_tree().create_timer(1.5).timeout
	$Horton/AnimatedSprite2D.speed_scale = 1.0
	$Horton/AnimatedSprite2D.stop()
