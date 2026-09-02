module mov_continuo #(
    parameter WIDTH               = 9,
    parameter signed [WIDTH-1:0]  X_INIT          = 0, // usado so na ativaçao/reset
    parameter signed [WIDTH-1:0]  Y_INIT          = 0, // usado so no ativaçao/reset
    parameter [19:0]              PERIODO_NORMAL  = 20'd100000,
    parameter                     DIV_RAPIDO      = 2
)(
    input  wire                  clk_sys,
    input  wire                  reset,
    input  wire                  ativo,
    input  wire                  reinit,
    input  wire signed [WIDTH-1:0] reinit_x, // valor carregado em x_local quando reinit=1
    input  wire signed [WIDTH-1:0] reinit_y, // valor carregado em y_local quando reinit=1
    input  wire [1:0]            dir_h, //     01 = decrementa (esquerda / cima)
	 input  wire [1:0]            dir_v,//     10 = incrementa (direita / baixo)
													//     00 ou 11 = parado
    input  wire                  veloc_rapida, //Aumenta velocidade
    input  wire [15:0]           end_x,
    input  wire [15:0]           end_y,

    output reg                   wr_en,
    output reg  [15:0]           endereco,
    output reg  [8:0]            dado,

    output reg signed [WIDTH-1:0] x_local,
    output reg signed [WIDTH-1:0] y_local
);

    reg [19:0] timer;
    reg        eixo; // 0 = X, 1 = Y

    wire [19:0] periodo = veloc_rapida ? (PERIODO_NORMAL >> DIV_RAPIDO) : PERIODO_NORMAL;

    always @(posedge clk_sys) begin
        if (reset) begin
            timer    <= 20'd0;
            eixo     <= 1'b0;
            wr_en    <= 1'b0;
            endereco <= 16'd0;
            dado     <= 9'd0;
            x_local  <= X_INIT;
            y_local  <= Y_INIT;
        end else begin
            wr_en <= 1'b0;

            if (reinit) begin
                x_local <= reinit_x;
                y_local <= reinit_y;
                timer   <= 20'd0;
                eixo    <= 1'b0;
            end else if (ativo) begin
                if (timer >= periodo) begin
                    timer <= 20'd0;

                    if (!eixo) begin
                        // eixo x
                        case (dir_h)
                            2'b01: begin // esquerda / decrementa
                                x_local  <= x_local - 1'sd1;
                                wr_en    <= 1'b1;
                                endereco <= end_x;
                                dado     <= x_local - 1'sd1;
                            end
                            2'b10: begin // direita / incrementa
                                x_local  <= x_local + 1'sd1;
                                wr_en    <= 1'b1;
                                endereco <= end_x;
                                dado     <= x_local + 1'sd1;
                            end
                            default: ;
                        endcase
                    end else begin
                        // eixo  Y
                        case (dir_v)
                            2'b01: begin // baixo
                                y_local  <= y_local + 1'sd1;
                                wr_en    <= 1'b1;
                                endereco <= end_y;
                                dado     <= y_local + 1'sd1;
                            end
                            2'b10: begin // cima
                                y_local  <= y_local - 1'sd1;
                                wr_en    <= 1'b1;
                                endereco <= end_y;
                                dado     <= y_local - 1'sd1;
                            end
                            default: ;
                        endcase
                    end
                    eixo <= ~eixo;
                end else begin
                    timer <= timer + 20'd1;
                end
            end else begin
                timer <= 20'd0;
            end
        end
    end

endmodule