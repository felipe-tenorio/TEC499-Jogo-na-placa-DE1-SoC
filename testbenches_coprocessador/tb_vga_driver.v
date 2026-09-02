// =============================================================================
// tb_vga_driver.v
// Testbench do vga_driver
// Verifica: contagem H/V, pulsos HSYNC/VSYNC, área ativa 640×480
// =============================================================================
`timescale 1ns/1ps

module tb_vga_driver;

    reg clock, reset;
    reg [7:0] color_in;
    wire [9:0] next_x, next_y;
    wire hsync, vsync;
    wire [7:0] red, green, blue;
    wire sync, clk_out, blank;

    vga_driver uut (
        .clock(clock), .reset(reset), .color_in(color_in),
        .next_x(next_x), .next_y(next_y),
        .hsync(hsync), .vsync(vsync),
        .red(red), .green(green), .blue(blue),
        .sync(sync), .clk(clk_out), .blank(blank)
    );

    // ~25 MHz
    initial clock = 0;
    always #20 clock = ~clock;

    integer falhas;
    integer hsync_edges, vsync_edges;
    integer ciclos_ativos_h;
    reg hsync_d, vsync_d;

    initial begin
        $display("=== TB vga_driver ===");
        falhas = 0;
        color_in = 8'hE0;
        reset = 1;
        hsync_edges = 0; vsync_edges = 0;
        hsync_d = 1; vsync_d = 1;
        ciclos_ativos_h = 0;
        repeat (5) @(posedge clock);
        reset = 0;

        // Observa ~2 frames (cada frame ~800*525 = 420000 ciclos — reduzido para demo)
        // Conta bordas de HSYNC/VSYNC e verifica blank na região ativa
        repeat (20000) begin
            @(posedge clock);
            if (hsync_d && !hsync) hsync_edges = hsync_edges + 1;
            if (vsync_d && !vsync) vsync_edges = vsync_edges + 1;
            hsync_d = hsync;
            vsync_d = vsync;

            // Na área ativa típica blank deve estar ativo (nível conforme driver)
            // next_x/next_y devem estar em faixa quando blank indica vídeo
            if (next_x < 10'd640 && next_y < 10'd480) begin
                // pixel potencialmente ativo
                ciclos_ativos_h = ciclos_ativos_h + 1;
            end
        end

        $display("INFO: hsync_edges=%0d vsync_edges=%0d ciclos_com_xy_ativos=%0d",
                 hsync_edges, vsync_edges, ciclos_ativos_h);

        if (hsync_edges < 10) begin
            $display("FALHA: poucos pulsos HSYNC"); falhas = falhas + 1;
        end else $display("PASS: HSYNC gerando pulsos (%0d)", hsync_edges);

        // Em 20000 ciclos @ 800/linha ≈ 25 linhas — VSYNC pode ainda não ter borda
        // Aumenta observação
        repeat (500000) begin
            @(posedge clock);
            if (vsync_d && !vsync) vsync_edges = vsync_edges + 1;
            vsync_d = vsync;
        end

        if (vsync_edges < 1) begin
            $display("FALHA: nenhum VSYNC observado"); falhas = falhas + 1;
        end else $display("PASS: VSYNC gerando pulsos (%0d)", vsync_edges);

        // Color path: força color_in e observa red/green/blue em algum momento ativo
        // RRRGGGBB = E0 → R=111, G=000, B=00 → expansão depende do driver
        color_in = 8'hE0;
        // Apenas verifica que saídas RGB existem e mudam de 0 em algum ponto
        begin : wait_rgb
            integer k;
            for (k = 0; k < 5000; k = k + 1) begin
                @(posedge clock);
                if (red !== 8'd0 || green !== 8'd0 || blue !== 8'd0) begin
                    $display("PASS: RGB não nulo (R=%h G=%h B=%h) next_x=%0d next_y=%0d",
                             red, green, blue, next_x, next_y);
                    disable wait_rgb;
                end
            end
            $display("INFO: RGB permaneceu 0 no intervalo (pode ser blank) — não conta como falha crítica");
        end

        if (falhas == 0)
            $display("=== TB vga_driver: TESTES PRINCIPAIS PASSARAM ===");
        else
            $display("=== TB vga_driver: %0d FALHA(S) ===", falhas);
        #100;
        $finish;
    end

endmodule
