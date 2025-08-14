# 🌐 Tutorial Completo: Jogo de Plataforma Multiplayer Online no Godot

> **📌 Objetivo:** Transformar o jogo de plataforma simples em um multiplayer online onde vários jogadores podem jogar juntos em tempo real

---

## 📚 Índice

- [ ] **Conceitos de Networking**
- [ ] **Configuração do Projeto**
- [ ] **Sistema de Servidor e Cliente**
- [ ] **Sincronização de Players**
- [ ] **Interface de Conexão**
- [ ] **Sistema de Chat**
- [ ] **Testes e Deploy**
- [ ] **Melhorias Avançadas**

---

# 🎯 1. Conceitos de Networking no Godot

> **💡 Info:** Entenda como funciona o multiplayer online no Godot

## **🔧 Arquitetura Client-Server**

- **Servidor (Host)**: Controla o estado do jogo e sincroniza todos os clientes
- **Cliente**: Conecta ao servidor e envia inputs do jogador
- **Authority**: Sistema que define quem controla cada objeto

## **📡 Tipos de Comunicação**

- **RPC (Remote Procedure Call)**: Chama funções em outros peers
- **MultiplayerSpawner**: Spawna objetos automaticamente na rede
- **MultiplayerSynchronizer**: Sincroniza propriedades automaticamente

## **🔒 Conceitos Importantes**

- **Peer ID**: Identificador único de cada jogador
- **Authority**: Quem tem controle sobre um objeto
- **Reliability**: Garantia de entrega de mensagens
- **Ordering**: Ordem de chegada das mensagens

---

# ⚙️ 2. Configuração do Projeto

> **🎯 Meta:** Preparar o projeto para suporte a multiplayer

## **📁 1. Estrutura de Pastas**

Crie a seguinte estrutura:

```
scenes/
├── game.tscn              # Cena principal
├── player.tscn            # Player (já existe)
├── multiplayer_player.tscn # Player para multiplayer
├── main_menu.tscn         # Menu principal
└── game_multiplayer.tscn  # Cena do jogo multiplayer

scripts/
├── player.gd              # Script do player local
├── multiplayer_player.gd  # Player multiplayer
├── network_manager.gd     # Gerenciador de rede
├── main_menu.gd          # Menu principal
└── game_manager.gd       # Gerenciador do jogo

autoload/
└── network_autoload.gd   # Singleton de rede
```

## **🔧 2. Configurar Autoload**

1. Vá em **Projeto → Configurações do Projeto**
2. Aba **AutoLoad**
3. Adicione:
   - **Path**: `res://autoload/network_autoload.gd`
   - **Name**: `NetworkManager`
   - **Singleton**: ✓ (marcado)

---

# 🎮 3. Sistema de Servidor e Cliente

> **🎯 Meta:** Criar a base do sistema de networking

## **🚀 Passo 1: NetworkManager Singleton**

Crie `autoload/network_autoload.gd`:

```gdscript
extends Node

# Sinais para comunicação
signal player_connected(peer_id, player_info)
signal player_disconnected(peer_id)
signal server_disconnected

# Configurações de rede
const DEFAULT_PORT = 7000
const MAX_CLIENTS = 10

# Variáveis de estado
var multiplayer_peer: ENetMultiplayerPeer
var players = {}
var player_info = {"name": "Player"}

func _ready():
	# Conectar sinais do multiplayer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# Criar servidor
func create_server(port = DEFAULT_PORT):
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(port, MAX_CLIENTS)

	if error == OK:
		multiplayer.multiplayer_peer = multiplayer_peer
		print("Servidor criado na porta ", port)

		# Adicionar o host como jogador
		players[1] = player_info
		return true
	else:
		print("Erro ao criar servidor: ", error)
		return false

# Conectar ao servidor
func join_server(address = "127.0.0.1", port = DEFAULT_PORT):
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_client(address, port)

	if error == OK:
		multiplayer.multiplayer_peer = multiplayer_peer
		print("Tentando conectar a ", address, ":", port)
		return true
	else:
		print("Erro ao conectar: ", error)
		return false

# Desconectar
func disconnect_from_game():
	if multiplayer_peer:
		multiplayer_peer.close()
		multiplayer_peer = null
	players.clear()

# Definir informações do jogador
func set_player_info(name: String):
	player_info.name = name

# Callbacks de conexão
func _on_player_connected(id):
	print("Jogador conectado: ", id)

	# Enviar info do jogador para o servidor
	if not multiplayer.is_server():
		_register_player.rpc_id(1, player_info)

func _on_player_disconnected(id):
	print("Jogador desconectado: ", id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server():
	print("Conectado ao servidor!")

func _on_connection_failed():
	print("Falha na conexão!")

func _on_server_disconnected():
	print("Servidor desconectado!")
	server_disconnected.emit()

# RPC para registrar jogador
@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var id = multiplayer.get_remote_sender_id()
	players[id] = new_player_info

	# Notificar todos os clientes
	_player_registered.rpc(id, new_player_info)

	# Enviar lista de jogadores existentes para o novo jogador
	for existing_id in players:
		if existing_id != id:
			_player_registered.rpc_id(id, existing_id, players[existing_id])

@rpc("authority", "reliable")
func _player_registered(id, new_player_info):
	players[id] = new_player_info
	player_connected.emit(id, new_player_info)
```

