// =============================================================================
// tb_motor_sprites.v
// Testbench do motor de sprites com ROM stub
// Verifica: hit de bounding-box, prioridade, flip H, req_valid
// =============================================================================
`timescale 1ns/1ps

module tb_motor_sprites;

    reg clk_pix, reset;
    reg [8:0] logico_x, logico_y;
    reg req_valid;
    reg [8:0] attr_x [0:31];
    reg [8:0] attr_y [0:31];
    reg [4:0] attr_padrao [0:31];
    reg       attr_en [0:31];
    reg [2:0] attr_pri [0:31];
    reg       attr_fliph [0:31];
    reg       attr_flipv [0:31];
    wire [12:0] padrao_addr_sprite;
    reg  [7:0]  padrao_data_sprite;
    wire [7:0]  cor_indice;
    wire        pixel_ativo;

    integer i;

    // ROM stub: devolve endereço baixo como cor
    always @(*) padrao_data_sprite = padrao_addr_sprite[7:0];

    motor_sprites uut (
        .clk_pix(clk_pix), .reset(reset),
        .logico_x(logico_x), .logico_y(logico_y),
        .req_valid(req_valid),
        .attr_x(attr_x), .attr_y(attr_y),
        .attr_padrao(attr_padrao), .attr_en(attr_en),
        .attr_pri(attr_pri), .attr_fliph(attr_fliph), .attr_flipv(attr_flipv),
        .padrao_addr_sprite(padrao_addr_sprite),
        .padrao_data_sprite(padrao_data_sprite),
        .cor_indice(cor_indice), .pixel_ativo(pixel_ativo)
    );

    initial clk_pix = 0;
    always #5 clk_pix = ~clk_pix;

    integer falhas;

    initial begin
        $display("=== TB motor_sprites ===");
        falhas = 0;
        reset = 1;
        logico_x = 0; logico_y = 0; req_valid = 0;
        for (i = 0; i < 32; i = i + 1) begin
            attr_x[i] = 0; attr_y[i] = 0; attr_padrao[i] = 0;
            attr_en[i] = 0; attr_pri[i] = 0;
            attr_fliph[i] = 0; attr_flipv[i] = 0;
        end
        repeat (3) @(posedge clk_pix);
        reset = 0;

        // Sprite 0 em (10,20), padrão 3, enable, pri=1
        attr_x[0] = 10; attr_y[0] = 20;
        attr_padrao[0] = 5'd3;
        attr_en[0] = 1; attr_pri[0] = 3'd1;

        // Dentro do sprite
        logico_x = 12; logico_y = 22; req_valid = 1;
        @(posedge clk_pix); // endereço registrado, pixel_ativo sobe
        if (!pixel_ativo) begin
            $display("FALHA: pixel_ativo deveria ser 1"); falhas = falhas + 1;
        end else $display("PASS: pixel dentro do sprite 0");

        // px=2, py=2 → addr = {3,8'd0} + 2*16 + 2 = 3*256 + 34 = 802
        // Verificar fórmula: padrao*256 + py*16 + px
        if (padrao_addr_sprite !== (13'd3 << 8) + 13'd34) begin
            $display("FALHA: addr esperado %0d, got %0d", (3<<8)+34, padrao_addr_sprite);
            falhas = falhas + 1;
        end else $display("PASS: endereço do padrão correto");

        // Fora do sprite
        logico_x = 100; logico_y = 100;
        @(posedge clk_pix);
        if (pixel_ativo) begin
            $display("FALHA: fora do bounding-box"); falhas = falhas + 1;
        end else $display("PASS: fora do sprite → pixel_ativo=0");

        // Dois sprites sobrepostos: spr0 pri=1, spr1 pri=3 → vence spr1
        attr_x[1] = 10; attr_y[1] = 20;
        attr_padrao[1] = 5'd7;
        attr_en[1] = 1; attr_pri[1] = 3'd3;
        logico_x = 12; logico_y = 22;
        @(posedge clk_pix);
        if (!pixel_ativo) begin
            $display("FALHA: deveria haver hit"); falhas = falhas + 1;
        end
        // addr deve usar padrão 7 (vencedor)
        if (padrao_addr_sprite[12:8] !== 5'd7) begin
            $display("FALHA: prioridade — padrão esperado 7, got %0d", padrao_addr_sprite[12:8]);
            falhas = falhas + 1;
        end else $display("PASS: maior prioridade vence (spr1)");

        // Flip horizontal: px_ef = 15 - px
        attr_en[1] = 0; attr_fliph[0] = 1;
        attr_pri[0] = 3'd2;
        logico_x = 10; logico_y = 20; // px=0 → px_ef=15
        @(posedge clk_pix);
        // addr = 3*256 + 0*16 + 15 = 768+15 = 783
        if (padrao_addr_sprite !== (13'd3 << 8) + 13'd15) begin
            $display("FALHA: flip H addr esperado %0d, got %0d", (3<<8)+15, padrao_addr_sprite);
            falhas = falhas + 1;
        end else $display("PASS: flip horizontal");

        // req_valid=0
        req_valid = 0;
        logico_x = 12; logico_y = 22;
        @(posedge clk_pix);
        if (pixel_ativo) begin
            $display("FALHA: req_valid=0 deveria zerar pixel_ativo"); falhas = falhas + 1;
        end else $display("PASS: req_valid=0 invalida");

        if (falhas == 0)
            $display("=== TB motor_sprites: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB motor_sprites: %0d FALHA(S) ===", falhas);
        #30;
        $finish;
    end

endmodule
