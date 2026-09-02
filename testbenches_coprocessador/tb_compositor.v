// =============================================================================
// tb_compositor.v
// Testbench combinacional do compositor
// Verifica: prioridade sprite > poly > BG e transparência (cor == 0)
// =============================================================================
`timescale 1ns/1ps

module tb_compositor;

    reg enable_bg, enable_sprite, enable_poly;
    reg [7:0] cor_bg, cor_poly, cor_sprite;
    reg bg_valido, poly_ativo, sprite_ativo;
    wire [7:0] cor_final;

    compositor uut (
        .enable_bg(enable_bg), .enable_sprite(enable_sprite), .enable_poly(enable_poly),
        .cor_bg(cor_bg), .bg_valido(bg_valido),
        .cor_poly(cor_poly), .poly_ativo(poly_ativo),
        .cor_sprite(cor_sprite), .sprite_ativo(sprite_ativo),
        .cor_final(cor_final)
    );

    integer falhas;

    task checa;
        input [7:0] esperado;
        input [255:0] nome;
        begin
            #1;
            if (cor_final !== esperado) begin
                $display("FALHA [%0s]: cor_final=%h esperado=%h", nome, cor_final, esperado);
                falhas = falhas + 1;
            end else
                $display("PASS  [%0s]: cor_final=%h", nome, esperado);
        end
    endtask

    initial begin
        $display("=== TB compositor ===");
        falhas = 0;

        // defaults
        enable_bg = 0; enable_sprite = 0; enable_poly = 0;
        cor_bg = 8'h11; cor_poly = 8'h22; cor_sprite = 8'h33;
        bg_valido = 0; poly_ativo = 0; sprite_ativo = 0;

        // 1) nada ativo → 0
        checa(8'd0, "tudo off");

        // 2) só BG
        enable_bg = 1; bg_valido = 1;
        checa(8'h11, "somente BG");

        // 3) BG + poly (poly vence)
        enable_poly = 1; poly_ativo = 1;
        checa(8'h22, "poly sobre BG");

        // 4) BG + poly + sprite (sprite vence)
        enable_sprite = 1; sprite_ativo = 1;
        checa(8'h33, "sprite sobre tudo");

        // 5) sprite com cor 0 (transparente) → poly
        cor_sprite = 8'd0;
        checa(8'h22, "sprite transparente → poly");

        // 6) sprite e poly transparentes → BG
        cor_poly = 8'd0;
        checa(8'h11, "sprite+poly transparentes → BG");

        // 7) sprite ativo mas enable_sprite=0 → poly (ainda 0) → BG
        enable_sprite = 0; cor_sprite = 8'hAA; cor_poly = 8'hBB;
        poly_ativo = 1; enable_poly = 0;
        checa(8'h11, "enables desligados ignoram camadas");

        // 8) só sprite, cor não zero
        enable_bg = 0; enable_poly = 0; enable_sprite = 1;
        sprite_ativo = 1; cor_sprite = 8'hFC;
        checa(8'hFC, "somente sprite");

        // 9) sprite_ativo=0 mesmo com enable → BG se ligado
        sprite_ativo = 0; enable_bg = 1; bg_valido = 1; cor_bg = 8'h07;
        checa(8'h07, "sprite inativo → BG");

        if (falhas == 0)
            $display("=== TB compositor: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB compositor: %0d FALHA(S) ===", falhas);
        #10;
        $finish;
    end

endmodule
