extends Area2D

## Baron Von Bitey — the aristocratic capybara antagonist
## Manages Baron's sprite animations and in-world movement.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Patrol state
var _patrol_tween: Tween = null
var _patrol_min_x: float = 650.0
var _patrol_max_x: float = 950.0
var _patrol_speed: float = 60.0   # pixels per second (walk pace)
var _is_patrolling: bool = false
var _patrol_direction: int = -1    # -1 left, 1 right

func _ready() -> void:
	walk()

func walk(speed: float = 20.0) -> void:
	"""Play the walk animation (used on ready and for patrol)."""
	sprite.sprite_frames.set_animation_speed("walk", speed)
	sprite.play("walk")

func idle_noclover(speed: float = 20.0) -> void:
	"""Play the stand/idle animation where Baron does not have the clover."""
	sprite.sprite_frames.set_animation_speed("idle_noclover", speed)
	sprite.play("idle_noclover")

func idle_clover(speed: float = 20.0) -> void:
	"""Play the stand/idle animation where Baron has the clover."""
	sprite.sprite_frames.set_animation_speed("idle_clover", speed)
	sprite.play("idle_clover")

func flip_h(value: bool):
	sprite.flip_h = value

# ---------------------------------------------------------------------------
# Patrol — Baron paces back and forth between two x positions
# ---------------------------------------------------------------------------
func start_patrol(min_x: float = 600, max_x: float = 980, speed: float = 60.0) -> void:
	"""Begin Baron's circling patrol around the clover area."""
	_patrol_min_x = min_x
	_patrol_max_x = max_x
	_patrol_speed = speed
	_is_patrolling = true
	walk(24)
	_do_patrol_step()

func _do_patrol_step() -> void:
	if not _is_patrolling:
		return

	# Pick next target
	var target_x: float
	if _patrol_direction == 1:
		target_x = _patrol_max_x
	else:
		target_x = _patrol_min_x
	_patrol_direction *= -1  # flip for next step

	# Flip sprite to face direction of travel
	sprite.flip_h = (target_x < position.x)

	var distance = abs(target_x - position.x)
	var duration = distance / _patrol_speed if _patrol_speed > 0 else 1.0

	if _patrol_tween:
		_patrol_tween.kill()
	_patrol_tween = create_tween()
	_patrol_tween.tween_property(self, "position:x", target_x, duration)
	_patrol_tween.finished.connect(_do_patrol_step, CONNECT_ONE_SHOT)

func stop_patrol() -> void:
	"""Stop patrolling and stand still."""
	_is_patrolling = false
	if _patrol_tween:
		_patrol_tween.kill()
	idle_noclover()

# ---------------------------------------------------------------------------
# Escalation — run toward the clover (Horton's position area)
# ---------------------------------------------------------------------------
func make_move_for_clover(clover_x: float = 310.0) -> void:
	"""Baron charges toward the clover at high speed."""
	_is_patrolling = false
	if _patrol_tween:
		_patrol_tween.kill()

	walk(48)
	sprite.flip_h = (clover_x < position.x)

	var distance = abs(clover_x - position.x)
	var duration = distance / 250.0  # fast run speed

	var tween = create_tween()
	tween.tween_property(self, "position:x", clover_x, duration)

# ---------------------------------------------------------------------------
# Defeat — Baron stumbles and retreats off-screen
# ---------------------------------------------------------------------------
func defeat_retreat() -> void:
	_is_patrolling = false
	if _patrol_tween:
		_patrol_tween.kill()

	walk(24)
	sprite.flip_h = false

	var stagger_x = position.x - 80.0
	var stagger_y = position.y + 30.0

	var stumble = create_tween()
	stumble.set_parallel(true)
	stumble.tween_property(self, "position:x", stagger_x, 0.3).set_ease(Tween.EASE_OUT)
	stumble.tween_property(self, "position:y", stagger_y, 0.3)
	stumble.set_parallel(false)  # back to sequential after the parallel block
	stumble.tween_interval(0.2)  # replaces the await timer
	stumble.tween_property(self, "position:x", 1600.0, 1.4).set_ease(Tween.EASE_IN)
	stumble.tween_callback(func(): visible = false)