## **🎮 Passo 2: Player Multiplayer**

Crie `scripts/multiplayer_player.gd`:

```gdscript
extends CharacterBody2D

# Variáveis de movimento
const SPEED = 200.0
const JUMP_VELOCITY = -400.0

# Multiplayer
@export var player_id: int = 1
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Componentes
@onready var sprite = $Sprite2D
@onready var label = $Label

# Sincronização
var input_direction = 0.0
var jump_pressed = false

func _ready():
	# Configurar autoridade
	set_multiplayer_authority(player_id)

	# Configurar aparência baseada no ID
	_setup_player_appearance()

	# Mostrar nome do jogador
	if player_id in NetworkManager.players:
		label.text = NetworkManager.players[player_id].name
	else:
		label.text = "Player " + str(player_id)

func _setup_player_appearance():
	# Cores diferentes para cada jogador
	var colors = [Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Color.PURPLE, Color.ORANGE]
	sprite.modulate = colors[player_id % colors.size()]

func _physics_process(delta):
	# Apenas o dono do player processa input e física
	if not is_multiplayer_authority():
		return

	# Capturar input
	_handle_input()

	# Aplicar física
	_apply_physics(delta)

	# Aplicar movimento
	move_and_slide()

func _handle_input():
	# Detectar pulo
	jump_pressed = Input.is_action_just_pressed("ui_accept") and is_on_floor()

	# Detectar movimento horizontal
	input_direction = Input.get_axis("ui_left", "ui_right")

func _apply_physics(delta):
	# Aplicar gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# Pulo
	if jump_pressed:
		velocity.y = JUMP_VELOCITY

	# Movimento horizontal
	if input_direction != 0:
		velocity.x = input_direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
```

## **🌍 Passo 3: Cena do Player Multiplayer**

1. **Criar nova cena**: `scenes/multiplayer_player.tscn`
2. **Estrutura**:

```
MultiplayerPlayer (CharacterBody2D) [script: multiplayer_player.gd]
├── Sprite2D
├── CollisionShape2D
├── Label (para mostrar nome)
└── MultiplayerSynchronizer
```

3. **Configurar MultiplayerSynchronizer**:
   - **Root Path**: `..` (aponta para o CharacterBody2D)
   - **Replication**:
     - `position` - ✓
     - `velocity` - ✓
     - `input_direction` - ✓
     - `jump_pressed` - ✓

---

# 🏗️ 4. Sincronização de Players

> **🎯 Meta:** Garantir que todos os players vejam uns aos outros

## **🎮 Passo 1: Game Manager**

Crie `scripts/game_manager.gd`:

```gdscript
extends Node

# Spawner de players
@onready var players_container = $PlayersContainer
@onready var multiplayer_spawner = $MultiplayerSpawner

# Cena do player
const PLAYER_SCENE = preload("res://scenes/multiplayer_player.tscn")

func _ready():
	# Conectar sinais do NetworkManager
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

	# Se for servidor, spawnar todos os players existentes
	if multiplayer.is_server():
		for id in NetworkManager.players:
			_spawn_player(id)

func _on_player_connected(peer_id, player_info):
	if multiplayer.is_server():
		_spawn_player(peer_id)

func _on_player_disconnected(peer_id):
	# Remover player da cena
	var player_node = players_container.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

func _spawn_player(peer_id):
	# Criar instância do player
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id

	# Posição inicial (pode ser aleatória ou fixa)
	player.position = Vector2(100 + (peer_id * 50), 400)

	# Adicionar à cena
	players_container.add_child(player, true)
```

## **🌍 Passo 2: Cena do Jogo Multiplayer**

Crie `scenes/game_multiplayer.tscn`:

```
GameMultiplayer (Node2D) [script: game_manager.gd]
├── Ground (StaticBody2D)
│   ├── Sprite2D
│   └── CollisionShape2D
├── PlayersContainer (Node2D)
├── MultiplayerSpawner
│   ├── spawn_path: ../PlayersContainer
│   └── player_scene: res://scenes/multiplayer_player.tscn
└── UI
    └── ChatContainer (VBoxContainer)
```

