module porta_estimulo (
    input  wire clk_sys, reset,
    input  wire [9:0] SW,
    input  wire pulso_key0, pulso_key1, pulso_key2, //Botoes

    output wire wr_en,
    output wire [15:0] endereco,
    output wire [8:0]  dado,

    output reg  [2:0]  cenario_ativo,
    output reg  estimulo_invalido,  //Entrada incorreta 101/110/111 (estados nao utilizados)

    // Display 7-seg
    output reg  [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5
	 //HEX5/HEX4 = 'S' + dígito decimal do sprite(cenário 001/010)
		//HEX3/HEX2 = 'P' + dígito decimal do polígono(cenário 011)
);

    wire [2:0] cenario = SW[2:0]; //Escolhe cenario de teste

    // Constantes e tabelas de polígonos (vértices de origem)

    reg signed [9:0] poly_base_vx [0:5][0:2];
    reg signed [9:0] poly_base_vy [0:5][0:2];
    reg [1:0]        poly_base_ctrl [0:5]; // {modo_retangulo, habilitado}

    initial begin
        // 0 - retângulo
        poly_base_vx[0][0]=0;   poly_base_vy[0][0]=0;
        poly_base_vx[0][1]=70;  poly_base_vy[0][1]=50;
        poly_base_vx[0][2]=0;   poly_base_vy[0][2]=0;
        poly_base_ctrl[0]=2'b11;

        // 1 - triângulo retângulo
        poly_base_vx[1][0]=0;   poly_base_vy[1][0]=0;
        poly_base_vx[1][1]=0;   poly_base_vy[1][1]=70;
        poly_base_vx[1][2]=80;  poly_base_vy[1][2]=70;
        poly_base_ctrl[1]=2'b01;

        // 2 - triângulo equilátero
        poly_base_vx[2][0]=40;  poly_base_vy[2][0]=0;
        poly_base_vx[2][1]=0;   poly_base_vy[2][1]=70;
        poly_base_vx[2][2]=80;  poly_base_vy[2][2]=70;
        poly_base_ctrl[2]=2'b01;

        // 3 - triângulo isósceles
        poly_base_vx[3][0]=40;  poly_base_vy[3][0]=0;
        poly_base_vx[3][1]=5;   poly_base_vy[3][1]=80;
        poly_base_vx[3][2]=75;  poly_base_vy[3][2]=80;
        poly_base_ctrl[3]=2'b01;

        // 4 - triângulo escaleno
        poly_base_vx[4][0]=0;   poly_base_vy[4][0]=10;
        poly_base_vx[4][1]=90;  poly_base_vy[4][1]=30;
        poly_base_vx[4][2]=30;  poly_base_vy[4][2]=90;
        poly_base_ctrl[4]=2'b01;

        // 5 - quadrado
        poly_base_vx[5][0]=0;   poly_base_vy[5][0]=0;
        poly_base_vx[5][1]=60;  poly_base_vy[5][1]=60;
        poly_base_vx[5][2]=0;   poly_base_vy[5][2]=0;
        poly_base_ctrl[5]=2'b11;
    end

    // 00=vermelho, 01=verde, 10=azul, 11=amarelo
    function automatic [7:0] cor_from_sw;
        input [1:0] sel;
        begin
            case (sel)
                2'b00: cor_from_sw = 8'hE0; //Vermelho
                2'b01: cor_from_sw = 8'h1C; //Verde
                2'b10: cor_from_sw = 8'h03; //Azul
                2'b11: cor_from_sw = 8'hFC; //Amarelo
                default: cor_from_sw = 8'hE0;
            endcase
        end
    endfunction

    // Estado persistente de sprites e polígonos
    reg [4:0] sprite_cursor;          // índice em edição (KEY2)
    reg [4:0] last_confirmed_sprite;  // última confirmada (KEY0) — para movimento
    reg       tem_sprite_confirmado;
    reg       sprite_fliph_local;     // cópia local do flip horizontal do cursor
    reg       sprite_flipv_local;     // cópia local do flip vertical do cursor

    reg [2:0] poly_tipo_cursor;       // 0 a 5
    reg [1:0] poly_slot_next;         // próximo slot livre
    reg [1:0] last_confirmed_poly;    // último slot confirmado
    reg       tem_poly_confirmado;

    // Posição inicial padrão de sprite
    localparam SPRITE_X_INIT = 9'd150;
    localparam SPRITE_Y_INIT = 9'd100;

    // Máquina de sequências 
    localparam IDLE = 2'd0, REPROD = 2'd1;
    reg [1:0] estado;
    reg [5:0] passo;
    reg [5:0] passo_max;
    reg [2:0] cen_lat;
    reg [4:0] spr_lat;       // sprite selecionado no momento do KEY0
    reg [2:0] poly_tipo_lat;
    reg [1:0] poly_slot_lat;
    reg [1:0] cor_lat;
    reg [4:0] pos_lat;       //posicao inicial escolhida pro poligono
    reg       scroll_ativo;  // KEY0 ativo no cenário 000

    // Movimento contínuo (scroll BG e sprite)
    wire reinit_scroll = (estado == REPROD) && (cen_lat == 3'b000) && (passo == 6'd1);
    wire reinit_sprite = (estado == REPROD) && (cen_lat == 3'b010) && (passo == 6'd2);

    wire wr_en_scroll;
    wire [15:0] endereco_scroll;
    wire [8:0]  dado_scroll;

    mov_continuo #(
        .WIDTH(8), .X_INIT(8'sd0), .Y_INIT(8'sd0),
        .PERIODO_NORMAL(20'd100000), .DIV_RAPIDO(2)
    ) u_scroll_bg (
        .clk_sys(clk_sys), .reset(reset),
		  .reinit_x(8'sd0),
		.reinit_y(8'sd0),
        .ativo(cenario == 3'b000 && scroll_ativo && estado == IDLE),
        .reinit(reinit_scroll),
        .dir_h(SW[9:8]), .dir_v(SW[7:6]), .veloc_rapida(SW[5]), //Escolhe a velocidade do movimento
        .end_x(16'h0001), .end_y(16'h0002),
        .wr_en(wr_en_scroll), .endereco(endereco_scroll), .dado(dado_scroll),
        .x_local(), .y_local()
    );

    wire wr_en_sprite_mv;
    wire [15:0] endereco_sprite_mv;
    wire [8:0]  dado_sprite_mv;

    // Movimento da última sprite confirmada: escreve sempre no sprite_sel
    // (atualizado para last_confirmed_sprite antes de iniciar o movimento)
    mov_continuo #(
        .WIDTH(9), .X_INIT(SPRITE_X_INIT), .Y_INIT(SPRITE_Y_INIT),
        .PERIODO_NORMAL(20'd100000), .DIV_RAPIDO(2)
    ) u_move_sprite (
        .clk_sys(clk_sys), .reset(reset),
		  .reinit_x(SPRITE_X_INIT),
		  .reinit_y(SPRITE_Y_INIT),
        .ativo(cenario == 3'b010 && tem_sprite_confirmado && estado == IDLE),
        .reinit(reinit_sprite),
        .dir_h(SW[9:8]), .dir_v(SW[7:6]), .veloc_rapida(SW[5]), //Escolhe a velocidade do movimento
        .end_x(16'h0004), .end_y(16'h0005),
        .wr_en(wr_en_sprite_mv), .endereco(endereco_sprite_mv), .dado(dado_sprite_mv),
        .x_local(), .y_local()
    );

    // Sequenciador de escritas
    reg wr_en_seq;
    reg [15:0] endereco_seq;
    reg [8:0]  dado_seq;

    // Prioridade: sequência > scroll > movimento de sprite
    assign wr_en    = wr_en_seq ? 1'b1         : (wr_en_scroll ? 1'b1 : wr_en_sprite_mv);
    assign endereco = wr_en_seq ? endereco_seq : (wr_en_scroll ? endereco_scroll : endereco_sprite_mv);
    assign dado     = wr_en_seq ? dado_seq     : (wr_en_scroll ? dado_scroll     : dado_sprite_mv);

    // Offset de posição do polígono a partir de SW[9:5]
    wire [8:0] poly_xoff = {pos_lat, 4'b0}; // *16
    wire [8:0] poly_yoff = {1'b0, pos_lat, 3'b0}; // *8

    // Habilita background automaticamente no primeiro ciclo após reset
    reg bg_started;

    always @(posedge clk_sys) begin
        if (reset) begin
            wr_en_seq            <= 1'b0;
            endereco_seq         <= 16'd0;
            dado_seq             <= 9'd0;
            cenario_ativo        <= 3'd0;
            estimulo_invalido    <= 1'b0;
            estado               <= IDLE;
            passo                <= 6'd0;
            passo_max            <= 6'd0;
            cen_lat              <= 3'd0;
            spr_lat              <= 5'd0;
            poly_tipo_lat        <= 3'd0;
            poly_slot_lat        <= 2'd0;
            cor_lat              <= 2'd0;
            pos_lat              <= 5'd0;
            sprite_cursor        <= 5'd0;
            last_confirmed_sprite<= 5'd0;
            tem_sprite_confirmado<= 1'b0;
            sprite_fliph_local   <= 1'b0;
            sprite_flipv_local   <= 1'b0;
            poly_tipo_cursor     <= 3'd0;
            poly_slot_next       <= 2'd0;
            last_confirmed_poly  <= 2'd0;
            tem_poly_confirmado  <= 1'b0;
            scroll_ativo         <= 1'b0;
            bg_started           <= 1'b0;
        end else begin
            wr_en_seq         <= 1'b0;
            estimulo_invalido <= 1'b0;
            cenario_ativo     <= cenario;

            // Background sempre ativo: no primeiro ciclo após reset escreve
            // LAYER_ENABLE com bit de BG = 1

            if (!bg_started) begin
                wr_en_seq    <= 1'b1;
                endereco_seq <= 16'h0008;
                dado_seq     <= 9'b001; // só BG
                bg_started   <= 1'b1;
            end else if (cenario >= 3'b101) begin
                // Estímulo inválido
                estimulo_invalido <= 1'b1;
                estado            <= IDLE;
            end else begin
                case (estado)

                    IDLE: begin
                        //KEY2: troca cursor de sprite / tipo de polígono
                        if (pulso_key2) begin
                            if (cenario == 3'b001) begin
                                sprite_cursor <= (sprite_cursor == 5'd31) ? 5'd0 : sprite_cursor + 5'd1;
                                sprite_fliph_local <= 1'b0; // reseta flips visuais do cursor
                                sprite_flipv_local <= 1'b0;
                            end else if (cenario == 3'b011) begin
                                poly_tipo_cursor <= (poly_tipo_cursor == 3'd5) ? 3'd0 : poly_tipo_cursor + 3'd1;
                            end
                        end

                        // KEY1: espelhamento (cenário 001)
                        //   SW[5]=0 → toggle flip horizontal
                        //   SW[5]=1 → toggle flip vertical
                        if (pulso_key1 && cenario == 3'b001) begin
                            if (SW[5] == 1'b0)
                                sprite_fliph_local <= ~sprite_fliph_local;
                            else
                                sprite_flipv_local <= ~sprite_flipv_local;
                            // escrita imediata de flip no sprite do cursor
                            // (seleciona + escreve flags)
                            cen_lat   <= cenario;
                            spr_lat   <= sprite_cursor;
                            passo_max <= 6'd3; // sel + flags (com flip) + 0x20
                            passo     <= 6'd0;
                            estado    <= REPROD;
                            // flag especial: usaremos passo 0-2 só para flip
                        end

                        //KEY0: ações principais
                        if (pulso_key0) begin
                            cen_lat <= cenario;

                            case (cenario)
                                3'b000: begin
                                    // ativa scroll do background
                                    scroll_ativo <= ~scroll_ativo;
                                    if (!scroll_ativo) begin
                                        // ao ligar zera scroll e garante BG
                                        passo_max <= 6'd2;
                                        passo     <= 6'd0;
                                        estado    <= REPROD;
                                    end
                                end

                                3'b001: begin
                                    // Confirma sprite do cursor
                                    spr_lat               <= sprite_cursor;
                                    last_confirmed_sprite <= sprite_cursor;
                                    tem_sprite_confirmado <= 1'b1;
                                    passo_max <= 6'd6; // sel, padrao, flags, X, Y, leitor
                                    passo     <= 6'd0;
                                    estado    <= REPROD;
                                end

                                3'b010: begin
                                    // Prepara movimento, seleciona a última confirmada
                                    if (tem_sprite_confirmado) begin
                                        spr_lat   <= last_confirmed_sprite;
                                        passo_max <= 6'd3; // sel + X_init + Y_init (reinit)
                                        passo     <= 6'd0;
                                        estado    <= REPROD;
                                    end
                                end

                                3'b011: begin
                                    // Confirma polígono no próximo slot livre
                                    poly_tipo_lat         <= poly_tipo_cursor;
                                    poly_slot_lat         <= poly_slot_next;
                                    last_confirmed_poly   <= poly_slot_next;
                                    tem_poly_confirmado   <= 1'b1;
                                    cor_lat               <= SW[4:3];
                                    pos_lat               <= SW[9:5];
                                    poly_slot_next        <= poly_slot_next + 2'd1; // circular 0..3(zera ao contar 4)
                                    passo_max <= 6'd9; // 8 campos + layer
                                    passo     <= 6'd0;
                                    estado    <= REPROD;
                                end

                                3'b100: begin
                                    // Troca de buffers
                                    passo_max <= 6'd1;
                                    passo     <= 6'd0;
                                    estado    <= REPROD;
                                end

                                default: ;
                            endcase
                        end
                    end

                    REPROD: begin
                        if (passo < passo_max) begin
                            wr_en_seq <= 1'b1;

                            case (cen_lat)

                                //000: garante BG + zera scroll (não apaga sprite/poly)
                                3'b000: case (passo)
                                    6'd0: begin
                                        endereco_seq <= 16'h0008;
                                        // BG sempre,preserva elementos já confirmados
                                        dado_seq <= {6'b0,
                                                     tem_poly_confirmado,
                                                     tem_sprite_confirmado,
                                                     1'b1};
                                    end
                                    6'd1: begin
                                        endereco_seq <= 16'h0001;
                                        dado_seq     <= 9'd0;
                                    end
                                endcase

                                //001: confirma sprite OU aplica flip (KEY1)
                                3'b001: begin
                                    if (passo_max == 6'd3) begin
                                        // sequência curta de flip (KEY1)
                                        case (passo)
                                            6'd0: begin
                                                endereco_seq <= 16'h0003;
                                                dado_seq     <= {4'b0, spr_lat};
                                            end
                                            6'd1: begin
                                                // flags: enable=1, pri=0, fliph/flipv conforme locais
                                                // SPRITE_FLAGS [5:3]=pri, [2]=en, [1]=fliph, [0]=flipv
                                                endereco_seq <= 16'h0006;
                                                dado_seq     <= {3'd0, 1'b1, sprite_fliph_local, sprite_flipv_local};
                                            end
                                            6'd2: begin
                                                // também escreve 0x20: {6'b0, flipv, fliph}
                                                endereco_seq <= 16'h0020;
                                                dado_seq     <= {7'd0, sprite_flipv_local, sprite_fliph_local};
                                            end
                                        endcase
                                    end else begin
                                        // confirmação completa (KEY0)
                                        case (passo)
                                            6'd0: begin
                                                endereco_seq <= 16'h0003;
                                                dado_seq     <= {4'b0, spr_lat};
                                            end
                                            6'd1: begin
                                                // padrão = próprio índice (ou 0 se preferir fixo)
                                                endereco_seq <= 16'h0007;
                                                dado_seq     <= {4'b0, spr_lat};
                                            end
                                            6'd2: begin
                                                // enable=1, pri=0, fliph/flipv conforme locais
                                                endereco_seq <= 16'h0006;
                                                dado_seq     <= {3'd0, 1'b1, sprite_fliph_local, sprite_flipv_local};
                                            end
                                            6'd3: begin
                                                endereco_seq <= 16'h0004;
                                                dado_seq     <= SPRITE_X_INIT;
                                            end
                                            6'd4: begin
                                                endereco_seq <= 16'h0005;
                                                dado_seq     <= SPRITE_Y_INIT;
                                            end
                                            6'd5: begin
                                                // mantém BG + liga sprite (+ poly se já houver)
                                                endereco_seq <= 16'h0008;
                                                dado_seq     <= tem_poly_confirmado ? 9'b111 : 9'b011;
                                            end
                                        endcase
                                    end
                                end

                                //010: seleciona última sprite confirmada e reinicia pos
                                3'b010: case (passo)
                                    6'd0: begin
                                        endereco_seq <= 16'h0003;
                                        dado_seq     <= {4'b0, spr_lat};
                                    end
                                    6'd1: begin
                                        endereco_seq <= 16'h0004;
                                        dado_seq     <= SPRITE_X_INIT;
                                    end
                                    6'd2: begin
                                        endereco_seq <= 16'h0005;
                                        dado_seq     <= SPRITE_Y_INIT;
                                    end
                                endcase

                                //011: grava polígono no slot e mantém leitor
                                3'b011: begin
                                    case (passo)
                                        6'd0: begin // v0x
                                            endereco_seq <= 16'h0030 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vx[poly_tipo_lat][0] + poly_xoff;
                                        end
                                        6'd1: begin // v0y
                                            endereco_seq <= 16'h0031 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vy[poly_tipo_lat][0] + poly_yoff;
                                        end
                                        6'd2: begin // v1x
                                            endereco_seq <= 16'h0032 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vx[poly_tipo_lat][1] + poly_xoff;
                                        end
                                        6'd3: begin // v1y
                                            endereco_seq <= 16'h0033 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vy[poly_tipo_lat][1] + poly_yoff;
                                        end
                                        6'd4: begin // v2x
                                            endereco_seq <= 16'h0034 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vx[poly_tipo_lat][2] + poly_xoff;
                                        end
                                        6'd5: begin // v2y
                                            endereco_seq <= 16'h0035 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= poly_base_vy[poly_tipo_lat][2] + poly_yoff;
                                        end
                                        6'd6: begin // cor
                                            endereco_seq <= 16'h0036 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= {1'b0, cor_from_sw(cor_lat)};
                                        end
                                        6'd7: begin // ctrl
                                            endereco_seq <= 16'h0037 + {poly_slot_lat, 3'd0};
                                            dado_seq     <= {7'b0, poly_base_ctrl[poly_tipo_lat]};
                                        end
                                        6'd8: begin
                                            // BG + poly (+ sprite se já houver)
                                            endereco_seq <= 16'h0008;
                                            dado_seq     <= tem_sprite_confirmado ? 9'b111 : 9'b101;
                                        end
                                    endcase
                                end

                                //100: troca de buffers
                                3'b100: begin
                                    endereco_seq <= 16'h000B;
                                    dado_seq     <= 9'd1;
                                end

                                default: wr_en_seq <= 1'b0;
                            endcase

                            passo <= passo + 6'd1;
                        end else begin
                            estado <= IDLE;
                        end
                    end

                    default: estado <= IDLE;
                endcase
            end
        end
    end

    // Decodificador 7 segmentos
    function automatic [6:0] seg7;
        input [3:0] dig;
        begin
            case (dig)
                4'd0: seg7 = 7'b1000000;
                4'd1: seg7 = 7'b1111001;
                4'd2: seg7 = 7'b0100100;
                4'd3: seg7 = 7'b0110000;
                4'd4: seg7 = 7'b0011001;
                4'd5: seg7 = 7'b0010010;
                4'd6: seg7 = 7'b0000010;
                4'd7: seg7 = 7'b1111000;
                4'd8: seg7 = 7'b0000000;
                4'd9: seg7 = 7'b0010000;
                default: seg7 = 7'b1111111; // apagado
            endcase
        end
    endfunction



    localparam [6:0] SEG_S = 7'b0010010;     // 'S' 
    localparam [6:0] SEG_P = 7'b0001100;     // 'P' 
    localparam [6:0] SEG_OFF = 7'b1111111;
    localparam [6:0] SEG_DASH = 7'b0111111;

    // Valores a exibir
    wire [4:0] spr_show = (cenario == 3'b001) ? sprite_cursor :
                          (cenario == 3'b010) ? last_confirmed_sprite : 5'd0;
    wire [3:0] spr_dezenas = (spr_show >= 5'd30) ? 4'd3 :
                             (spr_show >= 5'd20) ? 4'd2 :
                             (spr_show >= 5'd10) ? 4'd1 : 4'd0;
    wire [3:0] spr_unidades = spr_show - (spr_dezenas * 4'd10);

    wire [2:0] poly_show = (cenario == 3'b011) ? poly_tipo_cursor : 3'd0;

    always @(*) begin
        //tudo apagado
        HEX0 = SEG_OFF;
        HEX1 = SEG_OFF;
        HEX2 = SEG_OFF;
        HEX3 = SEG_OFF;
        HEX4 = SEG_OFF;
        HEX5 = SEG_OFF;

        if (cenario == 3'b001 || cenario == 3'b010) begin
            // S + número do sprite (HEX5 = S, HEX4 = dezenas, HEX3 = unidades)
            HEX5 = SEG_S;
            HEX4 = (spr_dezenas == 4'd0) ? SEG_OFF : seg7(spr_dezenas);
            HEX3 = seg7(spr_unidades);
        end else if (cenario == 3'b011) begin
            // P + número do tipo de polígono (HEX5 = P, HEX4 = dígito)
            HEX5 = SEG_P;
            HEX4 = seg7({1'b0, poly_show});
        end else if (estimulo_invalido) begin
            HEX5 = SEG_DASH;
            HEX4 = SEG_DASH;
            HEX3 = SEG_DASH;
        end
    end

endmodule