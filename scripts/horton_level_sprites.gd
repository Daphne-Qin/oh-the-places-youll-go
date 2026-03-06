extends Node2D

## Sprite / animation controller for the Horton level.
## Handles entrances and all story-driven animations for Horton and Baron.

# Save Horton's resting X so he can return after a chase
var _horton_resting_x: float = 300.0

func _ready() -> void:
	pass

# ---------------------------------------------------------------------------
# Horton entrance — walks in from the left
# ---------------------------------------------------------------------------
func horton_enter() -> void:
	$Horton.position.x = -400
	$Horton/AnimatedSprite2D.flip_h = false
	$Horton/AnimatedSprite2D.play("walk_noclover")
	var tween = create_tween()
	tween.tween_property($Horton, "position:x", 300.0, 3.0).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		$Horton/AnimatedSprite2D.stop()
		_horton_resting_x = $Horton.position.x
	)

# ---------------------------------------------------------------------------
# Baron entrance — strolls in from the right, then patrols
# ---------------------------------------------------------------------------
func baron_enter() -> void:
	$Baron.visible = true
	$Baron.position = Vector2(1400.0, 520.0)
	$Baron.move()
	$Baron.sprite.flip_h = true  # face left on entry

	var tween = create_tween()
	tween.tween_property($Baron, "position:x", 850.0, 3.5).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		$Baron.sprite.flip_h = false
		$Baron.start_patrol(650.0, 1000.0, 55.0)
	)

# ---------------------------------------------------------------------------
# CHASE: Baron charges at Horton — Horton flees left
# ---------------------------------------------------------------------------
func baron_chase_horton() -> void:
	if not is_instance_valid($Horton) or not is_instance_valid($Baron):
		return

	_horton_resting_x = $Horton.position.x
	var flee_x = max(-900.0, $Horton.position.x - 350.0)

	# Horton flees
	$Horton/AnimatedSprite2D.flip_h = true   # face left (fleeing)
	$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 24.0)
	$Horton/AnimatedSprite2D.play("walk_noclover")
	var horton_tween = create_tween()
	horton_tween.tween_property($Horton, "position:x", flee_x, 2.2).set_ease(Tween.EASE_IN)

	# Baron charges
	$Baron.stop_patrol()
	$Baron.sprite.flip_h = true   # face left (toward Horton)
	$Baron.sprite.speed_scale = 2.5
	$Baron.move()
	var baron_tween = create_tween()
	baron_tween.tween_property($Baron, "position:x", flee_x + 120.0, 2.8).set_ease(Tween.EASE_IN)

# ---------------------------------------------------------------------------
# CHASE RESOLVED: Player intervenes — Baron backs off, Horton returns
# ---------------------------------------------------------------------------
func baron_back_off() -> void:
	if not is_instance_valid($Baron):
		return

	# Baron retreats to patrol zone
	$Baron.sprite.flip_h = false
	$Baron.sprite.speed_scale = 1.0
	var baron_tween = create_tween()
	baron_tween.tween_property($Baron, "position:x", 800.0, 2.0).set_ease(Tween.EASE_OUT)
	baron_tween.finished.connect(func():
		$Baron.sprite.speed_scale = 1.0
		$Baron.start_patrol(650.0, 1000.0, 55.0)
	)

	# Horton returns to his resting spot
	if is_instance_valid($Horton):
		$Horton/AnimatedSprite2D.flip_h = false
		$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 12.0)
		$Horton/AnimatedSprite2D.play("walk_noclover")
		var horton_tween = create_tween()
		horton_tween.tween_property($Horton, "position:x", _horton_resting_x, 2.2).set_ease(Tween.EASE_OUT)
		horton_tween.finished.connect(func():
			$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 12.0)
			$Horton/AnimatedSprite2D.stop()
		)

# ---------------------------------------------------------------------------
# CHASE FAILED: Baron grabs the clover
# ---------------------------------------------------------------------------
func baron_grab_clover() -> void:
	if not is_instance_valid($Baron):
		return

	# Baron stops triumphant
	$Baron.stop_patrol()
	$Baron.sprite.speed_scale = 1.0
	$Baron.stand()

	# Horton slumps — stop walking, face forward
	if is_instance_valid($Horton):
		$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 12.0)
		$Horton/AnimatedSprite2D.stop()
		$Horton/AnimatedSprite2D.flip_h = false

# ---------------------------------------------------------------------------
# BARON DROPS CLOVER: theatrical drop animation
# ---------------------------------------------------------------------------
func baron_drops_clover_visual() -> void:
	if not is_instance_valid($Baron):
		return

	# Small dramatic hop-down to indicate dropping something
	$Baron.stop_patrol()
	$Baron.stand()
	var orig_y = $Baron.position.y
	var tween = create_tween()
	tween.tween_property($Baron, "position:y", orig_y + 15.0, 0.12)
	tween.tween_property($Baron, "position:y", orig_y, 0.12)

# ---------------------------------------------------------------------------
# HORTON RECLAIMS CLOVER: quick happy bounce
# ---------------------------------------------------------------------------
func horton_reclaim_clover() -> void:
	if not is_instance_valid($Horton):
		return
	horton_react_happy()
	_horton_resting_x = $Horton.position.x

# ---------------------------------------------------------------------------
# Horton story-beat helpers
# ---------------------------------------------------------------------------
func horton_react_happy() -> void:
	if not is_instance_valid($Horton):
		return
	$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 24.0)
	$Horton/AnimatedSprite2D.play("walk_noclover")
	await get_tree().create_timer(1.5).timeout
	$Horton/AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", 12.0)
	$Horton/AnimatedSprite2D.stop()

# ---------------------------------------------------------------------------
# Baron story-beat methods (called by horton_chat.gd via sprites_node)
# ---------------------------------------------------------------------------
func baron_make_move_for_clover() -> void:
	if not is_instance_valid($Baron):
		return
	$Baron.make_move_for_clover(320.0)

func baron_defeat_retreat() -> void:
	if not is_instance_valid($Baron):
		return
	$Baron.defeat_retreat()

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
func get_baron_global_position() -> Vector2:
	if is_instance_valid($Baron):
		return $Baron.global_position
	return Vector2.ZERO

func get_horton_global_position() -> Vector2:
	if is_instance_valid($Horton):
		return $Horton.global_position
	return Vector2.ZERO
