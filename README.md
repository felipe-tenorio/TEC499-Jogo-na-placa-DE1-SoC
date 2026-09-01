<div align="center">
<h1 align="center"> 
 TEC499-Coprocessador-na-placa-DE1-SoC
</h1>
</div>

<details>
  <summary><h2>Descrição do Projeto</h2></summary>

  O repositório é a primeira fase de um projeto do desenvolvimento de um jogo que irá funcionar na placa **De1-SoC**. Nessa fase foi desenvolvido um coprocessador gráfico em FPGA, feito na que será desenvolvido em verilog para suportar imagens, armazenar recursos gráficos e desenhar background, sprites e polígonos no VGA.

  O objetivo foi criar um processador gráfico para suportar a renderização visual de um protótipo do jogo Bomberman, que será desenvolvido em etapas futuras do projeto. O hardware foi desenvolvido em verilog para suportar imagens, armazenar recursos gráficos e desenhar background, sprites e polígonos no VGA
</details>

<details>
  <summary><h2>Requisitos da 1º Etapa</h2></summary>

  - O hardware deve ser desenvolvido em **verilog**;
  - Armazenar dados gráficos em memórias internas e gerar continuamente um sinal de vídeo **VGA**;
  -  A resolução lógica da cena deverá ser de **320 × 240 pixels**, com duplicação de pixels na saída, fazendo o vídeo operar em 640 x 480 pixels;
  -  A saída não poderá apresentar instabilidade visual, perda de sincronismo ou pixels indefinidos após a inicialização;
 
 ## Estrutura Implementada

<details>
<summary>Módulos do Sistema</summary>

A arquitetura do co-processador é modular, isolando o controle, via de dados (datapath), memórias e a saída VGA. A composição da cena ocorre através do paralelismo de motores dedicados.

<details>
<summary>Banco de Registradores e Controle</summary>
A interface principal de entrada do co-processador (`banco_registradores.v`). Recebe comandos e instruções de 32 bits, armazenando as configurações de cena (coordenadas, cores, prioridades). Este módulo isola o barramento externo dos motores de renderização que operam no domínio de clock do pixel.
</details>

### Motores Gráficos
<details>
<summary>Motores de Renderização (Datapath)</summary>

O sistema renderiza os elementos gráficos por meio de três módulos principais:

- **Motor de Background (`motor_background.v`):**
  Implementa uma camada de plano de fundo baseada em um *tilemap* de 40x30 entradas. Os padrões gráficos (*tiles*) possuem 8x8 pixels e ficam armazenados em memória RAM interna (com 256 padrões suportados). O motor realiza deslocamento (scroll) contínuo nos eixos X e Y para navegação pelo cenário.

- **Motor de Sprites (`motor_sprites.v`):**
  Oferece suporte para renderizar até 32 sprites simultâneos. Cada sprite tem resolução de 16x16 pixels e é analisado em tempo real pelo motor. Para cada objeto, o motor respeita os seguintes atributos mapeados em memória: posição (X, Y), índice de padrão gráfico, bit de habilitação, nível de prioridade e controle de espelhamento (horizontal e vertical).

- **Rasterizador de Polígonos (`rasterizador_multi.v`):**
  Permite o desenho de primitivas geométricas preenchidas utilizando aritmética inteira. É capaz de desenhar retângulos e triângulos, sendo útil para a criação de elementos de interface, obstáculos ou efeitos visuais na tela.
</details>

### Compositor e Driver VGA
<details>
<summary>Compositor de Cena e Controlador de Vídeo</summary>

- **Compositor (`compositor.v`):**
  Combina a contribuição individual de cada motor gráfico a cada ciclo de pixel. Possui lógica de mistura de camadas respeitando a prioridade de exibição, onde os sprites podem se sobrepor a polígonos, que por sua vez se sobrepõem ao background. A transparência é gerenciada reservando o índice `0` para que a camada inferior seja exibida.

- **Driver VGA e Paleta (`vga_driver.v` / `coprocessador.v`):**
  Controla os tempos estritos de H-SYNC e V-SYNC para a saída 640x480. Puxa os dados resultantes do compositor e utiliza uma paleta programável para traduzir o índice de cor (8 bits) em um valor final de RGB (256 cores), enviado diretamente ao DAC e monitor através dos pinos da FPGA.
</details>
</details>

## Mapa de Registradores

<details>
<summary>Endereçamento (Interface de Comandos)</summary>

O acesso de leitura/escrita aos elementos processados é realizado através da decodificação de um barramento de memória (MMIO futuro):

Endereço | Nome | Função
:---: | :--- | :---
`0x00` | STATUS | Acesso somente leitura às flags do hardware (Buffer pronto, Erro).
`0x01` | BG_SCROLL_X | Deslocamento horizontal do Background.
`0x02` | BG_SCROLL_Y | Deslocamento vertical do Background.
`0x03` | SPRITE_SEL | Seleciona o sprite (0 a 31) que terá seus atributos modificados.
`0x04` | SPRITE_X | Configura a coordenada X do sprite selecionado.
`0x05` | SPRITE_Y | Configura a coordenada Y do sprite selecionado.
`0x06` | SPRITE_FLAGS | Atributos combinados do sprite (Prioridade, Enable, Espelhamento).
`0x07` | SPRITE_PADRAO | Define qual padrão gráfico de 16x16 o sprite usará.
`0x08` | LAYER_ENABLE | Habilita independentemente as camadas (Background, Sprites, Polígonos).
`0x0B` | SWAP_CTRL | Sinaliza o request para a troca de buffers (Double Buffering).
`0x30` a `0x4F` | POLY_CONFIG | Atributos completos dos 4 slots de polígonos (Modo, Coordenadas dos Vértices e Cores).

</details>
