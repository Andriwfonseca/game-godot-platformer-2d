extends Camera2D

var target: Node2D

@export var smooth_factor: float = 0.1

func _ready() -> void:
	get_target()

func _process(_delta: float) -> void:
	camera_follow_target()

func get_target() -> void:
	target = get_tree().get_first_node_in_group("Player")

	if not target:
		push_error("Camera: Player not found")

func camera_follow_target() -> void:
	var target_position = lerp(position, target.position, smooth_factor)
	position = target_position
