# Cube Puzzle 3D

Um jogo de quebra-cabeça 3D estilo Cubo Mágico desenvolvido na Godot Engine 4.

## Arquitetura da Cena

A cena principal (`CubeGame.tscn`) é organizada hierarquicamente para separar a lógica do jogo, a visualização e a interface do usuário:

* **Raiz (`CubeGame` - Node3D):** Gerencia o estado do jogo e a lógica principal através do script `cube_game.gd`.
* **Cubo (`cube`):** Nó pai que agrupa as 27 peças menores (cubies). É o ponto de referência para a rotação global do objeto.
* **Pivô de Rotação (`PivoRotacao`):** Um nó auxiliar `Node3D` utilizado temporariamente para agrupar peças selecionadas e aplicar a interpolação de rotação (Tween) sem afetar a hierarquia global.
* **Sistema de Câmera (`PivoCamera`):**
    * Utiliza um `Node3D` como pivô para orbitar o centro da cena.
    * Contém a `Camera3D` e uma `DirectionalLight3D` (acoplada à câmera para iluminar sempre o ponto de vista do jogador).
    * Script `camera_orbit.gd` gerencia o input de rotação da câmera.
* **Interface (`HUD` - CanvasLayer):** Camada de UI independente que renderiza elementos 2D (botões e textos) sobre o mundo 3D.

## Modelos e Materiais

### Modelagem
* **Modelo Base:** O cubo foi modelado externamente e importado como `Cube.glb`.
* **Instanciação:** O jogo utiliza instâncias de `MeshInstance3D` para cada uma das peças, permitindo manipulação individual.

### Materiais e UV Mapping
Os materiais foram configurados para simular um acabamento plástico semi-brilhante, utilizando a renderização baseada em física (PBR) do Godot:

* **Mapeamento de Faces:** As faces internas e externas são diferenciadas por materiais distintos. O corpo utiliza `PLASTICO.tres` e as faces coloridas utilizam materiais específicos (ex: `CIMA.tres`, `DIREITA.tres`).
* **Lógica de Detecção:** O sistema de vitória não depende apenas da posição, mas do produto escalar (dot product) entre os vetores normais das faces e os vetores globais, garantindo que o adesivo correto esteja apontando para a direção correta no espaço.

## Luzes e Sombras

A iluminação foi projetada para garantir legibilidade das cores e percepção de profundidade:

* **Luz Principal:** Uma `DirectionalLight3D` fixa na cena com sombras ativadas (`shadow_enabled = true`) para criar volume e contraste entre as peças.
* **Luz de Câmera:** Uma segunda luz direcional filha do `PivoCamera` atua como "fill light" (luz de preenchimento), evitando que o lado oposto do cubo fique totalmente escuro enquanto o jogador orbita.
* **WorldEnvironment:** Configurado para fornecer uma iluminação ambiente suave (Sky) e efeitos de pós-processamento (Glow/SSAO) para realçar o brilho dos materiais.

## Elementos de HUD

A interface do usuário (HUD) é minimalista e funcional, construída com nós de `Control`:

* **Cronômetro:** Exibe o tempo decorrido no formato `MM:SS.ms`. Inicia automaticamente apenas após o primeiro movimento do jogador pós-embaralhamento.
* **Contador de Movimentos:** Registra cada rotação válida feita pelo jogador, ignorando as rotações automáticas do embaralhamento.
* **Controles:** Botões para "Embaralhar" (gera um estado aleatório válido) e "Reset" (recarrega a cena).
* **Tela de Vitória:** Uma cena instanciada (`TelaVitoria.tscn`) que sobrepõe o jogo ao detectar a solução, bloqueando inputs 3D para evitar modificações acidentais.

## Paleta de Cores

* **Cores do Cubo:** Segue o padrão clássico (Branco, Amarelo, Vermelho, Laranja, Azul, Verde) com alta saturação para fácil distinção.
* **Corpo das Peças:** Preto (#000000) com alta rugosidade para contraste com os adesivos brilhantes.
* **HUD:** Textos brancos com fundos translúcidos escuros (estilo cápsula) para garantir leitura sobre qualquer fundo 3D.

## Limitações Atuais

1.  **Animações Simultâneas:** O sistema bloqueia novas interações enquanto uma rotação está ocorrendo (variável `girando`), impedindo movimentos rápidos em sequência.
2.  **Reset:** O botão de reset recarrega a cena inteira, o que é eficiente mas impede transições visuais suaves de reinício.
3.  **Persistência:** Não há sistema de salvamento de recordes (High Score) entre sessões.

## Possíveis Melhorias

* **Fila de Movimentos:** Implementar um "buffer" de input para permitir que o jogador enfileire o próximo movimento enquanto o atual termina.
* **Sistema de High Score:** Salvar o melhor tempo e menor número de movimentos em um arquivo local (`user://`).
* **Inspeção Livre:** Permitir rotacionar o cubo livremente sem ativar o cronômetro antes do primeiro movimento real de uma peça.
* **Sons:** Adicionar efeitos sonoros (SFX) de "clack" ao girar e música de fundo ambiente.