extends Node3D

@onready var cubo_pai = $cube
@onready var pivo = $PivoRotacao
@onready var camera = $PivoCamera/Camera3D

const TAMANHO_GRID = 2.05

# Mapeamento local -> Vetor (Nota: No Godot +Z é Back)
const MAPA_MATERIAIS = {
	"CIMA": Vector3.UP, "BAIXO": Vector3.DOWN,
	"DIREITA": Vector3.RIGHT, "ESQUERDA": Vector3.LEFT,
	"FRENTE": Vector3.BACK, "TRAS": Vector3.FORWARD
}

var girando = false
var embaralhando = false 
var peca_focada: Node3D = null
var normal_face_focada: Vector3 = Vector3.ZERO
var posicao_mouse_inicio = Vector2.ZERO
const LIMITE_ARRASTE = 30.0

func _input(event):
	if girando or embaralhando: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			tentar_iniciar_interacao(event.position)
			if peca_focada: get_viewport().set_input_as_handled()
		else:
			peca_focada = null

	if event is InputEventMouseMotion and peca_focada:
		get_viewport().set_input_as_handled()
		processar_arraste(event.position)

func tentar_iniciar_interacao(pos_mouse):
	var origem = camera.project_ray_origin(pos_mouse)
	var direcao = camera.project_ray_normal(pos_mouse)
	var fim = origem + direcao * 2000.0 
	
	var espaco = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origem, fim)
	var resultado = espaco.intersect_ray(query)
	
	if resultado:
		peca_focada = resultado["collider"].get_parent()
		var n = resultado["normal"]
		
		# Define a normal principal da face clicada
		var max_axis = max(abs(n.x), abs(n.y), abs(n.z))
		if max_axis == abs(n.x): normal_face_focada = Vector3(sign(n.x), 0, 0)
		elif max_axis == abs(n.y): normal_face_focada = Vector3(0, sign(n.y), 0)
		else: normal_face_focada = Vector3(0, 0, sign(n.z))
			
		posicao_mouse_inicio = pos_mouse
	else:
		peca_focada = null

func processar_arraste(pos_mouse_atual):
	var vetor_mouse = pos_mouse_atual - posicao_mouse_inicio
	if vetor_mouse.length() < LIMITE_ARRASTE: return

	var normal = normal_face_focada
	var centro_visual = peca_focada.to_global(peca_focada.get_aabb().get_center())
	
	# 1. Identificar eixo do movimento do mouse projetado no mundo
	var eixos_candidatos = []
	if abs(normal.x) < 0.5: eixos_candidatos.append(Vector3(1, 0, 0))
	if abs(normal.y) < 0.5: eixos_candidatos.append(Vector3(0, 1, 0))
	if abs(normal.z) < 0.5: eixos_candidatos.append(Vector3(0, 0, 1))
	
	var melhor_eixo_movimento = Vector3.ZERO
	var melhor_alinhamento = -1.0
	var sentido_na_tela = 0
	var tela_centro = camera.unproject_position(centro_visual)
	
	for eixo_mundo in eixos_candidatos:
		var tela_offset = camera.unproject_position(centro_visual + eixo_mundo)
		var direcao_visual = tela_offset - tela_centro
		var alinhamento = abs(vetor_mouse.normalized().dot(direcao_visual.normalized()))
		
		if alinhamento > melhor_alinhamento:
			melhor_alinhamento = alinhamento
			melhor_eixo_movimento = eixo_mundo
			sentido_na_tela = 1 if vetor_mouse.dot(direcao_visual) >= 0 else -1
	
	if melhor_alinhamento < 0.5: return

	# 2. Determinar Eixo de Rotação (Normal x Movimento)
	var eixo_rotacao_bruto = normal.cross(melhor_eixo_movimento)
	var eixo_final_abs = Vector3(abs(eixo_rotacao_bruto.x), abs(eixo_rotacao_bruto.y), abs(eixo_rotacao_bruto.z))
	
	var sinal_do_eixo = -1 if (eixo_rotacao_bruto.x + eixo_rotacao_bruto.y + eixo_rotacao_bruto.z) < 0 else 1
	var sentido_final = sentido_na_tela * sinal_do_eixo
	
	aplicar_rotacao(eixo_final_abs, sentido_final, peca_focada, 0.3)
	peca_focada = null 

