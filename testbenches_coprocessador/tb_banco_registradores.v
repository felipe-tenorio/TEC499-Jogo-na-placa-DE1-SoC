// =============================================================================
// tb_banco_registradores.v
// Testbench do banco de registradores
// Verifica: escritas 0x01-0x08, 0x20, 0x30-0x37; endereço inválido; reset
// =============================================================================
`timescale 1ns/1ps

module tb_banco_registradores;

    reg clk_sys, reset, wr_en;
    reg [15:0] endereco;
    reg [8:0]  dado_in;
    reg estimulo_invalido, buffer_pronto;

    wire [7:0] bg_scroll_x, bg_scroll_y;
    wire [4:0] sprite_sel;
    wire [8:0] sprite_x [0:31];
    wire [8:0] sprite_y [0:31];
    wire [4:0] sprite_padrao [0:31];
    wire       sprite_en [0:31];
    wire [2:0] sprite_pri [0:31];
    wire       sprite_fliph [0:31];
    wire       sprite_flipv [0:31];
    wire enable_bg, enable_sprite, enable_poly;
    wire [8:0] ovr_spr1_x;
    wire ovr_prioridade;
    wire swap_request;
    wire signed [9:0] poly_vx [0:3][0:2];
    wire signed [9:0] poly_vy [0:3][0:2];
    wire [7:0] poly_cor [0:3];
    wire poly_habilitado [0:3];
    wire poly_modo_retangulo [0:3];
    wire [7:0] status;
    wire endereco_invalido;

    banco_registradores uut (
        .clk_sys(clk_sys), .reset(reset), .wr_en(wr_en),
        .endereco(endereco), .dado_in(dado_in),
        .bg_scroll_x(bg_scroll_x), .bg_scroll_y(bg_scroll_y),
        .sprite_sel(sprite_sel),
        .sprite_x(sprite_x), .sprite_y(sprite_y),
        .sprite_padrao(sprite_padrao), .sprite_en(sprite_en),
        .sprite_pri(sprite_pri), .sprite_fliph(sprite_fliph), .sprite_flipv(sprite_flipv),
        .enable_bg(enable_bg), .enable_sprite(enable_sprite), .enable_poly(enable_poly),
        .ovr_spr1_x(ovr_spr1_x), .ovr_prioridade(ovr_prioridade),
        .swap_request(swap_request),
        .poly_vx(poly_vx), .poly_vy(poly_vy),
        .poly_cor(poly_cor), .poly_habilitado(poly_habilitado),
        .poly_modo_retangulo(poly_modo_retangulo),
        .status(status), .estimulo_invalido(estimulo_invalido),
        .buffer_pronto(buffer_pronto), .endereco_invalido(endereco_invalido)
    );

    initial clk_sys = 0;
    always #5 clk_sys = ~clk_sys; // 100 MHz sim

    task escreve;
        input [15:0] addr;
        input [8:0]  data;
        begin
            @(negedge clk_sys);
            endereco = addr;
            dado_in  = data;
            wr_en    = 1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            wr_en = 0;
        end
    endtask

    integer falhas;

    initial begin
        $display("=== TB banco_registradores ===");
        falhas = 0;
        wr_en = 0; endereco = 0; dado_in = 0;
        estimulo_invalido = 0; buffer_pronto = 1;
        reset = 1;
        repeat (4) @(posedge clk_sys);
        reset = 0;
        repeat (2) @(posedge clk_sys);

        // --- Reset limpa enables ---
        if (enable_bg !== 0 || enable_sprite !== 0 || enable_poly !== 0) begin
            $display("FALHA: enables não zerados no reset");
            falhas = falhas + 1;
        end else $display("PASS: reset zera enables");

        // --- BG scroll ---
        escreve(16'h0001, 9'd40);
        escreve(16'h0002, 9'd20);
        if (bg_scroll_x !== 8'd40 || bg_scroll_y !== 8'd20) begin
            $display("FALHA: scroll BG");
            falhas = falhas + 1;
        end else $display("PASS: BG_SCROLL X/Y");

        // --- Sprite sel + X/Y + flags + padrao ---
        escreve(16'h0003, 9'd5);          // sel = 5
        escreve(16'h0004, 9'd100);        // X
        escreve(16'h0005, 9'd80);         // Y
        escreve(16'h0006, 9'b001_1_1_0);  // pri=1, en=1, fliph=1, flipv=0
        escreve(16'h0007, 9'd12);         // padrao 12
        if (sprite_sel !== 5'd5) begin $display("FALHA: sprite_sel"); falhas=falhas+1; end
        if (sprite_x[5] !== 9'd100 || sprite_y[5] !== 9'd80) begin
            $display("FALHA: sprite X/Y"); falhas=falhas+1;
        end else $display("PASS: sprite 5 X/Y");
        if (sprite_en[5] !== 1'b1 || sprite_fliph[5] !== 1'b1 || sprite_pri[5] !== 3'd1) begin
            $display("FALHA: sprite flags"); falhas=falhas+1;
        end else $display("PASS: sprite flags");
        if (sprite_padrao[5] !== 5'd12) begin
            $display("FALHA: sprite padrao"); falhas=falhas+1;
        end else $display("PASS: sprite padrao");

        // --- LAYER_ENABLE ---
        escreve(16'h0008, 9'b111);
        if (!enable_bg || !enable_sprite || !enable_poly) begin
            $display("FALHA: LAYER_ENABLE"); falhas=falhas+1;
        end else $display("PASS: LAYER_ENABLE");

        // --- SPRITE_FLIP (0x20) ---
        escreve(16'h0020, 9'b000000010); // flipv=1, fliph=0
        if (sprite_fliph[5] !== 1'b0 || sprite_flipv[5] !== 1'b1) begin
            $display("FALHA: 0x20 flip"); falhas=falhas+1;
        end else $display("PASS: SPRITE_FLIP 0x20");

        // --- POLY0: retângulo ---
        escreve(16'h0030, 9'd10);  // v0x
        escreve(16'h0031, 9'd10);  // v0y
        escreve(16'h0032, 9'd50);  // v1x
        escreve(16'h0033, 9'd40);  // v1y
        escreve(16'h0036, 9'hE0);  // cor
        escreve(16'h0037, 9'b11);  // modo_ret=1, hab=1
        if (poly_vx[0][0] !== 10'sd10 || poly_vy[0][1] !== 10'sd40) begin
            $display("FALHA: poly vertices"); falhas=falhas+1;
        end else $display("PASS: POLY0 vertices");
        if (!poly_habilitado[0] || !poly_modo_retangulo[0]) begin
            $display("FALHA: poly ctrl"); falhas=falhas+1;
        end else $display("PASS: POLY0 ctrl");
        if (poly_cor[0] !== 8'hE0) begin
            $display("FALHA: poly cor"); falhas=falhas+1;
        end else $display("PASS: POLY0 cor");

        // --- SWAP_CTRL ---
        escreve(16'h000B, 9'd1);
        // swap_request é pulso de 1 ciclo — amostrar no posedge seguinte à escrita
        // A task já terminou; checar se em algum momento foi 1 é difícil após o fato.
        // Re-escreve e observa no mesmo ciclo:
        @(negedge clk_sys);
        endereco = 16'h000B; dado_in = 9'd1; wr_en = 1;
        @(posedge clk_sys);
        if (swap_request !== 1'b1) begin
            $display("FALHA: swap_request não pulsou"); falhas=falhas+1;
        end else $display("PASS: SWAP_CTRL pulso");
        @(negedge clk_sys); wr_en = 0;
        @(posedge clk_sys);
        if (swap_request !== 1'b0) begin
            $display("FALHA: swap_request não voltou a 0"); falhas=falhas+1;
        end else $display("PASS: swap_request 1 ciclo");

        // --- Endereço inválido ---
        escreve(16'h00FF, 9'd1);
        if (endereco_invalido !== 1'b1) begin
            $display("FALHA: endereco_invalido"); falhas=falhas+1;
        end else $display("PASS: endereco inválido sinalizado");

        // --- STATUS ---
        if (status[0] !== estimulo_invalido || status[1] !== buffer_pronto) begin
            $display("FALHA: status"); falhas=falhas+1;
        end else $display("PASS: status");

        if (falhas == 0)
            $display("=== TB banco_registradores: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB banco_registradores: %0d FALHA(S) ===", falhas);
        #50;
        $finish;
    end

endmodule
