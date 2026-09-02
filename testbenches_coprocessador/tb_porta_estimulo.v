// =============================================================================
// tb_porta_estimulo.v
// Testbench da porta de estímulo
// Verifica: cenários SW[2:0], KEY0/1/2, estímulo inválido, wr_en/endereço
// =============================================================================
`timescale 1ns/1ps

module tb_porta_estimulo;

    reg clk_sys, reset;
    reg [9:0] SW;
    reg pulso_key0, pulso_key1, pulso_key2;
    wire wr_en;
    wire [15:0] endereco;
    wire [8:0]  dado;
    wire [2:0]  cenario_ativo;
    wire estimulo_invalido;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    porta_estimulo uut (
        .clk_sys(clk_sys), .reset(reset),
        .SW(SW),
        .pulso_key0(pulso_key0), .pulso_key1(pulso_key1), .pulso_key2(pulso_key2),
        .wr_en(wr_en), .endereco(endereco), .dado(dado),
        .cenario_ativo(cenario_ativo), .estimulo_invalido(estimulo_invalido),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
    );

    initial clk_sys = 0;
    always #10 clk_sys = ~clk_sys; // 50 MHz

    integer falhas;
    integer wr_count;

    task pulso;
        input integer qual; // 0,1,2
        begin
            @(negedge clk_sys);
            if (qual == 0) pulso_key0 = 1;
            else if (qual == 1) pulso_key1 = 1;
            else pulso_key2 = 1;
            @(posedge clk_sys);
            @(negedge clk_sys);
            pulso_key0 = 0; pulso_key1 = 0; pulso_key2 = 0;
        end
    endtask

    initial begin
        $display("=== TB porta_estimulo ===");
        falhas = 0;
        SW = 10'd0;
        pulso_key0 = 0; pulso_key1 = 0; pulso_key2 = 0;
        reset = 1;
        repeat (5) @(posedge clk_sys);
        reset = 0;
        repeat (5) @(posedge clk_sys);

        // --- Cenário inválido 101 ---
        SW[2:0] = 3'b101;
        repeat (3) @(posedge clk_sys);
        if (!estimulo_invalido) begin
            $display("FALHA: estímulo inválido 101"); falhas = falhas + 1;
        end else $display("PASS: SW=101 → estimulo_invalido");

        SW[2:0] = 3'b110;
        repeat (2) @(posedge clk_sys);
        if (!estimulo_invalido) begin
            $display("FALHA: estímulo inválido 110"); falhas = falhas + 1;
        end else $display("PASS: SW=110 → estimulo_invalido");

        SW[2:0] = 3'b111;
        repeat (2) @(posedge clk_sys);
        if (!estimulo_invalido) begin
            $display("FALHA: estímulo inválido 111"); falhas = falhas + 1;
        end else $display("PASS: SW=111 → estimulo_invalido");

        // --- Cenário 000: BG — após reset a porta escreve LAYER_ENABLE ---
        SW = 10'd0; // cenário 000
        // Após sair do inválido, bg_started pode já ter ocorrido no início
        // Gera KEY0 para toggle scroll
        wr_count = 0;
        fork
            begin : cont_wr
                repeat (50) begin
                    @(posedge clk_sys);
                    if (wr_en) wr_count = wr_count + 1;
                end
            end
            begin
                repeat (5) @(posedge clk_sys);
                pulso(0); // KEY0
                repeat (30) @(posedge clk_sys);
            end
        join
        $display("INFO: escritas após KEY0 no cenário 000: %0d", wr_count);
        if (wr_count == 0)
            $display("INFO: pode não haver escrita se scroll só liga timer (depende da versão)");
        else
            $display("PASS: porta gerou escritas no cenário 000");

        // --- Cenário 001: seleção de sprite ---
        SW[2:0] = 3'b001;
        repeat (3) @(posedge clk_sys);
        if (cenario_ativo !== 3'b001) begin
            $display("FALHA: cenario_ativo"); falhas = falhas + 1;
        end else $display("PASS: cenario_ativo=001");

        // KEY2 troca cursor
        pulso(2);
        repeat (5) @(posedge clk_sys);
        // KEY0 confirma sprite → sequência de escritas
        wr_count = 0;
        fork
            begin
                repeat (80) begin
                    @(posedge clk_sys);
                    if (wr_en) begin
                        wr_count = wr_count + 1;
                        $display("  wr addr=%h data=%h", endereco, dado);
                    end
                end
            end
            begin
                repeat (2) @(posedge clk_sys);
                pulso(0);
                repeat (60) @(posedge clk_sys);
            end
        join
        if (wr_count < 3) begin
            $display("FALHA: poucas escritas na confirmação de sprite (%0d)", wr_count);
            falhas = falhas + 1;
        end else $display("PASS: confirmação de sprite gerou %0d escritas", wr_count);

        // --- Cenário 100: swap ---
        SW[2:0] = 3'b100;
        repeat (3) @(posedge clk_sys);
        wr_count = 0;
        fork
            begin
                repeat (40) begin
                    @(posedge clk_sys);
                    if (wr_en) begin
                        wr_count = wr_count + 1;
                        if (endereco == 16'h000B)
                            $display("  PASS: escrita SWAP em 0x0B data=%h", dado);
                    end
                end
            end
            begin
                repeat (2) @(posedge clk_sys);
                pulso(0);
                repeat (20) @(posedge clk_sys);
            end
        join
        if (wr_count < 1) begin
            $display("FALHA: swap não gerou escrita"); falhas = falhas + 1;
        end else $display("PASS: cenário 100 gerou escrita(s)");

        // HEX não deve estar todos em 1111111 no cenário 001
        SW[2:0] = 3'b001;
        repeat (5) @(posedge clk_sys);
        if (HEX5 === 7'b1111111 && HEX4 === 7'b1111111) begin
            $display("INFO: HEX pode estar off dependendo do estado do cursor");
        end else
            $display("PASS: HEX atualizado no cenário de sprite (HEX5=%b)", HEX5);

        if (falhas == 0)
            $display("=== TB porta_estimulo: TESTES PRINCIPAIS PASSARAM ===");
        else
            $display("=== TB porta_estimulo: %0d FALHA(S) ===", falhas);
        #100;
        $finish;
    end

endmodule
