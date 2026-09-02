module motor_sprites (
    input  wire clk_pix, reset,
    input  wire [8:0] logico_x, logico_y,  // Coordenada atual do pixel na tela
    input  wire       req_valid,       // 0 = fora da area=invalida
	// Atributos dos 32 sprites
    input  wire [8:0] attr_x       [0:31],
    input  wire [8:0] attr_y       [0:31],
    input  wire [4:0] attr_padrao  [0:31],
    input  wire       attr_en      [0:31],
    input  wire [2:0] attr_pri     [0:31],
    input  wire       attr_fliph   [0:31],
    input  wire       attr_flipv   [0:31],

    output reg  [12:0] padrao_addr_sprite,
    input  wire [7:0]  padrao_data_sprite,

    output wire [7:0]  cor_indice,
    output reg         pixel_ativo
);

    integer i;
    reg achou;
    reg [4:0] vencedor;
	
	// Procura qual sprite está na posição atual do pixel
    always @(*) begin
        achou = 1'b0;
        vencedor = 5'd0;
        for (i = 0; i < 32; i = i + 1) begin // Percorre os 32 sprites
            // Verifica se o sprite está habilitado
            // e se o pixel está dentro de sua área 16x16
				
				if (attr_en[i] &&
                logico_x >= attr_x[i] && logico_x < attr_x[i] + 16 &&
                logico_y >= attr_y[i] && logico_y < attr_y[i] + 16) begin
                if (!achou || attr_pri[i] > attr_pri[vencedor]) begin
                    vencedor = i[4:0];
                    achou = 1'b1;
                end
            end
        end
    end

    wire [3:0] px = logico_x - attr_x[vencedor];
    wire [3:0] py = logico_y - attr_y[vencedor];
    wire [3:0] px_ef = attr_fliph[vencedor] ? (4'd15 - px) : px;
    wire [3:0] py_ef = attr_flipv[vencedor] ? (4'd15 - py) : py;

    // pede na RAM, pixel_ativo so sobe se req_valid
	 // calcula o endereço do pixel na memória do sprite
    // e controla quando o pixel está ativo
    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            padrao_addr_sprite <= 13'd0;
            pixel_ativo        <= 1'b0;
        end else begin
            padrao_addr_sprite <= {attr_padrao[vencedor], 8'd0} + py_ef * 16 + px_ef;
            // req_valid=0 no fim da linha, pixel_ativo cai no ciclo da resposta
            pixel_ativo        <= achou & req_valid;
        end
    end
	// Cor obtida da memória do sprite
    assign cor_indice = padrao_data_sprite; // RRRGGGBB

endmodule
