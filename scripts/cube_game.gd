extends Node3D

const TELA_VITORIA_CENA = preload("res://cenas/ui/TelaVitoria.tscn")

# --- UI REFERÊNCIAS ---
# Usando o nó HUD que já existe na sua cena
@onready var label_tempo = $HUD/LabelTempo
@onready var label_movimentos = $HUD/LabelMovimentos
# ----------------------

@onready var cubo_pai = $cube
@onready var pivo = $PivoRotacao
@onready var camera = $PivoCamera/Camera3D

const TAMANHO_GRID = 2.05
const MAPA_MATERIAIS = {
	"CIMA": Vector3.UP, "BAIXO": Vector3.DOWN,
	"DIREITA": Vector3.RIGHT, "ESQUERDA": Vector3.LEFT,
	"FRENTE": Vector3.BACK, "TRAS": Vector3.FORWARD
}

# --- ESTADOS DO JOGO ---
var girando = false
var embaralhando = false
var jogo_ativo = false            # Controla se o cronômetro deve rodar
var esperando_primeiro_movimento = false # "Gatilho" para iniciar o tempo

var tempo_decorrido = 0.0
var movimentos_contador = 0

var peca_focada: Node3D = null
var normal_face_focada: Vector3 = Vector3.ZERO
var posicao_mouse_inicio = Vector2.ZERO
const LIMITE_ARRASTE = 30.0

func _process(delta):
	# Cronômetro só roda se o jogo estiver valendo E o jogador já tiver feito o 1º movimento
	if jogo_ativo and not esperando_primeiro_movimento:
		tempo_decorrido += delta
		atualizar_interface()

func atualizar_interface():
	# Formata segundos em Minutos:Segundos.Centésimos
	var mins = int(tempo_decorrido / 60)
	var segs = int(tempo_decorrido) % 60
	var centesimos = int((tempo_decorrido - int(tempo_decorrido)) * 100)
	
	if label_tempo:
		label_tempo.text = "%02d:%02d.%02d" % [mins, segs, centesimos]
	
	if label_movimentos:
		label_movimentos.text = "Movimentos: %d" % movimentos_contador

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

	# --- LÓGICA DO CRONÔMETRO ---
	# Se o jogo estava esperando o primeiro toque para começar:
	if esperando_primeiro_movimento:
		esperando_primeiro_movimento = false
		jogo_ativo = true # Start no relógio!
	# ----------------------------

	var normal = normal_face_focada
	var centro_visual = peca_focada.to_global(peca_focada.get_aabb().get_center())
	
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

	var eixo_rotacao_bruto = normal.cross(melhor_eixo_movimento)
	var eixo_final_abs = Vector3(abs(eixo_rotacao_bruto.x), abs(eixo_rotacao_bruto.y), abs(eixo_rotacao_bruto.z))
	var sinal_do_eixo = -1 if (eixo_rotacao_bruto.x + eixo_rotacao_bruto.y + eixo_rotacao_bruto.z) < 0 else 1
	var sentido_final = sentido_na_tela * sinal_do_eixo
	
	aplicar_rotacao(eixo_final_abs, sentido_final, peca_focada, 0.3)
	peca_focada = null 

func aplicar_rotacao(eixo: Vector3, sentido: int, peca_ref: Node3D, tempo: float) -> Tween:
	girando = true
	
	# --- CONTADOR DE MOVIMENTOS ---
	# Conta apenas se o jogo estiver "Valendo" (ativo e timer rodando)
	if jogo_ativo and not embaralhando and not esperando_primeiro_movimento:
		movimentos_contador += 1
		atualizar_interface()
	# ------------------------------

	var pecas_para_girar = []
	var centro_ref = peca_ref.to_global(peca_ref.get_aabb().get_center())
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
	
	for peca in cubo_pai.get_children():
		if peca is MeshInstance3D:
			peca.position = (peca.position / TAMANHO_GRID).round() * TAMANHO_GRID

	atualizar_nomes_apos_rotacao()
	girando = false
	verificar_vitoria()

func atualizar_nomes_apos_rotacao():
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
	# Se não estiver jogando (timer parado), não verifica vitória
	if embaralhando or not jogo_ativo: return 

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
			var direcao_global = (basis_peca * vetor_local_adesivo).normalized()
			var direcao_snap = direcao_global.round()
			
			if not direcao_snap in faces_mundo: continue

			if vetor_posicao_relativa.dot(direcao_snap) > (TAMANHO_GRID * 0.5):
				faces_mundo[direcao_snap].append(nome_material)

	# Validação
	for direcao in faces_mundo:
		var lista = faces_mundo[direcao]
		if lista.size() != 9: return
		var cor_base = lista[0]
		for cor in lista:
			if cor != cor_base: return
	
	# === VITÓRIA CONFIRMADA ===
	jogo_ativo = false # Para o cronômetro
	
	var tela = TELA_VITORIA_CENA.instantiate()
	add_child(tela)
	set_process_input(false)
	embaralhando = true

func embaralhar_cubo():
	if girando or embaralhando: return
	
	# Reset das variáveis
	embaralhando = true
	jogo_ativo = false # Garante que o timer pare
	esperando_primeiro_movimento = false 
	tempo_decorrido = 0.0
	movimentos_contador = 0
	atualizar_interface()
	
	var movimentos = 25 # Ajuste conforme a dificuldade desejada
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
			0.1 # Rápido para embaralhar logo
		)
		if tween: await tween.finished
	
	embaralhando = false
	esperando_primeiro_movimento = true # AGORA sim, estamos prontos para começar no próximo click

func _on_button_pressed() -> void:
	embaralhar_cubo()

func _on_reset_pressed() -> void:
	get_tree().reload_current_scene()