---

# 🎮 5. Interface de Conexão

> **🎯 Meta:** Criar menu para conectar ao jogo

## **🎨 Passo 1: Menu Principal**

Crie `scripts/main_menu.gd`:

```gdscript
extends Control

# UI Elements
@onready var player_name_input = $VBox/PlayerNameInput
@onready var host_button = $VBox/HostButton
@onready var join_button = $VBox/JoinButton
@onready var ip_input = $VBox/IPInput
@onready var status_label = $VBox/StatusLabel

func _ready():
	# Conectar sinais
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	# Conectar sinais do NetworkManager
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed():
	var player_name = player_name_input.text
	if player_name.strip_edges() == "":
		_show_status("Digite um nome válido!")
		return

	NetworkManager.set_player_info(player_name)

	if NetworkManager.create_server():
		_show_status("Servidor criado! Aguardando jogadores...")
		_start_game()
	else:
		_show_status("Erro ao criar servidor!")

func _on_join_pressed():
	var player_name = player_name_input.text
	var ip_address = ip_input.text

	if player_name.strip_edges() == "":
		_show_status("Digite um nome válido!")
		return

	if ip_address.strip_edges() == "":
		ip_address = "127.0.0.1"

	NetworkManager.set_player_info(player_name)

	if NetworkManager.join_server(ip_address):
		_show_status("Conectando...")
	else:
		_show_status("Erro ao conectar!")

func _on_player_connected(peer_id, player_info):
	if multiplayer.is_server():
		_show_status("Jogador conectado: " + player_info.name)

		# Se for o primeiro cliente, iniciar o jogo
		if NetworkManager.players.size() >= 2:
			_start_game()

func _on_server_disconnected():
	_show_status("Desconectado do servidor!")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _start_game():
	# Trocar para a cena do jogo multiplayer
	get_tree().change_scene_to_file("res://scenes/game_multiplayer.tscn")

func _show_status(message: String):
	status_label.text = message
	print(message)
```

## **🎨 Passo 2: Cena do Menu**

Crie `scenes/main_menu.tscn`:

```
MainMenu (Control) [script: main_menu.gd]
└── VBox
    ├── Title (Label) - "Plataforma Multiplayer"
    ├── PlayerNameInput (LineEdit) - placeholder: "Seu nome"
    ├── HostButton (Button) - "Criar Servidor"
    ├── IPInput (LineEdit) - placeholder: "IP do servidor (opcional)"
    ├── JoinButton (Button) - "Conectar"
    └── StatusLabel (Label)
```

---

# 💬 6. Sistema de Chat

> **🎯 Meta:** Permitir comunicação entre jogadores

## **💻 Passo 1: Chat Manager**

Adicione ao `game_manager.gd`:

```gdscript
# Chat system
@onready var chat_container = $UI/ChatContainer
@onready var chat_log = $UI/ChatContainer/ChatLog
@onready var chat_input = $UI/ChatContainer/ChatInput
@onready var send_button = $UI/ChatContainer/SendButton

func _ready():
	# ... código existente ...

	# Configurar chat
	_setup_chat()

func _setup_chat():
	send_button.pressed.connect(_on_send_message)
	chat_input.text_submitted.connect(_on_chat_submitted)

func _on_send_message():
	var message = chat_input.text.strip_edges()
	if message != "":
		_send_chat_message(message)
		chat_input.text = ""

func _on_chat_submitted(text: String):
	_on_send_message()

func _send_chat_message(message: String):
	var player_name = NetworkManager.players[multiplayer.get_unique_id()].name
	var full_message = player_name + ": " + message

	# Enviar para todos
	_receive_chat_message.rpc(full_message)

@rpc("any_peer", "reliable")
func _receive_chat_message(message: String):
	# Adicionar mensagem ao log
	chat_log.text += message + "\n"

	# Scroll para baixo
	await get_tree().process_frame
	var scroll = chat_log.get_parent()
	if scroll is ScrollContainer:
		scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
```

---

# 🧪 7. Testes e Deploy

> **🎯 Meta:** Testar e preparar para distribuição

## **🔍 Passo 1: Testes Locais**

### **Teste com múltiplas instâncias**

1. **Build do projeto**:

   - **Projeto → Exportar**
   - Configurar preset para sua plataforma
   - **Exportar Projeto**

2. **Executar múltiplas instâncias**:
   - Execute o jogo exportado
   - Execute também pelo editor (F5)
   - Um cria servidor, outro conecta

### **Comandos de debug**

Adicione ao `network_autoload.gd`:

