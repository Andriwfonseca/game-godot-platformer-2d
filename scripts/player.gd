extends CharacterBody2D

# Variáveis de movimento
const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Gravidade do projeto (obtida das configurações)
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# Aplicar gravidade quando não estiver no chão
	if not is_on_floor():
		velocity.y += gravity * delta

	# Detectar pulo (quando está no chão)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Detectar movimento horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Aplicar o movimento
	move_and_slide()
