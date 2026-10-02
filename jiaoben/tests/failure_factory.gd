extends RefCounted
## Test-only null return injection. Formal assets and catalog remain untouched.
const Real = preload("res://runtime/visuals/industrial_visual_factory.gd")
static var reject_player: bool = false
static var reject_enemy: bool = false
static var player_calls: int = 0
static var enemy_calls: int = 0

static func scene(ship_id: String) -> CharacterBody3D:
	player_calls += 1
	return null if reject_player else Real.scene(ship_id)

static func enemy_scene(archetype: String) -> CharacterBody3D:
	enemy_calls += 1
	return null if reject_enemy else Real.enemy_scene(archetype)