```gdscript
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print("Players conectados: ", players.size())
			KEY_F2:
				print("Peer ID: ", multiplayer.get_unique_id())
			KEY_F3:
				print("É servidor: ", multiplayer.is_server())
```

## **🌐 Passo 2: Deploy Online**

### **Opções de Hospedagem**

1. **VPS/Servidor Dedicado**:

   - Exportar para Linux Server
   - Executar via linha de comando
   - Configurar firewall (porta 7000)

2. **Godot Multiplayer Services**:

   - Usar Nakama ou similar
   - Multiplayer relay servers

3. **Docker Container**:

```dockerfile
FROM ubuntu:20.04
COPY game_server /app/
WORKDIR /app
EXPOSE 7000
CMD ["./game_server", "--headless"]
```

### **Build para servidor**

```bash
# Exportar para servidor Linux
godot --export "Linux/X11" --headless game_server
```

---

# 🚀 8. Melhorias Avançadas

> **🎯 Meta:** Expandir funcionalidades do multiplayer

## **🎮 Gameplay Melhorado**

### **Sistema de Respawn**

```gdscript
# No multiplayer_player.gd
signal player_died(player_id)

func _on_death():
	if is_multiplayer_authority():
		player_died.emit(player_id)
		_respawn.rpc()

@rpc("authority", "reliable")
func _respawn():
	position = Vector2(100, 400)
	velocity = Vector2.ZERO
```

### **Coletáveis Sincronizados**

```gdscript
extends Area2D

@onready var sync = $MultiplayerSynchronizer

func _on_body_entered(body):
	if multiplayer.is_server() and body.has_method("collect_item"):
		_collect_item.rpc()

@rpc("authority", "reliable")
func _collect_item():
	queue_free()
```

## **🔧 Otimizações**

### **Interpolação de Movimento**

```gdscript
# No multiplayer_player.gd
var network_position = Vector2()
var network_velocity = Vector2()

func _physics_process(delta):
	if is_multiplayer_authority():
		# Código de movimento existente
		pass
	else:
		# Interpolar para posição de rede
		position = position.lerp(network_position, 10.0 * delta)
		velocity = velocity.lerp(network_velocity, 5.0 * delta)

@rpc("unreliable")
func sync_position(pos: Vector2, vel: Vector2):
	if not is_multiplayer_authority():
		network_position = pos
		network_velocity = vel
```

### **Compressão de Dados**

```gdscript
# Enviar apenas mudanças necessárias
var last_sent_position = Vector2()

func _physics_process(delta):
	if is_multiplayer_authority():
		# ... movimento ...

		# Enviar posição apenas se mudou significativamente
		if position.distance_to(last_sent_position) > 5.0:
			sync_position.rpc_unreliable(position, velocity)
			last_sent_position = position
```

## **🛡️ Segurança**

### **Validação no Servidor**

```gdscript
# Validar movimento no servidor
@rpc("any_peer", "unreliable")
func validate_movement(new_position: Vector2):
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()
	var player = get_node("../Players/" + str(sender_id))

	# Verificar se movimento é válido
	if player.position.distance_to(new_position) < MAX_MOVEMENT_PER_FRAME:
		player.position = new_position
		sync_validated_position.rpc(sender_id, new_position)

@rpc("authority", "reliable")
func sync_validated_position(player_id: int, position: Vector2):
	var player = get_node("../Players/" + str(player_id))
	if player:
		player.position = position
```

---

# 🎉 Conclusão

## **🏆 O que você aprendeu:**

- ✅ **Arquitetura Client-Server** no Godot
- ✅ **RPCs e sincronização** de dados
- ✅ **MultiplayerSpawner e Synchronizer**
- ✅ **Sistema de chat** em tempo real
- ✅ **Interface de conexão** completa
- ✅ **Testes e deploy** de multiplayer
- ✅ **Otimizações** de performance
- ✅ **Segurança** básica

## **🚀 Próximos Passos**

- [ ] **Rooms/Lobbies** - Sistema de salas
- [ ] **Matchmaking** - Busca automática de partidas
- [ ] **Persistência** - Salvar dados dos jogadores
- [ ] **Anti-cheat** - Proteções avançadas
- [ ] **Voice Chat** - Comunicação por voz
- [ ] **Spectator Mode** - Modo observador

## **💡 Dicas Finais**

- **Teste sempre** com múltiplas instâncias
- **Use debug prints** para acompanhar o estado da rede
- **Otimize** apenas após funcionar corretamente
- **Documente** suas configurações de rede
- **Monitore** performance em conexões lentas

> **🌟 Parabéns!** Você criou um jogo multiplayer online completo no Godot!
