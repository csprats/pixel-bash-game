extends Control

@export var winner_icon: TextureRect
@export var winner_text: Label
@export var button: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	button.grab_focus()
	# 1. Comprobamos si el GameManager guardó la ruta del .tres del ganador
	if GameManager.winner_data_path != "":
		# 2. Cargamos el recurso .tres en memoria
		var data: CharacterData = load(GameManager.winner_data_path)
		
		if data:
			# 3. Accedemos DIRECTAMENTE a tus variables personalizadas
			var name_of_winner: String = data.character_name
			var icon_of_winner: Texture2D = data.character_icon
			
			# 4. Los pintamos en la interfaz de Pixel Bash
			winner_text.text = "%s (Player %s) win the game!" % [name_of_winner, GameManager.winner]
			winner_icon.texture = icon_of_winner
	else:
		# Por si acaso juegas desde una escena de prueba y no viene del GameManager
		winner_text.text = "Player %s win the game!" % GameManager.winner


func _on_button_pressed() -> void:
	GameManager.change_scene(GameManager.MENU_SCENE)
