// banco_registradores.v
// Banco de registradores do coprocessador grafico (versao de bancada V3).
// Escrito em clk_sys pela Porta de estimulo; lido combinacionalmente pelos
// motores graficos (que rodam em clk_pix) atraves de sincronizadores externos
// quando necessario (ver observacao de CDC no README).
//
// Mapa de enderecos (documentado tambem no README):
//   0x00 STATUS          {6'b0, buffer_pronto, estimulo_invalido}      (somente leitura via 'status')
//   0x01 BG_SCROLL_X
//   0x02 BG_SCROLL_Y
//   0x03 SPRITE_SEL       [4:0] indice do sprite (0-31) em edicao
//   0x04 SPRITE_X         posicao X do sprite selecionado
//   0x05 SPRITE_Y         posicao Y do sprite selecionado
//   0x06 SPRITE_FLAGS     [5:3]=prioridade, [2]=enable, [1]=fliph, [0]=flipv
//   0x07 SPRITE_PADRAO    indice do padrao grafico (bloco de 16x16) do sprite
//   0x08 LAYER_ENABLE     [2]=enable_poly, [1]=enable_sprite, [0]=enable_bg
//   0x09 OVR_SPR1_X       posicao X do sprite 1 no cenario de sobreposicao
//   0x0A OVR_PRIORIDADE   bit0 = 1 -> sprite1 tem prioridade maior que sprite0
//   0x0B SWAP_CTRL        escrever 1 dispara troca de buffers (pulso)
//   0x20 SPRITE_FLIP      {6'b0,flipv,fliph} do sprite selecionado (espelho de 0x06[1:0])
//   0x30-0x37 POLY0_*     v0x,v0y,v1x,v1y,v2x,v2y,COR,CTRL{modo_retangulo,habilitado}
//   0x38-0x3F POLY1_*     idem slot 1
//   0x40-0x47 POLY2_*     idem slot 2
//   0x48-0x4F POLY3_*     idem slot 3
//
// Enderecos fora do mapa: nao alteram nenhum registrador e sinalizam
// endereco_invalido (agregado ao STATUS pela Porta de estimulo / topo).

module banco_registradores (
    input  wire clk_sys, reset,
    input  wire wr_en,
    input  wire [15:0] endereco,
    input  wire [8:0]  dado_in, // 9 bits: cobre coordenadas ate 319 (eixo X)

    output reg  [7:0] bg_scroll_x, bg_scroll_y,
    output reg  [4:0] sprite_sel, // indice do sprite

    output reg  [8:0] sprite_x        [0:31], //posicao X do sprite selecionado															
    output reg  [8:0] sprite_y        [0:31], //posicao Y do sprite selecionado
    output reg  [4:0] sprite_padrao   [0:31], // indice do bloco 16x16 (0-31 padroes)
    output reg        sprite_en       [0:31],
    output reg  [2:0] sprite_pri      [0:31],
    output reg        sprite_fliph    [0:31],
    output reg        sprite_flipv    [0:31],

    output reg  enable_bg, enable_sprite, enable_poly,

    output reg  [8:0] ovr_spr1_x,
    output reg  ovr_prioridade, //sprite1 tem prioridade maior que sprite0

    output reg  swap_request, // pulso de 1 ciclo de clk_sys

    // 4 slots de poligono
    output reg signed [9:0] poly_vx [0:3][0:2],
    output reg signed [9:0] poly_vy [0:3][0:2],
    output reg [7:0] poly_cor [0:3],
    output reg poly_habilitado [0:3],
    output reg poly_modo_retangulo [0:3],

    output wire [7:0] status,
    input  wire estimulo_invalido,
    input  wire buffer_pronto,
    output reg  endereco_invalido
);

    integer i, j;

    assign status = {6'b0, buffer_pronto, estimulo_invalido}; //(somente leitura via 'status')

    //decodificacao de slot de poligono
    wire eh_poly    = (endereco[7:0] >= 8'h30) && (endereco[7:0] <= 8'h4F);
    wire [1:0] poly_slot  = (endereco[7:0] - 8'h30) >> 3;
    wire [2:0] poly_campo = endereco[2:0];

    always @(posedge clk_sys) begin
        if (reset) begin
            bg_scroll_x <= 0; bg_scroll_y <= 0;
            sprite_sel  <= 0;
            enable_bg <= 0; enable_sprite <= 0; enable_poly <= 0;
            ovr_spr1_x <= 0; ovr_prioridade <= 0;
            swap_request <= 0;
            endereco_invalido <= 0;
            for (i = 0; i < 32; i = i + 1) begin
                sprite_x[i] <= 0; sprite_y[i] <= 0; sprite_padrao[i] <= 0;
                sprite_en[i] <= 0; sprite_pri[i] <= 0;
                sprite_fliph[i] <= 0; sprite_flipv[i] <= 0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                poly_habilitado[i] <= 0; poly_cor[i] <= 0;
                poly_modo_retangulo[i] <= 0;
                for (j = 0; j < 3; j = j + 1) begin
                    poly_vx[i][j] <= 0; poly_vy[i][j] <= 0;
                end
            end
        end else begin
            swap_request      <= 0;
            endereco_invalido <= 0;

            if (wr_en) begin
                if (eh_poly) begin
                    case (poly_campo)
                        3'd0: poly_vx[poly_slot][0] <= dado_in[8:0];
                        3'd1: poly_vy[poly_slot][0] <= dado_in[8:0];
                        3'd2: poly_vx[poly_slot][1] <= dado_in[8:0];
                        3'd3: poly_vy[poly_slot][1] <= dado_in[8:0];
                        3'd4: poly_vx[poly_slot][2] <= dado_in[8:0];
                        3'd5: poly_vy[poly_slot][2] <= dado_in[8:0];
                        3'd6: poly_cor[poly_slot]   <= dado_in;
                        3'd7: begin
                            poly_habilitado[poly_slot]     <= dado_in[0];
                            poly_modo_retangulo[poly_slot] <= dado_in[1];
                        end
                    endcase
                end else begin
                    case (endereco[7:0])
                        8'h01: bg_scroll_x <= dado_in;
                        8'h02: bg_scroll_y <= dado_in;
                        8'h03: sprite_sel  <= dado_in[4:0];
                        8'h04: sprite_x[sprite_sel]      <= dado_in;
                        8'h05: sprite_y[sprite_sel]      <= dado_in;
                        8'h06: begin
                            sprite_pri[sprite_sel]   <= dado_in[5:3];
                            sprite_en[sprite_sel]    <= dado_in[2];
                            sprite_fliph[sprite_sel] <= dado_in[1];
                            sprite_flipv[sprite_sel] <= dado_in[0];
                        end
                        8'h07: sprite_padrao[sprite_sel] <= dado_in[4:0];
                        8'h08: begin
                            enable_bg     <= dado_in[0]; //Flags
                            enable_sprite <= dado_in[1];
                            enable_poly   <= dado_in[2];
                        end
                        8'h09: ovr_spr1_x     <= dado_in;
                        8'h0A: ovr_prioridade <= dado_in[0];
                        8'h0B: swap_request   <= 1'b1;
                        8'h20: begin
                            sprite_fliph[sprite_sel] <= dado_in[0];
                            sprite_flipv[sprite_sel] <= dado_in[1];
                        end
                        default: endereco_invalido <= 1'b1; // fora do mapa nao alteram nenhum registrador e sinalizam endereco_invalido
                    endcase
                end
            end
        end
    end

endmodule