func aplicar_rotacao(eixo: Vector3, sentido: int, peca_ref: Node3D, tempo: float) -> Tween:
	girando = true
	var pecas_para_girar = []
	var centro_ref = peca_ref.to_global(peca_ref.get_aabb().get_center())
	
	# Coordenadas de grade da peça de referência
	var ref_coords = (centro_ref / TAMANHO_GRID).round()

	for filho in cubo_pai.get_children():
		if not filho is MeshInstance3D: continue
		var pos_coords = (filho.to_global(filho.get_aabb().get_center()) / TAMANHO_GRID).round()
		
		var deve_girar = false
		if eixo.x > 0.5 and abs(pos_coords.x - ref_coords.x) < 0.1: deve_girar = true
		elif eixo.y > 0.5 and abs(pos_coords.y - ref_coords.y) < 0.1: deve_girar = true
		elif eixo.z > 0.5 and abs(pos_coords.z - ref_coords.z) < 0.1: deve_girar = true
			
		if deve_girar: pecas_para_girar.append(filho)

	if pecas_para_girar.is_empty():
		girando = false
		return null

	for peca in pecas_para_girar: peca.reparent(pivo, true)
	
	var tween = create_tween()
	var rotacao_final = eixo * deg_to_rad(90 * sentido)
	
	tween.tween_property(pivo, "rotation", rotacao_final, tempo).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_fim_da_rotacao)
	return tween

func _fim_da_rotacao():
	for peca in pivo.get_children(): peca.reparent(cubo_pai, true)
	pivo.rotation = Vector3.ZERO
	
	# Snap positions to grid
	for peca in cubo_pai.get_children():
		if peca is MeshInstance3D:
			peca.position = (peca.position / TAMANHO_GRID).round() * TAMANHO_GRID

	atualizar_nomes_apos_rotacao()
	girando = false
	verificar_vitoria()

func atualizar_nomes_apos_rotacao():
	# Reseta nomes para evitar conflitos antes de renomear corretamente
	var index = 0
	for peca in cubo_pai.get_children():
		if peca is MeshInstance3D:
			peca.name = "Temp_" + str(index)
			index += 1
	
	for peca in cubo_pai.get_children():
		if not peca is MeshInstance3D: continue
		var centro = peca.to_global(peca.get_aabb().get_center())
		var grid = (centro / TAMANHO_GRID).round()
		peca.name = "Peca_%d_%d_%d" % [grid.x, grid.y, grid.z]

func verificar_vitoria():
	if embaralhando: return

	var faces_mundo = {
		Vector3.UP: [], Vector3.DOWN: [], Vector3.LEFT: [], 
		Vector3.RIGHT: [], Vector3.FORWARD: [], Vector3.BACK: []
	}
	
	var centro_absoluto_cubo = cubo_pai.global_position
	
	for peca in cubo_pai.get_children():
		if not peca is MeshInstance3D: continue
		
		var centro_peca_global = peca.to_global(peca.get_aabb().get_center())
		var vetor_posicao_relativa = centro_peca_global - centro_absoluto_cubo
		var basis_peca = peca.global_transform.basis
		
		for nome_material in MAPA_MATERIAIS.keys():
			var vetor_local_adesivo = MAPA_MATERIAIS[nome_material]
			
			# Direção do adesivo no mundo
			var direcao_global = (basis_peca * vetor_local_adesivo).normalized()
			var direcao_snap = direcao_global.round()
			
			if not direcao_snap in faces_mundo: continue

			# Projeção: Verifica se o adesivo está na face externa (distante do centro)
			# Se > 0, aponta para fora. Se > TAMANHO_GRID/2, está na superfície externa.
			if vetor_posicao_relativa.dot(direcao_snap) > (TAMANHO_GRID * 0.5):
				faces_mundo[direcao_snap].append(nome_material)

	# Validação
	for direcao in faces_mundo:
		var lista = faces_mundo[direcao]
		
		if lista.size() != 9: return # Face incompleta
			
		var cor_base = lista[0]
		for cor in lista:
			if cor != cor_base: return # Cores misturadas
	
	print("VITÓRIA")
	# Adicione aqui: get_tree().quit() ou UI de vitória

func embaralhar_cubo():
	if girando or embaralhando: return
	
	embaralhando = true
	var movimentos = 100
	var eixos_possiveis = [Vector3(1,0,0), Vector3(0,1,0), Vector3(0,0,1)]
	
	for i in range(movimentos):
		var pecas_validas = []
		for filho in cubo_pai.get_children():
			if filho is MeshInstance3D: pecas_validas.append(filho)
		
		if pecas_validas.is_empty(): break
		
		var tween = aplicar_rotacao(
			eixos_possiveis.pick_random(), 
			[1, -1].pick_random(), 
			pecas_validas.pick_random(), 
			0.2
		)
		if tween: await tween.finished
	
	embaralhando = false

func _on_button_pressed() -> void:
	embaralhar_cubo()


func _on_reset_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/niveis/CubeGame.tscn")
