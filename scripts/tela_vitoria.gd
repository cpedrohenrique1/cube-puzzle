extends CanvasLayer

func _ready() -> void:
	# O caminho deve bater com os nomes que criamos no Passo 1
	$Fundo/PanelContainer/VBoxContainer/BtnJogarNovamente.pressed.connect(_on_jogar_novamente)
	$Fundo/PanelContainer/VBoxContainer/BtnInicio.pressed.connect(_on_inicio)

func _on_jogar_novamente() -> void:
	get_tree().reload_current_scene()

func _on_inicio() -> void:
	# Verifique se o caminho da sua tela inicial é exatamente este
	get_tree().change_scene_to_file("res://cenas/ui/TelaInicial.tscn")
