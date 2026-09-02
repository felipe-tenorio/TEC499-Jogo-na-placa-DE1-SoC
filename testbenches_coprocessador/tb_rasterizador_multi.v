// =============================================================================
// tb_rasterizador_multi.v
// Testbench do rasterizador: retângulo, triângulo, desempate por menor slot
// =============================================================================
`timescale 1ns/1ps

module tb_rasterizador_multi;

    reg clk_pix, reset;
    reg signed [9:0] logico_x, logico_y;
    reg signed [9:0] poly_vx [0:3][0:2];
    reg signed [9:0] poly_vy [0:3][0:2];
    reg [7:0] poly_cor [0:3];
    reg poly_habilitado [0:3];
    reg poly_modo_retangulo [0:3];
    wire pixel_ativo;
    wire [7:0] cor_indice;

    rasterizador_multi uut (
        .clk_pix(clk_pix), .reset(reset),
        .logico_x(logico_x), .logico_y(logico_y),
        .poly_vx(poly_vx), .poly_vy(poly_vy),
        .poly_cor(poly_cor),
        .poly_habilitado(poly_habilitado),
        .poly_modo_retangulo(poly_modo_retangulo),
        .pixel_ativo(pixel_ativo), .cor_indice(cor_indice)
    );

    initial clk_pix = 0;
    always #5 clk_pix = ~clk_pix;

    integer falhas, i, j;

    initial begin
        $display("=== TB rasterizador_multi ===");
        falhas = 0;
        reset = 1;
        logico_x = 0; logico_y = 0;
        for (i = 0; i < 4; i = i + 1) begin
            poly_habilitado[i] = 0;
            poly_modo_retangulo[i] = 0;
            poly_cor[i] = 0;
            for (j = 0; j < 3; j = j + 1) begin
                poly_vx[i][j] = 0;
                poly_vy[i][j] = 0;
            end
        end
        repeat (3) @(posedge clk_pix);
        reset = 0;

        // --- Retângulo no slot 0: (10,10) até (50,40), cor E0 ---
        poly_vx[0][0] = 10; poly_vy[0][0] = 10;
        poly_vx[0][1] = 50; poly_vy[0][1] = 40;
        poly_cor[0] = 8'hE0;
        poly_modo_retangulo[0] = 1;
        poly_habilitado[0] = 1;

        logico_x = 20; logico_y = 20; #1;
        if (!pixel_ativo || cor_indice !== 8'hE0) begin
            $display("FALHA: dentro do retângulo"); falhas = falhas + 1;
        end else $display("PASS: dentro do retângulo cor=%h", cor_indice);

        logico_x = 5; logico_y = 20; #1;
        if (pixel_ativo) begin
            $display("FALHA: fora do retângulo (esquerda)"); falhas = falhas + 1;
        end else $display("PASS: fora do retângulo");

        logico_x = 50; logico_y = 20; #1; // limite superior exclusivo em X
        if (pixel_ativo) begin
            $display("FALHA: X==v1x deve ser fora"); falhas = falhas + 1;
        end else $display("PASS: borda X exclusiva");

        // --- Triângulo slot 1: (0,0)-(0,40)-(40,40), cor 1C ---
        poly_habilitado[0] = 0;
        poly_vx[1][0] = 0;  poly_vy[1][0] = 0;
        poly_vx[1][1] = 0;  poly_vy[1][1] = 40;
        poly_vx[1][2] = 40; poly_vy[1][2] = 40;
        poly_cor[1] = 8'h1C;
        poly_modo_retangulo[1] = 0;
        poly_habilitado[1] = 1;

        logico_x = 5; logico_y = 30; #1;
        if (!pixel_ativo || cor_indice !== 8'h1C) begin
            $display("FALHA: dentro do triângulo (got ativo=%b cor=%h)", pixel_ativo, cor_indice);
            falhas = falhas + 1;
        end else $display("PASS: dentro do triângulo");

        logico_x = 30; logico_y = 5; #1;
        if (pixel_ativo) begin
            $display("FALHA: fora do triângulo"); falhas = falhas + 1;
        end else $display("PASS: fora do triângulo");

        // --- Desempate: dois retângulos sobrepostos → menor índice ---
        poly_habilitado[1] = 0;
        poly_vx[0][0] = 0; poly_vy[0][0] = 0;
        poly_vx[0][1] = 30; poly_vy[0][1] = 30;
        poly_cor[0] = 8'hAA;
        poly_modo_retangulo[0] = 1;
        poly_habilitado[0] = 1;

        poly_vx[2][0] = 10; poly_vy[2][0] = 10;
        poly_vx[2][1] = 40; poly_vy[2][1] = 40;
        poly_cor[2] = 8'hBB;
        poly_modo_retangulo[2] = 1;
        poly_habilitado[2] = 1;

        logico_x = 15; logico_y = 15; #1;
        if (!pixel_ativo || cor_indice !== 8'hAA) begin
            $display("FALHA: desempate (esperado slot0=AA, got %h)", cor_indice);
            falhas = falhas + 1;
        end else $display("PASS: desempate menor índice (slot0)");

        // --- Polígono desabilitado ---
        poly_habilitado[0] = 0; poly_habilitado[2] = 0;
        logico_x = 15; logico_y = 15; #1;
        if (pixel_ativo) begin
            $display("FALHA: deveria estar inativo"); falhas = falhas + 1;
        end else $display("PASS: todos desabilitados");

        if (falhas == 0)
            $display("=== TB rasterizador_multi: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB rasterizador_multi: %0d FALHA(S) ===", falhas);
        #20;
        $finish;
    end

endmodule
