<h1 align="center"> 
 TEC499-Coprocessador-na-placa-DE1-SoC
</h1>

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
</details>
