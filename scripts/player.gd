extends CharacterBody2D

# onready (quando carregar a cena) para pegar o componente AnimatedSprite2D
# $AnimatedSprite2D é o nome do componente na cena ($ + o nome)
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

@export var next_level_name: String

@export var max_level_limit_x: int = 0
@export var min_level_limit_x: int = 5
@export var level_limit_y: int = 208

# Variáveis de movimento
const SPEED = 80.0
const JUMP_VELOCITY = -300.0

# physics_process é chamado a cada frame
func _physics_process(delta):
	# Aplicar gravidade quando não estiver no chão
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Detectar pulo (quando está no chão)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Detectar movimento horizontal
	var direction = Input.get_axis("left", "right")
	move_player(direction)

	# animação
	if is_on_floor():
		if direction > 0:
			anim.flip_h = false
			anim.play("walk")
		elif direction < 0:
			anim.flip_h = true
			anim.play("walk")
		else:
			anim.play("idle")
	else:
		anim.play("jump")


	# Aplicar o movimento
	move_and_slide()

	# ir para o próximo nível
	if position.x > max_level_limit_x:
		go_to_next_level()

func move_player(direction: int) -> void:
	if direction > 0 and position.x < max_level_limit_x + 10:
		velocity.x = direction * SPEED
	elif direction < 0 and position.x > min_level_limit_x:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

func go_to_next_level() -> void:
	if next_level_name == "":
		push_error("Next level name is empty")
		return

	var path_next_level = "res://scenes/" + next_level_name + ".tscn"
	get_tree().change_scene_to_file(path_next_level)
