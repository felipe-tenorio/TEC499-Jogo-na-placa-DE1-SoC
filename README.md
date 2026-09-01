<div align="center">
<h1 align="center"> 
 TEC499-Coprocessador-na-placa-DE1-SoC
</h1>
</div>

## Descrição do Projeto
<details>
  <summary>Descrição</summary>

  O repositório é a primeira fase de um projeto do desenvolvimento de um jogo que irá funcionar na placa **De1-SoC**. Nessa fase foi desenvolvido um coprocessador gráfico em FPGA, feito na que será desenvolvido em verilog para suportar imagens, armazenar recursos gráficos e desenhar background, sprites e polígonos no VGA.

  O objetivo foi criar um processador gráfico para suportar a renderização visual de um protótipo do jogo Bomberman, que será desenvolvido em etapas futuras do projeto. O hardware foi desenvolvido em verilog para suportar imagens, armazenar recursos gráficos e desenhar background, sprites e polígonos no VGA


<details>
  <summary><h2>Requisitos da 1º Etapa</h2></summary>

  - O hardware deve ser desenvolvido em **verilog**;
  - Armazenar dados gráficos em memórias internas e gerar continuamente um sinal de vídeo **VGA**;
  - A resolução lógica da cena deverá ser de **320 × 240 pixels**, com duplicação de pixels na saída, fazendo o vídeo operar em 640 x 480 pixels;
  - A saída não poderá apresentar instabilidade visual, perda de sincronismo ou pixels indefinidos após a inicialização;
  - **Motor de Background** baseado em tilemap de 40x30 posições, com até 256 padrões;
  - **Motor de Sprites** que gerencia até 32 sprites simultâneos, com atributos individuais de posição (X, Y), índice de padrão, habilitação, prioridade e **espelhamento**;
  - **Rasterizador** que desenha de polígonos preenchidos;
  - Implementar pelo menos três **níveis de prioridade** entre as camadas;
  - Aplicar **transparência** antes da seleção do pixel final;
  - Converter o índice de cor de 8 bits por meio de uma paleta programável de 256 entradas RGB.
</details>
</details>

 ## Estrutura Implementada

<details>
<summary>Módulos do Sistema</summary>

A arquitetura do co-processador é modular, isolando o controle, via de dados (datapath), memórias e a saída VGA. A composição da cena ocorre através do paralelismo de motores dedicados.

## Registradores
<details>
<summary>Banco de Registradores e Controle</summary>
A interface principal de entrada do co-processador. Recebe comandos e instruçõess, armazenando as configurações de cena (coordenadas, cores, prioridades). Este módulo isola o barramento externo dos motores de renderização que operam no domínio de clock do pixel.
</details>

### Motores Gráficos
<details>
<summary>Motores de Renderização (Datapath)</summary>

O sistema renderiza os elementos gráficos por meio de três módulos principais:

- **Motor de Background:**
  Implementa uma camada de plano de fundo baseada em um *tilemap* de 40x30 entradas. Os padrões gráficos (*tiles*) possuem 8x8 pixels e ficam armazenados em memória RAM interna (com 256 padrões suportados). O motor realiza deslocamento (scroll) contínuo nos eixos X e Y para navegação pelo cenário.

  <div align="center">
  <figure>
    <img src="Docs/gif_back.gif" width="200px"/>
    <figcaption>
      <p align="center">
        <b>Figura 1</b> - Movimentação do Background
      </p>
    </figcaption>
  </figure>
  </div>

- **Motor de Sprites:**
  Oferece suporte para renderizar até 32 sprites simultâneos. Cada sprite tem resolução de 16x16 pixels e é analisado em tempo real pelo motor. Para cada objeto, o motor respeita os seguintes atributos mapeados em memória: posição (X, Y), índice de padrão gráfico, bit de habilitação, nível de prioridade e controle de espelhamento (horizontal e vertical).

  <div align="center">
  <figure>
    <img src="Docs/todos_sprites.jpeg" width="200px"/>
    <figcaption>
      <p align="center">
        <b>Figura 2</b> - 32 Sprites simultâneos no VGA
      </p>
    </figcaption>
  </figure>
  </div>

