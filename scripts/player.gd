extends CharacterBody2D

# onready (quando carregar a cena) para pegar o componente AnimatedSprite2D
# $AnimatedSprite2D é o nome do componente na cena ($ + o nome)
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

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
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

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
