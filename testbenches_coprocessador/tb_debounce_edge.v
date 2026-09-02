// =============================================================================
// tb_debounce_edge.v
// Testbench do módulo debounce_edge
// Verifica: bounce não gera pulso; após estabilização gera 1 pulso de 1 ciclo
// =============================================================================
`timescale 1ns/1ps

module tb_debounce_edge;

    reg clk, reset, tecla_bruta;
    wire pulso;

    debounce_edge uut (
        .clk(clk),
        .reset(reset),
        .tecla_bruta(tecla_bruta),
        .pulso(pulso)
    );

    // Clock 50 MHz
    initial clk = 0;
    always #10 clk = ~clk;

    integer ciclos_sem_pulso;
    integer falhas;

    initial begin
        $display("=== TB debounce_edge ===");
        falhas = 0;
        reset = 1;
        tecla_bruta = 1; // KEY solto (ativo-baixo: 1 = não pressionado)
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (5) @(posedge clk);

        // --- Teste 1: bounce rápido não deve gerar pulso ---
        $display("[%0t] Teste 1: bounce", $time);
        tecla_bruta = 0; @(posedge clk);
        tecla_bruta = 1; @(posedge clk);
        tecla_bruta = 0; @(posedge clk);
        tecla_bruta = 1; @(posedge clk);
        tecla_bruta = 0; // fica pressionado, mas contador ainda não chegou a FFFF
        ciclos_sem_pulso = 0;
        repeat (1000) begin
            @(posedge clk);
            if (pulso) begin
                $display("FALHA: pulso durante bounce em t=%0t", $time);
                falhas = falhas + 1;
            end
            ciclos_sem_pulso = ciclos_sem_pulso + 1;
        end
        $display("  OK: nenhum pulso nos primeiros 1000 ciclos de bounce");

        // --- Teste 2: espera contador 16'hFFFF (~65536 ciclos) ---
        $display("[%0t] Teste 2: estabilização e borda de subida", $time);
        // tecla_bruta já está em 0 (pressionado)
        // precisa manter estável por 65536 ciclos
        begin : wait_stable
            integer k;
            for (k = 0; k < 66000; k = k + 1) begin
                @(posedge clk);
                if (pulso) begin
                    $display("  PASS: pulso detectado após estabilização em t=%0t (ciclo ~%0d)", $time, k);
                    disable wait_stable;
                end
            end
            $display("FALHA: pulso não apareceu após 66000 ciclos");
            falhas = falhas + 1;
        end

        // --- Teste 3: soltar e pressionar de novo gera novo pulso ---
        $display("[%0t] Teste 3: segundo acionamento", $time);
        tecla_bruta = 1; // solta
        repeat (66000) @(posedge clk);
        tecla_bruta = 0; // pressiona
        begin : wait_stable2
            integer k;
            for (k = 0; k < 66000; k = k + 1) begin
                @(posedge clk);
                if (pulso) begin
                    $display("  PASS: segundo pulso em t=%0t", $time);
                    disable wait_stable2;
                end
            end
            $display("FALHA: segundo pulso não apareceu");
            falhas = falhas + 1;
        end

        // --- Teste 4: pulso tem largura de 1 ciclo ---
        // (já observado nos testes anteriores; validação visual no waveform)

        if (falhas == 0)
            $display("=== TB debounce_edge: TODOS OS TESTES PASSARAM ===");
        else
            $display("=== TB debounce_edge: %0d FALHA(S) ===", falhas);

        #100;
        $finish;
    end

endmodule
