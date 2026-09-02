module debounce_edge (
    input  wire clk,        // clk_sys (50 MHz)
    input  wire reset,
    input  wire tecla_bruta, // KEY[n], ativo em nivel baixo
    output reg  pulso        // 1 ciclo de clk_sys quando a tecla e pressionada
);

    reg [15:0] contador = 0;
    reg estavel = 1'b1, estavel_ant = 1'b1;
    wire tecla = ~tecla_bruta; // inverte para ativo-alto internamente

    always @(posedge clk) begin
        if (reset) begin
            contador    <= 0;
            estavel     <= 1'b0;
            estavel_ant <= 1'b0;
            pulso       <= 1'b0;
        end else begin
            if (tecla == estavel) begin
                contador <= 0;
            end else if (contador == 16'hFFFF) begin
                estavel  <= tecla;
                contador <= 0;
            end else begin
                contador <= contador + 1'b1;
            end
            estavel_ant <= estavel;
            pulso <= estavel & ~estavel_ant; // borda de subida do sinal ja limpo
        end
    end

endmodule