- **Rasterizador de Polígonos:**
  Permite o desenho de primitivas geométricas preenchidas utilizando aritmética inteira. É capaz de desenhar retângulos e triângulos, sendo útil para a criação de elementos de interface, obstáculos ou efeitos visuais na tela.
</details>

### Compositor e Driver VGA
<details>
<summary>Compositor de Cena e Controlador de Vídeo</summary>

- **Compositor:**
  Combina a contribuição individual de cada motor gráfico a cada ciclo de pixel. Possui lógica de mistura de camadas respeitando a prioridade de exibição, onde os sprites podem se sobrepor a polígonos, que por sua vez se sobrepõem ao background. A transparência é gerenciada reservando o índice `0` para que a camada inferior seja exibida.

- **Driver VGA e Paleta:**
  Controla os tempos estritos de H-SYNC e V-SYNC para a saída 640x480. Puxa os dados resultantes do compositor e utiliza uma paleta programável para traduzir o índice de cor (8 bits) em um valor final de RGB (256 cores), enviado diretamente ao DAC e monitor através dos pinos da FPGA.
</details>
</details>

## Mapa de Registradores

<details>
<summary>Endereçamento (Interface de Comandos)</summary>

O acesso de leitura/escrita aos elementos processados é realizado através da decodificação de um barramento de memória:

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

## Barramentos
<details>
<summary>Barramentos</summary>
Barramento | Tamanho | Descrição
:---: | :--- | :---
Address | 16 | Barramento de endereçamento dos registradores internos
Data In | 9 | Barramento de entrada de dados para configuração
Control | 1 | Sinais de controle de escrita em memória
Status | 8 | Barramento de saída contendo as flags de estado do núcleo
VGA Out | 29 | Barramento de saída contendo os sinais físicos de vídeo


### Address
Esse barramento de 16 bits (endereco) é utilizado para selecionar em qual registrador do coprocessador a operação atual será realizada. Ele mapeia o acesso a configurações de sprites (endereços 0x03 a 0x07), propriedades dos polígonos (0x30 a 0x4F), controle de deslocamento do background (0x01 e 0x02) e requisições de sistema, como a troca de buffers (0x0B). Acessos a endereços fora do mapa documentado são ignorados e geram uma sinalização de erro.

### Data In
Barramento de entrada de dados de 9 bits. Ele é responsável por carregar os valores que serão salvos no registrador apontado pelo barramento de endereço. A largura de 9 bits foi escolhida por ela ser o tamanho exato necessário para representar a coordenada máxima do eixo X dentro da resolução lógica do sistema (320x240), cobrindo valores de 0 até 319.

### Control
Composto pelo sinal de controle que dá permição a interface de memória:

- Wr_en (Write Enable): Sinal de 1 bit que autoriza a gravação. O dado presente no barramento Data In só é gravado no registrador selecionado no Address quando esta flag está em nível lógico alto.

### Status
Barramento de saída de 8 bits (status) que reporta a saúde e o estado atual do coprocessador para o sistema de controle externo. Os bits menos significativos possuem funções específicas de monitoramento:

- Bit 1 (buffer_pronto): Indica a estabilidade do clock base (PLL locked), garantindo que o sistema está em frequência ideal de operação.
- Bit 0 (estimulo_invalido / endereco_invalido): Atua como uma flag de Erro. Fica em nível lógico alto caso o controlador tente acessar um registrador fora do mapa existente ou caso o cenário injetado seja inválido.

### VGA Out
Este é o barramento de saída física do coprocessador.

- Cores (24 bits): Barramentos VGA_R, VGA_G e VGA_B, com 8 bits cada, carregando o valor da cor do pixel extraído da paleta.
- Sincronismo (5 bits): Sincronismo horizontal (VGA_HS), vertical (VGA_VS), pulso de relógio para o DAC (VGA_CLK) e controles de período ativo (VGA_BLANK_N e VGA_SYNC_N).
</details>

## Testes
<details>
<summary>Testes</summary>
 
</details>
