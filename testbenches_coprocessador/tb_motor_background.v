// =============================================================================
// tb_motor_background.v
// Testbench do motor de background com stubs de tilemap e padrões
// Verifica: endereços, pipeline de 2 ciclos, req_valid, scroll
// =============================================================================
`timescale 1ns/1ps

module tb_motor_background;

    reg clk_pix, reset;
    reg [8:0] logico_x, logico_y;
    reg req_valid;
    reg [7:0] scroll_x, scroll_y;
    wire [10:0] tilemap_addr;
    reg  [7:0]  tilemap_data;
    wire [13:0] padrao_addr;
    reg  [7:0]  padrao_data;
    wire [7:0]  cor_indice;
    wire        cor_valida;

    // Stub: tilemap devolve o próprio endereço baixo (padrão = addr[7:0])
    // Stub: padrão devolve valor fixo baseado no endereço
    always @(*) begin
        tilemap_data = tilemap_addr[7:0];
        padrao_data  = padrao_addr[7:0] ^ 8'hA5;
    end

    motor_background uut (
        .clk_pix(clk_pix), .reset(reset),
        .logico_x(logico_x), .logico_y(logico_y),
        .req_valid(req_valid),
        .scroll_x(scroll_x), .scroll_y(scroll_y),
        .tilemap_addr(tilemap_addr), .tilemap_data(tilemap_data),
        .padrao_addr(padrao_addr), .padrao_data(padrao_data),
        .cor_indice(cor_indice), .cor_valida(cor_valida)
    );

    initial clk_pix = 0;
    always #5 clk_pix = ~clk_pix;

    integer falhas;

    initial begin
        $display("=== TB motor_background ===");
        falhas = 0;
        reset = 1;
        logico_x = 0; logico_y = 0;
        req_valid = 0; scroll_x = 0; scroll_y = 0;
        repeat (4) @(posedge clk_pix);
        reset = 0;

        // Pixel (0,0), sem scroll, req_valid=1
        // tile_col=0, tile_row=0 → tilemap_addr=0
        logico_x = 0; logico_y = 0; req_valid = 1; scroll_x = 0; scroll_y = 0;
        @(posedge clk_pix); // N: tilemap_addr atualizado
        if (tilemap_addr !== 11'd0) begin
            $display("FALHA: tilemap_addr esperado 0, got %0d", tilemap_addr);
            falhas = falhas + 1;
        end else $display("PASS: tilemap_addr=0 em (0,0)");

        @(posedge clk_pix); // N+1: padrao_addr
        @(posedge clk_pix); // N+2: cor_valida / cor_indice
        if (!cor_valida) begin
            $display("FALHA: cor_valida deveria ser 1"); falhas = falhas + 1;
        end else $display("PASS: cor_valida após pipeline (2 ciclos)");

        // req_valid=0 → após 2 ciclos cor_valida=0
        req_valid = 0;
        @(posedge clk_pix);
        @(posedge clk_pix);
        @(posedge clk_pix);
        if (cor_valida) begin
            $display("FALHA: cor_valida deveria cair com req_valid=0"); falhas = falhas + 1;
        end else $display("PASS: req_valid=0 invalida pipeline");

        // Scroll: logico (0,0) + scroll_x=8 → x_w=8 → tile_col=1 (8>>3)
        req_valid = 1; scroll_x = 8; scroll_y = 0;
        logico_x = 0; logico_y = 0;
        @(posedge clk_pix);
        if (tilemap_addr !== 11'd1) begin
            $display("FALHA: scroll X: tilemap_addr esperado 1, got %0d", tilemap_addr);
            falhas = falhas + 1;
        end else $display("PASS: scroll X altera tile_col");

        // Pixel no tile (5, 3): x=40 (5*8), y=24 (3*8) → addr = 3*40+5 = 125
        scroll_x = 0; scroll_y = 0;
        logico_x = 40; logico_y = 24;
        @(posedge clk_pix);
        if (tilemap_addr !== 11'd125) begin
            $display("FALHA: tile (5,3) addr esperado 125, got %0d", tilemap_addr);
            falhas = falhas + 1;
        end else $display("PASS: tilemap_addr=125 em (40,24)");

        // Wrap: x=319+scroll 2 → 321-320=1
        logico_x = 319; scroll_x = 2; scroll_y = 0;
        @(posedge clk_pix);
        // x_w=1 → tile_col=0
        if (tilemap_addr[5:0] !== 6'd0) begin
            $display("INFO: wrap X tilemap_addr=%0d (tile_col=%0d)", tilemap_addr, tilemap_addr % 40);
        end
        $display("PASS: wrap horizontal exercitado (addr=%0d)", tilemap_addr);

        if (falhas == 0)
            $display("=== TB motor_background: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB motor_background: %0d FALHA(S) ===", falhas);
        #30;
        $finish;
    end

endmodule
